--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
	 * NoIndex: true
--]]

local reaper = reaper

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

if not reaper.APIExists("JS_ReaScriptAPI_Version") then
  reaper.MB( "JS_ReaScriptAPI is required for this script", "Please download it from ReaPack", 0 )
  return reaper.defer(function() end)
 else
   local version = reaper.JS_ReaScriptAPI_Version()
   if version < 1.002 then
     reaper.MB( "Your JS_ReaScriptAPI version is " .. version .. "\nPlease update to latest version.", "Older version is installed", 0 )
     return reaper.defer(function() end)
   end
end

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

local function Main()
    local window, segment, details = reaper.BR_GetMouseCursorContext()
    if window == "tcp" or window == "arrange" then
        local rprobj = nil
        if segment == "track" then
            rprobj = reaper.BR_GetMouseCursorContext_Track();
        elseif segment == "envelope" then
            rprobj, takeenv = reaper.BR_GetMouseCursorContext_Envelope()
            rprobj = takeenv and nil or rprobj
        end
        if rprobj then
            if SetupSingleElement(rprobj) and #Get_VT_TB() then
                    local _, v = next(Get_VT_TB())
                    Show_menu(v)
            end
        end
    end
end

reaper.atexit(StoreInProject)
xpcall(Main, GetCrash())
