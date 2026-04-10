-- clipboard.lua

function play_from_clipboard()
    -- 获取剪切板内容
    local handle = io.popen('xclip -selection clipboard -o')  -- 使用 xclip 从剪切板获取链接
    local clipboard_content = handle:read('*a')
    handle:close()

    -- 去除可能存在的空白字符
    clipboard_content = clipboard_content:match("^%s*(.-)%s*$")

    -- 如果剪切板有内容
    if clipboard_content ~= "" then
        -- 播放链接
        mp.command('loadfile "' .. clipboard_content .. '"')

        -- 监听播放停止事件
        mp.register_event("stop", function()
            -- 检查当前播放状态是否出错
            local error = mp.get_property("error")
            if error and error ~= "" then
                -- 如果有错误，显示错误消息
                mp.osd_message("无法播放此链接", 3)
            end
        end)
    else
        -- 如果剪切板为空，显示提示信息
        mp.osd_message("剪切板没有内容", 3)
    end
end

-- 将脚本绑定到快捷键 Ctrl+V
mp.add_key_binding("Ctrl+v", "play_from_clipboard", play_from_clipboard)
