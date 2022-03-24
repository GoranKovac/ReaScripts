--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
   * NoIndex: true
--]]
local reaper = reaper

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

options = {
  --  ["SWIPE"] = false,
    ["LANE_COLORS"] = false
}


if reaper.HasExtState( "VirtualTrack", "options" ) then
   local state = reaper.GetExtState( "VirtualTrack", "options" )
  -- options["SWIPE"] = state:match("SWIPE (%S+)") == "true" and true or false
   options["LANE_COLORS"] = state:match("LANE_COLORS (%S+)") == "true" and true or false
end

local window_flags
function GuiInit()
    window_flags = reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoResize()
    CTX = reaper.ImGui_CreateContext('Virtual Track OPTIONS') -- Add VERSION TODO
    FONT = reaper.ImGui_CreateFont('sans-serif', 15) -- Create the fonts you need
    reaper.ImGui_AttachFont(CTX, FONT)-- Attach the fonts you need
    reaper.ImGui_SetNextWindowSize(CTX, 250, 300)
    local cent_x, cent_y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetMainViewport(CTX))
    reaper.ImGui_SetNextWindowPos(CTX, cent_x, cent_y, nil, 0.5, 0.5)
end

local function save()
    local store_string = ""
    for k, v in pairs(options) do
        store_string = store_string .. tostring(k) .. " " .. tostring(v) .. " "
    end
    reaper.SetExtState( "VirtualTrack", "options", store_string, true )
end

function Main()
    reaper.ImGui_PushFont(CTX, FONT)
    local visible, open  = reaper.ImGui_Begin(CTX, 'Virtual Track OPTIONS', true, window_flags)
    reaper.ImGui_SetNextWindowSize(CTX, 250, 300, reaper.ImGui_Cond_Once())

    if visible then
       -- _, options["SWIPE"] = reaper.ImGui_Checkbox(CTX, "SWIPE",  options["SWIPE"])
        _, options["LANE_COLORS"] = reaper.ImGui_Checkbox(CTX, "LANE COLORS", options["LANE_COLORS"])
        reaper.ImGui_Spacing( CTX ) ; reaper.ImGui_Spacing( CTX )
        --if reaper.ImGui_Button(CTX, 'SAVE', 80) then save() end
        reaper.ImGui_End(CTX)
    end
    reaper.ImGui_PopFont(CTX)

    if open then
        reaper.defer(Main)
    else
        save()
        reaper.ImGui_DestroyContext(CTX)
    end
end

GuiInit()
Main()
