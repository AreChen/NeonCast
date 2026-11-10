local _, ns = ...
local ICON = "Interface\\AddOns\\NeonCast\\Icons\\ChromaCast"
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function PlaceMinimapButton(b)
    local saved = NeonCastDB and NeonCastDB.minimap
    local degrees = saved and tonumber(saved.angle) or 215
    if not degrees or degrees ~= degrees or math.abs(degrees) == math.huge then degrees = 215 end
    local angle = math.rad(degrees)
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
        GameTooltip:AddLine(ns.L.minimapOpen, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(ns.L.minimapDrag, 0.8, 0.8, 0.8)
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
-- Slash commands and explicit addon reset.
------------------------------------------------------------------------
SLASH_NEONCAST1 = "/neoncast"
SLASH_NEONCAST2 = "/nc"
SlashCmdList["NEONCAST"] = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "reset" then
        ns.RestoreDefaults()
        if ns.RefreshOptions then ns.RefreshOptions() end
        print("|cff33ff99NeonCast|r: " .. ns.L.resetDone)
    else
        ns.ToggleOptions()
    end
end
