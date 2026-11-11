local mp = require("mp")

-- 超分档位只在这里定义，菜单用 script-message-to upscale set <名字> 切换。
local a4k = "~~/third_party/Anime4K/glsl/"
local artcnn = "~~/third_party/ArtCNN/GLSL/"
local modes = {
    a4k_light = {
        label = "Anime4K 轻量",
        chain = { a4k .. "Upscale/Anime4K_Upscale_CNN_x2_S.glsl" },
    },
    a4k_balanced = {
        label = "Anime4K 推荐",
        chain = {
            a4k .. "Restore/Anime4K_Restore_CNN_M.glsl",
            a4k .. "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
        },
    },
    a4k_ultra = {
        label = "Anime4K 极致",
        chain = {
            a4k .. "Deblur/Anime4K_Deblur_DoG.glsl",
            a4k .. "Restore/Anime4K_Restore_CNN_L.glsl",
            a4k .. "Upscale/Anime4K_Upscale_CNN_x2_L.glsl",
        },
    },
    artcnn_neutral = { label = "ArtCNN 中性", chain = { artcnn .. "ArtCNN_C4F32.glsl" } },
    artcnn_sharp = { label = "ArtCNN 去噪锐化", chain = { artcnn .. "ArtCNN_C4F32_DS.glsl" } },
    artcnn_soft = { label = "ArtCNN 去噪柔化", chain = { artcnn .. "ArtCNN_C4F32_DN.glsl" } },
    artcnn_light = { label = "ArtCNN 轻量", chain = { artcnn .. "ArtCNN_C4F16.glsl" } },
}
local default_mode = "a4k_ultra"
local last_mode = default_mode

-- modernz.lua 自己挂的玻璃模糊着色器也在 glsl-shaders 里，换档时不能动它。
local function is_glass(path)
    return path:find("modernz-glass", 1, true) ~= nil
end

local function upscale_paths()
    local found = {}
    for _, path in ipairs(mp.get_property_native("glsl-shaders") or {}) do
        if not is_glass(path) then
            found[#found + 1] = path
        end
    end
    return found
end

local function remove_upscale()
    for _, path in ipairs(upscale_paths()) do
        mp.commandv("change-list", "glsl-shaders", "remove", path)
    end
end

local function current_mode()
    local paths = upscale_paths()
    if #paths == 0 then
        return "off"
    end
    for name, m in pairs(modes) do
        if #m.chain == #paths then
            local same = true
            for i, path in ipairs(m.chain) do
                if paths[i] ~= path then
                    same = false
                    break
                end
            end
            if same then
                return name
            end
        end
    end
    return "custom"
end

local function set_mode(name, quiet)
    local m = modes[name]
    if not m then
        mp.msg.error("unknown mode: " .. tostring(name))
        return
    end
    remove_upscale()
    for _, path in ipairs(m.chain) do
        mp.commandv("change-list", "glsl-shaders", "append", path)
    end
    last_mode = name
    if not quiet then
        mp.osd_message("超分: " .. m.label)
    end
end

local function off()
    remove_upscale()
    mp.osd_message("超分: 关闭")
end

local function toggle()
    if current_mode() == "off" then
        set_mode(last_mode)
    else
        off()
    end
end

-- 菜单靠 user-data/upscale 打勾。
mp.observe_property("glsl-shaders", "native", function()
    local mode = current_mode()
    if modes[mode] then
        last_mode = mode
    end
    mp.set_property_native("user-data/upscale", mode)
end)

mp.add_key_binding(nil, "toggle", toggle)
mp.add_key_binding(nil, "off", off)
mp.register_script_message("set", function(name) set_mode(name) end)
mp.register_script_message("off", off)

set_mode(default_mode, true)
