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
    local VT_TB = Get_VT_TB()

    if VT_TB[track] then
        MSG("TABLE COMP_IDX VALUE :" .. VT_TB[track].comp_idx)
    end
    Copy_area(VT_TB[track])
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
