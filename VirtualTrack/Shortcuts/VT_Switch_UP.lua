--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("\\Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()

local function Main()
	local tbl = OnDemand()
	if not tbl then return end
	local num = tbl.idx + 1
	if num > #tbl.info then return end
	local linked_VT = GetLinkedTracksVT_INFO(tbl, true)
	reaper.PreventUIRefresh(1)
	reaper.Undo_BeginBlock2(0)
	for i = 1, #linked_VT do
        SwapVirtualTrack(linked_VT[i], num)
        StoreStateToDocument(linked_VT[i])
    end
	reaper.Undo_EndBlock2(0, "VT: Recall Version " .. tbl.info[num].name, -1)
	reaper.PreventUIRefresh(-1)
end

xpcall(Main, GetCrash())