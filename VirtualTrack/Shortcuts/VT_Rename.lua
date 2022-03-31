--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("[\\|/]Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Utils")

Check_Requirements()

local function Main()
    local track_tbl = OnDemand()
    if not track_tbl then return end
    --local retval, retvals_csv = reaper.GetUserInputs( "VIRTUAL TRACK - RENAME", 1, "New Version name : ", track_tbl.info[track_tbl.idx].name )
    --if not retval then return end
    local func = "ReaperRename"
    Show_menu(track_tbl, func)
end

xpcall(Main, GetCrash())
