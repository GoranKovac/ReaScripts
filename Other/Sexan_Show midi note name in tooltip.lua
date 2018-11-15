--[[
 * ReaScript Name: Show midi note name in tooltip.lua 
 * About: Show tooltip with note name and position under mouse cursor
 *        Requested by nofish
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2018-15-11)
  + Initial release
--]]

local oct_tbl = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

function main()
local x,y = reaper.GetMousePosition()
local window, segment, details = reaper.BR_GetMouseCursorContext()
  if segment == "notes" and window == "midi_editor" then
    local retval, inlineEditor, noteRow, ccLane, ccLaneVal, ccLaneId = reaper.BR_GetMouseCursorContext_MIDI()
    local pos =  reaper.BR_GetMouseCursorContext_Position()
    local retval, measures, cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats( 0, pos )
    local beats = retval + 1    
    local oct =  math.floor(noteRow / 12) -- get OCTAVE (1,2,3,4....)
    local cur_oct = oct * 12 -- GET OCAVE RANGE (12,24,36...)
    local cur_oct_note = ((cur_oct - noteRow ) * -1) + 1 -- GET OCTAVE NOTE (1,2,3,4...)
    
    for i = 1,#oct_tbl do
      if i == cur_oct_note then
        local note = oct_tbl[i] .. oct - 1 .. " - " .. measures + 1 .. "." .. round(beats, 2)
        if last_x ~= x or last_y ~= y then -- DO NOT UPDATE ALL THE TIME, JUST IF MOUSE POSITION CHANGED 
          reaper.TrackCtl_SetToolTip( note, x, y - 25, true )
          last_x, last_y = x, y
        end
      end
    end
  end
reaper.defer(main)  
end
main()