--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("[\\|/]Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Utils")

local _, _, sectionID, cmdID, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID, cmdID, 1)
reaper.RefreshToolbar2(sectionID, cmdID)

PREV_RAZOR_DATA = nil
local func = "CopyToCOMP"
function SWIPE()
    local track_tbl = OnDemand()
    if not track_tbl then return end
    if reaper.ValidatePtr(track_tbl.rprobj, "TrackEnvelope*") then return end -- DO NOT ALLOW ON EVELOPES
    if track_tbl.lane_mode == 0 then return end -- IF NOT IN LANE MODE IGNORE
    local CURRENT_RAZOR_DATA = Get_Razor_Data(track_tbl.rprobj)
    if not CURRENT_RAZOR_DATA then return end
    CURRENT_RAZOR_DATA = table.concat(CURRENT_RAZOR_DATA)
    if CURRENT_RAZOR_DATA ~= PREV_RAZOR_DATA then
        Show_menu(track_tbl, func)
        PREV_RAZOR_DATA = CURRENT_RAZOR_DATA
    end
end

function Main()
    SWIPE()
    reaper.defer(Main)
end

function DoAtExit()
    -- set toggle state to off
    reaper.SetToggleCommandState(sectionID, cmdID, 0);
    reaper.RefreshToolbar2(sectionID, cmdID);
  end

reaper.atexit(DoAtExit)
xpcall(Main, GetCrash())
