local mp = require("mp")

local chain = {
    "~~/shaders/glsl/Deblur/Anime4K_Deblur_DoG.glsl",
    "~~/shaders/glsl/Restore/Anime4K_Restore_CNN_L.glsl",
    "~~/shaders/glsl/Upscale/Anime4K_Upscale_CNN_x2_L.glsl",
}

local function is_glass(path)
    return path:find("modernz-glass", 1, true) ~= nil
end

local function sr_paths()
    local found = {}
    for _, path in ipairs(mp.get_property_native("glsl-shaders") or {}) do
        if not is_glass(path) then
            found[#found + 1] = path
        end
    end
    return found
end

local function off()
    for _, path in ipairs(sr_paths()) do
        mp.commandv("change-list", "glsl-shaders", "remove", path)
    end
    mp.osd_message("超分: 关闭")
end

local function on()
    for _, path in ipairs(sr_paths()) do
        mp.commandv("change-list", "glsl-shaders", "remove", path)
    end
    for _, path in ipairs(chain) do
        mp.commandv("change-list", "glsl-shaders", "append", path)
    end
    mp.osd_message("超分: Anime4K 极致")
end

local function toggle()
    if #sr_paths() > 0 then
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
