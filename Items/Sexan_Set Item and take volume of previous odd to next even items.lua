--[[
 * ReaScript Name: Set Item and take volume of odd to even items.lua
 * Discription: Script sets volume of item and take of previous odd item to next even item
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.3
--]]
 
--[[
 * Changelog:
 * v1.3 (2017-07-25)
  + Small modifications
--]]

-- Aquired from SPK77 Script - Copy take volume envelope from selected take to other takes in same group
local function get_and_show_take_envelope(take, envelope_name)
  local env = reaper.GetTakeEnvelopeByName(take, envelope_name)
  local item 
 
  if env == nil then
    item = reaper.GetMediaItemTake_Item(take)
    local sel = reaper.IsMediaItemSelected(item)
    if not sel then
      reaper.SetMediaItemSelected(item, true)
    end
    if     envelope_name == "Volume" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV1"), 0) -- show take volume envelope
    elseif envelope_name == "Pan" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV2"), 0)    -- show take pan envelope
    elseif envelope_name == "Mute" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV3"), 0)   -- show take mute envelope
    elseif envelope_name == "Pitch" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV10"), 0) -- show take pitch envelope
    end
    if sel then
      reaper.SetMediaItemSelected(item, false)
    end
    env = reaper.GetTakeEnvelopeByName(take, envelope_name)
  end
  return env,item
end

local function Main() 
  -- ALWAYS USE TRACK 3 
  local tr =  reaper.GetTrack(0,2)
  
  if not tr then return 0 end
  
  local cnt_items = reaper.CountTrackMediaItems( tr )  
  reaper.PreventUIRefresh(1)
  
    for i = 1, cnt_items, 2 do
      -- ODD
      local o_item =  reaper.GetTrackMediaItem( tr, i-1 )
      local o_item_v =  reaper.GetMediaItemInfo_Value( o_item, "D_VOL" )
      
      local o_take = reaper.GetActiveTake(o_item)      
      local o_take_v =  reaper.GetMediaItemTakeInfo_Value( o_take, "D_VOL" )
      local o_take_e = get_and_show_take_envelope(o_take, "Volume")
      local retval, env_chunk = reaper.GetEnvelopeStateChunk( o_take_e, "", true )
      
      i = i + 1
      
      -- EVEN
      local e_item =  reaper.GetTrackMediaItem( tr, i-1 )
      local e_item_v = reaper.SetMediaItemInfo_Value( e_item, "D_VOL", o_item_v )
      
      local e_take = reaper.GetActiveTake(e_item)      
      local e_take_v = reaper.SetMediaItemTakeInfo_Value( e_take, "D_VOL", o_take_v )
      local env,item = get_and_show_take_envelope(e_take, "Volume")
      local set_env = reaper.SetEnvelopeStateChunk(env, env_chunk, true)
        
        if item then
          -- UNSELECT ITEMS
          reaper.SetMediaItemSelected(item, false)
        end 
           
    end
  reaper.PreventUIRefresh(0)  
  reaper.UpdateArrange()
end
Main()
