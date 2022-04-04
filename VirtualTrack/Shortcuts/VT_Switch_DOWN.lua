--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("[\\|/]Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Utils")

local function Main()
    local track_tbl = OnDemand()
    if not track_tbl then return end
    local func = "CycleVersionsDOWN"
    Show_menu(track_tbl, func)
end

xpcall(Main, GetCrash())
