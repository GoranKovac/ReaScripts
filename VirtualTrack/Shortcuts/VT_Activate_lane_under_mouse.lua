--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("[\\|/]Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()

local function Main()
    local track = OnDemand()
    if not track then return end
    local mouse = MouseInfo(Get_VT_TB())
    if not mouse.lane then return end
    local VT_TB = Get_VT_TB()
    local focused_tracks = GetSelectedTracksData(track, true) -- THIS ADDS NEW TRACKS TO VT_TB FOR ON DEMAND SCRIPT AND RETURNS TRACK SELECTION
    local linked_VT = GetLinkedTracksVT_INFO(focused_tracks, true)
    reaper.PreventUIRefresh(1)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
            for linked_track in pairs(linked_VT) do
                CheckTrackLaneModeState(VT_TB[linked_track])
                Mute_view(VT_TB[linked_track], mouse.lane)
                StoreStateToDocument(VT_TB[linked_track])
            end
        end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

xpcall(Main, GetCrash())
