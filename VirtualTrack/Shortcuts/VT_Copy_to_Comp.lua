--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("[\\|/]Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Utils")

Check_Requirements()

local OLD_RAZOR_INFO
local function Main()
    local track = OnDemand()
    if not track then return end
    local func = "CopyToCOMP"
    Show_menu(track, func)
end

xpcall(Main, GetCrash())
