local _, ns = ...
local SCHOOL_COLOR = {
    [1] = {1, 1, 0},
    [2]  = { 1.00, 0.90, 0.50 },
    [4]  = { 1.00, 0.50, 0.00 },
    [8]  = { 0.30, 1.00, 0.30 },
    [16] = { 0.50, 1.00, 1.00 },
    [32] = { 0.50, 0.50, 1.00 },
    [64] = { 1.00, 0.50, 1.00 },
}
local DEFAULT_COLOR = { 0.70, 0.70, 0.70 }
local SCHOOL_BITS = { 1, 2, 4, 8, 16, 32, 64 }

-- Returns a list of colors, one per school in the mask, lowest school first
local function ColorsForMask(mask)
    if not mask then return { DEFAULT_COLOR } end
    local solid = SCHOOL_COLOR[mask]
    if solid then return { solid } end
    local list = {}
    for _, bit in ipairs(SCHOOL_BITS) do
        if mask % (bit * 2) >= bit then
            list[#list + 1] = SCHOOL_COLOR[bit]
        end
    end
    if #list == 0 then return { DEFAULT_COLOR } end
    return list
end

local SCHOOL_NAMES, TICK_NAMES = ns.SCHOOL_NAMES, ns.TICK_NAMES
local HIDDEN_CASTS = ns.HIDDEN_CASTS

-- Schools learned from the combat log at runtime (Classic Era), by spell name.
local learned = {}

local function TickCount(name, total)
    local info = TICK_NAMES[name]
    if not info then return 0 end
    if info.ticks then return info.ticks end
    if info.interval and total > 0 then
        return math.floor(total / info.interval + 0.5)
    end
    return 0
end

------------------------------------------------------------------------
-- Secret values (Forever): another unit's cast info can come
-- back secret. If it does, that bar simply stays hidden.

-- Automatic school detection: read the spell's own description and take the
-- school word that appears first ("... dealing 1,234 Nature damage").
local SCHOOL_WORDS
local SCHOOL_BY_SCAN = {} -- spellID -> mask, or false when no school word was found
local pendingLoad = {}

local function BitCount(m)
    local n = 0
    while m > 0 do
        n = n + m % 2
        m = math.floor(m / 2)
    end
    return n
end

local function SchoolString(mask)
    if C_Spell and C_Spell.GetSchoolString then
        return C_Spell.GetSchoolString(mask)
    end
    if GetSchoolString then
        return GetSchoolString(mask)
    end
end

local function BuildWords()
    SCHOOL_WORDS = {}
    -- Every named multi-school combination (Shadowflame, Frostfire, Spellfire,
    -- Chaos, Magic, ...), with the name taken from the client. Combinations
    -- containing physical are skipped (their names, like Flamestrike, clash
    -- with spell names), except Chaos (127). Listed first so they win ties.
    for mask = 3, 127 do
        if BitCount(mask) >= 2 and (mask % 2 == 0 or mask == 127) then
            local name = SchoolString(mask)
            if type(name) == "string" and name ~= "" and name ~= "Unknown" and name ~= UNKNOWN then
                SCHOOL_WORDS[#SCHOOL_WORDS + 1] = { word = name, mask = mask }
            end
        end
    end
    local fallback = { [0] = "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }
    for i = 0, 6 do
        local w = _G["SPELL_SCHOOL" .. i .. "_CAP"]
        if type(w) ~= "string" or w == "" then w = fallback[i] end
        SCHOOL_WORDS[#SCHOOL_WORDS + 1] = { word = w, mask = 2 ^ i }
    end
end

local function GetDescription(id)
    if C_Spell and C_Spell.GetSpellDescription then
        return C_Spell.GetSpellDescription(id)
    end
    if GetSpellDescription then
        return GetSpellDescription(id)
    end
end

-- Position of "<word> damage" (any capitalization of "damage"), or nil.
local function FindPhrase(desc, word, suffix)
    local init = 1
    while true do
        local pos = string.find(desc, word, init, true)
        if not pos then return nil end
        local after = string.sub(desc, pos + #word, pos + #word + #suffix - 1)
        if string.lower(after) == suffix then return pos end
        init = pos + 1
    end
end

local function ScanDescription(desc)
    if type(desc) ~= "string" or desc == "" then return nil end
    if issecretvalue and issecretvalue(desc) then return nil end
    if not SCHOOL_WORDS then BuildWords() end

    -- Look for "Shadowflame damage", "Nature damage", "Chaos damage", ...
    local dmg = (type(DAMAGE) == "string" and DAMAGE ~= "") and DAMAGE or "Damage"
    local suffix = " " .. string.lower(dmg)
    local bestPos, bestMask
    for _, s in ipairs(SCHOOL_WORDS) do
        local pos = FindPhrase(desc, s.word, suffix)
        if pos and (not bestPos or pos < bestPos) then
            bestPos, bestMask = pos, s.mask
        end
    end
    if bestMask then return bestMask end

    -- Other languages often write school and damage as one word (e.g. "Frostschaden"),
    -- so there fall back to finding the school name anywhere in the text.
    local locale = GetLocale and GetLocale()
    if locale ~= "enUS" and locale ~= "enGB" then
        for _, s in ipairs(SCHOOL_WORDS) do
            local pos = string.find(desc, s.word, 1, true)
            if pos and (not bestPos or pos < bestPos) then
                bestPos, bestMask = pos, s.mask
            end
        end
    end
    return bestMask
end

local function SchoolFromDescription(id)
    local cached = SCHOOL_BY_SCAN[id]
    if cached ~= nil then return cached or nil end

    local desc = GetDescription(id)
    if type(desc) == "string" and desc ~= "" then
        local mask = ScanDescription(desc)
        SCHOOL_BY_SCAN[id] = mask or false
        return mask
    end

    -- Description data not loaded yet: ask for it and recolor when it arrives.
    if Spell and Spell.CreateFromSpellID and not pendingLoad[id] then
        pendingLoad[id] = true
        Spell:CreateFromSpellID(id):ContinueOnSpellLoad(function()
            pendingLoad[id] = nil
            local d = GetDescription(id)
            if type(d) == "string" and d ~= "" then
                SCHOOL_BY_SCAN[id] = ScanDescription(d) or false
                for _, b in pairs(ns.Bars or {}) do
                    if b:IsShown() and b.spellID == id then ns.Bar.ApplyColor(b) end
                end
            end
        end)
    end
    return nil
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
end

-- The spell data in Data.lua is keyed by English names. Each entry is also added under the client's own
-- name for that spell (from its ID in SPELL_IDS), so it matches on any client language, and after a rename.
-- An existing entry is never replaced.
local function AddLocalNames()
    for english, id in pairs(ns.SPELL_IDS or {}) do
        local ok, name = pcall(SpellName, id)
        if ok and type(name) == "string" and name ~= "" and name ~= english then
            for _, t in ipairs({ SCHOOL_NAMES, TICK_NAMES, HIDDEN_CASTS }) do
                if t[english] ~= nil and t[name] == nil then t[name] = t[english] end
            end
        end
    end
end


ns.Spells = {
    ColorsForMask = ColorsForMask, TickCount = TickCount,
    AddLocalNames = AddLocalNames, Name = SpellName, Icon = SpellIcon,
}
function ns.Spells.Colors(name, id)
    local mask = SCHOOL_NAMES[name] or learned[name] or (id and SchoolFromDescription(id))
    return ColorsForMask(mask)
end
function ns.Spells.Learn(name, school)
    if not SCHOOL_NAMES[name] and not learned[name] then learned[name] = school end
end
