-- EP1 CM Reader -- Addon that reads the monster list from the client's memory and uses a specified route to show
--                  the number of waves per room on the route. The addon can also display the
--                  individual monsters in each wave.

-- I kind of use "map event" and "wave" interchangeably here, as well "floor" and "area". 
-- The secondary window that displays the monsters in a specified room->wave is also called
-- "counts" in most of this too.
-- This will be cleaned up maybe by 2021 ;)

local addonName                   = "EP1 CM Reader"
local addonHome                   = "addons/" .. addonName .. "/"
local optionsFileName             = addonHome .. "options.lua"

local lib_helpers                 = require("solylib.helpers")

local core_mainmenu               = require("core_mainmenu")
local cfg                         = require(addonName .. ".configuration")
local debug                       = require(addonName .. ".debug")
local cmode_events                = require(addonName .. ".cmode_events")
local memory                      = require(addonName .. ".memory")

local optionsLoaded, options      = pcall(require, addonName .. ".options")

-- Holder for configuration.lua
local ConfigurationWindow

-- Defaults
local _EP1CMReaderOptionsDefaults = {
    {"enable", true},                          -- Is this enabled?
    {"configurationWindowEnable", true},       -- Is the config window enabled?
    {"anchor", 3},                             -- Anchor to the screen--see configuration.lua
    {"X", 0},                                  -- X coord of window (relative to anchor)
    {"Y", 0},                                  -- Y coord of window (relative to anchor)
    {"W", 400},                                -- Width of window 
    {"H", 300},                                -- Height of window
    {"noTitleBar", ""},                        -- If set, do not show title bar of the window
    {"noResize", ""},                          -- If set, no resizing the window
    {"noMove", ""},                            -- If set, no moving the window
    {"transparentWindow", false},              -- If true, window's background style is invisible
    {"AlwaysAutoResize", ""},                  -- If set, resize the addon based on the items. Can be nice for adding flags temporarily
    {"countsEnable", false},                   -- Enable monster counts window?
    {"countsIndividual", false},               -- Show the individual monsters (false => show counts)
    {"countsAnchor", 3},                       -- Anchor to the screen for counts window
    {"countsX", 0},                            -- X coord of window (relative to anchor)
    {"countsY", 0},                            -- Y coord of window (relative to anchor)
    {"countsW", 400},                          -- Width of window 
    {"countsH", 300},                          -- Height of window
    {"countsNoTitleBar", ""},                  -- If set, do not show title bar of the window
    {"countsNoResize", ""},                    -- If set, no resizing the window
    {"countsNoMove", ""},                      -- If set, no moving the window
    {"countsTransparentWindow", false},        -- If true, window's background style is invisible
    {"countsAlwaysAutoResize", ""},            -- If set, resize the addon based on the items. Can be nice for adding flags temporarily
    {"countsDebug", false},                    -- Enable debug info to help me!
}

-- Inserts tabs/spaces for saving the options.lua
local function InsertTabs(level)
    for i=0,level do
        io.write("    ")
    end
end

-- Recursively save a table to a file. Has some awful hacks.
local function SaveTableToFile(tbl, level)
    if level == 0 then
        io.write("return\n")
    end
    
    InsertTabs(level-1)
    io.write("{\n")
    for key,val in pairs(tbl) do
        local skey
        local ktype = type(key)			
        local sval
        local vtype = type(val)
        
        -- Hack to avoid writing out the internal changed var
        if tostring(key) ~= "changed" then
        
            if     vtype == "string"  then 
                sval = string.format("%q", val)
                
                InsertTabs(level)
                io.write(string.format("%s = %s,\n", key, sval))
                
            elseif vtype == "number"  then 
                -- Hack for hex...
                if tostring(key) == "flagMask" or tostring(key) == "flagNum" then
                    sval = string.format("0x%-0.8X", val)
                else
                    sval = string.format("%s", val)
                end
                
                InsertTabs(level)
                io.write(string.format("%s = %s,\n", key, sval))
                
            elseif vtype == "boolean" then 
                sval = tostring(val) 
                
                InsertTabs(level)
                io.write(string.format("%s = %s,\n", key, sval))
                
            elseif vtype == "table"   then 
                -- Very hackish... Don't write the index for nested  tables
                -- Why? Because I'm assuming there aren't any nested tables with
                -- any real indexes..
                if level == 0 then
                    InsertTabs(level)
                    io.write(string.format("%s = \n", key))
                end
                
                -- And recurse to write the table in this place
                SaveTableToFile(val, level+1)
            end
        end
    end
    
    InsertTabs(level-1)
    if level ~= 0 then
        io.write("},\n")
    else
        io.write("}\n")
    end
end

-- Save options to the file. Does some cleanup for hacks and removing empty flags.
local function SaveOptions(tbl, fileName)
    local xTemp = 0
    if xTemp == 1 then 
        return
    end

    local file = io.open(fileName, "w")
    if file ~= nil then
        io.output(file)
        SaveTableToFile(tbl, 0)
        io.close(file)
    end
end

-- Retrieve local window options 
local function GetWindowOptions()
    local opts = { options.noMove, options.noResize, options.noTitleBar, options.AlwaysAutoResize }
    return opts
end

-- Retrieve monster counts window options
local function GetMonstersWindowOptions()
    local opts = { options.countsNoMove, options.countsNoResize, options.countsNoTitleBar, options.countsAlwaysAutoResize }
    return opts
end

-- Hack: find the index of the first map event.
-- The idea is what the person stored in the cmode_events.lua 
-- should not care if the quests have different order of floors.
-- We know they don't and won't, but it's easier to do this.
-- This is useful for stages like 1c5 and 1c6 where for some reason,
-- the floors begin at "floor number" 6 and 7, but the rest of the
-- stages do not. So generally, this will return 1.
-- It's probably a better idea to adjust those tables for those stages 
-- to have their areas be 1-based...
local function HackIBase(mapEventsForAFloor)
    local iBase = 0
    for itmp=1,memory.MaxFloors do
        if mapEventsForAFloor[itmp].waves ~= nil then
            iBase = itmp - 1
            break
        end
    end

    return iBase
end

-- Assuming 'result' is the table described in the behemoth of a comment for ReadMonsterList(),
-- insert newMonster into the table in its appropriate place. This function should handle allocating
-- the sub-tables for the result table.
local function InsertMonsterIntoResult(result, newMonster, floor)
    local resultFloor = result[floor]
    if resultFloor == nil then
        result[floor] = {}
        resultFloor = result[floor]
    end
    
    local sectionNumber = newMonster.section
    local resultSection = resultFloor[sectionNumber]
    if resultSection == nil then
        resultFloor[sectionNumber] = {}
        resultSection = resultFloor[sectionNumber]
    end

    local waveNumber = newMonster.wave
    local resultWaves = resultSection[waveNumber]
    if resultWaves == nil then
        resultSection[waveNumber] = {}
        resultWaves = resultSection[waveNumber]
    end

    debug.DebugPrint(string.format("Inserting monster %i into table for floor %i, section %i, wave %i", 
        newMonster.ID, floor, sectionNumber, waveNumber))

    table.insert(resultWaves, newMonster)
    return result
end

-- Globals for preventing work every frame.
local _CachedImguiStrings  = {}
local _CachedMapEvents     = {}
local _CachedMonsters      = {}
local _CachedEP            = -1
local _CachedQuestPtr      = -1
local _CachedCMFlag        = -1
local _CacheValid          = false

-- Check if the cache is invalid. 
-- Returns true when cache is valid, false when it's invalid.
local function ResultCacheStillValid()
    if (_CachedEP       == memory.ReadEP() and
        _CachedQuestPtr == memory.ReadQuestPtr() and
        _CachedCMFlag   == memory.ReadCMFlag() and
        _CacheValid) then
       return true
    end

    -- Cache is invalid...
    if _CacheValid then
        debug.DebugPrint("Invalid cache, falsifying it")
        _CacheValid = false
    end
    return false
end

-- Save this info to prevent constantly doing work every frame.
local function SaveResultCache(monsters, mapEvents, filteredList, imguiDisplay)
    if _CacheValid then
        return
    end

    _CacheValid         = true
    _CachedMonsters     = monsters
    _CachedMapEvents    = mapEvents
    _CachedFilterList   = filteredList
    _CachedImguiStrings = imguiDisplay
    _CachedEP           = memory.ReadEP()
    _CachedQuestPtr     = memory.ReadQuestPtr()
    _CachedCMFlag       = memory.ReadCMFlag()
    debug.DebugPrint(string.format("Saved result cache for quest %s.", memory.ReadQuestName()))
end

-- Function to read the monster list and create a resulting table.
-- The resulting table should be a table of areas. Each area is a table
-- of rooms aka sections. Each room/section is a table of waves. Each wave
-- is a table of monsters.
-- 
-- Suppose this function returns 'result'. Then...
-- 1) result[1] shall be a table for area 1. Call this 'x'.
-- 2) x[n] shall be a table of the waves in room number 'n'. Call this 'room'.
-- 3) room[i] shall be a table of the monsters in wave 'i' of room 'n' for area '1'.
-- The goal is that there should be details available at the monster level.
--
-- The result is cached as long as the state hasn't changed.
local function ReadMonsterList()
    if ResultCacheStillValid() then
        return _CachedMonsters
    end

    local result            = {}    
    local floor             = 0 -- start on P2, then advance when necessary
    local totalMonsters     = 0
    local numMonstersSoFar  = 0
    local monsterCounts
    local iMonster   
    
    -- Get the count of monsters per floor and figure out total monsters in quest.
    -- Need this to know which floors the monsters belong because EP1 CM doesn't
    -- generate those floor numbers. It's also likely those fields are useless anyway.
    monsterCounts     = memory.ReadMonsterCounts()
    for i=0,memory.MaxFloors do
        totalMonsters = totalMonsters + monsterCounts[i]
    end

    --  For each monster in the list (this includes Pioneer2 NPCs).
    for iMonster=0,totalMonsters do
        local newMonster = {}

        memory.ReadMonsterInfo(newMonster, iMonster)
        if newMonster.ID == 0xFFFF then
            break -- reached the end early?
        end

        debug.DebugMonsterInfo(newMonster.debug_addr, newMonster.memory_string)

        -- Update the floor number. Basically loop until we know
        -- exactly which floor this monster number belongs.
        -- This handles cases where floors are skipped too.
        while ((floor <= memory.MaxFloors) and 
               (iMonster >= numMonstersSoFar + monsterCounts[floor])) do
            numMonstersSoFar = numMonstersSoFar + monsterCounts[floor]
            floor = floor + 1
        end

        -- TODO: Handle bosses?

        -- Insert it into the result correctly
        InsertMonsterIntoResult(result, newMonster, floor)

        -- And move on to the next monster
        iMonster = iMonster + 1
    end

    return result
end

-- Return a list of map events. This is essentially a wrapper around ReadAllMapEvents().
local function ReadMapEvents()
    if ResultCacheStillValid() then
        return _CachedMapEvents
    end

    local result = memory.ReadAllMapEvents()
    return result
end

-- Debugging function.
local function DumpMonsterList(m)
    for i,v in pairs(m) do
        for ii,vv in pairs(v) do
            for iii,vvv in pairs(vv) do
                print(i, v, ii, vv, iii, vvv)
            end
        end
    end
end

-- Given the table of events (possibly for this area), find the one matching
-- the specified id.
local function GetEventByID(events, id)
    local result
    for iEvent,tmp in pairs(events) do
        if tmp.ID == id then
            result = tmp
            break
        end
    end
    return result
end

-- Count the waves that must be cleared in order to clear eventID.
-- The client generates additional random spawns, so it's possible
-- the starting spawn ends up chaining together events. I'm not sure
-- if there are any waves in EP1 CM that explicitly call two potentially
-- pseudorandom spawn waves. IF so, that should be handled here.
local function CountWavesForEventID(events, eventID, floor)
    local doorUnlocked = false
    local numWaves = 0

    -- Count number of waves until door unlocked.
    -- Assumptions here...
    local id       = eventID
    local stack    = {}
    local i        = 0
    local maxLoops = 100

    -- Loop until we inspect the event that unlocks this door.
    -- That event could be this one, or it could be an event
    -- generated by the client's pseudorandom spawn generator 
    -- which the event denoted by 'eventID' ultimately calls through
    -- a chain.
    while (doorUnlocked == false and i < maxLoops) do
        local thisEvent

        -- This should be true every iteration except the initial.
        if id <= 0 then
            id = table.remove(stack)
        end

        if id <= 0 then
            error(string.format(
                "Unexpected error following call graph. Incorrect map event %i for floor %i specified?", eventID, floor))
        end 
        
        thisEvent = GetEventByID(events, id)
        if thisEvent == nil then
            -- Definitely something wrong
            error(string.format("Unexpected error trying to find map event for id %i for floor %i", id, floor))
        end

        -- Clear this now. If this event does a call, the next event will be inserted onto the
        -- stack and it'll be checked from there.
        id = 0

        -- At least one more wave for this map event.
        numWaves = numWaves + 1
        for _,cv in pairs(thisEvent.clear_events) do
            if      memory.IsWaveClearUnlockType(cv.type) then
                -- Assumption: This is the goal for clearing the room.
                doorUnlocked = true
                break
            elseif memory.IsWaveClearCallType(cv.type) then
                -- Add this to the stack and we'll check them later
                table.insert(stack, cv.event)
            end
        end
        i = i + 1
    end

    -- Something went horribly wrong.
    if i >= maxLoops then
        error(string.format(
            "Infinite loop encountered in CountWavesForEventID following event ID %i", eventID))
    end

    return numWaves
end

-- Display the areas in the imgui window. Per area, display a list of the 
-- number of waves in each room on the specified path through the area.
local function DisplayAreas(monsterList, mapEvents)
    if ResultCacheStillValid() then
        -- No need to re-read and re-parse.
        for _,s in ipairs(_CachedImguiStrings) do
            imgui.Text(s)
        end
        return _CachedImguiStrings
    end

    local imguiStrings = {}
    local route        = cmode_events.GetEventsForStage(memory.ReadQuestName())
    
    --for k,v in pairs(route) do print(k,v, v.ID) end

    -- Loop through each area of the route.
    -- Figure out the waves and get the count of the spawns in each event.
    for areaNum, areaEvents in ipairs(route) do
        local formatString = string.format("Area %2i: ", areaNum)
        local areaWaves 
        local iBase = HackIBase(mapEvents)

        areaWaves = mapEvents[iBase + areaNum].waves
        if areaWaves == nil then
            error("Unexpected error determining events for this area.")
        end

        for _,eventIDToClear in ipairs(areaEvents) do
            local numWaves = CountWavesForEventID(areaWaves, eventIDToClear, areaNum)
            formatString = string.format("%s%i", formatString, numWaves)
        end 
 
        -- Can finally display it now 
        imgui.Text(formatString)

        -- Save the text string into a cache for avoiding this work next frame.
        table.insert(imguiStrings, formatString)
    end

    return imguiStrings
end

-- Helper for not displaying anything
local function NotInQuest()
    -- First some sanity checks. If these fail, no point displaying anything
    if memory.InEP1CMQuest() == false then
        debug.DebugText("Not in EP1 CM Quest")
        _CacheValid = false
        return true
    end

    debug.DebugText("In EP1 CM Quest")
    return false
end

-- Highest level of the present() code specific for this addon.
local function PresentWaveWindow()
    if NotInQuest() then
        return
    end

    -- Read the map events with caching
    local mapEvents = ReadMapEvents()

    -- Read the Monster list with caching
    local monsterList = ReadMonsterList()

    -- Display the areas and their wave counts
    imguiStrings = DisplayAreas(filteredList, mapEvents)

    -- Does nothing if cache is still valid
    SaveResultCache(monsterList, mapEvents, filteredList, imguiStrings)
end

-- Display the options
local function PresentConfigurationWindow()
    if options.configurationWindowEnable then
        ConfigurationWindow.open = true
        options.configurationWindowEnable = false
    end
    
    local configWindowChanged = false
    ConfigurationWindow.Update()
    if ConfigurationWindow.changed then
        configWindowChanged = true
        ConfigurationWindow.changed = false
        SaveOptions(options, optionsFileName)
    end
end

-- Display the "main window", which is the window showing the waves.
local function PresentMainWindow()
    -- Global enable here to let the configuration window work
    if options.enable == false then
        return
    end
        
    if options.transparentWindow == true then
        imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.0)
    end

    if options.AlwaysAutoResize == "AlwaysAutoResize" then
       imgui.SetNextWindowSizeConstraints(0, 0, options.W, options.H)
    end

    if imgui.Begin(addonName, nil, GetWindowOptions()) then
        PresentWaveWindow()
        lib_helpers.WindowPositionAndSize(addonName, options.X, options.Y, options.W, options.H, options.anchor, options.AlwaysAutoResize, configWindowChanged)
        imgui.End()
        if options.transparentWindow == true then
            imgui.PopStyleColor()
        end
    end
end

-- State for the combo boxes in this window...
local areaIndex = 1
local sectionIndex = 0
local waveIndex = 1

-- Display the monsters in each wave.
local function PresentMonstersPerWave()
    -- Nothing to do...
    if NotInQuest() then
        return
    end

    -- Get the cached monsterList and mapEvents list
    local monsterList = ReadMonsterList()
    local mapEvents   = ReadMapEvents()
    local iBase       = HackIBase(mapEvents)

    -- Get the specified route through the map events

    -- TODO: Cache these into a separate cache to prevent scouring through the tables every frame.

    local route           = cmode_events.GetEventsForStage(memory.ReadQuestName())
    local tableOfAreas    = {} -- display table for area numbers
    local tableOfSections = {} -- display table for section numbers
    local tableOfWaveNums = {} -- display table for wave numbers
    local tableOfWaves    = {} -- internal pairing with wave numbers to wave tables
    local tableOfEvents   = {} -- internal pairing with tableOfSections. Unlock event sequence starts with this event for the room.

    -- Build the display area table. Keep it nice (areas 1 to 5, not areas 7 to 11 for example)
    for i,_ in ipairs(route) do
        tableOfAreas[i] = string.format("%i", i)
    end
    
    local success

    -- Area number (1 indexed)
    imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
    success, areaIndex = imgui.Combo("Area Number", areaIndex, tableOfAreas, table.getn(tableOfAreas))
    imgui.PopItemWidth()

    -- Use the areaIndex to prepare the tables specific to that area
    local routeSections = route[areaIndex]
    if routeSections ~= nil then
        for k,v in ipairs(routeSections) do
            local event = GetEventByID(mapEvents[iBase + areaIndex].waves, v)
            table.insert(tableOfSections, event.section)
            table.insert(tableOfEvents, event)
        end
    end

    -- Get the section number for that area.
    imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
    success, sectionIndex = imgui.Combo("Section Number", sectionIndex, tableOfSections, table.getn(tableOfSections))
    imgui.PopItemWidth()
    local sectionNumber      = tableOfSections[sectionIndex]

    -- Waves aren't necessarily in wave_number order... This means the "first wave" is often not wave_number 1.
    -- So we display waves 1 and up, but internally match them nicely.
    local iWaveCounter    = 1 -- assume one
    local event           = tableOfEvents[sectionIndex]
    if event then
        local id              = event.ID

        -- Need to follow the chain of events to cover all the waves correctly.
        local stack           = {}
        local doorUnlocked    = false
        while doorUnlocked == false do
            -- Pop from the stack if second iteration
            if id <= 0 then
                id = table.remove(stack)
            end

            event = GetEventByID(mapEvents[iBase + areaIndex].waves, id)
            if event == nil then
                -- Shouldn't happen. This is a bug if it does.
                error(string.format(
                    "Event is nil for ID %i on floor number %i", id, areaIndex))
            end

            -- Got an event, so clear this and force the code to get the next one from the 'stack'.
            id = 0

            -- Save this wave's sequence number and the wave's event table.
            table.insert(tableOfWaveNums, iWaveCounter)
            table.insert(tableOfWaves, event)
            -- Follow its chain of event calls...
            for _,v in pairs(event.clear_events) do
                if     memory.IsWaveClearUnlockType(v.type) then
                    doorUnlocked = true
                elseif memory.IsWaveClearCallType(v.type) then
                    table.insert(stack, v.event)
                end
            end

            -- Saw a wave so increment counter
            iWaveCounter = iWaveCounter + 1
        end
    end
    
    -- Get the displayed wave number. Here, waveIndex 1 means the first wave, which is *not* necessarily wave_number 1.
    imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
    success, waveIndex = imgui.Combo("Wave Number", waveIndex, tableOfWaveNums, table.getn(tableOfWaveNums))
    imgui.PopItemWidth()

    -- Now display the monsters for this wave in this room in this area.
    -- Map the specified wave sequence to the real wave to get the actual wave number.
    -- Then, look up the monsters from the 'monsterList' using the area number and section number.
    -- This is rather cautious. 
    local waveMonsters = {}
    if (waveIndex > 0 and tableOfWaveNums[waveIndex] ~= nil) then
        local desiredWave        = tableOfWaves[waveIndex]
        if desiredWave ~= nil then
            local mapEventWaveNumber = desiredWave.wave
            local areaMonsters       = monsterList[areaIndex + iBase]
            if areaMonsters then
                local sectionMonsters    = areaMonsters[sectionNumber]
                waveMonsters             = sectionMonsters[mapEventWaveNumber]
            end
        end
    end

    -- And finally display the monsters 
    if options.countsIndividual then
        -- Show each monster individually (probably not very useful)
        for _,monster in pairs(waveMonsters) do
            local s = ""
            -- What else would be useful here? Unfortunately the X, Y, Z positioning
            -- isn't very useful unless you know the room's orientation.
            if options.countsDebug then
                s = string.format("%s (%i,%i): (%i, %i, %i)", 
                        monster.name, monster.ID, monster.params[6], 
                        monster.x, monster.y, monster.z)
            else
                s = string.format("%s: (%i, %i, %i)",
                        monster.name, monster.x, monster.y, monster.z)
            end
            imgui.Text(s)
        end
    else
        -- Count the monsters. Map "name" -> "count" in this wave.
        local uniqueCounts = {}
        for _,monster in pairs(waveMonsters) do
            if uniqueCounts[monster.name] == nil then
                uniqueCounts[monster.name] = 0
            end
            uniqueCounts[monster.name] = uniqueCounts[monster.name] + 1
        end

        -- Display the counts of each unique monster type in this wave.
        for name,count in pairs(uniqueCounts) do
            local s = string.format("%s: %i", name, count)
            imgui.Text(s)
        end
    end
end

-- Present the monsters window
local function PresentMonstersWindow()
    -- Global enable here to let the configuration window work
    if options.countsEnable == false then
        return
    end

    if options.countsTransparentWindow == true then
        imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.0)
    end

    if options.countsAlwaysAutoResize == "AlwaysAutoResize" then
       imgui.SetNextWindowSizeConstraints(0, 0, options.W, options.H)
    end

    windowName = addonName .. " Monsters"
    if imgui.Begin(windowName, nil, GetMonstersWindowOptions()) then
        PresentMonstersPerWave()
        lib_helpers.WindowPositionAndSize(windowName, options.countsX, options.countsY, options.countsW, options.countsH, 
                                          options.countsAnchor, options.countsAlwaysAutoResize, configWindowChanged)
        imgui.End()
        if options.countsTransparentWindow == true then
            imgui.PopStyleColor()
        end
    end
end

-- Top level present() with options checks.
local function present()
    -- Show configuration window if it's enabled.
    PresentConfigurationWindow()

    -- Show the main window, which is the waves per area window.
    PresentMainWindow()

    -- Show the monsters window which shows the monsters for specified wave.
    PresentMonstersWindow()
end

-- After reading options, verify they're okay.
if optionsLoaded then
    -- Make sure everything is okay or else configuration will break.
    for _, opt in pairs(_EP1CMReaderOptionsDefaults) do
        options[opt[1]] = lib_helpers.NotNilOrDefault(options[opt[1]], opt[2])
    end
else
    options = {}
    for _, opt in pairs(_EP1CMReaderOptionsDefaults) do
        options[opt[1]] = opt[2]
    end
    
    -- We just created the options, so we should save to have valid file
    SaveOptions(options, optionsFileName) 
end

-- Initialization routine that creates the config window and adds the 
-- button to the main addon_list menu.
local function init()
    ConfigurationWindow = cfg.ConfigurationWindow(options, addonName)

    local function mainMenuButtonHandler()
        ConfigurationWindow.open = not ConfigurationWindow.open
    end
    
    core_mainmenu.add_button(addonName, mainMenuButtonHandler)
    
    return 
    {
        name = 'EP1 CM Reader',
        version = '0.1.0',
        author = 'Ender',
        present = present,
        toggleable = true,
    }
end

return 
{
    __addon = 
    {
        init                      = init,
    },
}
