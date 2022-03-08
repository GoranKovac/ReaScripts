--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("\\Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()

local function Main()
    local tbl = Get_On_Demand_DATA()
    if not tbl then return end
    local mouse = MouseInfo(Get_VT_TB())
    if not mouse.lane then return end
    if reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then
        if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 2 then
            Mute_view(tbl, mouse.lane)
           -- Set_Razor_Data(tbl, Get_Razor_Data(tbl.rprobj), mouse.lane)
            reaper.UpdateArrange()
        end
    end
end

xpcall(Main, GetCrash())