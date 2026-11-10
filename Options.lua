-- Settings panel. Preview is explicit; the live cast bar keeps running while settings are open.

local _, ns = ...
local CONFIG, LIMITS = ns.CONFIG, ns.LIMITS

local MakeSlider, MakeCheck, MakeColorRow = ns.Widgets.Slider, ns.Widgets.Check, ns.Widgets.Color
local AddTooltip = ns.Widgets.Tooltip

local frame
local widgets = {}          -- everything that can re-read its value with :Refresh()
local queueRow, xRow, yRow, heightRow, fontRow
local resetButton
local function UpdateReset()
    if resetButton then if ns.IsDefault() then resetButton:Disable() else resetButton:Enable() end end
end
ns.RefreshReset = UpdateReset


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
    f:SetSize(720, 620)
    ns.OptionsFrame = f
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local function surface(parent, r, g, b, a)
        return ns.Theme.Surface(parent,{r,g,b},a,0.11)
    end
    local function label(parent, text, font, x, y, color)
        local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        t:SetText(text)
        if color then t:SetTextColor(unpack(color)) end
        return t
    end
    surface(f, 0.025, 0.035, 0.062, 0.97)
    local shadow=f:CreateTexture(nil,"BACKGROUND",nil,-8)
    shadow:SetTexture("Interface\\AddOns\\NeonCast\\Media\\NeonGlow")
    shadow:SetPoint("TOPLEFT",f,"TOPLEFT",-28,28);shadow:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",28,-28)
    shadow:SetVertexColor(0,0,0,0.85)
    local top=ns.Theme.Texture(f,"ARTWORK",{0.2,0.82,1},0.85)
    top:SetHeight(1);top:SetPoint("TOPLEFT",18,-1);top:SetPoint("TOPRIGHT",-18,-1)
    local head=ns.Theme.Texture(f,"BACKGROUND",{0.2,0.82,1},0.06,-1)
    head:SetPoint("TOPLEFT",184,-10);head:SetPoint("BOTTOMRIGHT",f,"TOPRIGHT",-10,-67)
    ns.Theme.Observe(function(c)
        top:SetColorTexture(c.r,c.g,c.b,0.85)
        ns.Theme.Gradient(head,{c.r,c.g,c.b,0.065},{c.r,c.g,c.b,0})
    end)
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 0, 0); side:SetPoint("BOTTOMLEFT", 0, 0); side:SetWidth(174)
    surface(side, 0.018, 0.025, 0.043, 0.99)
    local brand = label(side, "NEON|cffffffffCAST|r", "GameFontNormalLarge", 20, -25)
    local divider=ns.Theme.Texture(side,"BORDER",{1,1,1},0.05)
    divider:SetWidth(1);divider:SetPoint("TOPRIGHT",0,-16);divider:SetPoint("BOTTOMRIGHT",0,16)
    local small = label(side, L.subtitle, "GameFontNormalSmall", 20, -49, {0.54,0.58,0.64})
    local close = ns.Theme.Button(f)
    close:SetSize(28,28);close:SetText("×");close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -14)
    close:SetScript("OnClick",function() f:Hide() end);ns.Navigation.Focusable(close)
    local title = label(f, L.appearance, "GameFontNormalLarge", 201, -24)
    local desc = label(f, L.description, "GameFontHighlightSmall", 201, -48, {0.57,0.61,0.66})
    local footer = label(side, L.version, "GameFontNormalSmall", 20, -588, {0.47,0.52,0.57})
    local pageFrames, navButtons = {}, {}
    local selected = 1
    local accentRegions = {brand}
    local function accent()
        ns.Theme.Refresh()
        local c = ns.Theme.Accent()
        for _, t in ipairs(accentRegions) do t:SetTextColor(c.r,c.g,c.b) end
        for i, b in ipairs(navButtons) do
            b.marker:SetColorTexture(c.r,c.g,c.b, i == selected and 0.95 or 0)
            b.bg:SetColorTexture(c.r,c.g,c.b, i == selected and 0.13 or 0)
            b.caption:SetTextColor(i == selected and c.r or 0.64,i == selected and c.g or 0.70,i == selected and c.b or 0.80)
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
        local t = label(b, name, "GameFontHighlight", 32, -12)
        b.caption=t
        local number=label(b,string.format("%02d",index),"GameFontHighlightSmall",9,-13,{0.35,0.43,0.54})
        ns.Navigation.Focusable(b)
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
    local latencyPage = page(L.latencyPage, 4)
    local function card(parent, top, height, heading)
        local c = CreateFrame("Frame", nil, parent)
        c:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, top); c:SetSize(502, height)
        surface(c, 0.045, 0.060, 0.092, 0.96)
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
    local palette = ns.Theme.presets
    local function choose(r,g,b)
        NeonCastDB.accent = {r=r,g=g,b=b}
        accent(); ns.Redraw(); RefreshAll()
    end
    for i, color in ipairs(palette) do
        local b = CreateFrame("Button", nil, colors)
        b:SetSize(26,26); b:SetPoint("TOPLEFT", colors, "TOPLEFT", 145 + (i-1)*32, -46)
        local sw = b:CreateTexture(nil, "ARTWORK"); sw:SetAllPoints(); sw:SetColorTexture(color.r,color.g,color.b,1)
        ns.Navigation.Focusable(b,L[color.key])
        b:SetScript("OnClick", function() choose(color.r,color.g,color.b) end)
    end
    local picker = ns.Theme.Button(colors)
    picker:SetSize(110,24); picker:SetPoint("TOPLEFT", colors, "TOPLEFT", 320, -47); picker:SetText(L.chooseColor)
    picker:SetScript("OnClick", function()
        local c = ns.Theme.Accent()
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
    ns.Theme.Sample(style)
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

    local latencyCard = card(latencyPage, 0, 448, L.latencyTitle)
    add(MakeCheck(latencyCard, -43, L.showLatencyText,
        function() return CONFIG.showLatencyText end,
        function(v) ns.SetSetting("showLatencyText", v) end))
    slider(latencyCard, -75, "latencyFontSize", L.latencyFontSize)
    add(MakeColorRow(latencyCard, -112, L.latencyTextColor, "latencyTextColor"))
    label(latencyCard, L.latencyFont, "GameFontHighlight", 16, -163)
    local pathBox = CreateFrame("EditBox", nil, latencyCard, "InputBoxTemplate")
    pathBox:SetSize(390, 24); pathBox:SetPoint("TOPLEFT", latencyCard, "TOPLEFT", 18, -237)
    pathBox:SetAutoFocus(false); pathBox:SetMaxLetters(255)
    ns.Theme.Surface(pathBox,ns.Theme.colors.inset,1,0.18)
    local pathLabel = label(latencyCard, L.fontPath, "GameFontHighlightSmall", 16, -214, {0.62,0.66,0.71})
    function pathBox.Refresh() pathBox:SetText(NeonCastDB.latencyFont or "") end
    widgets[#widgets + 1] = pathBox
    pathBox:SetScript("OnEnterPressed", function(self)
        ns.SetLatencyFont(self:GetText()); self:ClearFocus(); self.Refresh(); UpdateReset()
    end)
    pathBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self.Refresh() end)
    pathBox:SetScript("OnEditFocusLost", function(self) self.Refresh() end)
    ns.Navigation.Ignore(pathBox)
    local function cycleFont(direction)
        local fonts = {{name=L.defaultFont, path=""}}
        local ok, media = pcall(function() return LibStub and LibStub("LibSharedMedia-3.0", true) end)
        if ok and media and media.List and media.Fetch then
            for _, name in ipairs(media:List("font")) do
                local path = media:Fetch("font", name, true)
                if path then fonts[#fonts+1]={name=name,path=path} end
            end
        end
        local index=1
        for i, font in ipairs(fonts) do if font.path == (NeonCastDB.latencyFont or "") then index=i end end
        index=(index-1+direction)%#fonts+1
        ns.SetLatencyFont(fonts[index].path); pathBox.Refresh(); UpdateReset()
    end
    for i, entry in ipairs({{L.fontPrev,-1},{L.fontNext,1}}) do
        local button=ns.Theme.Button(latencyCard)
        button:SetSize(200,28); button:SetPoint("TOPLEFT",latencyCard,"TOPLEFT",18+(i-1)*218,-372)
        button:SetText(entry[1]); ns.Navigation.Focusable(button)
        button:SetScript("OnClick",function() cycleFont(entry[2]) end)
    end
    local resetFont = ns.Theme.Button(latencyCard)
    resetFont:SetSize(140,24); resetFont:SetPoint("TOPLEFT", latencyCard, "TOPLEFT", 18, -277)
    resetFont:SetText(L.defaultFont)
    resetFont:SetScript("OnClick", function() ns.SetLatencyFont(""); pathBox.Refresh(); UpdateReset() end)
    label(latencyCard, L.latencyHint, "GameFontHighlightSmall", 16, -331, {0.62,0.66,0.71})

    -- SharedMedia is optional. Manual paths and the game's font remain available without it.
    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
        local dropdown = CreateFrame("Frame", "NeonCastLatencyFontDropdown", latencyCard, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", latencyCard, "TOPLEFT", 135, -148)
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dropdown, 240) end
        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(dropdown, L.latencyFont) end
        UIDropDownMenu_Initialize(dropdown, function()
            local default = UIDropDownMenu_CreateInfo()
            default.text = L.defaultFont
            default.func = function() ns.SetLatencyFont(""); pathBox.Refresh(); UpdateReset() end
            UIDropDownMenu_AddButton(default)
            local ok, media = pcall(function() return LibStub and LibStub("LibSharedMedia-3.0", true) end)
            if ok and media and media.List and media.Fetch then
                for _, name in ipairs(media:List("font")) do
                    local fontName = name
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = fontName
                    info.func = function()
                        local path = media:Fetch("font", fontName, true)
                        if path then ns.SetLatencyFont(path); pathBox.Refresh(); UpdateReset() end
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
        end)
    end

    local toolbar = CreateFrame("Frame", nil, f)
    toolbar:SetPoint("TOPLEFT", f, "TOPLEFT", 194, -540); toolbar:SetSize(502, 60)
    local preview = add(MakeCheck(toolbar, 0, L.preview,
        function() local b = ns.GetBar(); return b and b.unlocked end,
        function(on) ns.SetUnlocked(on) end, L.previewHint))
    local hint = label(toolbar, L.controllerHint, "GameFontHighlightSmall", 16, -32, {0.65,0.7,0.75})
    hint:SetWidth(470); hint:SetWordWrap(true)
    widgets[#widgets+1] = {Refresh=function() hint:SetShown(ns.Navigation.IsGamepad()) end}
    label(side, L.layoutMode, "GameFontNormalSmall", 16, -272)
    local modeText = label(side, "", "GameFontHighlightSmall", 16, -295)
    modeText:SetWidth(150); modeText:SetWordWrap(true)
    widgets[#widgets+1] = {Refresh=function() modeText:SetText(string.format(L.activeLayout, L[ns.Profiles.active])) end}
    for i, mode in ipairs({"auto", "keyboard", "gamepad"}) do
        local button = ns.Theme.Button(side)
        button:SetSize(146, 28); button:SetPoint("TOPLEFT", side, "TOPLEFT", 14, -330-(i-1)*34)
        button:SetText(L[mode]); ns.Navigation.Focusable(button)
        widgets[#widgets+1] = {Refresh=function()
            button:SetText(L[mode]);button.SetSelected((NeonCastDB.layoutMode or "auto") == mode)
        end}
        button:SetScript("OnClick", function() ns.Profiles.SetMode(mode); RefreshAll() end)
    end
    local large = ns.Theme.Button(side)
    large:SetSize(146,28); large:SetPoint("TOPLEFT", side, "TOPLEFT", 14,-442)
    large:SetText(L.largePreset); large:SetScript("OnClick", function() ns.Profiles.LargePreset(); RefreshAll() end)
    ns.Navigation.Focusable(large)
    local queueReset = ns.Theme.Button(casting)
    queueReset:SetSize(430,28); queueReset:SetPoint("TOPLEFT", casting,"TOPLEFT",16,-322)
    queueReset:SetText(L.queueReset)
    queueReset:SetScript("OnClick", function() ns.SetQueueMs(400); queueRow.Refresh() end)
    AddTooltip(queueReset,{queueReset},L.queueReset,L.queueResetHint)
    local reset = ns.Theme.Button(side)
    reset:SetSize(138, 26); reset:SetPoint("BOTTOM", side, "BOTTOM", 0, 70); reset:SetText(L.reset)
    ns.Navigation.Focusable(reset)
    resetButton = reset
    reset:SetScript("OnClick", function() ns.RestoreDefaults(); accent(); RefreshAll() end)
    AddTooltip(reset, {reset}, L.reset, L.resetHint)
    f:SetScript("OnUpdate", function()
        local b = ns.GetBar()
        if b and b.dragging then local x,y = ns.GetDragPixelPos(b); xRow.Display(x); yRow.Display(y) end
    end)
    local function resize()
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        local scale = math.min(1, (width - 24) / 720, (height - 24) / 620)
        f:SetScale(math.max(0.35, scale))
    end
    f:SetScript("OnShow", function(self)
        self:ClearAllPoints(); self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        resize(); accent(); RefreshAll()
        ns.Theme.Refresh()
    end)
    f:RegisterEvent("UI_SCALE_CHANGED")
    f:RegisterEvent("DISPLAY_SIZE_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function() if f:IsShown() then resize() end; ns.Navigation.Sync(f) end)
    f:SetScript("OnHide", function() ns.SetUnlocked(false); RefreshAll() end)
    tinsert(UISpecialFrames, "NeonCastOptions")
    ns.Navigation.Attach(f)
    accent()
    return f
end

function ns.OnMoved()
    if frame and frame:IsShown() then RefreshPosition() end
end

function ns.HideOptions() if frame then frame:Hide() end end
function ns.RefreshOptions()
    if frame then RefreshAll(); ns.Navigation.Sync(frame) end
end
function ns.ToggleOptions()
    if ns.Navigation.InCombat() then print("NeonCast: " .. ns.L.combatSettings); return end
    if not frame then frame = CreateOptions() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Bindings share the same preview gate as the panel.
function ns.TogglePreview()
    if ns.Navigation.InCombat() then return end
    if not frame or not frame:IsShown() then ns.ToggleOptions() end
    local bar = ns.GetBar()
    ns.SetUnlocked(not (bar and bar.unlocked))
    RefreshAll()
end
NeonCast_ToggleOptions = ns.ToggleOptions
NeonCast_TogglePreview = ns.TogglePreview
