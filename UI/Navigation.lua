-- Integrate with the client's own focus/binding stack; never replace player bindings.
local _, ns = ...
local N = {}
local ignored = setmetatable({}, {__mode="k"})
ns.Navigation = N
function N.IsGamepad() return ns.Profiles.DetectMode() == 'gamepad' end
function N.InCombat() return InCombatLockdown and InCombatLockdown() end
function N.Focusable(frame, name)
    if name then
        local caption = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        caption:SetPoint('BOTTOM', frame, 'TOP', 0, 2)
        caption:SetText(name); caption:Hide()
        frame:HookScript('OnEnter', function() caption:Show() end)
        frame:HookScript('OnLeave', function() caption:Hide() end)
    end
    ns.Theme.Focus(frame)
end
function N.Ignore(frame)
    ignored[frame] = true
    if SmartNavigation_MarkFrameIgnored and not N.InCombat() then SmartNavigation_MarkFrameIgnored(frame) end
end
function N.Sync(frame)
    if N.InCombat() then return end
    if SmartNavigation_MarkFrameIgnored then
        for ignoredFrame in pairs(ignored) do SmartNavigation_MarkFrameIgnored(ignoredFrame) end
    end
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if not manager or not manager.FrameShown or not manager.FrameHidden then return end
    if N.IsGamepad() and frame:IsShown() then
        if not frame.neonNavActive then
            manager:FrameShown(frame)
            frame.neonNavActive = true
        end
    elseif frame.neonNavActive then
        manager:FrameHidden(frame)
        frame.neonNavActive = nil
    end
end
function N.Close(frame)
    local manager = GamepadMode and GamepadMode.FrameControlsManager
    if frame.neonNavActive then
        -- The manager's public wrapper enforces the client's combat restrictions.
        if manager and not N.InCombat() then
            manager:FrameHidden(frame)
            frame.neonNavActive = nil
        end
    end
end
function N.Attach(frame)
    frame.SmartNavigationCloseHandler = function() frame:Hide(); return true end
    frame:HookScript('OnShow', function() N.Sync(frame) end)
    frame:HookScript('OnHide', function() N.Close(frame) end)
end
