--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("[\\|/]Shortcuts", "") .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Utils")

-- adopted from BirdBird
local terminateScript = false
local VKLow, VKHi = 8, 0xFE
local VKState0 = string.rep("\0", VKHi - VKLow + 1)
local startTime = 0

-- adopted from BirdBird
function awake()
    keyState = reaper.JS_VKeys_GetState(startTime - 0.5):sub(VKLow, VKHi)
    startTime = reaper.time_precise()
    thisCycleTime = startTime

    reaper.atexit(atExit)
    reaper.JS_VKeys_Intercept(-1, 1)

    keyState = reaper.JS_VKeys_GetState(-2):sub(VKLow, VKHi)

    local terminate = false
    if terminate == true then
        return true
    else
        return false
    end
end
-- adopted from BirdBird
function scriptShouldStop()
    local prevCycleTime = thisCycleTime or startTime
    thisCycleTime = reaper.time_precise()
    local prevKeyState = keyState
    keyState = reaper.JS_VKeys_GetState(startTime - 0.5):sub(VKLow, VKHi)
    -- All keys are released.
    if keyState ~= prevKeyState and keyState == VKState0 then return true end
    -- Any keys were pressed.
    local keyDown = reaper.JS_VKeys_GetDown(prevCycleTime):sub(VKLow, VKHi)
    if keyDown ~= prevKeyState and keyDown ~= VKState0 then
        local p = 0
        ::checkNextKeyDown:: do
            p = keyDown:find("\1", p + 1)
            if p then
                if prevKeyState:byte(p) == 0 then
                    return true
                else
                    goto checkNextKeyDown
                end
            end
        end
    end

    return false
end

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
    if scriptShouldStop() or terminateScript then
        atExit()
        return 0
    end
    SWIPE()
    reaper.defer(Main)
end

function atExit()
    reaper.JS_VKeys_Intercept(-1, -1)
end
--------------------------------------
local terminate = awake()
if terminate == false then
    xpcall(Main, GetCrash())
end