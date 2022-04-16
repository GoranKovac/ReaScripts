local reaper = reaper
local startTime = reaper.time_precise()
local key_state = reaper.JS_VKeys_GetState(startTime - 2)
for i = 1, 255 do
    if key_state:byte(i) ~= 0 then KEY = i; reaper.JS_VKeys_Intercept(KEY, 1) --[[ reaper.ShowConsoleMsg(string.char(i)) ]] end
end

function Kill_script()
    if not KEY then return true end
    key_state = reaper.JS_VKeys_GetState(startTime - 2)
    reaper.ShowConsoleMsg("SCRIPT RUNNING")
    if key_state:byte(KEY) == 0 then reaper.JS_VKeys_Intercept(KEY, -1) return true end
end

function Main()
    if Kill_script() then return end
    reaper.defer(Main)
end

function atExit() reaper.JS_VKeys_Intercept(-1, -1) end -- JUST IN CASE RELEASE ALL KEYS

reaper.atexit(atExit)
Main()
