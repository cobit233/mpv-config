-- clipboard.lua

function play_from_clipboard()
    -- 获取剪切板内容
    local handle = io.popen('xclip -selection clipboard -o')
    local clipboard_content = handle:read('*a')
    handle:close()

    -- 去除可能存在的空白字符
    clipboard_content = clipboard_content:match("^%s*(.-)%s*$")

    -- 如果剪切板有内容
    if clipboard_content ~= "" then
        -- 设置 idle 模式，防止加载失败时 mpv 直接退出
        mp.set_property("idle", "yes")

        -- 使用 commandv 安全传递参数（避免 URL 中的特殊字符导致问题）
        mp.commandv("loadfile", clipboard_content)

        -- 延迟检查是否加载成功
        mp.add_timeout(0.5, function()
            if mp.get_property_bool("idle-active") then
                mp.osd_message("无法解析此链接: " .. clipboard_content, 5)
            end
        end)
    else
        -- 如果剪切板为空，显示提示信息
        mp.osd_message("剪切板没有内容", 3)
    end
end

-- 将脚本绑定到快捷键 Ctrl+V
mp.add_key_binding("Ctrl+v", "play_from_clipboard", play_from_clipboard)
