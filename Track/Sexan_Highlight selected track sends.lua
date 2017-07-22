--[[
 * ReaScript Name: Highlight selected track sends.lua
 * Discription: Script highlights sends tracks of selected track
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2017-07-22)
  + Innitial release
--]]


local function Main()
  local tr = reaper.GetSelectedTrack(0,0)
  
  if not tr then return 0 end
  
  local snd_cnt = reaper.GetTrackNumSends(tr, 0)
    
    for i = 1, snd_cnt do
      local send_tr = reaper.BR_GetMediaTrackSendInfo_Track(tr, 0, i-1, 1)
      reaper.SetTrackSelected(send_tr, true )
    end
 
  reaper.defer(Main)
end
Main()
