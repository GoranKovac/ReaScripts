--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("[\\|/]Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()

local OLD_RAZOR_INFO
local function Main()
    local track = OnDemand()
    if not track then return end
    local razor_info = Get_Razor_Data(track)
    if not razor_info then return end
    if table.concat(razor_info) ~= OLD_RAZOR_INFO then -- PREVENT DOING COPY IF RAZOR DATA HAS NOT CHANGED
        reaper.Undo_BeginBlock2(0)
        reaper.PreventUIRefresh(1)
        local focused_tracks = GetSelectedTracksData(track, true) -- THIS ADDS NEW TRACKS TO VT_TB FOR ON DEMAND SCRIPT AND RETURNS TRACK SELECTION
        for sel_track in pairs(focused_tracks) do
           -- Set_Razor_Data(sel_track, razor_info)
            Copy_area(Get_VT_TB()[sel_track],razor_info)
        end
        reaper.PreventUIRefresh(-1)
        reaper.Undo_EndBlock2(0, "VT: " .. "COPY AREA TO COMP", -1)
        reaper.UpdateArrange()
        OLD_RAZOR_INFO = table.concat(razor_info)
    end
end

xpcall(Main, GetCrash())
