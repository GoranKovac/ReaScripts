-- @description Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 1.14
-- @changelog
--   + Small refactors and simplify logic
--   + Added comp icon when track is comp enabled
--   + Added menu actions to lane mode (Create,Delete,etc)
--   + Added comping "silence" (deletes content of item if razor is empty)
--   + Comping follows autocrossfade
--   + Removed Swiping and LINK for now
-- @provides
--   {Images,Modules}/*
--   [main] Shortcuts/*.lua
--   [main] Virtual_track_Mouse.lua
--   [main] Virtual_track_SelTrack.lua
--   [main] Virtual_track_Swipe.lua
--   [main] Virtual_track_Options.lua

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
