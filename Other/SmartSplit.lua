function Main()
  count_sel_items = reaper.CountSelectedMediaItems(0)
  if count_sel_items > 0 then
  SmartSplit()
  end
  
end

function SmartSplit()
   item = reaper.GetSelectedMediaItem(0, 0)
   item_start = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
   item_len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
   item_end = item_start + item_len
   Tstart, Tend = reaper.GetSet_LoopTimeRange(0, 0, 0, 0, 0)   
        
     --is item in TS
     if Tstart <= item_start and Tend >= item_end then
     reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWSPLITXFADELEFT"), 0)
    
     --is item outside TS (left side)
     elseif Tstart > item_start and Tstart >= item_end then
           reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWSPLITXFADELEFT"), 0)
           
     --is item outside TS (left side but end in TS)
     elseif Tstart > item_start and Tend > item_end then
     reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWSPLITXFADELEFT"), 0)
     
    
     --is item outside TS (right side)
     elseif Tend <= item_start and Tend < item_end then
           reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWSPLITXFADELEFT"), 0)
    
    --is item outside TS (right side but start in TS)
    elseif Tstart < item_start and Tend < item_end then
           pos = reaper.GetCursorPosition()
           reaper.SetEditCurPos(Tend, false, false)           
           reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWSPLITXFADELEFT"), 0)
           reaper.SetEditCurPos(Tstart, false, false)          
           reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_ADDLEFTITEM"), 0)
           csi = reaper.CountSelectedMediaItems(0)
           for i = 0 , csi-1 do
             curitem = reaper.GetSelectedMediaItem(0, i)
             curitem_start = reaper.GetMediaItemInfo_Value(curitem,"D_POSITION")
             curitem_len = reaper.GetMediaItemInfo_Value(curitem,"D_LENGTH")
             curitem_end = curitem_start + curitem_len
               if curitem_start > Tstart and curitem_end > Tend then
               reaper.SetMediaItemInfo_Value(curitem,"B_UISEL", 0)
               end
           end
           
           
     elseif Tstart == Tend then
            reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_AWSPLITXFADELEFT"), 0)
    
     --is item over TS
     elseif Tstart >= item_start and Tend <= item_end then
           reaper.Main_OnCommand(40061, 0)
                      
     end
end

Main()
