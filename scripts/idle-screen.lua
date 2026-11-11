local mp = require("mp")

-- 坐标按 360 高的虚拟画布算，libass 会按窗口实际大小缩放，模糊半径也跟着缩放。
local CANVAS_H = 360
local BANDS = 36

-- 颜色写成 RGB，输出时再转成 ASS 的 BGR。
local TOP = { 0x10, 0x13, 0x1c }
local BOTTOM = { 0x1b, 0x15, 0x30 }
local GLOWS = {
    { x = 0.18, y = 0.12, r = 0.55, rgb = { 0x4a, 0x5b, 0xd4 }, alpha = 0xb0 },
    { x = 0.88, y = 0.95, r = 0.50, rgb = { 0x2a, 0xa1, 0x98 }, alpha = 0xc8 },
}

-- ModernGlass 的空闲图标在 z=-1000，背景要在它下面。
local bg = mp.create_osd_overlay("ass-events")
bg.z = -2000

local function ass_color(rgb)
    return string.format("&H%02X%02X%02X&", rgb[3], rgb[2], rgb[1])
end

local function mix(a, b, t)
    return {
        math.floor(a[1] + (b[1] - a[1]) * t + 0.5),
        math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
        math.floor(a[3] + (b[3] - a[3]) * t + 0.5),
    }
end

local function circle(cx, cy, r)
    local k = math.floor(r * 0.5523 + 0.5)
    return string.format(
        "m %d %d b %d %d %d %d %d %d b %d %d %d %d %d %d b %d %d %d %d %d %d b %d %d %d %d %d %d",
        cx - r, cy,
        cx - r, cy - k, cx - k, cy - r, cx, cy - r,
        cx + k, cy - r, cx + r, cy - k, cx + r, cy,
        cx + r, cy + k, cx + k, cy + r, cx, cy + r,
        cx - k, cy + r, cx - r, cy + k, cx - r, cy)
end

local function draw()
    local w, h = mp.get_osd_size()
    if not w or w <= 0 or h <= 0 then return end

    local cw = math.ceil(CANVAS_H * w / h)
    local events = {}

    for i = 0, BANDS - 1 do
        local y0 = math.floor(CANVAS_H * i / BANDS)
        local y1 = math.ceil(CANVAS_H * (i + 1) / BANDS)
        events[#events + 1] = string.format(
            "{\\an7\\pos(0,0)\\bord0\\shad0\\1c%s\\p1}m 0 %d l %d %d %d %d 0 %d{\\p0}",
            ass_color(mix(TOP, BOTTOM, i / (BANDS - 1))), y0, cw, y0, cw, y1, y1)
    end

    for _, g in ipairs(GLOWS) do
        events[#events + 1] = string.format(
            "{\\an7\\pos(0,0)\\bord0\\shad0\\blur60\\1c%s\\1a&H%02X&\\p1}%s{\\p0}",
            ass_color(g.rgb), g.alpha, circle(math.floor(cw * g.x), math.floor(CANVAS_H * g.y), math.floor(CANVAS_H * g.r)))
    end

    bg.res_x, bg.res_y = cw, CANVAS_H
    bg.data = table.concat(events, "\n")
    bg:update()
end

-- 最近播放列表由 mpv 自带的 select.lua 提供，界面借用 console。
local function history_exists()
    local path = mp.command_native({ "expand-path", mp.get_property("watch-history-path") })
    local f = io.open(path)
    if f then f:close() end
    return f ~= nil
end

local function console_open()
    return mp.get_property_native("user-data/mpv/console/open") == true
end

local idle = false
local opened_history = false

local function open_history()
    -- 没有历史文件时 select.lua 会弹报错，第一次启动直接跳过。
    if not idle or console_open() or not history_exists() then return end
    mp.commandv("script-binding", "select/select-watch-history")
    opened_history = true
end

mp.observe_property("idle-active", "bool", function(_, active)
    idle = active
    if active then
        draw()
        -- 刚启动时 select.lua 可能还没加载完，稍等再打开。
        mp.add_timeout(0.3, open_history)
    else
        bg:remove()
        if opened_history and console_open() then
            mp.commandv("script-message-to", "console", "disable")
        end
        opened_history = false
    end
end)

mp.observe_property("osd-dimensions", "native", function()
    if idle then draw() end
end)
