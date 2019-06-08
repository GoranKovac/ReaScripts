function move_items_envs(tbl,offset)
  for i = 1, #tbl.info do
    if tbl.info[i].items then
      for j = 1, #tbl.info[i].items do
        local as_item = tbl.info[i].items[j]
        local as_item_pos = reaper.GetMediaItemInfo_Value( as_item, "D_POSITION" )
        reaper.SetMediaItemInfo_Value( as_item, "D_POSITION", as_item_pos + offset)
      end
    elseif tbl.info[i].env_points then
      for j = 1, #tbl.info[i].env_points do
        local env = tbl.info[i].env_points[j]
        env.time = env.time + offset
        reaper.SetEnvelopePoint( tbl.info[i].track, env.id, env.time, env.val, env.shape, env.tension, env.selected, true )
      end  
    end
  end
end

local function add_info_to_edge(tbl)
  local tracks = {}
  for i = 1, #tbl.info do
    tracks[#tracks+1] = {track = tbl.info[i].track} 
  end


  local info   = GetRangeInfo(tracks, tbl.time_start,  tbl.time_end)
  tbl.info = info  
end

function zone(z)
  local rx, ry   = mouse.dx, mouse.dy
  local zoom_lvl = reaper.GetHZoomLevel()
  local offset = (rx / zoom_lvl)
  if  z[1] == "C" then
    if z[2].time_start >= 0 then
      z[2].time_start  = z[2].time_start  + (rx / zoom_lvl)
      if z[2].time_start > 0 then
        z[2].time_end    = z[2].time_end    + (rx / zoom_lvl)
        move_items_envs(z[2],offset)
      end
    else
      z[2].time_start = 0
    end
  elseif z[1] == "L" then
    if z[2].time_start <= z[2].time_end then
      z[2].time_start  = z[2].time_start  + (rx / zoom_lvl)
      add_info_to_edge(z[2])
    else z[2].time_start = z[2].time_end
    end
    
  elseif z[1] == "R" then
    if z[2].time_end >= z[2].time_start then
      z[2].time_end = z[2].time_end + (rx / zoom_lvl)
      add_info_to_edge(z[2])
    else
      z[2].time_end = z[2].time_start
    end
  end
  
  z[2]:update_xywh()
end

function item_blit(item, as_start, as_end , pos)
  local tsStart, tsEnd = as_start, as_end
  local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_start  = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_dur    = item_lenght + item_start
  
  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS OUT OF ITEM BUT TS END IS IN THEN COPY ONLY PART FROM TS START TO ITEM END
    local new_start, new_item_lenght, offset = (pos ~= nil) and ((item_start-tsStart) + pos) or item_start, tsEnd - item_start, 0
    return new_start, new_item_lenght, offset, item
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF START IS IN ITEM AND TS END IS OUTSIDE ITEM COPY PART FROM TS START TO TS END
    local new_start, new_item_lenght, offset = (pos ~= nil) and pos or tsStart , item_dur - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM
    local new_start, new_item_lenght, offset = (pos ~= nil) and pos or tsStart , tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart <= item_start and tsEnd >= item_dur then -- >= NEW
    ------ IF BOTH TS START AND END ARE OUTSIDE OF THE ITEM
    local new_start, new_item_lenght, offset = (pos ~= nil) and ((item_start-tsStart) + pos) or item_start, item_lenght, 0
    return new_start, new_item_lenght, offset, item
  end
  
end

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

function env_prop(env)
  br_env = reaper.BR_EnvAlloc(env, false)
  local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type, faderScaling = reaper.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
end

function insert_edge_points(env, as_time_tbl, offset, src_tr)
  
  local edge_pts = {}
  
    local retval, value_st, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( env, as_time_tbl[1] + offset, 0, 0 ) -- DESTINATION START POINT
    reaper.InsertEnvelopePoint(env, as_time_tbl[1] + offset - 0.001, value_st, 0, 0, true, true)
    local retval, value_et, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( env, as_time_tbl[2] + offset, 0, 0 ) -- DESTINATION END POINT
    reaper.InsertEnvelopePoint(env, as_time_tbl[2] + offset + 0.001, value_et, 0, 0, true, true)
    
    reaper.DeleteEnvelopePointRange( env, as_time_tbl[1] + offset, as_time_tbl[2]+ offset )
    
    local retval, value_s, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( src_tr, as_time_tbl[1], 0, 0 )  -- SOURCE START POINT
    reaper.InsertEnvelopePoint(env, as_time_tbl[1] + offset + 0.001, value_s, 0, 0, true, false)
    
    local retval, value_e, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate( src_tr, as_time_tbl[2], 0, 0 )  -- SOURCE END POINT
    reaper.InsertEnvelopePoint(env, as_time_tbl[2] + offset - 0.001, value_e, 0, 0, true, false)
   
end

function paste_env(tbl, mouse_tr, mouse_time_pos, active_as)
  if not mouse_tr then return end -- DO NOT PASTE IF MOUSE IS OUT OF ARRANGE WINDOW 
  local first_as_tr_in_all = find_highest_tr()
  
  for i = 1, #tbl do 
    local tbl2 = active_as or tbl[i]              -- USE ACTIVE_AS TBL OR MAIN ONE WITH ALL OF THEM
    local pos = mouse_time_pos 
    local offset_paste =  (pos - tbl2.time_start)
    if i > 1 then pos = pos + (tbl2.time_start - tbl[1].time_start) end -- IF i > 1 THAT MEANS WE ARE PASTING ALL AS AT ONCE, ELSE PASTE ACTIVE AS
    
    for j = 1 ,#tbl2.info do
      
      if tbl2.info[j].env_points then
        local as_tr = tbl2.info[j].track
        local offset , tr = GetTrackOffset(as_tr, mouse_tr, first_as_tr_in_all, tbl2.info[#tbl2.info].track)
        local env_t, env_b, env_h, tr_env = GetEnvOffset_MatchCriteria(tr, tbl2.info[j].env_name,tbl2.info[j].track,j)
        if tr_env then
        insert_edge_points(tr_env, {tbl2.time_start, tbl2.time_end}, offset_paste, as_tr)
        if reaper.ValidatePtr(tr, "MediaTrack*") then -- NOT NEEDED MAYBE
          for l = 1 ,#tbl2.info[j].env_points do
            local env = tbl2.info[j].env_points[l]
            reaper.InsertEnvelopePoint( 
                                        tr_env, 
                                        env.time + offset_paste, 
                                        env.value, 
                                        env.shape, 
                                        env.tension, 
                                        env.selected, 
                                        true
                                      )
          end
          reaper.Envelope_SortPoints( tr_env )
        end
        end
      end
    end
  end
end
   
local function create_item(item, tr, as_start, as_end, mouse_time_pos)
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

function paste(items, item_track, as_start, as_end, pos_offset, first_track)
  if not mouse.tr then return end -- DO NOT PASTE IF MOUSE IS OUT OF ARRANGE WINDOW
  reaper.PreventUIRefresh(1)
  
  local offset_track, under_last_tr = generic_track_offset(item_track, first_track)
  
  if under_last_tr and under_last_tr > 0 then 
    for t = 1, under_last_tr do reaper.InsertTrackAtIndex(( reaper.GetNumTracks() ), true ) end-- IF THE TRACKS ARE BELOW LAST TRACK OF THE PROJECT CREATE HAT TRACKS
    offset_track = reaper.GetTrack(0,reaper.GetNumTracks()-1)
  end
  
  for i = 1, #items do
    local item = items[i]
    local mouse_offset = pos_offset + mouse.p 
    create_item(item, offset_track, as_start, as_end, mouse_offset) -- CREATE ITEMS AT NEW POSITION
  end
        
 reaper.PreventUIRefresh(-1)
end

function AreaDo(tbl,job)
  reaper.PreventUIRefresh(1)
  for a = 1, #tbl do
    local tbl = tbl[a]
    
    local pos_offset        = 0
          pos_offset        = pos_offset + (tbl.time_start - lowest_start()) --  OFFSET AREA SELECTIONS TO MOUSE POSITION
    local as_start, as_end  = tbl.time_start, tbl.time_end
    
    for i = 1, #tbl.info do
      local info = tbl.info[i]
      local first_tr = find_highest_tr(info.track)
      
      if info.items then
        local item_track    = info.track
        local item_data     = info.items
        if job == "PASTE" then paste(info.items, item_track, as_start, as_end, pos_offset, first_tr) end
        if job == "del" or job == "split" then split_or_delete_items(item_track, item_data, as_start, as_end, job) end
        
      elseif info.env_name then
        local env_track     = info.track
        local env_name      = info.env_name
        local env_data      = info.env_points
        
      end
    end
    if job == "del" then tbl.info = GetAreaInfo(tbl) end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
end

function get_and_show_take_envelope(take, envelope_name)
  local env = reaper.GetTakeEnvelopeByName(take, envelope_name)
  
  if env == nil then
    local item = reaper.GetMediaItemTake_Item(take)
    local sel = reaper.IsMediaItemSelected(item)
    
    if not sel then reaper.SetMediaItemSelected(item, true) end
    
    if     envelope_name == "Volume" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV1"), 0) -- show take volume envelope
    elseif envelope_name == "Pan" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV2"), 0)    -- show take pan envelope
    elseif envelope_name == "Mute" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV3"), 0)   -- show take mute envelope
    elseif envelope_name == "Pitch" then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV10"), 0) -- show take pitch envelope
    end
    
    if sel then reaper.SetMediaItemSelected(item, true) end
    env = reaper.GetTakeEnvelopeByName(take, envelope_name)
  end
  
  return env
end

function get_take_env(item)
  local source_take = reaper.GetActiveTake(item)
  local source_env = get_and_show_take_envelope(source_take, "Volume")
  
  for i = 1 , reaper.CountTakeEnvelopes( take ) do
    local env = reaper.GetTakeEnvelope( take, i )
    retval, str = reaper.GetEnvelopeStateChunk( env, "", true )
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

function get_env(as_tr, as_start, as_end)
  local env_points = {}
  
  for i = 1 , reaper.CountTrackEnvelopes( as_tr ) do
    local tr = reaper.GetTrackEnvelope( as_tr, i-1 )
    
    for i = 1, reaper.CountEnvelopePoints(tr) do
      local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(tr, i-1)
      
      if time >= as_start and time <= as_end then
        reaper.SetEnvelopePoint( tr, i-1, _, _, _, _, true,_ )
      
        env_points[#env_points + 1] = 
        {
          id = i-1,
          retval    = retval,
          time      = time,
          value     = value,
          shape     = shape,
          tension   = tension,
          selected  = true
        }
      end
    end
  end
  
  if #env_points ~= 0 then return env_points end
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
        id = i-1,
        retval    = retval,
        time      = time,
        value     = value,
        shape     = shape,
        tension   = tension,
        selected  = true
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
