-- Debugging module. Generates lots of output to the log and some to the addon window.

local debugOn = 0

local function SetDebug(n)
    debugOn = n
end

local function DebugPrint(s)
    if debugOn == 0 then
        return
    end

    print(s)
end

local function DebugText(s)
    if debugOn == 1 then
        imgui.Text(s)
    end
end

local function PrintOptions()
    for key, val in pairs(options) do
        DebugPrint(tostring(key), tostring(val))
    end
end

local function DebugMonsterInfo(addr, mem_str)
    if debugOn == 0 then
        return
    end

    local b
    local s = "\n"
    --DebugPrint(string.format("%-0.8X", addr))
    for b=1,72 do
        s = string.format("%s %-.02X", s, string.byte(mem_str, b))
        if b % 24 == 0 then
            s = string.format("%s\n", s)
        end
    end
    --DebugPrint(s)
end

local function DebugMapEvent(wave)
    if debugOn == 0 then
        return
    end

    print(wave.ID, wave.section, wave.wave, wave.delay, wave.clear_idx)
    for k,v in pairs(wave.clear_events) do
        for kk,vv in pairs(v) do
            print("wave_clear_event", k, v, kk, vv)
        end
    end
end


return 
{
    DebugSectionTables               = DebugSectionTables,
    DebugText                        = DebugText,
    PrintOptions                     = PrintOptions,
    DebugMonsterInfo                 = DebugMonsterInfo,
    DebugPrint                       = DebugPrint,
    DebugMapEvent                    = DebugMapEvent,
    SetDebug                         = SetDebug,
}