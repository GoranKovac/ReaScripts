--[[
 * ReaScript Name: Select all other items on track.lua
 * Discription: Script select all items on the track except selected one
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.13
--]]
 
--[[
 * Changelog:
 * v1.13 (2017-07-23)
  + wrong api used
--]]

function Main()
  sel_item = reaper.GetSelectedMediaItem( 0, 0 )
  
  if not sel_item then return 0 end
  
  local tr =   reaper.GetMediaItem_Track( sel_item )
  reaper.SetMediaItemInfo_Value( sel_item, "B_UISEL", 0 )
  
  cnt_items = reaper.CountTrackMediaItems( tr ) 
  
    for i = 1, cnt_items do
      local item =  reaper.GetTrackMediaItem( tr, i-1 )
      if item ~= sel_item then 
        reaper.SetMediaItemSelected( item, true )       
      end
    end 
  reaper.UpdateArrange()
end
Main()
