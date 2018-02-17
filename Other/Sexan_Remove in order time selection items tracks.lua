--[[
 * ReaScript Name: Remove in order time selection,items,tracks
 * About: Script removes things in following order. If there is time selection, some selected items and tracks
 *              First run of the script it removes time selection, second items and third tracks.
 *              (I use it on "ESC" key)
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: SWS
 * Version: 1.01
--]]
 
--[[
 * Changelog:
 * v1.01 (2017-07-13)
--]]

local Tstart, Tend = reaper.GetSet_LoopTimeRange(0, 0, 0, 0, 0)

function Main()
  -- First remove Time Selection
  if Tstart ~= Tend then 
    reaper.Main_OnCommand(40020,0)
  -- Second deselect items
  elseif reaper.CountSelectedMediaItems(0) then 
    reaper.Main_OnCommand(40289,0)
  -- Third deselect tracks  
  elseif reaper.CountSelectedTracks(0) then 
    reaper.Main_OnCommand(40297,0)
  end
end
Main()
