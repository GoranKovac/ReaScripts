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
    local tbl = Get_On_Demand_DATA()
    if not tbl then return end
    local num = tbl.idx - 1
    if num == 0 then return end
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2(0)
    Set_Virtual_Track(tbl.rprobj, tbl, num)
    reaper.Undo_EndBlock2(0, "VT: Recall Version " .. tbl.info[num].name, -1)
    reaper.MarkProjectDirty(0)
    reaper.PreventUIRefresh(-1)
end

xpcall(Main, GetCrash())