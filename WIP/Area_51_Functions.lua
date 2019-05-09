function as_item_position(item, as_start, as_end, mouse_time_pos)
  local cur_pos = mouse_time_pos
  if job == "duplicate" then cur_pos = as_end end
  local tsStart, tsEnd = as_start, as_end
  local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_dur = item_lenght + item_start

  local new_start, new_item_lenght, offset
  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS OUT OF ITEM BUT TS END IS IN THEN COPY ONLY PART FROM TS START TO ITEM END
    new_start, new_item_lenght, offset = (item_start-tsStart) + cur_pos, tsEnd - item_start, 0
    return new_start, new_item_lenght, offset, item
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF START IS IN ITEM AND TS END IS OUTSIDE ITEM COPY PART FROM TS START TO TS END
    new_start, new_item_lenght, offset = cur_pos, item_dur - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM
    --new_start, new_item_lenght, offset = tsStart + cur_pos , tsEnd - tsStart, (tsStart - item_start)
    new_start, new_item_lenght, offset = cur_pos , tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart <= item_start and tsEnd >= item_dur then -- >= NEW
    ------ IF BOTH TS START AND END ARE OUTSIDE OF THE ITEM
    new_start, new_item_lenght, offset = (item_start-tsStart) + cur_pos, item_lenght, 0
    return new_start, new_item_lenght, offset, item
  end
end

function get_track_offset(as_tr,m_tr)
  local first_tr = reaper.GetMediaTrackInfo_Value(as_tr, "IP_TRACKNUMBER")
  local mouse_tr = reaper.GetMediaTrackInfo_Value(m_tr, "IP_TRACKNUMBER")
  local offset = (mouse_tr - first_tr)
  return offset
end

function paste_env(tbl, as_tr, as_start, as_end, mouse_tr, mouse_time_pos)
  local offset =  (mouse_time_pos - as_start) 
    for i = 1, #tbl do
      for j = 1 ,#as_tr do
        if reaper.ValidatePtr(as_tr[j], "TrackEnvelope*") then
          reaper.InsertEnvelopePoint( as_tr[j], tbl[i].time + offset, tbl[i].value, tbl[i].shape, tbl[i].tension, tbl[i].selected, true)
        end
      end
    end
end

local first_tr
function paste(tbl, as_tr, as_start, as_end, mouse_tr, mouse_time_pos)
  if not mouse_tr or reaper.ValidatePtr(mouse_tr, "TrackEnvelope*") or not tbl then return end -- DO NOT PASTE IF MOUSE IS OUT OF ARRANGE WINDOW OR ON ENVELOPE
  if not first_tr then first_tr = as_tr end
  local tr_offset = get_track_offset(first_tr, mouse_tr)
  for i = 1, #tbl do
    local item = tbl[i]
    local tr_num = reaper.GetMediaTrackInfo_Value(as_tr, "IP_TRACKNUMBER")
    local tr = reaper.GetTrack( 0, (tr_num + tr_offset) - 1 ) 
    if not tr then reaper.InsertTrackAtIndex((tr_num + tr_offset)-1, true ); tr = reaper.GetTrack(0, (tr_num + tr_offset)-1 ) end -- IF WE ARE PASTING AT THE VERY BOTTOM OF THE PROJECTS AND THERE ARE NO TRACKS TO PASTE,CREATE THEM
    
    local filename, clonedsource
    local take = reaper.GetMediaItemTake(item, 0)
    local source = reaper.GetMediaItemTake_Source(take)
    local m_type = reaper.GetMediaSourceType(source, "")
    local item_volume = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    local new_Item = reaper.AddMediaItemToTrack(tr)---
    local new_Take = reaper.AddTakeToMediaItem(new_Item)
    
    if m_type:find("MIDI") then -- MIDI COPIES GET INTO SAME POOL IF JUST SETTING CHUNK SO WE NEED TO SET NEW POOL ID TO NEW COPY
      local _, chunk = reaper.GetItemStateChunk(item, "")
      local pool_guid = string.match(chunk, "POOLEDEVTS {(%S+)}"):gsub("%-", "%%-")
      local new_pool_guid = reaper.genGuid():sub(2, -2) -- MIDI ITEM
      chunk = string.gsub(chunk, pool_guid, new_pool_guid)
      reaper.SetItemStateChunk(new_Item, chunk, false)
    else -- NORMAL TRACK ITEMS
      filename = reaper.GetMediaSourceFileName(source, "")
      clonedsource = reaper.PCM_Source_CreateFromFile(filename)
    end
    
    local new_item_start, new_item_lenght, offset = as_item_position(item, as_start, as_end, mouse_time_pos)
    reaper.SetMediaItemInfo_Value(new_Item, "D_POSITION", new_item_start)
    reaper.SetMediaItemInfo_Value(new_Item, "D_LENGTH", new_item_lenght)
    local newTakeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    reaper.SetMediaItemTakeInfo_Value(new_Take, "D_STARTOFFS", newTakeOffset + offset)
  
    if m_type:find("MIDI") == nil then reaper.SetMediaItemTake_Source(new_Take, clonedsource) end
  
    reaper.SetMediaItemInfo_Value(new_Item, "D_VOL", item_volume)
  end
end

function get_items_in_as(as_tr, as_start, as_end, as_items)
  local as_items = {}
  for i = 1, reaper.CountTrackMediaItems(as_tr) do
    local item = reaper.GetTrackMediaItem(as_tr, i-1)
    local item_start = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
    local item_end = item_start + item_len
    
    if (as_start >= item_start and as_start < item_end) and (as_end <= item_end and as_end > item_start) or -- IF SELECTION START & END ARE "IN" OR "ON" ITEM (START AND END ARE IN ITEM OR START IS ON ITEM START,END IS ON ITEM END) 
      (as_start < item_start and as_end > item_end ) then -- IF SELECTION START & END ARE OVER ITEM (SEL STARTS BEFORE ITEM END IS AFTER ITEM 
      as_items[#as_items+1] = item
    elseif (as_start >= item_start and as_start < item_end) and (as_end >= item_end) then -- IF SEL START IS IN THE ITEM
      as_items[#as_items+1] = item
    elseif (as_end <= item_end and as_end > item_start) and (as_start <= item_start) then -- IF SEL END IS IN THE ITEM
      as_items[#as_items+1] = item
    end 
  end
  if #as_items ~= 0 then return as_items end
end

function split_or_delete_items(as_tr, as_items_tbl, as_start, as_end, key)
  if not as_items_tbl then return end
  for i = #as_items_tbl, 1, -1 do
    local item = as_items_tbl[i]
    if key == "del" or key == "split" then
      local s_item_first = reaper.SplitMediaItem(item, as_end)
      local s_item_last = reaper.SplitMediaItem(item, as_start)
      
      -- ITEMS FOR DELETING
      if key == "del" then
        if s_item_first and s_item_last then
          reaper.DeleteTrackMediaItem(as_tr, s_item_last)
        elseif s_item_last and not s_item_first then
          reaper.DeleteTrackMediaItem(as_tr, s_item_last)
        elseif s_item_first and not s_item_last then
          reaper.DeleteTrackMediaItem(as_tr, item)
        elseif not s_item_first and not s_item_last then
          reaper.DeleteTrackMediaItem(as_tr, item)
        end
      end
      
    end
  end
  if key == "del" then return key end
end

function get_as_tr_env_pts(as_tr, as_start, as_end)
  local retval, env_name = reaper.GetEnvelopeName(as_tr)
  local env_points = {}
  for i = 1, reaper.CountEnvelopePoints(as_tr) do
    local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(as_tr, i-1)
    if time >= as_start and time <= as_end then
      reaper.SetEnvelopePoint( as_tr, i-1, _, _, _, _, true,_ )
    
      env_points[#env_points + 1] = 
      {
        retval = retval,
        time = time,
        value = value,
        shape = shape,
        tension = tension,
        selected = false
      }
    elseif (time > as_start and time > as_end) or (time < as_start and time < as_end) then
      reaper.SetEnvelopePoint( as_tr, i-1, _, _, _, _, false,_ )
    end
  end
  if #env_points ~= 0 then return env_points end
end

local AI_info = {"D_POOL_ID", "D_POSITION", "D_LENGTH", "D_STARTOFFS", "D_PLAYRATE", "D_BASELINE", "D_AMPLITUDE", "D_LOOPSRC", "D_UISEL", "D_POOL_QNLEN"}
function get_as_tr_AI(as_tr, as_start, as_end)
  local as_AI = {}
  for i = 1, reaper.CountAutomationItems(as_tr) do
    local AI = reaper.GetSetAutomationItemInfo( as_tr, i-1, AI_info[2], 0, false ) -- GET AI POSITION
    if AI >= as_start and AI <= as_end then
      as_AI[#as_AI+1] = {} -- MAKE NEW TABLE FOR AI
      for j = 1, #AI_info do
        as_AI[#as_AI][AI_info[j]] = reaper.GetSetAutomationItemInfo( as_tr, i-1, AI_info[j], 0, false ) -- ADD AI INFO TO AI TABLE
      end
    end
  end
  if #as_AI ~= 0 then return as_AI end
end

function validate_as_items(tbl)
  for i = 1 ,#tbl.items do
    if not reaper.ValidatePtr(tbl.items[i], "MediaItem*") then tbl.items[i] = nil end -- IF ITEM DOES NOT EXIST REMOVE IT FROM TABLE
  end
  if #tbl.items == 0 then tbl.items = nil end -- IF ITEM TABLE IS EMPTY REMOVE TABLE
end

function get_as_info(tbl,key,m_tr,mouse_time_pos)
  --reaper.PreventUIRefresh(1)
  --for i = 1, #tbl do
    local as_start, as_end = tbl.sel_start, tbl.sel_end
     for j = 1, #tbl.tracks do
      local as_tr = tbl.tracks[j].track
      local as_items = tbl.tracks[j].items
      if reaper.ValidatePtr(as_tr, "MediaTrack*") then -- FOT TRACKS ONLY
        if key == "del" or key == "split" then 
          local del = split_or_delete_items(as_tr, as_items, as_start, as_end, key) -- IF DELETING RETURN VAL
          if del then validate_as_items(tbl.tracks[j]) end -- REMOVE ITEMS FROM AS TBL
        end
        if key == "paste" then paste(as_items, as_tr, as_start, as_end, m_tr, mouse_time_pos) end
      end
      if reaper.ValidatePtr(as_tr, "TrackEnvelope*") then -- FOR ENVELOPES ONLY
        --if key == "paste" then paste_env(tbl[i].as_env, tbl[i].tracks, as_start, as_end, m_tr, mouse_time_pos) break end
        --as_env_points[j] = get_as_tr_env_pts(as_tr, as_start, as_end) -- GET ENVELOPE POINTS IN AREA SELECTION
        --as_AI[j] = get_as_tr_AI(as_tr, as_start, as_end) -- GET AI-s IN AREA SELECTION
        --as_env_points = get_as_tr_env_pts(as_tr, as_start, as_end) -- GET ENVELOPE POINTS IN AREA SELECTION
        --as_AI = get_as_tr_AI(as_tr, as_start, as_end) -- GET AI-s IN AREA SELECTION
        -----------------------------------------------------------------------------------------------------------------
        -- AFTER GETTING ALL THE ENVELOPEs-AIs DO STUFF BELOW DEPENDING ON PRESSED KEY (SPLIT,DEL,COPY,PASTE,DUPLICATE...)
        
      end
    end
  --end
  --reaper.PreventUIRefresh(-1)
  --reaper.UpdateArrange() 
end
