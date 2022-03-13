-- @description Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 0.85
-- @changelog
--   + Native LaneMode Exclusive solo (removed mute system)
--   + Fixed bug when not storing envelope data in lane mode
--   + when triggered from shortcut scripts
--   + Renamed Promote_to_main to Copy_to_COMP shortcut script
-- @provides
--   {Images,Modules}/*
--   [main] Shortcuts/*.lua
--   [main] Virtual_track_Mouse.lua
--   [main] Virtual_track_SelTrack.lua

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()

local function Main()
    Create_VT_Element()
    CheckUndoState()
    Draw(Get_VT_TB())
    reaper.defer(Main)
end

function Exit()
    for _, v in pairs(Get_VT_TB()) do
        v:cleanup()
    end
end

reaper.atexit(Exit)
xpcall(Main, GetCrash())
