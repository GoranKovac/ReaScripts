-- @description Name Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 0.71
-- @changelog
--   + Dual script refactor (sockmonkey)
--   + Added on demand script on shortcut (non-defered) (sockmonkey)
--   + Added undo (sockmonkey)
--   + Added Comping mode in ShowAll mode (lane mode)
--   + Added "Mute View" for previewing versions in LaneMode
--   + Added shortcut scripts for changing versions up and down and promoting to main in lane mode
-- @provides
--   {Images,Modules}/*
--   [main] Virtual_track_Direct.lua
--   [main] VT_Promote_to_MAIN.lua
--   [main] VT_Switch_DOWN.lua
--   [main] VT_Switch_UP.lua

local reaper = reaper
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()

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
    for _, v in pairs(Get_VT_TB()) do
        v:cleanup()
    end
end

reaper.atexit(Exit)
Main()
