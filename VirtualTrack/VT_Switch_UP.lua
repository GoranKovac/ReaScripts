--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
	 * NoIndex: true
--]]

local reaper = reaper

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()

local function Main()
	local tbl = Get_On_Demand_DATA()
	if not tbl then return end
	local num = tbl.idx + 1
	if num > #tbl.info then return end
	reaper.PreventUIRefresh(1)
	reaper.Undo_BeginBlock2(0)
	Set_Virtual_Track(tbl.rprobj, tbl, num)
	StoreStateToDocument(tbl)
	reaper.Undo_EndBlock2(0, "VT: Recall Version " .. tbl.info[num].name, -1)
	reaper.PreventUIRefresh(-1)
end

xpcall(Main, GetCrash())