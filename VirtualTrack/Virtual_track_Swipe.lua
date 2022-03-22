--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
   * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()
reaper.gmem_attach('Virtual_Tracks')

--! FIX ONLY WORKING ON MULTIOPLE TRACKS IF WAS TOGGLED ON FIRST TRACK
local OLD_RAZOR_INFO
function Do_swipe()
    local track = OnDemand()
    if not track then return end
    local razor_info = Get_Razor_Data(track)
    if not razor_info then return end
    if table.concat(razor_info) ~= OLD_RAZOR_INFO then
        local focused_tracks = GetSelectedTracksData(track, true) -- THIS ADDS NEW TRACKS TO VT_TB FOR ON DEMAND SCRIPT AND RETURNS TRACK SELECTION
        for sel_track in pairs(focused_tracks) do
            Set_Razor_Data(sel_track, razor_info)
            Copy_area(Get_VT_TB()[sel_track], razor_info)
        end
        OLD_RAZOR_INFO = table.concat(razor_info)
    end
end

local function Main()
    local exit = reaper.gmem_read(1)
    if exit ~= 1 then
        reaper.gmem_write(2, 1)
        reaper.defer(Main)
        Do_swipe()
    else
        --EXIT CODE
        reaper.gmem_write(1, 0)
        reaper.gmem_write(2, 0)
    end
end

xpcall(Main, GetCrash())