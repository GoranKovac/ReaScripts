--[[
 * ReaScript Name: Create VCA Master from selection.lua
 * About: Script creates Master VCA for selected tracks and makes them VCA Slave.Also Mute and SOLO flags are added
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.700
--]]
 
--[[
 * Changelog:
 * v1.700 (2018-02-17)
  + Added user setting "group range" for creating custom VCA ranges
--]]

-- USER SETTING
---------------
local group_range = 1 -- (1 creates from 64-1, 32 creates 32-64)
local popup = 0    -- (set to 0 for no popup, set to 1 for popup asking to name the VCA group)
local mute_solo = 1 -- (set to 0 to disable mute and solo flags)
local position = 3 -- (set VCA Master track position 1 - TOP , 0 - Bottom, 3 - Above selected tracks)
local warning = 0  -- (gives user a warning popup to select tracks if no tracks are selected, 0 OFF , 1 ON)
---------------
--------------------------------------------------------------------------------------
-- GROUP FLAGS

local VCA_FLAGS = { "VOLUME_MASTER", 
                    "VOLUME_SLAVE", 
                    "VOLUME_VCA_MASTER", 
                    "VOLUME_VCA_SLAVE",
                    "PAN_MASTER",
                    "PAN_SLAVE", 
                    "WIDTH_MASTER", 
                    "WIDTH_SLAVE" ,
                    "MUTE_MASTER", 
                    "MUTE_SLAVE", 
                    "SOLO_MASTER", 
                    "SOLO_SLAVE", 
                    "RECARM_MASTER", 
                    "RECARM_SLAVE" ,
                    "POLARITY_MASTER", 
                    "POLARITY_SLAVE", 
                    "AUTOMODE_MASTER",
                    "AUTOMODE_SLAVE"
                  }
local free_group,master_pos = nil, nil 
local tracks, vca_group ,cnt = {}, {}, 1 
for i = 1 ,64 do vca_group[i] = 0 end

local function scan_groups()
  local cnt_tr = reaper.CountTracks(0)
  for i = 0 , cnt_tr-1 do
    local tr = reaper.GetTrack(0,i)
    for k = 1 , #vca_group do
      if reaper.GetSetTrackGroupMembership(tr,"VOLUME_VCA_MASTER", 0,0) == 2^(k-1) or reaper.GetSetTrackGroupMembershipHigh(tr,"VOLUME_VCA_MASTER", 0,0) == 2^((k-32)-1) then cnt = cnt + 1 end
      for j = 1 , #VCA_FLAGS do
        if reaper.GetSetTrackGroupMembership(tr,VCA_FLAGS[j], 0,0) == 2^(k-1) or 
          reaper.GetSetTrackGroupMembershipHigh(tr,VCA_FLAGS[j], 0,0) == 2^((k-32)-1) then 
          vca_group[k] = nil
        end
      end
    end
  end
end
 
function create_VCAs()
 local group 
 for i = group_range, #vca_group do
 --for k,v in pairs(vca_group) do
   if vca_group[i] == 0 then
     if i > 32 then group = reaper.GetSetTrackGroupMembershipHigh free_group = 2^((i-32)-1)
     else group = reaper.GetSetTrackGroupMembership free_group = 2^(i-1)
     end
     if group_range == 32 then break end -- ADD BREAK TO ITERIATE FROM 1 to 32, without its 32 to 1
    end
  end
  
  if position == 1 then
    master_pos = cnt - 1
  elseif position == 0 then
    master_pos = reaper.CountTracks(0)
  else
    master_pos = reaper.CSurf_TrackToID( tracks[1], false ) - 1 -- ADD VCA ABOVE SELECTED TRACKS
  end
  
  -- INSERT MASTER VCA TRACK AT TOP OR BOTTTOM
  reaper.InsertTrackAtIndex(master_pos, false)
  reaper.TrackList_AdjustWindows(false)
  local tr = reaper.GetTrack(0,master_pos) 
  
  -- VCA NAMING
  if popup == 0 then
    local retval, track_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "VCA " .. cnt , true)
  else
    local ret , name = reaper.GetUserInputs("ADD VCA NAME ", 1, "VCA NAME :", "")
    -- IF OK WAS CLICKED
    if ret then 
      local retval, track_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name , true)
    -- IF CANCEL OR ESC KEY IS PRESSED DELETE TRACK AND DO NOTHING
    else      
      reaper.DeleteTrack(tr)
      return 0
    end
  end
 
  -- SET TRACK AS VCA MASTER
  local VCA_M = group(tr,"VOLUME_VCA_MASTER", free_group,free_group)
    if mute_solo == 1 then 
      local VCA_M_MUTE = group(tr,"MUTE_MASTER", free_group,free_group)
      local VCA_M_SOLO = group(tr,"SOLO_MASTER", free_group,free_group)
    end
    
  -- SET VCA SLAVES  
  for i = 1, #tracks do
    local tr = tracks[i]
    local VCA_S = group(tr,"VOLUME_VCA_SLAVE", free_group,free_group)
      if mute_solo == 1 then
        local VCA_S_MUTE = group(tr,"MUTE_SLAVE", free_group,free_group)
        local VCA_S_SOLO = group(tr,"SOLO_SLAVE", free_group,free_group)
      end
  end
end

local function main()
  local cnt_sel = reaper.CountSelectedTracks(0)
  if warning == 1 and cnt_sel == 0 then
    reaper.ShowMessageBox("Please select tracks to create VCA", "WARNING", 0)
  end
  -- IF VCA GROUP TABLE IS EMPTY DO NOT CREATE NEW GROUP
  if #vca_group ~= 0 and cnt_sel > 0 then 
    -- ADD SELECTED TRACKS TO TABLE (FOR MAKING THEM VCA SLAVES)
    for i = 0, cnt_sel-1 do
      local tr = reaper.GetSelectedTrack(0,i)
      tracks[#tracks+1] = tr
    end
    create_VCAs()
  end
end
scan_groups()
main()