local info = debug.getinfo(1, 'S');
local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]];

dofile(script_path .. "/LoadDebug.lua")

global_table = { "this", "is", "test", "table", "1", "2" }
function Main()
    --DEBUG.console("HELLO VSCODE!") -- PRINTS IN VS Debug Console
    local variable = -1

    for i = 1, 10 do
        variable = i
    end
    --a = "ASB" + 1

    local new_variable = "RUNNING IN REAPER"
    DEBUG.defer(Main)
end

function exit() return end

reaper.atexit(exit)
DEBUG.defer(Main)
