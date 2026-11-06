-- ChromaCast
-- A cast bar colored by spell school, with the spell icon, elapsed and remaining time, channel tick markers,
-- spell queue and latency zones, and a fade-out. Works on Classic Era and WoW Forever.

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
    cardPadding = 9, iconScale = 1, glowIntensity = 0.95, fillOpacity = 0.22, backgroundOpacity = 0.96,
    showGlow = true, pulseGlow = true,
    showLatencyText = true, latencyFontSize = 11, latencyTextColor = "white",
    showIcon = true, -- spell icon to the left of the bar, sharing the bar's left border
    showQueue = true, -- draw the spell queue window zone at the end of the cast
    showLatency = true, -- draw the world latency zone at the end of the cast
    queueColor   = "red", -- spell queue window zone
    latencyColor = "white", -- world latency zone
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
    value = tonumber(value) or DEFAULTS[key]
    value = math.floor(value / step + 0.5) * step
    value = math.max(lo, math.min(hi, value))
    return tonumber(string.format("%.2f", value)) -- trims float noise such as 0.30000000000000004
end

------------------------------------------------------------------------
-- School colors (school masks: 1 physical, 2 holy, 4 fire, 8 nature,
-- 16 frost, 32 shadow, 64 arcane)
------------------------------------------------------------------------
local SCHOOL_COLOR = {
    [1]  = { 1.00, 1.00, 0.00 },
    [2]  = { 1.00, 0.90, 0.50 },
    [4]  = { 1.00, 0.50, 0.00 },
    [8]  = { 0.30, 1.00, 0.30 },
    [16] = { 0.50, 1.00, 1.00 },
    [32] = { 0.50, 0.50, 1.00 },
    [64] = { 1.00, 0.50, 1.00 },
}
local DEFAULT_COLOR = { 0.70, 0.70, 0.70 }
local SCHOOL_BITS = { 1, 2, 4, 8, 16, 32, 64 }

-- Returns a list of colors, one per school in the mask, lowest school first
local function ColorsForMask(mask)
    if not mask then return { DEFAULT_COLOR } end
    local solid = SCHOOL_COLOR[mask]
    if solid then return { solid } end
    local list = {}
    for _, bit in ipairs(SCHOOL_BITS) do
        if mask % (bit * 2) >= bit then
            list[#list + 1] = SCHOOL_COLOR[bit]
        end
    end
    if #list == 0 then return { DEFAULT_COLOR } end
    return list
end

local SCHOOL_NAMES, TICK_NAMES = ns.SCHOOL_NAMES, ns.TICK_NAMES
local HIDDEN_CASTS = ns.HIDDEN_CASTS

-- Schools learned from the combat log at runtime (Classic Era), by spell name.
local learned = {}

local function TickCount(name, total)
    local info = TICK_NAMES[name]
    if not info then return 0 end
    if info.ticks then return info.ticks end
    if info.interval and total > 0 then
        return math.floor(total / info.interval + 0.5)
    end
    return 0
end

------------------------------------------------------------------------
-- Secret values (Forever): another unit's cast info can come
-- back secret. If it does, that bar simply stays hidden.
------------------------------------------------------------------------
local function Plain(...)
    if not issecretvalue then return true end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end

------------------------------------------------------------------------
-- Bars
------------------------------------------------------------------------
local bars = {}

-- Size of one physical screen pixel, in this frame's own units.
local function PixelSize(frame)
    local _, physH = GetPhysicalScreenSize()
    local scale = frame:GetEffectiveScale()
    if not physH or physH == 0 or not scale or scale == 0 then return 1 end
    return (768 / physH) / scale
end

-- Left edge of tick marker i of count (i = 1 is the first tick, at the right), on a whole pixel. A channel drains
-- from the right, so the fill's edge reaches this point when tick i lands.
local function TickX(w, i, count, px)
    return math.floor(w * (1 - i / count) / px + 0.5) * px
end

local function SetTicks(bar, count)
    if CONFIG.tickWidth <= 0 then count = 0 end -- tick width 0 turns the markers off

    local w, h = bar:GetWidth(), bar:GetHeight()
    local px = PixelSize(bar)
    local tickW = math.max(1, math.floor(CONFIG.tickWidth + 0.5)) * px

    -- Areas covered by the name (left) and the time (right), measured at their widest.
    -- UpdateValue rewrites the time text right after this runs.
    local pad, gap = CONFIG.textPadding, CONFIG.textGap
    bar.measure:SetFormattedText("%.1f", bar.total)
    local timeW = bar.measure:GetStringWidth()
    local rects = {}
    if count > 1 then
        local text = bar.nameText:GetText() or ""
        local fullW, shownW = bar.nameText:GetStringWidth(), bar.nameText:GetWidth()
        if text == "" or fullW > shownW then
            -- Empty, or cut short with "...": treat the whole name as one block.
            rects[1] = { pad - gap, pad + math.min(fullW, shownW) + gap }
        else
            -- One area per word, so a tick that falls in the space between two words is not cut.
            -- Each word's start and end come from measuring the text up to it.
            local m = bar.measure
            m:SetText("x")
            local xW = m:GetStringWidth()
            local pos = 1
            while true do
                local s, e = string.find(text, "%S+", pos)
                if not s then break end
                m:SetText(string.sub(text, 1, s - 1) .. "x")
                local startX = m:GetStringWidth() - xW
                m:SetText(string.sub(text, 1, e))
                local endX = m:GetStringWidth()
                rects[#rects + 1] = { pad + startX - gap, pad + endX + gap }
                pos = e + 1
            end
        end
    end
    rects[#rects + 1] = { w - pad - timeW - gap, w - pad + gap }
    local sh = math.max(bar.nameText:GetStringHeight(), bar.timeText:GetStringHeight())
    -- The text's bottom edge sits at bar.textY (set in SetName), so these are the tick pieces above and below it.
    local topH = h - (bar.textY + sh + gap)   -- tick piece above the text
    local botH = bar.textY - gap              -- tick piece below the text

    for i = 1, math.max(count - 1, 0) do
        local t, t2 = bar.ticks[i], bar.ticks2[i]
        if not t then
            t = bar.overlay:CreateTexture(nil, "ARTWORK", nil, 2)
            t:SetColorTexture(PartColor("tickColor"))
            bar.ticks[i] = t
            t2 = bar.overlay:CreateTexture(nil, "ARTWORK", nil, 2)
            t2:SetColorTexture(PartColor("tickColor"))
            bar.ticks2[i] = t2
        end
        local t3 = bar.ticks3[i]
        if not t3 then
            t3 = bar.overlay:CreateTexture(nil, "ARTWORK", nil, 2)
            t3:SetColorTexture(PartColor("tickColor"))
            bar.ticks3[i] = t3
        end
        t3:ClearAllPoints()
        t3:Hide()

        local x = TickX(w, i, count, px)

        t:SetWidth(tickW)
        t:ClearAllPoints()
        t2:SetWidth(tickW)
        t2:ClearAllPoints()

        local hit = false
        for _, r in ipairs(rects) do
            if x + tickW > r[1] and x < r[2] then
                hit = true
                break
            end
        end

        -- A tick centered in the space between two words keeps a 1-pixel line through the text's height.
        -- The line sits on the free pixel nearest the tick, and when there is room it stays one pixel
        -- away from each word.
        local mid
        if hit then
            local cx = x + tickW / 2
            for k = 1, #rects - 1 do
                local gl, gr = rects[k][2], rects[k + 1][1]
                if cx >= gl and cx <= gr then
                    local first = math.ceil(gl / px - 0.001)
                    local last = math.floor(gr / px + 0.001) - 1
                    if last - first >= 2 then first, last = first + 1, last - 1 end
                    local p = math.floor(cx / px)
                    if last >= first then p = math.max(first, math.min(last, p)) end
                    mid = { p * px, (p + 1) * px }
                    break
                end
            end
        end

        if hit then
            if mid then
                bar.ticks3[i]:SetWidth(mid[2] - mid[1])
                bar.ticks3[i]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", mid[1], math.max(botH, 0))
                bar.ticks3[i]:SetPoint("TOPLEFT", bar, "TOPLEFT", mid[1], -math.max(topH, 0))
                bar.ticks3[i]:Show()
            end
            if topH > 0 then
                t:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
                t:SetHeight(topH)
                t:Show()
            else
                t:Hide()
            end
            if botH > 0 then
                t2:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
                t2:SetHeight(botH)
                t2:Show()
            else
                t2:Hide()
            end
        else
            t:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
            t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
            t:Show()
            t2:Hide()
        end
    end

    for i = math.max(count, 1), #bar.ticks do
        bar.ticks[i]:Hide()
        bar.ticks2[i]:Hide()
        if bar.ticks3[i] then bar.ticks3[i]:Hide() end
    end
end

-- Horizontal gradient from color a to color b (same color twice = solid).
-- Newer clients take color objects, older ones take plain numbers.
local function SetGradient(tex, a, b)
    if CreateColor then
        local ok = pcall(tex.SetGradient, tex, "HORIZONTAL",
            CreateColor(a[1], a[2], a[3], 1), CreateColor(b[1], b[2], b[3], 1))
        if ok then return end
    end
    pcall(tex.SetGradient, tex, "HORIZONTAL", a[1], a[2], a[3], b[1], b[2], b[3])
end

-- Turns a color list into positioned stops (0 = left edge, 1 = right edge).
-- 1-2 colors run edge to edge; 3+ colors each own a 1/n band, centered in it.
local function ColorStops(colors)
    local n = #colors
    if n == 1 then return { { 0, colors[1] }, { 1, colors[1] } } end
    if n == 2 then return { { 0, colors[1] }, { 1, colors[2] } } end
    local stops = { { 0, colors[1] } }
    for i = 1, n do
        stops[#stops + 1] = { (i - 0.5) / n, colors[i] }
    end
    stops[#stops + 1] = { 1, colors[n] }
    return stops
end

-- Positions each gradient segment. Stretching bars lay the segments out
-- across the current fill width; the others across the full bar, with the
-- fill just revealing them.
local function LayoutSegments(bar, w)
    local stops = bar.stops
    if not stops then return end
    local anchor, span = bar, bar:GetWidth()
    if bar.stretch then anchor, span = bar.fill, w end
    for i = 1, #stops - 1 do
        for _, s in ipairs({ bar.segs[i], bar.segs2[i] }) do
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", anchor, "TOPLEFT", stops[i][1] * span, 0)
            s:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", stops[i + 1][1] * span, 0)
        end
    end
end

-- One gradient texture per segment between stops, in each of the two fill parts (fillClip and fillLow).
local function SetGradientStops(bar, colors)
    local stops = ColorStops(colors)
    bar.stops = stops
    bar.stretch = #colors <= CONFIG.stretchMaxColors
    for _, part in ipairs({ { bar.segs, bar.fillClip }, { bar.segs2, bar.fillLow } }) do
        local segs, parent = part[1], part[2]
        for i = 1, #stops - 1 do
            local s = segs[i]
            if not s then
                s = parent:CreateTexture(nil, "ARTWORK")
                s:SetColorTexture(1, 1, 1, 1)
                segs[i] = s
            end
            SetGradient(s, stops[i][2], stops[i + 1][2])
            s:Show()
        end
        for i = #stops, #segs do
            segs[i]:Hide()
        end
    end
    LayoutSegments(bar, bar.fill:GetWidth())
end

local ApplyColor

-- Automatic school detection: read the spell's own description and take the
-- school word that appears first ("... dealing 1,234 Nature damage").
local SCHOOL_WORDS
local SCHOOL_BY_SCAN = {} -- spellID -> mask, or false when no school word was found
local pendingLoad = {}

local function BitCount(m)
    local n = 0
    while m > 0 do
        n = n + m % 2
        m = math.floor(m / 2)
    end
    return n
end

local function SchoolString(mask)
    if C_Spell and C_Spell.GetSchoolString then
        return C_Spell.GetSchoolString(mask)
    end
    if GetSchoolString then
        return GetSchoolString(mask)
    end
end

local function BuildWords()
    SCHOOL_WORDS = {}
    -- Every named multi-school combination (Shadowflame, Frostfire, Spellfire,
    -- Chaos, Magic, ...), with the name taken from the client. Combinations
    -- containing physical are skipped (their names, like Flamestrike, clash
    -- with spell names), except Chaos (127). Listed first so they win ties.
    for mask = 3, 127 do
        if BitCount(mask) >= 2 and (mask % 2 == 0 or mask == 127) then
            local name = SchoolString(mask)
            if type(name) == "string" and name ~= "" and name ~= "Unknown" and name ~= UNKNOWN then
                SCHOOL_WORDS[#SCHOOL_WORDS + 1] = { word = name, mask = mask }
            end
        end
    end
    local fallback = { [0] = "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }
    for i = 0, 6 do
        local w = _G["SPELL_SCHOOL" .. i .. "_CAP"]
        if type(w) ~= "string" or w == "" then w = fallback[i] end
        SCHOOL_WORDS[#SCHOOL_WORDS + 1] = { word = w, mask = 2 ^ i }
    end
end

local function GetDescription(id)
    if C_Spell and C_Spell.GetSpellDescription then
        return C_Spell.GetSpellDescription(id)
    end
    if GetSpellDescription then
        return GetSpellDescription(id)
    end
end

-- Position of "<word> damage" (any capitalization of "damage"), or nil.
local function FindPhrase(desc, word, suffix)
    local init = 1
    while true do
        local pos = string.find(desc, word, init, true)
        if not pos then return nil end
        local after = string.sub(desc, pos + #word, pos + #word + #suffix - 1)
        if string.lower(after) == suffix then return pos end
        init = pos + 1
    end
end

local function ScanDescription(desc)
    if type(desc) ~= "string" or desc == "" then return nil end
    if issecretvalue and issecretvalue(desc) then return nil end
    if not SCHOOL_WORDS then BuildWords() end

    -- Look for "Shadowflame damage", "Nature damage", "Chaos damage", ...
    local dmg = (type(DAMAGE) == "string" and DAMAGE ~= "") and DAMAGE or "Damage"
    local suffix = " " .. string.lower(dmg)
    local bestPos, bestMask
    for _, s in ipairs(SCHOOL_WORDS) do
        local pos = FindPhrase(desc, s.word, suffix)
        if pos and (not bestPos or pos < bestPos) then
            bestPos, bestMask = pos, s.mask
        end
    end
    if bestMask then return bestMask end

    -- Other languages often write school and damage as one word (e.g. "Frostschaden"),
    -- so there fall back to finding the school name anywhere in the text.
    local locale = GetLocale and GetLocale()
    if locale ~= "enUS" and locale ~= "enGB" then
        for _, s in ipairs(SCHOOL_WORDS) do
            local pos = string.find(desc, s.word, 1, true)
            if pos and (not bestPos or pos < bestPos) then
                bestPos, bestMask = pos, s.mask
            end
        end
    end
    return bestMask
end

local function SchoolFromDescription(id)
    local cached = SCHOOL_BY_SCAN[id]
    if cached ~= nil then return cached or nil end

    local desc = GetDescription(id)
    if type(desc) == "string" and desc ~= "" then
        local mask = ScanDescription(desc)
        SCHOOL_BY_SCAN[id] = mask or false
        return mask
    end

    -- Description data not loaded yet: ask for it and recolor when it arrives.
    if Spell and Spell.CreateFromSpellID and not pendingLoad[id] then
        pendingLoad[id] = true
        Spell:CreateFromSpellID(id):ContinueOnSpellLoad(function()
            pendingLoad[id] = nil
            local d = GetDescription(id)
            if type(d) == "string" and d ~= "" then
                SCHOOL_BY_SCAN[id] = ScanDescription(d) or false
                for _, b in pairs(bars) do
                    if b:IsShown() and b.spellID == id then ApplyColor(b) end
                end
            end
        end)
    end
    return nil
end

-- Theme color applies to the card independently of spell-school fill colors.
local function PaintNeon(bar)
    if not bar.neonRing then return end
    local c = NeonCastDB and NeonCastDB.accent or {r=0.67, g=0.83, b=0.45}
    bar.neonRing:SetVertexColor(c.r, c.g, c.b, 0.65)
    bar.neonGlow:SetVertexColor(c.r, c.g, c.b, CONFIG.glowIntensity)
    bar.neonGlow:SetShown(CONFIG.showGlow)
    if CONFIG.showGlow and CONFIG.pulseGlow then
        if not bar.neonAnimation:IsPlaying() then bar.neonAnimation:Play() end
    else
        bar.neonAnimation:Stop()
        bar.neonGlow:SetAlpha(1)
    end
    bar.neonBack:SetVertexColor(0.025, 0.03, 0.04, CONFIG.backgroundOpacity)
    if bar.fill then bar.fill:SetAlpha(CONFIG.fillOpacity) end
    bar.neonStripe:SetColorTexture(c.r, c.g, c.b, 1)
end

ApplyColor = function(bar)
    PaintNeon(bar)
    if NeonCastDB and NeonCastDB.useThemeColor and NeonCastDB.accent then
        local c = NeonCastDB.accent
        SetGradientStops(bar, { { c.r, c.g, c.b } })
        return
    end
    local id = bar.spellID
    local mask = SCHOOL_NAMES[bar.spellName]
        or learned[bar.spellName]
        or (id and SchoolFromDescription(id))
    SetGradientStops(bar, ColorsForMask(mask))
end

-- The game's spell queue window setting, in milliseconds.
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

-- Spell queue window, in seconds: how long before the end of a cast your next spell queues
-- instead of interrupting it.
local function GetQueueWindow()
    return GetQueueMs() / 1000
end

-- World latency, in seconds: roughly how long the server takes to see your next press.
local function GetLatency()
    local _, _, _, world = GetNetStats()
    return (world or 0) / 1000
end

-- Places the zones from bar.zoneSpans (set by SetSafeZone), each cut at `limit` pixels from the end of the cast.
local function PlaceZones(bar, limit)
    bar.zoneLimit = limit
    local side = bar.channel and "LEFT" or "RIGHT"
    local dir = bar.channel and 1 or -1
    for _, span in ipairs(bar.zoneSpans) do
        local tex, from, to = span[1], span[2], math.min(span[3], limit)
        tex:ClearAllPoints()
        if to <= from then
            tex:Hide()
        else
            tex:SetPoint("TOP" .. side, bar, "TOP" .. side, dir * from, 0)
            tex:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, dir * from, 0)
            tex:SetWidth(to - from)
            tex:Show()
        end
    end
end

-- Both zones at the end of the cast, the shorter one at the very end and the longer one continuing from where it
-- stops. Returns their total width.
local function EndZones(bar)
    local q, l = bar.queuePx, bar.latencyPx
    if q <= l then
        bar.zoneSpans = { { bar.queueZone, 0, q }, { bar.latencyZone, q, l } }
    else
        bar.zoneSpans = { { bar.latencyZone, 0, l }, { bar.queueZone, l, q } }
    end
    return math.max(q, l)
end

-- Left edge of the latency zone before a channel's next tick, for a fill this wide. nil when the next tick is the
-- channel's end (the zone then sits at the end).
local function NextTickZone(bar, width)
    local xs = bar.tickXs
    if not xs then return nil end
    for i = 1, #xs do
        if xs[i] < width then return xs[i] end
    end
    return nil
end

-- Lays out a channel's zones for the next tick at x (nil: the channel's end), and the gap left in the fill for them.
-- bar.fillLeft is the end zones' width; bar.gapLeft / bar.gapRight the latency zone's edges before a tick.
local function ChannelZones(bar, x)
    if x then
        local right = math.min(x + bar.latencyPx, bar:GetWidth())
        bar.zoneSpans = { { bar.queueZone, 0, bar.queuePx }, { bar.latencyZone, x, right } }
        bar.fillLeft, bar.gapLeft, bar.gapRight = bar.queuePx, x, right
        bar.zoneEnd = right
        local lowW = x - bar.fillLeft
        if lowW > 0 then
            bar.fillLow:ClearAllPoints()
            bar.fillLow:SetPoint("TOPLEFT", bar, "TOPLEFT", bar.fillLeft, 0)
            bar.fillLow:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", bar.fillLeft, 0)
            bar.fillLow:SetWidth(lowW)
            bar.fillLow:Show()
        else
            bar.fillLow:Hide()
        end
    else
        bar.fillLeft, bar.gapLeft, bar.gapRight = EndZones(bar), nil, nil
        bar.zoneEnd = bar.fillLeft
        bar.fillLow:Hide()
    end
    bar.zoneLimit = nil
end

-- Sets how much of the bar is filled, and the drawn part of it. On channels the fill leaves out the zones, so they
-- show on the bar's background (see CreateBar): the end zones (bar.fillLeft wide) and, before the last tick, the
-- latency zone before the next tick. The zones shrink with the fill once it drains into them.
local function SetFillWidth(bar, width)
    bar.fill:SetWidth(width)
    if not bar.channel or bar.failed then
        -- Casts: the fill covers the zones. Failed: the zones are hidden and the whole filled part turns red.
        bar.fillClip:SetWidth(math.max(width, 0.01))
        bar.fillLow:Hide()
        return
    end
    local key = NextTickZone(bar, width) or false
    if key ~= bar.zoneTick then
        bar.zoneTick = key
        ChannelZones(bar, key or nil)
    end
    -- fillClip draws from the zones' right edge to the fill's edge; fillLow between the end zones and the gap.
    bar.fillClip:SetWidth(math.max(width - (bar.gapRight or bar.fillLeft), 0.01))
    local limit = math.min(width, bar.zoneEnd)
    if limit ~= bar.zoneLimit then PlaceZones(bar, limit) end
end

-- Works out the zones, whole pixels wide. A zone that is switched off in the options simply gets no width.
-- Casts: both at the end (right edge). Channels: only the latency zone, at the end (left edge), except that on
-- channels with known ticks it sits just before the next tick until the last one. A move made once the fill is in
-- that zone reaches the server after the tick has landed, so the tick is kept. There is no queue zone on channels:
-- a spell pressed during a channel cancels it at once instead of queueing.
local function SetSafeZone(bar)
    local px = bar.px
    local function pixels(sec)
        local win = math.min(sec, bar.total)
        return math.floor(bar:GetWidth() * win / bar.total / px + 0.5) * px
    end
    bar.queuePx = (CONFIG.showQueue and not bar.channel) and pixels(GetQueueWindow()) or 0
    bar.latencyPx = CONFIG.showLatency and pixels(GetLatency()) or 0

    bar.tickXs = nil
    local count = bar.channel and bar.tickCount or 0
    if bar.latencyPx > 0 and count > 1 then
        bar.tickXs = {}
        for i = 1, count - 1 do bar.tickXs[i] = TickX(bar:GetWidth(), i, count, px) end
    end

    if bar.channel then
        bar.zoneTick = nil -- SetFillWidth lays them out, following the fill
    else
        EndZones(bar)
        PlaceZones(bar, math.huge)
        bar.fillLeft, bar.gapLeft, bar.gapRight = 0, nil, nil
    end
    SetFillWidth(bar, bar.fill:GetWidth())
end

-- The game draws text at an origin it rounds to a whole pixel. A text placed exactly on a pixel line sits on
-- the edge of that rounding, and the tiny float noise in the screen scale then tips it to one side or the
-- other from one height, one login or one cast to the next. Moving the text a quarter of a pixel off the line
-- (the same distance from the whole-pixel line and from the half-pixel line) makes the result always the same.
local TEXT_SHIFT = 0.25

local function ApplyLatencyStyle(bar)
    if not bar.latencyText then return end
    local fallback = GameFontHighlight:GetFont()
    local path = NeonCastDB and NeonCastDB.latencyFont or fallback
    local ok, applied = pcall(bar.latencyText.SetFont, bar.latencyText, path, CONFIG.latencyFontSize, "OUTLINE")
    if not ok or applied == false then bar.latencyText:SetFont(fallback, CONFIG.latencyFontSize, "OUTLINE") end
    bar.latencyText:SetTextColor(PartColor("latencyTextColor"))
    bar.latencyText:ClearAllPoints()
    bar.latencyText:SetPoint("LEFT", bar, "RIGHT", (bar.neonRing and CONFIG.cardPadding or 2) + 8, 0)
    bar.latencyText:SetShown(CONFIG.showLatencyText)
    bar.lastLatencyUpdate = nil
end

local function UpdateValue(bar, now)
    if bar.latencyText and CONFIG.showLatencyText and (not bar.lastLatencyUpdate or now - bar.lastLatencyUpdate >= 1) then
        local latency = GetLatency()
        if Plain(latency) then bar.latencyText:SetText(string.format("%d ms", math.floor(latency * 1000 + 0.5))) end
        bar.lastLatencyUpdate = now
    end
    local elapsed = now - bar.startTime
    if elapsed < 0 then elapsed = 0 end
    if elapsed > bar.total then elapsed = bar.total end
    local fraction = elapsed / bar.total
    if bar.channel then fraction = 1 - fraction end
    local width = math.max(bar:GetWidth() * fraction, 0.01)
    SetFillWidth(bar, width)
    if bar.stretch then LayoutSegments(bar, width) end
    local str = string.format("%.1f", bar.total - elapsed)
    if str ~= bar.lastStr then
        bar.lastStr = str
        bar.timeText:SetText(str)
        bar.timeOutline:SetText(str)
        -- Right-align by hand on a whole-pixel x, since the text's width changes with its digits.
        local px = bar.px
        local x = math.floor((bar:GetWidth() - CONFIG.textPadding - bar.timeText:GetStringWidth()) / px + 0.5) * px
        bar.timeText:ClearAllPoints()
        bar.timeText:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x + px * TEXT_SHIFT, bar.textY + px * TEXT_SHIFT)
        bar.timeOutline:ClearAllPoints()
        bar.timeOutline:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x + px * TEXT_SHIFT, bar.textY + px * TEXT_SHIFT)
    end
end

-- Turns the bar red with a word ("Interrupted", "Failed") and no time or ticks.
local function ShowFailed(bar, label)
    bar.failed = true -- SetFillWidth then draws the whole filled part (the zones are hidden below), in red
    SetFillWidth(bar, bar.progressWidth) -- keep what was already filled; only that part turns red
    SetGradientStops(bar, { CONFIG.failColor })
    bar.nameText:SetText(label)
    bar.nameOutline:SetText(label)
    bar.timeText:SetText("")
    bar.timeOutline:SetText("")
    bar.lastStr = nil
    SetTicks(bar, 0)
    bar.queueZone:Hide()
    bar.latencyZone:Hide()
end

-- Called when the unit has no cast or channel anymore. The bar fades out instead of hiding.
-- Interrupted and failed casts turn red first. A new cast replaces the fade at once (see Refresh).
local function EndCast(bar, event, castGUID)
    if not bar.active and not bar.fading then return end -- nothing was casting, so nothing to end

    -- Already fading as a finished cast: a late FAILED or INTERRUPTED event for the same cast turns it red.
    if not bar.active then
        if not bar.failed and (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED") then
            local sameCast
            if castGUID and bar.castID then
                sameCast = (castGUID == bar.castID)
            else
                sameCast = GetTime() - bar.fadeStart < 0.5 -- no cast IDs on this client: accept only right after the end
            end
            if sameCast then
                ShowFailed(bar, event == "UNIT_SPELLCAST_FAILED" and (FAILED or "Failed") or (INTERRUPTED or "Interrupted"))
            end
        end
        return
    end

    -- The cast just ended. Say why, if we know.
    local label
    if event == "UNIT_SPELLCAST_INTERRUPTED" then
        label = INTERRUPTED or "Interrupted"
    elseif event == "UNIT_SPELLCAST_FAILED" then
        label = FAILED or "Failed"
    elseif not bar.channel and GetTime() < bar.endTime - (0.25 + GetLatency()) then
        -- A cast that stopped well before its end and gave no reason was cancelled.
        label = INTERRUPTED or "Interrupted"
    end

    bar.progressWidth = bar.fill:GetWidth()
    bar.active = false
    bar.fading = true
    bar.fadeStart = GetTime()
    if label then
        ShowFailed(bar, label)
    else
        UpdateValue(bar, bar.endTime) -- show the final state: full for casts, empty for channels
    end
end

-- Sets the spell name and places both texts on whole pixels: bottom-anchored, with the offset
-- measured from the string's height.
local function SetName(bar, name)
    bar.nameText:SetText(name)
    bar.nameOutline:SetText(name)
    local px = bar.px
    -- bar.textY (how far the text sits above the bar's bottom edge) is worked out in SnapBar.
    local padX = math.floor(CONFIG.textPadding / px + 0.5) * px
    for _, fs in ipairs({ bar.nameText, bar.nameOutline }) do
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", padX + px * TEXT_SHIFT, bar.textY + px * TEXT_SHIFT)
    end
end

function ns.DisplayCastName(name, spellID)
    if spellID == 22810 or name == "Opening - No Text" then
        return (ns.L and ns.L.opening) or OPENING or "Opening"
    end
    return name
end

local Refresh
local ApplySettings
local StartPending

-- How long (seconds, plus latency) a hidden cast's bar stays full past its expected end, waiting for the spell to go off.
local HIDDEN_HOLD = 0.5

-- Width kept free on the right for the time, so long spell names get cut before reaching it.
-- It grows with the font size, matching CONFIG.timeReserve at the default size.
local function TimeReserve()
    return CONFIG.timeReserve * CONFIG.fontSize / DEFAULTS.fontSize
end

-- Gives every text on the bar the font size from the options. The outlined copies keep their outline.
local function ApplyFont(bar)
    local font, _, flags = GameFontHighlight:GetFont()
    for _, fs in ipairs({ bar.nameText, bar.timeText, bar.measure }) do
        fs:SetFont(font, CONFIG.fontSize, flags)
    end
    for _, fs in ipairs({ bar.nameOutline, bar.timeOutline }) do
        fs:SetFont(font, CONFIG.fontSize, "OUTLINE")
    end
    bar.lastStr = nil -- the time text is right-aligned by its width, so place it again
end

-- If the screen scale changed without any event we listen to, the bar's size and position are no longer
-- on whole pixels. This checks that when a cast starts and places the bar again if needed.
local function EnsurePixelGrid(bar)
    local px = PixelSize(bar)
    if math.abs(px - bar.px) > 0.0001 then
        bar.px = px
        ApplySettings(bar)
    end
end

local function OnUpdate(bar)
    if bar.unlocked then return end
    local now = GetTime()
    if bar.fading then
        local alpha = CONFIG.fadeTime > 0 and (1 - (now - bar.fadeStart) / CONFIG.fadeTime) or 0
        if alpha <= 0 then
            bar.fading = false
            bar:Hide()
            bar:SetAlpha(1)
        else
            bar:SetAlpha(alpha)
        end
        return
    end
    if bar.hiddenCast and now >= bar.endTime then
        -- The cast should be done. It ends when the spell goes off (OnSucceeded); until then the bar stays full,
        -- for a short while at most in case that never comes.
        if now >= bar.endTime + HIDDEN_HOLD + GetLatency() then
            bar.hiddenCast = nil
            Refresh(bar) -- no real cast is running, so this ends the bar and starts the fade
        else
            UpdateValue(bar, now)
        end
        return
    end
    if now >= bar.endTime + 0.1 then
        Refresh(bar)
        return
    end
    UpdateValue(bar, now)
end

Refresh = function(bar, event, castGUID)
    if bar.unlocked then return end
    local unit = bar.unit
    local name, startMS, endMS, channel, spellID, icon, castID

    local cName, _, cIcon, cStart, cEnd, _, cCastID, _, cID = UnitCastingInfo(unit)
    if cName then
        name, startMS, endMS, channel, spellID, icon, castID = cName, cStart, cEnd, false, cID, cIcon, cCastID
    else
        local chName, _, chIcon, chStart, chEnd, _, _, chID = UnitChannelInfo(unit)
        if chName then
            name, startMS, endMS, channel, spellID, icon = chName, chStart, chEnd, true, chID, chIcon
        end
    end

    if not name then
        if bar.hiddenCast and bar.active then return end -- a hidden cast runs on its own timer
        EndCast(bar, event, castGUID)
        StartPending(bar)
        return
    end
    if not Plain(name, startMS, endMS, spellID) or not startMS or not endMS or endMS <= startMS then
        bar.active, bar.fading = false, false
        bar:Hide()
        bar:SetAlpha(1)
        return
    end

    -- A cast is running: cancel any fade or red state left over from the previous one.
    bar.active = true
    bar.fading = false
    bar.failed = nil
    bar.hiddenCast = nil
    bar.castID = castID
    if bar.icon then bar.icon:SetTexture(icon) end
    bar:SetAlpha(1)

    if type(spellID) ~= "number" then spellID = nil end
    bar.spellID   = spellID
    bar.spellName = name
    bar.channel   = channel
    bar.startTime = startMS / 1000
    bar.endTime   = endMS / 1000
    bar.total     = bar.endTime - bar.startTime
    bar.lastStr = nil
    bar.tickCount = channel and TickCount(name, bar.total) or 0
    EnsurePixelGrid(bar)
    local progress = ns.CraftProgress.Label(spellID)
    local displayName = ns.DisplayCastName(name, spellID)
    SetName(bar, progress and (displayName .. " " .. progress) or displayName)
    SetSafeZone(bar)

    ApplyColor(bar)
    SetTicks(bar, bar.tickCount)
    UpdateValue(bar, GetTime())
    bar:Show()
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
end

-- The spell data in ChromaData.lua is keyed by English names. Each entry is also added under the client's own
-- name for that spell (from its ID in SPELL_IDS), so it matches on any client language, and after a rename.
-- An existing entry is never replaced.
local function AddLocalNames()
    for english, id in pairs(ns.SPELL_IDS or {}) do
        local ok, name = pcall(SpellName, id)
        if ok and type(name) == "string" and name ~= "" and name ~= english then
            for _, t in ipairs({ SCHOOL_NAMES, TICK_NAMES, HIDDEN_CASTS }) do
                if t[english] ~= nil and t[name] == nil then t[name] = t[english] end
            end
        end
    end
end

-- Draws a cast the game does not report (see HIDDEN_CASTS in ChromaData.lua), starting now.
local function ShowHiddenCast(bar, name, spellID, duration, castGUID)
    bar.active = true
    bar.fading = false
    bar.failed = nil
    bar.hiddenCast = true
    bar.pending = nil
    bar.castID = castGUID
    bar:SetAlpha(1)
    if bar.icon then bar.icon:SetTexture(SpellIcon(spellID)) end
    bar.spellID   = spellID
    bar.spellName = name
    bar.channel   = false
    bar.tickCount = 0
    bar.startTime = GetTime()
    bar.endTime   = bar.startTime + duration
    bar.total     = duration
    bar.lastStr = nil
    EnsurePixelGrid(bar)
    local progress = ns.CraftProgress.Label(spellID)
    local displayName = ns.DisplayCastName(name, spellID)
    SetName(bar, progress and (displayName .. " " .. progress) or displayName)
    SetSafeZone(bar)
    ApplyColor(bar)
    SetTicks(bar, 0)
    UpdateValue(bar, GetTime())
    bar:Show()
end

-- Ranged haste in percent (Classic Era: gear, Rapid Fire, quivers), or 0 where the client doesn't give it.
local function RangedHaste()
    if not GetRangedHaste then return 0 end
    local ok, h = pcall(GetRangedHaste)
    if ok and type(h) == "number" and Plain(h) and h > -100 then return h end
    return 0
end

-- A hidden cast's length in seconds: the game's cast time for the spell (entry true), or the entry's seconds when
-- the game lists it as instant, shortened by ranged haste. nil when neither is known.
-- On Classic Era, GetSpellInfo gives the cast time without haste (Aimed Shot: 3000 with or without Rapid Fire).
local function HiddenDuration(spellID, entry)
    local ms
    if GetSpellInfo then
        local ok, _, _, _, castTime = pcall(GetSpellInfo, spellID)
        if ok then ms = castTime end
    elseif C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then ms = info.castTime end
    end
    local base
    if type(ms) == "number" and Plain(ms) and ms > 0 then
        base = ms / 1000
    elseif type(entry) == "number" then
        base = entry
    end
    if not base then return nil end
    return base / (1 + RangedHaste() / 100)
end

-- UNIT_SPELLCAST_SENT: a hidden cast starts when the spell is sent. If a reported cast is still running (the spell
-- was queued), it starts when that cast ends.
local function OnSent(bar, castGUID, spellID)
    if not bar or bar.unlocked then return end
    if not Plain(castGUID, spellID) or type(spellID) ~= "number" then return end
    local name = SpellName(spellID)
    local entry = name and HIDDEN_CASTS[name]
    if not entry then return end
    local duration = HiddenDuration(spellID, entry)
    if not duration or duration <= 0 then return end
    if bar.active and not bar.hiddenCast then
        bar.pending = { name = name, spellID = spellID, duration = duration, castGUID = castGUID, sent = GetTime() }
        return
    end
    ShowHiddenCast(bar, name, spellID, duration, castGUID)
end

-- Starts a queued hidden cast once the cast before it has ended. A queued spell is sent at most one spell queue
-- window before that end; one sent longer ago than that (plus latency and some slack) is not coming anymore.
StartPending = function(bar)
    local p = bar.pending
    bar.pending = nil
    if p and GetTime() - p.sent < GetQueueWindow() + GetLatency() + 0.5 then
        ShowHiddenCast(bar, p.name, p.spellID, p.duration, p.castGUID)
    end
end

-- UNIT_SPELLCAST_SUCCEEDED: the hidden cast went off, so its bar ends now, full, however long it really took.
local function OnSucceeded(bar, castGUID)
    if not bar or bar.unlocked or not castGUID or not Plain(castGUID) then return end
    if bar.pending and bar.pending.castGUID == castGUID then bar.pending = nil end
    if not (bar.hiddenCast and bar.active and castGUID == bar.castID) then return end
    bar.hiddenCast = nil
    local now = GetTime()
    bar.endTime = now
    bar.total = math.max(now - bar.startTime, 0.01)
    EndCast(bar)
end

-- UNIT_SPELLCAST_INTERRUPTED / FAILED / FAILED_QUIET for a hidden cast (same cast GUID). Interrupted and failed turn
-- the bar red; a quiet failure means the spell never started, so the bar just goes away. True when handled.
local function OnHiddenStopped(bar, event, castGUID)
    if not bar or bar.unlocked or not castGUID or not Plain(castGUID) then return false end
    if bar.pending and bar.pending.castGUID == castGUID then
        bar.pending = nil
        return true
    end
    if not (bar.hiddenCast and bar.active and castGUID == bar.castID) then return false end
    bar.hiddenCast = nil
    if event == "UNIT_SPELLCAST_FAILED_QUIET" then
        bar.active, bar.fading = false, false
        bar:Hide()
        bar:SetAlpha(1)
    else
        EndCast(bar, event, castGUID)
    end
    return true
end

-- The bar's center, in whole screen pixels from the screen center: the saved position if there
-- is one, else CONFIG.point. Position is kept as whole pixels, so one step is exactly one pixel.
local function GetPixelPos(unit)
    local saved = NeonCastDB and NeonCastDB.pos
    if saved then return saved.x, saved.y end
    local p, px = CONFIG.point[unit], PixelSize(UIParent)
    return math.floor(p[4] / px + 0.5), math.floor(p[5] / px + 0.5)
end

local function SetPixelPos(x, y)
    NeonCastDB.pos = { x = x, y = y }
end

-- Sizes the bar in whole screen pixels and places its bottom-left corner on the pixel grid.
-- The bar is anchored to the screen's center, so it stays put if the screen size or scale
-- is not final yet when this runs (a toggled UI scale, or the moment after login).
-- The height of one line of the bar's text.
local function TextHeight(bar)
    local m = bar.measure
    if m then
        m:SetText("Ag")
        return m:GetStringHeight()
    end
    local _, size = GameFontHighlight:GetFont()
    return size or 12
end

-- The text is the anchor: its place on the screen comes from the saved Y alone, on whole pixels, and the bar
-- is placed around it, with the text centered in it. So changing the height never moves the text: the bar
-- grows and shrinks one pixel up, then one pixel down, then up again.
local function SnapBar(bar, unit)
    local px = PixelSize(bar)
    bar.px = px
    local function snap(v) return math.floor(v / px + 0.5) * px end
    local w, h = snap(CONFIG.width), snap(CONFIG.height)
    bar:SetSize(w, h)
    local x, y = GetPixelPos(unit)
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local sh = TextHeight(bar)
    -- A half pixel always rounds up: the tiny float noise in the screen scale would otherwise round it
    -- differently from one login to the next.
    local textBottom = math.floor((H / 2 + y * px - sh / 2) / px + 0.5 + 0.001) * px -- from the bottom of the screen
    -- Centered, then one pixel lower: with this font the letters sit high in their box, so the exact center looks too high.
    bar.textY = math.max(0, math.floor(((h - sh) / 2 + CONFIG.textOffsetY) / px + 0.5 + 0.001) - 1) * px -- from the bar's bottom edge
    local bottom = textBottom - bar.textY
    local left = snap(W / 2 + x * px - w / 2)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", left + w / 2 - W / 2, bottom + h / 2 - H / 2)
end

-- Border textures just outside the bar, a whole number of screen pixels thick.
-- With CONFIG.showIcon, the spell icon sits to the left of the bar and the bar's left border
-- is also the icon's right border; the top and bottom edges run across both.
local function CreateBorder(bar)
    local b = math.max(0, math.floor(CONFIG.borderSize + 0.5)) * PixelSize(bar)
    local h = bar:GetHeight()

    if CONFIG.showIcon and not bar.icon then
        bar.icon = bar:CreateTexture(nil, "ARTWORK")
        bar.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trims the icon's own edge
    end
    local iconOn = bar.icon and CONFIG.showIcon
    if bar.icon then
        bar.icon:SetShown(iconOn)
        bar.icon:ClearAllPoints()
        local iconSize = bar.neonRing and h * CONFIG.iconScale or h
        bar.icon:SetSize(iconSize, iconSize)
        bar.icon:SetPoint("RIGHT", bar, "LEFT", -b - (bar.neonRing and 3 or 0), 0)
    end

    if bar.neonRing then
        -- The dark card wraps both icon and progress instead of separating them.
        local left = iconOn and bar.icon or bar
        for _, texture in ipairs({bar.neonBack, bar.neonRing}) do
            texture:ClearAllPoints()
            local pad = CONFIG.cardPadding
            local extra = iconOn and math.max(0, (bar.icon:GetHeight() - h) / 2) or 0
            local top = iconOn and (pad + (h - bar.icon:GetHeight()) / 2 + extra) or pad
            texture:SetPoint("TOPLEFT", left, "TOPLEFT", iconOn and -14 or -pad, top)
            texture:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", pad, -pad - extra)
        end
        bar.neonGlow:ClearAllPoints()
        bar.neonGlow:SetPoint("TOPLEFT", bar.neonBack, "TOPLEFT", -12, 12)
        bar.neonGlow:SetPoint("BOTTOMRIGHT", bar.neonBack, "BOTTOMRIGHT", 12, -12)
        bar.neonStripe:ClearAllPoints()
        bar.neonStripe:SetPoint("TOPLEFT", bar.neonBack, "TOPLEFT", 5, -6)
        bar.neonStripe:SetPoint("BOTTOMLEFT", bar.neonBack, "BOTTOMLEFT", 5, 6)
        PaintNeon(bar)
        return
    end

    if not bar.border then
        bar.border = {}
        for i = 1, 5 do
            local t = bar:CreateTexture(nil, "BORDER")
            t:SetColorTexture(PartColor("borderColor"))
            bar.border[i] = t
        end
    end
    local top, bottom, left, right, iconLeft = unpack(bar.border)
    for _, t in ipairs(bar.border) do
        t:ClearAllPoints()
        t:SetShown(b > 0)
    end
    if b <= 0 then return end

    local leftRef = iconOn and bar.icon or bar -- the top and bottom edges start at the icon when there is one

    top:SetPoint("BOTTOMLEFT", leftRef, "TOPLEFT", -b, 0)
    top:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", b, 0)
    top:SetHeight(b)

    bottom:SetPoint("TOPLEFT", leftRef, "BOTTOMLEFT", -b, 0)
    bottom:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", b, 0)
    bottom:SetHeight(b)

    -- The bar's left border; with an icon, this is also the icon's right border.
    left:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, 0)
    left:SetWidth(b)

    right:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(b)

    -- The icon's own left border.
    if iconOn then
        iconLeft:SetPoint("TOPRIGHT", bar.icon, "TOPLEFT", 0, 0)
        iconLeft:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMLEFT", 0, 0)
        iconLeft:SetWidth(b)
    else
        iconLeft:Hide()
    end
end

local function CreateBar(unit)
    local bar = CreateFrame("Frame", "NeonCastBar_" .. unit, UIParent)
    SnapBar(bar, unit)
    bar.px = PixelSize(bar)

    -- Independently drawn nine-slice textures; no HunterSuite assets are required.
    local ring = bar:CreateTexture(nil, "BACKGROUND", nil, -5)
    if ring.SetTextureSliceMargins then
        bar.neonBack = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        bar.neonBack:SetTexture("Interface\\AddOns\\NeonCast\\Media\\NeonBack")
        bar.neonBack:SetTextureSliceMargins(16, 16, 16, 16)
        bar.neonBack:SetVertexColor(0.025, 0.03, 0.04, 0.96)
        bar.neonGlow = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
        bar.neonGlow:SetTexture("Interface\\AddOns\\NeonCast\\Media\\NeonGlow")
        bar.neonGlow:SetTextureSliceMargins(24, 24, 24, 24)
        bar.neonGlow:SetBlendMode("ADD")
        bar.neonRing = ring
        ring:SetTexture("Interface\\AddOns\\NeonCast\\Media\\NeonRing")
        ring:SetTextureSliceMargins(16, 16, 16, 16)
        if ring.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
            bar.neonBack:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            ring:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            bar.neonGlow:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
        bar.neonStripe = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        bar.neonStripe:SetWidth(3)
        local animation = bar.neonGlow:CreateAnimationGroup()
        bar.neonAnimation = animation
        animation:SetLooping("BOUNCE")
        local pulse = animation:CreateAnimation("Alpha")
        pulse:SetFromAlpha(0.45)
        pulse:SetToAlpha(1)
        pulse:SetDuration(0.8)
        pulse:SetSmoothing("IN_OUT")
        animation:Play()
    else
        ring:Hide()
    end

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.35)
    CreateBorder(bar)

    -- The fill is a frame that clips its gradient segments, so the bar only
    -- reveals more or less of them as the cast progresses.
    bar.fill = CreateFrame("Frame", nil, bar)
    bar.fill:SetClipsChildren(true)
    if bar.neonRing then bar.fill:SetAlpha(CONFIG.fillOpacity) end
    bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT")
    bar.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
    bar.fill:SetWidth(0.01)

    bar.segs = {}
    bar.segs2 = {}

    -- The segments are drawn inside fillClip, the fill's right part: the whole fill, except on channels, where it
    -- leaves out the zones (see SetFillWidth). A channel's fill starts full and drains toward its zones, so this
    -- keeps them visible on the bar's background from the start. Before a channel's last tick the latency zone
    -- sits in the middle of the fill; fillLow, with its own copy of the segments, draws the fill left of it.
    bar.fillClip = CreateFrame("Frame", nil, bar.fill)
    bar.fillClip:SetClipsChildren(true)
    bar.fillClip:SetPoint("TOPRIGHT", bar.fill, "TOPRIGHT")
    bar.fillClip:SetPoint("BOTTOMRIGHT", bar.fill, "BOTTOMRIGHT")
    bar.fillClip:SetWidth(0.01)
    bar.fillLow = CreateFrame("Frame", nil, bar.fill)
    bar.fillLow:SetClipsChildren(true)
    bar.fillLow:Hide()
    bar.fillLeft = 0

    -- Tick markers sit above the fill. The queue and latency zones sit below it,
    -- so the cast progress covers them.
    bar.overlay = CreateFrame("Frame", nil, bar)
    bar.overlay:SetAllPoints()
    bar.overlay:SetFrameLevel(bar:GetFrameLevel() + 3)
    bar.latencyText = bar.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ApplyLatencyStyle(bar)
    bar.queueZone = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar.queueZone:SetColorTexture(PartColor("queueColor"))
    bar.queueZone:Hide()
    bar.latencyZone = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar.latencyZone:SetColorTexture(PartColor("latencyColor"))
    bar.latencyZone:Hide()

    local pad = CONFIG.textPadding

    -- Plain text lives in a clipped frame covering only the unfilled part of the bar.
    bar.rest = CreateFrame("Frame", nil, bar)
    bar.rest:SetClipsChildren(true)
    bar.rest:SetPoint("TOPLEFT", bar.fill, "TOPRIGHT")
    bar.rest:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
    bar.rest:SetFrameLevel(bar:GetFrameLevel() + 5)

    bar.nameText = bar.rest:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.nameText:SetPoint("LEFT", bar, "LEFT", pad, CONFIG.textOffsetY)
    bar.nameText:SetWidth(bar:GetWidth() - 2 * pad - TimeReserve())
    bar.nameText:SetJustifyH("LEFT")
    bar.nameText:SetWordWrap(false)

    bar.timeText = bar.rest:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -pad, CONFIG.textOffsetY)
    bar.timeText:SetJustifyH("RIGHT")

    -- An invisible string used only to measure how wide the time text can get.
    bar.measure = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.measure:SetAlpha(0)

    -- Outlined copies live in their own clipped frame covering only the filled part of the bar,
    -- above the ticks, so the outline only shows over the fill.
    bar.textFill = CreateFrame("Frame", nil, bar)
    bar.textFill:SetClipsChildren(true)
    bar.textFill:SetPoint("TOPLEFT", bar, "TOPLEFT")
    bar.textFill:SetPoint("BOTTOMRIGHT", bar.fill, "BOTTOMRIGHT")
    bar.textFill:SetFrameLevel(bar:GetFrameLevel() + 5)

    local font = GameFontHighlight:GetFont()
    local tr, tg, tb = GameFontHighlight:GetTextColor()

    bar.nameOutline = bar.textFill:CreateFontString(nil, "OVERLAY")
    bar.nameOutline:SetFont(font, CONFIG.fontSize, "OUTLINE")
    bar.nameOutline:SetTextColor(tr, tg, tb)
    bar.nameOutline:SetPoint("LEFT", bar, "LEFT", pad, CONFIG.textOffsetY)
    bar.nameOutline:SetWidth(bar:GetWidth() - 2 * pad - TimeReserve())
    bar.nameOutline:SetJustifyH("LEFT")
    bar.nameOutline:SetWordWrap(false)

    bar.timeOutline = bar.textFill:CreateFontString(nil, "OVERLAY")
    bar.timeOutline:SetFont(font, CONFIG.fontSize, "OUTLINE")
    bar.timeOutline:SetTextColor(tr, tg, tb)
    bar.timeOutline:SetPoint("RIGHT", bar, "RIGHT", -pad, CONFIG.textOffsetY)
    bar.timeOutline:SetJustifyH("RIGHT")

    bar.unit  = unit
    bar.ticks = {}
    bar.ticks2 = {}
    bar.ticks3 = {}
    ApplyFont(bar)
    SnapBar(bar, unit) -- again now that the text exists, so its real height is used
    bar:SetScript("OnUpdate", OnUpdate)
    bar:Hide()
    return bar
end

------------------------------------------------------------------------
-- Moving the bar and changing its settings (the options window is in ChromaOptions.lua)
------------------------------------------------------------------------
-- A frozen, half-filled bar to preview settings and to grab while the bar is unlocked.
local function ShowDemo(bar)
    bar.active, bar.fading, bar.failed = false, false, nil
    bar:SetAlpha(1)
    bar.spellID, bar.spellName, bar.channel, bar.castID = nil, nil, false, nil
    bar.total = 3
    bar.startTime = GetTime() - bar.total * 0.72 -- 72% filled, so it does not land on a tick
    bar.endTime = bar.startTime + bar.total
    bar.lastStr = nil
    PaintNeon(bar)
    SetName(bar, "NeonCast - drag to move")
    if NeonCastDB and NeonCastDB.useThemeColor and NeonCastDB.accent then
        local c = NeonCastDB.accent
        SetGradientStops(bar, {{c.r, c.g, c.b}})
    else
        SetGradientStops(bar, ColorsForMask(20)) -- Fire + Frost
    end
    SetTicks(bar, 5) -- previews the tick width
    SetSafeZone(bar)
    if bar.icon then bar.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
    UpdateValue(bar, GetTime())
    bar:Show()
end

local function SetLocked(bar, locked)
    bar.unlocked = not locked
    bar:SetMovable(not locked)
    bar:EnableMouse(not locked)
    if locked then
        bar:Hide()
        bar:SetAlpha(1)
        Refresh(bar) -- show a cast already in progress, if any
    else
        ShowDemo(bar)
    end
end

-- Re-applies size, border, icon and the preview after a setting changed.
-- Re-colors the zones, every tick marker made so far, and the border.
local function ApplyPartColors(bar)
    bar.queueZone:SetColorTexture(PartColor("queueColor"))
    bar.latencyZone:SetColorTexture(PartColor("latencyColor"))
    for _, list in ipairs({ bar.ticks, bar.ticks2, bar.ticks3 }) do
        for _, t in pairs(list) do t:SetColorTexture(PartColor("tickColor")) end
    end
    if bar.border then
        for _, t in ipairs(bar.border) do t:SetColorTexture(PartColor("borderColor")) end
    end
end

function ApplySettings(bar)
    ApplyFont(bar) -- before SnapBar, which centers the text by its height
    ApplyPartColors(bar)
    SnapBar(bar, bar.unit)
    CreateBorder(bar)
    ApplyLatencyStyle(bar)
    local nameW = bar:GetWidth() - 2 * CONFIG.textPadding - TimeReserve()
    bar.nameText:SetWidth(nameW)
    bar.nameOutline:SetWidth(nameW)
    if bar.unlocked then ShowDemo(bar) end
end

-- The bar's X and Y in pixels while it is dragged. Y moves by the whole pixels the bar has moved since
-- the drag started, because Y belongs to the text and not to the bar's center.
local function DragPixelPos(bar)
    local cx, cy = bar:GetCenter()
    local px = bar.px
    local _, y0 = GetPixelPos(bar.unit)
    return math.floor((cx - UIParent:GetWidth() / 2) / px + 0.5),
           y0 + math.floor((cy - bar.dragCy0) / px + 0.5)
end

local function EnableDragging(bar)
    bar:SetClampedToScreen(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self)
        self.dragging = true
        local _, cy = self:GetCenter()
        self.dragCy0 = cy
        self:StartMoving()
    end)
    bar:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:StopMovingOrSizing()
        SetPixelPos(DragPixelPos(self))
        SnapBar(self, self.unit) -- re-place it on the pixel grid
        if self.unlocked then ShowDemo(self) end
        if ns.OnMoved then ns.OnMoved() end
    end)
end

-- What the options window uses.
ns.CONFIG, ns.LIMITS, ns.DEFAULTS = CONFIG, LIMITS, DEFAULTS
ns.GetQueueMs, ns.SetQueueMs = GetQueueMs, SetQueueMs
ns.Range = Range
ns.PALETTE, ns.COLOR_PARTS, ns.COLOR_ALPHA = PALETTE, COLOR_PARTS, COLOR_ALPHA
ns.ColorTakenBy, ns.ColorUsable, ns.GetPartColor = ColorTakenBy, ColorUsable, PartColor

function ns.GetBar()
    return bars.player
end

-- How many pixels the bar's center sits above the text's center, for the position limits in the options.
function ns.GetBarShift()
    local bar = bars.player
    if not bar then return 0 end
    return (bar:GetHeight() / 2 - bar.textY - TextHeight(bar) / 2) / bar.px
end

function ns.GetDragPixelPos(bar)
    return DragPixelPos(bar)
end

-- Unlocked = the bar shows a preview and can be dragged. Locked = it shows real casts.
function ns.SetUnlocked(unlocked)
    local bar = bars.player
    if bar then SetLocked(bar, not unlocked) end
end

function ns.GetPosition()
    return GetPixelPos("player")
end

-- True when every setting, the bar's position and the game's spell queue window are at their defaults.
function ns.IsDefault()
    for key, value in pairs(DEFAULTS) do
        if CONFIG[key] ~= value then return false end
    end
    local saved = NeonCastDB and NeonCastDB.pos
    if saved then
        local p, px = CONFIG.point.player, PixelSize(UIParent)
        if saved.x ~= math.floor(p[4] / px + 0.5) or saved.y ~= math.floor(p[5] / px + 0.5) then return false end
    end
    if NeonCastDB and (NeonCastDB.accent or NeonCastDB.useThemeColor or NeonCastDB.latencyFont) then return false end
    return GetQueueMs() == 400
end

function ns.SetPosition(x, y)
    SetPixelPos(x, y)
    local bar = bars.player
    if bar then
        SnapBar(bar, bar.unit)
        if bar.unlocked then ShowDemo(bar) end -- the text's pixel rounding depends on where the bar is
    end
end

function ns.SetSetting(key, value)
    if DEFAULTS[key] == nil then return end
    if type(DEFAULTS[key]) == "boolean" then
        value = (value == true)
    elseif COLOR_ALPHA[key] then
        if not ColorUsable(key, value) then return end -- not offered for this part, or another part has it
    else
        value = Clamp(key, value)
    end
    CONFIG[key] = value
    NeonCastDB.config[key] = value
    local bar = bars.player
    if bar then ApplySettings(bar) end
end

function ns.SetLatencyFont(path)
    if type(path) ~= "string" or #path > 512 then return end
    path = path:match("^%s*(.-)%s*$")
    NeonCastDB.latencyFont = path ~= "" and path or nil
    local bar = bars.player
    if bar then ApplyLatencyStyle(bar); if bar.unlocked then ShowDemo(bar) end end
end

-- Redraws the preview, for changes that are not in CONFIG (the game's spell queue window).
function ns.Redraw()
    local bar = bars.player
    if bar and bar.unlocked then ShowDemo(bar) end
end

function ns.RestoreDefaults()
    for key, value in pairs(DEFAULTS) do CONFIG[key] = value end
    NeonCastDB.config = {}
    NeonCastDB.pos = nil
    NeonCastDB.accent, NeonCastDB.useThemeColor, NeonCastDB.latencyFont = nil, nil, nil
    SetQueueMs(400) -- the game's default spell queue window
    local bar = bars.player
    if bar then ApplySettings(bar) end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
-- Hides Blizzard's own player cast bar so only ChromaCast's bar shows.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

local function HideDefaultCastBar()
    local f = PlayerCastingBarFrame or CastingBarFrame
    if not f then return end
    f:UnregisterAllEvents()
    f:SetParent(hiddenParent)
    f:Hide()
end

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_FAILED_QUIET",
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

-- Where the combat log is still open to addons (Classic Era), learn the
-- school of your own casts by spell name. Spell IDs are 0 there, names work.
local playerGUID

local function OnCombatLog()
    local _, sub, _, srcGUID = CombatLogGetCurrentEventInfo()
    if srcGUID ~= playerGUID then return end
    if sub ~= "SPELL_CAST_START" and sub ~= "SPELL_CAST_SUCCESS" then return end
    local spellName, school = select(13, CombatLogGetCurrentEventInfo())
    if type(spellName) ~= "string" or type(school) ~= "number" then return end
    if SCHOOL_NAMES[spellName] or learned[spellName] then return end -- the built-in list wins
    learned[spellName] = school
    local bar = bars.player
    if bar and bar:IsShown() and bar.spellName == spellName then
        ApplyColor(bar)
    end
end

frame:SetScript("OnEvent", function(_, event, unit, ...)
    local castGUID = ...
    if event == "PLAYER_LOGIN" then
        NeonCastDB = NeonCastDB or {}
        NeonCastDB.config = NeonCastDB.config or {}
        for key, value in pairs(NeonCastDB.config) do
            if DEFAULTS[key] ~= nil then
                if type(DEFAULTS[key]) == "boolean" then
                    CONFIG[key] = (value == true)
                elseif COLOR_ALPHA[key] then
                    CONFIG[key] = value -- checked below, once every part is loaded
                else
                    CONFIG[key] = Clamp(key, value, true)
                end
            end
        end
        -- Now that both are loaded, a font too big for the bar is brought down to fit.
        CONFIG.fontSize = Clamp("fontSize", CONFIG.fontSize)
        -- A saved color that is unknown, not offered for its part, or clashing with an earlier part goes back to
        -- the default, or to the first free entry if the default is taken.
        -- Parts are filled in one by one, so an earlier part keeps its color and a later one gives way.
        local fixed, saved = {}, {}
        for _, part in ipairs(COLOR_PARTS) do saved[part] = CONFIG[part] CONFIG[part] = nil end
        for _, part in ipairs(COLOR_PARTS) do
            local want = saved[part]
            if not ColorUsable(part, want) then
                want = DEFAULTS[part]
                if not ColorUsable(part, want) then
                    for _, e in ipairs(PALETTE) do
                        if ColorUsable(part, e.key) then want = e.key break end
                    end
                end
            end
            CONFIG[part] = want
            fixed[part] = want
        end
        for part, key in pairs(fixed) do
            if NeonCastDB.config[part] ~= nil then NeonCastDB.config[part] = key end
        end
        playerGUID = UnitGUID("player")
        AddLocalNames()
        -- Post-hooks only observe crafting requests; they never invoke protected actions.
        if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe and hooksecurefunc then
            pcall(hooksecurefunc, C_TradeSkillUI, "CraftRecipe", function(id, count)
                if issecretvalue and (issecretvalue(id) or issecretvalue(count)) then return end
                ns.CraftProgress.Begin(id, count)
                if bars.player and bars.player.active then Refresh(bars.player) end
            end)
        end
        HideDefaultCastBar()
        for _, u in ipairs(CONFIG.units) do
            bars[u] = CreateBar(u)
            EnableDragging(bars[u])
        end
        for _, ev in ipairs(CAST_EVENTS) do
            pcall(frame.RegisterUnitEvent, frame, ev, unpack(CONFIG.units))
        end
        if not issecretvalue then
            frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        end
        -- The UI scale and size can still change after login, which moves the pixel grid under the bar.
        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("UI_SCALE_CHANGED")
        frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
        for _, bar in pairs(bars) do Refresh(bar) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        -- Place the bar again from its saved pixel position, now that the screen size and scale are final.
        local function place()
            for _, bar in pairs(bars) do
                bar.px = PixelSize(bar)
                ApplySettings(bar)
            end
        end
        place()
        if C_Timer and C_Timer.After then C_Timer.After(0, place) end -- the size can settle a frame after the event
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog()
    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, sentGUID, spellID = ... -- target, castGUID, spellID
        OnSent(bars[unit], sentGUID, spellID)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, spellID = ...
        OnSucceeded(bars[unit], castGUID)
        if unit == "player" and not (issecretvalue and issecretvalue(spellID)) then ns.CraftProgress.Succeeded(spellID) end
    elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
        if unit == "player" then ns.CraftProgress.Reset() end
        OnHiddenStopped(bars[unit], event, castGUID)
    elseif bars[unit] then
        if unit == "player" and (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET") then ns.CraftProgress.Reset() end
        if (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
            and OnHiddenStopped(bars[unit], event, castGUID) then
            return
        end
        Refresh(bars[unit], event, castGUID)
    end
end)
