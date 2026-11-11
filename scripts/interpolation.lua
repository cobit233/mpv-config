local mp = require("mp")

-- RIFE 2 倍插帧的开关，启动时挂上。参数都在 frame-interpolation/rife.vpy 里。
local vpy = mp.command_native({ "expand-path", "~~/frame-interpolation/rife.vpy" })

local function is_rife(f)
    return f.name == "vapoursynth" and (f.params.file or ""):find("rife%.vpy$") ~= nil
end

local function other_filters()
    local kept = {}
    for _, f in ipairs(mp.get_property_native("vf") or {}) do
        if not is_rife(f) then
            kept[#kept + 1] = f
        end
    end
    return kept
end

local function is_on()
    for _, f in ipairs(mp.get_property_native("vf") or {}) do
        if is_rife(f) and f.enabled ~= false then
            return true
        end
    end
    return false
end

local function on(quiet)
    local vf = other_filters()
    vf[#vf + 1] = { name = "vapoursynth", label = "rife", enabled = true, params = { file = vpy } }
    mp.set_property_native("vf", vf)
    if not quiet then
        mp.osd_message("插帧: 开启")
    end
end

local function off()
    mp.set_property_native("vf", other_filters())
    mp.osd_message("插帧: 关闭")
end

local function toggle()
    if is_on() then
        off()
    else
        on()
    end
end

-- 菜单靠 user-data/rife 打勾。滤镜加载失败时 mpv 会自己把它删掉，勾也跟着去掉。
mp.observe_property("vf", "native", function()
    mp.set_property_native("user-data/rife", is_on())
end)

mp.add_key_binding(nil, "toggle", toggle)

if not is_on() then
    on(true)
end
