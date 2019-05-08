package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;" -- GET DIRECTORY FOR REQUIRE
require("Area_51_Functions") -- AREA FUNCTIONS SCRIPT
local Areas = {}
local active_as
local W,H = 5000,5000
local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 1000) -- GET TRACK VIEW
local mixer_wnd = reaper.JS_Window_Find("mixer", true) -- GET MIXER -- tHIS NEEDS TO BE CONVERTED TO ID , AND I STILL DO NOT KNOW HOW TO FIND THEM

local A
local function test()
  local a = reaper.new_array({}, 1000)
  A = {}
  reaper.JS_Window_ArrayAllChild(reaper.GetMainHwnd(), a)
  local t = a.table()
  for i, adr in ipairs(t) do
    local handl = reaper.JS_Window_HandleFromAddress(adr)
    local track = reaper.JS_Window_GetLongPtr(handl, "USER")
    local vis = reaper.JS_Window_IsVisible(handl)
    if reaper.JS_Window_GetParent(reaper.JS_Window_GetParent(handl)) ~= mixer_wnd then --and vis then
      if reaper.ValidatePtr(track, "MediaTrack*") or reaper.ValidatePtr(track, "TrackEnvelope*") then
        local _, _, top, _, bottom = reaper.JS_Window_GetClientRect(handl)
        A[tostring(track)] = {t = top, b = bottom, h = bottom - top}
      end
    end
  end
end

local function new_GetTrackFromRange(y_t, y_b)
  local range_tracks = {}
  for k , v in pairs(A) do
    if v.t >= y_t and v.b <= y_b then
      range_tracks[#range_tracks+1] = k
    end
  end
  return range_tracks
end

local l_r_s,l_r_e
A1 = 0
local function GetTrackFromRange(y_t, y_b) -- GET ALL TRACKS IN MOUSE RANGE
  if l_r_s ~= y_t or l_r_e ~= y_b then
    local range_tracks = {} -- TABLE FOR TRACKS IN RANGE
    local trackview_window
    local _, _, arr_top = reaper.JS_Window_GetRect(track_window)
    local window = reaper.JS_Window_GetRelated(track_window, "NEXT")
    while window do
      local _, _, top = reaper.JS_Window_GetRect(window)
      if top == arr_top then trackview_window = reaper.JS_Window_GetRelated(window, "CHILD") end
      window = reaper.JS_Window_GetRelated(window, "NEXT")
    end 
      -- loop over track and envelope windows 
    local window = reaper.JS_Window_GetRelated(trackview_window, "CHILD")
    while window do
      A1 = A1 + 1
      if reaper.JS_Window_IsVisible(window) then
        -- windows visible in arrange view only
        local _, _, top, _, bottom = reaper.JS_Window_GetRect(window)
        if top >= y_t and bottom <= y_b then -- IF TRACK IS IN THE MOUSE ZONE RANGE 
          local pointer = reaper.JS_Window_GetLongPtr(window, "USERDATA")
          if reaper.ValidatePtr(pointer, "MediaTrack*") then
            if not has_val(range_tracks, pointer) then range_tracks[#range_tracks+1] = pointer end -- ADD TRACKS TO TABLE IF THEY ARE NOT ALREADY THERE
          elseif  reaper.ValidatePtr(pointer, "TrackEnvelope*") then
            --local retval, index, index2 = reaper.Envelope_GetParentTrack(pointer) -- GET PARENT TRACK OF ENVELOPE
            if not has_val(range_tracks, pointer) then range_tracks[#range_tracks+1] = pointer end
          end
        end
      end
    window = reaper.JS_Window_GetRelated(window, "NEXT") --> window or nil
    end
    l_r_s,l_r_e = y_t, y_b
    return range_tracks 
  end
end

local function GetTrackFromPoint() --> Track, segment
  local x, y = reaper.GetMousePosition()
  local trackview_window
  local window_under_mouse = reaper.JS_Window_FromPoint(x, y)
  if window_under_mouse ~= track_window then return end -- DO NOT ALLOW DRAWING OVER WINDOW THAT IS NOT ARRANGE
  local _, _, arr_top = reaper.JS_Window_GetRect(track_window)
  local window = reaper.JS_Window_GetRelated(track_window, "NEXT")
  while window do
    local _, _, top = reaper.JS_Window_GetRect(window)
    if top == arr_top then trackview_window = reaper.JS_Window_GetRelated(window, "CHILD") end
    window = reaper.JS_Window_GetRelated(window, "NEXT")
  end
    -- loop over track and envelope windows
  local window = reaper.JS_Window_GetRelated(trackview_window, "CHILD")
  while window do
    if reaper.JS_Window_IsVisible(window) then
      -- windows visible in arrange view only
      local _, _, top, _, bottom = reaper.JS_Window_GetRect(window)
      if top <= y and bottom > y then -- IF MOUSE IS IN THE TRACK RANGE
        local pointer = reaper.JS_Window_GetLongPtr(window, "USERDATA")
        if reaper.ValidatePtr(pointer, "MediaTrack*") then
          return pointer, top, bottom  --> Track, segment
        elseif  reaper.ValidatePtr(pointer, "TrackEnvelope*") then
          --local retval, index, index2 = reaper.Envelope_GetParentTrack(pointer) -- GET PARENT TRACK OF ENVELOPE
          return pointer, top, bottom --> Envelope, segment
        end
      end
    end
  window = reaper.JS_Window_GetRelated(window, "NEXT") --> window or nil
  end
end

local function project_info()
  local proj_state = reaper.GetProjectStateChangeCount( 0 )
  local zoom_lvl = reaper.GetHZoomLevel() -- HORIZONTAL ZOOM LEVEL
  local _, scroll, _, _, scroll_b = reaper.JS_Window_GetScrollInfo(track_window, "SB_VERT") -- GET VERTICAL SCROLL
  local Arr_start_time, Arr_end_time = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW
  local Arr_pixel = math.floor(Arr_start_time * zoom_lvl)-- ARRANGE VIEW POSITION CONVERT TO PIXELS 
  local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window) -- GET TRACK WINDOW X-Y COORDINATES
  return zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, proj_state, scroll, scroll_b
end

local prev_start,prev_end
local function check_draw(c_start,c_end)
  if prev_end ~= c_end or prev_start ~= c_start then 
    prev_start, prev_end = c_start, c_end
    return true
  end
end

local function new_track_y_range(tbl)
  local totalh = 0
  local t, b, h, first_top
  for i = 1, #tbl do
    local track = tbl[i].track
    t, b, h = A[tostring(track)].t, A[tostring(track)].b, A[tostring(track)].h
    totalh = totalh + h
    if not first_top then first_top = t end -- GET FIRST TRACK Y_TOP
    if t < first_top then first_top = t end
  end
  return first_top, totalh, b
end

local prev_total_pr_h, prev_Arr_end_time, prev_proj_state, last_zoom_lvl, last_scroll, last_tr, last_scroll_b
local function status()
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, proj_state, scroll, scroll_b = project_info() 
  if prev_Arr_end_time ~= Arr_end_time then -- THIS ONE ALWAYS CHANGES WHEN ZOOMING IN OUT
    prev_Arr_end_time = Arr_end_time
    return true
  elseif last_zoom_lvl ~= zoom_lvl then 
    last_zoom_lvl = zoom_lvl
    return true
  elseif prev_proj_state ~= proj_state then
    prev_proj_state = proj_state
    return true
  elseif last_scroll ~= scroll then 
    last_scroll = scroll
    return true
  elseif last_scroll_b ~= scroll_b then
    last_scroll_b = scroll_b
    return true 
  end 
end

local area_selection = {}
function area_selection:new(as_tracks, as_sel_start, as_sel_end, as_guid)
  local elm = {}
  elm.guid, elm.bm = as_guid, reaper.JS_LICE_CreateBitmap(true, 1, 1); reaper.JS_LICE_Clear(elm.bm, 0x33000055)
  elm.tracks, elm.sel_start, elm.sel_end = as_tracks, as_sel_start, as_sel_end
  setmetatable(elm, self)
  self.__index = self 
  return elm
end

function area_selection:update_xywh()
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end = project_info() 

  local y, h = new_track_y_range(self.tracks) -- NEW TRACK RANGE (FIND IT FROM TABLE)
  if not y then y = 0 end -- FIX BECAUSE FUNCTION ABOVE DOES NOT RETURN Y IF THE TRACK IS NOT IN VIEW
  
  y = y - y_view_start
  
  local xStart = math.floor(self.sel_start * zoom_lvl) -- convert time to pixel 
  local xEnd  = math.floor(self.sel_end * zoom_lvl) -- convert time to pixel  
   
  local w = xEnd - xStart -- CREATE/UPDATE W
  local x = xStart - Arr_pixel -- CREATE/UPDATE X
  self:draw(x, y, w, h) -- REDRAW AFTER UPDATE
end

function area_selection:draw(x, y, w, h)
  reaper.JS_Composite(track_window, x, y, w, h, self.bm, 0, 0, 1, 1)
  reaper.JS_Window_InvalidateRect(track_window, 0, 0, W, H, false)
end

local function get_mouse_y_pos_in_track(tr, mY)
  if tr == nil then return end
  local tr_tbl = {[1] = {track = tr}}
  local tYs, tr_h = new_track_y_range(tr_tbl)
  local mouse_in_track = (mY - tYs)
  if mouse_in_track < tr_h / 2 then return true else return false end -- IF MOUSE IS IN UPPER HALF OF THE TRACK RETURN TRUE, IF IN LOWER PART RETURN FALSE
end

function has_val(tab, val)
  for i = 1 , #tab do
    local in_table = tab[i]
    if in_table == val then return i end
  end
end

local function has_guid(tab, val)
  for i = 1 , #tab do
    local in_table = tab[i].guid
    if in_table == val then return tab[i] end
  end
end

local function remove_as_from_tbl(tab, val) -- REMOVE AS FROM TABLE ALONG WITH ITS BITMAPS
  for i = #tab , 1, -1 do
    local in_table = tab[i].guid
    if in_table ~= val then
      reaper.JS_Composite_Unlink(track_window, tab[i].bm) -- UNLINK BITMAPS THAT WILL BE DESTROYED
      reaper.JS_LICE_DestroyBitmap(tab[i].bm) -- DESTROY BITMAPS FROM AS THAT WILL BE DELETED
      table.remove(tab, i) -- REMOVE AS FROM TABLE
    end
  end
end

local function check_reverse(val1, val2)
  if val2 < val1 then
    return val2, val1 -- RETURN REVERSE
  else
    return val1, val2 -- RETURN NOTMAL
  end
end

local function make_as(tbl, click)
  local as_sel_start, as_sel_end, as_info, as_guid = tbl[1], tbl[2], tbl[3], tbl[4]
  -- MAKE NEW AREA CLASS
  if not has_guid(Areas, as_guid) then
    Areas[#Areas+1] = area_selection:new(as_info, as_sel_start, as_sel_end, as_guid) -- CREATE NEW CLASS ONLY IF DOES NOT EXIST
    active_as = Areas[#Areas] 
  else
    if click == 1 then  -- IF SHIFT IS NOT DOWN (FOR MAKING MULTI AS)
      if #Areas > 1 then remove_as_from_tbl(Areas,"single") end -- REMOVE ALL OTHER AS -- FUNCTION REMOVES EVERYTHING THAT DOES NOT THIS NAME
    end
    local cur_area = has_guid(Areas, as_guid) -- IF AS ALREADY EXISTS
    cur_area.sel_start, cur_area.sel_end, cur_area.tracks = as_sel_start, as_sel_end, as_info -- UPDATE IT
  end
end
A2 = 0
local mouse_range_tracks
local l_click_start, l_click_end
local function get_range_info(click_start, click_end, as_guid, click, r_s, r_e)
  local click_start, click_end = check_reverse(click_start, click_end)
  local mouse_range_tracks1 = GetTrackFromRange(r_s, r_e) -- GET ALL TRACKS IN MOUSE RANGE
  
  if mouse_range_tracks1 then mouse_range_tracks = mouse_range_tracks1 end
  local as_items = {}
  if l_click_start ~= click_start or l_click_end ~= click_end then
    for i = 1, #mouse_range_tracks do
      A2 = A2 + 1
      local as_tr = mouse_range_tracks[i]
      local tr_as_items, tr_as_env, tr_as_AI, retval, env_name
      local items_bm = {}
      if reaper.ValidatePtr(as_tr, "MediaTrack*") then
        tr_as_items = get_items_in_as(as_tr, click_start, click_end) -- TRACK ITEMS 
      elseif reaper.ValidatePtr(as_tr, "TrackEnvelope*") then
        retval, env_name = reaper.GetEnvelopeName( mouse_range_tracks[i])
        tr_as_env = get_as_tr_env_pts(as_tr, click_start, click_end) -- NORMAL ENVELOPES
        tr_as_AI = get_as_tr_AI(as_tr, click_start, click_end) -- AUTOMATION ITEMS
      end
      as_items[#as_items + 1] = {track = mouse_range_tracks[i], items = tr_as_items, items_bm = items_bm, env_name = env_name, points = tr_as_env, AIs = tr_as_AI}
    end
    
    if click_start ~= click_end then 
      drawing = check_draw(click_start,click_end)
      make_as({click_start, click_end, as_items, as_guid}, click ) -- ONLY MAKE AS IF THERE IS RANGE
    end
    l_click_start, l_click_end = click_start, click_end
  end
  
end

local function top_bot(top_start, top_end, bot_start, bot_end)
  if bot_end <= top_start then -- IF BOTTOM IS LESS THAN TOP (MOUSE IS ABOVE STARTING TRACK)
    return bot_start, top_end
  else                         -- IF BOTTOM IS GREATER THAN TOP (MOUSE IS BELLOW STARTING TRACK)
    return top_start, bot_end
  end
end

local down,hold
local click_start,click_end
local top_start, top_end, bot_start, bot_end
local r_s, r_e
local as_guid
--- THIS BELOW COULD BE BETTER WRITTEN
local function mouse_click(click, pos, mouse_in, mouse_r_start, mouse_r_end, AS_AT_MOUSE)
  if block then return end  
  if (click == 1 or click == 9) and mouse_in then down = true
    if not hold then
      top_start, top_end = mouse_r_start, mouse_r_end -- MOUSE RANGE START
      click_start = pos -- GET TIME WHEN MOUSE IS CLICKED
      if click == 9 then as_guid = reaper.genGuid() elseif click == 1 then as_guid = "single" end
      hold = true
    end 
  end
  if down then
    click_end = pos -- GET TIME WHILE MOUSE IS DOWN
    bot_start, bot_end = mouse_r_start, mouse_r_end -- MOUSE RANGE END
      
    if bot_start and bot_end then
      r_s, r_e = top_bot(top_start, top_end, bot_start, bot_end) -- CHECK IF RANGES ARE REVERSED 
    end
    
    get_range_info(click_start, click_end, as_guid, click, r_s, r_e)
    
    if click == 0 or click == 8 then -- RESET EVERYTHING WHEN CLICK IS DOWN
      over = nil
      down,hold = nil,nil
      click_start, click_end = nil, nil
      drawing = nil
      check = nil
    end
  end 
end

local function select_as(key)
  local num = tonumber(key)
  if #Areas ~= 0 and num > #Areas then return end
  active_as = Areas[num] 
end

local vk = {
            {code = 0x1B, name = 'ESC', press = false, hold = false, release = true},
            {code = 0x31, name = '1', press = false, hold = false, release = true},
            {code = 0x32, name = '2', press = false, hold = false, release = true},
            {code = 0x33, name = '3', press = false, hold = false, release = true},
            {code = 0x34, name = 'paste', press = false, hold = false, release = true},
            {code = 0x35, name = '5', press = false, hold = false, release = true}
            }
function keys(tr, pos) 
  local OK, state = reaper.JS_VKeys_GetState()
  for i = 1, #vk do
    if state:byte(vk[i].code) ~= 0 then 
      if not vk[i].press then vk[i].press = true --end -- PRESS
        if vk[i].name == "ESC" then remove_as_from_tbl(Areas,"DELETE")
        elseif vk[i].name == "1" or vk[i].name == "2" or vk[i].name == "3" then
          select_as(vk[i].name)
          elseif vk[i].name == "5" then copy = not copy
        else
        --if vk[i].name == "ESC" then get_as_info(Areas,"ESC") end
        --get_as_info(Areas,vk[i].name, tr, pos)
        get_as_info(active_as,vk[i].name, tr, pos)
        end
      end
    else
      vk[i].press = false
      vk[i].hold = false
      vk[i].release = true
      key_status = nil
    end
  end
end

local function mouse_as(m_tr, time) -- RETURN GUID OF AS UNDER MOUSE CURSOR
  for i = 1, #Areas do
    if time > Areas[i].sel_start and time < Areas[i].sel_end then
      for j = 1, #Areas[i].tracks do
        local as_tr = Areas[i].tracks[j]
        if as_tr == m_tr then return Areas[i] end
      end
    end
  end
end

local items_bm = {}
local function draw_item_shadow(mouse_time_pos, zoom_lvl, y_view_start, Arr_pixel)
  if not active_as then return end
  for i = 1, #active_as.tracks do
    if active_as.tracks[i].items then
      local track = active_as.tracks[i].track
      local i_y, i_h, i_b = A[tostring(track)].t, A[tostring(track)].h, A[tostring(track)].b
      if not items_bm[i] then items_bm[i] = {} end
      for j = 1, #active_as.tracks[i].items do
        local item = active_as.tracks[i].items[j]
        if items_bm[i][j] == nil then items_bm[i][j] = reaper.JS_LICE_CreateBitmap(true, 1, 1); reaper.JS_LICE_Clear(items_bm[i][j], 0x66557788) end   
        local new_item_start, new_item_lenght = as_item_position(item, active_as.sel_start, active_as.sel_end, mouse_time_pos)
        --reaper.JS_Composite(track_window, math.floor(new_item_start * zoom_lvl) - Arr_pixel, (i_y - y_view_start), math.floor(new_item_lenght * zoom_lvl), i_b - i_y, items_bm[i][j], 0, 0, 1, 1)
        --reaper.JS_Window_InvalidateRect(track_window, 0, 0, W, H, false)
      end
    end
  end
  --reaper.JS_Window_InvalidateRect(track_window, 0, 0, W, H, false)
end

local function main()
  test() -- GET ALL TRACKS Y-H INFO
  local tr, r_start, r_end = GetTrackFromPoint() -- TRACK OR ENVELOPE
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, state, scroll = project_info() 
  local cur_m_x, cur_m_y = reaper.GetMousePosition()
  local m_click = reaper.JS_Mouse_GetState(13) -- INTERCEPT MOUSE CLICK
  local mouse_time_pos = ((cur_m_x - x_view_start) / zoom_lvl) + Arr_start_time
  local mouse_in = get_mouse_y_pos_in_track(tr, cur_m_y) -- CHECKS THE MOUSE POSITION IN THE TRACK (UPPER PART TRUE, LOWER PART FALSE)
  local pos = (reaper.GetToggleCommandState(1157) == 1) and reaper.SnapToGrid(0, mouse_time_pos) or mouse_time_pos -- FINAL POSITION IS SNAP IF ENABLED OF FREE MOUSE POSITION
  
  mouse_click(m_click, pos, mouse_in, r_start, r_end, AS_AT_MOUSE) -- GET CLICKED TRACKS, MOUSE TIME RANGE
  
  draw_item_shadow(pos, zoom_lvl, y_view_start, Arr_pixel)
  
  DRAW_AREA(Areas) -- DRAW THIS BAD BOYS
  
  keys(tr,pos)
  
  reaper.defer(main)
end

function DRAW_AREA(tbl)
  if status() then
    for i = 1 ,#tbl do tbl[i]:update_xywh() end -- UPDATE ALL AS ONLY ON CHANGE
  elseif drawing then
    tbl[#tbl]:update_xywh() -- UPDATE ONLY AS THAT IS DRAWING (LAST CREATED) STILL NEEDS MINOR FIXING TO DRAW ONLY LAST AS IN LAST TABLE,RIGHT NOT IT UPDATES ONLY LAST AS TABLE (EVERY AS IN LAST TABLE)
  end
end

function exit() -- DESTROY BITMAPS ON REAPER EXIT
  for i = 1, #Areas do
    local bm = Areas[i].bm
    reaper.JS_Composite_Unlink(track_window,bm)
    reaper.JS_LICE_DestroyBitmap(bm)
    for j = 1, #Areas[i].tracks do
      if Areas[i].tracks[j].items_bm then
        for k = 1 , #Areas[i].tracks[j].items_bm do
          reaper.JS_Composite_Unlink(track_window,Areas[i].tracks[j].items_bm[k])
          reaper.JS_LICE_DestroyBitmap(Areas[i].tracks[j].items_bm[k])
        end
      end
  end
 
  end
  
  if reaper.ValidatePtr(track_window, "HWND") then 
    reaper.JS_Window_InvalidateRect(track_window, 0, 0, W, H, true) 
  end
end

reaper.atexit(exit)
main()
