local _, ns = ...
local CONFIG = ns.CONFIG
local B = ns.Bar
local SetFillWidth, SetGradientStops, SetTicks = B.SetFillWidth, B.SetGradientStops, B.SetTicks
local UpdateValue, EnsurePixelGrid, SetName = B.UpdateValue, B.EnsurePixelGrid, B.SetName
local SetSafeZone, ApplyColor = B.SetSafeZone, B.ApplyColor
local TickCount, SpellName, SpellIcon = ns.Spells.TickCount, ns.Spells.Name, ns.Spells.Icon
local HIDDEN_CASTS = ns.HIDDEN_CASTS
local HIDDEN_HOLD = 0.5
local Refresh, StartPending
local function GetQueueWindow() return ns.GetQueueMs() / 1000 end
local function Plain(...)
    if not issecretvalue then return true end
    for i = 1, select('#', ...) do if issecretvalue((select(i, ...))) then return false end end
    return true
end
local function ResponseAllowance(bar) return math.min(bar.castLatency or 0, 1) end
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
                ShowFailed(bar, event == "UNIT_SPELLCAST_FAILED" and (FAILED or ns.L.failed) or (INTERRUPTED or ns.L.interrupted))
            end
        end
        return
    end

    -- The cast just ended. Say why, if we know.
    local label
    if event == "UNIT_SPELLCAST_INTERRUPTED" then
        label = INTERRUPTED or ns.L.interrupted
    elseif event == "UNIT_SPELLCAST_FAILED" then
        label = FAILED or ns.L.failed
    elseif not bar.channel and GetTime() < bar.endTime - (0.25 + ResponseAllowance(bar)) then
        -- A cast that stopped well before its end and gave no reason was cancelled.
        label = INTERRUPTED or ns.L.interrupted
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
        if now >= bar.endTime + HIDDEN_HOLD + ResponseAllowance(bar) then
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

local function ShowHiddenCast(bar, name, spellID, duration, castGUID)
    ns.CastLatency.ClearText(bar) -- Synthetic casts have no matching start event.
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
    if p and GetTime() - p.sent < GetQueueWindow() + ResponseAllowance(bar) + 0.5 then
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

ns.Cast = { Refresh = Refresh, OnUpdate = OnUpdate, OnSent = OnSent, OnSucceeded = OnSucceeded, OnHiddenStopped = OnHiddenStopped }
