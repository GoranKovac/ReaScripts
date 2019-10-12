package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
package.cursor = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "Cursors\\" -- GET DIRECTORY FOR CURSORS

require("Area_51_class") -- AREA FUNCTIONS SCRIPT
require("Area_51_functions") -- AREA CLASS SCRIPT
require("Area_51_input") -- AREA INPUT HANDLING/SETUP
require("Area_51_mouse")

--debug = false

crash = function(errObject)
   local byLine = "([^\r\n]*)\r?\n?"
   local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
   local err = errObject and string.match(errObject, trimPath) or "Couldn't get error message."

   local trace = debug.traceback()
   local stack = {}
   for line in string.gmatch(trace, byLine) do
      local str = string.match(line, trimPath) or line
      stack[#stack + 1] = str
   end

   local name = ({reaper.get_action_context()})[2]:match("([^/\\_]+)$")

   local ret =
      reaper.ShowMessageBox(
      name .. " has crashed!\n\n" .. "Would you like to have a crash report printed " .. "to the Reaper console?",
      "Oops",
      4
   )

   if ret == 6 then
      reaper.ShowConsoleMsg(
         "Error: " ..
            err ..
               "\n\n" ..
                  "Stack traceback:\n\t" ..
                     table.concat(stack, "\n\t", 2) ..
                        "\n\n" ..
                           "Reaper:       \t" .. reaper.GetAppVersion() .. "\n" .. "Platform:     \t" .. reaper.GetOS()
      )
   end
end

local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 1000) -- GET TRACK VIEW
local track_window_dc = reaper.JS_GDI_GetWindowDC(track_window)
Areas_TB = {}
local Key_TB = {}
local active_as
local last_proj_change_count = reaper.GetProjectStateChangeCount(0)

function msg(m)
   reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local ceil, floor = math.ceil, math.floor
function Round(n)
   return n % 1 >= 0.5 and ceil(n) or floor(n)
end

local function Has_val(tab, val, guid)
   local val_n = guid and guid or val
   for i = 1, #tab do
      local in_table = guid and tab[i].guid or tab[i]
      if in_table == val_n then
         return tab[i]
      end
   end
end

local TBH
function GetTracksXYH()
   TBH = {}
   local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window)
   -- ONLY ADD MASTER TRACK IF VISIBLE IN TCP
   if reaper.GetMasterTrackVisibility() == 1 then
      local master_tr = reaper.GetMasterTrack(0)
      local m_tr_h = reaper.GetMediaTrackInfo_Value(master_tr, "I_TCPH")
      local m_tr_t = reaper.GetMediaTrackInfo_Value(master_tr, "I_TCPY") + y_view_start
      local m_tr_b = m_tr_t + m_tr_h
      TBH[master_tr] = {t = m_tr_t, b = m_tr_b, h = m_tr_h} 
   end
   for i = 1, reaper.CountTracks(0) do
      local tr = reaper.GetTrack(0, i - 1)
      local tr_h = reaper.GetMediaTrackInfo_Value(tr, "I_TCPH")
      local tr_t = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY") + y_view_start
      local tr_b = tr_t + tr_h
      TBH[tr] = {t = tr_t, b = tr_b, h = tr_h}
      for j = 1, reaper.CountTrackEnvelopes(tr) do
         local env = reaper.GetTrackEnvelope(tr, j - 1)
         local env_h = reaper.GetEnvelopeInfo_Value(env, "I_TCPH")
         local env_t = reaper.GetEnvelopeInfo_Value(env, "I_TCPY") + tr_t
         local env_b = env_t + env_h
         TBH[env] = {t = env_t, b = env_b, h = env_h}
      end
   end
end

function GetTracksFromRange(y_t, y_b)
   local range_tracks = {}
   for track, coords in pairs(TBH) do
      if coords.t >= y_t and coords.b <= y_b then
         range_tracks[#range_tracks+1] = {track = track, v = coords.t}
      end
   end
   table.sort(
      range_tracks,
      function(a, b)
         return a.v < b.v
      end
   )
   for i = 1, #range_tracks do
      range_tracks[i] = {track = range_tracks[i].track}
   end
   return range_tracks
end

local function GetTracksFromMouse(x, y)
   local track, env_info = reaper.GetTrackFromPoint(x, y)

   if track == reaper.GetMasterTrack( 0 ) and  reaper.GetMasterTrackVisibility() == 0 then return end -- IGNORE DOCKED MASTER TRACK

   if track and env_info == 0 then
      return track, TBH[track].t, TBH[track].b, TBH[track].h
   elseif track and env_info == 1 then
      for i = 1, reaper.CountTrackEnvelopes(track) do
         local env = reaper.GetTrackEnvelope(track, i - 1)
         if TBH[env].t <= y and TBH[env].b >= y then
            return env, TBH[env].t, TBH[env].b, TBH[env].h
         end
      end
   end
end

local function Get_Set_Position_In_Arrange(x, y, w)
   local zoom_lvl = reaper.GetHZoomLevel() -- HORIZONTAL ZOOM LEVEL
   local Arr_start_time, _ = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW
   local Arr_pixel = Round(Arr_start_time * zoom_lvl) -- ARRANGE VIEW POSITION CONVERT TO PIXELS
   local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window) -- GET TRACK WINDOW X-Y Selection
   if x or y or w then
      x = Round(x * zoom_lvl) - Arr_pixel
      y = y - y_view_start
      w = Round(w * zoom_lvl)
      return x, y, w
   else
      return zoom_lvl, Arr_start_time, Arr_pixel, x_view_start, y_view_start
   end
end

local prev_Arr_end_time, prev_proj_state, last_scroll, last_scroll_b, last_pr_t, last_pr_h
function Arrange_view_info(x, y, w)
   local last_pr_tr = get_last_visible_track()
   local proj_state = reaper.GetProjectStateChangeCount(0) -- PROJECT STATE
   local _, scroll, _, _, scroll_b = reaper.JS_Window_GetScrollInfo(track_window, "SB_VERT") -- GET VERTICAL SCROLL
   local _, Arr_end_time = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW

   if prev_Arr_end_time ~= Arr_end_time then -- THIS ONE ALWAYS CHANGES WHEN ZOOMING IN OUT
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
   elseif last_pr_tr then -- LAST TRACK ALWAYS CHANGES HEIGHT WHEN OTHER TRACK RESIZE
      if TBH[last_pr_tr].h ~= last_pr_h or TBH[last_pr_tr].t ~= last_pr_t then
         last_pr_h = TBH[last_pr_tr].h
         last_pr_t = TBH[last_pr_tr].t
         return true
      end
   end
end

function get_last_visible_track()
   if reaper.CountTracks(0) == 0 then
      return
   end
   local last_tr = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
   if not reaper.IsTrackVisible(last_tr, false) then
      for i = reaper.CountTracks(0), 1, -1 do
         local track = reaper.GetTrack(0, i - 1)
         if reaper.IsTrackVisible(track, false) then
            return track
         end
      end
   end
   return last_tr
end

function GetTrackTBH(tbl)
   if not tbl then
      return
   end
   -- GET INFO FROM FIRST AND LAST TRACK FROM TABLE
   if TBH[tbl[1].track] and TBH[tbl[#tbl].track] then
      return TBH[tbl[1].track].t, TBH[tbl[#tbl].track].b - TBH[tbl[1].track].t
   end
end

function Mouse_in_arrange()
   -- IF SOME WINDOW IS IN FRONT OF MOUSE RETURN
   if reaper.JS_Window_GetForeground() ~= main_wnd then
      return
   end
   local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window) -- GET TRACK WINDOW X-Y Selection
   -- IS MOUSE IN ARRANGE VIEW COORDINATES
   if (mouse.oy >= y_view_start and mouse.oy <= y_view_end) and (mouse.ox >= x_view_start and mouse.ox <= x_view_end) and mouse.l_down then
      -- IF MOUSE IS OVER TRACK (THIS IS CHECK IF WE ARE IN ARRANGE VIEW BUT WE ARE BELLOW LAST TRACK)
      if GetTracksFromMouse(mouse.ox, mouse.oy) then
         --[[
         local tr = GetTracksFromMouse(mouse.ox, mouse.oy)
         local tr_t, _, tr_h = TBH[tr].t, TBH[tr].b, TBH[tr].h
         if (mouse.oy - tr_t < tr_h / 2) then
            return "UPPER"
         elseif (mouse.oy - tr_t > tr_h / 2) then
            return "LOWER"
         end
         return true
      end
      ]]
         ARRANGE = true
         return true
      end
   end
end

function GetTrackZoneInfo()
   if Mouse_in_arrange() then
      local track_part = Mouse_in_arrange()
      if mouse.l_down then
         if mouse.detail == "EDGE L" or mouse.detail == "EDGE R" then
            if track_part == "LOWER" then
               msg("LOW")
               reaper.JS_WindowMessage_PassThrough(track_window, "WM_LBUTTONDOWN", false)
            elseif track_part == "UPPER" then
               msg("HI")
               reaper.JS_WindowMessage_PassThrough(track_window, "WM_LBUTTONDOWN", true)
            end
         end
         if mouse.detail == "MOVE" or mouse.detail == "FADE L" or mouse.detail == "FADE R" or mouse.detail == "DRAW" then
            BLOCK = true
         end
      else
         if BLOCK then
            BLOCK = nil
         end
      end
   end
end

local function Check_top_bot(top_start, top_end, bot_start, bot_end) -- CHECK IF VALUES GOT REVERSED
   if bot_end <= top_start then
      return bot_start, top_end
   else
      return top_start, bot_end
   end
end

local function Check_left_right(val1, val2) -- CHECK IF VALUES GOT REVERSED
   if val2 < val1 then
      return val2, val1
   else
      return val1, val2
   end
end

local prev_s_start, prev_s_end, prev_r_start, prev_r_end
local function Check_change(s_start, s_end, r_start, r_end)
   if s_start == s_end then
      return
   end
   if prev_s_end ~= s_end or prev_s_start ~= s_start then
      prev_s_start, prev_s_end = s_start, s_end
      return "TIME X"
   elseif prev_r_start ~= r_start or prev_r_end ~= r_end then
      prev_r_start, prev_r_end = r_start, r_end
      return "RANGE Y"
   end
end

local function GDIBlit(dest, x, y, w, h)
   reaper.JS_GDI_Blit(dest, 0, 0, track_window_dc, x, y, w, h)
end

local ghosts = {}
local function GetGhosts(data, as_start, as_end)
   for i = 1, #data do
      if data[i].items then
         local tr = data[i].track
         local item_t, item_h = TBH[tr].t, TBH[tr].h
         local item_bar = (item_h > 42) and 15 or 0
         for j = 1, #data[i].items do
            local item = data[i].items[j]
            local item_start, item_lenght = item_blit(item, as_start, as_end)
            local x, y, w = Get_Set_Position_In_Arrange(item_start, (item_t + item_bar), item_lenght)
            local h = item_h
            local bm = reaper.JS_LICE_CreateBitmap(true, w, h)
            local dc = reaper.JS_LICE_GetDC(bm)
            local item_ghost_id = tostring(item) .. as_start
            GDIBlit(dc, x, y, w, (h - 19))
            ghosts[item_ghost_id] = {
               bm = bm,
               dc = dc,
               p = x,
               l = w,
               h = h,
               i_s = item_start,
               i_l = item_lenght
            }
         end
      elseif data[i].env_points then
         local tr = data[i].track
         local env_t, env_h = TBH[tr].t, TBH[tr].h
         local x, y, w = Get_Set_Position_In_Arrange(as_start, env_t, (as_end - as_start))
         local h = env_h
         local bm = reaper.JS_LICE_CreateBitmap(true, w, env_h)
         local dc = reaper.JS_LICE_GetDC(bm)
         local env_ghost_id = tostring(tr) .. as_start
         GDIBlit(dc, x, y, w, h)
         ghosts[env_ghost_id] = {
            bm = bm,
            dc = dc,
            p = as_start,
            l = w,
            h = h
         }
      end
   end
end

local function split_by_line(str)
   local t = {}
   for line in string.gmatch(str, "[^\r\n]+") do
       t[#t + 1] = line
   end
   return t
end

local function edit_chunk(str, org, new)
   local chunk = string.gsub(str, org, new)
   return chunk
end

function get_set_envelope_chunk(track, env, as_start, as_end, mouse_offset)
   local ret, chunk = reaper.GetTrackStateChunk(track, "", false)
   local ret2, env_chunk = reaper.GetEnvelopeStateChunk(env, "")

   chunk = split_by_line(chunk)
   env_chunk = split_by_line(env_chunk)

   for i = 1, #env_chunk do
       if i < 8 then
           table.insert(chunk, #chunk, env_chunk[i]) -- INSERT FIRST 7 LINES INTO TRACK CHUNK (DEFAULT INFO WITH FIRST POINT)
       elseif i == #env_chunk then
           table.insert(chunk, #chunk, env_chunk[i])
       else
           local time, val, something, selected = env_chunk[i]:match("([%d%.]+)%s([%d%.]+)%s([%d%.]+)%s([%d%.]+)")
           if time then
               time = tonumber(time)
               if time >= as_start and time <= as_end then
                   local new_time = time + mouse_offset
                   env_chunk[i] = edit_chunk(env_chunk[i], time, new_time)
                   table.insert(chunk, #chunk, env_chunk[i])
               end
           end
       end
   end

   local new_chunk = table.concat(chunk, "\n")
   reaper.SetTrackStateChunk(track, new_chunk, true)
end

local function GetTrackData(tbl, as_start, as_end)
   for i = 1, #tbl do
      if reaper.ValidatePtr(tbl[i].track, "MediaTrack*") then
         tbl[i].items = get_items_in_as(tbl[i].track, as_start, as_end) -- TRACK MEDIA ITEMS
      elseif reaper.ValidatePtr(tbl[i].track, "TrackEnvelope*") then
         local _, env_name = reaper.GetEnvelopeName(tbl[i].track)
         tbl[i].env_name = env_name -- ENVELOPE NAME
         tbl[i].env_points = get_as_tr_env_pts(tbl[i].track, as_start, as_end) -- ENVELOPE POINTS
         tbl[i].AIs = get_as_tr_AI(tbl[i].track, as_start, as_end) -- AUTOMATION ITEMS
      end
   end
   return tbl
end

local function RemoveAsFromTable(tab, val)
   for i = #tab, 1, -1 do
      local in_table = tab[i].guid
      if in_table ~= val then -- REMOVE ANY AS THAT HAS DIFFERENT GUID
         reaper.JS_LICE_DestroyBitmap(tab[i].bm) -- DESTROY BITMAPS FROM AS THAT WILL BE DELETED
         table.remove(tab, i) -- REMOVE AS FROM TABLE
      end
   end
   for k, v in pairs(ghosts) do
      reaper.JS_LICE_DestroyBitmap(v.bm)
      ghosts[k] = nil
   end
end

local function CreateAreaTable(x, y, w, h, guid, time_start, time_end)
   if not Has_val(Areas_TB, nil, guid) then
      Areas_TB[#Areas_TB + 1] = AreaSelection:new(x, y, w, h, guid, time_start, time_end - time_start) -- CREATE NEW CLASS ONLY IF DOES NOT EXIST
   else
      Areas_TB[#Areas_TB].time_start = time_start
      Areas_TB[#Areas_TB].time_dur = time_end - time_start
      Areas_TB[#Areas_TB].x = x
      Areas_TB[#Areas_TB].y = y
      Areas_TB[#Areas_TB].w = w
      Areas_TB[#Areas_TB].h = h
   end
end

function GetSelectionInfo(tbl)
   if not tbl then
      return
   end
   local area_top, area_bot, area_start, area_end = tbl.y, tbl.y + tbl.h, tbl.time_start, tbl.time_start + tbl.time_dur
   local tracks = GetTracksFromRange(area_top, area_bot) -- GET TRACK RANGE
   local data = GetTrackData(tracks, area_start, area_end) -- GATHER ALL INFO
   return data
end

function convert_time_to_pixel(t_start, t_end)
   local zoom_lvl, Arr_start_time, Arr_pixel, x_view_start, y_view_start = Get_Set_Position_In_Arrange()
   local x_s = Round(t_start * zoom_lvl) -- convert time to pixel
   local x_e = Round(t_end * zoom_lvl) -- convert time to pixel
   local x = (x_s - Arr_pixel) + x_view_start
   local w = x_e - x_s
   return x, w
end

local function CreateAreaFromSelection()
   if not ARRANGE then return end
   local as_top, as_bot = Check_top_bot(mouse.ort, mouse.orb, mouse.r_t, mouse.r_b) -- RANGE ON MOUSE CLICK HOLD AND RANGE WHILE MOUSE HOLD
   local as_left, as_right = Check_left_right(mouse.op, mouse.p) -- CHECK IF START & END TIMES ARE REVERSED

   if mouse.l_down then
      DRAWING = Check_change(as_left, as_right, as_top, as_bot)

      if DRAWING then
         CREATING = true
         if guid == nil then
            guid = mouse.Shift() and reaper.genGuid() or "single"
         end

         if copy then
            copy_mode()
         end -- DISABLE COPY MODE IF ENABLED
         if not mouse.Shift() then
            RemoveAsFromTable(Areas_TB, "single")
         end -- REMOVE ALL CREATED AS AND GHOSTS IF SHIFT IS NOT PRESSED (FOR MULTI CREATING AS)

         local x, w = convert_time_to_pixel(as_left, as_right)
         local y, h = as_top, as_bot - as_top
         CreateAreaTable(x, y, w, h, guid, as_left, as_right)
      end
   elseif mouse.l_up and CREATING then
      local last_as = Areas_TB[#Areas_TB]
      local sel_info = GetSelectionInfo(last_as)
      Areas_TB[#Areas_TB].sel_info = sel_info
      GetGhosts(sel_info, last_as.time_start, last_as.time_start + last_as.time_dur) -- MAKE ITEM GHOSTS
      table.sort(
         Areas_TB,
         function(a, b)
            return a.y < b.y
         end
      ) -- SORT AREA TABLE BY Y POSITION (LOWEST TO HIGHEST)
      CREATING, guid, DRAWING, ARRANGE = nil, nil, nil, nil
   elseif mouse.l_up and ARRANGE then
      ARRANGE = nil
   end
end

local function find_visible_tracks(cur_offset_id) -- RETURN FIRST VISIBLE TRACK
   if cur_offset_id == 0 then
      return 1
   end -- TO DO FIX
   for i = cur_offset_id, reaper.CountTracks(0) do
      local track = reaper.GetTrack(0, i - 1)
      if reaper.IsTrackVisible(track, false) then
         return i
      else
      end
   end
end

function GetEnvOffset_MatchCriteria(tr, env)
   for i = 1, reaper.CountTrackEnvelopes(tr) do
      local tr_env = reaper.GetTrackEnvelope(tr, i - 1)
      local _, env_name = reaper.GetEnvelopeName(tr_env)
      if env_name == env then
         return tr_env, i
      end -- RETURN ONLY MATCHED ENVELOPES (MATCH CRITERIA)
   end
   return tr
end

function env_mouse_offset(tr, env_name, first_env)
   local mouse_env = reaper.ValidatePtr(mouse.tr, "TrackEnvelope*") and mouse.tr
   if mouse_env then
      local parent = reaper.Envelope_GetParentTrack(mouse_env)
      local _, first_env_name = reaper.GetEnvelopeName(first_env)
      local _, first = GetEnvOffset_MatchCriteria(parent, first_env_name) -- TODO ADD FIRST TRACK
      local _, env_tr_id = GetEnvOffset_MatchCriteria(parent, env_name)
      for i = 1, reaper.CountTrackEnvelopes(parent) do
         local env = reaper.GetTrackEnvelope(parent, i - 1)
         if env == mouse_env then
            local env_tr_offset = i - first
            local env_pos_offset = (env_tr_offset + env_tr_id) - 1
            local new_env_tr = reaper.GetTrackEnvelope(parent, env_pos_offset)
            return new_env_tr
         end
      end
   end
end

function env_to_track(tr)
   if reaper.ValidatePtr(tr, "TrackEnvelope*") then
      return reaper.Envelope_GetParentTrack(tr)
   end
   return tr
end

function generic_track_offset(as_tr, offset_tr, job)--, first_tr, num)
   --  GET ALL ENVELOPE TRACKS PARENT MEDIA TRACKS (SINCE ENVELOPE TRACKS HAVE NO ID WHICH WE USE TO MAKE OFFSET)
   local cur_m_tr = mouse.tr -- ADD TEMP MOUSE TRACK (DO NOT CONVERT) BELOW

   if reaper.ValidatePtr(as_tr, "TrackEnvelope*") then
      as_tr = reaper.Envelope_GetParentTrack(as_tr)
   end
   if reaper.ValidatePtr(offset_tr, "TrackEnvelope*") then
      offset_tr = reaper.Envelope_GetParentTrack(offset_tr)
   end
   if reaper.ValidatePtr(cur_m_tr, "TrackEnvelope*") then
      cur_m_tr = reaper.Envelope_GetParentTrack(cur_m_tr)
   end

   local offset_tr_id = reaper.CSurf_TrackToID(offset_tr, false)
   local as_tr_id = reaper.CSurf_TrackToID(as_tr, false)
   local m_tr_id = reaper.CSurf_TrackToID(cur_m_tr, false)

   if mouse.y > mouse.r_b and GetTracksFromRange(mouse.r_b, mouse.y) then
      m_tr_id = reaper.CSurf_TrackToID(cur_m_tr, false) + 1
   end -- IF MOUSE IS BELOW LAST PROJECT TRACK INCREASE MOUSE ID FOR OFFSET

   local last_project_tr = get_last_visible_track()
   local last_project_tr_id = reaper.CSurf_TrackToID(last_project_tr, false)

   local as_tr_offset = m_tr_id - offset_tr_id 
   local as_pos_offset = as_tr_id + as_tr_offset -- ADD MOUSE OFFSET TO CURRENT TRACK ID
   as_pos_offset = find_visible_tracks(as_pos_offset) or as_pos_offset -- FIND FIRST AVAILABLE VISIBLE TRACK IF HIDDEN

   local new_as_tr =
      as_pos_offset < last_project_tr_id and -- POSITION ITEMS TO MOUSE POSITION
      reaper.CSurf_TrackFromID(as_pos_offset, false) or
      last_project_tr

   --if job then new_as_tr = as_pos_offset < last_project_tr reaper.CSurf_TrackFromID(as_pos_offset, false) end
   --if as_pos_offset == last_project_tr_id+1 then return as_tr end

   local under_last_tr = (as_pos_offset - last_project_tr_id > 0) and as_pos_offset - last_project_tr_id -- HOW MANY TRACKS BELOW LAST PROJECT TRACK IS THE OFFSET
   return new_as_tr, under_last_tr
end

function lowest_start()
   local as_tbl = active_as and {active_as} or Areas_TB
   local min = as_tbl[1].time_start
   for i = 1, #as_tbl do
      if as_tbl[i].time_start < min then
         min = as_tbl[i].time_start
      end -- FIND LOWEST (FIRST) TIME SEL START
   end
   return min
end

local function generic_table_find(job)
   local as_tbl = active_as and {active_as} or Areas_TB -- ACTIVE AS OR WHOLE AREA TABLE

   for a = 1, #as_tbl do
      local tbl = as_tbl[a]

      local pos_offset = 0
      pos_offset = pos_offset + (tbl.time_start - lowest_start()) --  OFFSET AREA SELECTIONS TO MOUSE POSITION
      local as_start, as_dur = tbl.time_start, tbl.time_dur

      for i = 1, #tbl.sel_info do
         local sel_info = tbl.sel_info[i]
         local first_tr = find_highest_tr()

         if sel_info.items then
            local item_track = sel_info.track
            local item_data = sel_info.items
            if copy then
               DrawItemGhosts(item_data, item_track, as_start, as_dur, pos_offset, first_tr)
            end
         elseif sel_info.env_name then
            local env_track = sel_info.track
            local env_name = sel_info.env_name
            --local env_data = sel_info.env_points -- CURENTLY UNUSED
            if copy then
               DrawEnvGhosts(env_track, env_name, as_start, as_dur, pos_offset, first_tr)
            end
         end
      end
   end
end

local function Composite(src_x, src_y, src_w, src_h, dest, dest_x, dest_y, dest_w, dest_h)
   reaper.JS_Composite(track_window, src_x, src_y, src_w, src_h, dest, dest_x, dest_y, dest_w, dest_h)
   if mouse.x ~= prev_mouse_x or mouse.y ~= prev_mouse_y then -- MINIMIZE FLICKERING
      refresh_reaper()
      prev_mouse_x = mouse.x
      prev_mouse_y = mouse.y
   end
end

function DrawItemGhosts(item_data, item_track, as_start, as_end, pos_offset, first_track)
   local offset_track, under_last_tr = generic_track_offset(item_track, first_track)
   local off_h = under_last_tr and reaper.GetMediaTrackInfo_Value(offset_track, "I_WNDH") * under_last_tr or 0 -- USE THIS INSTEAD OF THB[] SINCE IT MAYBE GOT ENVELOPES WHICH ARE INCLUDED IN THIS API
   if TBH[offset_track] then -- THIS IS NEEDED FOR PASTE FUNCTION OR IT WILL CRASH
      local track_t, _, track_h = TBH[offset_track].t + off_h, TBH[offset_track].b, TBH[offset_track].h
      for i = 1, #item_data do
         local item = item_data[i]
         local item_ghost_id = tostring(item) .. as_start
         local mouse_offset = pos_offset + (mouse.p - as_start) + ghosts[item_ghost_id].i_s
         local x, y, w = Get_Set_Position_In_Arrange(mouse_offset, track_t, ghosts[item_ghost_id].i_l)
         local h = track_h
         Composite(x, y, w, h, ghosts[item_ghost_id].bm, 0, 0, ghosts[item_ghost_id].l, ghosts[item_ghost_id].h - 19)
      end
   end
end

function DrawEnvGhosts(env_track, env_name, as_start, as_end, pos_offset, first_env_tr, env_first_tr)
   local offset_track, under_last_tr = generic_track_offset(env_track, first_env_tr)
   local off_h = under_last_tr and TBH[offset_track].h * under_last_tr or 0 -- IF OFFSET TRACKS ARE BELOW LAST PROJECT TRACK MULTIPLY HEIGHT BY THAT NUMBER AND ADD IT TO GHOST
   local env_tr_offset = GetEnvOffset_MatchCriteria(offset_track, env_name)
   --env_tr_offset = reaper.ValidatePtr(mouse.tr,"TrackEnvelope*") and env_mouse_offset(offset_track, env_name, env_first_tr) or env_tr_offset
   if TBH[env_tr_offset] then
      local track_t, _, track_h = TBH[env_tr_offset].t + off_h, TBH[env_tr_offset].b, TBH[env_tr_offset].h
      local env_ghost_id = tostring(env_track) .. as_start
      if ghosts[env_ghost_id] then
         local mouse_offset = pos_offset + (mouse.p - as_start) + ghosts[env_ghost_id].p
         local x, y, w = Get_Set_Position_In_Arrange(mouse_offset, track_t, as_end)
         local h = track_h
         Composite(x, y, w, h, ghosts[env_ghost_id].bm, 0, 0, ghosts[env_ghost_id].l, ghosts[env_ghost_id].h)
      end
   end
end

function check_limit(val, limit)
   val = val >= limit and val or limit
   return val
end

local function Mouse_Data_From_Arrange()
   local zoom_lvl, Arr_start_time, Arr_pixel, x_view_start, y_view_start = Get_Set_Position_In_Arrange()
   local x, y = reaper.GetMousePosition()
   local p = ((x - x_view_start) / zoom_lvl) + Arr_start_time

   if reaper.GetToggleCommandState(1157) == 1 then
      p = p >= 0 and reaper.SnapToGrid(0, p) or p
      x = (Round(p * zoom_lvl) + x_view_start) - Arr_pixel
   end

   if Mouse_in_arrange() then
      p = p >= Arr_start_time and p or Arr_start_time
      x = x >= x_view_start and x or x_view_start
      y = y >= y_view_start and y or y_view_start
   end
   
   mouse = MouseInfo(x, y, p)
   mouse.detail = ReaperCursors()
   if GetTracksFromMouse(mouse.x, mouse.y) then
      mouse.tr, mouse.r_t, mouse.r_b = GetTracksFromMouse(mouse.x, mouse.y)
   end
end

function find_highest_tr(job)
   local as_tbl = active_as and {active_as} or Areas_TB
   for i = 1, #as_tbl do
      local tbl = as_tbl[i]
      for j = 1, #tbl.sel_info do
         if tbl.sel_info[j].items or not job then
            return tbl.sel_info[j].track
         elseif tbl.sel_info[j].env_name or job then
            return tbl.sel_info[j].track
         end
      end
   end
end

local reaper_cursors_list = {
   {187, "MOVE"}, -- MOVE
   {185, "DRAW"}, -- DRAW
   {417, "EDGE L"}, -- LEFT EDGE
   {418, "EDGE R"}, -- RIGHT EDGE
   {184, "FADE L"}, -- FADE RIGHT
   {105, "FADE R"} -- FADE LEFT
}

function ReaperCursors()
   local cur_cursor = reaper.JS_Mouse_GetCursor()
   for i = 1, #reaper_cursors_list do
      local cursor = reaper.JS_Mouse_LoadCursor(reaper_cursors_list[i][1])
      if cur_cursor == cursor then
         return reaper_cursors_list[i][2]
      end
   end
end

local function ValidateRemovedTracks()
   if #Areas_TB == 0 then
      return
   end
   for i = #Areas_TB, 1, -1 do
      for j = #Areas_TB[i].sel_info, 1, -1 do
         if not reaper.ValidatePtr(Areas_TB[i].sel_info[j].track, "MediaTrack*") then
            table.remove(Areas_TB[i].sel_info, j)
            if #Areas_TB[i].sel_info == 0 then
               table.remove(Areas_TB, i)
            end
         end
      end
   end
end

local function check_undo_history()
   local proj_change_count = reaper.GetProjectStateChangeCount(0)
   if proj_change_count > last_proj_change_count then
      local last_action = reaper.Undo_CanUndo2(0)
      if not last_action then
         return
      end
      last_action = last_action:lower()
      if last_action:find("remove tracks") then
         ValidateRemovedTracks()
      elseif
         last_action:find("toggle track volume/pan/mute envelopes") or
            last_action:find("track envelope active/visible/armed change")
       then
      -- TO DO
      -- CHECK ENVELOPES
      end
      last_proj_change_count = proj_change_count
   end
end

function copy_mode(key)
   copy = next(ghosts) ~= nil and not copy
   if not copy then
      for _, v in pairs(ghosts) do
         reaper.JS_Composite_Unlink(track_window, v.bm)
      end -- REMOVE GHOSTS
      for i = 1, #Key_TB do
         if Key_TB[i].func then
            Key_TB[i]:intercept(-1)
         end
      end -- RELEASE INTRECEPT
      refresh_reaper() -- REFRESH SCREEN FROM GHOST REMOVING
   else
      for i = 1, #Key_TB do
         if Key_TB[i].name == "COPY" or Key_TB[i].name == "PASTE" then
            Key_TB[i]:intercept(1)
         end -- INTERCEPT
      end
   end
end

function copy_paste()
   if copy and #Areas_TB ~= 0 then
      local tbl = active_as and {active_as} or Areas_TB
      AreaDo(tbl, "PASTE")
      GetTracksXYH() -- REFRESH MAIN TABLE TRACKS (IF PASTE CREATED NEW TRACKS)
   end
end

function remove()
   if copy then
      copy_mode()
   end -- DISABLE COPY MODE
   RemoveAsFromTable(Areas_TB, "Delete")
   active_as = nil
   
   for i = 1, #Key_TB do
      if Key_TB[i].func then
         Key_TB[i]:intercept(-1) -- RELEASE INTERCEPTS
      end
   end 

   refresh_reaper()
end

function del()
   local tbl = active_as and {active_as} or Areas_TB
   if #tbl ~= 0 then
       AreaDo(tbl, "del")
   end
end

local function check_keys()
   local key = Track_keys(Key_TB, Areas_TB)
   if key then
      if key.DOWN then
         if key.DOWN.func then
            key.DOWN.func(key.DOWN)
         end
         if key.DOWN.name == "X" then
            del()
         end
         if tonumber(key.DOWN.name) then
            local num = tonumber(key.DOWN.name)
            active_as = Areas_TB[num] and Areas_TB[num] or nil
            for _, v in pairs(ghosts) do
               reaper.JS_Composite_Unlink(track_window, v.bm)
            end
         end
      elseif key.HOLD then
      elseif key.UP then
      end
   end
end

local function Main()
   xpcall(
      function()
         GetTracksXYH() -- GET XYH INFO OF ALL TRACKS
         Mouse_Data_From_Arrange()
         --GetTrackZoneInfo()
         check_keys()

         if not ZONE and not BLOCK then
            CreateAreaFromSelection()
         end -- CREATE AS IF IN ARRANGE WINDOW AND NON AS ZONES ARE CLICKED

         Draw(Areas_TB, track_window) -- DRAWING CLASS

         if copy and #Areas_TB ~= 0 then
            generic_table_find()
         end

         check_undo_history()

         reaper.defer(Main)
      end,
      crash
   )
end

function Exit() -- DESTROY ALL BITMAPS ON REAPER EXIT
   for i = 1, #Areas_TB do
      reaper.JS_LICE_DestroyBitmap(Areas_TB[i].bm)
   end
   for _, v in pairs(ghosts) do
      reaper.JS_LICE_DestroyBitmap(v.bm)
   end
   if reaper.ValidatePtr(track_window, "HWND") then
      refresh_reaper()
   end
   for i = 1, #Key_TB do
      if Key_TB[i].func then
         Key_TB[i]:intercept(-1)
      end
   end
end

for i = 1, 255 do
   local func
   local name = string.char(i)
   if i == 16 then
      name = "Shift"
   elseif i == 17 then
      name = "Ctrl"
   elseif i == 18 then
      name = "Alt"
   elseif i == 13 then
      name = "Return"
   elseif i == 8 then
      name = "Backspace"
   elseif i == 32 then
      name = "Space"
   elseif i == 20 then
      name = "Caps-Lock"
   elseif i == 27 then
      name = "ESC"
      func = remove
   elseif i == 9 then
      name = "TAB"
   elseif i == 192 then
      name = "~"
   elseif i == 91 then
      name = "Win"
   elseif i == 45 then
      name = "Insert"
   elseif i == 46 then
      name = "Del"
   elseif i == 36 then
      name = "Home"
   elseif i == 35 then
      name = "End"
   elseif i == 33 then
      name = "PG-Up"
   elseif i == 34 then
      name = "PG-Down"
   end
   Key_TB[#Key_TB + 1] = Key:new({i}, name, func)
end

Key_TB[#Key_TB + 1] = Key:new({17, 67}, "COPY", copy_mode) -- COPY (TOGGLE)
Key_TB[#Key_TB + 1] = Key:new({17, 86}, "PASTE", copy_paste) -- PASTE

reaper.atexit(Exit)
Main()
