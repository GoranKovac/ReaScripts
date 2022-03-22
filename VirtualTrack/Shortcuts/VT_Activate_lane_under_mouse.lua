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
    local mouse = MouseInfo()
    if not mouse.lane then return end
    local VT_TB = Get_VT_TB()
    local focused_tracks = GetSelectedTracksData(track, true) -- THIS ADDS NEW TRACKS TO VT_TB FOR ON DEMAND SCRIPT AND RETURNS TRACK SELECTION
   -- local all_childrens_and_parents = GetChild_ParentTrack_FromStored_PEXT(focused_tracks)
   -- local current_tracks = GetLinkVal() and all_childrens_and_parents or focused_tracks
    reaper.PreventUIRefresh(1)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
            for linked_track in pairs(focused_tracks) do
                CheckTrackLaneModeState(VT_TB[linked_track])
                UpdateInternalState(VT_TB[linked_track])
                --Lane_view(VT_TB[linked_track], mouse.lane)
                SwapVirtualTrack(VT_TB[linked_track], mouse.lane)
                StoreStateToDocument(VT_TB[linked_track])
            end
        end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

xpcall(Main, GetCrash())
