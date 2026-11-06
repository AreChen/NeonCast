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
local MAX_AGE = 15
local M = {}
ns.CastLatency = M

local function valid(value)
    if issecretvalue and issecretvalue(value) then return false end
    return type(value) == "string" and value ~= ""
end

function M.Sent(guid, now)
    if not valid(guid) or type(now) ~= "number" then return end
    for id, when in pairs(pending) do
        if now - when > MAX_AGE or now < when then pending[id] = nil end
    end
    pending[guid] = now
end

function M.Start(guid, now)
    if not valid(guid) or type(now) ~= "number" then return nil end
    local sent = pending[guid]
    pending[guid] = nil
    if not sent or now < sent or now - sent > MAX_AGE then return nil end
    return now - sent
end

function M.Forget(guid)
    if valid(guid) then pending[guid] = nil end
end

end
