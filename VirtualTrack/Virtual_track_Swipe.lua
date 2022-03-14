--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
   * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()
reaper.gmem_attach('Virtual_Tracks')

function do_swipe()
    local track = OnDemand()
    if not track then return end
    Copy_area(Get_VT_TB()[track])
    MSG(#Get_VT_TB()[track].info)
end

local function Main()
    local exit = reaper.gmem_read(1)
    if exit ~= 1 then
        reaper.gmem_write(2, 1)
        reaper.defer(Main)
        do_swipe()
    else
        --EXIT CODE
        MSG("EXIT")
        local exit = reaper.gmem_write(1, 0)
        reaper.gmem_write(2, 0)
    end
end

xpcall(Main, GetCrash())
