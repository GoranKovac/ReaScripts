--[[
 * ReaScript Name: Set Item and take volume of odd to even items.lua
 * Discription: Script sets volume of item and take of previous odd item to next even item
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2017-07-24)
  + Initial Release
--]]

function Main()  
  local tr =  reaper.GetSelectedTrack(0,0)
  
  if not tr then return 0 end
  
  local cnt_items = reaper.CountTrackMediaItems( tr )  
    
    for i = 1, cnt_items, 2 do
      -- ODD
      local o_item =  reaper.GetTrackMediaItem( tr, i-1 )
      local o_take = reaper.GetActiveTake(o_item)
      local o_item_v =  reaper.GetMediaItemInfo_Value( o_item, "D_VOL" )
      local o_take_v =  reaper.GetMediaItemTakeInfo_Value( o_take, "D_VOL" )
      
      i = i + 1
      
      -- EVEN
      local e_item =  reaper.GetTrackMediaItem( tr, i-1 )
      local e_take = reaper.GetActiveTake(e_item)
      local e_item_v = reaper.SetMediaItemInfo_Value( e_item, "D_VOL", o_item_v )
      local e_take_v = reaper.SetMediaItemTakeInfo_Value( e_take, "D_VOL", o_take_v )
    end
    
  reaper.UpdateArrange()
end
Main()
