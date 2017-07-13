--[[
 * ReaScript Name: Create VCA master from selection.lua
 * Discription: Script creates Master VCA for selected tracks and makes them VCA Slave.Also Mute and SOLO flags are added
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.451
--]]
 
--[[
 * Changelog:
 * v1.451 (2017-07-13)
  + Minor error fix
--]]

-- USER SETTING
---------------
popup = 0    -- (set to 0 for no popup, set to 1 for popup asking to name the VCA group)
mute_solo = 1 -- (set to 0 to disable mute and solo flags)
position = 1 -- (set VCA Master track position 1 - TOP , 0 - Bottom)
---------------
--------------------------------------------------------------------------------------
-- GROUP FLAGS
local groups =  { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536,
                  131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432, 67108864,
                  134217728, 268435456, 536870912, 1073741824, 2147483648 
                } 
local unused =  { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536,                  
                  131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432, 67108864,                  
                  134217728, 268435456, 536870912, 1073741824, 2147483648 
                }                

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
local vca_group = {}                                              
local tracks = {}
local top_pos_offset

local function scan_groups()
  local cnt_tr = reaper.CountTracks(0)
  -- SCAN FOR ALL FLAGS
  for i = 0 , cnt_tr-1 do
    local tr = reaper.GetTrack(0,i)
    local VCA_M = reaper.GetSetTrackGroupMembership(tr,"VOLUME_VCA_MASTER", 0,0)
      for j = 1 , #VCA_FLAGS do
        local flags = reaper.GetSetTrackGroupMembership(tr,VCA_FLAGS[j], 0,0)
          for k = 1 , #groups do
            -- IF GROUP IS USED REMOVE IT FROM UNUSED TABLE
            if flags == unused[k] then
              table.remove(unused,k)
            end
          end
      end
      --SCAN VCA MASTER FLAGS ONLY AND ADD IT TO GROUP(NEEDED FOR TRACK CREATION ON TOP)
      for l = 1 , #groups do
        if VCA_M == groups[l] then
          vca_group[#vca_group+1] = groups[l]            
        end
      end      
  end
  top_pos_offset = #vca_group
end
 
local function create_master(free_group)
  if position == 1 then
    master_pos = top_pos_offset
  else
    master_pos = reaper.CountTracks(0)
  end
  -- INSERT MASTER VCA TRACK AT TOP OR BOTTTOM
  reaper.InsertTrackAtIndex(master_pos, false)
  reaper.TrackList_AdjustWindows(false)
  local tr = reaper.GetTrack(0,master_pos) 
  -- VCA NAMING
  if popup == 0 then
    for i = 1 , #groups do
      if free_group == groups[i] then
        local retval, track_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "VCA " .. i , true) 
      end
    end
  else
    local _, name = reaper.GetUserInputs("ADD VCA NAME ", 1, "VCA NAME :", "")
    local retval, track_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name , true)
  end
  -- SET TRACK AS VCA MASTER
  local VCA_M = reaper.GetSetTrackGroupMembership(tr,"VOLUME_VCA_MASTER", free_group,free_group)
    if mute_solo == 1 then 
      local VCA_M_MUTE = reaper.GetSetTrackGroupMembership(tr,"MUTE_MASTER", free_group,free_group)
      local VCA_M_SOLO = reaper.GetSetTrackGroupMembership(tr,"SOLO_MASTER", free_group,free_group)
    end
end

local function set_slaves()
  local free_group
  local cnt_sel = reaper.CountSelectedTracks(0)
  -- IF UNUSED GROUP TABLE IS EMPTY DO NOT CREATE NEW GROUP
  if #unused ~= 0 and cnt_sel > 0 then 
    -- ADD SELECTED TRACKS TO TABLE (FOR MAKING THEM VCA SLAVES)
    for i = 0, cnt_sel-1 do
      local tr = reaper.GetSelectedTrack(0,i)
      tracks[#tracks+1] = tr
    end
    
    for i = 1, #tracks do
      local tr = tracks[i]
      -- SET FIRST UNUSED GROUP
      free_group = unused[#unused]
      -- SET SELECTED TRACKS (TABLE) AS VCA SLAVES)  
      local VCA_S = reaper.GetSetTrackGroupMembership(tr,"VOLUME_VCA_SLAVE", free_group,free_group)
        if mute_solo == 1 then
          local VCA_S_MUTE = reaper.GetSetTrackGroupMembership(tr,"MUTE_SLAVE", free_group,free_group)
          local VCA_S_SOLO = reaper.GetSetTrackGroupMembership(tr,"SOLO_SLAVE", free_group,free_group)
        end
    end   
    create_master(free_group)
  end
end
scan_groups()
set_slaves()
