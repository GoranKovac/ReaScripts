-- @description Name Virtual Tracks
-- @author Sexan
-- @license GPL v3
-- @version 0.6
-- @changelog
--   + Dual script refactor (sockmonkey)
--   + Added on demand script on shortcut (non-defered) (sockmonkey)
-- @provides
--   {Images,Modules}/*
--   [main] Virtual_track_Direct.lua

local reaper = reaper
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
image_path = script_folder .. "Images\\VT_icon_empty.png"

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

local function RunLoop()
    Create_VT_Element()
    Draw(Get_VT_TB())
    reaper.defer(RunLoop)
end

local function Main()
    xpcall(RunLoop, GetCrash())
end

function Exit()
    StoreInProject()
    local VT_TB = Get_VT_TB()
    for _, v in pairs(VT_TB) do
        reaper.JS_LICE_DestroyBitmap(v.bm)
        reaper.JS_LICE_DestroyBitmap(v.font_bm)
    end
end

reaper.atexit(Exit)
Main()
