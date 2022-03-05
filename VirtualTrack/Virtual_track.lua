-- @description Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 0.73
-- @changelog
--   + Small fix of sorting LaneMode and Showing active in MENU
-- @provides
--   {Images,Modules}/*
--   [main] Virtual_track_Direct.lua
--   [main] VT_Promote_to_main.lua
--   [main] VT_Switch_DOWN.lua
--   [main] VT_Switch_UP.lua
--   [main] VT_Activate_lane_under_mouse.lua

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
