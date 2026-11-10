local _, ns = ...
local CONFIG, DEFAULTS = ns.CONFIG, ns.DEFAULTS
local PartColor = ns.GetPartColor
local bars = {}; ns.Bars = bars
local ApplySettings, ApplyColor
local function GetQueueWindow() return ns.GetQueueMs() / 1000 end
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

local function PaintNeon(bar)
    if not bar.neonRing then return end
    local c = ns.Theme.Accent()
    bar.neonRing:SetVertexColor(c.r, c.g, c.b, 0.48)
    bar.neonGlow:SetVertexColor(c.r, c.g, c.b, CONFIG.glowIntensity)
    bar.neonGlow:SetShown(CONFIG.showGlow)
    if CONFIG.showGlow and CONFIG.pulseGlow then
        if not bar.neonAnimation:IsPlaying() then bar.neonAnimation:Play() end
    else
        bar.neonAnimation:Stop()
        bar.neonGlow:SetAlpha(1)
    end
    bar.neonBack:SetVertexColor(0.018, 0.027, 0.047, CONFIG.backgroundOpacity)
    if bar.fill then bar.fill:SetAlpha(CONFIG.fillOpacity) end
    bar.neonStripe:SetColorTexture(c.r,c.g,c.b,0.9)
    if bar.progressEdge then bar.progressEdge:SetColorTexture(c.r,c.g,c.b,0.9) end
end

ApplyColor = function(bar)
    PaintNeon(bar)
    if NeonCastDB and NeonCastDB.useThemeColor and NeonCastDB.accent then
        local c = NeonCastDB.accent
        SetGradientStops(bar, { { c.r, c.g, c.b } })
        return
    end
    SetGradientStops(bar, ns.Spells.Colors(bar.spellName, bar.spellID))
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
    if bar.progressEdge then bar.progressEdge:SetShown(not bar.failed and width > 1) end
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
    bar.latencyPx = CONFIG.showLatency and bar.castLatency and pixels(bar.castLatency) or 0

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
    bar.latencyDisplay = nil
end

local function UpdateValue(bar, now)
    if bar.latencyText and CONFIG.showLatencyText then
        ns.CastLatency.UpdateText(bar, bar.castLatency)
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

local function GetPixelPos(unit)
    local saved = NeonCastDB and ns.Profiles.Position()
    if saved then return saved.x, saved.y end
    local p, px = CONFIG.point[unit], PixelSize(UIParent)
    return math.floor(p[4] / px + 0.5), math.floor(ns.Profiles.DefaultY() / px + 0.5)
end

local function SetPixelPos(x, y)
    ns.Profiles.SetPosition(x, y)
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
        bar.neonStripe:SetWidth(2)
        local animation = bar.neonGlow:CreateAnimationGroup()
        bar.neonAnimation = animation
        animation:SetLooping("BOUNCE")
        local pulse = animation:CreateAnimation("Alpha")
        pulse:SetFromAlpha(0.62)
        pulse:SetToAlpha(1)
        pulse:SetDuration(1.8)
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

    local reflection=bar:CreateTexture(nil,"ARTWORK",nil,-1)
    reflection:SetPoint("TOPLEFT",bar,"TOPLEFT",0,0);reflection:SetPoint("TOPRIGHT",bar,"TOPRIGHT",0,0)
    reflection:SetHeight(1);reflection:SetColorTexture(1,1,1,0.07)

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
    bar.progressEdge=bar.overlay:CreateTexture(nil,"ARTWORK",nil,3)
    bar.progressEdge:SetWidth(1)
    bar.progressEdge:SetPoint("TOP",bar.fill,"TOPRIGHT",0,0)
    bar.progressEdge:SetPoint("BOTTOM",bar.fill,"BOTTOMRIGHT",0,0)
    bar.progressEdge:SetColorTexture(0.2,0.82,1,0.9)
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
    bar:SetScript("OnUpdate", function(self) ns.Cast.OnUpdate(self) end)
    bar:SetScript("OnHide", function(hiddenBar) ns.CastLatency.ClearText(hiddenBar) end)
    bar:Hide()
    return bar
end

------------------------------------------------------------------------
-- Moving the bar and changing its settings (the options window is in Options.lua)
------------------------------------------------------------------------
-- A frozen, half-filled bar to preview settings and to grab while the bar is unlocked.
local function ShowDemo(bar)
    bar.active, bar.fading, bar.failed = false, false, nil
    bar.castLatency = 0.052
    bar:SetAlpha(1)
    bar.spellID, bar.spellName, bar.channel, bar.castID = nil, nil, false, nil
    bar.total = 3
    bar.startTime = GetTime() - bar.total * 0.72 -- 72% filled, so it does not land on a tick
    bar.endTime = bar.startTime + bar.total
    bar.lastStr = nil
    PaintNeon(bar)
    SetName(bar, ns.L.previewName)
    if NeonCastDB and NeonCastDB.useThemeColor and NeonCastDB.accent then
        local c = NeonCastDB.accent
        SetGradientStops(bar, {{c.r, c.g, c.b}})
    else
        SetGradientStops(bar, ns.Spells.ColorsForMask(20)) -- Fire + Frost
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
        ns.Cast.Refresh(bar) -- show a cast already in progress, if any
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
    if bar and (bar.unlocked or false) ~= unlocked then SetLocked(bar, not unlocked) end
end

function ns.GetPosition()
    return GetPixelPos("player")
end

function ns.SetPosition(x, y)
    SetPixelPos(x, y)
    local bar = bars.player
    if bar then
        SnapBar(bar, bar.unit)
        if bar.unlocked then ShowDemo(bar) end -- the text's pixel rounding depends on where the bar is
    end
end


ns.Bar = {
    PixelSize = PixelSize, SetTicks = SetTicks, SetGradientStops = SetGradientStops,
    ApplyColor = ApplyColor, SetFillWidth = SetFillWidth, SetSafeZone = SetSafeZone,
    ApplyLatencyStyle = ApplyLatencyStyle, UpdateValue = UpdateValue, SetName = SetName,
    EnsurePixelGrid = EnsurePixelGrid, ApplySettings = ApplySettings, Create = CreateBar,
    EnableDragging = EnableDragging, GetPixelPos = GetPixelPos, ShowDemo = ShowDemo,
}

-- Appearance changes can be inspected while a real cast is running or in preview.
function ns.Redraw()
    local bar = bars.player
    if bar then
        if bar.unlocked then ShowDemo(bar) else ApplyColor(bar) end
    end
end
