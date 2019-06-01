package.path    = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;"      -- GET DIRECTORY FOR REQUIRE
package.cursor  = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .. "Cursors\\"  -- GET DIRECTORY FOR CURSORS

require("Area51/Area_51_class")                                         -- AREA FUNCTIONS SCRIPT
require("Area51/Area_51_functions")                                     -- AREA CLASS SCRIPT
require("Area51/Area_51_input")                                         -- AREA INPUT HANDLING/SETUP

local main_wnd        = reaper.GetMainHwnd()                            -- GET MAIN WINDOW
track_window    = reaper.JS_Window_FindChildByID(main_wnd, 1000)  -- GET TRACK VIEW
local track_window_dc = reaper.JS_GDI_GetWindowDC( track_window )
local mixer_wnd       = reaper.JS_Window_Find("mixer", true)            -- GET MIXER -- tHIS NEEDS TO BE CONVERTED TO ID , AND I STILL DO NOT KNOW HOW TO FIND THEM

local Areas_TB = {}
--Menu_TB  = {Menu:new(0, 0, 0, 0, "H", nil, nil, nil, 8)}
local active_as

local Key_TB = {}

function msg(m)
  reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local TBH
local function GetTracksXYH_Info()
  TBH = {}
  local array = reaper.new_array({}, 1000)
  reaper.JS_Window_ArrayAllChild(reaper.GetMainHwnd(), array)
  local t = array.table()
  
  for i, adr in ipairs(t) do
    local handl = reaper.JS_Window_HandleFromAddress(adr)
    local track = reaper.JS_Window_GetLongPtr(handl, "USER")
    local vis   = reaper.JS_Window_IsVisible(handl)
    if reaper.JS_Window_GetParent(reaper.JS_Window_GetParent(handl)) ~= mixer_wnd then
      
      if reaper.ValidatePtr(track, "MediaTrack*") or reaper.ValidatePtr(track, "TrackEnvelope*") then
        local _, _, top, _, bottom = reaper.JS_Window_GetClientRect(handl)
        TBH[track] = {t = top, b = bottom, h = bottom - top}
      end 
    end
  end
  
end

function Project_info()
  local proj_state  = reaper.GetProjectStateChangeCount( 0 )                                            -- PROJECT STATE
  local zoom_lvl    = reaper.GetHZoomLevel()                                                            -- HORIZONTAL ZOOM LEVEL
  local _, scroll, _, _, scroll_b     = reaper.JS_Window_GetScrollInfo(track_window, "SB_VERT")         -- GET VERTICAL SCROLL
  local Arr_start_time, Arr_end_time  = reaper.GetSet_ArrangeView2(0, false, 0, 0)                      -- GET ARRANGE VIEW
  local Arr_pixel                     = math.ceil(Arr_start_time * zoom_lvl)                            -- ARRANGE VIEW POSITION CONVERT TO PIXELS 
  local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window)  -- GET TRACK WINDOW X-Y COORDINATES
  
  return zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, proj_state, scroll, scroll_b
end

local prev_total_pr_h, prev_Arr_end_time, prev_proj_state, last_scroll, last_scroll_b, last_pr_t, last_pr_h
function Status()                                                  -- THIS IS USED TO CHECK CHANGES IN THE PROJECT FOR DRAWING
  local last_pr_tr = reaper.GetTrack(0,reaper.CountTracks(0)-1)
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, proj_state, scroll, scroll_b = Project_info() 
  
  if prev_Arr_end_time ~= Arr_end_time then                        -- THIS ONE ALWAYS CHANGES WHEN ZOOMING IN OUT
    prev_Arr_end_time = Arr_end_time
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
  elseif last_pr_tr then                                            -- LAST TRACK ALWAYS CHANGES HEIGHT WHEN OTHER TRACK RESIZE
    if TBH[last_pr_tr].h ~= last_pr_h or TBH[last_pr_tr].t ~= last_pr_t then
      last_pr_h = TBH[last_pr_tr].h
      last_pr_t = TBH[last_pr_tr].t
      return true
    end 
  end
end

local function Has_val(tab, val, guid)
  local val_n = guid and guid or val
  
  for i = 1 , #tab do
    local in_table = guid and tab[i].guid or tab[i]
    if in_table == val_n then return tab[i] end
  end
end

local function GetTrackFromMouseRange(t, b, tr)
  local range_tracks = {}
  local trackview_window
  local _, _, arr_top = reaper.JS_Window_GetRect(track_window)
  local window        = reaper.JS_Window_GetRelated(track_window, "NEXT")
  
  while window do
    local _, _, top = reaper.JS_Window_GetRect(window)
    if top == arr_top then trackview_window = reaper.JS_Window_GetRelated(window, "CHILD") end
    window          = reaper.JS_Window_GetRelated(window, "NEXT")
  end 
    -- loop over track and envelope windows 
  local window = reaper.JS_Window_GetRelated(trackview_window, "CHILD")
  while window do
    if reaper.JS_Window_IsVisible(window) then
      -- windows visible in arrange view only
      local _, _, top, _, bottom = reaper.JS_Window_GetRect(window)
      if top >= t and bottom <= b then -- IF TRACK IS IN THE MOUSE ZONE RANGE 
        local pointer = reaper.JS_Window_GetLongPtr(window, "USERDATA")
        if reaper.ValidatePtr(pointer, "MediaTrack*") then
          if not Has_val(range_tracks, pointer) then range_tracks[#range_tracks+1] = {track = pointer} end -- ADD TRACKS TO TABLE IF THEY ARE NOT ALREADY THERE
        elseif  reaper.ValidatePtr(pointer, "TrackEnvelope*") then
          if not Has_val(range_tracks, pointer) then range_tracks[#range_tracks+1] = {track = pointer} end
        end
      end
    end
  window = reaper.JS_Window_GetRelated(window, "NEXT")
  end
  return range_tracks
end

local function GetTrackFromPoint(x, y)
  local trackview_window
  local window_under_mouse = reaper.JS_Window_FromPoint(x, y)
  --if window_under_mouse ~= track_window then return end            -- DO NOT ALLOW DRAWING OVER WINDOW THAT IS NOT ARRANGE
  local _, _, arr_top = reaper.JS_Window_GetRect(track_window)
  local window        = reaper.JS_Window_GetRelated(track_window, "NEXT")
  
  while window do
    local _, _, top = reaper.JS_Window_GetRect(window)
    if top == arr_top then trackview_window = reaper.JS_Window_GetRelated(window, "CHILD") end
    window          = reaper.JS_Window_GetRelated(window, "NEXT")
  end
    -- loop over track and envelope windows
  local window = reaper.JS_Window_GetRelated(trackview_window, "CHILD")
  while window do
    if reaper.JS_Window_IsVisible(window) then
      -- windows visible in arrange view only
      local _, _, top, _, bottom = reaper.JS_Window_GetRect(window)
      local last_tr = reaper.GetTrack(0,reaper.CountTracks(0)-1)
      local ltr_t, ltr_b = TBH[last_tr].t,TBH[last_tr].b
      if top <= y and bottom > y then -- IF MOUSE IS IN THE TRACK RANGE
        local pointer = reaper.JS_Window_GetLongPtr(window, "USERDATA")
        if reaper.ValidatePtr(pointer, "MediaTrack*") then
          if reaper.GetMediaTrackInfo_Value(pointer, "I_FOLDERDEPTH") == 1 then 
                _, _, bottom = get_folder(pointer)
          end
          return pointer, top, bottom  --> Track, segment
        elseif  reaper.ValidatePtr(pointer, "TrackEnvelope*") then
          return pointer, top, bottom --> Envelope, segment
        end
      elseif CREATING and y <= top then return reaper.GetTrack(0,0), top, bottom   -- RETURN FIRST TRACK IF STARTED CREATING AS AND GONE ABOVE RULLER
      elseif CREATING and y >= ltr_b then return last_tr, ltr_t, ltr_b               -- RETURN LAST TRACK IF STARTED CREATING AS AND GONE BELOW LAST TRACK
      end
    end
  window = reaper.JS_Window_GetRelated(window, "NEXT") --> window or nil
  end
end

function GetTrackTBH(tbl)
  local total_h = 0
  local t, b, h, nt
  
  for i = #tbl , 1, -1 do                                              -- NEEDS TO BE REVERSED OR IT DRAWS WEIRD SHIT
    local track = tbl[i].track
    t, b, h = TBH[track].t, TBH[track].b, TBH[track].h
    total_h = total_h + h
    if t ~= 1984 then nt = t else total_h = total_h - h end            -- NEED TO FIX THIS,RESOLUTION DEPENDANT        -- FIX FOR WHEN THE TOP OF AS IS OUT PROJECT TOP IT WOULD EXPAND THE BOTTOM WHEN THE TOP TRACK IS OUT OF VIEW
  end
  
  if total_h == 0 then nt = 0 end
  
  return nt, total_h, b
end

local function GetTrackZoneInfo(tr, m_y)
  if tr == nil then return end
  
  local tr_y, tr_h      = TBH[tr].t, TBH[tr].h
  local mouse_in_track  = (m_y - tr_y)
  
  if mouse_in_track < tr_h / 2 then return true else return false end
end

local function Check_top_bot(top_start, top_end, bot_start, bot_end)            -- CHECK IF VALUES GOT REVERSED 
  if bot_end <= top_start then return bot_start, top_end else return top_start, bot_end end
end

local function Check_left_right(val1, val2)                                     -- CHECK IF VALUES GOT REVERSED
  if val2 < val1 then return val2, val1 else return val1, val2 end
end

local prev_s_start, prev_s_end, prev_r_start, prev_r_end
local function Check_change(s_start, s_end, r_start, r_end)
  if s_start == s_end then return end
  
  if prev_s_end ~= s_end or prev_s_start ~= s_start then 
    prev_s_start, prev_s_end = s_start, s_end
    return "TIME X"
  elseif prev_r_start ~= r_start or prev_r_end ~= r_end then 
    prev_r_start, prev_r_end = r_start, r_end 
    return "RANGE Y"
  end
  
end

function GetRangeInfo(tbl, as_start, as_end)
  for i = 1, #tbl do
    if      reaper.ValidatePtr(tbl[i].track, "MediaTrack*")    then
      tbl[i].items           = get_items_in_as(tbl[i].track, as_start, as_end)        -- TRACK MEDIA ITEMS
      --tbl.info[i].env_points  = get_env(as_tr, as_start, as_end)                  -- FOR HIDDEN TRACKS
    elseif  reaper.ValidatePtr(tbl[i].track, "TrackEnvelope*") then
      local retval, env_name      = reaper.GetEnvelopeName(tbl[i].track)
      tbl[i].env_name        = env_name                                        -- ENVELOPE NAME
      tbl[i].env_points      = get_as_tr_env_pts(tbl[i].track, as_start, as_end)      -- ENVELOPE POINTS
      tbl[i].AIs             = get_as_tr_AI(tbl[i].track, as_start, as_end)           -- AUTOMATION ITEMS
    end
  end
  return tbl
end

local function RemoveAsFromTable(tab, val)
  for i = #tab , 1, -1 do
    local in_table = tab[i].guid
    
    if in_table ~= val then                                     -- REMOVE ANY AS THAT HAS DIFFERENT GUID
      reaper.JS_LICE_DestroyBitmap(tab[i].bm)                   -- DESTROY BITMAPS FROM AS THAT WILL BE DELETED
      table.remove(tab, i)                                      -- REMOVE AS FROM TABLE
    end
  end
  
  reaper.JS_Composite_Unlink(track_window,  m_bm)               -- ONLY REMOVE MENU HIGHLIHGT FROM SCREEN
  --reaper.JS_Composite_Unlink(track_window,  Menu_TB[1].bm)      -- ONLY REMOVE MENU BAR FROM SCREEN
  active_as = Areas_TB[#Areas_TB]
end
local function CreateArea(x, y, w, h, guid, time_start, time_end)
  if not Has_val(Areas_TB, nil, guid) then
    Areas_TB[#Areas_TB+1] = AreaSelection:new(x, y, w, h, guid, time_start, time_end, {}) -- CREATE NEW CLASS ONLY IF DOES NOT EXIST
    active_as = Areas_TB[#Areas_TB]
  else
    --if m_state == 1 then                                                                    -- IF SHIFT IS NOT DOWN (FOR MAKING MULTI AS)
      --if #Areas_TB > 1 then RemoveAsFromTable(Areas_TB,"single") end                        -- REMOVE ALL OTHER AS
    --end
    Areas_TB[#Areas_TB].time_start, Areas_TB[#Areas_TB].time_end, Areas_TB[#Areas_TB].x, Areas_TB[#Areas_TB].y , Areas_TB[#Areas_TB].w, Areas_TB[#Areas_TB].h = time_start, time_end, x, y, w, h -- UPDATE IT
  end
end

local env_ghosts
local function GetEnvGhosts(tbl)
    local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, state, scroll = Project_info()  
      
    env_ghosts = {}
    for a = 1, #Areas_TB do
    local tbl = Areas_TB[a]
      for i = 1, #tbl.info do 
        if tbl.info[i].env_points then
          local as_tr               = tbl.info[i].track
          local env_t, env_h, env_b = TBH[as_tr].t, TBH[as_tr].h, TBH[as_tr].b
          local bm = reaper.JS_LICE_CreateBitmap(true, math.ceil((tbl.time_end - tbl.time_start) * zoom_lvl), env_h)
          local dc = reaper.JS_LICE_GetDC(bm)
          
          reaper.JS_GDI_Blit(
                              dc, 0, 0, track_window_dc, 
                              math.floor(tbl.time_start * zoom_lvl) - Arr_pixel, 
                              (env_t - y_view_start), 
                              math.floor((tbl.time_end - tbl.time_start) * zoom_lvl), 
                              env_h
                            )
          
          env_ghosts[#env_ghosts+1] =  {bm =  bm , dc = dc, p = tbl.time_start ,h = env_h, l = math.floor((tbl.time_end - tbl.time_start) * zoom_lvl), track = as_tr, env = tbl.info[i].env_name}
        end
      end
    end
end

local item_ghosts
local function GetItemsGhosts(tbl)
    local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, state, scroll = Project_info()  
    item_ghosts = {}
    for a = 1, #Areas_TB do
      local tbl = Areas_TB[a]
      for i = 1, #tbl.info do
        if tbl.info[i].items then
          local as_tr = tbl.info[i].track
          for j =  1, #tbl.info[i].items do
            local as_item = tbl.info[i].items[j]
            local item_t, item_h, item_b  = TBH[as_tr].t, TBH[as_tr].h, TBH[as_tr].b
            local item_bar                = (item_h > 42) and 15 or 0
            local item_start, item_lenght = item_blit(as_item, tbl.time_start, tbl.time_end)
            local bm = reaper.JS_LICE_CreateBitmap(true, math.ceil(item_lenght * zoom_lvl), item_h)
            local dc = reaper.JS_LICE_GetDC(bm)
            
            reaper.JS_GDI_Blit(
                                dc, 0, 0, track_window_dc,                        -- SOURCE - DESTINATION
                                math.ceil(item_start    * zoom_lvl) - Arr_pixel,  -- X
                                ((item_t       + item_bar) - y_view_start),       -- Y
                                math.ceil(item_lenght   * zoom_lvl),              -- W
                                item_h - 19                                       -- H (-19 TO COMPENSATE ITEM BAR REMOVING)
                              )                                  
            
            item_ghosts[as_item] =  {bm =  bm , dc = dc, h = item_h, l = math.ceil(item_lenght   * zoom_lvl), track = as_tr, item = as_item}
          end
        end
      end
    end
end

local function CreateAreaFromCoordinates(m_r_t, m_r_b)
  if not mouse_ort or not m_r_t then return end
  local as_top,   as_bot    = Check_top_bot(mouse_ort, mouse_orb, m_r_t, m_r_b)   -- RANGE ON MOUSE CLICK HOLD AND RANGE WHILE MOUSE HOLD
  local as_left,  as_right  = Check_left_right(mouse_ot, m_t)                     -- CHECK IF START & END TIMES ARE REVERSED
  local x_s,      x_e       = Check_left_right(mouse_ox, m_x)                     -- CHECK IF X START & END ARE REVERSED
  
  if m_state &1==1 then
    if copy then copy_mode() end                                      -- DISABLE COPY MODE IF ENABLED
    if last_mouse_cap &1==0 then                                      -- IF LAST MOUSE CLICK WAS DOWN
      if Shift then guid = reaper.genGuid() else guid = "single" end
    end
    
    DRAWING = Check_change(as_left, as_right, as_top, as_bot)
    
    if DRAWING then
      CREATING = true
      local x, y, w, h = x_s, as_top, x_e - x_s, as_bot - as_top
      CreateArea(x, y, w, h, guid, as_left, as_right)
    end
      
  elseif m_state &1== 0 and last_mouse_cap &1==1 and CREATING then
    local tracks = GetTrackFromMouseRange(as_top, as_bot)
    local info   = GetRangeInfo(tracks, as_left,  as_right) 
    Areas_TB[#Areas_TB].info = info
    GetItemsGhosts() 
    GetEnvGhosts()
    CREATING, guid = nil, nil
  end 
end

function GetTrackOffset(as_tr, m_tr, first_tr, last_tr)
  if not m_tr then return end
   
  if reaper.ValidatePtr(m_tr,     "TrackEnvelope*") then m_tr     = reaper.Envelope_GetParentTrack( m_tr )      end
  if reaper.ValidatePtr(as_tr,    "TrackEnvelope*") then as_tr    = reaper.Envelope_GetParentTrack( as_tr )     end
  if reaper.ValidatePtr(first_tr, "TrackEnvelope*") then first_tr = reaper.Envelope_GetParentTrack( first_tr )  end
  if reaper.ValidatePtr(last_tr,  "TrackEnvelope*") then last_tr  = reaper.Envelope_GetParentTrack( last_tr )   end 
  
  local first_tr_id = reaper.CSurf_TrackToID( first_tr, false )
  local last_tr_id  = reaper.CSurf_TrackToID( last_tr,  false )
  local m_tr_id     = reaper.CSurf_TrackToID( m_tr,     false )   -- MOUSE TRACK
  local as_tr_id    = reaper.CSurf_TrackToID( as_tr,    false )
  
  local offset_first_tr = (m_tr_id - first_tr_id)                                         -- GET OFFSET BETWEEN THE FIRST TRACK IN SELECTION AN MOUSE TRACK
  local offset_below    = (last_tr_id - reaper.CountTracks(0)) + offset_first_tr > 0 and (last_tr_id  - reaper.CountTracks(0)) + offset_first_tr or nil
                                                                                          -- GET HOW MANY TRACKS IS THE LAST TRACK IN SELECTION BELOW PROJECTS LAST TRACK 
  local offset_tr = reaper.CSurf_TrackFromID((as_tr_id + offset_first_tr), false)
  
  local offset_h  = 0
  
  if as_tr_id + offset_first_tr > reaper.CountTracks(0) then                              -- IF NEW TRACK POSITION IS BELOW LAST TRACK
    offset_tr = reaper.CSurf_TrackFromID(reaper.CountTracks(0),false)                     -- USE THAT TRACK AS REFERENCE
    local offset_below_cur_tr  = ((as_tr_id )  - reaper.CountTracks(0)) + offset_first_tr -- GET HOW MANY TRACKS IS CURRENT ONE BELOW LAST TRACK
    offset_h = TBH[offset_tr].h * offset_below_cur_tr                                     -- MULTIPLY ITS HEIGHT (WE WILL USE THIS FOR OFFSETING ITEM GHOSTS
  end
  
  return offset_below, offset_tr, offset_h
end

function GetEnvOffset_MatchCriteria(tr, env, src_tr, env_num) 
  local retval, m_env_name, m_env_par
  local env_t, env_b, env_h, f_env
  local window, segment, details  = reaper.BR_GetMouseCursorContext()
  local m_env, AtakeEnvelope      = reaper.BR_GetMouseCursorContext_Envelope()
  local sec_env_par               = reaper.Envelope_GetParentTrack( src_tr )
  
  if m_env then
    m_env_par           = reaper.Envelope_GetParentTrack( m_env )
    retval, m_env_name  = reaper.GetEnvelopeName(m_env)
  end
    
  for i = 1, reaper.CountTrackEnvelopes( tr ) do
    local tr_env            = reaper.GetTrackEnvelope( tr, i-1 )
    local retval, env_name  = reaper.GetEnvelopeName(tr_env)
    
    if m_env_name == env_name then 
      local num         = reaper.CountTrackEnvelopes( tr ) - i
      local mouse_off   = reaper.CountTrackEnvelopes( tr ) - ((num - env_num) + 2)
      local tr_env_off  = reaper.GetTrackEnvelope( tr, mouse_off )
      if tr_env_off then                      -- RETURN ENVELOPE UNDER MOUSE OFFSETED (OVERRIDE MODE)
        --if #Areas_TB > 1 then return end
        env_t,env_b,env_h, f_env = TBH[tr_env_off].t, TBH[tr_env_off].b, TBH[tr_env_off].h, tr_env_off
      end
    elseif not m_env and env_name == env then -- RETURN NORMAL ENVELOPE WITH SOURCE POSSITION (MATCH CRITERIA)
      env_t,env_b,env_h, f_env = TBH[tr_env].t, TBH[tr_env].b, TBH[tr_env].h, tr_env
    end
  end
  return env_t,env_b,env_h, f_env
end

local function DrawItemGhosts(tbl, mouse_time_pos, tr)
  if not tr then return end
    local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, state, scroll = Project_info()  
    local first_as_tr_in_all = find_highest_tr()
    
    for a = 1, #Areas_TB do
      local tbl = Areas_TB[a]  
       
      local pos = mouse_time_pos
      if a > 1 then pos = pos + (tbl.time_start - Areas_TB[1].time_start) end -- IF THERE ARE MULTIPLE SS INCREASE THE LENGHT FROM MOUSE POS TO THE NEXT AS
      
      for i = 1, #tbl.info do
        if tbl.info[i].items then
          local _, off_tr, off_h = GetTrackOffset(tbl.info[i].track, tr, first_as_tr_in_all, tbl.info[#tbl.info].track)
          local item_t, item_h, item_b  = TBH[off_tr].t + off_h, TBH[off_tr].h, TBH[off_tr].b
          for j = 1, #tbl.info[i].items do
            local as_item = tbl.info[i].items[j]
            local item_start, item_lenght = item_blit(as_item, tbl.time_start, tbl.time_end, pos)
            
            reaper.JS_Composite(
                                 track_window, 
                                 math.ceil(item_start * zoom_lvl) - Arr_pixel, -- X
                                 item_t - y_view_start + 0,                    -- Y
                                 math.ceil(item_lenght * zoom_lvl),            -- W
                                 item_h,                                       -- H
                                 item_ghosts[as_item].bm,                                      
                                 0,                                            -- x
                                 0,                                            -- y
                                 item_ghosts[as_item].l,                       -- w
                                 item_ghosts[as_item].h - 19                   -- h
                               )  
          end
        end
      end
    end
  refresh_reaper()
end


local function DrawEnvGhosts(tbl, mouse_time_pos, tr)
  if not tr then return end
    local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, state, scroll = Project_info()  
    local first_as_tr_in_all = find_highest_tr()
    
      for a = 1, #Areas_TB do
        local tbl = Areas_TB[a] 
        
        for i = 1, #tbl.info do
          if tbl.info[i].env_points and not tbl.info[i].items then
            local as_tr = tbl.info[i].track
            local _, off_tr           = GetTrackOffset(tbl.info[i].track, tr, first_as_tr_in_all, tbl.info[#tbl.info].track)
            local env_t, env_b, env_h = GetEnvOffset_MatchCriteria(off_tr, tbl.info[i].env_name, tbl.info[i].track, i)
            for e = 1, #env_ghosts do
              if as_tr == env_ghosts[e].track then
                
                local pos = mouse_time_pos
                if e > 1 then pos = pos + (env_ghosts[e].p - Areas_TB[1].time_start) end
                
                if env_t then  
                  reaper.JS_Composite(
                                        track_window, 
                                        math.floor(pos  * zoom_lvl) - Arr_pixel,                -- X
                                        (env_t - y_view_start),                                 -- Y
                                        math.floor((tbl.time_end - tbl.time_start) * zoom_lvl), -- W
                                        env_h,                                                  -- H
                                        env_ghosts[e].bm,                                      
                                        0,                                                      -- x
                                        0,                                                      -- y
                                        env_ghosts[e].l,                                        -- w
                                        env_ghosts[e].h                                         -- h
                                      )
                else
                  reaper.JS_Composite_Unlink(track_window, env_ghosts[e].bm)    -- DO NOT SHOW IF NOT OVER ENVELOPE  
                end
              end
            end
          end
        end
      end
    
    
   -- refresh_reaper()
end

function mouse_info()
  local zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, state, scroll = Project_info()  
  local cur_m_x, cur_m_y = reaper.GetMousePosition()
  local mouse_time_pos = ((cur_m_x - x_view_start) / zoom_lvl) + Arr_start_time
  mouse_time_pos = (mouse_time_pos > 0) and mouse_time_pos or 0
  local pos = (reaper.GetToggleCommandState(1157) == 1) and reaper.SnapToGrid(0, mouse_time_pos) or mouse_time_pos -- FINAL POSITION IS SNAP IF ENABLED OF FREE MOUSE POSITION
    return pos
end

function copy_mode()
  copy = not copy
  
  if not copy and #Areas_TB ~= 0 then
    for k, v in pairs(item_ghosts) do
      reaper.JS_Composite_Unlink(track_window,  v.bm) 
    end
    for k, v in pairs(env_ghosts) do
      reaper.JS_Composite_Unlink(track_window,  v.bm) 
    end
    refresh_reaper()
  end
end

function copy_paste()
  if copy and #Areas_TB ~= 0 then
    paste(Areas_TB, last_m_tr, m_t)
    paste_env(Areas_TB, last_m_tr, m_t)
    GetTracksXYH_Info()
  end
end

function remove()
  if copy then copy_mode() end
  RemoveAsFromTable(Areas_TB, "Delete")
  refresh_reaper()
end

local function check_keys()
  local key = Track_keys(Key_TB)
  if key then 
    if key.DOWN then
   --   msg(key.DOWN.name .. " - " .. "DOWN")  
      if key.DOWN.func then key.DOWN.func() end
    elseif key.HOLD then
   --   msg(key.HOLD.name .. " - " .. "HOLD") 
    elseif key.UP then
    --  msg(key.UP.name .. " - " .. "UP") 
    end
    
  end
end

function find_highest_tr()
  local first_tr = Areas_TB[1].info[1].track
  local min, tr = TBH[first_tr].t, first_tr
  for i = 1, #Areas_TB do
    local tbl = Areas_TB[i]
    local first_tbl_tr = tbl.info[1].track
    for j = 1, #tbl.info do
      local as_tr = tbl.info[j].track
      local cur_min = TBH[as_tr].t
      if cur_min < min then min, tr = cur_min, as_tr end
    end
  end
  return tr, min
end

local function Main()
  GetTracksXYH_Info()                                               -- GET XYH INFO OF ALL TRACKS
  check_keys()
  
  m_x, m_y  = reaper.GetMousePosition()                             -- GET MOUSE POSITION
  m_state   = reaper.JS_Mouse_GetState(95)                          -- GET MOUSE STATE FROM REAPER
  m_t       = mouse_info()                                          -- GET MOUSE TIME POSITION
  
  local tr, m_r_t, m_r_b  = GetTrackFromPoint(m_x, m_y)             -- GET TRACK OR ENVELOPE AND RANGE OF TRACKS MADE BY MOUSE Y
  local track_zone        = GetTrackZoneInfo(tr, m_y)               -- TRUE UPPER HALF, FALSE LOWER HALF
 
  if m_state  &1==1  and last_mouse_cap  &1==0  or                  -- L mouse
     m_state  &2==2  and last_mouse_cap  &2==0  or                  -- R mouse
     m_state &64==64 and last_mouse_cap &64==0 then                 -- M mouse
     mouse_ox, mouse_oy, mouse_ot, mouse_ort, mouse_orb = m_x, m_y, m_t, m_r_t, m_r_b
  elseif m_state &1==0 then DRAWING = nil ZONE = nil
  
  end
  
  if ZONE then zone(ZONE) end
  
  if not ZONE then CreateAreaFromCoordinates(m_r_t, m_r_b) end        -- CREATE AS IF IN ARRANGE WINDOW AND NON AS ZONES ARE CLICKED
 
  Ctrl  = m_state  &4==4                                            -- CTRL
  Shift = m_state  &8==8                                            -- SHIFT
  Alt   = m_state &16==16                                           -- ALT
  
  Draw(Areas_TB, track_window)                                      -- DRAWING CLASS 
  --Menu_TB[1]:draw_body(active_as)
  
  if copy and #Areas_TB ~= 0 then DrawItemGhosts(active_as, m_t ,tr) DrawEnvGhosts(active_as, m_t ,tr) end
   
  last_mouse_cap = m_state
  last_x, last_y, last_m_p, last_m_r_t, last_m_r_b = m_x, m_y, m_t, m_r_t, m_r_b
  last_m_tr = tr
  reaper.defer(Main)
end

function Exit()                                                      -- DESTROY ALL BITMAPS ON REAPER EXIT
  for i = 1, #Areas_TB do
    reaper.JS_LICE_DestroyBitmap(Areas_TB[i].bm)
  end
  --reaper.JS_LICE_DestroyBitmap(Menu_TB[1].bm)
  reaper.JS_LICE_DestroyBitmap(m_bm) 
  
  if item_ghosts then
    for k, v in pairs(item_ghosts) do
      reaper.JS_LICE_DestroyBitmap(v.bm) 
    end
  end
  
  if reaper.ValidatePtr(track_window, "HWND") then refresh_reaper() end
end

function Init()
  last_x, last_y, last_mouse_cap = 0, 0, 0
  mouse_ox, mouse_oy, mouse_ot, mouse_ort, mouse_orb = -1, -1, -1, -1, -1
end

for i = 1, 255 do
  local func
  local name = string.char(i)
  if     i == 16  then name = "Shift"
  elseif i == 17  then name = "Ctrl"
  elseif i == 18  then name = "Alt"
  elseif i == 13  then name = "Return"
  elseif i == 8   then name = "Backspace"
  elseif i == 32  then name = "Space"
  elseif i == 20  then name = "Caps-Lock"
  elseif i == 27  then name = "ESC" func = remove
  elseif i == 9   then name = "TAB" func = test     
  elseif i == 192 then name = "~"
  elseif i == 91  then name = "Win"
  elseif i == 45  then name = "Insert"
  elseif i == 46  then name = "Del"
  elseif i == 36  then name = "Home"
  elseif i == 35  then name = "End"
  elseif i == 33  then name = "PG-Up"
  elseif i == 34  then name = "PG-Down"
  end
  Key_TB[#Key_TB+1] = Key:new({i},name,func)
end

  Key_TB[#Key_TB+1] = Key:new({17,67}   ,"COPY" ,copy_mode) -- COPY
  Key_TB[#Key_TB+1] = Key:new({17,86}   ,"PASTE",copy_paste) -- COPY
  
Init()
reaper.atexit(Exit)
Main()
