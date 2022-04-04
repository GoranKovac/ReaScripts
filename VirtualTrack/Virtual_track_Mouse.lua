-- @description Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 1.45
-- @changelog
--   + Properly calculate fade-in/fade-out for new item
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
    local track_tbl = OnDemand()
    if not track_tbl then return end
    Show_menu(track_tbl)
end

xpcall(Main, GetCrash())
