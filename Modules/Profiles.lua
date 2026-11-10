-- Saved-variable migration, shared appearance and independent input-mode geometry.
local _, ns = ...
local C, defaults = ns.CONFIG, ns.DEFAULTS
local P = { active = 'keyboard' }
ns.Profiles = P
local geometry = {width=true, height=true, fontSize=true, iconScale=true, showIcon=true, latencyFontSize=true}
local gamepad = {width=300, height=27, fontSize=16, latencyFontSize=14}
local function finite(n) return type(n) == 'number' and n == n and math.abs(n) < math.huge end
function P.DetectMode()
    if InputUtil and InputUtil.IsGamepadUIEnabled then
        return InputUtil.IsGamepadUIEnabled() and 'gamepad' or 'keyboard'
    end
    if C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and Enum and Enum.InputDeviceInterfaceType then
        return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad and 'gamepad' or 'keyboard'
    end
    return 'keyboard'
end
local function wantedMode()
    local mode = NeonCastDB.layoutMode
    return (mode == 'keyboard' or mode == 'gamepad') and mode or P.DetectMode()
end
function P.Default(key) return (P.active == 'gamepad' and gamepad[key]) or defaults[key] end
function P.DefaultY() return P.active == 'gamepad' and -180 or C.point.player[5] end
function P.Position()
    local pos = NeonCastDB.layouts[P.active].pos
    if type(pos) == 'table' and finite(pos.x) and finite(pos.y) then return pos end
end
function P.SetPosition(x, y)
    if finite(x) and finite(y) then NeonCastDB.layouts[P.active].pos = {x=math.floor(x+0.5), y=math.floor(y+0.5)} end
end
local function load()
    for key in pairs(defaults) do C[key] = P.Default(key) end
    local layout = NeonCastDB.layouts[P.active]
    for key, value in pairs(NeonCastDB.config) do
        if defaults[key] ~= nil and not geometry[key] then
            if type(defaults[key]) == 'boolean' then C[key] = value == true
            elseif not ns.COLOR_ALPHA[key] then C[key] = ns.Clamp(key, value, true) end
        end
    end
    local colors = {}
    for _, key in ipairs(ns.COLOR_PARTS) do
        colors[key] = NeonCastDB.config[key] or defaults[key]
        C[key] = nil
    end
    for _, key in ipairs(ns.COLOR_PARTS) do
        local value = colors[key]
        if not ns.ColorUsable(key, value) then value = defaults[key] end
        if not ns.ColorUsable(key, value) then
            for _, entry in ipairs(ns.PALETTE) do
                if ns.ColorUsable(key, entry.key) then value = entry.key; break end
            end
        end
        C[key] = value
    end
    for key in pairs(geometry) do
        local value = layout[key]
        if value ~= nil then
            if type(defaults[key]) == 'boolean' then C[key] = value == true
            else C[key] = ns.Clamp(key, value, true) end
        end
    end
    C.fontSize = ns.Clamp('fontSize', C.fontSize)
end
function P.Initialize()
    if type(NeonCastDB) ~= 'table' then NeonCastDB = {} end
    if type(NeonCastDB.config) ~= 'table' then NeonCastDB.config = {} end
    if type(NeonCastDB.layouts) ~= 'table' then
        NeonCastDB.layouts = {keyboard={}}
        local old = NeonCastDB.layouts.keyboard
        for key in pairs(geometry) do old[key] = NeonCastDB.config[key] end
        old.pos = NeonCastDB.pos
    end
    for _, mode in ipairs({'keyboard', 'gamepad'}) do
        if type(NeonCastDB.layouts[mode]) ~= 'table' then NeonCastDB.layouts[mode] = {} end
    end
    for key in pairs(geometry) do NeonCastDB.config[key] = nil end
    NeonCastDB.pos = nil
    if type(NeonCastDB.accent) ~= 'table' or not ns.ColorUsable('latencyTextColor', NeonCastDB.accent) then NeonCastDB.accent = nil end
    if type(NeonCastDB.latencyFont) ~= 'string' then NeonCastDB.latencyFont = nil end
    NeonCastDB.schemaVersion = 1
    P.active = wantedMode()
    load()
end
local function redraw()
    local bar = ns.GetBar and ns.GetBar()
    if bar then
        ns.Bar.ApplySettings(bar)
        if not bar.unlocked then ns.Cast.Refresh(bar) end
    end
end
function P.UpdateMode()
    if not NeonCastDB or not NeonCastDB.layouts then return end
    local nextMode = wantedMode()
    if P.active ~= nextMode then P.active = nextMode; load(); redraw() end
end
function P.SetMode(mode)
    if mode ~= 'auto' and mode ~= 'keyboard' and mode ~= 'gamepad' then return end
    NeonCastDB.layoutMode = mode
    P.UpdateMode()
end
function ns.SetSetting(key, value)
    if defaults[key] == nil then return end
    if type(defaults[key]) == 'boolean' then value = value == true
    elseif ns.COLOR_ALPHA[key] then if not ns.ColorUsable(key, value) then return end
    else value = ns.Clamp(key, value) end
    C[key] = value
    local target = geometry[key] and NeonCastDB.layouts[P.active] or NeonCastDB.config
    target[key] = value
    redraw()
end
function P.LargePreset()
    ns.SetSetting('height', 30)
    ns.SetSetting('fontSize', 18)
    ns.SetSetting('width', 320)
    ns.SetSetting('latencyFontSize', 16)
end
function ns.SetLatencyFont(path)
    if type(path) ~= 'string' or #path > 512 then return end
    path = path:match('^%s*(.-)%s*$')
    NeonCastDB.latencyFont = path ~= '' and path or nil
    redraw()
end
function ns.RestoreDefaults()
    NeonCastDB.config = {}
    NeonCastDB.layouts[P.active] = {}
    NeonCastDB.accent, NeonCastDB.useThemeColor, NeonCastDB.latencyFont = nil, nil, nil
    load(); redraw()
end
function ns.IsDefault()
    for key in pairs(defaults) do if C[key] ~= P.Default(key) then return false end end
    return not P.Position() and not NeonCastDB.accent and not NeonCastDB.useThemeColor and not NeonCastDB.latencyFont
end
