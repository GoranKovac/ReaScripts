--[[
 * ReaScript Name: Area51 Selection ALPHA
 * Author: Sexan
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 0.40
 * Provides: Modules/*.lua
--]]

--[[
 * Changelog:
 * v0.40 (2020-05-18)
   + Potential fix for OSX tap thingy
--]]
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
package.cursor = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "Cursors\\" -- GET DIRECTORY FOR CURSORS
local reaper = reaper

if not reaper.APIExists("JS_ReaScriptAPI_Version") then
  reaper.MB( "JS_ReaScriptAPI is required for this script", "Please download it from ReaPack", 0 )
  return reaper.defer(function() end)
 else
   local version = reaper.JS_ReaScriptAPI_Version()
   if version < 1.002 then
     reaper.MB( "Your JS_ReaScriptAPI version is " .. version .. "\nPlease update to latest version.", "Older version is installed", 0 )
     return reaper.defer(function() end)
   end
end

require("Modules/Area_51_class")      -- AREA FUNCTIONS SCRIPT
require("Modules/Area_51_ghosts")     -- AREA MOUSE INPUT HANDLING
require("Modules/Area_51_keyboard")   -- AREA KEYBOARD INPUT HANDLING
require("Modules/Area_51_mouse")      -- AREA MOUSE INPUT HANDLING
require("Modules/Area_51_functions")  -- AREA FUNCTION CALL
require("Modules/Area_51_functions_code")  -- AREA FUNCTIONS CODE
require("Modules/Area_51_key_functions")  -- AREA KEY FUNCTIONS

local _, _, section, cmdID = reaper.get_action_context()
reaper.SetToggleCommandState( section, cmdID, 1 )
reaper.RefreshToolbar2( section, cmdID )

local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local last_proj_change_count = reaper.GetProjectStateChangeCount(0)
local last_project, last_project_fn = reaper.EnumProjects(-1, "")
local WML_intercept = reaper.JS_WindowMessage_Intercept(track_window, "WM_LBUTTONDOWN", false) -- INTERCEPT MOUSE L BUTTON

local Areas_TB = {}
local CPY_TBL = {}
local active_as
local CHANGE
local ICON_INT
copy = false

local crash = function(errObject)
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
   Exit()
end

function msg(m)
   reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local ceil, floor = math.ceil, math.floor
function Round(n)
   return n % 1 >= 0.5 and ceil(n) or floor(n)
end

function To_screen(x,y)
   local sx, sy = reaper.JS_Window_ClientToScreen( track_window, x, y )
   return sx, sy
end

function To_client(x,y)
   local cx, cy = reaper.JS_Window_ScreenToClient( track_window, x, y )
   return cx, cy
end

function Get_window_under_mouse()
   if mouse.l_click or mouse.l_down then
      local old_windowUnderMouse = reaper.JS_Window_FromPoint(mouse.ox, mouse.oy)
      if old_windowUnderMouse ~= track_window then
         return true
      end
   end
   return false
end

function Has_val(tab, val, guid)
   local val_n = guid and guid or val
   for i = 1, #tab do
      local in_table = guid and tab[i].guid or tab[i]
      if in_table == val_n then
         return tab[i]
      end
   end
end

-- FIND AREA WHICH HAS LOWEST TIME START
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

function Get_folder_last_child(tr)
   if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") <= 0 then return end -- ignore tracks and last folder child
   local depth, last_child = 0
   local folderID = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") - 1
   for i = folderID + 1, reaper.CountTracks(0) - 1 do -- start from first track after folder
     local child = reaper.GetTrack(0, i)
     local currDepth = reaper.GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
     last_child = child
     depth = depth + currDepth
     if depth <= -1 then
       break
     end --until we are out of folder
   end
   return last_child -- if we only getting folder childs
 end

function Snap_val(val)
   return reaper.GetToggleCommandState(1157) == 1 and reaper.SnapToGrid(0, val) or val
end

local function Check_undo_history()
   local proj_change_count = reaper.GetProjectStateChangeCount(0)
   if proj_change_count > last_proj_change_count then
      local last_action = reaper.Undo_CanUndo2(0)
      if not last_action then
         return
      end
      last_action = last_action:lower()
      if last_action:find("A51") then
         make_undo()
      elseif last_action:find("remove tracks") then --or last_action:find("area51") then
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


local function get_invisible_tracks()
   local cnt = 0
   for i = 1, reaper.CountTracks(0) do
      local tr = reaper.GetTrack(0, i - 1)
      local tr_vis = reaper.IsTrackVisible(tr, false)
      if tr_vis then
         cnt = cnt + 1
      end
   end
   return cnt
end

-- SINCE TRACKS CAN BE HIDDEN, LAST VISIBLE TRACK COULD BE ANY NOT NECESSARY TAST PROJECT TRACK
local function Get_last_visible_track()
   if reaper.CountTracks(0) == 0 then return end
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

-- MAIN FUNCTION FOR FINDING TRACKS COORDINATES (RETURNS CLIENTS COORDINATES)
local TBH
function GetTracksXYH()
   if reaper.CountTracks(0) == 0 then return end
   TBH = {}
   -- ONLY ADD MASTER TRACK IF VISIBLE IN TCP
   local master_tr_visibility = reaper.GetMasterTrackVisibility()
   if master_tr_visibility == 1 or master_tr_visibility == 3 then
      local master_tr = reaper.GetMasterTrack(0)
      local m_tr_h = reaper.GetMediaTrackInfo_Value(master_tr, "I_TCPH")
      local m_tr_t = reaper.GetMediaTrackInfo_Value(master_tr, "I_TCPY")
      local m_tr_b = m_tr_t + m_tr_h
      TBH[master_tr] = {t = m_tr_t, b = m_tr_b, h = m_tr_h, vis = true, ID = 0}
      for j = 1, reaper.CountTrackEnvelopes(master_tr) do
         local m_env = reaper.GetTrackEnvelope(master_tr, j - 1)
         local m_env_h = reaper.GetEnvelopeInfo_Value(m_env, "I_TCPH")
         local m_env_t = reaper.GetEnvelopeInfo_Value(m_env, "I_TCPY") + m_tr_t
         local m_env_b = m_env_t + m_env_h
         TBH[m_env] = {t = m_env_t, b = m_env_b, h = m_env_h}
      end
   end

   local last_Tr = Get_last_visible_track()
   local last_Tr_total = reaper.GetMediaTrackInfo_Value(last_Tr, "I_WNDH") -- USE THIS BECAUSE TRACK MAY HAVE ENVELOPES
   local last_Tr_h = reaper.GetMediaTrackInfo_Value(last_Tr, "I_TCPH")
   local last_Tr_t = reaper.GetMediaTrackInfo_Value(last_Tr, "I_TCPY")

   local visible_index = 0
   for i = 1, reaper.CountTracks(0) do
      local tr = reaper.GetTrack(0, i - 1)
      local tr_vis = reaper.IsTrackVisible(tr, false)
      local tr_h = reaper.GetMediaTrackInfo_Value(tr, "I_TCPH")
      local tr_t = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY")
      local tr_b = tr_t + tr_h
      if tr_vis then
         visible_index = visible_index + 1
      end

      local ID = tr_vis and visible_index or nil
      TBH[tr] = {t = tr_t, b = tr_b, h = tr_h, used = false, vis = tr_vis, ID = ID}
      if ID then
         local last_Tr_b = (last_Tr_t + (last_Tr_total*ID)) + last_Tr_total
         TBH["INV" .. ID] = {t = last_Tr_t + (last_Tr_total*ID), b = last_Tr_b, h = last_Tr_total, used = false, vis = true}
      end

      for j = 1, reaper.CountTrackEnvelopes(tr) do
         local env = reaper.GetTrackEnvelope(tr, j - 1)
         local env_h = reaper.GetEnvelopeInfo_Value(env, "I_TCPH")
         local env_t = reaper.GetEnvelopeInfo_Value(env, "I_TCPY") + tr_t
         local env_b = env_t + env_h
         TBH[env] = {t = env_t, b = env_b, h = env_h}
      end
   end
end

function Get_tr_TBH(tr)
   if TBH[tr] then
      return TBH[tr].t, TBH[tr].h, TBH[tr].b, TBH[tr].th
   end
end

function Set_active_as(act)
   active_as = act and act or nil
end

function Set_copy_tbl(tbl)
   CPY_TBL = tbl
end

function Get_area_table(name)
   if name == "Areas" then return Areas_TB end
   if name == "Active" then return active_as end
   if name == "Copy" then return CPY_TBL end
   local tbl = active_as and {active_as} or Areas_TB
   return #tbl ~= 0 and tbl
end

-- FINDS TRACKS THAT ARE IN AREA OR MOUSE SWIPED RANGE
local function GetTracksFromRange(y_t, y_b)
   local range_tracks = {}
   for track, coords in pairs(TBH) do
      if coords.t >= y_t and coords.b <= y_b and coords.h ~= 0 then
         range_tracks[#range_tracks+1] = {track = track, v = coords.t}
      end
   end
   -- WE NEED TO SORT TRACKS FROM TOP TO BOTTOM BECAUSE PAIRS DOES NOT HAVE ORDER (TRACK 1 CAN BE AT 5th POSITION, TRACK 3 AT 1st POSITION ETC)
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

-- FINDS TRACK THAT IS UNDER MOUSE AND RETURNS ITS POSITION AND VALUES
local function Get_track_under_mouse(x, y)
   local _, cy = To_client(x, y)
   local track, env_info = reaper.GetTrackFromPoint(x, y)
   if track == reaper.GetMasterTrack( 0 ) and reaper.GetMasterTrackVisibility() == 0 then return end -- IGNORE DOCKED MASTER TRACK
   if track and env_info == 0 then
      if not FOLDER_MOD then
         return track, TBH[track].t, TBH[track].b, TBH[track].h
      else
         if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            return track, TBH[track].t, TBH[Get_folder_last_child(track)].b
         else
            return track, TBH[track].t, TBH[track].b, TBH[track].h
         end
      end
   elseif track and env_info == 1 then
      for i = 1, reaper.CountTrackEnvelopes(track) do
         local env = reaper.GetTrackEnvelope(track, i - 1)
         if TBH[env].t <= cy and TBH[env].b >= cy then
            return env, TBH[env].t, TBH[env].b, TBH[env].h
         end
      end
   end
end

function Get_zoom_and_arrange_start(x, w)
   local zoom_lvl = reaper.GetHZoomLevel() -- HORIZONTAL ZOOM LEVEL
   local Arr_start_time = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW
   return zoom_lvl, Arr_start_time
end

-- GET PROJECT CHANGES, WE USE THIS TO PREVENT DRAW LOOPING AND REDUCE CPU USAGE
local prev_Arr_end_time, prev_proj_state, last_scroll, last_scroll_b, last_pr_t, last_pr_h
function Arrange_view_info()
   local last_pr_tr = Get_last_visible_track()
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

-- TOTAL HEIGHT OF AREA SELECTION IS FIRST TRACK IN THE CURRENT AREA AND LAST TRACK IN THE CURRENT AREA (RANGE)
function GetTrackTBH(tbl)
   if not tbl then return end
   if TBH[tbl[1].track] and TBH[tbl[#tbl].track] then
      if TBH[tbl[#tbl].track].b - TBH[tbl[1].track].t == 0 then
         return TBH[tbl[#tbl].track].t, TBH[tbl[1].track].b - TBH[tbl[#tbl].track].t
      else
         return TBH[tbl[1].track].t, TBH[tbl[#tbl].track].b - TBH[tbl[1].track].t
      end
   end
end

-- CHECK IF VALUES ARE REVERSED AND RETURN THEM THAT WAY
local function Check_top_bot(top_start, top_end, bot_start, bot_end) -- CHECK IF VALUES GOT REVERSED
   if bot_end <= top_start then
      return bot_start, top_end
   else
      return top_start, bot_end
   end
end

-- CHECK IF VALUES ARE REVERSED AND RETURN THEM THAT WAY
function Check_left_right(val1, val2) -- CHECK IF VALUES GOT REVERSED
   if val2 < val1 then
      return val2, val1
   else
      return val1, val2
   end
end

-- CHECK IF MOUSE IS MOVING IN X OR Y DIRRECTION (USING TO REDUCE CPU USAGE)
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

function DeleteCopy(tab)
   if not tab then return end
   for i = #tab, 1, -1 do
      reaper.JS_LICE_DestroyBitmap(tab[i].bm) -- DESTROY BITMAPS FROM AS THAT WILL BE DELETED
      table.remove(tab, i) -- REMOVE AS FROM TABLE
   end
end

-- DELETE AREA
function RemoveAsFromTable(tab, val, job)
   for i = #tab, 1, -1 do
      local in_table = tab[i].guid
      if job == "==" then
         if in_table == val then
            Remove_ghost(tab[i].sel_info)
            reaper.JS_LICE_DestroyBitmap(tab[i].bm) -- DESTROY BITMAPS FROM AS THAT WILL BE DELETED
            table.remove(tab, i) -- REMOVE AS FROM TABLE
         end
      elseif job == "~=" then
         if in_table ~= val then -- REMOVE ANY AS THAT HAS DIFFERENT GUID
            Remove_ghost(tab[i].sel_info)
            reaper.JS_LICE_DestroyBitmap(tab[i].bm) -- DESTROY BITMAPS FROM AS THAT WILL BE DELETED
            table.remove(tab, i) -- REMOVE AS FROM TABLE
         end
      end
   end
end

function Remove_ghost(tbl)
   if not tbl then return end
   for i = 1, #tbl do
      if tbl[i].ghosts then
         for j = 1, #tbl[i].ghosts do
            reaper.JS_LICE_DestroyBitmap(tbl[i].ghosts[j].bm)
         end
      end
   end
end

-- DELETE OR UNLINK GHOSTS
function Ghost_unlink_or_destroy(tbl, job,area)
   if not tbl then return end
   for a = 1, #tbl do
      if area then reaper.JS_Composite_Unlink(track_window, tbl[a].bm, true) end
      if not tbl[a].sel_info then return end
      for i = 1, #tbl[a].sel_info do
         if tbl[a].sel_info[i].ghosts then
            for j = 1, #tbl[a].sel_info[i].ghosts do
               local ghost = tbl[a].sel_info[i].ghosts[j]
               if job == "Delete" then
                  reaper.JS_LICE_DestroyBitmap(ghost.bm)
               elseif job == "Unlink" then
                  reaper.JS_Composite_Unlink(track_window, ghost.bm, true)
               end
            end
         end
      end
   end
end

-- CREATE TABLE WITH ALL AREA INFORMATION NEEDED
local function CreateAreaTable(x, y, w, h, guid, time_start, time_end)
   local Element = Get_class_tbl()
   if not Has_val(Areas_TB, nil, guid) then
      Areas_TB[#Areas_TB + 1] = Element:new(x, y, 1, 1, guid, time_start, time_end - time_start) -- CREATE NEW CLASS ONLY IF DOES NOT EXIST
   else
      Areas_TB[#Areas_TB].time_start = time_start
      Areas_TB[#Areas_TB].time_dur = time_end - time_start
      Areas_TB[#Areas_TB].x = x
      Areas_TB[#Areas_TB].y = y
      Areas_TB[#Areas_TB].w = w
      Areas_TB[#Areas_TB].h = h
   end
end

-- CONVERTS TIME TO PIXELS
function Convert_time_to_pixel(t_start, t_end)
   local zoom_lvl, Arr_start_time = Get_zoom_and_arrange_start()
   local x = Round((t_start - Arr_start_time) * zoom_lvl) -- convert time to pixel
   local w = Round(t_end * zoom_lvl) -- convert time to pixel
   return x, w
end

-- GET ITEMS, ENVELOPES, ENVELOPE POINTS, AI IF ANY EXIST
local function GetTrackData(tbl, as_start, as_end)
   for i = 1, #tbl do
      if reaper.ValidatePtr(tbl[i].track, "MediaTrack*") then
         tbl[i].items = get_items_in_as(tbl[i].track, as_start, as_end) -- TRACK MEDIA ITEMS
         tbl[i].ghosts = Get_item_ghosts(tbl[i].track, tbl[i].items, as_start, as_end)
      elseif reaper.ValidatePtr(tbl[i].track, "TrackEnvelope*") then
         local _, env_name = reaper.GetEnvelopeName(tbl[i].track)
         tbl[i].env_name = env_name -- ENVELOPE NAME
         tbl[i].env_points = get_as_tr_env_pts(tbl[i].track, as_start, as_end) -- ENVELOPE POINTS
         tbl[i].AI = get_as_tr_AI(tbl[i].track, as_start, as_end) -- AUTOMATION ITEMS
         tbl[i].ghosts = Get_AI_or_ENV_ghosts(tbl[i].track, tbl[i].env_points, tbl[i].AI, as_start, as_end)
      end
   end
   return tbl
end

-- ALL DATA FROM THAT TRACKS (ITEMS,ENVELOPES,AIS)
function GetSelectionInfo(tbl)
   if not tbl then return end
   local area_top, area_bot, area_start, area_end = tbl.y, tbl.y + tbl.h, tbl.time_start, tbl.time_start + tbl.time_dur
   local tracks = GetTracksFromRange(area_top, area_bot) -- GET TRACK RANGE
   local data = GetTrackData(tracks, area_start, area_end) -- GATHER ALL INFO
   return data
end

function Change()
   local as_top, as_bot = Check_top_bot(mouse.ort, mouse.orb, mouse.last_r_t, mouse.last_r_b) -- RANGE ON MOUSE CLICK HOLD AND RANGE WHILE MOUSE HOLD
   local as_left, as_right = Check_left_right(mouse.op, mouse.p) -- CHECK IF START & END TIMES ARE REVERSED
   return Check_change(as_left, as_right, as_top, as_bot)
end

-- MAIN FUNCTION FOR CREATING AREAS FROM MOUSE MOVEMENT
local function CreateAreaFromSelection()
   if not ARRANGE and not CREATING then return end
   local as_top, as_bot = Check_top_bot(mouse.ort, mouse.orb, mouse.last_r_t, mouse.last_r_b) -- RANGE ON MOUSE CLICK HOLD AND RANGE WHILE MOUSE HOLD
   local as_left, as_right = Check_left_right(mouse.op, mouse.p) -- CHECK IF START & END TIMES ARE REVERSED
   DRAWING = CHANGE

   if mouse.l_down and mouse.DRAW_AREA then
      if DRAWING then
         CREATING = true
         if not guid then
            guid = reaper.genGuid()--mouse.Ctrl_Shift_Alt() and reaper.genGuid() or "single"
         end

         local x, w = Convert_time_to_pixel(as_left, as_right - as_left)
         local y, h = as_top, as_bot - as_top
         CreateAreaTable(x, y, w, h, guid, as_left, as_right)
      end
   elseif (mouse.l_up or not mouse.DRAW_AREA) and CREATING then --(mouse.l_up and CREATING) 
      Areas_TB[#Areas_TB].sel_info = GetSelectionInfo(Areas_TB[#Areas_TB])
      table.sort(
         Areas_TB,
         function(a, b)
            return a.y < b.y
         end
      ) -- SORT AREA TABLE BY Y POSITION (LOWEST TO HIGHEST)
      CREATING, guid, DRAWING = nil, nil, nil
   end
end

-- IF TRACK IS DELETED FROM PROJECT REMOVE IT FROM AREAS TABLE
function ValidateRemovedTracks()
   if #Areas_TB == 0 then return end
   for i = #Areas_TB, 1, -1 do
      for j = #Areas_TB[i].sel_info, 1, -1 do
         if not reaper.ValidatePtr(Areas_TB[i].sel_info[j].track, "MediaTrack*") or reaper.ValidatePtr(Areas_TB[i].sel_info[j].track, "TrackEnvelope*") then
            if Areas_TB[i].sel_info[j].ghosts then
               for k = 1, #Areas_TB[i].sel_info[j].ghosts do
                  local ghost = Areas_TB[i].sel_info[j].ghosts[k]
                  reaper.JS_LICE_DestroyBitmap(ghost.bm)
               end
            end
            table.remove(Areas_TB[i].sel_info, j)
            if #Areas_TB[i].sel_info == 0 then
               reaper.JS_LICE_DestroyBitmap(Areas_TB[i].bm)
               table.remove(Areas_TB, i)
            end
         end
      end
   end
   if #Areas_TB == 0 then
      if copy then Copy_mode() end
   end
end

-- GET ENVELOPE ID
local function GetEnvNum(env)
   if reaper.ValidatePtr(env, "MediaTrack*") then return end
   local par_tr = reaper.Envelope_GetParentTrack( env )
   for i = 1, reaper.CountTrackEnvelopes(par_tr) do
      local tr_env = reaper.GetTrackEnvelope(par_tr, i - 1)
      if tr_env == env then
         return i-1 -- MATCH MODE
      end
   end
end

-- GET MEDIA TRACK OR PARENT OF ENVELOPE
function Convert_to_track(tr)
   return reaper.ValidatePtr(tr, "TrackEnvelope*") and reaper.Envelope_GetParentTrack(tr) or tr
end

function env_offset_new(src_tr_tbl, old, tr, env_name)
   local tbl = Get_area_table()
   local cur_tr = mouse.last_tr
   local first_tr = copy and tbl[1].sel_info[1].track or mouse.otr
   if type(tr) == "string" then return end -- AVOID INVISIBLE TRACKS
   if reaper.ValidatePtr(first_tr, "TrackEnvelope*") and not Validate_tracks_type(src_tr_tbl,"MediaTrack") then -- ONLY ENVELOPES ARE SELECTED
      if reaper.ValidatePtr(cur_tr, "TrackEnvelope*") then
         local m_num = GetEnvNum(cur_tr)
         local first_num = GetEnvNum(first_tr)
         local tr_num = GetEnvNum(old)
         local first_area_tr_num = GetEnvNum(src_tr_tbl[1].track)
         local last_area_tr_num = GetEnvNum(src_tr_tbl[#src_tr_tbl].track)
         local delta_test = Limit_offset_range(m_num - first_num, first_area_tr_num, last_area_tr_num, 0, reaper.CountTrackEnvelopes(Convert_to_track(cur_tr))-1)--Convert_to_track(first_tr)
         local new_env = reaper.GetTrackEnvelope(tr, delta_test + tr_num)
         return new_env
      end
   end

   if reaper.ValidatePtr(first_tr, "MediaTrack*") or Validate_tracks_type(src_tr_tbl,"MediaTrack") or reaper.ValidatePtr(cur_tr, "MediaTrack*") then -- IF MEDIA TRACKS ARE ALSO IN SELECTION RETURN ONLY MATCHED
      local par_tr = Convert_to_track(tr)
      for i = 1, reaper.CountTrackEnvelopes(par_tr) do
         local tr_env = reaper.GetTrackEnvelope(par_tr, i - 1)
         local _, tr_env_name = reaper.GetEnvelopeName(tr_env)
         if tr_env_name == env_name then
            return tr_env
         end
      end
   end
end

function Limit_offset_range(delta, first, last, min, max)
   delta = delta + first >= min and delta or min - first
   delta = delta + last <= max and delta or max - last
   return delta
end

function Mouse_track_offset(first)
   local tbl = Get_area_table()
   local _, m_cy = To_client(0, mouse.y)

   local first_area = copy and TBH[Convert_to_track(tbl[1].sel_info[1].track)].ID or TBH[Convert_to_track(first)].ID

   local last_project_tr = Get_last_visible_track()
   local l_h = reaper.GetMediaTrackInfo_Value(last_project_tr, "I_WNDH") -- USE THIS BECAUSE TRACK MAY HAVE ENVELOPES
   local l_y = reaper.GetMediaTrackInfo_Value(last_project_tr, "I_TCPY")
   --local last_Tr_h = reaper.GetMediaTrackInfo_Value(last_project_tr, "I_TCPH")
   --local l_y, l_h, l_b = Get_tr_TBH(last_project_tr)

   local cur_m_tr = mouse.last_tr
   local first_m_tr = copy and tbl[1].sel_info[1].track or mouse.otr
   local cur_m_tr_num = TBH[Convert_to_track(cur_m_tr)].ID

   local first_m_tr_num = TBH[Convert_to_track(first_m_tr)].ID

   -- local mouse_inv_tracks = (l_b ~= 0 and m_cy > l_b) and floor((m_cy - l_b) / l_h) + 1 or 0 -- IF MOUSE IS UNDER LAST PROJECT TRACK START COUTNING VOODOO
   local mouse_inv_tracks = (l_y+l_h) ~= 0 and m_cy > (l_y+l_h) and floor((m_cy - (l_y+l_h)) / l_h) + 1 or 0 -- IF MOUSE IS UNDER LAST PROJECT TRACK START COUTNING VOODOO
   local mouse_tr_offset = cur_m_tr_num - first_m_tr_num + mouse_inv_tracks

   local master_tr_visibility = reaper.GetMasterTrackVisibility()
   local min_tr = (master_tr_visibility == 1 or master_tr_visibility == 3) and 0 or 1 -- if master track is visible lowest track id is 0

   mouse_tr_offset = Limit_offset_range(mouse_tr_offset, first_area, first_area, min_tr, get_invisible_tracks()+1)-- LIMIT OFFSET RANGE TO FROM 1 TRACK IN PROJECT TO LAST TRACK + AREA SIZE
   return mouse_tr_offset
end

function Validate_tracks_type(tbl,tr_type)
   for i = 1, #tbl do
      if reaper.ValidatePtr(tbl[i].track, tr_type .. "*") then return true end
   end
end

local function find_visible_tracks(num, inv_tr_num)
   for k, v in pairs(TBH) do
      if num <= inv_tr_num then
         if num == v.ID then
            return k
         end
      else
         return "INV" .. num - inv_tr_num
      end
   end
end

function Track_from_offset(tr, offset)
   local inv_tr_num = get_invisible_tracks()
   local tr_num = TBH[Convert_to_track(tr)].ID
   local under = (tr_num + offset) > inv_tr_num and (tr_num + offset) - inv_tr_num or nil
   local offset_tr = find_visible_tracks(tr_num + offset, inv_tr_num) or Get_last_visible_track() -- IF THERE IS NO OFFSET_TR IT MEANS ITS UNDER LAST TRACK
   return offset_tr, under
end

function Check_project()
   local proj, projfn = reaper.EnumProjects(-1, "")
   if last_project ~= proj then
      Remove()
      last_proj_change_count = reaper.GetProjectStateChangeCount(0)
      last_project = proj
   end
end

local reaper_cursors_list = {
   {187, "C"}, -- MOVE
   {185, "DRAW"}, -- DRAW
   {462, "L"}, -- LEFT EDGE
   {462, "R"}, -- RIGHT EDGE
   {530, "T"}, -- FADE RIGHT
   {530, "B"} -- FADE LEFT
}

function check_window_in_front()
   if reaper.JS_Window_FromPoint(mouse.x, mouse.y) ~= track_window then return true end
end
function Change_cursor(zone)
   if mouse.DRAW_AREA then return end
   if check_window_in_front() then zone = nil end
   if zone then
      if not ICON_INT then
         reaper.JS_WindowMessage_Intercept(track_window, "WM_SETCURSOR", false)
         ICON_INT = true
      end
      for i = 1, #reaper_cursors_list do
         if zone == reaper_cursors_list[i][2] then
            local cursor = reaper.JS_Mouse_LoadCursor(reaper_cursors_list[i][1])
            reaper.JS_Mouse_SetCursor(cursor)
         end
      end
   else
      if ICON_INT then
         reaper.JS_WindowMessage_Release(track_window, "WM_SETCURSOR")
         ICON_INT = false
      end
   end
end

local last_m_tr, last_m_p, last_mc
function check_mouse_change()
   if mouse.p ~= last_m_p or mouse.tr ~= last_m_tr or mouse.l_click ~= last_mc then
      last_m_p = mouse.p
      last_m_tr = mouse.tr
      last_mc = mouse.l_click
      return true
   end
end

local function Main()
   xpcall(
      function()
         GetTracksXYH() -- GET XYH INFO OF ALL TRACKS
         Check_undo_history()
         Check_project()
         mouse = MouseInfo()
         mouse.tr, mouse.r_t, mouse.r_b = Get_track_under_mouse(mouse.x, mouse.y)
         CHANGE = ARRANGE and Change() or false
         WINDOW_IN_FRONT = Get_window_under_mouse()
         Track_keys()
         Intercept_reaper_key(Areas_TB) -- WATCH TO INTERCEPT KEYS WHEN AREA IS DRAWN (ON SCREEN)
         Pass_thru()
         if not BLOCK then
            if mouse.DRAW_AREA or CREATING then --and mouse.Shift() then
               CreateAreaFromSelection()
            end
            if mouse.Ctrl_Shift() and not mouse.Ctrl_Shift_Alt() and mouse.l_click then -- REMOVE AREAS ON CLICK
              if #Areas_TB ~= 0 then
                  Remove()
              end
            end
         end -- CREATE AS IF IN ARRANGE WINDOW AND NON AS ZONES ARE CLICKED
         Draw(Areas_TB) -- DRAWING CLASS
         reaper.defer(Main)
      end,
      crash
   )
end

function Exit() -- DESTROY ALL BITMAPS ON REAPER EXIT
   reaper.JS_WindowMessage_Release(track_window, "WM_LBUTTONDOWN")
   reaper.JS_WindowMessage_Release(track_window, "WM_SETCURSOR")
   if get_buffer_bm() then reaper.JS_LICE_DestroyBitmap(get_buffer_bm()) end -- KILL ZONE BUFFER BM (DRAGING/MOVING BM)
   Release_reaper_keys()
   RemoveAsFromTable(Areas_TB, "Delete", "~=")
   DeleteCopy(CPY_TBL)
   reaper.SetToggleCommandState( section, cmdID, 0 )
   reaper.RefreshToolbar2( section, cmdID )
end
reaper.atexit(Exit)
Main()
