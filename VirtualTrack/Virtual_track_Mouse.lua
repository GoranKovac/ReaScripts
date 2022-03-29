-- @description Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 1.19
-- @changelog
--   + Save updated state to P_EXT STATE before opening menu
--   + fixes tracks not adding to groups if only single version
--   + on initial menu open
-- @provides
--   {Images,Modules}/*
--   [main] Shortcuts/*.lua
--   [main] Virtual_track_SelTrack.lua
--   [main] Virtual_track_Options.lua

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()
reaper.SetProjExtState(0, "VirtualTrack", "ONDEMAND_MODE", "mouse")
local function Main()
    local track = OnDemand()
    if not track then return end
    Show_menu(track)
end

xpcall(Main, GetCrash())
