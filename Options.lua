-- ChromaCast options: the settings window and the minimap button.
-- Opening the window unlocks the bar so it can be dragged, and closing it locks the bar again.

local _, ns = ...
local CONFIG, LIMITS = ns.CONFIG, ns.LIMITS

local FRAME_W = 470
local ICON = "Interface\\AddOns\\NeonCast\\Icons\\ChromaCast"

local frame
local widgets = {}          -- everything that can re-read its value with :Refresh()
local queueRow, xRow, yRow, heightRow, fontRow
local resetButton
local colorRows = {}        -- picking a color in one row changes what the others may pick

local function Round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(v * m + 0.5) / m
end

-- "Restore defaults" is grayed out while everything is already at its default.
local function UpdateReset()
    if not resetButton then return end
    if ns.IsDefault() then resetButton:Disable() else resetButton:Enable() end
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
-- Shows a title and a wrapped description while the mouse is over any of `regions`, to the right of `owner`,
-- or level with `owner` but at the right edge of `alignTo` when given (so every tooltip opens at the window's edge).
-- HookScript keeps any OnEnter/OnLeave a template already has.
local function AddTooltip(owner, regions, title, text, alignTo)
    local function show()
        local dx = 0
        if alignTo then dx = (alignTo:GetRight() or 0) - (owner:GetRight() or 0) end
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", dx, 0)
        GameTooltip:AddLine(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end
    local function hide() GameTooltip:Hide() end
    for _, r in ipairs(regions) do
        r:HookScript("OnEnter", show)
        r:HookScript("OnLeave", hide)
    end
end

-- A row with a label, "-" and "+" buttons for single steps, a slider, and a box to type an exact value.
-- `tip` is the tooltip text, shown over the whole row.
local function MakeSlider(parent, y, text, min, max, step, decimals, get, set, tip)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_W, 24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    -- The row takes the mouse so the label shows the tooltip; a drag on it still moves the window.
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() if frame then frame:StartMoving() end end)
    row:SetScript("OnDragStop", function() if frame then frame:StopMovingOrSizing() end end)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 16, 0)
    label:SetWidth(130)
    label:SetJustifyH("LEFT")
    label:SetText(text)

    local function smallButton(text)
        local button = CreateFrame("Button", nil, row)
        local bg = button:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.16,0.18,0.21,1)
        local t = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("CENTER"); t:SetText(text)
        return button
    end
    local minus = smallButton("-")
    minus:SetSize(20, 20)
    minus:SetPoint("LEFT", row, "LEFT", 150, 0)

    local slider = CreateFrame("Slider", nil, row)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(124, 16)
    slider:SetPoint("LEFT", row, "LEFT", 176, 0)
    -- min and max can be numbers or functions, for ranges that change (the position limits).
    local function lo() if type(min) == "function" then return min() end return min end
    local function hi() if type(max) == "function" then return max() end return max end
    local function setRange() slider:SetMinMaxValues(lo(), hi()) end
    setRange()
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.25, 0.27, 0.34, 1)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    slider:GetThumbTexture():SetSize(8, 16)
    slider:GetThumbTexture():SetVertexColor(0.67, 0.83, 0.45, 1)

    local plus = smallButton("+")
    plus:SetSize(20, 20)
    plus:SetPoint("LEFT", row, "LEFT", 304, 0)

    local edit = CreateFrame("EditBox", nil, row)
    edit:SetFontObject(GameFontHighlightSmall)
    local editBg = edit:CreateTexture(nil, "BACKGROUND"); editBg:SetAllPoints(); editBg:SetColorTexture(0.035,0.04,0.05,1)
    edit:SetSize(44, 20)
    edit:SetPoint("LEFT", row, "LEFT", 336, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(6)
    edit:SetJustifyH("CENTER")

    local fmt = "%." .. decimals .. "f"
    local busy = false -- true while we move the slider from code, so that is not taken for a drag

    local function display(v)
        busy = true
        setRange()
        slider:SetValue(v)
        busy = false
        edit:SetText(string.format(fmt, v))
    end

    -- Rounds to the step, keeps the value in range, shows it, and passes it on.
    local function apply(v)
        v = Round(v / step, 0) * step
        v = Round(math.max(lo(), math.min(hi(), v)), decimals)
        display(v)
        set(v)
        UpdateReset()
    end

    slider:SetScript("OnValueChanged", function(_, v)
        if not busy then apply(v) end
    end)
    minus:SetScript("OnClick", function() apply(get() - step) end)
    plus:SetScript("OnClick", function() apply(get() + step) end)
    edit:SetScript("OnEnterPressed", function(self)
        local n = tonumber(self:GetText())
        if n then apply(n) end
        self:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", function() display(get()) end)

    if tip then AddTooltip(row, { row, minus, slider, plus, edit }, text, tip) end

    function row.Refresh() display(get()) end
    function row.Display(v) display(v) end
    function row.SetEnabled(on)
        row:SetAlpha(on and 1 or 0.4)
        slider:EnableMouse(on)
        minus:EnableMouse(on)
        plus:EnableMouse(on)
        edit:EnableMouse(on)
        if not on then edit:ClearFocus() end
    end

    return row
end

-- `tip` is the tooltip text, shown over the check box.
local function MakeCheck(parent, y, text, get, set, tip)
    local cb = CreateFrame("Button", nil, parent)
    cb:SetSize(38, 22)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 400, y)
    local track = cb:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    local knob = cb:CreateTexture(nil, "ARTWORK")
    knob:SetSize(14, 14)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y - 4)
    label:SetText(text)
    local function paint()
        local on = get() and true or false
        local c = NeonCastDB.accent or {r=0.67,g=0.83,b=0.45}
        if on then track:SetColorTexture(c.r,c.g,c.b,0.75) else track:SetColorTexture(0.22,0.24,0.28,1) end
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", cb, "LEFT", on and 20 or 4, 0)
        knob:SetColorTexture(0.95,0.96,0.97,1)
    end
    cb:SetScript("OnClick", function() set(not get()); paint(); UpdateReset() end)
    function cb.Refresh() paint() end
    if tip then AddTooltip(cb, { cb }, text, tip, parent) end
    return cb
end

-- How the tooltips name each part that has a color.
local PART_NAMES = {
    queueColor = "the queue zone", latencyColor = "the latency zone", tickColor = "the ticks", borderColor = "the border",
}

local function RefreshColors()
    for _, r in ipairs(colorRows) do r.Refresh() end
end

-- A row with a label and one square per palette color offered for `part`, drawn at that part's opacity over
-- the bar's own background. The chosen color has a gold frame; a color another part uses is faded and can't be
-- picked.
local function MakeColorRow(parent, y, text, part, tip)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_W, 20)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() if frame then frame:StartMoving() end end)
    row:SetScript("OnDragStop", function() if frame then frame:StopMovingOrSizing() end end)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 16, 0)
    label:SetWidth(130)
    label:SetJustifyH("LEFT")
    label:SetText(text)

    local swatches = {}
    local x = 150
    for _, e in ipairs(ns.PALETTE) do
        if not e.only or e.only[part] then
            local b = CreateFrame("Button", nil, row)
            b:SetSize(16, 16)
            b:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + 20
            b.edge = b:CreateTexture(nil, "BACKGROUND")
            b.edge:SetAllPoints()
            local back = b:CreateTexture(nil, "BORDER")
            back:SetPoint("TOPLEFT", 2, -2)
            back:SetPoint("BOTTOMRIGHT", -2, 2)
            back:SetColorTexture(0, 0, 0, 0.6) -- the bar's background
            local fill = b:CreateTexture(nil, "ARTWORK")
            fill:SetPoint("TOPLEFT", 2, -2)
            fill:SetPoint("BOTTOMRIGHT", -2, 2)
            fill:SetColorTexture(e[1], e[2], e[3], ns.COLOR_ALPHA[part])
            b.key = e.key
            b:SetScript("OnClick", function()
                if ns.ColorUsable(part, e.key) then
                    ns.SetSetting(part, e.key)
                    RefreshColors()
                    UpdateReset()
                end
            end)
            b:SetScript("OnEnter", function()
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:AddLine(e.name, 1, 1, 1)
                local by, similar = ns.ColorTakenBy(part, e.key)
                if by then
                    local why = similar and "Too close to the color of " or "Already used by "
                    GameTooltip:AddLine(why .. PART_NAMES[by] .. ".", 1, 0.3, 0.3, true)
                end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            swatches[#swatches + 1] = b
        end
    end

    function row.Refresh()
        for _, b in ipairs(swatches) do
            if CONFIG[part] == b.key then
                b.edge:SetColorTexture(1, 0.82, 0, 1)
            else
                b.edge:SetColorTexture(0.35, 0.38, 0.5, 1)
            end
            b:SetAlpha(ns.ColorTakenBy(part, b.key) and 0.25 or 1)
        end
    end

    if tip then AddTooltip(row, { row }, text, tip) end
    colorRows[#colorRows + 1] = row
    return row
end

local function RefreshAll()
    for _, w in ipairs(widgets) do w.Refresh() end
    if queueRow then queueRow.SetEnabled(CONFIG.showQueue) end
    UpdateReset()
end

-- How far the bar can be moved while everything stays on screen, in pixels from the screen center:
-- minX, maxX, minY, maxY. The spell icon counts when it is shown, so the slider stops at the icon.
local function PositionLimits()
    local bar = ns.GetBar()
    local px = bar.px
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local w, h = bar:GetWidth(), bar:GetHeight()
    local b = math.max(0, math.floor(CONFIG.borderSize + 0.5)) * px
    local shift = ns.GetBarShift() -- Y is where the text is, and the bar's center can sit above or below that
    local padding = CONFIG.cardPadding or b
    local left = padding
    if CONFIG.showIcon then left = h * (CONFIG.iconScale or 1) + b + 17 end
    local vertical = math.max(h, CONFIG.showIcon and h * (CONFIG.iconScale or 1) or h) / 2 + padding
    return math.ceil((-W / 2 + w / 2 + left) / px),
           math.floor((W / 2 - w / 2 - padding) / px),
           math.ceil((-H / 2 + vertical) / px - shift),
           math.floor((H / 2 - vertical) / px - shift)
end

-- Recomputes the limits and pulls the bar back inside them, after a change in size, border or icon.
local function RefreshPosition()
    local minX, maxX, minY, maxY = PositionLimits()
    local x, y = ns.GetPosition()
    local cx = math.max(minX, math.min(maxX, x))
    local cy = math.max(minY, math.min(maxY, y))
    if cx ~= x or cy ~= y then ns.SetPosition(cx, cy) end
    xRow.Refresh()
    yRow.Refresh()
    UpdateReset()
end

------------------------------------------------------------------------
-- The options window
------------------------------------------------------------------------
local function CreateOptions()
    local L = ns.L
    local f = CreateFrame("Frame", "NeonCastOptions", UIParent)
    f:SetSize(720, 560)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local function surface(parent, r, g, b, a)
        local t = parent:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        if t.SetTextureSliceMargins then
            t:SetTexture("Interface\\AddOns\\NeonCast\\Media\\NeonBack")
            t:SetTextureSliceMargins(16,16,16,16)
            if t.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
                t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            end
            t:SetVertexColor(r,g,b,a)
        else
            t:SetColorTexture(r,g,b,a)
        end
        return t
    end
    local function label(parent, text, font, x, y, color)
        local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        t:SetText(text)
        if color then t:SetTextColor(unpack(color)) end
        return t
    end
    surface(f, 0.045, 0.052, 0.065, 0.99)
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 0, 0); side:SetPoint("BOTTOMLEFT", 0, 0); side:SetWidth(174)
    surface(side, 0.027, 0.031, 0.041, 0.98)
    local brand = label(side, "NEON|cffffffffCAST|r", "GameFontNormalLarge", 20, -25)
    local small = label(side, L.subtitle, "GameFontNormalSmall", 20, -49, {0.54,0.58,0.64})
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    local title = label(f, L.appearance, "GameFontNormalLarge", 201, -24)
    local desc = label(f, L.description, "GameFontHighlightSmall", 201, -48, {0.57,0.61,0.66})
    local footer = label(side, L.version, "GameFontNormalSmall", 20, -518, {0.47,0.52,0.57})
    local pageFrames, navButtons = {}, {}
    local selected = 1
    local accentRegions = {brand, title}
    local function accent()
        local c = NeonCastDB.accent or {r=0.67,g=0.83,b=0.45}
        for _, t in ipairs(accentRegions) do t:SetTextColor(c.r,c.g,c.b) end
        for i, b in ipairs(navButtons) do
            b.marker:SetColorTexture(c.r,c.g,c.b, i == selected and 1 or 0)
            b.bg:SetColorTexture(c.r,c.g,c.b, i == selected and 0.13 or 0)
        end
    end
    local function page(name, index)
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", f, "TOPLEFT", 194, -77)
        p:SetSize(502, 454)
        if index ~= 1 then p:Hide() end
        pageFrames[index] = p
        local b = CreateFrame("Button", nil, side)
        b:SetSize(158, 38); b:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -92 - (index-1)*46)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
        b.marker = b:CreateTexture(nil, "ARTWORK"); b.marker:SetPoint("TOPLEFT", 0, -7); b.marker:SetPoint("BOTTOMLEFT", 0, 7); b.marker:SetWidth(3)
        local t = label(b, name, "GameFontHighlight", 16, -12)
        b:SetScript("OnClick", function()
            selected = index
            for i, panel in ipairs(pageFrames) do panel:SetShown(i == index) end
            title:SetText(name); accent()
        end)
        navButtons[index] = b
        return p
    end
    local appearance = page(L.appearance, 1)
    local layout = page(L.layout, 2)
    local behavior = page(L.behavior, 3)
    local function card(parent, top, height, heading)
        local c = CreateFrame("Frame", nil, parent)
        c:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, top); c:SetSize(502, height)
        surface(c, 0.078, 0.088, 0.105, 0.98)
        local h = label(c, heading, "GameFontNormalSmall", 16, -14, {0.65,0.70,0.75})
        local line = c:CreateTexture(nil, "BORDER")
        line:SetPoint("TOPLEFT", 16, -35); line:SetPoint("TOPRIGHT", -16, -35); line:SetHeight(1); line:SetColorTexture(1,1,1,0.06)
        return c
    end
    local function add(w) widgets[#widgets + 1] = w; return w end
    local function slider(c, y, key, caption)
        local lim = LIMITS[key]
        local decimals = lim[3] < 1 and 2 or 0
        return add(MakeSlider(c, y, caption, lim[1], lim[2], lim[3], decimals,
            function() return CONFIG[key] end,
            function(v)
                ns.SetSetting(key, v)
                if xRow and (key == "width" or key == "iconScale" or key == "cardPadding") then RefreshPosition() end
            end))
    end
    local colors = card(appearance, 0, 130, L.accentTitle)
    label(colors, L.presets, "GameFontHighlight", 16, -54)
    local palette = {{0.67,0.83,0.45}, {0.24,0.75,0.94}, {0.72,0.48,0.96}, {1,0.40,0.40}, {1,0.72,0.28}}
    local function choose(r,g,b)
        NeonCastDB.accent = {r=r,g=g,b=b}
        accent(); ns.Redraw(); RefreshAll()
    end
    for i, color in ipairs(palette) do
        local b = CreateFrame("Button", nil, colors)
        b:SetSize(24,24); b:SetPoint("TOPLEFT", colors, "TOPLEFT", 145 + (i-1)*32, -47)
        local sw = b:CreateTexture(nil, "ARTWORK"); sw:SetAllPoints(); sw:SetColorTexture(color[1],color[2],color[3],1)
        b:SetScript("OnClick", function() choose(color[1], color[2], color[3]) end)
    end
    local picker = CreateFrame("Button", nil, colors, "UIPanelButtonTemplate")
    picker:SetSize(110,24); picker:SetPoint("TOPLEFT", colors, "TOPLEFT", 320, -47); picker:SetText(L.chooseColor)
    picker:SetScript("OnClick", function()
        local c = NeonCastDB.accent or {r=0.67,g=0.83,b=0.45}
        local original = {r=c.r,g=c.g,b=c.b}
        local function apply() local r,g,b = ColorPickerFrame:GetColorRGB(); choose(r,g,b) end
        local function cancel() choose(original.r,original.g,original.b) end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({r=c.r,g=c.g,b=c.b,swatchFunc=apply,cancelFunc=cancel})
        else
            ColorPickerFrame.func = apply; ColorPickerFrame.cancelFunc = cancel
            ColorPickerFrame:SetColorRGB(c.r,c.g,c.b); ColorPickerFrame:Show()
        end
    end)
    local useTheme = add(MakeCheck(colors, -86, L.useTheme,
        function() return NeonCastDB.useThemeColor end,
        function(on) NeonCastDB.useThemeColor = on; ns.Redraw() end))
    local style = card(appearance, -142, 306, L.cardTitle)
    slider(style, -43, "cardPadding", L.cardPadding)
    slider(style, -75, "glowIntensity", L.glowIntensity)
    slider(style, -107, "fillOpacity", L.fillOpacity)
    slider(style, -139, "backgroundOpacity", L.backgroundOpacity)
    add(MakeCheck(style, -177, L.showGlow, function() return CONFIG.showGlow end, function(v) ns.SetSetting("showGlow",v) end))
    add(MakeCheck(style, -209, L.pulseGlow, function() return CONFIG.pulseGlow end, function(v) ns.SetSetting("pulseGlow",v) end))

    local geometry = card(layout, 0, 448, L.geometryTitle)
    slider(geometry, -43, "width", L.width)
    heightRow = add(MakeSlider(geometry, -75, L.height,
        function() return ns.Range("height") end, function() local _,hi=ns.Range("height"); return hi end, LIMITS.height[3], 0,
        function() return CONFIG.height end, function(v) ns.SetSetting("height",v); fontRow.Refresh(); RefreshPosition() end))
    fontRow = add(MakeSlider(geometry, -107, L.fontSize,
        function() return ns.Range("fontSize") end, function() local _,hi=ns.Range("fontSize"); return hi end, LIMITS.fontSize[3], 0,
        function() return CONFIG.fontSize end, function(v) ns.SetSetting("fontSize",v); heightRow.Refresh(); RefreshPosition() end))
    slider(geometry, -139, "iconScale", L.iconScale)
    add(MakeCheck(geometry, -175, L.icon, function() return CONFIG.showIcon end,
        function(v) ns.SetSetting("showIcon",v); RefreshPosition() end))
    xRow = add(MakeSlider(geometry, -218, L.x,
        function() return PositionLimits() end, function() local _,x=PositionLimits(); return x end, 1, 0,
        function() local x=ns.GetPosition(); return x end, function(v) local _,y=ns.GetPosition(); ns.SetPosition(v,y) end))
    yRow = add(MakeSlider(geometry, -250, L.y,
        function() local _,_,y=PositionLimits(); return y end, function() local _,_,_,y=PositionLimits(); return y end, 1, 0,
        function() local _,y=ns.GetPosition(); return y end, function(v) local x=ns.GetPosition(); ns.SetPosition(x,v) end))
    label(geometry, L.about, "GameFontHighlightSmall", 16, -300, {0.60,0.65,0.70})

    local casting = card(behavior, 0, 448, L.behaviorTitle)
    slider(casting, -43, "fadeTime", L.fade)
    slider(casting, -75, "tickWidth", L.tickWidth)
    add(MakeCheck(casting, -108, L.latency, function() return CONFIG.showLatency end, function(v) ns.SetSetting("showLatency",v) end))
    add(MakeCheck(casting, -140, L.queue, function() return CONFIG.showQueue end,
        function(v) ns.SetSetting("showQueue",v); queueRow.SetEnabled(v) end))
    queueRow = add(MakeSlider(casting, -175, L.queueWindow, 0, 400, 10, 0,
        function() return ns.GetQueueMs() end, function(v) ns.SetQueueMs(v); ns.Redraw(); queueRow.Display(ns.GetQueueMs()) end))
    add(MakeColorRow(casting, -215, L.queueColor, "queueColor"))
    add(MakeColorRow(casting, -245, L.latencyColor, "latencyColor"))
    add(MakeColorRow(casting, -275, L.tickColor, "tickColor"))

    local reset = CreateFrame("Button", nil, side, "UIPanelButtonTemplate")
    reset:SetSize(138, 26); reset:SetPoint("BOTTOM", side, "BOTTOM", 0, 45); reset:SetText(L.reset)
    resetButton = reset
    reset:SetScript("OnClick", function() ns.RestoreDefaults(); accent(); RefreshAll() end)
    AddTooltip(reset, {reset}, L.reset, L.resetHint)
    f:SetScript("OnUpdate", function()
        local b = ns.GetBar()
        if b and b.dragging then local x,y = ns.GetDragPixelPos(b); xRow.Display(x); yRow.Display(y) end
    end)
    f:SetScript("OnShow", function(self)
        self:ClearAllPoints(); self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        ns.SetUnlocked(true); accent(); RefreshAll()
    end)
    f:SetScript("OnHide", function() ns.SetUnlocked(false) end)
    tinsert(UISpecialFrames, "NeonCastOptions")
    accent()
    return f
end

function ns.OnMoved()
    if frame and frame:IsShown() then RefreshPosition() end
end

function ns.ToggleOptions()
    if not frame then frame = CreateOptions() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function PlaceMinimapButton(b)
    local saved = NeonCastDB and NeonCastDB.minimap
    local angle = math.rad((saved and saved.angle) or 215)
    local r = Minimap:GetWidth() / 2 + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function CreateMinimapButton()
    local b = CreateFrame("Button", "NeonCastMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture(ICON)
    icon:SetPoint("TOPLEFT", 7, -6)

    local overlay = b:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    b:SetScript("OnClick", function() ns.ToggleOptions() end)

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            NeonCastDB.minimap = NeonCastDB.minimap or {}
            NeonCastDB.minimap.angle = math.deg(atan2(cy / s - my, cx / s - mx))
            PlaceMinimapButton(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("NeonCast", 1, 1, 1)
        GameTooltip:AddLine("Click to open the options and move the bar.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag to move this button.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    PlaceMinimapButton(b)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    NeonCastDB = NeonCastDB or {}
    CreateMinimapButton()
end)

------------------------------------------------------------------------
-- Slash commands: /cc opens and closes the options (the same as the minimap button)
------------------------------------------------------------------------
SLASH_NEONCAST1 = "/neoncast"
SLASH_NEONCAST2 = "/nc"
SlashCmdList["NEONCAST"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "reset" then
        ns.RestoreDefaults()
        if frame then RefreshAll() end
        print("|cff33ff99NeonCast|r: defaults restored.")
    else
        ns.ToggleOptions()
    end
end
