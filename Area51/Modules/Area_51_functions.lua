--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.07
	 * NoIndex: true
--]]
local reaper = reaper
local refresh_tracks, update, update_all

function Delete(tr, src_tr, data, t_start, t_dur, t_offset, job)
	if not data then return end
  split_or_delete_items(tr, data.items, t_start, t_dur, job)
  --insert_edge_points(tr, t_start, t_dur, 0)
  del_env(tr, t_start, t_dur, 0)
  del_AI(tr, nil, t_start, t_dur, 0)
	update_all = true
end

function Split(tr, src_tr, data, t_start, t_dur, t_offset, job)
	if not data then return end
	split_or_delete_items(tr, data.items, t_start, t_dur, job)
	update_all = true
end

function Paste(tr, src_tr, data, t_start, t_dur, t_offset, job)
  if not data then return end
  local offset = t_offset - t_start
  create_item(tr, data.items, t_start, t_dur, offset, job)
  paste_env(tr, src_tr, data.env_points, t_start, t_dur, offset, job)
  Paste_AI(tr, src_tr, data.AI, t_start, t_dur, offset, job)
  refresh_tracks = true
end

function Duplicate(tr, src_tr, data, t_start, t_dur, t_offset, job)
  if not data then return end
  local offset = t_dur
  create_item(tr, data.items, t_start, t_dur, offset, job)
  paste_env(tr, src_tr, data.env_points, t_start, t_dur, offset, job)
  Paste_AI(tr, src_tr, data.AI, t_start, t_dur, offset, job)
  update = true
end

function Area_function(tbl,func)
  if not tbl then return end -- IF THERE IS NO TABLE OR TABLE HAS NO DATA RETURN
  local tr_offset = copy and Mouse_track_offset() or 0
  local BUFFER = Get_area_table("Copy")
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for a = 1, #tbl do
    local tbl_t = tbl[a]
    local area_pos_offset = 0
    area_pos_offset = area_pos_offset + (tbl_t.time_start - lowest_start()) --  OFFSET BETWEEN AREAS
    local total_pos_offset = mouse.p + area_pos_offset

    for i = 1, #tbl_t.sel_info do	-- LOOP THRU AREA DATA
      local sel_info_t = tbl_t.sel_info[i]
      local target_track = sel_info_t.track -- AREA TRACK
      local new_tr, under = Track_from_offset(target_track, tr_offset)
      new_tr = under and Insert_track(under) or new_tr
      new_tr = env_offset_new(tbl_t.sel_info, target_track, new_tr, tbl_t.sel_info[i].env_name) or new_tr

      if reaper.ValidatePtr(new_tr, "MediaTrack*") and reaper.ValidatePtr(target_track, "TrackEnvelope*") then
        new_tr = get_set_envelope_chunk(new_tr, target_track)
      end

      local off_tr = copy and new_tr or target_track -- OFFSET TRACK ONLY IF WE ARE IN COPY MODE
      local data = ((#BUFFER ~= 0 and BUFFER[a].sel_info[i]) and (BUFFER[a].guid == tbl[a].guid)) and BUFFER[a].sel_info[i] or sel_info_t
      _G[func](off_tr, target_track, data, tbl_t.time_start, tbl_t.time_dur, total_pos_offset, func)
    end

    if update then
      tbl_t.time_start = (func == "Duplicate") and tbl_t.time_start + tbl_t.time_dur or tbl_t.time_start
      tbl_t.sel_info = GetSelectionInfo(tbl_t)
      update = nil
    end

    if update_all then
      local areas_tbl = Get_area_table("Areas")
      Ghost_unlink_or_destroy(areas_tbl, "Delete")
      for i = 1, #areas_tbl do
        areas_tbl[i].sel_info = GetSelectionInfo(areas_tbl[i])
      end
      update_all = nil
    end
  end

  reaper.Undo_EndBlock("A51 " .. func, 4)
  reaper.PreventUIRefresh(-1)
  --reaper.UpdateTimeline()
  reaper.UpdateArrange()
  if refresh_tracks then
    GetTracksXYH()      -- CALL AFTER PreventUIRefresh SINCE TRACK COORDINATE DO NOT UPDATE
    refresh_tracks = false
  end
end

------------------------------------------- D R A G ----------------------------------------------------
function Split_for_move(tbl)
  if not tbl then return end
  for i = 1, #tbl.sel_info do
    split_or_delete_items(tbl.sel_info[i].track, tbl.sel_info[i], tbl.time_start, tbl.time_dur, "Split_for_move")
    tbl.sel_info[i].items = get_items_in_as(tbl.sel_info[i].track, tbl.time_start, tbl.time_start + tbl.time_dur)
  end
  update_all = true
end

function Clean(dst_tbl, src_tbl, dst_t, src_t)
  for i = 1, #dst_tbl do
    local dst_tr = dst_tbl[i].track
    local src_tr = src_tbl[i].track
    del_env(src_tr, src_t[1], src_t[2], 0)
    del_env(dst_tr, dst_t[1], dst_t[2], 0)
    if dst_tr ~= src_tr then -- ONYLY MOVE AIS ON OTHER TRACKS IF DESTINATION AND SOURCE ARE DIFFERENT
      del_AI(src_tr, nil, src_t[1], src_t[2], 0)
      del_AI(dst_tr, nil, dst_t[1], dst_t[2], 0)
    end
  end
end

function C_move(new_tr, src_tr, src_data, src_time_start, src_time_dur, src_dst_offset)
  Move_items(new_tr, src_data.items, src_dst_offset)
  paste_env(new_tr, src_tr, src_data.env_points, src_time_start, src_time_dur, src_dst_offset)
  if new_tr ~= src_tr then -- ONYLY MOVE AIS ON OTHER TRACKS IF DESTINATION AND SOURCE ARE DIFFERENT
    Paste_AI(new_tr, src_tr, src_data.AI, src_time_start, src_time_dur, src_dst_offset)
  else
    Move_AIs(new_tr, src_data.AI, src_dst_offset)
  end
end

function C_drag_copy(new_tr, src_tr, src_data, src_time_start, src_time_dur, src_dst_offset)
  create_item(new_tr, src_data.items, src_time_start, src_time_dur, src_dst_offset)
  paste_env(new_tr, src_tr, src_data.env_points, src_time_start, src_time_dur, src_dst_offset)
  Paste_AI(new_tr, src_tr, src_data.AI, src_time_start, src_time_dur, src_dst_offset)
end

function Area_Drag(src_tbl, dst_tbl, src_time_tbl, dst_time_tbl, src_dst_offset, zone, action)
  local tr_offset = Mouse_track_offset(src_tbl.sel_info[1].track)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  local func = zone .. "_" .. action
  local clean = (action == "move" and src_dst_offset ~= 0) and Clean(dst_tbl.sel_info, src_tbl.sel_info, dst_time_tbl, src_time_tbl)

  local new_area = {}

  for i = 1, #dst_tbl.sel_info do
    local dst_tr, src_tr = dst_tbl.sel_info[i].track, src_tbl.sel_info[i].track
    local src_time_start, src_time_dur = src_time_tbl[1], src_time_tbl[2]
    --local dst_time_start, dst_time_dur = dst_time_tbl[1], dst_time_tbl[2]

    local new_tr, under = Track_from_offset(src_tr, tr_offset)
    new_tr = under and Insert_track(under) or new_tr
    new_tr = env_offset_new(src_tbl.sel_info, src_tr, new_tr, src_tbl.sel_info[i].env_name) or new_tr

    if reaper.ValidatePtr(new_tr, "MediaTrack*") and reaper.ValidatePtr(src_tr, "TrackEnvelope*") then
      new_tr = get_set_envelope_chunk(new_tr, src_tr)
    end
    new_area[i] = {track = new_tr}

    _G[func](new_tr, src_tr, src_tbl.sel_info[i], src_time_start, src_time_dur, src_dst_offset)
  end
  if update_all then
    local areas_tbl = Get_area_table("Areas")
    Ghost_unlink_or_destroy(areas_tbl, "Delete")
    for i = 1, #areas_tbl do
      areas_tbl[i].sel_info = GetSelectionInfo(areas_tbl[i])
    end
    update_all = nil
  end

  reaper.Undo_EndBlock("A51 " .. func, 4)
  reaper.PreventUIRefresh(-1)
  --reaper.UpdateTimeline()
  reaper.UpdateArrange()

  GetTracksXYH()
  local new_y, new_h = GetTrackTBH(new_area)  -- SINCE WE ARE MOVING AREA, IF THERE ARE NEW ADDED TRACKS CHANGE AREA TO THAT LOCATION
  dst_tbl.y, dst_tbl.h = new_y, new_h
end