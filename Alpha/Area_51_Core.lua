Areas = {}
local W,H = 5000,5000
local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local mixer_wnd = reaper.JS_Window_Find("mixer", true) -- GET MIXEWR I GUESS
local track_window = reaper.JS_Window_Find("trackview", true) -- GET TRACK VIEW

local function to_pixel(val,zoom)
  local pixel = math.floor(val * zoom)
  return pixel
end

local function project_info()
  local zoom_lvl = reaper.GetHZoomLevel() -- HORIZONTAL ZOOM LEVEL
  local Arr_start_time, Arr_end_time = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW
  local Arr_pixel = to_pixel(Arr_start_time,zoom_lvl)-- ARRANGE VIEW POSITION CONVERT TO PIXELS
  local _, scroll, _, _, _ = reaper.JS_Window_GetScrollInfo(track_window, "SB_VERT") -- GET VERTICAL SCROLL
  local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window) -- GET TRACK WINDOW X-Y COORDINATES
  return zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, scroll, x_view_start, y_view_start, x_view_end, y_view_end
end

local function get_track_zoom_offset(tr,y_end,h,scroll) -- GET TRACK VIEW (THIS VOODOO SHIT HERE GETS TRACK VIEW OFFSETS COORDINATES)
  local retval, list = reaper.JS_Window_ListAllChild(main_wnd)
  local fl,offset
  for adr in list:gmatch("%w+") do
    local handl = reaper.JS_Window_HandleFromAddress(tonumber(adr))
    if reaper.JS_Window_GetLongPtr(handl, "USER") == tr then 
      if mixer_wnd ~= reaper.JS_Window_GetParent(reaper.JS_Window_GetParent(handl)) then fl = handl break end
    end
  end
  if not fl then return end
  local __, __, ztop, __, __ = reaper.JS_Window_GetRect(fl)
  if y_end > (ztop + h - 1) then offset = y_end - ztop - h end
  return offset
end

local function get_track_y_range(y_view_start, scroll, cur_tr)
  if not cur_tr then return end
  local trcount = reaper.GetMediaTrackInfo_Value(cur_tr, "IP_TRACKNUMBER" ) -- WE ONLY COUNT TO CURRENT SELECTED TRACK (SINCE WE ONLY NEED Y-POS OF THAT TRACK)
  local masvis, totalh, idx = reaper.GetMasterTrackVisibility(), y_view_start - scroll , 1 -- VIEWS Y START, SUBTRACTED BY SCROLL POSITION
  if masvis == 1 then totalh = totalh + 5; idx = 0 end -- INCLUDE MASTER TRACK IF VISIBLE -- THIS NEEDS FIXING
  local y_start, y_end, height, offset
  for tr = idx, trcount do
    local track = reaper.CSurf_TrackFromID(tr, false)
    height = reaper.GetMediaTrackInfo_Value(track, "I_WNDH") -- TRACK HEIGHT    
    y_start = totalh  -- TRACK Y START
    y_end = totalh + height -- TRACK Y END
    totalh = (totalh + height) -- TOTAL TRACK Y RANGE
    if get_track_zoom_offset(track, totalh, height, scroll) then -- IF SCROLLED/ZOOMED ETC
      offset = get_track_zoom_offset(track, totalh, height, scroll) -- GET OFFSET
      totalh = totalh - get_track_zoom_offset(track, totalh, height, scroll) -- UPDATE TRACK TOTAL Y RANGE
    end
  end
  return y_start,y_end -- RETURN TRACKS Y START & END
end

local prev_start,prev_end,prev_scroll
local pre_tr_y_start,prev_tr_y_end
local prev_Arr_start_time,prev_Arr_end_time = reaper.GetSet_ArrangeView2( 0, false,0,0)
local prev_proj_state = reaper.GetProjectStateChangeCount( 0 )

local function status(c_start, c_end, tr_tbl) -- needs y_view_start
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, scroll, x_view_start, y_view_start, x_view_end, y_view_end = project_info()
  local proj_state = reaper.GetProjectStateChangeCount( 0 )
  
  local tr_y_start,tr_y_end = get_track_y_range(y_view_start,scroll,tr_tbl[1])  -- GET TRACK Y RANGE (FIRST_TRACK)
  
  if prev_Arr_start_time ~= Arr_start_time or prev_Arr_end_time ~= Arr_end_time  then
    prev_Arr_start_time,prev_Arr_end_time = Arr_start_time,Arr_end_time
    return true
  elseif prev_end ~= c_end or prev_start ~= c_start then 
    prev_start, prev_end = c_start, c_end 
    return true
  elseif prev_proj_state ~= proj_state then
    prev_proj_state = proj_state
    return true
  elseif pre_tr_y_start ~= tr_y_start or prev_tr_y_end ~= tr_y_end then
    pre_tr_y_start = tr_y_start
    prev_tr_y_end = tr_y_end
    return true
  end 
end

local area_selection = {}
function area_selection:new(as_tracks, as_sel_start, as_sel_end, as_guid)
  local elm = {}
  elm.bm, elm.guid = reaper.JS_LICE_CreateBitmap(true, 1, 1) , as_guid
  reaper.JS_LICE_Clear(elm.bm, 0x77AA0000)
  elm.tracks, elm.sel_start, elm.sel_end = as_tracks, as_sel_start, as_sel_end
  setmetatable(elm, self)
  self.__index = self 
  return elm
end

function area_selection:update_xywh()
  local x,y,w,h
  ------------------------------------------------------------------------------------------------------------------------------------
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, scroll, x_view_start, y_view_start, x_view_end, y_view_end = project_info()
  ------------------------------------------------------------------------------------------------------------------------------------ 
  local tr_y_start,tr_y_end = get_track_y_range(y_view_start,scroll,self.tracks[1])  -- GET AREAS FIRST TRACKY Y RANGE 
  local last_tr_y_start,last_tr_y_end = get_track_y_range(y_view_start,scroll,self.tracks[#self.tracks])  -- GET AREAS LAST TRACK Y RANGE 
  
  local draw = status(self.sel_start, self.sel_end, self.tracks) -- CHECK IF X,Y,ARRANGE VIEW ETC CHANGED IN PROJECT (WOULD BE USED FOR DRAWING ONLY WHEN THERE IS A CHANGE IN THE PROJECT) 
  
  if draw then -- UPDATE ONLY IF THERE ARE CHANGES IN PROJECT (X,Y,SCROLL,HEIGHT,SHIT LIKE THAT)
    local xStart = math.floor(self.sel_start * zoom_lvl) -- convert time to pixel
    local xEnd  = math.floor(self.sel_end * zoom_lvl) -- convert time to pixel 
    w = xEnd - xStart -- CREATE/UPDATE W
    x = xStart - Arr_pixel -- CREATE/UPDATE X 
    if last_tr_y_start >= tr_y_start then -- IF LAST TRACK IS UNDER FIRST TRACK UPDATE H,Y (EXPAND BOTTOM)
      h = last_tr_y_end - tr_y_start -- CREATE/UPDATE H
      y = tr_y_start - y_view_start -- CREATE/UPDATE Y
    else                                  -- IF LAST TRACK IS ABOVE FIRST TRACK UPDATE H,Y (EXPANT TOP)
      h = tr_y_end - last_tr_y_start   -- CREATE/UPDATE H
      y = last_tr_y_start - y_view_start -- CREATE/UPDATE Y
    end
    self:draw(x,y,w,h) -- REDRAW AFTER UPDATE
  end
end

function area_selection:draw(x,y,w,h)
    reaper.JS_Composite(track_window, x,y,w,h, self.bm, 0, 0, 1, 1)
    reaper.JS_Window_InvalidateRect(track_window, 0, 0, W, H, true)
end

local function get_mouse_y_pos_in_track(tr,xV,mX,mY,y_view_start,scroll)
  if not tr then return end
  local tr_n = reaper.GetMediaTrackInfo_Value( tr, "IP_TRACKNUMBER" )
  if tr_n < 0 then return end
  local tYs,tYe = get_track_y_range(y_view_start,scroll,tr) -- GET RANGE OF TRACK UNDER MOUSE CURSOR
  local tr_h = tYe - tYs
  if mX > xV and tYs and (mY >= tYs and mY <= tYe) then -- IF MOUSE IS IN THE TRACK
    local mouse_in = mY - tYs -- GET MOUSE Y IN TRACK(WE WANT NEW RANGE FROM 0 TO ITS HEIGHT
    if mouse_in < tr_h/2 then return true else return false end -- IF MOUSE IS IN UPPER HALF OF THE TRACK RETURN TRUE (WILL USE THIS TO TRIGGER INITIAL AREA SELECTION)
  end  
end

local function has_val(tab, val)
  for i = 1 , #tab do
    local in_table = tab[i]
    if in_table == val then return i end
  end
return false
end

local function has_guid(tab, val)
  for i = 1 , #tab do
    local in_table = tab[i].guid
    if in_table == val then return tab[i] end
  end
return false
end

local function remove_as_from_tbl(tab,val) -- REMOVE AS FROM TABLE ALONG WITH ITS BITMAPS
  for i = #tab , 1, -1 do
    local in_table = tab[i].guid
    if in_table ~= val then
      reaper.JS_Composite_Unlink(track_window,tab[i].bm) -- UNLINK BITMAPS THAT WILL BE DESTROYED
      reaper.JS_LICE_DestroyBitmap(tab[i].bm) -- DESTROY BITMAPS FROM AS THAT WILL BE DELETED
      table.remove(tab,i) -- REMOVE AS FROM TABLE
    end
  end
end

local function make_as(tbl,click)
  local as_tracks, as_sel_start, as_sel_end, as_guid
  
  if tbl[2] < tbl[1] then
    as_sel_start, as_sel_end = tbl[2], tbl[1] -- IF END IS BEFORE START REVERSE VALUES
  else
    as_sel_start, as_sel_end = tbl[1], tbl[2] -- IF END IS AFTER START SEND AS NORMAL
  end
  as_tracks = tbl[3] -- AREA SELECTION TRACKS
  as_guid = tbl[4] -- AREA GUID
  
  -- MAKE NEW AREA CLASS
  if not has_guid(Areas,as_guid) then
    Areas[#Areas+1] = area_selection:new(as_tracks, as_sel_start, as_sel_end, as_guid)
  else
    if click == 1 then  -- IF SHIFT IS NOT DOWN (FOR MAKING MULTI AS)
      if #Areas > 1 then remove_as_from_tbl(Areas,"single") end -- REMOVE ALL OTHER AS
    end
    local cur_area = has_guid(Areas, as_guid) -- IF AS ALREADY EXISTS
    cur_area.sel_start, cur_area.sel_end, cur_area.tracks = as_sel_start, as_sel_end, as_tracks -- UPDATE IT
  end
end

local function mouse_in_selection(m_x, m_y, x_view_start, y_view_start) -- NEED TO FIX
  local AS_mx_in,AS_my_y = m_x - x_view_start, m_y - y_view_start
  if Ain_x >= area_X and Ain_x <= (area_X + area_W)
  and Ain_y >= area_Y and Ain_y <= (area_Y + area_H) then
  return true
  end 
end

local down,hold,down_time
local click_start,click_end
local area_tracks = {} -- TABLE FOR AS TRACKS
local as_guid

--- THIS BELOW COULD BE BETTER WRITTEN
local function mouse_click(click,time,tr,grid,mouse_in) 
  if click == 1 or click == 9 and mouse_in then down = true   
    if not hold then
      click_start = grid or time -- GET TIME WHEN MOUSE IS CLICKED
      if click == 9 then as_guid = reaper.genGuid() elseif click == 1 then as_guid = "single" end
      hold = true
    end 
  end
  if down then
    if not has_val(area_tracks, tr) then area_tracks[#area_tracks+1]=tr  -- add track to table if does not exits
    else
    local last_num = has_val(area_tracks, tr) -- get last track
    if last_num < #area_tracks then table.remove(area_tracks, #area_tracks) end -- if last track is no longer in table remove it
    end
    click_end = grid or time -- GET TIME WHILE MOUSE IS DOWN 
    
    if click_start ~= click_end and #area_tracks ~= 0 then make_as({click_start,click_end,area_tracks,as_guid},click) end -- CREATE NEW AS ONLY IF TIME IS GREATER THAN 0
    
    if click == 0 or click == 8 then 
      down,hold = nil,nil
      click_start,click_end = nil,nil
      area_tracks = {}
    end
  end 
end

--------------------------------------------------------------------------------------------------------
local test_keys = { {0x1B, 'ESC', false, false, true} }
-- FOR TESTING ONLY NEED TO REWRITE IT
local function keyboard()
  local OK, state = reaper.JS_VKeys_GetState()
  for i = 1, #test_keys do
    if state:byte(test_keys[i][1]) ~= 0 then
      local up_time = reaper.time_precise()
      if not test_keys[i][3] then test_keys[i][3] = true -- press
        if test_keys[i][2] == "ESC" then
          remove_as_from_tbl(Areas,"DELETE") -- REMOVE AS FROM TABLE ALONG WITH ITS BITMAPS - 
        end
        test_keys[i][3] = true
      end
      if test_keys[i][5] then test_keys[i][5] = false down_time = reaper.time_precise() end -- release
      if test_keys[i][5] == false then 
        local hold_time = up_time - down_time
        if hold_time > 0.2 then test_keys[i][4] = true end
      end -- hold
    else
      test_keys[i][3] = false
      test_keys[i][4] = false
      test_keys[i][5] = true
    end
  end
end
-------------------------------------------------------------------------------------------------------

local function main()
  local closest_grid
  local window, segment, details = reaper.BR_GetMouseCursorContext()
  local tr = reaper.BR_GetMouseCursorContext_Track()
  local snap = reaper.GetToggleCommandState( 1157 ) 
  ------------------------------------------------------------------------------------------------------------------------------------ 
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, scroll, x_view_start, y_view_start, x_view_end, y_view_end = project_info()
  ------------------------------------------------------------------------------------------------------------------------------------
  local cur_m_x, cur_m_y = reaper.GetMousePosition()
  local m_click = reaper.JS_Mouse_GetState(13) -- INTERCEPT MOUSE CLICK
  local mouse_time_pos = ((cur_m_x - x_view_start ) / zoom_lvl) + Arr_start_time -- NEW
  local mouse_in = get_mouse_y_pos_in_track(tr, x_view_start, cur_m_x, cur_m_y, y_view_start, scroll) -- CHECKS THE MOUSE POSITION IN THE TRACK
  if snap == 1 then closest_grid = reaper.SnapToGrid(0,reaper.BR_GetClosestGridDivision( mouse_time_pos )) else closest_grid = nil end 
   
  mouse_click(m_click, mouse_time_pos, tr, closest_grid, mouse_in, window) -- GET CLICKED TRACKS, MOUSE TIME RANGE  
  
  DRAW_AREA(Areas) -- DRAW THIS BAD BOYS
  
  --if #Areas ~= 0 then AS_MOUSE_IN = mouse_in_selection(cur_m_x, cur_m_y, x_view_start, y_view_start) end -- ADD CHECK IF MOUSE IS IN SOME AS SO IT CAN BE MANIPULATED
 
  keyboard() -- BASIC INPUT EVENT HANDLING (PROBABLY WRONG) PRESS ESC TO REMOVE ALL AS
  
  reaper.defer(main)
end

function DRAW_AREA(tbl)
  for key,area_selection in pairs(tbl) do area_selection:update_xywh() end
end

function exit() -- DESTROY BITMAPS ON REAPER EXIT
  for i = 1, #Areas do
    local bm = Areas[i].bm
    reaper.JS_Composite_Unlink(track_window,bm)
    reaper.JS_LICE_DestroyBitmap(bm)
  end 
  if reaper.ValidatePtr(track_window, "HWND") then 
    reaper.JS_Window_InvalidateRect(track_window, 0, 0, W, H, true) 
  end
end
reaper.atexit(exit)
main()
