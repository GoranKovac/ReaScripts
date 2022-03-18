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
    local focused_tracks = GetSelectedTracksData(track, true) -- THIS ADDS NEW TRACKS TO VT_TB FOR ON DEMAND SCRIPT AND RETURNS TRACK SELECTION
    local linked_VT = GetLinkedTracksVT_INFO(focused_tracks, true)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(0)
    for linked_track in pairs(linked_VT) do
        UpdateInternalState(VT_TB[linked_track])
        ShowAll(VT_TB[linked_track])
        StoreStateToDocument(VT_TB[linked_track])
    end
    reaper.Undo_EndBlock2(0, "VT: ShowALL Versions ", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

xpcall(Main, GetCrash())
