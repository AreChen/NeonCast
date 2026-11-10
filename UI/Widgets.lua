local _, ns = ...
local FRAME_W = 470
local CONFIG = ns.CONFIG
local function stepMultiplier()
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    local hud = ns.Navigation.IsGamepad() and GamepadMode and GamepadMode.IsHUDBindingModifierDown and GamepadMode.IsHUDBindingModifierDown()
    return (shift or hud) and 10 or 1
end
local function Round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(v * m + 0.5) / m
end

-- "Restore defaults" is grayed out while everything is already at its default.
local function UpdateReset() if ns.RefreshReset then ns.RefreshReset() end end

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
    row:SetScript("OnDragStart", function() if ns.OptionsFrame then ns.OptionsFrame:StartMoving() end end)
    row:SetScript("OnDragStop", function() if ns.OptionsFrame then ns.OptionsFrame:StopMovingOrSizing() end end)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 16, 0)
    label:SetWidth(130)
    label:SetJustifyH("LEFT")
    label:SetText(text)

    local function smallButton(text)
        local button=ns.Theme.Button(row);button:SetText(text)
        return button
    end
    local minus = smallButton("-")
    minus:SetSize(26, 26)
    minus:SetPoint("LEFT", row, "LEFT", 150, 0)

    ns.Navigation.Focusable(minus)
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
    track:SetColorTexture(0.11,0.15,0.21,1)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    slider:GetThumbTexture():SetSize(8, 16)
    ns.Theme.Observe(function(c) slider:GetThumbTexture():SetVertexColor(c.r,c.g,c.b,1) end)
    local active=ns.Theme.Texture(slider,"ARTWORK",{0.2,0.82,1},0.7)
    active:SetPoint("LEFT",track,"LEFT",0,0);active:SetHeight(3)
    ns.Theme.Observe(function(c) active:SetColorTexture(c.r,c.g,c.b,0.7) end)

    local plus = smallButton("+")
    plus:SetSize(26, 26)
    plus:SetPoint("LEFT", row, "LEFT", 304, 0)
    ns.Navigation.Focusable(plus)

    local edit = CreateFrame("EditBox", nil, row)
    edit:SetFontObject(GameFontHighlightSmall)
    ns.Theme.Surface(edit,ns.Theme.colors.inset,1,0.15)
    edit:SetSize(44, 20)
    edit:SetPoint("LEFT", row, "LEFT", 336, 0)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(6)
    edit:SetJustifyH("CENTER")

    ns.Navigation.Ignore(slider)
    ns.Navigation.Ignore(edit)
    local fmt = "%." .. decimals .. "f"
    local busy = false -- true while we move the slider from code, so that is not taken for a drag

    local function display(v)
        busy = true
        setRange()
        slider:SetValue(v)
        active:SetWidth(math.max(1,124*(v-lo())/math.max(hi()-lo(),0.001)))
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
    minus:SetScript("OnClick", function() apply(get() - step * stepMultiplier()) end)
    plus:SetScript("OnClick", function() apply(get() + step * stepMultiplier()) end)
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
        if on then minus:Enable(); plus:Enable() else minus:Disable(); plus:Disable() end
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
    local track=ns.Theme.Surface(cb,ns.Theme.colors.inset,1,0.16)
    local knob = cb:CreateTexture(nil, "ARTWORK")
    knob:SetSize(14, 14)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y - 4)
    label:SetText(text)
    local function paint()
        local on = get() and true or false
        local c = ns.Theme.Accent()
        if on then track:SetVertexColor(c.r*0.35,c.g*0.35,c.b*0.35,1) else track:SetVertexColor(0.07,0.10,0.15,1) end
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", cb, "LEFT", on and 20 or 4, 0)
        knob:SetColorTexture(0.95,0.96,0.97,1)
    end
    ns.Theme.Observe(function() paint() end)
    ns.Navigation.Focusable(cb)
    cb:SetScript("OnClick", function() set(not get()); paint(); UpdateReset() end)
    function cb.Refresh() paint() end
    if tip then AddTooltip(cb, { cb }, text, tip, parent) end
    return cb
end

-- Color picker plus controller-friendly preset swatches.
local function MakeColorRow(parent, y, text, part, tip)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_W, 26)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 16, 0)
    label:SetWidth(130); label:SetJustifyH("LEFT"); label:SetText(text)

    local preview = CreateFrame("Button", nil, row)
    preview:SetSize(24, 24); preview:SetPoint("LEFT", row, "LEFT", 150, 0)
    local border = preview:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(); border:SetColorTexture(0.55, 0.58, 0.62, 1)
    local swatch = preview:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2); swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    local presetButtons = {}
    local picker = ns.Theme.Button(row)
    picker:SetSize(110, 24); picker:SetPoint("LEFT", preview, "RIGHT", 12, 0); picker:SetText(ns.L.chooseColor)

    local function refresh()
        if ns.RefreshOptions then ns.RefreshOptions() else row.Refresh(); UpdateReset() end
    end
    local function openPicker()
        local r, g, b = ns.GetPartColor(part)
        local original = CONFIG[part]
        local function apply()
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            ns.SetSetting(part, {r=red, g=green, b=blue})
            refresh()
        end
        local function cancel()
            ns.SetSetting(part, original)
            refresh()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({r=r, g=g, b=b, swatchFunc=apply, cancelFunc=cancel})
        else
            ColorPickerFrame.func = apply; ColorPickerFrame.cancelFunc = cancel
            ColorPickerFrame:SetColorRGB(r,g,b); ColorPickerFrame:Show()
        end
    end
    preview:SetScript("OnClick", openPicker)
    picker:SetScript("OnClick", openPicker)
    local slot = 0
    for _, color in ipairs(ns.PALETTE) do
        if not color.only or color.only[part] then
            slot = slot + 1
            if slot > 5 then break end
            local button = CreateFrame("Button", nil, row)
            button:SetSize(24,24); button:SetPoint("LEFT",row,"LEFT",304+(slot-1)*30,0)
            local texture=button:CreateTexture(nil,"ARTWORK"); texture:SetAllPoints(); texture:SetColorTexture(color[1],color[2],color[3],1)
            local key=color.key
            ns.Navigation.Focusable(button, string.format(ns.L.presetColor,slot))
            button:SetScript("OnClick",function() ns.SetSetting(part,key);refresh() end)
            presetButtons[#presetButtons+1]={button=button,key=key}
        end
    end
    ns.Navigation.Focusable(preview); ns.Navigation.Focusable(picker)
    function row.Refresh()
        for _, entry in ipairs(presetButtons) do
            if ns.ColorUsable(part,entry.key) then entry.button:Enable() else entry.button:Disable() end
        end
        local r, g, b = ns.GetPartColor(part)
        swatch:SetColorTexture(r,g,b,1)
    end
    if tip then AddTooltip(row, {row}, text, tip) end
    return row
end


ns.Widgets = { Slider = MakeSlider, Check = MakeCheck, Color = MakeColorRow, Tooltip = AddTooltip }
