package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
STANDALONE_RUN = true
require("Sexan_ReaSpaghetti")
local func_file = "C:/Users/Gokily/Documents/ReaGit/ReaScripts/ReaSpaghetti/Examples/Toggle_Mute_Tracks.reanodes"
local file = io.open(func_file, "r")
if file then
   local string = file:read("*all")
    RestoreNodes(string)
    file:close()
end
InitRunFlow()