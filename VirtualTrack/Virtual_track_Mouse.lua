-- @description Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 1.27
-- @changelog
--   + Do not add razors if lane does not exist
--   + Do not copy to COMP lane if current track does not have that lane
--   + Calculate new razor data from current track data
--   + (properly shows razors on groups with missmatch version count)
-- @provides
--   {Images,Modules}/*
--   [main] Shortcuts/*.lua
--   [main] Virtual_track_SelTrack.lua

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Utils")

Check_Requirements()
reaper.SetProjExtState(0, "VirtualTrack", "ONDEMAND_MODE", "mouse")
local function Main()
    local track = OnDemand()
    if not track then return end
    Show_menu(track)
end

xpcall(Main, GetCrash())
