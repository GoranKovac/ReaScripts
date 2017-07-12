--[[
 * ReaScript Name: Remove VCA Master And Slaves.lua
 * Discription: Script Removes VCA Master, Slaves and all flags
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2017-07-12)
  + Innitial release
--]]

--------------------------------------------------------------------------------------
local function remove_slave_flags(VCA_GROUP)
  local cnt_tr = reaper.CountTracks(0)
  
  for i = 0 , cnt_tr-1 do
    local tr = reaper.GetTrack(0,i)
    -- REMOVE ALL SLAVES FROM GROUP 
    local VCA_S = reaper.GetSetTrackGroupMembership(tr,"VOLUME_VCA_SLAVE", VCA_GROUP,0)
    local VCA_S_MUTE = reaper.GetSetTrackGroupMembership(tr,"MUTE_SLAVE", VCA_GROUP,0)
    local VCA_S_SOLO = reaper.GetSetTrackGroupMembership(tr,"SOLO_SLAVE", VCA_GROUP,0)
  end
  
end

local function remove_master_flags()
  local sel_tr = reaper.GetSelectedTrack(0,0)
  -- Find ACTIVE GROUP
  local VCA_GROUP = reaper.GetSetTrackGroupMembership(sel_tr,"VOLUME_VCA_MASTER", 0, 0)
  -- REMOVE VCA MASTER AND GROUP
  local VCA_M = reaper.GetSetTrackGroupMembership(sel_tr,"VOLUME_VCA_MASTER", VCA_GROUP, 0)
  local VCA_M_MUTE = reaper.GetSetTrackGroupMembership(sel_tr,"MUTE_MASTER", VCA_GROUP,0)
  local VCA_M_SOLO = reaper.GetSetTrackGroupMembership(sel_tr,"SOLO_MASTER", VCA_GROUP,0)
  remove_slave_flags(VCA_GROUP)
end
remove_master_flags()
