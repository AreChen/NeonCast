local _, ns = ...
local CONFIG = ns.CONFIG
local bars = ns.Bars
local CreateBar, EnableDragging = ns.Bar.Create, ns.Bar.EnableDragging
local PixelSize, ApplySettings, ApplyColor = ns.Bar.PixelSize, ns.Bar.ApplySettings, ns.Bar.ApplyColor
local Refresh, OnSent = ns.Cast.Refresh, ns.Cast.OnSent
local OnSucceeded, OnHiddenStopped = ns.Cast.OnSucceeded, ns.Cast.OnHiddenStopped
local AddLocalNames = ns.Spells.AddLocalNames
-- Hides Blizzard's own player cast bar so only NeonCast's bar shows.
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
frame:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
pcall(frame.RegisterEvent, frame, "INPUT_DEVICE_INTERFACE_TRANSITION")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")

-- Where the combat log is still open to addons (Classic Era), learn the
-- school of your own casts by spell name. Spell IDs are 0 there, names work.
local playerGUID

local function OnCombatLog()
    local _, sub, _, srcGUID = CombatLogGetCurrentEventInfo()
    if srcGUID ~= playerGUID then return end
    if sub ~= "SPELL_CAST_START" and sub ~= "SPELL_CAST_SUCCESS" then return end
    local spellName, school = select(13, CombatLogGetCurrentEventInfo())
    if type(spellName) ~= "string" or type(school) ~= "number" then return end
    ns.Spells.Learn(spellName, school)
    local bar = bars.player
    if bar and bar:IsShown() and bar.spellName == spellName then
        ApplyColor(bar)
    end
end

frame:SetScript("OnEvent", function(_, event, unit, ...)
    local castGUID = ...
    if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        ns.Profiles.UpdateMode()
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.SetUnlocked(false)
        if ns.HideOptions then ns.HideOptions() end
    elseif event == "PLAYER_LOGIN" then
        ns.Profiles.Initialize()
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
    elseif event == "CURRENT_SPELL_CAST_CHANGED" then
        ns.CastLatency.CastChanged(ns.CastLatency.Now())
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog()
    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, sentGUID, spellID = ... -- target, castGUID, spellID
        if unit == "player" then ns.CastLatency.Sent(sentGUID, ns.CastLatency.Now()) end
        OnSent(bars[unit], sentGUID, spellID)
    elseif (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") and unit == "player" then
        local bar = bars[unit]
        local measured = ns.CastLatency.Start(castGUID, ns.CastLatency.Now())
        if bar then bar.castLatency = measured; Refresh(bar, event, castGUID) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" then ns.CastLatency.Forget(castGUID) end
        local _, spellID = ...
        OnSucceeded(bars[unit], castGUID)
        if unit == "player" and not (issecretvalue and issecretvalue(spellID)) then ns.CraftProgress.Succeeded(spellID) end
    elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
        if unit == "player" then ns.CraftProgress.Reset(); ns.CastLatency.Forget(castGUID) end
        OnHiddenStopped(bars[unit], event, castGUID)
    elseif bars[unit] then
        if unit == "player" and (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET") then ns.CraftProgress.Reset(); ns.CastLatency.Forget(castGUID) end
        if (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
            and OnHiddenStopped(bars[unit], event, castGUID) then
            return
        end
        Refresh(bars[unit], event, castGUID)
    end
end)
