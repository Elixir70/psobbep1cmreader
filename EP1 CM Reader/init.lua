-- EP1 CM Reader -- Addon that reads the monster list from the client's memory and uses a specified route to show
--                  the number of waves per room on the route. The addon can also display the
--                  individual monsters in each wave.

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
    {"enable", false},                         -- Is this enabled?
    {"spaceSpawns", true},                     -- Put a space between the numbers?
    {"currentWavesColorR", 0xFF},              -- Current waves color (red) in the main window.
    {"currentWavesColorG", 0xFF},              -- Current waves color (green) in the main window.
    {"currentWavesColorB", 0xFF},              -- Current waves color (blue) in the main window.
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

-- Wrapper around imgui.Text for a table
local function DisplayTextStrings(t)
    for _,s in ipairs(t) do
        imgui.Text(s)
    end
end

-- Hack: find the index of the first map event.
-- The idea is what the person stored in the cmode_events.lua 
-- should not care if the quests have different order of floors.
-- We know they don't and won't, but it's easier to do this.
-- This is useful for stages like 1c5 and 1c6 where for some reason,
-- the floors begin at "floor number" 6 and 7, but the rest of the
-- stages do not. This usually returns 1.
-- It's probably a better idea to adjust those tables for those stages 
-- to have their areas be converted to floor numbers be 1-based...
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
    -- Get the tables for this floor
    local resultFloor = result[floor]
    if resultFloor == nil then
        result[floor] = {}
        resultFloor = result[floor]
    end
    
    -- Get the tables for the monster's section
    local sectionNumber = newMonster.section
    local resultSection = resultFloor[sectionNumber]
    if resultSection == nil then
        resultFloor[sectionNumber] = {}
        resultSection = resultFloor[sectionNumber]
    end

    -- Get the tables for all the monsters in the wave.
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

-- Globals for preventing work every frame for the main window.
local _CachedImguiStringsMain  = {}
local _CachedMapEvents         = {}
local _CachedMonsters          = {}
local _CachedEP                = -1
local _CachedQuestPtr          = -1
local _CachedCMFlag            = -1
local _CacheValid              = false

-- State for the combo boxes in the monsters window.
local floorIndex               = 0
local sectionIndex             = 0
local waveIndex                = 0

-- Check if the cache is invalid. 
-- Returns true when cache is valid, false when it's invalid.
local function MemoryCacheStillValid()
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
local function SaveMemoryCache(monsters, mapEvents, filteredList, imguiDisplay)
    if _CacheValid then
        return
    end

    _CacheValid             = true
    _CachedMonsters         = monsters
    _CachedMapEvents        = mapEvents
    _CachedFilterList       = filteredList
    _CachedImguiStringsMain = imguiDisplay
    _CachedEP               = memory.ReadEP()
    _CachedQuestPtr         = memory.ReadQuestPtr()
    _CachedCMFlag           = memory.ReadCMFlag()
    debug.DebugPrint(string.format("Saved result cache for quest %s.", memory.ReadQuestName()))
end

-- Function to read the monster list and create a resulting table.
-- The resulting table should be a table of floors. Each floor is a table
-- of rooms aka sections. Each room/section is a table of waves. Each wave
-- is a table of monsters.
-- 
-- Suppose this function returns 'result'. Then...
-- 1) result[1] shall be a table for floor 1. Call this 'x'.
-- 2) x[n] shall be a table of the waves in room number 'n'. Call this 'room'.
-- 3) room[i] shall be a table of the monsters in wave 'i' of room 'n' for floor '1'.
-- The goal is that there should be details available at the monster level.
--
-- The result is cached as long as the state hasn't changed.
local function ReadMonsterList()
    if MemoryCacheStillValid() then
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
    monsterCounts = memory.ReadMonsterCounts()
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

        -- Insert it into the result correctly
        InsertMonsterIntoResult(result, newMonster, floor)

        -- And move on to the next monster
        iMonster = iMonster + 1
    end

    return result
end

-- Return a list of map events. This is essentially a wrapper around ReadAllMapEvents().
local function ReadMapEvents()
    if MemoryCacheStillValid() then
        return _CachedMapEvents
    end

    return memory.ReadAllMapEvents()
end

-- Given the table of events, find the one matching
-- the specified id.
local function GetEventByID(events, id)
    local result
    for _,tmp in pairs(events) do
        if tmp.ID == id then
            result = tmp
            break
        end
    end
    return result
end

-- Loop until we inspect the event that unlocks this door.
-- That event could be this one, or it could be an event
-- generated by the client's pseudorandom spawn generator 
-- which the event denoted by 'eventID' ultimately calls through
-- a chain.
local function FollowEventCalls(events, id, predicate, iterator, debugFloor)
    local stack    = {}
    local i        = 0
    local maxLoops = 100

    while (predicate() and i < maxLoops) do
        local thisEvent
        
        -- This should be true every iteration except the initial.
        if id <= 0 then
            id = table.remove(stack)
            -- TODO: Could this ever return nil? Don't think so..
        end

        if id <= 0 then
            error(string.format(
                "Unexpected error following call graph. Incorrect map event %i for floor %i specified?", eventID, debugFloor))
        end 

        thisEvent = GetEventByID(events, id)
        if thisEvent == nil then
            -- Definitely something wrong
            error(string.format("Unexpected error trying to find map event for id %i for floor %i", id, debugFloor))
        end

        -- Clear this now. If this event does a call, the next event will be inserted onto the
        -- stack and it'll be checked from there.
        id = 0

        iterator(thisEvent)
        for _,cv in pairs(thisEvent.clear_events) do
            if memory.IsWaveClearCallType(cv.type) then
                -- Add this to the stack and we'll check them later
                table.insert(stack, cv.event)
            end
        end

        -- Next iteration
        i = i + 1
    end

    -- Something went horribly wrong.
    if i >= maxLoops then
        error(string.format(
            "Infinite loop encountered in CountWavesForEventID following event ID %i", eventID))
    end
end

-- Count the waves that must be cleared in order to clear eventID.
-- The client generates additional random spawns, so it's possible
-- the starting spawn ends up chaining together events. I'm not sure
-- if there are any waves in EP1 CM that explicitly call two potentially
-- pseudorandom spawn waves. IF so, that should be handled here.
local function CountWavesForEventID(events, eventID, floor)
    local doorUnlocked = false
    local numWaves = 0

    -- Callbacks for FollowEventCalls traversal
    local fPredicate = function() 
        return (doorUnlocked == false) 
    end
    local fIterator  = function(thisEvent) 
        numWaves = numWaves + 1
        for _,cv in pairs(thisEvent.clear_events) do
            if memory.IsWaveClearUnlockType(cv.type) then
                -- Assumption: This is the goal for clearing the room.
                doorUnlocked = true
                break
            end
        end
    end

    FollowEventCalls(events, eventID, fPredicate, fIterator, floor)

    return numWaves 
end

local function StringSplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end

    local t = {}

    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

-- From the DisplayFloors() strings, color my room correctly.
local function DisplayFloorStringsWithColor(strings, mapEvents)
    local myFloor      = memory.ReadMyPlayerFloor()
    local iBase        = HackIBase(mapEvents)
    local myFloorIndex = myFloor - iBase
    local route        = cmode_events.GetEventsForStage(memory.ReadQuestName())

    -- Shouldn't happen but no harm being cautious.
    if (myFloorIndex <= 0 or myFloorIndex > table.getn(route)) then
        DisplayTextStrings(strings)
        return
    end

    -- Display preceeding floors.
    for i=1,myFloorIndex-1 do
        imgui.Text(strings[i])
    end

    -- We're on this floor. Copy the rooms and then color ours correctly.
    local floorRoute = route[myFloorIndex]
    local mySection  = memory.ReadMyPlayerRoom()
    local split1     = StringSplit(strings[myFloorIndex], ":")
    local split2     = StringSplit(split1[2], " ")

    -- Figure out which spot in the string of waves
    local myRoomIdx  = 0
    for i,eventNum in pairs(floorRoute) do
        local event = GetEventByID(mapEvents[myFloor].waves, eventNum)
        if event.section == mySection then
            myRoomIdx = i
            break
        end
    end

    -- Build new string for this floor with color for the current room.
    -- First display the "Floor %i:" 
    imgui.Text(string.format("%s: ", split1[1]))
    if table.getn(floorRoute) > 0  then
        imgui.SameLine(0, 0)
    end

    -- Now display each of the wave counts.
    for tmp=1,table.getn(floorRoute) do
        local s = string.format("%s ", split2[tmp])
        if tmp == myRoomIdx then
            -- Player is in this room. Color it appropriately.
            imgui.SameLine(0, 0)
            imgui.TextColored(options.currentWavesColorR / 0xFF, 
                              options.currentWavesColorG / 0xFF, 
                              options.currentWavesColorB / 0xFF, 
                              0xFF / 0xFF,
                              s)
       else
            imgui.SameLine(0, 0)
            imgui.Text(s)
        end
    end

    -- Any extra fields (extra spawns for the floor)
    for i=table.getn(floorRoute)+1,table.getn(split2) do
        imgui.SameLine(0, 0)
        imgui.Text(split2[i])
    end
    
    -- Display proceeding floors.
    for i=myFloorIndex+1,table.getn(route) do
        imgui.Text(strings[i])
    end

    -- Any additional strings (total extra spawns)
    for i=table.getn(route)+1, table.getn(strings) do
        imgui.Text(strings[i])
    end
end

-- Display the floors in the imgui window. Per floor, display a list of the 
-- number of waves in each room on the specified path through the floor.
local function DisplayFloors(filteredList, mapEvents)
    if (MemoryCacheStillValid() and
        ConfigurationWindow.spaceSpawns == _CachedSpaceSpawns) then
        -- No need to re-read and re-parse.
        DisplayFloorStringsWithColor(_CachedImguiStringsMain, mapEvents)
        return _CachedImguiStringsMain
    end

    local imguiStrings = {}
    local route        = cmode_events.GetEventsForStage(memory.ReadQuestName())
    local questExtraSpawns  = 0

    -- Loop through each floor of the route.
    -- Figure out the waves and get the count of the spawns in each event.
    for floorNum, floorEvents in ipairs(route) do
        local formatString = string.format("Floor %2i: ", floorNum)
        local floorWaves 
        local floorExtraSpawns = 0
        local iBase = HackIBase(mapEvents)

        floorWaves = mapEvents[iBase + floorNum].waves
        if floorWaves == nil then
            error("Unexpected error determining events for this floor.")
        end

        for _,eventIDToClear in ipairs(floorEvents) do
            local numWaves  = CountWavesForEventID(floorWaves, eventIDToClear, floorNum)
            local separator = ""

            if options.spaceSpawns then
                separator = " "
            end

            formatString = string.format("%s%i%s", formatString, numWaves, separator)
            if numWaves >= 1 then
                floorExtraSpawns  = floorExtraSpawns  + numWaves - 1
            end
        end 
 
        formatString = string.format("%s(+%i)", formatString, floorExtraSpawns)


        -- Save the text string into a cache for avoiding this work next frame.
        table.insert(imguiStrings, formatString)

        questExtraSpawns = questExtraSpawns + floorExtraSpawns
    end

    local questExtraSpawnsString = string.format("+%i Spawns", questExtraSpawns)
    table.insert(imguiStrings, questExtraSpawnsString)
    DisplayFloorStringsWithColor(imguiStrings, mapEvents)
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

-- Create a new monster list for the stage that only contains those which spawn
local function FilterMonsterList(monsterList, mapEvents)
    if ((monsterList == nil or mapEvents == nil) and MemoryCacheStillValid()) then
        return _CachedFilterList
    end
    
    local result = {}
    local iBase = HackIBase(mapEvents)
    local route = cmode_events.GetEventsForStage(memory.ReadQuestName())

    for iFloor=1,table.getn(route) do
        local floorMonsters         = monsterList[iBase + iFloor]
        local filteredFloorMonsters = {}
        local floorEvents           = mapEvents[iBase + iFloor].waves
        local routeEventNums        = route[iFloor]

        result[iBase + iFloor] = filteredFloorMonsters -- consistent with monsterList ...

        -- For each event on this floor, follow the event in its section
        -- and add each event's corresponding monsters to the result list.
        for _,eventNum in ipairs(routeEventNums) do
            local event = GetEventByID(floorEvents, eventNum)
            if event then
                local sectionMonsters         = floorMonsters[event.section]
                local filteredSectionMonsters = {} 
                local doorUnlocked            = false
                local numWaves                = 0

                filteredFloorMonsters[event.section] = filteredSectionMonsters

                -- Callbacks for FollowEventCalls traversal
                local fPredicate = function() 
                    return (doorUnlocked == false) 
                end

                local fIterator  = function(thisEvent) 
                    -- Move the table of monsters for this wave in the section into the filtered
                    -- list for the section.
                    table.insert(filteredSectionMonsters, sectionMonsters[thisEvent.wave])

                    for _,cv in pairs(thisEvent.clear_events) do
                        if memory.IsWaveClearUnlockType(cv.type) then
                            -- Assumption: This is the goal for clearing the room.
                            doorUnlocked = true
                            break
                        end
                    end
                end
                
                -- Follow the event through to completing the room.
                FollowEventCalls(floorEvents, eventNum, fPredicate, fIterator, iFloor)
            end
        end
    end    

    -- At this point, result is the same as monsterList except the waves are in order
    -- according to the random spawn generation.
    return result
end

local function GetFilterMonsterList(monsterList, mapEvents)
    if MemoryCacheStillValid() then
        return _CachedFilterList
    end

    return FilterMonsterList(monsterList, mapEvents)
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

    -- Filter out only monsters that actually spawn
    local filteredList = GetFilterMonsterList(monsterList, mapEvents)

    -- Display the floors and their wave counts
    imguiStrings = DisplayFloors(filteredList, mapEvents)

    -- Does nothing if cache is still valid
    SaveMemoryCache(monsterList, mapEvents, filteredList, imguiStrings)
end

-- Display the options
local function PresentConfigurationWindow()
    local configWindowChanged = false
    
    if options.configurationWindowEnable then
        ConfigurationWindow.open = true
        options.configurationWindowEnable = false
    end
    
    ConfigurationWindow.Update()
    if ConfigurationWindow.changed then
        configWindowChanged = true
        ConfigurationWindow.changed = false
        ConfigurationWindow.SaveOptions(options, optionsFileName)
    end

    return configWindowChanged
end

-- Display the "main window", which is the window showing the waves.
local function PresentMainWindow(cfgWindowChanged)
    if options.enable == false then
        return
    end
        
    if options.transparentWindow == true then
        imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.0)
    end

    if options.AlwaysAutoResize == "AlwaysAutoResize" then
       imgui.SetNextWindowSizeConstraints(0, 0, options.W, options.H)
    end

    if imgui.Begin(addonName, nil, ConfigurationWindow.GetWindowOptions()) then
        PresentWaveWindow()
        lib_helpers.WindowPositionAndSize(addonName, options.X, options.Y, options.W, options.H, 
                                          options.anchor, options.AlwaysAutoResize, cfgWindowChanged)
        imgui.End()
        if options.transparentWindow == true then
            imgui.PopStyleColor()
        end
    end
end

-- Shallow copy
local function CloneTable(t)
    local result = {}
    for k,v in pairs(t) do
        result[k] = v
    end
    return result
end

-- Counts window below.

local function DisplayMonsterCounts(monsterCount)
    -- Sort 
    local tkeys = {}
    for k,_ in pairs(monsterCount) do
        table.insert(tkeys, k)
    end
    table.sort(tkeys)

    for _,uid in ipairs(tkeys) do
        local count = monsterCount[uid]
        local name  = memory.GetMonsterNameByUnitxtID(uid)
        local s     = string.format("%s: %i", name, count)
        imgui.Text(s)
    end
end

-- Count monsters in the filtered table of waves.
local function CountMonstersInWave(floorNum, sectionNum, waveNum, monsterCount)
    local filteredMonsters        = GetFilterMonsterList()
    local mapEvents               = ReadMapEvents()
    local iBase                   = HackIBase(mapEvents)
    local filteredFloorMonsters   = filteredMonsters[iBase + floorNum] or {}
    local filteredSectionMonsters = filteredFloorMonsters[sectionNum] or {}
    local filteredWaveMonsters    = filteredSectionMonsters[waveNum] or {}

    for _,monster in pairs(filteredWaveMonsters) do
        local uid = memory.GetUnitxtID(monster)
        monsterCount[uid] = (monsterCount[uid] or 0) + 1
    end
end

-- Count monsters in the filtered table of sections.
local function CountMonstersInSection(floorNum, sectionNum, monsterCount)
    local filteredMonsters        = GetFilterMonsterList()
    local mapEvents               = ReadMapEvents()
    local iBase                   = HackIBase(mapEvents)
    local filteredFloorMonsters   = filteredMonsters[iBase + floorNum] or {}
    local filteredSectionMonsters = filteredFloorMonsters[sectionNum] or {}

    for waveNum,waveMonsters in pairs(filteredSectionMonsters) do
        CountMonstersInWave(floorNum, sectionNum, waveNum, monsterCount)
    end
end

-- Count monsters in all sections of a floor number.
local function CountMonstersInFloor(floorNum, monsterCount)
    local filteredMonsters      = GetFilterMonsterList()
    local mapEvents             = ReadMapEvents()
    local iBase                 = HackIBase(mapEvents)
    local filteredFloorMonsters = filteredMonsters[iBase + floorNum] or {}

    for sectionNum,sectionMonsters in pairs(filteredFloorMonsters) do
        CountMonstersInSection(floorNum, sectionNum, monsterCount)
    end
end

-- Display totals for one wave
local function PresentCountsForWave(floorNum, sectionNum, waveNum)
    local monsterCount = {}

    CountMonstersInWave(floorNum, sectionNum, waveNum, monsterCount)
    DisplayMonsterCounts(monsterCount)
end

-- Display totals of all enemies in one room.
local function PresentCountsForSection(floorNum, sectionNum)
    local monsterCount = {}
    CountMonstersInSection(floorNum, sectionNum, monsterCount)
    DisplayMonsterCounts(monsterCount)
end

-- Display totals of all enemies on the route in this floor.
local function PresentCountsForFloor(floorNum)
    local monsterCount = {}

    CountMonstersInFloor(floorNum, monsterCount)
    DisplayMonsterCounts(monsterCount)
end

-- Display totals of all enemies on the route.
local function PresentCountsTotal()
    local route                = cmode_events.GetEventsForStage(memory.ReadQuestName())
    local monsterCount         = {}

    for iFloor=1,table.getn(route) do
        CountMonstersInFloor(iFloor, monsterCount)
    end
    DisplayMonsterCounts(monsterCount)
end

-- Display the individual monsters in a wave.
local function PresentCountsIndividualForWave(waveMonsters)
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
end

-- Display the monsters in each wave.
local function PresentCounts()
    -- Common helper function.
    local PresentMonstersComboBox        = function(description, index, tbl, numItems)
        local success 
        imgui.PushItemWidth(0.25 * imgui.GetWindowWidth())
        success, index = imgui.Combo(description, index, tbl, numItems)
        imgui.PopItemWidth()
        return success, index
    end

    local PresentCountsFloorComboBox    = function(tableOfFloors, index)
        return PresentMonstersComboBox("Floor Number", index, tableOfFloors, table.getn(tableOfFloors))
    end
    
    local PresentCountsSectionComboBox = function(tableOfSections, index)
        return PresentMonstersComboBox("Section Number", index, tableOfSections, table.getn(tableOfSections))
    end
    
    local PresentCountsWaveComboBox    = function(tableOfWaves, index)
        return PresentMonstersComboBox("Wave Number", index, tableOfWaves, table.getn(tableOfWaves))
    end

    -- Nothing to do...
    if NotInQuest() then
        return
    end

    -- Get the cached monsterList and mapEvents list
    local filteredMonsters = GetFilterMonsterList()
    local mapEvents        = ReadMapEvents()
    local iBase            = HackIBase(mapEvents)
    
    -- TODO: Cache these into a separate cache to prevent scouring through the tables every frame.

    local route                   = cmode_events.GetEventsForStage(memory.ReadQuestName())
    local tableOfFloors           = {} -- table for floor numbers
    local tableOfSections         = {} -- table for section numbers
    local tableOfWaveNums         = {} -- table for wave numbers
    local success

    -- Build the display floor table. Keep it nice (floors 1 to 5, not floors 7 to 11 for example)
    for i,_ in ipairs(route) do
        table.insert(tableOfFloors, i)
    end

    -- Allow selecting all floors
    if not options.countsIndividual then
        table.insert(tableOfFloors, "All")
        table.insert(tableOfFloors, "Current")
    end

    -- Floor number (1 indexed)
    success, floorIndex = PresentCountsFloorComboBox(tableOfFloors, floorIndex)
    if tableOfFloors[floorIndex] == nil then
        return
    end

    if tableOfFloors[floorIndex] == "All" then
        -- User wants to display all monsters in quest
        PresentCountsTotal()
        return
    end

     if tableOfFloors[floorIndex] == "Current" then
        -- User wants to display current monsters on floor
        PresentCountsForFloor(memory.ReadMyPlayerFloor() - iBase)
        return
    end 

    local floorNumber  = tableOfFloors[floorIndex]
    local routeEvents = route[floorIndex]
    if routeEvents == nil then
        -- Sanity
        return
    end

    -- Get the sections
    for _,routeEvent in ipairs(routeEvents) do
        local event = GetEventByID(mapEvents[iBase + floorIndex].waves, routeEvent)
        table.insert(tableOfSections, event.section)
    end

    -- Allow selecting all sections in an floor
    if not options.countsIndividual then
        table.insert(tableOfSections, "All")
        --table.insert(tableOfSections, "Current")
    end

    local mapEventsForFloor = mapEvents[iBase + floorIndex].waves
    success, sectionIndex = PresentCountsSectionComboBox(tableOfSections, sectionIndex)
    if tableOfSections[sectionIndex] == nil then
        return
    end

    if tableOfSections[sectionIndex] == "All" then
        -- User wants to display all monsters for a floor
        PresentCountsForFloor(floorIndex)
        return
    end
--[[     if tableOfSections[sectionIndex] == "Current" then
        -- Convert to floor index...
        PresentCountsForSection(floorNumber, memory.ReadMyPlayerRoom())
        return
    end ]]

    local sectionNumber            = tableOfSections[sectionIndex]
    local filteredFloorMonsters    = filteredMonsters[iBase + floorIndex]
    local filteredSectionMonsters  = filteredFloorMonsters[sectionNumber]
    for k,_ in pairs(filteredSectionMonsters) do
        table.insert(tableOfWaveNums, k)
    end

    -- Allow selecting all waves in a room
    if not options.countsIndividual then
        table.insert(tableOfWaveNums, "All")
    end

    -- Get the displayed wave number. Here, waveIndex 1 means the first wave, which is *not* necessarily wave_number 1.
    success, waveIndex = PresentCountsWaveComboBox(tableOfWaveNums, waveIndex)
    if tableOfWaveNums[waveIndex] == nil then
        return
    end

    if tableOfWaveNums[waveIndex] == "All" then
        -- User wants to see everything in a room
        PresentCountsForSection(floorNumber, sectionNumber)
        return
    end

    -- Otherwise, they want a specific wave.
    local waveMonsters = filteredSectionMonsters[tableOfWaveNums[waveIndex]]
    if options.countsIndividual then
        PresentCountsIndividualForWave(waveMonsters)
    else
        PresentCountsForWave(floorNumber, sectionNumber, tableOfWaveNums[waveIndex])
    end
end

-- Present the counts window.
local function PresentCountsWindow(cfgWindowChanged)
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

    windowName = addonName .. " Counts"
    if imgui.Begin(windowName, nil, ConfigurationWindow.GetMonstersWindowOptions()) then
        PresentCounts()
        lib_helpers.WindowPositionAndSize(windowName, options.countsX, options.countsY, options.countsW, options.countsH, 
                                          options.countsAnchor, options.countsAlwaysAutoResize, cfgWindowChanged)
        imgui.End()
        if options.countsTransparentWindow == true then
            imgui.PopStyleColor()
        end
    end
end

-- Top level present() with options checks.
local function present()
    local cfgWindowChanged

    -- Show configuration window if it's enabled.
    cfgWindowChanged = PresentConfigurationWindow()

    -- Need to have the base wave window enabled in order to display anything.
    -- Sorry, but there's some dependencies on the caching that will be resolved 
    -- eventually.
    if not options.enable then
        return
    end

    -- Show the main window, which is the waves per floor window.
    PresentMainWindow(cfgWindowChanged)

    -- Show the monsters window which shows the monsters for specified wave.
    PresentCountsWindow(cfgWindowChanged)
end

-- After reading options, verify they're okay.
if optionsLoaded and type(options) == "table" then
    -- Make sure everything is okay or else configuration will break.
    for _, opt in pairs(_EP1CMReaderOptionsDefaults) do
        options[opt[1]] = lib_helpers.NotNilOrDefault(options[opt[1]], opt[2])
    end
else
    -- Either no options.lua or an error opening it. Setup the defaults.
    options = {}
    for _, opt in pairs(_EP1CMReaderOptionsDefaults) do
        options[opt[1]] = opt[2]
    end
    -- Not saving the options here... Will be done when they change.
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
        version = '0.3.0',
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
