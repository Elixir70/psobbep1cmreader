-- The cmode map events that need to be cleared to advance. The route is defined by the map events
-- that need to be cleared on the direct path to the exit. This includes both shortcut and non-shortcut.
-- If there are optional enemies that can be skipped, those enemies from the base map event should be skipped. 
-- These are the map events listed here. Generally the first two digits of the map event will
-- point to the section number that you see in QEdit.
-- Be careful with editing this file. 
-- If you add a map event that is not in the quest file, the addon WILL break. 
-- If you add a map event that is in the quest file but isn't actually used in the area, the map event 
-- will not be in the client memory and the addon WILL break.
-- It is probably best to leave this alone unless you're making your own version and removing some extra rooms,
-- such as the 1c8/1c9 non-shortcut routes.

local _Pioneer2Events = { }

local _C1Events = {
    [1] = { 51, 21, 111 },
    [2] = { 21, 111, 151, 121 },
}

local _C2Events = {
    [1] = { 502, 321, 101, 601, 511, 521 },
    [2] = { 101 },
    [3] = { 301, 121, 511, 501, 601, 521, 341, 331 },
    [4] = { 101, 501, 601 },
    [5] = { 101, 401, 341, 501, 601, 111, 311, 321, 521, 331 },
}

local _C3Events = {
    [1] = { 141, 231, 302, 402, 601, 111, 211, 201, 151 },
    [2] = { 401, 601, 301 },
    [3] = { 221, 111, 121, 101, 201, 601, 402, 301 },
    [4] = { 101, 111, 201 },
    [5] = { 131, 201, 211, 221, 601, 451, 141, 301, 401, 151 },
}

local _C4Events = {
    [1] = { 501, 211, 321, 401, 711, 231, 511, 221, 521, 701 },
    [2] = { 601, 201, 701 },
    [3] = { 301, 501, 311, 701, 531 },
    [4] = { 501, 601, 611, 521},
    [5] = { 501, 511, 211, 411, 701, 531 },
}

local _C5Events = {
    [1] = { 501, 601, 511, 751, 301, 901, 211, 611, 541 },
    [2] = { 501, 601 },
    [3] = { 601, 501, 511, 301, 611, 751, 531 },
    [4] = { 401, 501, 601 },
    [5] = { 501, 601, 901, 511, 301, 521, 411, 531, 611 },
}

local _C6Events = {
    [1] = { 501, 601, 801, 301, 531, 702, 611 },
    [2] = { 301, 801, 501, 401 },
    [3] = { 201, 511, 501, 601, 301, 521, 801, 531 },
    [4] = { 601, 201, 501, 511 },
    [5] = { 401, 701, 501, 601, 301, 211, 521, 531, 611 },
}

local _C7Events = {
    [1] = { 602, 201, 701, 311, 221, 501, 321, 231, 331 },
    [2] = { 301, 201, 601, 111 },
    [3] = { 331, 201, 321, 701, 311, 121, 401, 501, 101 },
    [4] = { 701, 111, 311, 301, 101 },
    [5] = { 201, 601, 701, 301, 551, 211, 331, 311, 221, 321 },
}

local _C8Events = {
    [1] = { 401, 311, 431, 301, 411, 241, 801, 601, 441, 321 },
    [2] = { 311, 211, 701, 401 },
    [3] = { 301, 401, 241, 421, 321, 801, 701, 431, 341 },
    [4] = { 311, 201, 401, 801 },
    [5] = { 301, 401, 651, 321, 411, 501, 801, 331, 421, 431 },
}

local _C9Events = {
    [1] = { 401, 301, 421, 431, 321, 211, 602, 441, 801 },
    [2] = { 211, 321, 501, 311, 411, 301, 201 },
    [3] = { 331, 651, 321, 221, 311, 301, 431, 801 },
    [4] = { 301, 801, 211, 401 },
    [5] = { 401, 211, 301, 551, 201, 411, 321, 221, 231, 311, 421, 331, 801 },
}

local _MapStageNameToEventTables = {
    ["Stage1"] = _C1Events,
    ["Stage2"] = _C2Events,
    ["Stage3"] = _C3Events,
    ["Stage4"] = _C4Events,
    ["Stage5"] = _C5Events,
    ["Stage6"] = _C6Events,
    ["Stage7"] = _C7Events,
    ["Stage8"] = _C8Events,
    ["Stage9"] = _C9Events,
    ["ステージ1"] = _C1Events,
    ["ステージ2"] = _C2Events,
    ["ステージ3"] = _C3Events,
    ["ステージ4"] = _C4Events,
    ["ステージ5"] = _C5Events,
    ["ステージ6"] = _C6Events,
    ["ステージ7"] = _C7Events,
    ["ステージ8"] = _C8Events,
    ["ステージ9"] = _C9Events,
}

-- Apparently 'Stage5' is really 'Stage5 '.
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function GetEventsForStage(stage)
    local events = _MapStageNameToEventTables[trim(stage)]
    if events == nil then
        return {}
    end
    return events
end

return 
{
    Pioneer2Events    = _Pioneer2Events,
    C1Events          = _C1Events,
    C2Events          = _C2Events,
    C3Events          = _C3Events,
    C4Events          = _C4Events,
    C5Events          = _C5Events,
    C6Events          = _C6Events,
    C7Events          = _C7Events,
    C8Events          = _C8Events,
    C9Events          = _C9Events, 
    GetEventsForStage = GetEventsForStage,
}