--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
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
    local VT_TB = Get_VT_TB()
    local current_name = VT_TB[track].info[VT_TB[track].idx].name
    local current_name_id = current_name:match("%S+ %S+ (%S+)")
    if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") ~= 0 then return end
    local retval, name = reaper.GetUserInputs(current_name, 1, " New Name :", current_name_id)
    if not retval then return end
    local focused_tracks = GetSelectedTracksData(track, true) -- THIS ADDS NEW TRACKS TO VT_TB FOR ON DEMAND SCRIPT AND RETURNS TRACK SELECTION
    local linked_VT = GetLinkedTracksVT_INFO(focused_tracks, true)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(0)
    for linked_track in pairs(linked_VT) do
        UpdateInternalState(VT_TB[linked_track])
        Rename(VT_TB[linked_track], name)
        StoreStateToDocument(VT_TB[linked_track])
    end
    reaper.Undo_EndBlock2(0, "VT: Rename Version ", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

xpcall(Main, GetCrash())
