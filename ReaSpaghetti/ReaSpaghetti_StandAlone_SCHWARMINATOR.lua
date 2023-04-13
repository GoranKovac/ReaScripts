package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;"
STANDALONE_RUN = true
DEFER = true
require("Sexan_ReaSpaghetti")
local func_file = "C:/Users/Gokily/Documents/ReaGit/ReaScripts/ReaSpaghetti/Examples/SCHWARMINATOR.reanodes"
local file = io.open(func_file, "r")
if file then
   local string = file:read("*all")
    RestoreNodes(string)
    file:close()
end
local function Main()
InitRunFlow()
if DEFER then reaper.defer(Main) end
end
local function Exit()
DEFER = false
end
reaper.atexit(Exit)
reaper.defer(Main)