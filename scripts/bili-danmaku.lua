--[[
bili-danmaku.lua — B站弹幕自动加载

原理：
  mpv 的 ytdl_hook 用 `yt-dlp -J`（纯 JSON 模式）跑 yt-dlp，全程不落地文件，
  它拿到的弹幕轨只有原始 XML，而 mpv 不认 B站 XML 弹幕格式（显示为 (null) codec）。
  本脚本在文件加载后独立再跑一次 yt-dlp 把 XML 落盘，用 biliass 转成 ASS，
  再通过 sub-add 挂给 mpv，并移除那个无法解析的内置轨。

依赖：yt-dlp、biliass 均在 PATH 中。

缓存：~/.cache/bili-danmaku/<URL>-<hash>/danmaku-v<版本>.ass
      只缓存弹幕 ASS；视频音频不落盘（mpv 流式播放）。

快捷键：
  d 键        开/关弹幕（默认开启）
  手动重载弹幕：在 input.conf 里绑 script-message bili-danmaku-reload

]]

local mp      = require 'mp'
local msg     = mp.msg
local utils   = require 'mp.utils'
local options = require 'mp.options'

local opts = {
    enabled                = true,    -- false = 完全关闭本脚本
    font_face              = "Source Han Sans CN",  -- 弹幕字体
    font_size              = 0,       -- 0 = 自动，取 max(宽,高)/30；>0 = 固定字号
    text_opacity           = 0.5,     -- 弹幕透明度（0 完全透明，1 完全不透明）
    duration_marquee       = 12.0,    -- 滚动弹幕停留秒数
    duration_still         = 8.0,     -- 固定弹幕停留秒数
    block_top              = false,   -- 屏蔽顶部弹幕
    block_bottom           = false,   -- 屏蔽底部弹幕
    block_scroll           = false,   -- 屏蔽滚动弹幕
    block_reverse          = false,   -- 屏蔽逆向弹幕
    block_fixed            = false,   -- 屏蔽固定弹幕（顶+底）
    block_special          = false,   -- 屏蔽高级弹幕
    block_colorful         = false,   -- 屏蔽彩色弹幕
    block_keyword_patterns = "",      -- 关键词屏蔽，逗号分隔
    ytdl_path              = "yt-dlp", -- yt-dlp 可执行文件路径，默认走 PATH
    biliass_path           = "biliass", -- biliass 可执行文件路径，默认走 PATH
    cache_days             = 1,       -- 缓存天数，0 = 永不过期
    keep_intermediate      = false,   -- true = 保留 xml/info.json 便于排查
    style_version          = 2,       -- 改弹幕风格参数后 +1 让旧缓存失效（v2: 尺寸改从 mpv 取，字号自动 /30）
}
options.read_options(opts, "bili-danmaku")

local HOME  = os.getenv("HOME") or "/tmp"
local CACHE = utils.join_path(HOME, ".cache/bili-danmaku")

-- 每次换文件自增，异步回调靠它丢弃过期结果
local gen = 0

-- d 键开关弹幕用：记住上一次挂载的 ASS 路径（非 nil 说明挂载过）
local last_ass = nil
-- 开关状态：默认关时不自动挂载
local danmaku_off = false

-- ---------------------------------------------------------------- 小工具

local function log(fmt, ...)  msg.info("[bili-danmaku] " .. string.format(fmt, ...)) end
local function warn(fmt, ...) msg.warn("[bili-danmaku] " .. string.format(fmt, ...)) end

local function exists(path)
    local ok, info = pcall(utils.file_info, path)
    return ok and info ~= nil and info.is_file == true
end

-- mp.utils 没有 read_file（本构建只有 readdir/file_info/parse_json 等），
-- 用标准 Lua io 读文件
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- 缓存是否新鲜
local function is_fresh(path)
    if opts.cache_days <= 0 then return true end
    local ok, info = pcall(utils.file_info, path)
    if not ok or not info or not info.mtime then return true end -- 拿不到 mtime 就当作新鲜
    local age = os.time() - info.mtime
    return age >= 0 and age < opts.cache_days * 86400
end

local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function mkdir_p(path)
    os.execute("mkdir -p " .. shell_quote(path))
end

local function sanitize(s)
    s = tostring(s):gsub("[^%w%-%._]", "_")
    if #s > 72 then s = s:sub(1, 72) end
    return s
end

-- 纯算术 hash，兼容 Lua 5.1 (LuaJIT) 与 5.2+
local function hash(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 4294967296
    end
    return string.format("%08x", h)
end

local BILI_HOSTS = { "bilibili%.com", "b23%.tv", "bilibili%.tv", "acg%.tv" }

local function is_bili(url)
    if not url or url == "" then return false end
    for _, pat in ipairs(BILI_HOSTS) do
        if url:find(pat) then return true end
    end
    return false
end

local function cache_paths(url)
    local key     = sanitize(url) .. "-" .. hash(url)
    local workdir = utils.join_path(CACHE, key)
    local ass     = utils.join_path(workdir, "danmaku-v" .. tostring(opts.style_version) .. ".ass")
    return workdir, ass
end

-- ---------------------------------------------------------------- 字幕挂载

local function add_sub(ass)
    mp.commandv("sub-add", ass, "select", "弹幕", "danmaku")
    last_ass = ass
end

-- 移除 ytdl_hook 留下的无法解析的弹幕轨（codec 为空的那个）。
-- 注意 sub-remove 会让 track id 重排，所以收集后按 id 倒序删。
local function drop_broken_danmaku_track()
    local tracks = mp.get_property_native("track-list") or {}
    local victims = {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" and t.lang == "danmaku" then
            local codec = t.codec or ""
            local ext   = t["external-filename"] or ""
            -- 我们挂的 ASS 有 codec=ass；ytdl 的 XML 轨 codec 为 "" 或 "null"
            if (codec == "" or codec == "null") and not ext:match("%.ass$") then
                victims[#victims + 1] = t.id
            end
        end
    end
    table.sort(victims, function(a, b) return a > b end)
    for _, id in ipairs(victims) do
        mp.commandv("sub-remove", tostring(id))
        log("移除无法解析的内置弹幕轨 id=%s", tostring(id))
    end
end

-- ---------------------------------------------------------------- 转换

local function run_biliass(xml, info_path, ass_out, mygen)
    -- 尺寸优先取 mpv 自己解出来的视频尺寸（真实分辨率）。
    -- 不能优先用 info.json：抓弹幕那次 yt-dlp 调用不带 cookie，
    -- 番剧会被限到 480P，info.json 里的宽高就变成 852x480，与 1080P 的视频不符。
    local w = mp.get_property_number("width")
    local h = mp.get_property_number("height")
    local src = "mpv"

    if not (w and h and w > 0 and h > 0) then
        src = "info.json"
        w, h = nil, nil
        local raw = info_path and read_file(info_path)
        if raw then
            local ok, info = pcall(utils.parse_json, raw)
            if ok and type(info) == "table" and info.width and info.height then
                w, h = info.width, info.height
            end
        end
        if not w then w, h, src = 1920, 1080, "默认值" end
    end

    local fs = opts.font_size
    if not fs or fs <= 0 then fs = math.max(w, h) / 30 end

    local args = {
        opts.biliass_path,
        "-s",  string.format("%dx%d", w, h),
        "-fn", opts.font_face,
        "-fs", tostring(math.floor(fs + 0.5)),
        "-a",  tostring(opts.text_opacity),
        "-dm", tostring(opts.duration_marquee),
        "-ds", tostring(opts.duration_still),
        "-o",  ass_out,
    }
    if opts.block_top      then args[#args + 1] = "--block-top"      end
    if opts.block_bottom   then args[#args + 1] = "--block-bottom"   end
    if opts.block_scroll   then args[#args + 1] = "--block-scroll"   end
    if opts.block_reverse  then args[#args + 1] = "--block-reverse"  end
    if opts.block_fixed    then args[#args + 1] = "--block-fixed"    end
    if opts.block_special  then args[#args + 1] = "--block-special"  end
    if opts.block_colorful then args[#args + 1] = "--block-colorful" end
    if opts.block_keyword_patterns ~= "" then
        args[#args + 1] = "--block-keyword-patterns"
        args[#args + 1] = opts.block_keyword_patterns
    end
    args[#args + 1] = xml

    log("转换: %dx%d (尺寸来源: %s) 字号=%d %s", w, h, src, math.floor(fs + 0.5), xml)

    mp.command_native_async({
        name           = "subprocess",
        args           = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only  = false,
    }, function(success, res, err)
        if mygen ~= gen then return end
        if not success or not exists(ass_out) then
            local e = tostring(err)
            if type(res) == "table" and res.stderr then e = e .. " " .. tostring(res.stderr) end
            warn("biliass 失败: %s", e)
            return
        end
        log("弹幕就绪: %s", ass_out)
        add_sub(ass_out)
        drop_broken_danmaku_track()

        if not opts.keep_intermediate then
            os.remove(xml)
            if info_path then os.remove(info_path) end
        end
    end)
end

-- ---------------------------------------------------------------- 抓取

local function start_fetch(url, mygen)
    local workdir, ass = cache_paths(url)

    if exists(ass) and is_fresh(ass) then
        log("缓存命中: %s", ass)
        add_sub(ass)
        drop_broken_danmaku_track()
        return
    end

    mkdir_p(workdir)

    -- 注意：Lua 普通字符串里 % 是字面量，不能写成 %%
    local template = utils.join_path(workdir, "%(id)s.%(ext)s")
    local args = {
        opts.ytdl_path, "--no-warnings", "--skip-download",
        "--write-subs", "--sub-format", "xml", "--sub-langs", "danmaku",
        "--write-info-json", "--no-playlist",
        "-o", template,
        "--", url,
    }

    log("抓取弹幕: %s", url)

    mp.command_native_async({
        name           = "subprocess",
        args           = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only  = false,
    }, function(success, res, err)
        if mygen ~= gen then return end
        if not success then
            local e = tostring(err)
            if type(res) == "table" and res.stderr then e = e .. " " .. tostring(res.stderr) end
            warn("yt-dlp 失败: %s", e)
            return
        end

        local entries = utils.readdir(workdir, "files") or {}
        local xml, info_path
        for _, f in ipairs(entries) do
            local full = utils.join_path(workdir, f)
            if f:match("%.danmaku%.xml$") then
                xml = full
            elseif f:match("%.info%.json$") then
                info_path = full
            end
        end

        if not xml then
            warn("未找到弹幕 XML（该视频可能没有弹幕或已关闭）")
            return
        end

        run_biliass(xml, info_path, ass, mygen)
    end)
end

-- ---------------------------------------------------------------- 事件

mp.register_event("file-loaded", function()
    gen = gen + 1
    local mygen = gen

    if not opts.enabled then return end

    local url = mp.get_property("path")
    if not is_bili(url) then return end

    log("检测到 B站链接: %s", tostring(url))
    start_fetch(url, mygen)
end)

-- ---------------------------------------------------------------- 开关弹幕（d 键）

local function remove_ass_track()
    if not last_ass then return end
    local tracks = mp.get_property_native("track-list") or {}
    local victims = {}
    for _, t in ipairs(tracks) do
        if t.type == "sub" and t.lang == "danmaku" then
            local ext = t["external-filename"] or ""
            if ext:match("%.ass$") then
                victims[#victims + 1] = t.id
            end
        end
    end
    table.sort(victims, function(a, b) return a > b end)
    for _, id in ipairs(victims) do
        mp.commandv("sub-remove", tostring(id))
    end
end

local function toggle_danmaku()
    local url = mp.get_property("path")
    if not is_bili(url) then
        mp.osd_message("bili-danmaku: 当前不是 B站链接", 2)
        return
    end

    if not danmaku_off then
        -- 关弹幕：卸载 ASS 轨，但保留 last_ass 以便下次恢复
        remove_ass_track()
        danmaku_off = true
        log("弹幕：已关闭")
        mp.osd_message("弹幕：关闭", 1.5)
        return
    end

    -- 开弹幕
    danmaku_off = false
    if last_ass and exists(last_ass) then
        -- 已有现成的 ASS，直接重新挂
        log("弹幕：重新挂载 %s", last_ass)
        add_sub(last_ass)
        drop_broken_danmaku_track()
        mp.osd_message("弹幕：开启", 1.5)
        return
    end
    -- 还没抓过或缓存丢了，走正常抓取流程
    local _, ass = cache_paths(url)
    if exists(ass) and is_fresh(ass) then
        log("缓存命中(开关打开时): %s", ass)
        add_sub(ass)
        drop_broken_danmaku_track()
        mp.osd_message("弹幕：开启", 1.5)
        return
    end
    gen = gen + 1
    log("弹幕开关打开，触发抓取: %s", tostring(url))
    mp.osd_message("弹幕：开启，正在抓取…", 2)
    start_fetch(url, gen)
end

mp.add_key_binding("d", "toggle-danmaku", toggle_danmaku)

-- ---------------------------------------------------------------- 手动重载（通过 script-message 调用，无默认键位）

local function reload()
    gen = gen + 1
    local mygen = gen

    local url = mp.get_property("path")
    if not is_bili(url) then
        mp.osd_message("bili-danmaku: 当前不是 B站链接", 2)
        return
    end

    local _, ass = cache_paths(url)
    os.remove(ass)
    log("忽略缓存，重新抓取: %s", tostring(url))
    mp.osd_message("bili-danmaku: 重新抓取弹幕…", 2)
    start_fetch(url, mygen)
end

mp.register_script_message("bili-danmaku-reload", reload)
