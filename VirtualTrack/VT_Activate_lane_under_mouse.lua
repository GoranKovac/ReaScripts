--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
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
    local mouse = MouseInfo()
    if not mouse.lane then return end
    if reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then
        if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 2 then
            Mute_view_test(tbl, mouse.lane)
            reaper.UpdateArrange()
        end
    end
end

xpcall(Main, GetCrash())