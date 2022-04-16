local reaper = reaper
local start_time = reaper.time_precise()
local key_state, KEY = reaper.JS_VKeys_GetState(start_time - 2), nil
for i = 1, 255 do
    if key_state:byte(i) ~= 0 then KEY = i; reaper.JS_VKeys_Intercept(KEY, 1) break end
end
if not KEY then return end

function Key_held()
    key_state = reaper.JS_VKeys_GetState(start_time - 2)
    return key_state:byte(KEY) == 1
end

function Release() reaper.JS_VKeys_Intercept(KEY, -1) end

function Handle_errors(err)
    reaper.ShowConsoleMsg(err .. '\n' .. debug.traceback())
    Release()
end

function Main()
    if not Key_held() then return end
    reaper.ShowConsoleMsg('Hello!' .. '\n')
    reaper.defer(function() xpcall(Main, Handle_errors) end)
end

reaper.atexit(Release)
xpcall(Main, Handle_errors)
