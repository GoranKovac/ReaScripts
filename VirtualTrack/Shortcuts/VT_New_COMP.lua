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
    if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") ~= 0 then return end
    if VT_TB[track].comp_idx ~= 0 then return end
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(0)
    UpdateInternalState(VT_TB[track])
    NewComp(VT_TB[track])
    StoreStateToDocument(VT_TB[track])
    reaper.Undo_EndBlock2(0, "VT: New Empty COMP ", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

xpcall(Main, GetCrash())
