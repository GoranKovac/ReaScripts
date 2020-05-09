--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.07
	 * NoIndex: true
--]]
local reaper = reaper

function Buffer_copy(tbl)
  for a = 1, #tbl do
    local tbl_t = tbl[a]
    for i = 1, #tbl_t.sel_info do
      Buffer_area_data(tbl_t.sel_info[i].items)
    end
  end
end

function TranslateRange(value, oldMin, oldMax, newMin, newMax)
	local oldRange = oldMax - oldMin;
	local newRange = newMax - newMin;
	local newValue = ((value - oldMin) * newRange / oldRange) + newMin;
	return newValue
end

function deselect_all_ai_on_track(env_track)
  for i = 0,  reaper.CountAutomationItems( env_track ) do
    reaper.GetSetAutomationItemInfo(env_track, i-1, "D_UISEL", 0, true) -- SET AI DESELECTED
  end
end

function get_AI_edges(as_start, as_end, item_start, item_end, flag)
  if (as_start >= item_start and as_start < item_end) and (as_end <= item_end and as_end > item_start) and flag == "IN" then --or-- IF SELECTION START & END ARE "IN" OR "ON" ITEM (START AND END ARE IN ITEM OR START IS ON ITEM START,END IS ON ITEM END)
    return as_start, as_end
  elseif (as_start < item_start and as_end > item_end) and flag == "OUT" then
    return  item_start, item_end-- IF SELECTION START & END ARE OVER ITEM (SEL STARTS BEFORE ITEM END IS AFTER ITEM      
  elseif (as_start >= item_start and as_start < item_end) and (as_end >= item_end) and flag == "LEFT" then -- IF SEL START IS IN THE ITEM
    return as_start
  elseif (as_end <= item_end and as_end > item_start) and (as_start <= item_start) and  flag == "RIGHT" then-- IF SEL END IS IN THE ITEM
    return as_end
  end
end

function del_AI(env_track, data, t_start, t_dur, offset)
  if reaper.ValidatePtr(env_track, "MediaTrack*") or type(env_track) == "string" then return end
  deselect_all_ai_on_track(env_track)
  for i = 0,  reaper.CountAutomationItems( env_track ) do
    local AI_idx = i-1
    local AI_pos = reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_POSITION", 0, false) -- AI POSITION
    local AI_len = reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_LENGTH", 0, false) -- AI POSITION
    local AI_start_off = reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_STARTOFFS", 0, false) -- AI POSITION
    if get_AI_edges(t_start, t_start + t_dur, AI_pos, AI_pos + AI_len, "OUT") then
      reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_UISEL", 1, true) -- SET AI SELECTED
    else
      local new_end = get_AI_edges(t_start, t_start + t_dur, AI_pos, AI_pos + AI_len, "LEFT")
      local new_start = get_AI_edges(t_start, t_start + t_dur, AI_pos, AI_pos + AI_len, "RIGHT")
      local new_in_start, new_in_end = get_AI_edges(t_start, t_start + t_dur, AI_pos, AI_pos + AI_len, "IN")
      if new_end then
        local new_AI_len = new_end - AI_pos
        reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_LENGTH", new_AI_len, true) -- AI LEN
      elseif new_start then
        local new_AI_end = new_start - AI_pos
        reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_LENGTH", AI_len - new_AI_end, true) -- AI LEN
        reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_POSITION", new_start, true) -- AI START
        reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_STARTOFFS", AI_start_off + new_AI_end, true) -- AI START OFFSET
      elseif new_in_start and new_in_end then
        local AI_1_new_len = new_in_start - AI_pos
        local AI_1_new_start = AI_pos

        local AI_2_new_start = new_in_end
        local AI_2_new_len = (AI_pos + AI_len) - new_in_end
        local AI_2_new_Start_off = (new_in_end - AI_pos) --+ AI_start_off

        local new_Aidx = reaper.InsertAutomationItem(env_track, -1, AI_pos, AI_len) -- CREATE NEW ITEM
        reaper.GetSetAutomationItemInfo(env_track, new_Aidx, "D_UISEL", 0, true) -- SET AI DESELECTED SO ACTION WONT REMOVE IT

        for j = 0, reaper.CountEnvelopePointsEx( env_track, AI_idx) do
          local retval, time, value, shape, tension, selected = reaper.GetEnvelopePointEx( env_track, AI_idx, j)
          reaper.InsertEnvelopePointEx(env_track, new_Aidx, time, value, shape, tension, 0, true )
        end
        reaper.Envelope_SortPointsEx( env_track, new_Aidx )
        reaper.GetSetAutomationItemInfo(env_track, new_Aidx, "D_POSITION", AI_2_new_start, true) -- AI1 START
        reaper.GetSetAutomationItemInfo(env_track, new_Aidx, "D_LENGTH", AI_2_new_len, true) -- AI1 LEN
        reaper.GetSetAutomationItemInfo(env_track, new_Aidx, "D_STARTOFFS", AI_2_new_Start_off, true) -- AI1 OFFSET

        reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_POSITION", AI_1_new_start, true) -- AI1 START
        reaper.GetSetAutomationItemInfo(env_track, AI_idx, "D_LENGTH", AI_1_new_len, true) -- AI1 LEN
      end
    end
  end
  reaper.Main_OnCommand(42086,0)
end

local AI_info = {
  "D_POOL_ID",
  "D_POSITION",
  "D_LENGTH",
  "D_STARTOFFS",
  "D_PLAYRATE",
  "D_BASELINE",
  "D_AMPLITUDE",
  "D_LOOPSRC",
  "D_UISEL",
  "D_POOL_QNLEN",
  "ID"
}

function Paste_AI(tr, src_tr, data, t_start, t_dur, t_offset, job)
  if not data then return end
  if tr and reaper.ValidatePtr(tr, "TrackEnvelope*") then
    local d_min = env_prop(tr,"minValue")
    local d_max = env_prop(tr,"maxValue")
    local s_min = env_prop(src_tr,"minValue")
    local s_max = env_prop(src_tr,"maxValue")
    for i = 1, #data do
      if not data[i].info then return end
      local AI_offset = data[i].info["D_POSITION"]
      local Aidx = reaper.InsertAutomationItem( tr, -1, AI_offset + t_offset, data[i].info["D_LENGTH"])
      for j = 1, #data[i].points do
        local ai_point = data[i].points[j]
          reaper.InsertEnvelopePointEx( tr, Aidx, ai_point.time + t_offset, TranslateRange(ai_point.value,s_min,s_max,d_min,d_max), ai_point.shape, ai_point.tension, 0, true ) --(t_offset - t_start)
      end
      reaper.Envelope_SortPointsEx( tr, Aidx )
      reaper.GetSetAutomationItemInfo(tr, Aidx, "D_UISEL", 0, true) -- DESELECT
    end
  end
end

function split_or_delete_items(tr, as_items_tbl, as_start, as_dur, job)
  if reaper.ValidatePtr(tr, "TrackEnvelope*") then return end
  for i = reaper.CountTrackMediaItems(tr), 1, -1 do
    local item = reaper.GetTrackMediaItem( tr, i-1 )
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    if is_item_in_as(as_start, as_start + as_dur, item_start, item_start + item_len) then
      if job == "Delete" or job == "Split" or job == "Split_for_move" then
        local s_item_first = reaper.SplitMediaItem(item, as_start + as_dur)
        local s_item_last = reaper.SplitMediaItem(item, as_start)
        if job == "Delete" then
          if s_item_first and s_item_last then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( s_item_last ), s_item_last)
          elseif s_item_last and not s_item_first then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( s_item_last ), s_item_last)
          elseif s_item_first and not s_item_last then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( item ), item)
          elseif not s_item_first and not s_item_last then
            reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( item ), item)
          end
        end
      end
    end
	end
end

function env_prop(env,val)
  local br_env = reaper.BR_EnvAlloc(env, false)
  local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type_, faderScaling = reaper.BR_EnvGetProperties(br_env, true, true, true, true, 0, 0, 0, 0, 0, 0, true)
  local properties = {["active"] = active,
                      ["visible"] = visible,
                      ["armed"] = armed,
                      ["inLane"] = inLane,
                      ["defaultShape"] =defaultShape,
                      ["laneHeight"] = laneHeight,
                      ["minValue"] = minValue,
                      ["maxValue"] = maxValue,
                      ["centerValue"] = centerValue,
                      ["type"] = type_,
                      ["faderScaling"] = faderScaling
                    }
  reaper.BR_EnvFree( env, true )
  return properties[val]
end

function env_eval(env,time)
  local retval, value_st, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env, time + 0, 0, 0) -- DESTINATION START POINT
  return value_st
end

function insert_edge_points(env, as_start, as_dur, time_offset, pt_s, pt_e, srt)
  if not reaper.ValidatePtr(env, "TrackEnvelope*") then return end -- DO NOT ALLOW MEDIA TRACK HERE
  local as_end = as_start + as_dur

  local d_min = env_prop(env,"minValue")
  local d_max = env_prop(env,"maxValue")
  local d_c_val = env_prop(env,"centerValue")

  local s_min = srt and env_prop(srt,"minValue")
  local s_max = srt and env_prop(srt,"maxValue")
  local s_c_val = env_prop(srt,"centerValue")

  local retval, value_st, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env, as_start + time_offset, 0, 0) -- DESTINATION START POINT -- CURENT VALUE AT THAT POSITION
  reaper.InsertEnvelopePoint(env, as_start + time_offset - 0.00001, value_st, 0, 0, true, true)
  local retval, value_et, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env, as_end + time_offset, 0, 0) -- DESTINATION END POINT -- CURENT VALUE AT THAT POSITION
  reaper.InsertEnvelopePoint(env, as_end + time_offset + 0.00001, value_et, 0, 0, true, true)

  if pt_s and pt_e then
    local retval, value_s1t, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(srt, as_start, 0, 0) -- DESTINATION START POINT -- CURENT VALUE AT THAT POSITION
    local retval, value_e1t, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(srt, as_end, 0, 0) -- DESTINATION END POINT -- CURENT VALUE AT THAT POSITION
    value_s1t = Check_env_scaling(srt, env, value_s1t)
    value_e1t = Check_env_scaling(srt, env, value_e1t)
    reaper.InsertEnvelopePoint(env, as_start + time_offset + 0.00001, TranslateRange(value_s1t,s_min,s_max,d_min,d_max), 0, 0, true, true)
    reaper.InsertEnvelopePoint(env, as_end + time_offset - 0.00001, TranslateRange(value_e1t,s_min,s_max,d_min,d_max), 0, 0, true, true)
    --reaper.InsertEnvelopePoint(env, as_start + time_offset - 0.001, TranslateRange(pt_s.value,s_min,s_max,d_min,d_max), 0, 0, true, true)
    --reaper.InsertEnvelopePoint(env, as_end + time_offset - 0.001, TranslateRange(pt_e.value,s_min,s_max,d_min,d_max), 0, 0, true, true)
  end
  reaper.Envelope_SortPoints( env )
end

function del_env(env_track, as_start, as_dur, offset)
  if reaper.ValidatePtr(env_track, "MediaTrack*") or type(env_track) == "string" then return end

  local c_val = env_prop(env_track,"centerValue")
  local retval, cur_as_start, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env_track, as_start + offset, 0, 0) -- DESTINATION START POINT -- CURENT VALUE AT THAT POSITION
  reaper.InsertEnvelopePoint(env_track, as_start + offset - 0.00001, cur_as_start, 0, 0, true, true)

  local retval, cur_as_end, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env_track, as_start + as_dur + offset, 0, 0) -- DESTINATION END POINT -- CURENT VALUE AT THAT POSITION
  reaper.InsertEnvelopePoint(env_track, as_start + as_dur + offset + 0.00001, cur_as_end, 0, 0, true, true)
  reaper.DeleteEnvelopePointRange(env_track, as_start + offset - 0.00001, as_start + as_dur + offset + 0.00001)
	reaper.Envelope_SortPoints(env_track)
end

function Check_env_scaling(src, dst, val)
  local mode_s = reaper.GetEnvelopeScalingMode( src )
  local mode_d = reaper.GetEnvelopeScalingMode( dst )

  if mode_s ~= mode_d then
    if mode_s == 1 and mode_d == 0 then
      val = reaper.ScaleFromEnvelopeMode(1, val)
    elseif mode_s == 0 and mode_d == 1 then
      val = reaper.ScaleToEnvelopeMode(1, val)
    end
  end

  return val
end

function paste_env(tr, env_name, env_data, as_start, as_dur, time_offset, job)
  if not env_data then
    --insert_edge_points(tr, as_start, as_dur, time_offset)
    del_env(tr, as_start, as_dur, time_offset)
    return
  end
  if tr and reaper.ValidatePtr(tr, "TrackEnvelope*") then -- IF TRACK HAS ENVELOPES PASTE THEM
    del_env(tr, as_start, as_dur, time_offset)
    insert_edge_points(tr, as_start, as_dur, time_offset, env_data[1], env_data[#env_data], env_name) -- INSERT EDGE POINTS AT CURRENT ENVELOE VALUE AND DELETE WHOLE RANGE INSIDE (DO NOT ALLOW MIXING ENVELOPE POINTS AND THAT WEIRD SHIT)
    --del_env(tr, as_start, as_dur, time_offset)

    local d_min = env_prop(tr,"minValue")
    local d_max = env_prop(tr,"maxValue")
    local s_min = env_prop(env_name,"minValue")
    local s_max = env_prop(env_name,"maxValue")

    for i = 1, #env_data do
        local env = env_data[i]
        local env_val = Check_env_scaling(env_name, tr, env.value)
         -- msg(env_data[i].value .. " " .. env_val)
          reaper.InsertEnvelopePoint(
          tr,
          env.time +  time_offset,
          TranslateRange(env_val,s_min,s_max,d_min,d_max),
          env.shape,
          env.tension,
          env.selected,
          true
        )
    end
    reaper.Envelope_SortPoints(tr)
  end
end

function get_chunk(item)
  if item then
    local _, chunk = reaper.GetItemStateChunk( item, "", false )
    return chunk
  end
end

function Buffer_area_data(data)
  if not data then return end
  for i = 1, #data do
    local item = data[i]
    local chunk = get_chunk(item)
    data[i] = chunk
  end
end

function create_item(tr, data, as_start, as_dur, time_offset, job)
  if not data or tr == reaper.GetMasterTrack(0) then
    split_or_delete_items(tr, data, as_start + time_offset, as_dur, "Delete")
    return
  end
  split_or_delete_items(tr, data, as_start + time_offset, as_dur, "Delete")
  for i = 1, #data do
    local chunk = type(data[i]) == "string" and data[i] or get_chunk(data[i]) -- DUPLICATE DOES NOT NEED BUFFER SO WE CONVERT ITEM TO CHUNK
    local empty_item = reaper.AddMediaItemToTrack(tr)
    reaper.SetItemStateChunk(empty_item, chunk, false )

    local item_start = reaper.GetMediaItemInfo_Value( empty_item, "D_POSITION" )
    local item_lenght = reaper.GetMediaItemInfo_Value( empty_item, "D_LENGTH" )
    local new_start, new_lenght, new_source_offset, fade = New_items_position_in_area(as_start, as_start + as_dur, item_start, item_lenght)

    reaper.SetMediaItemInfo_Value(empty_item, "D_POSITION", new_start + time_offset)
    reaper.SetMediaItemInfo_Value(empty_item, "D_LENGTH", new_lenght)
    reaper.GetSetMediaItemInfo_String( empty_item, "GUID", reaper.genGuid(), true )

    if fade then
      if fade == "END" or fade == "BOTH" then
        reaper.SetMediaItemInfo_Value(empty_item, "D_FADEOUTLEN", 0.05) -- RESET FADE IN
      end
      if fade == "START" or fade == "BOTH" then
        reaper.SetMediaItemInfo_Value(empty_item, "D_FADEINLEN", 0.05) -- RESET FADE IN
      end
    end

    for j = 1, reaper.CountTakes( empty_item ) do
      local take_dst = reaper.GetMediaItemTake( empty_item, j-1 )
      local take_startoffset = reaper.GetMediaItemTakeInfo_Value(take_dst, "D_STARTOFFS")
      reaper.GetSetMediaItemTakeInfo_String( take_dst, "GUID", reaper.genGuid(), true )
      reaper.SetMediaItemTakeInfo_Value(take_dst, "D_STARTOFFS", take_startoffset + new_source_offset)
    end
    reaper.SetMediaItemInfo_Value(empty_item, "B_UISEL", 1)
    reaper.Main_OnCommand(41613, 0)
    reaper.SetMediaItemInfo_Value(empty_item, "B_UISEL", 0)
  end
end

function Insert_track(under)
  for t = 1, under do
    reaper.InsertTrackAtIndex((reaper.GetNumTracks()), true)
  end
  local new_offset_tr = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
  return new_offset_tr
end

function Move_items(tr, data, time_offset)
  if not data then return end
  for i = 1, #data do
    local item = data[i]
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", item_start + time_offset)
    reaper.MoveMediaItemToTrack(item, tr)
  end
end

function Move_AIs(tr, data, time_offset)
  if not data then return end
    for j = 1, #data do
      local AI_ID = data[j].info["ID"]
      local AI_pos = reaper.GetSetAutomationItemInfo(tr, AI_ID, "D_POSITION", 0, false) -- AI POSITION
      reaper.GetSetAutomationItemInfo(tr, AI_ID, "D_POSITION", AI_pos + time_offset, true) -- AI NEW POSITION
    end
end

function New_items_position_in_area(as_start, as_end, item_start, item_lenght)
  local tsStart, tsEnd = as_start, as_end
  local item_dur = item_lenght + item_start

  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS OUT OF ITEM BUT TS END IS IN THEN COPY ONLY PART FROM TS START TO ITEM END
    local new_start, new_item_lenght, offset  = item_start, tsEnd - item_start, 0
    return new_start, new_item_lenght, offset, "END"
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF START IS IN ITEM AND TS END IS OUTSIDE ITEM COPY PART FROM TS START TO TS END
    local new_start, new_item_lenght, offset  = tsStart, item_dur - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, "START"
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM
    local new_start, new_item_lenght, offset  = tsStart, tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, "BOTH"
  elseif tsStart <= item_start and tsEnd >= item_dur then -- >= NEW
    ------ IF BOTH TS START AND END ARE OUTSIDE OF THE ITEM
    local new_start, new_item_lenght, offset  = item_start, item_lenght, 0
    return new_start, new_item_lenght, offset
  end
end

function is_item_in_as(as_start, as_end, item_start, item_end)
  if (as_start >= item_start and as_start < item_end) and -- IF SELECTION START & END ARE "IN" OR "ON" ITEM (START AND END ARE IN ITEM OR START IS ON ITEM START,END IS ON ITEM END)
      (as_end <= item_end and as_end > item_start) or
      (as_start < item_start and as_end > item_end)
    then -- IF SELECTION START & END ARE OVER ITEM (SEL STARTS BEFORE ITEM END IS AFTER ITEM
      return true
    elseif (as_start >= item_start and as_start < item_end) and (as_end >= item_end) then -- IF SEL START IS IN THE ITEM
      return true
    elseif (as_end <= item_end and as_end > item_start) and (as_start <= item_start) then-- IF SEL END IS IN THE ITEM
      return true
    end
end

function get_items_in_as(as_tr, as_start, as_end)
  if reaper.ValidatePtr(as_tr, "TrackEnvelope*") then return end
  local as_items = {}

  for i = 1, reaper.CountTrackMediaItems(as_tr) do
    local item = reaper.GetTrackMediaItem(as_tr, i - 1)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_len

    if (as_start >= item_start and as_start < item_end) and -- IF SELECTION START & END ARE "IN" OR "ON" ITEM (START AND END ARE IN ITEM OR START IS ON ITEM START,END IS ON ITEM END)
      (as_end <= item_end and as_end > item_start) or
      (as_start < item_start and as_end > item_end)
    then -- IF SELECTION START & END ARE OVER ITEM (SEL STARTS BEFORE ITEM END IS AFTER ITEM
      as_items[#as_items + 1] = item--item
    elseif (as_start >= item_start and as_start < item_end) and (as_end >= item_end) then -- IF SEL START IS IN THE ITEM
      as_items[#as_items + 1] = item--item
    elseif (as_end <= item_end and as_end > item_start) and (as_start <= item_start) then -- IF SEL END IS IN THE ITEM
      as_items[#as_items + 1] = item--item
    end
  end

  return #as_items ~= 0 and as_items or nil
end

function get_as_tr_env_pts(as_tr, as_start, as_end)
  local retval, env_name = reaper.GetEnvelopeName(as_tr)
  local env_points = {}

  for i = 1, reaper.CountEnvelopePoints(as_tr) do
    local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(as_tr, i - 1)

    if time >= as_start and time <= as_end then
      reaper.SetEnvelopePoint(as_tr, i - 1, time, value, shape, tension, true, true) -- SELECT POINTS IN AREA

      env_points[#env_points + 1] = {
        type = "env",
        id = i - 1,
        retval = retval,
        time = time,
        value = value,
        shape = shape,
        tension = tension,
        selected = true
      }
    elseif (time > as_start and time > as_end) or (time < as_start and time < as_end) then
      reaper.SetEnvelopePoint(as_tr, i - 1, time, value, shape, tension, false, true) -- DESELECT POINTS OUTSIDE AREA
    end
  end

  return #env_points ~= 0 and env_points or nil
end

function get_as_tr_AI(as_tr, as_start, as_end)
  local as_AI = {}
  if reaper.CountAutomationItems(as_tr) == 0 then return end
  for i = 1, reaper.CountAutomationItems(as_tr) do
    local AI_Points = {}

    local AI_pos = reaper.GetSetAutomationItemInfo(as_tr, i - 1, AI_info[2], 0, false) -- AI POSITION
    local AI_len = reaper.GetSetAutomationItemInfo(as_tr, i - 1, AI_info[3], 0, false) -- AI LENGHT

    if is_item_in_as(as_start, as_end, AI_pos, AI_pos + AI_len) then -- IF AI IS IN AREA
      local new_AI_start, new_AI_len = New_items_position_in_area(as_start, as_end, AI_pos, AI_len) -- GET/TRIM AI START/LENGTH IF NEEDED (DEPENDING ON AI POSITION IN AREA)
      as_AI[#as_AI + 1] = {} -- MAKE NEW TABLE FOR AI
      as_AI[#as_AI].info = {}
      for j = 1, #AI_info do
        if j == 2 then
          as_AI[#as_AI].info[AI_info[j]] = new_AI_start
        elseif j == 3 then
          as_AI[#as_AI].info[AI_info[j]] = new_AI_len
        elseif j == 11 then
          as_AI[#as_AI].info[AI_info[j]] = i-1
        else
          as_AI[#as_AI].info[AI_info[j]] = reaper.GetSetAutomationItemInfo(as_tr, i - 1, AI_info[j], 0, false) -- ADD AI INFO TO AI TABLE
        end
      end
      for j = 0, reaper.CountEnvelopePointsEx( as_tr, i-1) do
        local retval, time, value, shape, tension, selected = reaper.GetEnvelopePointEx( as_tr, i-1, j)
        if time >= as_start and time <= as_end then
            AI_Points[#AI_Points + 1] = {
              type = "AI",
              id = j,
              retval = retval,
              time = time,
              value = value,
              shape = shape,
              tension = tension,
              selected = true
            }
        end
        as_AI[#as_AI].points = AI_Points
      end
    end
  end
  return #as_AI ~= 0 and as_AI or nil
end

-- SPLIT CHUNK TO LLINES
function split_by_line(str)
  local t = {}
  for line in string.gmatch(str, "[^\r\n]+") do
      t[#t + 1] = line
  end
  return t
end

-- CREATE EMPTY ENVELOPE CHUNK FROM TEMPLATE, TAKE NEEDED VALUES FROM INCOMING ENV CHUNK
local match = string.match
function get_set_envelope_chunk(track, env)
  if reaper.ValidatePtr(track, "MediaTrack*") then--or reaper.ValidatePtr(track, "TrackEnvelope*") then return end
    local _, env_name = reaper.GetEnvelopeName( env )
    if reaper.GetTrackEnvelopeByName( track, env_name ) then return reaper.GetTrackEnvelopeByName( track, env_name )  end
    local ret, chunk = reaper.GetTrackStateChunk(track, "", false)
    local ret2, env_chunk = reaper.GetEnvelopeStateChunk(env, "")
    local env_center_val = env_prop(env, "centerValue")
    local env_name_from_chunk = match(env_chunk, "[^\r\n]+")
    local chunk_template = env_name_from_chunk .."\nACT 1 -1\nVIS 1 1 1\nLANEHEIGHT 0 0\nARM 1\nDEFSHAPE 0 -1 -1\nPT 0 " .. env_center_val .. " 0\n>"
    local new_chunk = chunk:sub(1, -3) .. chunk_template .. "\n>"
    reaper.SetTrackStateChunk(track, new_chunk, true)
    local new_env_tr = reaper.GetTrackEnvelopeByName( track, env_name )
    return new_env_tr
  end
end