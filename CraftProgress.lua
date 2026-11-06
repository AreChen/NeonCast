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
