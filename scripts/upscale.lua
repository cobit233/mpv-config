local mp = require("mp")

-- 默认超分链路只在这里定义，脚本加载时挂上。
local chain = {
    "~~/third_party/Anime4K/glsl/Deblur/Anime4K_Deblur_DoG.glsl",
    "~~/third_party/Anime4K/glsl/Restore/Anime4K_Restore_CNN_L.glsl",
    "~~/third_party/Anime4K/glsl/Upscale/Anime4K_Upscale_CNN_x2_L.glsl",
}

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

local function apply_chain()
    remove_upscale()
    for _, path in ipairs(chain) do
        mp.commandv("change-list", "glsl-shaders", "append", path)
    end
end

local function off()
    remove_upscale()
    mp.osd_message("超分: 关闭")
end

local function on()
    apply_chain()
    mp.osd_message("超分: Anime4K 极致")
end

local function toggle()
    if #upscale_paths() > 0 then
        off()
    else
        on()
    end
end

mp.add_key_binding(nil, "toggle", toggle)
mp.add_key_binding(nil, "on", on)
mp.add_key_binding(nil, "off", off)
mp.register_script_message("on", on)
mp.register_script_message("off", off)

apply_chain()
