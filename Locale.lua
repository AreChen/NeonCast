-- English is the fallback; each translation lives in its own independently registered file.
local _, ns = ...
local packs = {}
ns.L = {}
ns.Locale = {}
function ns.Locale.Register(locale, values)
    packs[locale] = values
end
function ns.Locale.Activate(locale)
    local base = packs.enUS or {}
    local translated = packs[locale] or base
    for key in pairs(ns.L) do ns.L[key] = nil end
    for key, value in pairs(base) do ns.L[key] = translated[key] or value end
    setmetatable(ns.L, {__index = function(_, key) return base[key] or key end})
end
function ns.Locale.Has(locale) return packs[locale] ~= nil end
