local lib_unitxt                  = require("solylib.unitxt")

-- Quest Data
local _QuestPtr            = 0xA95AA8
local _QuestDataOffset     = 0x19C
local _QuestDataNameOffset = 0x18
local _QuestDataNumOffset  = 0x10

-- Simple values
local _Episode             = 0xA9B1C8
local _CModeFlag           = 0xA49508
local _PlayerCount         = 0xAAE168
local _Difficulty          = 0xA9CD68
local _FloorNumber         = 0xAAFCA0
local _MyPlayerIndex       = 0xA9C4F4
local _PlayerClassPointers = 0xA94254

-- Player struct info
local _ID                  = 0x1C
local _Room                = 0x28
local _Room2               = 0x2E

-- Stuff loaded from quest file
local _MonsterList         = 0xAB0214 -- already filled in by time the quest finishes loading
local _MonsterListCounts   = 0xAAFF60 -- array of number of monsters on each floor
local _ObjectList          = 0xAB0210 -- the objects you see in qedit
local _ObjectListCounts    = 0xAAFF00 -- array of number of objects on each floor
local _MapEventsPtrArray   = 0xAAFE00 -- array of pointers to the map events for each floor

-- Info about the monster structures
local _MonsterIDOffset        = 0x0
local _MonsterFloorOffset     = 0x08
local _MonsterSectionOffset   = 0x0C
local _MonsterWaveOffset      = 0x0E
local _MonsterXOffset         = 0x014
local _MonsterYOffset         = 0x018
local _MonsterZOffset         = 0x1C
local _MonsterParam1          = 0x2C
local _MonsterParam2          = 0x30
local _MonsterParam3          = 0x34
local _MonsterParam4          = 0x38
local _MonsterParam5          = 0x3C
local _MonsterParam6          = 0x40

-- Offsets for the Wave Header
local _WaveHdrByteSizeOffset = 0
local _WaveHdrHdrSizeOffset  = 4
local _WaveHdrNumWavesOffset = 8
local _WaveHdrZeroOffset     = 12

-- Offsets for the Wave structure
local _WaveIDOffset          = 0
local _WaveSectionOffset     = 8
local _WaveWaveNumberOffset  = 10
local _WaveDelayOffset       = 12 
local _WaveMinEnemiesOffset  = 16 -- from the extra 4 bytes in the EP1 CM wave structure in quest file
local _WaveMaxEnemiesOffset  = 17 -- from the extra 4 bytes in the EP1 CM wave structure in quest file
local _WaveMaxWavesOffset    = 18 -- from the extra 4 bytes in the EP1 CM wave structure in quest file
local _WaveZeroOffset        = 19 -- from the extra 4 bytes in the EP1 CM wave structure in quest file
local _WaveClearIdxOffset    = 20

-- Constants
local _WaveSizeEP1CM       = 24   -- this is true only for the events on disk. They become 20 bytes in memory.
local _WaveSizeNormal      = 20   
local _WaveClearDelimiter  = 0x01 -- End of wave clear events
local _WaveClearUnlock     = 0x0a -- "Unlock <door>"
local _WaveClearLock       = 0x0b -- "Lock <door>" ???
local _WaveClearStartEvent = 0x0c -- "Call <event>"
local _WaveClearUnhide     = 0x08 -- "Unhide <floor> <appear_flag>"
   
local _MaxFloors           = 14 -- ???

-- Monster base skin # => table of unitxt values.
-- EP1 Only...
local _MonsterIDToUnitxtID = {
    -- Forest
    [64]   = { 1, 2 },       -- Hildebear/Hildeblue
    [66]   = { 3, 4 },       -- Mothmant/Monest
    [65]   = { 5, 6 },       -- Rag Rappy/Al Rappy
    [67]   = { 7, 8 },       -- Savage Wolf/Barbarous Wolf
    [68]   = { 9, 10, 11 },  -- Booma/Gobooma/Gigobooma

    -- Caves
    [96]   = { 12 },         -- Grass Assassin
    [97]   = { 13, 14 },     -- Poison Lily/Nar Lily
    [98]   = { 15 },         -- Nano Dragon
    [99]   = { 16, 17, 18 }, -- Evil Shark/Pal Shark/Guil Shark
    [100]  = { 19, 20 },     -- Pofuilly Slim/Pouilly Slime
    [101]  = { 21, 22, 23 }, -- Pan Arms/Migium/Hidoom

    -- Mines
    [128]  = { 24, 50 },     -- Dubchic/Gilchic
    [129]  = { 25 },         -- Garanz
    [130]  = { 26, 27 },     -- Sinow Beat/Sinow Gold
    [131]  = { 28 },         -- Canadine
    [132]  = { 29 },         -- Canane
    [133]  = { 49 },         -- Dubwitch

    -- Ruins
    [160]  = { 30 },         -- Delsaber
    [161]  = { 31, 32, 33 }, -- Chaos Sorcerer//Bee R/Bee L
    [162]  = { 34 },         -- Dark Gunner
    [163]  = { 35 },         -- Death Gunner
    [164]  = { 36 },         -- Dark Bringer
    [165]  = { 37 },         -- Indi Belra
    [166]  = { 41, 42, 43 }, -- Dimenian/La Dimenian/So Dimenian
    [167]  = { 40 },         -- Bulclaw
    [168]  = { 38 },         -- Claw

    -- Unknown container
    [48]   = { 0 },
}

-- monster.ID => param number if it has a sub type
local _SkinToSubtypeParamIdx = {
    [68]    =  6,  -- Booma/Gobooma/Gigobooma
    [99]    =  6,  -- Evil Shark/Pal Shark/Guil Shark
    [128]   =  6,  -- Dubchic/Gilchic
    [130]   =  2,  -- Sinow Beat/Sinow Gold
    [166]   =  6,  -- Dimenian/La Dimenian/So Dimenian
}

local function ReadPlayerArray()
    return _PlayerClassPointers
end

local function ReadPlayer(idx)
    local p     = ReadPlayerArray()
    return pso.read_u32(p + 4 * idx)
end

local function ReadMyPlayerIndex()
    return pso.read_u32(_MyPlayerIndex)
end

local function ReadMyPlayer()
    local myIdx = ReadMyPlayerIndex()
    return ReadPlayer(myIdx)
end

local function ReadPlayerRoom(idx)
    local p = ReadPlayer(idx)
    return pso.read_u32(p + _Room)
end

local function ReadMyPlayerRoom()
    local myIdx = ReadMyPlayerIndex()
    return ReadPlayerRoom(myIdx)
end

local function ReadMyPlayerFloor()
    return pso.read_u32(_FloorNumber)
end

-- Read the monster.ID field and determine what is the proper parameter
-- in the monster data for the sub type field.
local function GetMonsterSubtype(monster)
    local result = 0
    local entry  = _SkinToSubtypeParamIdx[monster.ID]
    if entry ~= nil then
        result = monster.params[entry]
    end
    return result
end

-- Convert the monster skin and subType into its unitxt ID.
local function GetUnitxtID(monster)
    local result = 48
    local entry = _MonsterIDToUnitxtID[monster.ID]
    if entry then
        local subTypeIndex = GetMonsterSubtype(monster) + 1 -- lua arrays 1-indexed
        if entry[subTypeIndex] then
            result = entry[subTypeIndex]
        end
    end
    return result
end

-- Get monster name by its uid.
local function GetMonsterNameByUnitxtID(uid)
    return lib_unitxt.GetMonsterName(uid, pso.read_u32(_Difficulty) == 3)
end

-- Get the name for the monster by converting its ID and subtype appropriately.
local function GetMonsterName(monster)
    local unitxtID = GetUnitxtID(monster)
    if unitxtID > 0 then
        return lib_unitxt.GetMonsterName(unitxtID, pso.read_u32(_Difficulty) == 3)
    end
    return "<unknown>"
end

-- Helper function to copy from memory into a lua table indexed as an array.
local function _CopyArrayOfDWORDS(result, ptr)
    for i=0,_MaxFloors do
        if ptr ~= 0 then
            result[i] = pso.read_u32(ptr + i * 4)
        else
            result[i] = 0
        end
    end
    
    return result
end

-- Read a monster from the monster list into the table.
local function ReadMonsterInfo(monster, index)
    local monsterListAddr = pso.read_u32(_MonsterList)
    local monsterAddr     = monsterListAddr + 72 * index
    
    -- TODO: Should allocate and return the monster here instead.
    if monster.params == nil then
        monster.params = {}
    end

    monster.ID            = pso.read_u16(monsterAddr + _MonsterIDOffset) -- aka its skin
    monster.floor         = pso.read_u16(monsterAddr + _MonsterFloorOffset) -- u16? Not even used...
    monster.section       = pso.read_u8 (monsterAddr + _MonsterSectionOffset)
    monster.wave          = pso.read_u8 (monsterAddr + _MonsterWaveOffset)
    monster.x             = pso.read_f32(monsterAddr + _MonsterXOffset)
    monster.y             = pso.read_f32(monsterAddr + _MonsterYOffset)
    monster.z             = pso.read_f32(monsterAddr + _MonsterZOffset)
    monster.params[1]     = pso.read_f32(monsterAddr + _MonsterParam1)
    monster.params[2]     = pso.read_f32(monsterAddr + _MonsterParam2)
    monster.params[3]     = pso.read_f32(monsterAddr + _MonsterParam3)
    monster.params[4]     = pso.read_f32(monsterAddr + _MonsterParam4)
    monster.params[5]     = pso.read_f32(monsterAddr + _MonsterParam5)
    monster.params[6]     = pso.read_u32(monsterAddr + _MonsterParam6) -- subType for most things
    monster.unitxtID      = GetUnitxtID(monster)
    monster.name          = GetMonsterName(monster)
    monster.memory_string = pso.read_mem_str(monsterAddr, 72)
    monster.debug_addr    = monsterAddr -- for debugging later

    return monster
end

-- Read the quest pointer.
local function ReadQuestPtr()
    return pso.read_u32(_QuestPtr)
end

-- Return pointer to the quest data at the top of the .bin.
local function ReadQuestDataPtr()
    local qptr = ReadQuestPtr()

    if qptr == 0 then
        return 0
    end

    return pso.read_u32(qptr + _QuestDataOffset)
end

-- Read quest number, not really useful for CM unfortunately
local function ReadQuestNumber()
    local qdata = ReadQuestDataPtr()
    return pso.read_u32(qdata + _QuestDataNumOffset)
end

-- Read the quest name 
local function ReadQuestName()
    local qdata = ReadQuestDataPtr()
    return pso.read_wstr(qdata + _QuestDataNameOffset, 32)
end

-- Read the CM flag. 
local function ReadCMFlag()
    return pso.read_u32(_CModeFlag)
end

-- Read the _Episode number.
local function ReadEP()
    return pso.read_u32(_Episode)
end

-- Are we in a quest? If the pointer is 0, not in a quest.
local function InQuest() 
    return ReadQuestPtr() ~= 0
end

-- Are in Episode 1? Note that Ephinea allows you to start any CM stage
-- from EP1 or EP2 game, so this check doesn't matter unless we're in a quest.
-- _Episode seems to be 0, 1, or 2 for episode 1, 2, or 4 respectively.
local function InEP1()
    return ReadEP() == 0
end

-- Are we in CMode? _CModeFlag seems to be 0 outside CM, 1 for CM.
local function InCM()
    return ReadCMFlag() == 1
end

-- Sanity check that this addon is reading data that makes sense.
local function InEP1CMQuest()
    local dq  = InQuest()
    local dep = InEP1()
    local dcm = InCM()

    -- Explcitly check because of debugging
    if InQuest() == false then
        return false
    end

    if InEP1() == false then
        return false
    end

    if InCM() == false then
        return false
    end

    return true
end

-- Return base address of the array of monster counts per floor.
local function ReadMonsterCountPtr()
    return _MonsterListCounts
end

-- Return table of monster counts, indexed from 0 up to 10 for Pioneer 2 to the maximum, Ruins 3.
-- Floor 1 is not always Forest 1, for example. But 10 is still the maximum even though only 6 are used
-- in EP1 CM.
local function ReadMonsterCounts()
    local result = {}
    local ptr = ReadMonsterCountPtr()

    return _CopyArrayOfDWORDS(result, ptr)
end

-- Return the address of the map events array. 
-- This array is an array of pointers to the map event
-- structures.
local function ReadMapEventsPtr()
    return _MapEventsPtrArray
end

-- Return the pointer to the map events for the specified floor number.
local function ReadMapEventsPtrForFloor(floor)
    return pso.read_u32(_MapEventsPtrArray + floor * 4)
end

-- Return the array in a table. Indexed by floor number
-- from 0 to 10.
local function ReadMapEventsPtrArray()
    local result = {}
    local ptr = ReadMapEventsPtr()

    return _CopyArrayOfDWORDS(result, ptr)
end

-- Read the sepcified map events for this one floor.
-- Returned object is a table with fields "wave_header" and "waves".
-- The header contains the size and number of waves.
-- The waves is an array of waves where each wave contains
-- the wave number, the section number, the wave number, the spawn delay, and a table
-- that is an array of the clear events for the wave.
-- These fields are "ID", "section", "wave", "delay", and "clear_events".
local function ReadMapEventsForFloor(floor)
    local result = {}
    local ptr    = ReadMapEventsPtrForFloor(floor)
    local wavePtr
    local waveHeader

    if floor == 0 then
        -- keep this array 1-indexed
        return nil
    end
    
    if ptr == 0 then
        return result
    end

    waveHeader = {}
    waveHeader.byte_size         = pso.read_u32(ptr + _WaveHdrByteSizeOffset)
    waveHeader.header_size       = pso.read_u32(ptr + _WaveHdrHdrSizeOffset)
    waveHeader.wave_count        = pso.read_u32(ptr + _WaveHdrNumWavesOffset)
    waveHeader.wave_list_bytes   = (waveHeader.byte_size - waveHeader.header_size) / waveHeader.wave_count
    result.wave_header           = waveHeader
    wavePtr                      = ptr + waveHeader.header_size
    
    -- Sanity check. Should probably remove the _WaveSizeNormal check but oh well.
    if ( (waveHeader.wave_list_bytes ~= _WaveSizeEP1CM) and 
         (waveHeader.wave_list_bytes ~= _WaveSizeNormal) ) then
        error(string.format("Unexpected wave_list_bytes! Expected %i or %i, calculated %i.", 
              _WaveSizeEP1CM, _WaveSizeNormal, waveHeader.wave_list_bytes))
    end

    local size           = waveHeader.wave_list_bytes
    result.waves         = {}
  
    -- Read each map event and get its clear events as well.
    -- Note that in EP1 CM, the client injects additional map events. These usually
    -- have an ID that is around 10000+. For example, if map event 81 defined up to 2 waves
    -- and the client rolled two waves, the second wave would be event ID 10082.
    for iWave=0,waveHeader.wave_count-1 do
        local wave        = {}
        wave.ID           = pso.read_u32(wavePtr + iWave * size)
        wave.section      = pso.read_u16(wavePtr + iWave * size + 8)
        wave.wave         = pso.read_u16(wavePtr + iWave * size + 10)
        wave.delay        = pso.read_u16(wavePtr + iWave * size + 12)
--[[    These are in the quest file but not in memory...
        wave.min_enemies  = pso.read_u8 (wavePtr + iWave * size + 16)
        wave.max_enemies  = pso.read_u8 (wavePtr + iWave * size + 17)
        wave.max_waves    = pso.read_u8 (wavePtr + iWave * size + 18)
        wave.x00000000    = pso.read_u8 (wavePtr + iWave * size + 19) ]]
        wave.clear_idx    = pso.read_u32(wavePtr + iWave * size + 16)
        wave.clear_events = {}

        -- Start of reading the clear events
        local clearEventsPtr = ptr + waveHeader.byte_size + wave.clear_idx
        local b              = pso.read_u8(clearEventsPtr)

        -- Loop until we see the sentinel end of clear events.
        while (b ~= _WaveClearDelimiter) do
            local clear = {}
            
            -- At least one clear event. Parse it.
            clear.type = b
            clearEventsPtr = clearEventsPtr + 1

            if ((clear.type == _WaveClearUnlock) or (clear.type == _WaveClearLock)) then
                clear.name     = "Unlock"
                clear.door     = pso.read_u16(clearEventsPtr)
                clearEventsPtr = clearEventsPtr + 2
            elseif (clear.type == _WaveClearUnhide) then
                clear.name     = "Unhide"
                clear.section  = pso.read_u16(clearEventsPtr)
                clearEventsPtr = clearEventsPtr + 2
                clear.flag     = pso.read_u16(clearEventsPtr)
                clearEventsPtr = clearEventsPtr + 2
            elseif (clear.type == _WaveClearStartEvent) then
                clear.name     = "Call"
                clear.event    = pso.read_u32(clearEventsPtr)
                clearEventsPtr = clearEventsPtr + 4
            else
                error(string.format("Unexpected error parsing the wave clear events for wave number %i, wave.ID %i", iWave, wave.ID))
            end

            -- Done parsing this clear event so save it. Advance to the next byte.
            wave.clear_events[#wave.clear_events + 1] = clear
            b = pso.read_u8(clearEventsPtr)
        end

        -- Done with this wave.
        result.waves[#result.waves + 1] = wave
    end

    return result
end

-- Read all the map events in memory. 
-- This is tailored towards EP1 CMode, so it's not going
-- to work in other quests or even free field...
local function ReadAllMapEvents()
    local result = {}

    for iFloor=0,_MaxFloors do
        result[iFloor] = ReadMapEventsForFloor(iFloor)
    end

    return result
end

-- Is t the byte for an "Unlock" clear event?
local function IsWaveClearUnlockType(t)
    return t == _WaveClearUnlock
end

-- Is t the byte for a "Call" clear event?
local function IsWaveClearCallType(t)
    return t == _WaveClearStartEvent
end

return
{
    ReadMonsterInfo            = ReadMonsterInfo,
    ReadQuestPtr               = ReadQuestPtr,
    ReadQuestDataPtr           = ReadQuestDataPtr,
    ReadQuestNumber            = ReadQuestNumber, 
    ReadQuestName              = ReadQuestName,
    InQuest                    = InQuest,
    ReadCMFlag                 = ReadCMFlag,
    ReadEP                     = ReadEP,
    InEP1                      = InEP1,
    InCM                       = InCM,
    InEP1CMQuest               = InEP1CMQuest,
    ReadMonsterCountPtr        = ReadMonsterCountPtr,
    ReadMonsterCounts          = ReadMonsterCounts,
    ReadMapEventsPtr           = ReadMapEventsPtr,
    ReadMapEventPtrArray       = ReadMapEventsPtrArray,
    ReadMapEventsForFloor      = ReadMapEventsForFloor,
    ReadAllMapEvents           = ReadAllMapEvents,
    IsWaveClearUnlockType      = IsWaveClearUnlockType,
    IsWaveClearCallType        = IsWaveClearCallType,
    MaxFloors                  = _MaxFloors,
    GetUnitxtID                = GetUnitxtID,
    GetMonsterSubtype          = GetMonsterSubtype,
    GetMonsterNameByUnitxtID   = GetMonsterNameByUnitxtID,
    ReadPlayerArray            = ReadPlayerArray,
    ReadPlayer                 = ReadPlayer,
    ReadMyPlayerIndex          = ReadMyPlayerIndex,
    ReadMyPlayer               = ReadMyPlayer,
    ReadPlayerRoom             = ReadPlayerRoom,
    ReadMyPlayerRoom           = ReadMyPlayerRoom,
    ReadMyPlayerFloor          = ReadMyPlayerFloor,
}