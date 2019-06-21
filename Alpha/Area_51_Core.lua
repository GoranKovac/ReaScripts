--package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;" -- GET DIRECTORY FOR REQUIRE
--require("Area_51_Functions") -- AREA FUNCTIONS SCRIPT

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
  local proj_state = reaper.GetProjectStateChangeCount( 0 )
  local zoom_lvl = reaper.GetHZoomLevel() -- HORIZONTAL ZOOM LEVEL
  local Arr_start_time, Arr_end_time = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW
  local Arr_pixel = to_pixel(Arr_start_time,zoom_lvl)-- ARRANGE VIEW POSITION CONVERT TO PIXELS
  local _, scroll, _, _, _ = reaper.JS_Window_GetScrollInfo(track_window, "SB_VERT") -- GET VERTICAL SCROLL
  local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window) -- GET TRACK WINDOW X-Y COORDINATES
  return zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, scroll, x_view_start, y_view_start, x_view_end, y_view_end, proj_state
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

function get_env_y_range(tr, mouse_env)
  if not tr then return end
  local y_start, y_end
  local totalh = 0
  for env_id = 1, reaper.CountTrackEnvelopes(tr) do          
    local env = mouse_env or reaper.GetTrackEnvelope(tr, env_id-1)
    local retval, found = reaper.JS_Window_ListAllChild(main_wnd)
    for adr in found:gmatch("%w+") do
      local handl = reaper.JS_Window_HandleFromAddress(tonumber(adr))
      if reaper.JS_Window_GetLongPtr(handl, "USER") == env then 
        local retval, left, top, right, bottom = reaper.JS_Window_GetRect(handl)
        local env_h = bottom - top
        y_start = top 
        y_end = bottom
        totalh = totalh + env_h
      end
    end
  end
  return y_start, y_end, totalh
end

local function get_track_y_range(y_view_start, scroll, cur_tr)
  local trcount = reaper.GetMediaTrackInfo_Value(cur_tr, "IP_TRACKNUMBER" ) -- WE ONLY COUNT TO CURRENT SELECTED TRACK (SINCE WE ONLY NEED Y-POS OF THAT TRACK)
  local masvis, totalh, idx = reaper.GetMasterTrackVisibility(), y_view_start - scroll , 1 -- VIEWS Y START, SUBTRACTED BY SCROLL POSITION
  if masvis == 1 then totalh = totalh + 5; idx = 0 end -- INCLUDE MASTER TRACK IF VISIBLE -- THIS NEEDS FIXING
  local y_start, y_end, height, offset
  for tr = idx, trcount do
    local track = reaper.CSurf_TrackFromID(tr, false)
    local _, _, Aenv_h = get_env_y_range(track) -- FIND TOTAL ENV HEIGHT TO EXCLUDE IT FROM TRACK
    height = reaper.GetMediaTrackInfo_Value(track, "I_WNDH") -- TRACK HEIGHT 
    y_start = totalh -- TRACK Y START
    y_end = totalh + height - Aenv_h -- EXCLUDE ENVELOPE HEIGHT FROM TRACK IF ENVELOPES ARE VISIBLE
    totalh = (totalh + height)
    if get_track_zoom_offset(track, totalh, height, scroll) then -- IF SCROLLED/ZOOMED ETC
      offset = get_track_zoom_offset(track, totalh, height, scroll) -- GET OFFSET
      totalh = totalh - get_track_zoom_offset(track, totalh, height, scroll) -- UPDATE TRACK TOTAL Y RANGE
    end
  end
  return y_start, y_end, totalh -- RETURN TRACKS Y START & END
end

local prev_start,prev_end
local function check_draw(c_start,c_end)
  if prev_end ~= c_end or prev_start ~= c_start then 
    prev_start, prev_end = c_start, c_end 
    return true
  end
end

local prev_total_pr_h, prev_Arr_end_time, prev_proj_state, last_zoom_lvl
local function status(c_start,c_end) -- needs y_view_start
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, scroll, x_view_start, y_view_start, x_view_end, y_view_end, proj_state = project_info() 
  local cnt_tracks = reaper.CountTracks()
  local last_tr = reaper.GetTrack(0,cnt_tracks-1) -- GET LAST TRACK IN PROJECT
  local _, _, total_pr_h = get_track_y_range(y_view_start,scroll,last_tr) -- GET TOTAL HEIGHTS OF THE PROJECT 
  if prev_Arr_end_time ~= Arr_end_time then -- THIS ONE ALWAYS CHANGES WHEN ZOOMING IN OUT
    prev_Arr_end_time = Arr_end_time
    return true
  elseif last_zoom_lvl ~= zoom_lvl then 
    last_zoom_lvl = zoom_lvl
    return true
  elseif prev_proj_state ~= proj_state then
    prev_proj_state = proj_state
    return true
  elseif prev_total_pr_h ~= total_pr_h then -- IF SOME TRACK UPDATEED ITS FINAL HEIGHT (IT LOOKS LAST TRACK SINCE THAT ONE IS ALWAYS UPDATED IF TRACK BELOW IT CHANGED HEIGHT)
    prev_total_pr_h = total_pr_h
    return true
  end 
end

local area_selection = {}
function area_selection:new(as_tracks, as_envs, as_sel_start, as_sel_end, as_guid)
  local elm = {}
  elm.bm, elm.guid = reaper.JS_LICE_CreateBitmap(true, 1, 1) , as_guid
  reaper.JS_LICE_Clear(elm.bm, 0x33000055)
  elm.tracks, elm.envs, elm.sel_start, elm.sel_end = as_tracks, as_envs, as_sel_start, as_sel_end
  setmetatable(elm, self)
  self.__index = self 
  return elm
end

function area_selection:update_xywh()
  local x, y, w, h
  local tr_y_start, tr_y_end,last_tr_y_start, last_tr_y_end, env_y_start, env_y_end, last_env_y_start,last_env_y_end
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, scroll, x_view_start, y_view_start, x_view_end, y_view_end = project_info() 
  
  if self.tracks then
    tr_y_start,tr_y_end = get_track_y_range(y_view_start,scroll,self.tracks[1])
    last_tr_y_start, last_tr_y_end = get_track_y_range(y_view_start,scroll,self.tracks[#self.tracks])
    y = (last_tr_y_end > tr_y_start) and tr_y_start or last_tr_y_start
    h = (last_tr_y_end > tr_y_start) and last_tr_y_end - tr_y_start or tr_y_end - last_tr_y_start
  end
  
  if self.envs then
    env_y_start,env_y_end =  get_env_y_range(reaper.Envelope_GetParentTrack(self.envs[1]),self.envs[1]) 
    last_env_y_start,last_env_y_end = get_env_y_range(reaper.Envelope_GetParentTrack(self.envs[#self.envs]),self.envs[#self.envs]) 
    y = (last_env_y_end > env_y_start) and env_y_start or last_env_y_start
    h = (last_env_y_end > env_y_start) and last_env_y_end - env_y_start or env_y_end - last_env_y_start
  end
  
  if self.tracks and self.envs then
    y = (tr_y_start < env_y_start) and tr_y_start or env_y_start
    h = (last_tr_y_end > last_env_y_end) and last_tr_y_end - y or last_env_y_end - y 
  end
  
  y = y - y_view_start
    
  local xStart = math.floor(self.sel_start * zoom_lvl) -- convert time to pixel
  local xEnd  = math.floor(self.sel_end * zoom_lvl) -- convert time to pixel 
  w = xEnd - xStart -- CREATE/UPDATE W
  x = xStart - Arr_pixel -- CREATE/UPDATE X 
  
  self:draw(x,y,w,h) -- REDRAW AFTER UPDATE
end
function area_selection:draw(x,y,w,h)
  reaper.JS_Composite(track_window, x,y,w,h, self.bm, 0, 0, 1, 1)
  reaper.JS_Window_InvalidateRect(track_window, 0, 0, W, H, true)
end

local function get_mouse_y_pos_in_track(tr,xV,mX,mY,y_view_start,scroll,m_env)
  local tYs, tYe
  if not tr then return end
  if reaper.GetMediaTrackInfo_Value( tr, "IP_TRACKNUMBER" ) < 0 then return end -- EXCLUDE MASTER
  tYs, tYe = get_track_y_range(y_view_start, scroll, tr) -- GET RANGE OF TRACK UNDER MOUSE CURSOR  ------ FIX THIS SHIT HERE
  if m_env then tYs, tYe = get_env_y_range(tr, m_env) end                                              ------ FIX THIS SHIT HERE
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

function check_reverse(val1, val2)
  if val2 < val1 then
    return val2, val1 -- RETURN REVERSE
  else
    return val1, val2 -- RETURN NOTMAL
  end
end

local function make_as(tbl,click)
  local as_sel_start, as_sel_end = check_reverse(tbl[1], tbl[2])
  local as_tracks = tbl[3] -- AREA SELECTION TRACKS
  local as_envs = tbl[4] -- AREA SELECTION TRACKS
  local as_guid = tbl[5] -- AREA GUID 
  
  if #as_tracks == 0 then as_tracks = nil end
  if #as_envs == 0 then as_envs = nil end
  -- MAKE NEW AREA CLASS
  if not has_guid(Areas,as_guid) then
    Areas[#Areas+1] = area_selection:new(as_tracks, as_envs, as_sel_start, as_sel_end, as_guid)
  else
    if click == 1 then  -- IF SHIFT IS NOT DOWN (FOR MAKING MULTI AS)
      if #Areas > 1 then remove_as_from_tbl(Areas,"single") end -- REMOVE ALL OTHER AS -- FUNCTION REMOVES EVERYTHING THAT DOES NOT THIS NAME
    end
    local cur_area = has_guid(Areas, as_guid) -- IF AS ALREADY EXISTS
    cur_area.sel_start, cur_area.sel_end, cur_area.tracks, cur_area.envs = as_sel_start, as_sel_end, as_tracks, as_envs -- UPDATE IT
  end
end

local function mouse_in_as(m_tr, m_env, m_time) -- RETURN GUID OF AS UNDER MOUSE CURSOR
  for i = 1, #Areas do
    if m_time >= Areas[i].sel_start and m_time <= Areas[i].sel_end then
      for j = 1, #Areas[i].tracks do
        local as_tr = Areas[i].tracks[j]
        if as_tr == m_tr then return Areas[i] end
      end
    end
  end
end

local area_tracks = {} -- TABLE FOR AS TRACKS
local area_envs = {} -- TABLE FOR AS TRACKS
local as_guid
local last_env, last_env_tr
local function get_range_info(click_start, click_end, guid, tr, m_env, click) -- I AM SORRY TO ANYONE THAT READS THIS COMMENTS BELLOW, I'M REALLY BAD AT EXPLINING STUFF (LOGIC IS GOOD)
  if not tr then return end                                                   -- BASICALLY THIS SHIT BELLOW ADDS REMOVES TRACKS AND EVELOPES
  local last_env_num, last_num                                                -- REMOVING ENVELOPES WERE LITTLE HARD SINCE WHEN YOU ARE NOT ON THEM IT RETURNS TO TRACK
  if m_env then                                                                -- SO THERE IS CHECKING IS IT ON NEW TRACK AND COMPARES LAST ENVELOPE PARENT OR LAST ENVELOPE
    last_env = m_env                                                          -- IF WE PASSED ALL ANVELOPES AND ENTERED NEW TRACK SHIT BEGINS
    last_env_tr = reaper.Envelope_GetParentTrack(m_env)                       -- IT WOULD NOT REMOVE LAST TRACK UNLESS MOUSE IS ON TRACK (SO ENVELOPES ARE CONSIDERED AS TRACK)
    if not has_val(area_envs, m_env) then area_envs[#area_envs+1] = m_env;    -- OR IT WOULD NOT REMOVE LAST ENVELOPE (IF WE ENTERED NEW TRACK ENVELOPES)
    else                                                                      -- ITS SOME VOODOO SHIT I CANT EXPLAIN IT BUT THE LOGIC IS ALMOST THERE :), IT TOOK ME 3 GODDAMN DAYS
      local last_env_num = has_val(area_envs, m_env) -- get last ENV          
      if last_env_num < #area_envs then table.remove(area_envs, #area_envs) -- if last ENV is no longer in table remove it 
      elseif last_env_tr ~= area_tracks[#area_tracks] then table.remove(area_tracks, #area_tracks) -- IF WE PASSED ALL ENVELOPES AND ENTERED NEW TRACK, WHEN RETURNING TO PREVIOUS TRACK ENVELOPES DELETE TRACK THAT WAS BELOW IT (IT WOULD NOT REMOVE TRACK UNLESS MOUSE IS SPECIFICALLY ON TRACK) 
      end
    end
  elseif tr and not m_en then  
    if not has_val(area_tracks, tr) then area_tracks[#area_tracks+1] = tr
    else
      last_num = has_val(area_tracks, tr) -- get last track
      if last_num < #area_tracks then table.remove(area_tracks, #area_tracks) -- if last track is no longer in table remove it
      elseif last_env_tr == tr and last_env == area_envs[#area_envs] then table.remove(area_envs, #area_envs) -- IF WE PASSED ALL ENVELOPES AND ENTERED NEW TRACK, WHEN RETURNING TO PREVIOUS TRACK TO ENVELOPES DELETE LAST ENVELOPE (WOULD NOT REMOVE ENVELOPES IF WE ENTERED SECOND TRACK ENVELOPES) 
      end                                                -- IF THIS TRACK IS NEW (DOES NOT ALREADY EXIST (not has_val(area_tracks, tr)) 
    end
  elseif not tr then
    area_tracks = {} 
  end 
  
  if click_start ~= click_end then
    drawing = check_draw(click_start,click_end)
    make_as({click_start,click_end,area_tracks,area_envs,as_guid},click,m_env)
  end
end

--- THIS BELOW COULD BE BETTER WRITTEN
local down,hold
local click_start,click_end
local function mouse_click(click, time, tr, grid, mouse_in , m_env)
  if block then return end 
  if (click == 1 or click == 9) and mouse_in then down = true
    if not hold then
      click_start = grid or time -- GET TIME WHEN MOUSE IS CLICKED
      if click == 9 then as_guid = reaper.genGuid() elseif click == 1 then as_guid = "single" end
      hold = true
    end 
  end
  if down then
    click_end = grid or time -- GET TIME WHILE MOUSE IS DOWN   
    get_range_info(click_start, click_end, as_guid, tr, m_env, click)
    if click == 0 or click == 8 then -- RESET EVERYTHING WHEN CLICK IS DOWN
      down,hold = nil,nil
      click_start, click_end = nil, nil
      drawing = nil
      check = nil 
      area_tracks = {}
      area_envs = {}
    end
  end 
end

local vk = {{code = 0x1B, name = 'ESC', press = false, hold = false, release = true}}
function keys() 
  local OK, state = reaper.JS_VKeys_GetState()
  for i = 1, #vk do
    if state:byte(vk[i].code) ~= 0 then 
      if not vk[i].press then vk[i].press = true --end -- PRESS
        if vk[i].name == "ESC" then remove_as_from_tbl(Areas,"DELETE") end
      end
    else
      vk[i].press = false
      vk[i].hold = false
      vk[i].release = true
      key_status = nil
    end
  end
end

local cur_as,cur_z
local function resize_as(AS_AT_MOUSE, mouse_time_pos, click, cz) 
  if cz == "CENTER" then return end
  local range = 2
  if click == 1 then
    if not cur_z then cur_z = cz; cur_as = AS_AT_MOUSE end
    if not cur_as then return end
    check = true
    block = true 
    if cur_z == "LEFT" then cur_as.sel_start = mouse_time_pos
    elseif cur_z == "RIGHT" then cur_as.sel_end = mouse_time_pos 
    end
  else
    cur_z, cur_as, block = nil,nil,nil
  end
end

function as_zones(AS_AT_MOUSE,m_time,mouse_in) -- GET AS ZONE PART (LEFT - CENTER - RIGHT)
  local range = 2
  if AS_AT_MOUSE and not mouse_in and not block then
    if (m_time - AS_AT_MOUSE.sel_start) < range then zone = "LEFT"
    elseif (AS_AT_MOUSE.sel_end - m_time) < range then zone = "RIGHT"
    elseif (m_time - AS_AT_MOUSE.sel_start) > range and (AS_AT_MOUSE.sel_end - m_time) > range then zone = "CENTER"
    end
    return zone
  end
end

local function main()
  local closest_grid
  local window, segment, details = reaper.BR_GetMouseCursorContext() 
  local tr_x, tr_y = reaper.GetMousePosition()
  local tr = reaper.GetTrackFromPoint(tr_x,tr_y)
  local mouse_env, _ = reaper.BR_GetMouseCursorContext_Envelope()
  local snap = reaper.GetToggleCommandState( 1157 ) 
  ------------------------------------------------------------------------------------------------------------------------------------  
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, scroll, x_view_start, y_view_start, x_view_end, y_view_end = project_info()
  ------------------------------------------------------------------------------------------------------------------------------------
  local cur_m_x, cur_m_y = reaper.GetMousePosition()
  local m_click = reaper.JS_Mouse_GetState(13) -- INTERCEPT MOUSE CLICK
  local mouse_time_pos = ((cur_m_x - x_view_start ) / zoom_lvl) + Arr_start_time -- NEW
  local mouse_in = get_mouse_y_pos_in_track(tr, x_view_start, cur_m_x, cur_m_y, y_view_start, scroll, mouse_env) -- CHECKS THE MOUSE POSITION IN THE TRACK
  if snap == 1 then closest_grid = reaper.SnapToGrid(0,reaper.BR_GetClosestGridDivision( mouse_time_pos )) else closest_grid = nil end 
  --local AS_AT_MOUSE = mouse_in_as(tr, mouse_env, mouse_time_pos) 
  
  mouse_click(m_click, mouse_time_pos, tr, closest_grid, mouse_in, mouse_env) -- GET CLICKED TRACKS, MOUSE TIME RANGE 
  
  --cur_zone = as_zones(AS_AT_MOUSE,mouse_time_pos,mouse_in) 
  
  --resize_as(AS_AT_MOUSE, mouse_time_pos, m_click, cur_zone)
  
  DRAW_AREA(Areas) -- DRAW THIS BAD BOYS
  
  keys()
  
  reaper.defer(main)
end

function DRAW_AREA(tbl)
  if status() or drawing then -- DRAW ONLY WHEN THERE IS CHANGE (project x,y changed or we are drawing new AS)
    for key,area_selection in pairs(tbl) do area_selection:update_xywh() end
  end
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
