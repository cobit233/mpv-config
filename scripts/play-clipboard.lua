local mp = require("mp")

local function play_from_clipboard()
    -- 获取剪贴板内容
    local handle = io.popen("wl-paste --no-newline")
    local content = handle:read("*a")
    handle:close()

    -- 去除可能存在的空白字符
    content = content:match("^%s*(.-)%s*$")

    if content ~= "" then
        -- 设置 idle 模式，防止加载失败时 mpv 直接退出
        mp.set_property("idle", "yes")

        -- 使用 commandv 安全传递参数（避免 URL 中的特殊字符导致问题）
        mp.commandv("loadfile", content)

        -- 延迟检查是否加载成功
        mp.add_timeout(0.5, function()
            if mp.get_property_bool("idle-active") then
                mp.osd_message("无法解析此链接: " .. content, 5)
            end
        end)
    else
        mp.osd_message("剪贴板没有内容", 3)
    end
end

mp.add_key_binding(nil, "play", play_from_clipboard)
