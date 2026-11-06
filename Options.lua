-- ChromaCast options: the settings window and the minimap button.
-- Opening the window unlocks the bar so it can be dragged, and closing it locks the bar again.

local _, ns = ...
local CONFIG, LIMITS = ns.CONFIG, ns.LIMITS

local FRAME_W, FRAME_H = 392, 646
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
    row:SetScript("OnDragStart", function() parent:StartMoving() end)
    row:SetScript("OnDragStop", function() parent:StopMovingOrSizing() end)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 16, 0)
    label:SetWidth(130)
    label:SetJustifyH("LEFT")
    label:SetText(text)

    local minus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    minus:SetSize(20, 20)
    minus:SetPoint("LEFT", row, "LEFT", 150, 0)
    minus:SetText("-")

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
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(18, 18)

    local plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    plus:SetSize(20, 20)
    plus:SetPoint("LEFT", row, "LEFT", 304, 0)
    plus:SetText("+")

    local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
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
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    label:SetText(text)
    -- The label is part of the button: hovering it shows the tooltip and clicking it toggles the box.
    cb:SetHitRectInsets(0, -(label:GetStringWidth() + 4), 0, 0)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        UpdateReset()
    end)
    function cb.Refresh() cb:SetChecked(get()) end
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
    row:SetScript("OnDragStart", function() parent:StartMoving() end)
    row:SetScript("OnDragStop", function() parent:StopMovingOrSizing() end)

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
    local left = b -- the bar's left border
    if CONFIG.showIcon then left = left + h + b end -- the icon is as wide as the bar is tall, plus its own left border
    return math.ceil((-W / 2 + w / 2 + left) / px),
           math.floor((W / 2 - w / 2 - b) / px),
           math.ceil((-H / 2 + h / 2 + b) / px - shift),
           math.floor((H / 2 - h / 2 - b) / px - shift)
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
    local f = CreateFrame("Frame", "NeonCastOptions", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.043, 0.047, 0.055, 0.97)
    local function edge(p1, p2, w, h)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.18, 0.19, 0.23, 1)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("NeonCast")

    title:SetTextColor(0.67, 0.83, 0.45)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)

    local function add(w) widgets[#widgets + 1] = w return w end
    local L = LIMITS

    add(MakeSlider(f, -44, ns.L.width, L.width[1], L.width[2], L.width[3], 0,
        function() return CONFIG.width end,
        function(v) ns.SetSetting("width", v) RefreshPosition() end,
        "Length of the cast bar. The spell icon is added to its left and is not counted."))
    -- Height and font size limit each other (the text must fit in the bar), so their ranges are read live.
    heightRow = add(MakeSlider(f, -72, ns.L.height,
        function() return (ns.Range("height")) end,
        function() local _, hi = ns.Range("height") return hi end, L.height[3], 0,
        function() return CONFIG.height end,
        function(v) ns.SetSetting("height", v) fontRow.Refresh() RefreshPosition() end,
        "Thickness of the cast bar. The spell icon is always as tall as the bar, and the text stays in place. It can't go lower than the font size allows."))
    fontRow = add(MakeSlider(f, -100, ns.L.fontSize,
        function() return (ns.Range("fontSize")) end,
        function() local _, hi = ns.Range("fontSize") return hi end, L.fontSize[3], 0,
        function() return CONFIG.fontSize end,
        function(v) ns.SetSetting("fontSize", v) heightRow.Refresh() RefreshPosition() end,
        "Size of the spell name and time. The text stays centered in the bar, and the largest size depends on the bar's height."))
    add(MakeSlider(f, -128, ns.L.tickWidth, L.tickWidth[1], L.tickWidth[2], L.tickWidth[3], 0,
        function() return CONFIG.tickWidth end,
        function(v) ns.SetSetting("tickWidth", v) end,
        "Width of the markers that split channeled spells into their ticks. 0 hides them."))
    add(MakeSlider(f, -156, ns.L.border, L.borderSize[1], L.borderSize[2], L.borderSize[3], 0,
        function() return CONFIG.borderSize end,
        function(v) ns.SetSetting("borderSize", v) RefreshPosition() end,
        "Thickness of the black border around the bar and the icon, in screen pixels. 0 removes it."))
    add(MakeSlider(f, -184, ns.L.fade, L.fadeTime[1], L.fadeTime[2], L.fadeTime[3], 1,
        function() return CONFIG.fadeTime end,
        function(v) ns.SetSetting("fadeTime", v) end,
        "Seconds the bar takes to fade out after a cast ends, is interrupted or fails. 0 hides it at once."))

    add(MakeCheck(f, -218, ns.L.icon,
        function() return CONFIG.showIcon end,
        function(on)
            ns.SetSetting("showIcon", on)
            RefreshPosition()
        end,
        "Shows the spell's icon to the left of the bar."))
    add(MakeCheck(f, -246, ns.L.latency,
        function() return CONFIG.showLatency end,
        function(on) ns.SetSetting("showLatency", on) end,
        "Shades the end of the cast by your world latency: roughly how long the server takes to see your next key press."))
    add(MakeCheck(f, -274, ns.L.queue,
        function() return CONFIG.showQueue end,
        function(on)
            ns.SetSetting("showQueue", on)
            queueRow.SetEnabled(on)
        end,
        "Shades the end of the cast by the spell queue window: a spell pressed in that zone waits for the cast to finish instead of failing. Not shown on channels: a spell pressed during a channel cancels it."))
    -- This one changes the game's own SpellQueueWindow setting, not just the drawing.
    queueRow = add(MakeSlider(f, -302, ns.L.queueWindow, 0, 400, 10, 0,
        function() return ns.GetQueueMs() end,
        function(v)
            ns.SetQueueMs(v)
            ns.Redraw()
            local actual = ns.GetQueueMs()
            if actual ~= v then queueRow.Display(actual) end -- the game kept a different value
        end,
        "Changes the game's own Spell Queue Window setting, not just the drawing: how early a spell can be pressed before the current cast ends. Game default: 400 ms."))

    add(MakeColorRow(f, -334, ns.L.queueColor, "queueColor",
        "Color of the spell queue zone. Since the two zones sit side by side, it can't be the latency zone's color or one too close to it."))
    add(MakeColorRow(f, -358, ns.L.latencyColor, "latencyColor",
        "Color of the latency zone. Since the two zones sit side by side, it can't be the queue zone's color or one too close to it."))
    add(MakeColorRow(f, -382, ns.L.tickColor, "tickColor",
        "Color of the tick markers on channeled spells."))
    add(MakeColorRow(f, -406, ns.L.borderColor, "borderColor",
        "Color of the border around the bar and the icon."))

    xRow = add(MakeSlider(f, -446, ns.L.x,
        function() local minX = PositionLimits() return minX end,
        function() local _, maxX = PositionLimits() return maxX end, 1, 0,
        function() local x = ns.GetPosition() return x end,
        function(v) local _, y = ns.GetPosition() ns.SetPosition(v, y) end,
        "Horizontal position of the bar, in screen pixels from the center of the screen. You can also drag the bar while this window is open."))
    yRow = add(MakeSlider(f, -474, ns.L.y,
        function() local _, _, minY = PositionLimits() return minY end,
        function() local _, _, _, maxY = PositionLimits() return maxY end, 1, 0,
        function() local _, y = ns.GetPosition() return y end,
        function(v) local x = ns.GetPosition() ns.SetPosition(x, v) end,
        "Vertical position of the bar's text, in screen pixels from the center of the screen. You can also drag the bar while this window is open."))

    local useTheme
    local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reset:SetSize(150, 24)
    reset:SetPoint("TOP", f, "TOP", 0, -516)
    reset:SetText(ns.L.reset)
    resetButton = reset
    reset:SetScript("OnClick", function()
        ns.RestoreDefaults()
        title:SetTextColor(0.67, 0.83, 0.45)
        if useTheme then useTheme:SetChecked(false) end
        RefreshAll()
    end)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Restore defaults", 1, 1, 1)
        GameTooltip:AddLine("Resets every setting here, the bar's position, and the game's spell queue window (400 ms).", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", f, "TOP", 0, -550)
    hint:SetText(ns.L.hint)

    local themeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    themeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -580)
    themeLabel:SetText(ns.L.theme)
    local picker = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    picker:SetSize(110, 22)
    picker:SetPoint("TOPLEFT", f, "TOPLEFT", 145, -576)
    picker:SetText(ns.L.chooseColor)
    picker:SetScript("OnClick", function()
        local c = NeonCastDB.accent or { r = 0.67, g = 0.83, b = 0.45 }
        local function apply()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            NeonCastDB.accent = {r=r, g=g, b=b}
            title:SetTextColor(r, g, b)
            ns.Redraw()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({r=c.r,g=c.g,b=c.b,swatchFunc=apply})
        else
            ColorPickerFrame.func = apply
            ColorPickerFrame:SetColorRGB(c.r,c.g,c.b)
            ColorPickerFrame:Show()
        end
    end)
    local presets = { {0.67,0.83,0.45}, {0.24,0.75,0.94}, {0.72,0.48,0.96} }
    for i, color in ipairs(presets) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(20, 20)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 270 + (i - 1) * 26, -577)
        local swatch = b:CreateTexture(nil, "ARTWORK")
        swatch:SetAllPoints()
        swatch:SetColorTexture(color[1], color[2], color[3], 1)
        b:SetScript("OnClick", function()
            NeonCastDB.accent = {r=color[1], g=color[2], b=color[3]}
            title:SetTextColor(color[1], color[2], color[3])
            ns.Redraw()
        end)
    end
    useTheme = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    useTheme:SetSize(24,24)
    useTheme:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -606)
    useTheme:SetChecked(NeonCastDB.useThemeColor)
    local useThemeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    useThemeText:SetPoint("LEFT", useTheme, "RIGHT", 4, 0)
    useThemeText:SetText(ns.L.useTheme)
    useTheme:SetScript("OnClick", function(self)
        NeonCastDB.useThemeColor = self:GetChecked() and true or false
        NeonCastDB.accent = NeonCastDB.accent or {r=0.67,g=0.83,b=0.45}
        ns.Redraw()
    end)
    -- Live X and Y while the bar is being dragged.
    f:SetScript("OnUpdate", function()
        local b = ns.GetBar()
        if b and b.dragging then
            local x, y = ns.GetDragPixelPos(b)
            xRow.Display(x)
            yRow.Display(y)
        end
    end)

    f:SetScript("OnShow", function(self)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- opens centered, but can be dragged away
        ns.SetUnlocked(true)
        local c = NeonCastDB.accent or {r=0.67,g=0.83,b=0.45}
        title:SetTextColor(c.r,c.g,c.b)
        useTheme:SetChecked(NeonCastDB.useThemeColor)
        RefreshAll()
    end)
    f:SetScript("OnHide", function()
        ns.SetUnlocked(false)
    end)

    tinsert(UISpecialFrames, "NeonCastOptions") -- Escape closes it

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
