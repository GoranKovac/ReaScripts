--[[
 * ReaScript Name: Remove selected VCA master and its slaves with all flags.lua
 * About: Script removes selected VCA master its slaves and all flags associated
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.03
--]]
 
--[[
 * Changelog:
 * v1.03 (2018-02-27)
  + Fixed for 64 group remove
--]]

--------------------------------------------------------------------------------------
local tr_group = reaper.GetSetTrackGroupMembership

local function remove_slave_flags(VCA_GROUP)
  local cnt_tr = reaper.CountTracks(0)
  
  for i = 0 , cnt_tr-1 do
    local tr = reaper.GetTrack(0,i)
    -- REMOVE ALL SLAVES FROM GROUP 
    local VCA_S =tr_group(tr,"VOLUME_VCA_SLAVE", VCA_GROUP,0)
    local VCA_S_MUTE =tr_group(tr,"MUTE_SLAVE", VCA_GROUP,0)
    local VCA_S_SOLO = tr_group(tr,"SOLO_SLAVE", VCA_GROUP,0)
  end
  
end

local function remove_master_flags()
  local sel_tr = reaper.GetSelectedTrack(0,0)
  -- Find ACTIVE GROUP
  if tr_group(sel_tr,"VOLUME_VCA_MASTER", 0, 0) == 0 then tr_group = reaper.GetSetTrackGroupMembershipHigh end
  local VCA_GROUP = tr_group(sel_tr,"VOLUME_VCA_MASTER", 0, 0)
  -- REMOVE VCA MASTER AND GROUP
  local VCA_M = tr_group(sel_tr,"VOLUME_VCA_MASTER", VCA_GROUP, 0)
  local VCA_M_MUTE = tr_group(sel_tr,"MUTE_MASTER", VCA_GROUP,0)
  local VCA_M_SOLO = tr_group(sel_tr,"SOLO_MASTER", VCA_GROUP,0)
  remove_slave_flags(VCA_GROUP)
end
remove_master_flags()