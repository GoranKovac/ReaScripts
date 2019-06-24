-- NoIndex: true

TrackTB = {}
--track_window = reaper.JS_Window_Find("trackview", true) -- GET TRACK VIEW
track_window = reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), 0x3E8) -- all platforms (win,osx...)
track_window_dc = reaper.JS_GDI_GetWindowDC(track_window)
main_wnd = reaper.GetMainHwnd() -- MAIN WINDOW
mixer_wnd = reaper.JS_Window_Find("mixer", true) -- mixer
---------------------------------------------------------------------------------
--------------------
---  Pickle.lua  ---
--------------------
function pickle(t)
  return Pickle:clone():pickle_(t)
end
Pickle = {clone = function(t)
    local nt = {}
    for i, v in pairs(t) do
      nt[i] = v
    end
    return nt
  end}
function Pickle:pickle_(root)
  if type(root) ~= "table" then
    error("can only pickle tables, not " .. type(root) .. "s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""
  while #self._refToTable > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s .. "{\n"
    for i, v in pairs(t) do
      s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
    s = s .. "},\n"
  end
  return string.format("{%s}", s)
end
function Pickle:value_(v)
  local vtype = type(v)
  if vtype == "string" then
    return string.format("%q", v)
  elseif vtype == "number" then
    return v
  elseif vtype == "boolean" then
    return tostring(v)
  elseif vtype == "table" then
    return "{" .. self:ref_(v) .. "}"
  else
    error("pickle a " .. type(v) .. " is not supported")
  end
end
function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then
    if t == self then
      error("can't pickle the pickle class")
    end
    table.insert(self._refToTable, t)
    ref = #self._refToTable
    self._tableToRef[t] = ref
  end
  return ref
end
-----------------
---  unpickle ---
-----------------
function unpickle(s)
  if type(s) ~= "string" then
    error("can't unpickle a " .. type(s) .. ", only strings")
  end
  local gentables = load("return " .. s)
  local tables = gentables()
  for tnum = 1, #tables do
    local t = tables[tnum]
    local tcopy = {}
    for i, v in pairs(t) do
      tcopy[i] = v
    end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then
        ni = tables[i[1]]
      else
        ni = i
      end
      if type(v) == "table" then
        nv = tables[v[1]]
      else
        nv = v
      end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end
--------------------------------------------------
---  Function GET SHORTCUT DATA FROM EXTSTATE  ---
--------------------------------------------------
function get_shortcut(tbl)
  local retval, num = reaper.GetProjExtState(0, "TrackVersions", "shortcut")
  if num == "" then
    return
  elseif tonumber(num) then
    restoreTrackItems(tbl.guid, tonumber(num))
    update_listbox(tonumber(num))
    save_tracks()
  elseif num == "new_version" then
    new_version()
  elseif num == "delete_version" then
    delete()
  elseif num == "duplicate" then
    duplicate()
  elseif num == "rename" then
    rename()
  elseif num:find("show_all") then
    num = tonumber(num:sub(10))
    local param = not to_bool(num)
    show_all(param)
    save_tracks()
  end
  reaper.SetProjExtState(0, "TrackVersions", "shortcut", "")
end
-----------------------------
---  Function REDO SYSTEM ---
-----------------------------
function redo(guid)
  local tbl = find_guid(guid)
  local _, chunk = has_id(find_guid(undo[1]), undo[2])
  chunk = undo_last_chunk
end

-----------------------------
---  Function unpack undo ---
-----------------------------
function unpack_undo(string)
  local undo, nums = {}, {} -- 1 GUID, 2 VER ID, 3 NUMS TO DELETE, CURRENT TRACK CHUNK
  for i in string.gmatch(string, "[^%:]+") do
    if i ~= "RTV" then
      undo[#undo + 1] = i
    end
  end
  local _, chunk = has_id(find_guid(undo[1]), undo[2]) -- GET CHUNK BY VER ID
  for i in string.gmatch(undo[3], "[^%,]+") do
    nums[#nums + 1] = i
  end
  for i = #nums, 1, -1 do -- WE ALWAYS WANT TO REVERS SHIT AROUND WHEN REMOVING FROM TABLES
    table.remove(chunk, i) -- REMOVE IT FROM THAT CHUNK TABLE
  end
end
----------------------------------
---  Function CREATE UNDO NAME ---
----------------------------------
function create_undo_name(tr, ver_id, chunk_num, cur_chunk)
  local undo_name = "RTV:" .. tr .. ":" .. ver_id .. ":" .. chunk_num .. ":" .. pickle(cur_chunk)
  return undo_name
end
-------------------------------------------------
---  Function ESCAPE GODDAMN MAGIC CHARACTERS ---
-------------------------------------------------
function literalize(str)
  return str:gsub(
    "[%(%)%.%%%+%-%*%?%[%]%^%$]",
    function(c)
      return "%" .. c
    end
  )
end
------------------------------------
---  Function DELETE FX ON TRACK ---
------------------------------------
function remove_track_fx(guid)
  local track = reaper.BR_GetMediaTrackByGUID(0, guid)
  for i = 1, reaper.TrackFX_GetCount(track) do
    reaper.TrackFX_Delete(track, i - 1)
  end
end
-----------------------------------
---  Function CREATE FX VERSION ---
-----------------------------------
function create_fx(guid, tab, job, duplicate)
  if tab ~= 3 then
    return
  end
  ::JUMP::
  local fx_chunk = get_fx_chunk(guid)
  if not fx_chunk then
    return
  end
  local name
  if job == "V" then
    name = naming(find_guid(guid), "V", nil, "fx") -- NORMAL VERSION NAMES
    remove_track_fx(guid)
  elseif job == "D" then
    name = naming(find_guid(guid), job, duplicate, "fx") -- CREATE DUPLICATE NAMES
  end
  local data = {chunk = fx_chunk, name = name}
   -- .. #tbl.fx+1}
  if not find_guid(guid) then
    TrackTB[#TrackTB + 1] = {guid = guid, fx = {fx_num = 1, data}}
    goto JUMP
  else
    local version = find_guid(guid)
    if not version.fx then
      version.fx = {}
    end
    version.fx[#version.fx + 1] = data
    version.fx.fx_num = #version.fx
  end
end
----------------------------
---  Function RESTORE FX ---
----------------------------
function restore_fx(tbl, num)
  local chunk = tbl.fx[num].chunk
  local fx_chunk, track_chunk = get_fx_chunk(tbl.guid)
  local fx_chunk = literalize(fx_chunk)
  local track_chunk = string.gsub(track_chunk, fx_chunk, chunk)
  reaper.SetTrackStateChunk(reaper.BR_GetMediaTrackByGUID(0, tbl.guid), track_chunk, false)
  tbl.fx.fx_num = num
end
-------------------------------
---  Function GET FX CHUNK  ---
-------------------------------
function get_fx_chunk(guid)
  local _, track_chunk = reaper.GetTrackStateChunk(reaper.BR_GetMediaTrackByGUID(0, guid), "", false)
  if not track_chunk:find("<FXCHAIN") then
    return
  end -- DO NOT ALLOW CREATING FIRST EMPTY FX
  local fx_start = track_chunk:find("<FXCHAIN")
  local fx_end = track_chunk:find("<ITEM")
  if not fx_end then
    fx_end = -6
  else
    fx_end = fx_end - 4
  end
  local fx_chunk = track_chunk:sub(fx_start + 9, fx_end)
  return fx_chunk, track_chunk
end
------------------------------------
---  Function GET GROUP PRIORITY ---
------------------------------------
function priority(guid)
  local tr_group
  local test = {}
  -- GET ALL GROUP WHICH CONTAINS SELECTED TRACK
  if not TrackTB.groups then return end
  for i = 1, #TrackTB.groups do
    if has_undo(TrackTB.groups[i], guid) then
      test[#test + 1] = {group = i, num = has_undo(TrackTB.groups[i], guid)}
    end
  end
  -- IF THE TRACK IS IN MOST TOP OF THE GROUP SELECT THAT GROUP
  -- PRIORITY GOES FROM TOP TO BOTTOM, PRIORITY IS SET ON WHICH GROUP THE TRACK IS FIRST :
  -- FOR EXAMPLE SELECTED TRACK IS X
  -- GROUP1: 1 2 3 4 X
  -- GROUP2: 1 2 X
  -- GROUP3: X 1 2
  -- IF THE TRACK IS SELECTED IT WILL RETURN GROUP 3
  for i = 1, #test do
    local ref = test[1].num
    if test[i].num < test[1].num then
      tr_group = test[i].group
    elseif #test == 1 then
      tr_group = test[i].group
    end
  end
  return tr_group
end
---------------------------------------
---  Function EDIT GROUP ENVELOPES  ---
---------------------------------------
function edit_group_track_envelope()
  local sel_env = reaper.GetSelectedEnvelope(0)
  if not sel_env then
    return
  end
  local retval, env_name = reaper.GetEnvelopeName(sel_env, "")
  local _, _, _, sel_points = select_deselect_env_points(sel_env, false)
  local range_start, range_end
  if not sel_points then
    return
  end
  if #sel_points > 1 then
    range_start = sel_points[1].time
    range_end = sel_points[#sel_points].time
  else
    point = sel_points[1]
    Aval = point.value
  end

  local track, index, index2 = reaper.Envelope_GetParentTrack(sel_env) -- get envelopes main track
  local track_guid = reaper.GetTrackGUID(track)
  local prio = priority(track_guid) -- check track group
  if not prio then
    return
  end
  local tr_group = TrackTB.groups[prio]
  for i = 1, #tr_group do
    if tr_group[i] ~= track_guid then -- DO FOR OTHER TRACKS
      local tr = reaper.BR_GetMediaTrackByGUID(0, tr_group[i])
      local env = reaper.GetTrackEnvelopeByName(tr, env_name)
      local br_env = reaper.BR_EnvAlloc(env, true) -- get
      --if range_start then
      _, _, _, sel_pt, r_pt, all_pt = select_deselect_env_points(env, false, range_start, range_end)
      for j = 1, #all_pt do
        if point.time == all_pt[j].time then
          sel = true
          all_pt[j].selected = sel
        else
          sel = false
        end
        reaper.SetEnvelopePoint(env, j - 1, time, value, shape, tension, sel, false)
        --else
        -- reaper.SetEnvelopePoint( env, j-1, time, value, shape, tension, false, false )
        -- end
      end
      --  reaper.SetEnvelopePoint( env, j-1, time, value, shape, tension, true, false )
      --end
      for j = 1, #all_pt do
        if all_pt[j].selected == true then
          reaper.SetEnvelopePoint(env, j, point.time, value, shape, tension, selected, false)
        end
      end
      -- else
      --reaper.SetEnvelopePoint( env, j-1, time, value, shape, tension, false, false )
      --end
      --local br_val = reaper.BR_EnvValueAtPos( br_env, range_points[j].time )
      --local reaper_val = reaper.ScaleToEnvelopeMode( 1, br_val )
      --  end
      -- else
      local br_val = reaper.BR_EnvValueAtPos(br_env, point.time)
      local reaper_val = reaper.ScaleToEnvelopeMode(1, br_val)
    -- reaper.InsertEnvelopePoint( env, point.time, reaper_val, point.shape, point.tension, point.selected, false )
    --reaper.BR_EnvFree( br_env, true ) -- release
    --  end
    end
  end
  reaper.UpdateArrange()
end
--------------------------------------------------------------------------------
---  Function EDIT GROUP TRACKS OR ITEM ----------------------------------------
--------------------------------------------------------------------------------
function edit_group_track_or_item(sel_item, guid)
  if not sel_item then
    return
  end
  local prio = priority(guid)
  if not prio then
    return
  end

  local sitem_lenght = reaper.GetMediaItemInfo_Value(sel_item, "D_LENGTH")
  local sitem_start = reaper.GetMediaItemInfo_Value(sel_item, "D_POSITION")
  local sitem_dur = sitem_lenght + sitem_start

  local tr_group = TrackTB.groups[prio]
  reaper.PreventUIRefresh(1)
  for i = 1, #tr_group do
    if tr_group[i] ~= guid then
      local tr = reaper.BR_GetMediaTrackByGUID(0, tr_group[i])
      local track = find_guid(tr_group[i])
      --if tbl.num == track.num then
      for j = 1, reaper.CountTrackMediaItems(reaper.BR_GetMediaTrackByGUID(0, tr_group[i])) do
        local item = reaper.GetTrackMediaItem(reaper.BR_GetMediaTrackByGUID(0, tr_group[i]), j - 1)
        local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_dur = item_lenght + item_start

        if (item_start >= sitem_start) and (item_start < sitem_dur) and (item_dur <= sitem_dur) then
          reaper.SetMediaItemSelected(item, true) -- SELECT ITEMS ONLY
        --reaper.SetTrackSelected( tr, true ) -- SELECT ALL TRACKS
        end
        -- end
      end
    end
  end
  --reaper.UpdateTimeline()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
------------------------------------------------------------
---  Function MAKE ITEMS BASED TIME SELECTION (SWIPING)  ---
------------------------------------------------------------
function make_item_from_ts(tbl, item, track, job)
  local filename, clonedsource
  local take = reaper.GetMediaItemTake(item, 0)
  local source = reaper.GetMediaItemTake_Source(take)
  local m_type = reaper.GetMediaSourceType(source, "")
  local item_volume = reaper.GetMediaItemInfo_Value(item, "D_VOL")

  local swipedItem = reaper.AddMediaItemToTrack(track)
  local swipedTake = reaper.AddTakeToMediaItem(swipedItem)

  if m_type:find("MIDI") then
    local midi_chunk = check_item_guid(tbl, item, m_type)
    reaper.SetItemStateChunk(swipedItem, midi_chunk, false)
  else
    filename = reaper.GetMediaSourceFileName(source, "")
    clonedsource = reaper.PCM_Source_CreateFromFile(filename)
  end

  local new_item_start, new_item_lenght, offset = ts_item_position(item)
  reaper.SetMediaItemInfo_Value(swipedItem, "D_POSITION", new_item_start)
  reaper.SetMediaItemInfo_Value(swipedItem, "D_LENGTH", new_item_lenght)
  local swipedTakeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  reaper.SetMediaItemTakeInfo_Value(swipedTake, "D_STARTOFFS", swipedTakeOffset + offset)

  if m_type:find("MIDI") == nil then
    reaper.SetMediaItemTake_Source(swipedTake, clonedsource)
  end

  reaper.SetMediaItemInfo_Value(swipedItem, "D_VOL", item_volume)
  local _, swipe_chunk = reaper.GetItemStateChunk(swipedItem, "")
  swipe_chunk = {pattern(swipe_chunk)}

  if job then -- remove added item if needed (calling from multiedit function)
    local track = reaper.BR_GetMediaTrackByGUID(0, tbl.guid)
    reaper.DeleteTrackMediaItem(track, swipedItem)
  end
  return swipedItem, swipe_chunk
end
----------------------------------
---  Function GET ITEMS IN TS  ---
----------------------------------
function get_items_in_ts(item)
  local tsStart, tsEnd = get_time_sel()
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_dur = item_start + item_len
  if
    (tsStart >= item_start and tsStart <= item_dur) or -- if time selection start is in item
      (tsEnd >= item_start and tsEnd <= item_dur) or
      (tsStart <= item_start and tsEnd >= item_dur)
   then -- if time selection end is in the item
    return item
  end
end
--------------------------------------------------------------------------------
---  Function GET TIME SELECTION  ----------------------------------------------
--------------------------------------------------------------------------------
function get_time_sel()
  local t_start, t_end = reaper.GetSet_LoopTimeRange(0, true, 0, 0, false)
  if t_start == 0 and t_end == 0 then
    return false
  else
    return t_start, t_end
  end
end
-------------------------------------------------------------------
---  Function FIND VERSION BASED ON MOUSE POSITION IN THE TRACK  ---
--------------------------------------------------------------------
function get_mouse_ver(tbl, cY)
  if not tbl or not cY then
    return
  end
  local track_h = reaper.GetMediaTrackInfo_Value(reaper.BR_GetMediaTrackByGUID(0, tbl.guid), "I_WNDH")
  local v_num = #tbl.data
  local ver = track_h / v_num
  local num = math.floor((cY / ver) + 1)
  return num
end
------------------------------------------------
---  Function GET ZOOM OFFSET (MOUSE WHEEL)  ---
------------------------------------------------
function get_track_zoom_offset(tr, y_end, h, scroll)
  local retval, list = reaper.JS_Window_ListAllChild(main_wnd)
  local fl, offset
  for adr in list:gmatch("%w+") do
    local handl = reaper.JS_Window_HandleFromAddress(tonumber(adr))
    if reaper.JS_Window_GetLongPtr(handl, "USER") == tr then
      if mixer_wnd ~= reaper.JS_Window_GetParent(reaper.JS_Window_GetParent(handl)) then
        fl = handl
        break
      end
    end
  end
  if not fl then
    return
  end
  local __, __, ztop, __, __ = reaper.JS_Window_GetRect(fl)
  if y_end > (ztop + h - 1) then
    offset = y_end - ztop - h
  end
  return offset
end
----------------------------------------
---  Function GET TRACKS Y POSITION  ---
----------------------------------------
function get_track_y_range(y_view_start, scroll, cur_tr)
  if not cur_tr then
    return
  end
  local trcount = reaper.GetMediaTrackInfo_Value(cur_tr, "IP_TRACKNUMBER") -- WE ONLY COUNT TO CURRENT SELECTED TRACK (SINCE WE ONLY NEED Y-POS OF THAT TRACK)
  local masvis, totalh, idx = reaper.GetMasterTrackVisibility(), y_view_start - scroll, 1 -- VIEWS Y START, SUBTRACTED BY SCROLL POSITION
  if masvis == 1 then
    totalh = totalh + 5
    idx = 0
  end
  local y_start, y_end
  for tr = idx, trcount do
    local track = reaper.CSurf_TrackFromID(tr, false)
    height = reaper.GetMediaTrackInfo_Value(track, "I_WNDH") -- TRACK HEIGHT
    y_start = totalh -- TRACK Y START
    y_end = totalh + height -- TRACK Y END -- EXCLUDE 1 PIXEL SO WE DONT USE TRACKS DEVIDER
    totalh = totalh + height
    if get_track_zoom_offset(track, totalh, height, scroll) then
      offset = get_track_zoom_offset(track, totalh, height, scroll)
      y_start = y_start - offset
      y_end = y_end - offset
    end
  end
  return y_start, y_end -- RETURN SELECTED TRACKS Y START & END
end
--------------------------------------
---  Function GET SELECTED TRACKS  ---      NEED TO FIX MULTISELECTION (breakes folders)
--------------------------------------
function get_tracks()
  local sel_tr_count, tracks = reaper.CountSelectedTracks(0), {}
  for i = 1, sel_tr_count do
    local tr = reaper.GetSelectedTrack(0, i - 1)
    local tr_guid = reaper.GetTrackGUID(tr)
   -- if get_folder(tr) then
      --tracks = get_folder(tr) -- FOLDER
   -- else
      tracks[#tracks + 1] = tr_guid -- SINGLE TRACK OR SELECTED TRACKS
   -- end
  end
  return tracks
end
-------------------------------------------
---  Function UPDATE GUI TXT AND STUFF  ---
-------------------------------------------
function get_track_info(guid)
  local tr = reaper.BR_GetMediaTrackByGUID(0, guid)
  local folder = reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
  local retval, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  local tr_number = math.floor(reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
  local fipm = reaper.GetMediaTrackInfo_Value(tr, "B_FREEMODE")
  return tr_name, tr_number, folder, fipm
end
-------------------------------------------
---  Function UPDATE GUI TXT AND STUFF  ---
-------------------------------------------
function update_txt_elements(guid)
  local tr_name, tr_number, folder = get_track_info(guid)
  local lbl_name = tr_number .. " - " .. tr_name
  if folder == 1 then
    lbl_name = lbl_name .. " - " .. "FOLDER"
  end
  return lbl_name
end
----------------------------------
---  Function COUNT INSTANCES  ---
----------------------------------
local function count(tbl, val)
  local cnt = 1
  for i = 1, #tbl do
    if val == "V" then
      if string.len(tbl[i].name) == 3 and tbl[i].name:find(val) then
        cnt = cnt + 1
      end -- VERSIONS V01
    elseif val == "Comp" then
      if tbl[i].name:match(val) then
        cnt = cnt + 1
      end -- VERSIONS Comp01
    else
      if tbl[i].name:gsub("%-", ""):match(val:gsub("%-", "")) then
        cnt = cnt + 1
      end -- DUPLICATES V01-D01
    end
  end
  return cnt
end
--------------------------
---  Function FIND ID  ---
--------------------------
function has_id(tab, val)
  if not tab then return end
  for i = 1, #tab.data do
    local in_table = tab.data[i].ver_id
    if in_table == val then
      return i, tab.data[i].chunk
    end
  end
  return false
end
----------------------------
---  Function FIND UNDO  ---
----------------------------
function has_undo(tab, val)
  for i = 1, #tab do
    local in_table = tab[i]
    if in_table == val then
      return i
    end
  end
  return false
end
----------------------------
---  Function FIND ENV  ---
----------------------------
function has_env(tbl, val)
  for k, v in pairs(tbl) do
    local in_table = k
    if in_table == val then
      return true
    end
  end
  return false
end
-------------------------------------------------------------
---  Function FIND GUID AND RETURN ITS TABLE  ---------------
-------------------------------------------------------------
function find_guid(guid)
  for i = 1, #TrackTB do
    if TrackTB[i].guid == guid then
      return TrackTB[i], i
    end
  end
end
------------------------------------------------
-- FUNCTION CHECK IF TRACK HAS EMPTY DATA ---
------------------------------------------------
function check_for_emtpy_table(tbl)
  if not tbl then
    return
  end
  local cnt = 0
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      cnt = cnt + #v
    end
  end
  return cnt
end
------------------------------------
--    FUNCTION GET FOLDER CHILDS ---
------------------------------------
function delete_from_table(tbl, val, guid, tab, cur_env)
  if not tbl then
    return
  end
  if reaper.GetMediaTrackInfo_Value(reaper.BR_GetMediaTrackByGUID(0, guid), "I_FOLDERDEPTH") == 1 then
    local id = tbl[val].ver_id -- FOLDER ID (CHILDS HAVE SAME)
    for i = #tbl[val].chunk, 1, -1 do
      local child = find_guid(tbl[val].chunk[i]) -- GET CHILD TABLE
      if has_id(child, id) then -- IF IDs MATCH
        local child_num = has_id(child, id)
        delete_from_table(child.data, child_num, child.guid) -- SEND AGAIN TO DELETE TRACK (CHILD)
      end
    end
    table.remove(tbl, val) -- FEMOVE FOLDER
  else
    table.remove(tbl, val) -- REMOVE TRACK OR ENVELOPE
  end
  local cur_tbl, num = find_guid(guid)
  if tab == 1 then
    if cur_tbl.data.num >= #cur_tbl.data then
      cur_tbl.data.num = #cur_tbl.data
    else
      cur_tbl.data.num = cur_tbl.data.num
    end -- CHANGE TRACK/CHILD NUM
    if cur_tbl.data.dest > cur_tbl.data.num then
      cur_tbl.data.dest = cur_tbl.data.num
    end
    if #cur_tbl.data == 0 then
      cur_tbl.data = nil
    end -- DELETE ITEM TABLE IF EMPTY
  elseif tab == 2 then
    if cur_tbl[cur_env].num >= #cur_tbl[cur_env] then
      cur_tbl[cur_env].num = #cur_tbl[cur_env]
    else
      cur_tbl[cur_env].num = cur_tbl[cur_env].num
    end
    if #cur_tbl[cur_env] == 0 then
      cur_tbl[cur_env] = nil
    end -- DELETE ENV TABLE IF EMPTY
  elseif tab == 3 then
    if cur_tbl.fx.fx_num >= #cur_tbl.fx then
      cur_tbl.fx.fx_num = #cur_tbl.fx
    else
      cur_tbl.fx.fx_num = cur_tbl.fx.fx_num
    end -- CHANGE TRACK/CHILD NUM
    if #cur_tbl.fx == 0 then
      cur_tbl.fx = nil
    end -- DELETE FX TABLE IF EMPTY
  end

  if check_for_emtpy_table(cur_tbl) == 0 then
    table.remove(TrackTB, num)
  end -- DELETE CURRENT TABLE ONLY IF THERE IS NO DATA INSIDE (ONLY GUID LEFT)
  save_tracks() 
end
-----------------------------------------------------
---  Function GET ITEM LANE FROM ITEM SELECTION   ---
-----------------------------------------------------
function get_num_from_cordinate(data, item) -- gets num value from table if selected item guid is found
  local item_guid = reaper.BR_GetMediaItemGUID(item)
  for i = 1, #data do
    for j = 1, #data[i].chunk do
      local stored_guid = "{" .. data[i].chunk[j]:match("{(%S+)}") .. "}"
      if item_guid == stored_guid then
        return i
      end
    end
  end
end
-------------------------------------------------------
---  Function MUTE VIEW (VIEW ALL VERSION AT ONCE   ---
-------------------------------------------------------
function get_num_from_selected_item(item, tbl)
  local num
  if item and get_num_from_cordinate(tbl.data, item) ~= nil then
    num = get_num_from_cordinate(tbl.data, item)
    tbl.num = num
    mute_view(tbl, num)
  end
  return num
end
--------------------------------------------------------
---  Function MUTE VIEW (VIEW ALL VERSION AT ONCE   ---
-------------------------------------------------------
function mute_view(tbl, mouse_num)
  if not tbl then
    return
  end
  local tr = reaper.BR_GetMediaTrackByGUID(0, tbl.guid)
  local items = {}
  for i = 1, reaper.CountTrackMediaItems(tr) do -- go to all items and mute all which are not selected via click or by version in gui
    local item = reaper.GetTrackMediaItem(tr, i - 1)
    local d_num = mouse_num or tbl.data.num -- TEST FOR NEW EXCITING SHIT (FIND VERSION LANE BASED ON MOUSE POSITION)
    if d_num == get_num_from_cordinate(tbl.data, item) or get_num_from_cordinate(tbl.data, item) == nil then -- avoid muting splitted items with "get_num_from_cordinate2(tbl,item) ~= nil"
      reaper.SetMediaItemInfo_Value(item, "B_MUTE", 0)
      items[#items + 1] = item
    else
      reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
    end
  end
  reaper.UpdateArrange()
  return items
end
-----------------------------
---  Function CLEAR FIPM  ---
-----------------------------
function clear_muted_items(guid)
  local tr = reaper.BR_GetMediaTrackByGUID(0, guid)
  local num_items = reaper.CountTrackMediaItems(tr)
  for i = num_items, 1, -1 do
    local item = reaper.GetTrackMediaItem(tr, i - 1)
    if reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 1 then
      reaper.DeleteTrackMediaItem(tr, item)
    end
  end
end
---------------------------------------
---  Function DRAW FIPM LANES LINES  ---
---------------------------------------
function fipm_gui_lines(guid, Ystart, Yend, Xstart, Xend, view_start)
  local nums = #find_guid(guid).data
  local max_h = Yend - Ystart
  local lane_h = max_h / nums
  for i = 0, nums do
    local lane_y = Ystart + (math.floor(lane_h * i) - 2) - view_start
    reaper.JS_GDI_FillRect(track_window_dc, 0, lane_y - 1, Xend, lane_y + 1)
  end
end
---------------------------------------
---  Function SET TRACKS TBLL FIPM  ---
---------------------------------------
function set_track_fipm(guid, param)
  local tr_tbl = find_guid(guid)
  if not tr_tbl then
    return
  end
  local tr = reaper.BR_GetMediaTrackByGUID(0, guid)
  reaper.SetMediaTrackInfo_Value(tr, "B_FREEMODE", param)
end
---------------------------------------------
---  Function GET VALUES FOR FIPM UPDATE  ---
---------------------------------------------
function get_fipm_value(tbl)
  if not tbl then
    return
  end
  local ver_cnt = #tbl.data
  local offset = 0
  local track_h = reaper.GetMediaTrackInfo_Value(reaper.BR_GetMediaTrackByGUID(0, tbl.guid), "I_WNDH")
  if track_h <= 42 then
    offset = 15
  end
  local bar_h_FIPM = ((19 - offset) / track_h)
  local item_h_FIPM = (1 - (ver_cnt - 1) * bar_h_FIPM) / ver_cnt
  return bar_h_FIPM, item_h_FIPM, ver_cnt, track_h
end
-------------------------------------------
---  Function SORT ITEMS IN FIPM MODE  ----
-------------------------------------------
function sort_fipm(guid)
  if not guid then
    return
  end
  reaper.PreventUIRefresh(1)
  local tr = reaper.BR_GetMediaTrackByGUID(0, guid)
  local tbl = find_guid(guid)
  if not tbl then
    return
  end
  local num_items = reaper.CountTrackMediaItems(tr)
  delete_items_on_track(guid)
  local FIPM_bar, FIPM_item, ver_cnt = get_fipm_value(tbl)
  --if not FIPM_bar then return end
  for i = 1, #tbl.data do
    local chunk = tbl.data[i].chunk
    for j = 1, #chunk do
      local item = reaper.AddMediaItemToTrack(tr)
      reaper.SetItemStateChunk(item, chunk[j], false) -- set all versions on same track
      local set_item_H = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_H", FIPM_item) -- set item height (divide with number of items)
      local set_item_Y = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", ((i - 1) * (FIPM_item + FIPM_bar))) -- add Y position
    end
  end
  mute_view(tbl)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
------------------------------
---  Function REFRESH FIPM ---
------------------------------
function update_fipm(tbl, override)
  local FIPM_bar, FIPM_item, ver_cnt, H = get_fipm_value(tbl)
  if override then
    last_H = override
  end -- WE NEED TO UPDATE FIPM IN SOME SCENARIOS SO WEE WILL OVERRIDE THE CHECKING (MAKE IT PASS THE FUNCTION)
  if last_H ~= H then -- prevent updating positions if track height has not changed
    for i = 1, ver_cnt do
      for j = 1, #tbl.data[i].chunk do
        local item = "{" .. tbl.data[i].chunk[j]:match("{(%S+)}") .. "}"
        item = reaper.BR_GetMediaItemByGUID(0, item)
        if not item then
          return
        end
        local set_item_H = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_H", FIPM_item) -- set new item height
        local set_item_Y = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", ((i - 1) * (FIPM_bar + FIPM_item)))
      end
    end
    reaper.UpdateArrange()
    last_H = H
  end
end
----------------------------------------------
---  Function CHECK ITEM/TAKE CHUNK GUID  ----
----------------------------------------------
function check_item_guid(tab, item, m_type)
  local _, chunk = reaper.GetItemStateChunk(item, "")
  if not tab then
    return chunk
  end -- if there are no versions
  local item_guid = reaper.BR_GetMediaItemGUID(item)
  local take = reaper.GetMediaItemTake(item, 0)
  local source = reaper.GetMediaItemTake_Source(take)
  local m_type = m_type or reaper.GetMediaSourceType(source, "")
  local take_guid = reaper.BR_GetMediaItemTakeGUID(take)
  local POOL_guid

  for i = 1, #tab.data do
    for j = 1, #tab.data[i].chunk do
      local in_table = "{" .. tab.data[i].chunk[j]:match("{(%S+)}") .. "}"
      if in_table == item_guid then
        item_guid = item_guid:sub(2, -2):gsub("%-", "%%-")
        take_guid = take_guid:sub(2, -2):gsub("%-", "%%-")
        if m_type and m_type:find("MIDI") then
          POOL_guid = string.match(chunk, "POOLEDEVTS {(%S+)}"):gsub("%-", "%%-")
        end -- MIDI ITEM
        local new_item_guid = reaper.genGuid():sub(2, -2)
        local new_take_guid = reaper.genGuid():sub(2, -2)
        local new_POOL_guid = reaper.genGuid():sub(2, -2) -- MIDI ITEM
        if m_type and m_type:find("MIDI") then
          chunk = string.gsub(chunk, POOL_guid, new_POOL_guid)
        end -- MIDI ITEM
        chunk = string.gsub(chunk, item_guid, new_item_guid)
        chunk = string.gsub(chunk, take_guid, new_take_guid)
        return chunk
      end
    end
  end
  return chunk
end
--------------------------------------------
---  Function REMOVE PATTERNS FROM CHUNK ---
--------------------------------------------
function pattern(chunk, guid)
  local patterns = {"SEL 0", "SEL 1"}
  for i = 1, #patterns do
    chunk = string.gsub(chunk, patterns[i], "")
  end -- remove SEL part of the chunk
  if guid then
    chunk = string.gsub(chunk, guid, "")
  end
  return chunk
end
---------------------------------
---  Function GET ITEMS CHUNK ---
---------------------------------
function getTrackItems(track, job)
  if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 and not job then
    return
  end
  local items_chunk, items = {}, {}
  local num_items = reaper.CountTrackMediaItems(track)
  for i = 1, num_items, 1 do
    items[#items + 1] = reaper.GetTrackMediaItem(track, i - 1)
  end
  for i = 1, #items do
    local it_chunk = check_item_guid(find_guid(reaper.GetTrackGUID(track)), items[i]) -- DO NOT ALLOW SAME ITEM OR TAKE GUIDS
    items_chunk[#items_chunk + 1] = pattern(it_chunk)
  end
  return items_chunk, items
end
----------------------------------------------------
--- SELECT UNSELECT ITEMS --------------------------
----------------------------------------------------
local function select_items(track, SEL)
  local _, items = getTrackItems(track)
  for i = 1, #items do
    reaper.SetMediaItemSelected(items[i], SEL)
  end
  reaper.UpdateArrange()
end
----------------------------
---  BUTTONS FUNCTIONS   ---
----------------------------
local function new_empty(guid)
  local childs = get_folder(reaper.BR_GetMediaTrackByGUID(0, guid)) or {guid}
  for i = 1, #childs do
    delete_items_on_track(childs[i])
    local child = find_guid(childs[i])
    if not child.data then
      return
    end
    child.data.num = #child.data
    reaper.SetMediaTrackInfo_Value(reaper.BR_GetMediaTrackByGUID(0, childs[i]), "B_FREEMODE", 0) -- disable FIPM
  end
end
------------------------------------
--    FUNCTION GET FOLDER CHILDS ---
------------------------------------
function get_folder(tr)
  if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") <= 0 then
    return
  end -- ignore tracks and last folder child
  local depth, children = 0, {}
  local folderID = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") - 1
  for i = folderID + 1, reaper.CountTracks(0) - 1 do -- start from first track after folder
    local child = reaper.GetTrack(0, i)
    local currDepth = reaper.GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
    children[#children + 1] = reaper.GetTrackGUID(child)
     --insert child into array
    depth = depth + currDepth
    if depth <= -1 then
      break
    end --until we are out of folder
  end
  return children -- if we only getting folder childs
end
-------------------------
---  Function NAMING  ---
-------------------------
function naming(tbl, string, dupli, job, cur_env)
  local count_num, name, data
  if not tbl then
    return "Main"
  end -- FIRST VERSION ON SELECTED TAB
  if job == "track" then
    data = tbl.data
  elseif job == "env" then
    data = tbl[cur_env]
  elseif job == "fx" then
    data = tbl.fx
  elseif job == "comp" then
    data = tbl.data
  end
  if not data then
    return "Main"
  end -- FIRST VERSION IN OTHER TABS
  if manual_naming then -- IF USERS ADD NAMES MANUALLY
    local retval, name = reaper.GetUserInputs("Version name ", 1, "Version Name :", "")
    if not retval or name == "" then
      return
    end
  end
  if string == "V" then -- NEW VERSION
    count_num = count(data, string)
    name = string .. string.format("%02d", count_num)
  elseif dupli then -- DUPLICATE
    count_num = count(data, dupli)
    name = dupli .. "-" .. string .. string.format("%02d", count_num - 1)
  else -- COMP
    count_num = count(data, string)
    name = string .. string.format("%02d", count_num)
  end
  return name
end
-------------------------------------------------
---  Function UNPACK AND SET ENVELOPE POINTS  ---
-------------------------------------------------
function set_env_points(env, tbl)
  local ts_start, ts_end = get_time_sel()
  local set_start, set_end

  -- CREATE POINTS ON CURRENT TIME SELECTION POSITIONS
  if VIEW == 1 then
    local br_env = reaper.BR_EnvAlloc(env, true) -- get
    local br_val_s = reaper.BR_EnvValueAtPos(br_env, ts_start)
    local br_val_e = reaper.BR_EnvValueAtPos(br_env, ts_end)
    local reaper_val_s = reaper.ScaleToEnvelopeMode(1, br_val_s)
    local reaper_val_e = reaper.ScaleToEnvelopeMode(1, br_val_e)
    reaper.InsertEnvelopePoint(env, ts_start, reaper_val_s, 0, 0, 0, false)
    reaper.InsertEnvelopePoint(env, ts_end, reaper_val_e, 0, 0, 0, false)
    reaper.BR_EnvFree(br_env, true) -- release
  end

  for i = 1, #tbl do
    if VIEW == 0 then
      reaper.InsertEnvelopePoint(env, tbl[i].time, tbl[i].value, tbl[i].shape, tbl[i].tension, tbl[i].selected, true)
    else
      if tbl[i].time >= ts_start and tbl[i].time <= ts_end then
        if not set_start then
          reaper.InsertEnvelopePoint(
            env,
            ts_start + 0.01,
            tbl[i].value,
            tbl[i].shape,
            tbl[i].tension,
            tbl[i].selected,
            true
          )
          set_start = true
        end
        if not set_end then
          if math.floor(tbl[i].time) == math.floor(ts_end) then -- IF VALUES ARE CLOSE TO EACH OTHER (SAME)
            reaper.InsertEnvelopePoint(
              env,
              ts_end - 0.01,
              tbl[i].value,
              tbl[i].shape,
              tbl[i].tension,
              tbl[i].selected,
              true
            )
            set_end = true
          end
        end
        reaper.InsertEnvelopePoint(env, tbl[i].time, tbl[i].value, tbl[i].shape, tbl[i].tension, tbl[i].selected, true)
      end
    end
  end
  if VIEW == 1 then
    select_deselect_env_points(env, false)
  end
  reaper.Envelope_SortPoints(env)
end
--------------------------------------------------
---  Function GET/SELECT/DESELECT ENVELOPE POINTS  ---
--------------------------------------------------
function select_deselect_env_points(env, SEL, r_start, r_end)
  if not env then
    return
  end
  local points = {}
  local sel_points = {}
  local range_points = {}
  local all_points = {}
  local env_point_count = reaper.CountEnvelopePoints(env)
  local retval, start_time = reaper.GetEnvelopePoint(env, 0) -- GET FISRT POINT START TIME
  local end_time
  for i = 0, env_point_count - 1 do
    local retval, time, value, shape, tension, selected = reaper.GetEnvelopePoint(env, i)
    points[#points + 1] = {
      retval = retval,
      time = time,
      value = value,
      shape = shape,
      tension = tension,
      selected = false
    }
    end_time = time + 0.0001
     -- GET LAST POINT TIME + add small number to last point (ITS NOT DELETED BY DEFAULT)
    if SEL then
      reaper.SetEnvelopePoint(env, i, timeIn, valueIn, shapeIn, tensionIn, SEL, noSortIn)
    end -- SELECT OR DESELECT ENVELOPE (SEL = FALSE-TRUE)
    all_points[#all_points + 1] = {
      retval = retval,
      time = time,
      value = value,
      shape = shape,
      tension = tension,
      selected = false
    }
    if selected == true then
      sel_points[#sel_points + 1] = {
        retval = retval,
        time = time,
        value = value,
        shape = shape,
        tension = tension,
        selected = false
      }
    end
    if r_start then
      if time >= r_start and time <= r_end then
        range_points[#range_points + 1] = {
          retval = retval,
          time = time,
          value = value,
          shape = shape,
          tension = tension,
          selected = false
        }
      end
    end
  end
  if #all_points == 0 then
    all_points = nil
  end
  if #sel_points == 0 then
    sel_points = nil
  end
  if #range_points == 0 then
    range_points = nil
  end
  local env_points = pickle(points)
  return start_time, end_time, env_points, sel_points, range_points, all_points -- RETURN ENVELOPE POINT TIME RANGE
end
-------------------------------------------
---  Function GET TRACK ENVELOPE TRACK  ---
-------------------------------------------
function get_envelope_track(guid, cur_env)
  local env_tbl = {}
  if not guid then
    return
  end
  local tr = reaper.BR_GetMediaTrackByGUID(0, guid)
  if not tr then
    return
  end
  local env, env_name, retval
  local envs = reaper.CountTrackEnvelopes(tr)
  for i = 0, envs - 1 do
    env = reaper.GetTrackEnvelope(tr, i)
    retval, env_name = reaper.GetEnvelopeName(env, "")
    env_tbl[#env_tbl + 1] = env_name
    if env_name == cur_env then
      break
    end
  end
  if #env_tbl == 0 then
    env_tbl = nil
  end
  return env, env_name, env_tbl
end
----------------------------------------
---  Function GET SELECTED ENVELOPE  ---
----------------------------------------
function get_selected_env()
  local sel_env = reaper.GetSelectedEnvelope(0)
  if sel_env then
    local retval, sel_env_name = reaper.GetEnvelopeName(sel_env, "")
    local env_track, index, index2 = reaper.Envelope_GetParentTrack(sel_env) -- GET TRACK OF SELECTED ENVELOPE
    local env_track_guid = reaper.GetTrackGUID(env_track)
    return env_track_guid, sel_env_name
  end
end
-------------------------------------------
---  Function GET TRACK ENVELOPE chunk  ---
-------------------------------------------
function get_env(guid, cur_env)
  local tr = reaper.BR_GetMediaTrackByGUID(0, guid)
  -- ENVELOPE TRACK IS NOT SELECTED,GET CURRENT ONE FROM MENUBOX SELECTION
  local env, env_name = get_envelope_track(guid, cur_env)
  --local env_track_guid,sel_env_name = get_selected_env()
  local sel_env = reaper.GetSelectedEnvelope(0)
  -- ENVELOPE TRACK IS SELECTED USE IT IF CRITERIA MATCH
  if sel_env then
    local retval, sel_env_name = reaper.GetEnvelopeName(sel_env, "")
    local env_track, index, index2 = reaper.Envelope_GetParentTrack(sel_env) -- GET TRACK OF SELECTED ENVELOPE
    local env_track_guid = reaper.GetTrackGUID(env_track)
    if env_track_guid == guid and cur_env == sel_env_name then
      env = sel_env
    end -- GUID IS SAME,NAME MATCHES MENUBOX
  end
  if not env then
    return
  end
  --- DESELECT ALL ENVELOPES
  select_deselect_env_points(env, false)
  local _, _, env_points = select_deselect_env_points(env)
  --- GET ENVELOPE CHUNK
  local retval, str = reaper.GetEnvelopeStateChunk(env, "", true)
  local visible = string.find(str, "VIS 1")
  if not visible then
    return
  end -- IF ENVELOPE IS NOT VISIBLE DO NOTHING
  return env_points, env_name, env
end
----------------------------------
---  Function CREATE ENVELOPE  ---
----------------------------------
function create_envelope(guid, cur_env, tab, job, duplicate)
  if tab ~= 2 then
    return
  end
  ::JUMP::
  local env_chunk, env_name, env = get_env(guid, cur_env) -- GET POINTS AND NAME
  if not env_name then
    return
  end -- THERE IS NO ENVELOPE TRACK
  local name
  if job == "V" then
    name = naming(find_guid(guid), job, nil, "env", cur_env) -- CREATE NORMAL NAMES
    local time_start, time_end = select_deselect_env_points(env, true) -- SELECT ALL POINTS AND RETURN START AND END OF ENVELOPE POINTS
    if time_start and time_end then
      reaper.DeleteEnvelopePointRange(env, time_start, time_end)
    end
   -- REMOVE POINTS IN THAT RANGE
  elseif job == "D" then
    name = naming(find_guid(guid), job, duplicate, "env", cur_env) -- CREATE DUPLICATE NAMES
  end
  local data = {chunk = env_chunk, name = name, ver_id = reaper.genGuid()}
  ------------------------------------ CREATE TABLE
  if not find_guid(guid) then
    TrackTB[#TrackTB + 1] = {guid = guid, [env_name] = {num = 1, data}}
    goto JUMP
  else
    local env_version = find_guid(guid)
    if not has_env(env_version, cur_env) then
      env_version[env_name] = {num = 1, data}
      goto JUMP
    else
      env_version[env_name][#env_version[env_name] + 1] = data
      env_version[env_name].num = #env_version[env_name]
    end
  end
end
---------------------------------
---  Function CREATE VERSION  ---
---------------------------------
local function create_button(name, guid, chunk, ver_id)
  local version_data = {chunk = chunk, ver_id = ver_id, name = name} -- VERSION TABLE
  if not find_guid(guid) then -- IF TRACK DOES NOT EXIST CREATE FIRST VERSION
    --TrackTB[#TrackTB+1] = {guid = guid, data = {num = 1,fipm = 0,dest = 1,version_data}}
    TrackTB[#TrackTB + 1] = {guid = guid, data = {num = 1, dest = 1, version_data}}
  else -- IF TRACK EXISTS ADD DATA TO ITS TABLE
    local version = find_guid(guid)
    if not version.data then
      version.data = {}
    end
    version.data[#version.data + 1] = version_data -- add data to ver table (insert at last)
    version.data.num = #version.data
  end
end
--------------------------------
--    FUNCTION CREATE FOLDER ---
--------------------------------
function create_folder(tr, version_name, ver_id)
  if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") ~= 1 then
    return
  end
  --local trim_name = string.sub(version_name, 5) -- exclue "F -" from main folder
  local childs = get_folder(tr)
  for i = 1, #childs do
    create_child = create_track(reaper.BR_GetMediaTrackByGUID(0, childs[i]), "F - " .. version_name, ver_id) -- create childs
  end
  create_track(tr, version_name, ver_id) -- create FOLDER only if childs have item chunk (note "empty")
end
-----------------------------------------------------
---  Function Create Button from TRACK SELECTION  ---
-----------------------------------------------------
function create_track(tr, version_name, ver_id, job)
  local chunk = getTrackItems(tr, job) or get_folder(tr) -- GET ITEM CHUNKS OR TRACK GUIDS (IF CHILDREN)
  create_button(version_name, reaper.GetTrackGUID(tr), chunk, ver_id)
end
----------------------------------------
---  Function CREATE TRACK VERSIONS  ---
----------------------------------------
function on_click_function(button, name, tab, duplicate)
  if tab ~= 1 then
    return
  end
  local sel_tr_count = reaper.CountSelectedTracks(0)
  for i = 1, sel_tr_count do
    ::JUMP::
    local tr = reaper.GetSelectedTrack(0, i - 1)
    local guid = reaper.GetTrackGUID(tr)
    if find_guid(guid) and name == "V" then
      new_empty(guid)
    end -- FIRST TIME STORE TRACK VERSION,EVERY TIME AFTER CREATE EMPTY VERSION
    local version_name
    if name == "D" then
      version_name = naming(find_guid(guid), name, duplicate, "track")
    else
      version_name = naming(find_guid(guid), name, nil, "track")
    end
    if not version_name then
      return
    end
    --if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
    --  version_name = "F - " .. version_name
    --end
    button(tr, version_name, reaper.genGuid(), "track") -- "track" to exclued creating folder chunk in gettrackitems function (would result a crash
    if #find_guid(guid).data == 1 then -- MAKE 2 VERSION ON START (IF TRACK HAS NO VERSIONS)
      if name == "V" then
        goto JUMP -- IF CREATING NORMAL VERSION
      elseif name == "D" then
        dupli = version_name
        goto JUMP -- IF CREATING DUPLICATE
      end
    end
  end
end
-----------------------------------
---  Function RESTORE ENVELOPES ---
-----------------------------------
function restore_envelope(guid, cur_env, num)
  local tbl = find_guid(guid)
  local env = reaper.GetTrackEnvelopeByName(reaper.BR_GetMediaTrackByGUID(0, guid), cur_env)
  local time_start, time_end = select_deselect_env_points(env, true) -- SELECT ALL POINTS AND RETURN START AND END OF ENVELOPE POINTS
  if VIEW == 1 then
    time_start, time_end = get_time_sel()
  end -- IF IN TIME SELECTION VIEW
  if time_start and time_end then
    reaper.DeleteEnvelopePointRange(env, time_start, time_end)
  end
   -- REMOVE POINTS IN THAT RANGE
  local point_chunk = unpickle(tbl[cur_env][num].chunk) -- ENV DATA HAS STRINGS AS KEYS
  set_env_points(env, point_chunk)
  tbl[cur_env].num = num -- SET ENVELOPE NEW VERSION NUM
end
----------------------------------------
---  Function DELETE ITEMS ON TRACK  ---
----------------------------------------
function delete_items_on_track(guid)
  local track = reaper.BR_GetMediaTrackByGUID(0, guid)
  local num_items = reaper.CountTrackMediaItems(track)
  for i = num_items, 1, -1 do
    local item = reaper.GetTrackMediaItem(track, i - 1)
    reaper.DeleteTrackMediaItem(track, item)
  end
end
------------------------------------------------
---  Function SHRINK ITEMS TO TIME SELECTION ---
------------------------------------------------
function show_ts_version(item)
  local take = reaper.GetMediaItemTake(item, 0)
  if not take then
    return
  end
  local new_item_start, new_item_lenght, offset = ts_item_position(item)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_item_start)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", new_item_lenght)
  local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", takeOffset + offset)
  reaper.SetMediaItemSelected(item, true)
  reaper.Main_OnCommand(40930, 0) -- trim content behind item
  reaper.SetMediaItemSelected(item, false)
  return item
end
-----------------------------------------
---  Function DO FOR SELECTED TRACKS  ---
-----------------------------------------
function do_tracks(fn_name, val)
  local tracks = get_tracks()
  for i = 1, #tracks do
    fn_name(tracks[i], val)
  end
end
-------------------------------
---  Function RESTORE ITEMS ---
-------------------------------
function restoreTrackItems(track, num)
  local track, track_tb = reaper.BR_GetMediaTrackByGUID(0, track), find_guid(track)
  --if num == track_tb.data.num then return end -- PREVENT ACTIVATING SAME VERSION AGAIN
  local track_items_table = track_tb.data[num].chunk
  -- REMOVE ALL ITEMS FROM TRACK
  local _, _, _, fipm = get_track_info(track_tb.guid)
  if fipm == 0 then
    delete_items_on_track(track_tb.guid)
  end
  -- VIEW TIME SELECTION VERSIONS
  if VIEW == 1 then
    if has_id(track_tb, track_tb.stored_version) then
      local ts_num = has_id(track_tb, track_tb.stored_version)
      for j = 1, #track_tb.data[ts_num].chunk do
        reaper.SetItemStateChunk(reaper.AddMediaItemToTrack(track), track_tb.data[ts_num].chunk[j], false)
      end
    end
  end
  -- SET ITEM CHUNK
  for i = 1, #track_items_table, 1 do
    if reaper.BR_GetMediaTrackByGUID(0, track_items_table[i]) then -- FOLDER (ITS CHUNKS ARE TRACK GUIDS (CHILDS)
      track_tb.data.num = num -- check parent version --
      local child = find_guid(track_items_table[i]) -- get child
      if has_id(child, track_tb.data[track_tb.data.num].ver_id) then -- SET ONLY CHILDS THAT HAVE SAME VER_ID AS FOLDER 
        local pointer = has_id(child, track_tb.data[track_tb.data.num].ver_id)
        child.data.num, child.data.dest = pointer, track_tb.data.dest -- FOLLOW PARENT NUM AND DEST (MAYBE FIRST ONE IS NOT NECCESARY SINCE WE ARE SETING IT BELOW AGAIN) 
        restoreTrackItems(track_items_table[i], pointer) -- SEND INDIVIDUAL CHILDS TO SAME FUNCTION
      end
    else
      track_tb.data.num = num -- SET VERSION NUMBER (TRACK ONLY)
      if fipm == 0 then -- IF VE ARE IN STANDARD VIEW
        local item = reaper.AddMediaItemToTrack(track)
        if VIEW == 1 then -- TIME SELECTION VIEW
          if track_tb.stored_version ~= track_tb.data[track_tb.data.num].ver_id then
            reaper.SetItemStateChunk(item, track_items_table[i], false)
          end -- PREVENT ADDING SAME VERSION AS SOURCE
          if ts_item_position(item) then
            show_ts_version(item)
          else
            reaper.DeleteTrackMediaItem(track, item)
          end -- TIMESELECTION VIEW
        else
          reaper.SetItemStateChunk(item, track_items_table[i], false) -- SET ITEM
        end
      else -- IF WE ARE IN SHOW ALL VERSIONS VIEW
        select_items(track, false) -- DESELECT ITEMS IN TRACK IF SELECTED (IF WE ARE USING MOUSE CLICK ON ITEM TO SELECT LANE IN FIPM)
        mute_view(track_tb) -- SWITCH VERSIONS IN FIPM MODE
      end
    end
  end
  if #track_items_table == 0 then
    track_tb.data.num = num
  end -- CHECK NUM VERSION WHEN SWITCHING EMPTY VERSIONS
end
------------------------------------------------------------
---  Function: CHECK IF GUID FROM TABLE EXIST IN PROJECT ---
------------------------------------------------------------
function validate_guid()
  for i = #TrackTB, 1, -1 do
    if not reaper.ValidatePtr(reaper.BR_GetMediaTrackByGUID(0, TrackTB[i].guid), "MediaTrack*") then
      table.remove(TrackTB, i)
    end
  end
  if TrackTB.groups then
    for i = #TrackTB.groups, 1, -1 do
      for j = #TrackTB.groups[i], 1, -1 do
        if not reaper.ValidatePtr(reaper.BR_GetMediaTrackByGUID(0, TrackTB.groups[i][j]), "MediaTrack*") then
          table.remove(TrackTB.groups[i], j)
        end
      end
      if #TrackTB.groups[i] == 0 then
        TrackTB.groups[i] = nil
      end
    end
    if #TrackTB.groups == 0 then
      TrackTB.groups = nil
    end
  end
  if TrackTB == nil then
    TrackTB = {}
  end
end
------------------------------------
---  Function: SAVE TO TXT FILE  ---
------------------------------------
function save_to_file(data)
  local file
  file = io.open(fn, "w")
  file:write(data)
  file:close()
end
-------------------------------------------
---  Function: READ DATA FROM TXT FILE  ---
-------------------------------------------
function read_from_file()
  local file = io.open(fn, "r")
  if not file then
    return
  end
  local content = file:read("a")
  if content == "" then
    return
  end
  TrackTB = unpickle(content)
  file:close()
  validate_guid() -- check if track exists in project
end
--------------------------------------
---  Function: STORE ALL THE DATA  ---
--------------------------------------
function save_tracks()
  save_to_file(pickle(TrackTB))
end
--------------------------------------
--- Function: Restore ALL THE DATA ---
--------------------------------------
function restore()
  read_from_file()
end
--------------------------------------------------------------------------------
---  Function SET ITEM POSITION AND LENGHT BASED ON TS  ------------------------
--------------------------------------------------------------------------------
function ts_item_position(item)
  local tsStart, tsEnd = get_time_sel()
  local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_dur = item_lenght + item_start

  local new_start, new_item_lenght, offset
  if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
    ----- IF TS START IS IN ITEM BUT TS END IS OUTSIDE THEN COPY ONLY PART FROM TS START TO ITEM END
    new_start, new_item_lenght, offset = item_start, tsEnd - item_start, 0
    return new_start, new_item_lenght, offset, item
  elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
    ------ IF BOTH TS START AND TS END ARE IN ITEM COPY PART FROM TS START TO TS END
    new_start, new_item_lenght, offset = tsStart, item_dur - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart >= item_start and tsEnd <= item_dur then
    ------ IF BOTH TS START AND TS END ARE OUT OF ITEM BUT ITEM IS IN TS COPY ITEM START END
    new_start, new_item_lenght, offset = tsStart, tsEnd - tsStart, (tsStart - item_start)
    return new_start, new_item_lenght, offset, item
  elseif tsStart <= item_start and tsEnd > item_dur then
    new_start, new_item_lenght, offset = item_start, item_lenght, 0
    return new_start, new_item_lenght, offset, item
  end
end
-----------------------------------------------
---  Function TRIM ITEMS AND RETURN CHUNK   ---
-----------------------------------------------
function trim_behind_item(tbl, item, num)
  reaper.SetMediaItemSelected(item, true) -- SELECT NEW ITEM
  reaper.Main_OnCommand(40930, 0) -- trim content behind item
  local items = mute_view(tbl, num) -- GET VERSION ITEMS (GET WHOLE CHUNK AGAIN SINCE WE USED TRIM CONTENT ON SOME ITEMS IF ANY AND WE NEED TO UPDATE THAT ITEMS TOO)
  local chunk = {}
  for j = 1, #items do
    local _, item_chunk = reaper.GetItemStateChunk(items[j], "") -- gets its chunk
    chunk[#chunk + 1] = pattern(item_chunk) -- add it to chunk table
  end
  reaper.SetMediaItemSelected(item, false)
  return chunk
end
---------------------------------
---  Function SWIPE COMPING   ---
---------------------------------
function comping(tbl, mousepos)
  if not tbl then
    return
  end
  local tracks = tbl

  for i = 1, #tracks do
    local track = reaper.BR_GetMediaTrackByGUID(0, tracks[i]) -- get curent track
    local tr_folder = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    local tr_tbl = find_guid(tracks[i])
    local items = mute_view(tr_tbl, mousepos) -- GET ALL ITEMS THAT ARE IN VERSION UNDER MOUSE CURSOR
    local tsitems = {}
    local filename, clonedsource
    -- GET ONLY ITEMS THAT ARE IN  TIME SELECTION
    for i = 1, #items do
      if get_items_in_ts(items[i]) then
        tsitems[#tsitems + 1] = get_items_in_ts(items[i])
      end
    end
    -- GO THRU ITEMS THAT ARE IN TIME SELECTION
    reaper.Undo_BeginBlock()
    local nums = {} -- TABLE IN WE WILL STORE HOW MANY ITEMS WERE CREATED SO WE CAN UNDO THEM
    for i = 1, #tsitems do
      local tsitem = tsitems[i]
      if reaper.IsMediaItemSelected(tsitem) == true then
        reaper.SetMediaItemSelected(tsitem, false)
      end -- deselect selected item if selected (because we will select items below to trim them and to choose version on mouse click)
      --- add unselecting all tracks (if one gets selected some shit start to happen with trim -- NOT SURE WHY I HAD THIS COMMENT FROM MAIN SCRIPT

      local swipedItem, swipe_chunk = make_item_from_ts(tr_tbl, tsitem, track) -- MAKE NEW ITEM FROM TIME SELECTION
      local num = has_id(tr_tbl, cur_comp_id) -- FIND COMP VER_ID IF EXISTS
      if not num then -- IF COMP VERSION DOES NOT EXISTS
        local version_name = naming(tr_tbl, "Comp", nil, "comp")
        create_button(version_name, tr_tbl.guid, swipe_chunk, cur_comp_id, tr_tbl.data.num) -- CREATE NEW COMP VERRSION
        local FIPM_bar, FIPM_item, ver_cnt = get_fipm_value(tr_tbl) -- PREPARE FOR NEW ITEM IN FIPM
        local set_item_H = reaper.SetMediaItemInfo_Value(swipedItem, "F_FREEMODE_H", FIPM_item) -- SET NEW ITEM HEIGHT
        local set_item_Y =
          reaper.SetMediaItemInfo_Value(swipedItem, "F_FREEMODE_Y", ((ver_cnt - 1) * (FIPM_item + FIPM_bar))) -- SET NEW ITEM Y
        tr_tbl.data.num = #tr_tbl.data -- SET TRACK VERSION TO COMP
        nums[#nums + 1] = #tr_tbl.data[#tr_tbl.data].chunk -- GET FIRST ITEM FOR UNDO
        update_fipm(tr_tbl, true) -- UPDATE FIPM VIEW (ADD COMP ITEM)
        populate_listbox(tr_tbl) -- UPDATE LISTBOX VIEW
      else -- IF COMP VERSION EXISTS
        if tr_folder ~= 1 then
          tr_tbl.data[num].chunk[#tr_tbl.data[num].chunk + 1] = swipe_chunk[1]
        end -- ADD CHUNK TO CURRENT COMP
        ---------- TRIM ITEMS BEHIND IF ITEMS OVERLAP
        update_fipm(tr_tbl, true) -- UPDATE FIPM VIEW (ADD COMP ITEM)
        local new_chunk = trim_behind_item(tr_tbl, swipedItem, num)
        tr_tbl.data[num].chunk = new_chunk -- REPLACE WHOLE COMP CHUNK TABLE WITH NEW ONE (WE NEED DO THIS SINCE WE ARE TRIMMING BEHIND SOME ITEM IF ANY)
        update_listbox(num) -- UPDATE LISTBOX HIGHLIGHT
        nums[#nums + 1] = #tr_tbl.data[#tr_tbl.data].chunk -- GET REST OF ITEMS FOR UNDO
      end
    end
    restoreTrackItems(tr_tbl.guid, #tr_tbl.data) -- SET COMP ACTIVE (IT IS LAST VERSION)
    undo_name = create_undo_name(tr_tbl.guid, cur_comp_id, table.concat(nums, ","), tr_tbl.data[#tr_tbl.data].chunk) -- CREATE UNDO NAME WHICH CONTAINTS CHUNK DATA
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(undo_name, 4)
end
------------------------------
---  Function: COPY TO  -----
------------------------------
function get_items_for_destination(guid, mouse_pos)
  local tr_tbl = find_guid(guid)
  local track = reaper.BR_GetMediaTrackByGUID(0, guid) -- get curent track
  local _, _, _, fipm = get_track_info(guid)
  local ret
  local cur_items = {}
  if fipm == 1 then
    cur_items = mute_view(tr_tbl, mouse_pos)
  else
    ret, cur_items = getTrackItems(reaper.BR_GetMediaTrackByGUID(0, guid))
  end

  local items = {}
  for i = 1, #cur_items do
    if get_time_sel() and get_items_in_ts(cur_items[i]) then
      items[#items + 1] = get_items_in_ts(cur_items[i])
    end
   -- TIME SELECTION AND ITEMS ARE IN IT
  end

  for i = 1, #items do
    if reaper.IsMediaItemSelected(items[i]) == true then
      reaper.SetMediaItemSelected(items[i], false)
    end -- deselect selected item if selected (because we will select items below to trim them and to choose version on mouse click)
    local swipedItem, swipe_chunk = make_item_from_ts(tr_tbl, items[i], track) -- MAKE NEW ITEM FROM TIME SELECTION
    tr_tbl.data[tr_tbl.data.dest].chunk[#tr_tbl.data[tr_tbl.data.dest].chunk + 1] = swipe_chunk[1]
    update_fipm(tr_tbl, true)
    local new_chunk = trim_behind_item(tr_tbl, swipedItem, tr_tbl.data.dest)
    tr_tbl.data[tr_tbl.data.dest].chunk = new_chunk -- REPLACE WHOLE CHUNK TABLE WITH NEW ONE (WE NEED DO THIS SINCE WE ARE TRIMMING BEHIND SOME ITEM IF ANY)
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Destination comp", 0)
end
------------------------------
---  Function: AUTO SAVE  ----
------------------------------
local delete_test = nil -- TESTING DELETING ITEMS AND SHIT AROUND WHEN SPLITTING
function auto_save(last_action, current, guid, mousepos)
  reaper.PreventUIRefresh(1)
  local save
  local tracks_tbl = {}
  local ignore = {"unselect all items", "remove material behind selected items"} -- undo which will ignore auto save
  if not has_undo(ignore, last_action) then
    if last_action:find("remove tracks") then
      validate_guid()
    end -- TRACK HAS BEEN DELETED IN REAPER
    if not last_action:find("automation item") and last_action:find("item") or last_action:find("recorded media") or
        last_action:find("midi editor: insert notes") or
        last_action:find("change source media") or
        last_action:find("rename source media") or
        last_action:find("custom") or
        last_action:find("take")
     then
      --------------------- ITEMS
      if not current then current =  reaper.GetSelectedTrack( 0, 0 )
        --return
      end
      local cur_track = reaper.GetTrackGUID(current)
      if not find_guid(cur_track) or not find_guid(cur_track).data then
        return
      end
      local cnt = reaper.CountSelectedMediaItems(0)
      -- IF WE ARE DRAWING ITEMS ON A TRACK (USER TRACK UNDER MOUSE SINCE THERE IS NO OTHER WAY TO GET TRACKS,NO ITEMS ARE SELECTED)
      if last_action:find("pencil") or last_action:find("adjust") then
        if not folder and current then
          tracks_tbl[#tracks_tbl + 1] = reaper.GetTrackGUID(current)
        end -- IF WE ARE MODIFYING CURRENT VERSION (DRAWING,FADING,CUTTING)
      end
      ---- MULTIPLE ITEMS ACCROSS THE TRACKS (INSERTED,SELECTED,CUT,FADED)
      for i = 1, cnt do
        local sel_item = reaper.GetSelectedMediaItem(0, i - 1)
        local tr = reaper.GetMediaItemTrack(sel_item)
        local tr_guid = reaper.GetTrackGUID(tr)
        if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") ~= 1 then
          tracks_tbl[#tracks_tbl + 1] = tr_guid
        end
      end

      local cur_tbl = tracks_tbl
      -- SAVE TRACKS IF THIS ACTIONS WERE MADE
      if
        last_action:find("marquee item selection") or last_action:find("split items") or
          last_action:find("change media item selection")
       then
        delete_test = tracks_tbl
      end
      if last_action:find("delete items") then
        cur_tbl = delete_test -- IF DELETE HAPPENED USE STORED TABLE
      end

      for i = 1, #cur_tbl do
        local track = find_guid(cur_tbl[i])
        if not track then
          return
        end -- IF TRACK HAS NO DATA DO NOTHING
        local _, _, _, fipm = get_track_info(track.guid)
        if last_action:find("change media item selection") or last_action:find("change track selection") then
          return
        end -- DO NOT SAVE DATA IF WE ARE ONLY CHANGING ITEM SELECTION
        if fipm == 0 then -- if multi view is disable
          track.data[track.data.num].chunk = getTrackItems(reaper.BR_GetMediaTrackByGUID(0, track.guid)) -- SINGLE TRACK SAVE
        else -- IF WE ARE IN FIPM
          local items = mute_view(track, mousepos) -- LOOK FOR ITEMS THAT ARE IN VERSION UNDER MOUSE CURSOR
          local chunk = {}
          for i = 1, #items do
            local _, item_chunk = reaper.GetItemStateChunk(items[i], "") -- gets its chunk
            chunk[#chunk + 1] = pattern(item_chunk) -- add it to chunk table
          end
          track.data[mousepos].chunk = chunk -- SAVE AT MOUSE POSITION VERSION
          track.data.num = mousepos -- SET LAST MODIFIED VERSION ACTIVE -----
          update_listbox(mousepos) -- UPDATE LISTBOX HIGHLIIGHT
          update_fipm(track, true)
        end
      end
      if last_action:find("delete items") then
        test = nil
      end
    end
    --------------------- ITEMS END ----- ENVELOPES START
    if last_action:find("envelope") then
      local cur_env = GUI.elms.Menubox1.optarray[GUI.Val("Menubox1")]
      local sel_env = reaper.GetSelectedEnvelope(0)
      if not sel_env then
        return
      end
      local env_track, index, index2 = reaper.Envelope_GetParentTrack(sel_env) -- get envelopes main track
      local env_track_guid = reaper.GetTrackGUID(env_track)
      local tbl = find_guid(env_track_guid)
      if not tbl or not tbl[cur_env] then
        return
      end -- IF ENVELOPE VERSION DOES NOT EXIST DO NOT STORE ANYTHING
      local env_num = tbl[cur_env].num -- GET CURRENT ENVELOPE NUM
      local _, _, env_points = select_deselect_env_points(sel_env, false)
      tbl[cur_env][env_num].chunk = env_points -- GET NEW CHUNK IF TABLE EXISTS
    end
    ------------------------ FX STARTS
    if last_action:find("edit fx parameter: track") then
      local tbl = find_guid(guid)
      tbl.fx[tbl.fx.fx_num].chunk = get_fx_chunk(guid)
    end
    save_tracks()
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end