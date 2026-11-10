local _, ns = ...
local CONFIG = {
    units   = { "player" },
    width   = 240,
    height  = 21,
    point   = {
        player = { "CENTER", UIParent, "CENTER", 0, -300 },
    },
    tickColor = "white", -- tick markers (a PALETTE key, see below)
    tickWidth = 1,
    textPadding = 4, -- distance (in UI units) of the name/time text from the bar's left/right edge
    textOffsetY = 0, -- extra vertical shift of the name/time text, on top of the automatic centering (positive = up)
    timeReserve = 32, -- width reserved on the right for the time, so long spell names get cut before reaching it
    textGap = 0, -- empty space (in pixels) kept around the text where ticks are cut
    borderSize  = 2, -- border thickness in physical screen pixels (0 = no border)
    borderColor = "black",
    cardPadding = 9, iconScale = 1, glowIntensity = 0.72, fillOpacity = 0.32, backgroundOpacity = 0.94,
    showGlow = true, pulseGlow = true,
    showLatencyText = true, latencyFontSize = 11, latencyTextColor = "white",
    showIcon = true, -- spell icon to the left of the bar, sharing the bar's left border
    showQueue = true, -- draw the spell queue window zone at the end of the cast
    showLatency = true, -- draw the measured cast response zone
    queueColor   = "red", -- spell queue window zone
    latencyColor = "white", -- measured cast response zone
    fadeTime  = 1, -- seconds the bar takes to fade out after a cast ends (0 = no fade)
    failColor = { 1, 0.1, 0.1 }, -- the bar's color when a cast is interrupted or fails
    stretchMaxColors = 6, -- spells with more colors than this (e.g. a 7-school Chaos) use a fixed gradient instead of stretching
}

-- Font size of the name and time text. The default is the game's own size for this font, so the default look
-- matches the game's.
CONFIG.fontSize = math.floor((tonumber((select(2, GameFontHighlight:GetFont()))) or 12) + 0.5)
-- The bar must be at least this much taller than the font size, so the text fits inside it.
local FONT_ROOM = 3

-- The settings the options window can change, with their allowed ranges { min, max, step }.
-- They are saved in NeonCastDB.config, and the values above are the defaults.
local LIMITS = {
    latencyFontSize = { 8, 24, 1 },
    cardPadding = { 3, 22, 1 },
    iconScale = { 0.5, 1.5, 0.05 },
    glowIntensity = { 0, 1, 0.05 },
    fillOpacity = { 0, 1, 0.05 },
    backgroundOpacity = { 0.2, 1, 0.05 },
    width      = { 160, 480, 1 },
    height     = { 11, 42, 1 },
    fontSize   = { 8, 24, 1 },
    tickWidth  = { 0, 3, 1 },
    borderSize = { 0, 4, 1 },
    fadeTime   = { 0, 2, 0.1 },
}
local TOGGLES = { "showIcon", "showQueue", "showLatency", "showGlow", "pulseGlow", "showLatencyText" }

-- The colors the options offer for the zones, ticks and border. None is close to a school color, so these
-- parts never blend into the bar's fill. `only` limits an entry to some parts: dark colors are hard to see as a
-- zone on the bar's dark background, and black is only used for the border.
local PALETTE = {
    -- In rainbow order (red to violet, darker before brighter within a hue), then white and black.
    { key = "darkred",   name = "Dark red",   0.5, 0.0, 0.0, only = { tickColor = true, borderColor = true } },
    { key = "red",       name = "Red",        1.0, 0.0, 0.0 },
    { key = "olive",     name = "Olive",      0.5, 0.5, 0.0 },
    { key = "darkgreen", name = "Dark green", 0.0, 0.5, 0.0, only = { tickColor = true, borderColor = true } },
    { key = "teal",      name = "Teal",       0.0, 0.5, 0.5 },
    { key = "azure",     name = "Azure",      0.0, 0.5, 1.0 },
    { key = "navy",      name = "Navy",       0.0, 0.1, 0.5, only = { tickColor = true, borderColor = true } },
    { key = "blue",      name = "Blue",       0.0, 0.0, 1.0 },
    { key = "rose",      name = "Rose",       1.0, 0.0, 0.5 },
    { key = "white",     name = "White",      1.0, 1.0, 1.0 },
    { key = "black",     name = "Black",      0.0, 0.0, 0.0, only = { borderColor = true } },
}
local PALETTE_BY_KEY = {}
for _, e in ipairs(PALETTE) do PALETTE_BY_KEY[e.key] = e end

-- The parts whose color can be picked, in the options' order, with their fixed opacity. A color is the palette
-- entry together with that opacity, so two parts can only clash when their opacities match (the two zones).
local COLOR_PARTS = { "queueColor", "latencyColor", "tickColor", "borderColor", "latencyTextColor" }
local COLOR_ALPHA = { queueColor = 0.4, latencyColor = 0.4, tickColor = 0.9, borderColor = 1, latencyTextColor = 1 }

local DEFAULTS = {}
for key in pairs(LIMITS) do DEFAULTS[key] = CONFIG[key] end
for _, key in ipairs(TOGGLES) do DEFAULTS[key] = CONFIG[key] end
for _, key in ipairs(COLOR_PARTS) do DEFAULTS[key] = CONFIG[key] end

-- r, g, b, a of a part's current color.
local function PartColor(part)
    local selected = CONFIG[part]
    if type(selected) == "table" then
        return selected.r, selected.g, selected.b, COLOR_ALPHA[part]
    end
    local e = PALETTE_BY_KEY[selected] or PALETTE_BY_KEY[DEFAULTS[part]]
    return e[1], e[2], e[3], COLOR_ALPHA[part]
end

-- Pairs of palette entries too alike to sit next to each other at the same opacity (the two zones).
local SIMILAR = {
    azure = { teal = true }, teal = { azure = true },
    red = { rose = true }, rose = { red = true },
}

-- The other part already showing this palette entry, or one too alike to it, at the same opacity; or nil.
-- The second value is true when the other part's color is only alike, not the same.
local function ColorTakenBy(part, key)
    for _, other in ipairs(COLOR_PARTS) do
        local k = CONFIG[other]
        if other ~= part and k and COLOR_ALPHA[other] == COLOR_ALPHA[part] then
            if k == key then return other, false end
            if SIMILAR[key] and SIMILAR[key][k] then return other, true end
        end
    end
end

-- True when `part` may use palette entry `key`: it exists, is offered for that part, and no other part has it.
local function ColorUsable(part, key)
    if type(key) == "table" then
        for _, channel in ipairs({"r", "g", "b"}) do
            local value = key[channel]
            if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return false end
        end
        return COLOR_ALPHA[part] ~= nil
    end
    local e = PALETTE_BY_KEY[key]
    if not e or (e.only and not e.only[part]) then return false end
    return not ColorTakenBy(part, key)
end

-- A setting's allowed range right now: the height and the font size limit each other, so the text always fits
-- inside the bar. With `alone`, that link is left out (used while loading, before both are known).
local function Range(key, alone)
    local lim = LIMITS[key]
    local lo, hi = lim[1], lim[2]
    if alone then return lo, hi end
    if key == "fontSize" then hi = math.min(hi, CONFIG.height - FONT_ROOM) end
    if key == "height" then lo = math.max(lo, CONFIG.fontSize + FONT_ROOM) end
    return lo, hi
end

-- Rounds a number setting to its step and keeps it inside its range.
local function Clamp(key, value, alone)
    local lim = LIMITS[key]
    if not lim then return value end
    local lo, hi = Range(key, alone)
    local step = lim[3]
    value = tonumber(value)
    if not value or value ~= value or math.abs(value) == math.huge then value = DEFAULTS[key] end
    value = math.floor(value / step + 0.5) * step
    value = math.max(lo, math.min(hi, value))
    return tonumber(string.format("%.2f", value)) -- trims float noise such as 0.30000000000000004
end

------------------------------------------------------------------------
local function GetQueueMs()
    local ms
    if C_CVar and C_CVar.GetCVar then
        ms = tonumber(C_CVar.GetCVar("SpellQueueWindow"))
    elseif GetCVar then
        ms = tonumber(GetCVar("SpellQueueWindow"))
    end
    return ms or 0
end

local function SetQueueMs(ms)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("SpellQueueWindow", ms)
    elseif SetCVar then
        SetCVar("SpellQueueWindow", ms)
    end
end

ns.CONFIG, ns.LIMITS, ns.DEFAULTS = CONFIG, LIMITS, DEFAULTS
ns.Range, ns.Clamp = Range, Clamp
ns.PALETTE, ns.COLOR_PARTS, ns.COLOR_ALPHA = PALETTE, COLOR_PARTS, COLOR_ALPHA
ns.ColorTakenBy, ns.ColorUsable, ns.GetPartColor = ColorTakenBy, ColorUsable, PartColor
ns.GetQueueMs, ns.SetQueueMs = GetQueueMs, SetQueueMs
