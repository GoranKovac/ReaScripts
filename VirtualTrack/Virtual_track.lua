-- @description Name Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 0.61
-- @changelog
--   + Dual script refactor (sockmonkey)
--   + Added on demand script on shortcut (non-defered) (sockmonkey)
--   + Added undo (sockmonkey)
--   + Added Comping mode in ShowAll mode (lane mode)
--   + Added shortcut scripts for changing versions up and down and promoting to main in lane mode
-- @provides
--   {Images,Modules}/*
--   [main] Virtual_track_Direct.lua
--   [main] VT_Promote_to_main.lua
--   [main] VT_Switch_DOWN.lua
--   [main] VT_Switch_UP.lua

local reaper = reaper
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
image_path = script_folder .. "Images/VT_icon_empty.png"

if not reaper.APIExists("JS_ReaScriptAPI_Version") then
    reaper.MB( "JS_ReaScriptAPI is required for this script", "Please download it from ReaPack", 0 )
    return reaper.defer(function() end)
else
    local version = reaper.JS_ReaScriptAPI_Version()
    if version < 1.002 then
        reaper.MB( "Your JS_ReaScriptAPI version is " .. version .. "\nPlease update to latest version.", "Older version is installed", 0 )
        return reaper.defer(function() end)
    end
end

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

local function RunLoop()
    Create_VT_Element()
    CheckUndoState()
    Draw(Get_VT_TB())
    reaper.defer(RunLoop)
end

local function Main()
    xpcall(RunLoop, GetCrash())
end

function Exit()
    StoreInProject()
    for _, v in pairs(Get_VT_TB()) do
        v:cleanup()
    end
end

reaper.atexit(Exit)
Main()
