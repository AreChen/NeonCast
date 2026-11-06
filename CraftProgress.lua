local _, ns = ...
local P = {}
ns.CraftProgress = P
local recipe, total, completed

function P.Reset()
    recipe, total, completed = nil, nil, nil
end
function P.Begin(id, count)
    P.Reset()
    if type(id) ~= "number" or type(count) ~= "number" or count <= 1 or count % 1 ~= 0 then return end
    recipe, total, completed = id, count, 0
end
function P.Label(id)
    if issecretvalue and issecretvalue(id) then return nil end
    if not recipe or id ~= recipe then return nil end
    return (completed + 1) .. "/" .. total
end
function P.Succeeded(id)
    if issecretvalue and issecretvalue(id) then return end
    if not recipe or id ~= recipe then return end
    completed = completed + 1
    if completed >= total then P.Reset() end
end

-- Event-paired cast latency tracking.
do
local _, ns = ...
local pending = {}
local lastCastChange
local MAX_AGE = 15
local M = {}
ns.CastLatency = M

-- GetTime may be constant for an entire rendered frame.
function M.Now()
    if type(GetTimePreciseSec) == "function" then return GetTimePreciseSec() end
    return GetTime()
end

local function valid(value)
    if issecretvalue and issecretvalue(value) then return false end
    return type(value) == "string" and value ~= ""
end

function M.CastChanged(now)
    if type(now) == "number" then lastCastChange = now end
end

function M.Sent(guid, now)
    local changed = lastCastChange
    lastCastChange = nil
    if not valid(guid) or type(now) ~= "number" then return end
    for id, when in pairs(pending) do
        if now - when > MAX_AGE or now < when then pending[id] = nil end
    end
    pending[guid] = nil
    if changed and changed <= now and now - changed <= MAX_AGE then
        pending[guid] = changed
    end
end

function M.Start(guid, now)
    if not valid(guid) or type(now) ~= "number" then return nil end
    local sent = pending[guid]
    pending[guid] = nil
    if not sent or now < sent or now - sent > MAX_AGE then return nil end
    return now - sent
end

-- A missing sample leaves the visible value unchanged until the bar is hidden.
function M.UpdateText(bar, latency)
    if latency == nil or not bar.latencyText then return end
    local display = string.format("%d ms", math.floor(latency * 1000))
    if display ~= bar.latencyDisplay then
        bar.latencyText:SetText(display)
        bar.latencyDisplay = display
    end
end

function M.ClearText(bar)
    if bar.latencyText then bar.latencyText:SetText("") end
    bar.latencyDisplay = nil
    bar.castLatency = nil
end

function M.Forget(guid)
    if valid(guid) then pending[guid] = nil end
end

end
