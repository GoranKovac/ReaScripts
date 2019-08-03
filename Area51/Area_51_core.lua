package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
package.cursor = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "Cursors\\" -- GET DIRECTORY FOR CURSORS

require("Area_51_class") -- AREA FUNCTIONS SCRIPT
require("Area_51_functions") -- AREA CLASS SCRIPT
require("Area_51_input") -- AREA INPUT HANDLING/SETUP
require("Area_51_mouse")

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
                                    "Reaper:       \t" ..
                                        reaper.GetAppVersion() .. "\n" .. "Platform:     \t" .. reaper.GetOS()
        )
    end
end

local main_wnd          = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window      = reaper.JS_Window_FindChildByID(main_wnd, 1000) -- GET TRACK VIEW
local track_window_dc   = reaper.JS_GDI_GetWindowDC(track_window)
local mixer_wnd         = reaper.JS_Window_Find("mixer", true) -- GET MIXER -- tHIS NEEDS TO BE CONVERTED TO ID , AND I STILL DO NOT KNOW HOW TO FIND THEM
local Areas_TB          = {}
local Key_TB            = {}

local active_as

local last_proj_change_count = reaper.GetProjectStateChangeCount(0)

function msg(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

local ceil, floor = math.ceil, math.floor
function round(n)
    return n % 1 >= 0.5 and ceil(n) or floor(n)
end

local TBH
function GetTracksXYH_Info()
    TBH = {}
    local array = reaper.new_array({}, 1000)
    reaper.JS_Window_ArrayAllChild(reaper.GetMainHwnd(), array)
    local t = array.table()

    for i, adr in ipairs(t) do
        local handl = reaper.JS_Window_HandleFromAddress(adr)
        local track = reaper.JS_Window_GetLongPtr(handl, "USER")
        if reaper.JS_Window_GetParent(reaper.JS_Window_GetParent(handl)) ~= mixer_wnd then
            if reaper.ValidatePtr(track, "MediaTrack*") or reaper.ValidatePtr(track, "TrackEnvelope*") then
                local _, _, top, _, bottom = reaper.JS_Window_GetClientRect(handl)
                TBH[track] = {t = top, b = bottom, h = bottom - top, vis = reaper.JS_Window_IsVisible(handl)}
            end
        end
    end
end

function Project_info()
    local proj_state                    = reaper.GetProjectStateChangeCount(0) -- PROJECT STATE
    local zoom_lvl                      = reaper.GetHZoomLevel() -- HORIZONTAL ZOOM LEVEL
    local _, scroll, _, _, scroll_b     = reaper.JS_Window_GetScrollInfo(track_window, "SB_VERT") -- GET VERTICAL SCROLL
    local Arr_start_time, Arr_end_time  = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW
    local Arr_pixel                     = round(Arr_start_time * zoom_lvl) -- ARRANGE VIEW POSITION CONVERT TO PIXELS
    local _, x_view_start, y_view_start, x_view_end, y_view_end = reaper.JS_Window_GetRect(track_window) -- GET TRACK WINDOW X-Y COORDINATES

    return zoom_lvl, Arr_start_time, Arr_end_time, Arr_pixel, x_view_start, y_view_start, x_view_end, y_view_end, proj_state, scroll, scroll_b
end

local prev_total_pr_h, prev_Arr_end_time, prev_proj_state, last_scroll, last_scroll_b, last_pr_t, last_pr_h
function Status() -- THIS IS USED TO CHECK CHANGES IN THE PROJECT FOR DRAWING
    local last_pr_tr = get_last_visible_track()
    local zoom_lvl,
        Arr_start_time,
        Arr_end_time,
        Arr_pixel,
        x_view_start,
        y_view_start,
        x_view_end,
        y_view_end,
        proj_state,
        scroll,
        scroll_b = Project_info()

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

local function Has_val(tab, val, guid)
    local val_n = guid and guid or val

    for i = 1, #tab do
        local in_table = guid and tab[i].guid or tab[i]
        if in_table == val_n then
            return tab[i]
        end
    end
end

local function GetTrackFromMouseRange(t, b, tr)
    local trackview_window
    local range_tracks  = {}
    local _, _, arr_top = reaper.JS_Window_GetRect(track_window)
    local window        = reaper.JS_Window_GetRelated(track_window, "NEXT")
    while window do
        local _, _, top = reaper.JS_Window_GetRect(window)
        if top == arr_top then
            trackview_window = reaper.JS_Window_GetRelated(window, "CHILD")
        end
        window = reaper.JS_Window_GetRelated(window, "NEXT")
    end
    local window = reaper.JS_Window_GetRelated(trackview_window, "CHILD")
    while window do
        if reaper.JS_Window_IsVisible(window) then
            local _, _, top, _, bottom = reaper.JS_Window_GetRect(window)
            if top >= t and bottom <= b then -- IF TRACK IS IN THE MOUSE ZONE RANGE
                local pointer = reaper.JS_Window_GetLongPtr(window, "USERDATA")
                if reaper.ValidatePtr(pointer, "MediaTrack*") then
                    if not Has_val(range_tracks, pointer) then
                        range_tracks[#range_tracks + 1] = {track = pointer}
                    end -- ADD TRACKS TO TABLE IF THEY ARE NOT ALREADY THERE
                elseif reaper.ValidatePtr(pointer, "TrackEnvelope*") then
                    if not Has_val(range_tracks, pointer) then
                        range_tracks[#range_tracks + 1] = {track = pointer}
                    end
                end
            end
        end
        window = reaper.JS_Window_GetRelated(window, "NEXT")
    end
    return range_tracks
end

local function GetTrackFromPoint()
    local trackview_window
    local _, _, arr_top = reaper.JS_Window_GetRect(track_window)
    local window = reaper.JS_Window_GetRelated(track_window, "NEXT")
    while window do
        local _, _, top = reaper.JS_Window_GetRect(window)
        if top == arr_top then
            trackview_window = reaper.JS_Window_GetRelated(window, "CHILD")
        end
        window = reaper.JS_Window_GetRelated(window, "NEXT")
    end
    local window = reaper.JS_Window_GetRelated(trackview_window, "CHILD")
    while window do
        if reaper.JS_Window_IsVisible(window) then -- DO NOT ALLOW TRACKING MOUSE IF THERE IS WINDOW IN FRONT OF ARRANGE AND MOUSE IS ON IT
            local _, _, top, _, bottom = reaper.JS_Window_GetRect(window)
            if top <= mouse.y and bottom > mouse.y then -- IF MOUSE IN THE TRACK
                local pointer = reaper.JS_Window_GetLongPtr(window, "USERDATA")
                if reaper.ValidatePtr(pointer, "MediaTrack*") then -- ON MEDIA TRACK
                    if reaper.GetMediaTrackInfo_Value(pointer, "I_FOLDERDEPTH") == 1 then
                    --     _, _, bottom = get_folder(pointer)
                    end
                    return pointer, top, bottom --> Track, segment
                elseif reaper.ValidatePtr(pointer, "TrackEnvelope*") then -- ON ENVELOPE TRACK
                    return pointer, top, bottom --> Envelope, segment
                end
            end
        end
        window = reaper.JS_Window_GetRelated(window, "NEXT") --> window or nil
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
    local total_h = 0
    local t, b, h

    for i = #tbl, 1, -1 do -- NEEDS TO BE REVERSED OR IT DRAWS SOME WEIRD SHIT
        local track = tbl[i].track
        if TBH[track] and TBH[track].vis then -- RETURN ONLY VISIBLE TRACKS (THAT ARE CURRENT ARRANGE VIEW NOT TRACK MANAGER HIDDINE RELATED)
            t, b, h = TBH[track].t, TBH[track].b, TBH[track].h
            total_h = total_h + h
        end
    end

    if total_h == 0 then
        t = 0
    end
    return t, total_h, b
end
function Get_Set_Position_In_Arrange(x, y, w)
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
       return zoom_lvl, Arr_start_time, Arr_pixel, x_view_start, y_view_end
    end
 end
--reaper.JS_WindowMessage_Intercept(track_window, "WM_LBUTTONDOWN", true)
function GetTrackZoneInfo() -- MODIFIED
    if not mouse.tr or not TBH[mouse.tr] then
        return
    end
    local zoom_lvl,
        Arr_start_time,
        Arr_end_time,
        Arr_pixel,
        x_view_start,
        y_view_start,
        x_view_end,
        y_view_end,
        state,
        scroll = Project_info()
    local detail      = project_mouse_info()
    local tr_t, tr_b, tr_h = TBH[mouse.tr].t, TBH[mouse.tr].b, TBH[mouse.tr].h
    if mouse.y >= y_view_start and mouse.y < tr_b and mouse.x >= x_view_start and mouse.x <= x_view_end then -- MOUSE IS IN ARRANGE WINDOW
        if mouse.y > tr_t and mouse.y < tr_b then --  TRACK ZONE (UPPER/LOWER HALF)
            local upper_half  = (mouse.y - tr_t < tr_h / 2) and true
            local lower_half  = (mouse.y - tr_t > tr_h / 2) and true
            
            if detail == "EDGE L" or detail == "EDGE R" then
              reaper.JS_WindowMessage_PassThrough(track_window, "WM_LBUTTONDOWN", false)
            else
              reaper.JS_WindowMessage_PassThrough(track_window, "WM_LBUTTONDOWN", true)
            end
            
            if detail == "MOVE" or detail == "FADE L" or detail == "FADE R" then
              BLOCK = true
            else BLOCK = nil
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

local ghosts = {}

local function GetGhosts(data, as_start, as_end)
    local zoom_lvl,
        Arr_start_time,
        Arr_end_time,
        Arr_pixel,
        x_view_start,
        y_view_start,
        x_view_end,
        y_view_end,
        state,
        scroll = Project_info()

    for i = 1, #data do
        if data[i].items then
            local tr = data[i].track
            local item_t, item_h, item_b = TBH[tr].t, TBH[tr].h, TBH[tr].b
            local item_bar = (item_h > 42) and 15 or 0

            for j = 1, #data[i].items do
                local item = data[i].items[j]
                local item_start, item_lenght = item_blit(item, as_start, as_end)
                local bm = reaper.JS_LICE_CreateBitmap(true, round(item_lenght * zoom_lvl), item_h)
                local dc = reaper.JS_LICE_GetDC(bm)
                local item_ghost_id = tostring(item) .. as_start

                reaper.JS_GDI_Blit(
                    dc,
                    0,
                    0,
                    track_window_dc, -- SOURCE - DESTINATION
                    round(item_start * zoom_lvl) - Arr_pixel, -- X
                    ((item_t + item_bar) - y_view_start), -- Y
                    round(item_lenght * zoom_lvl), -- W
                    item_h - 19 -- H (-19 TO COMPENSATE ITEM BAR REMOVING)
                )
                ghosts[item_ghost_id] = {
                    bm = bm,
                    dc = dc,
                    h = item_h,
                    l = round(item_lenght * zoom_lvl),
                    s = round(item_start * zoom_lvl) - Arr_pixel
                }
            end
        elseif data[i].env_points then
            local tr = data[i].track
            local env_t, env_h, env_b = TBH[tr].t, TBH[tr].h, TBH[tr].b
            local bm = reaper.JS_LICE_CreateBitmap(true, round((as_end - as_start) * zoom_lvl), env_h)
            local dc = reaper.JS_LICE_GetDC(bm)
            local env_ghost_id = tostring(tr) .. as_start

            reaper.JS_GDI_Blit(
                dc,
                0,
                0,
                track_window_dc,
                round(as_start * zoom_lvl) - Arr_pixel,
                (env_t - y_view_start),
                round((as_end - as_start) * zoom_lvl),
                env_h
            )
            ghosts[env_ghost_id] = {
                bm = bm,
                dc = dc,
                p = as_start,
                h = env_h,
                l = round((as_end - as_start) * zoom_lvl)
            }
        end
    end
end

function zone(z, tbl, tr)
    local zoom_lvl,
        Arr_start_time,
        Arr_end_time,
        Arr_pixel,
        x_view_start,
        y_view_start,
        x_view_end,
        y_view_end,
        state,
        scroll = Project_info()

    local rx = mouse.dx / zoom_lvl

    if z[1] == "L" then
        local new_x = z[2] + mouse.dx
        local new_w = z[3] - mouse.dx

        local new_x_time = ((new_x - x_view_start) / zoom_lvl) + Arr_start_time
        new_x_time = new_x_time > 0 and new_x_time or 0

        tbl.time_start = new_x_time

        if tbl.time_start >= tbl.time_end then
            tbl.time_start = tbl.time_end
        end

        tbl.x = (round(tbl.time_start * zoom_lvl) - Arr_pixel) + x_view_start
        tbl.w = round(tbl.time_end * zoom_lvl) - round(tbl.time_start * zoom_lvl)
    elseif z[1] == "R" then
        local new_x = z[2] + mouse.dx
        local new_w = z[3] - mouse.dx

        local new_x_time = ((new_x - x_view_start) / zoom_lvl) + Arr_start_time

        tbl.time_end = (((new_x) - x_view_start) / zoom_lvl) + Arr_start_time
        if tbl.time_end <= tbl.time_start then
            tbl.time_end = tbl.time_start
        end

        tbl.w = round(tbl.time_end * zoom_lvl) - round(tbl.time_start * zoom_lvl)
    elseif z[1] == "C" then
        local new_x = z[2] + mouse.dx
        local new_w = (z[2] + z[3]) + mouse.dx

        for i = 1, #tbl.info do
            local as_tr = tbl.info[i].track
            local offset_tr, below_last = generic_track_offset(tbl.info[i].track, mouse.last_tr)
            tbl.info[i].track = offset_tr
        end
        tbl.y, tbl.h = GetTrackTBH(tbl.info)

        local new_x_time = ((new_x - x_view_start) / zoom_lvl) + Arr_start_time
        new_x_time = new_x_time > 0 and new_x_time or 0
        local new_w_time = ((new_w - x_view_start) / zoom_lvl) + Arr_start_time

        local offset = (new_x_time - tbl.time_start) -- GET OFFSET BETWEEN NEW AND OLD POSITION BEFORE WE UPDATE THEM
        move_items_envs(tbl, offset) -- USE THAT OFFSET ON ITEMS AND ENVELOPES FOR MOVING

        tbl.time_start = new_x_time
        tbl.time_end =
            tbl.time_start > 0 and new_w_time or (((tbl.x + tbl.w) - x_view_start) / zoom_lvl) + Arr_start_time

        tbl.x = (round(tbl.time_start * zoom_lvl) - Arr_pixel) + x_view_start
        tbl.w = tbl.time_start > 0 and round(tbl.time_end * zoom_lvl) - round(tbl.time_start * zoom_lvl) or tbl.w
    elseif z[1] == "T" then
        local rd = (mouse.r_t - mouse.ort)
        local new_y, new_h = z[2] + rd, z[3] - rd
        if new_h > 0 then
            tbl.y, tbl.h = new_y, new_h
        end
    elseif z[1] == "B" then
        local rd = (mouse.r_b - mouse.orb)
        local new_y, new_h = z[2] - rd, z[3] + rd
        if new_h > 0 then
            tbl.h = new_h
        end
    end

    tbl:draw()
    return tbl
end

function GetRangeInfo(tbl, as_start, as_end)
    for i = 1, #tbl do
        if reaper.ValidatePtr(tbl[i].track, "MediaTrack*") then
            tbl[i].items = get_items_in_as(tbl[i].track, as_start, as_end) -- TRACK MEDIA ITEMS
        elseif reaper.ValidatePtr(tbl[i].track, "TrackEnvelope*") then
            local retval, env_name = reaper.GetEnvelopeName(tbl[i].track)
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

local function CreateArea(x, y, w, h, guid, time_start, time_end)
    if not Has_val(Areas_TB, nil, guid) then
        Areas_TB[#Areas_TB + 1] = AreaSelection:new(x, y, w, h, guid, time_start, time_end) -- CREATE NEW CLASS ONLY IF DOES NOT EXIST
    else
        Areas_TB[#Areas_TB].time_start = time_start
        Areas_TB[#Areas_TB].time_end = time_end
        Areas_TB[#Areas_TB].x = x
        Areas_TB[#Areas_TB].y = y
        Areas_TB[#Areas_TB].w = w
        Areas_TB[#Areas_TB].h = h
    end
end

function GetAreaInfo(tbl)
    if not tbl then
        return
    end
    local y_t, y_b, as_start, as_end = tbl.y, tbl.y + tbl.h, tbl.time_start, tbl.time_end
    local tracks    = GetTrackFromMouseRange(y_t, y_b) -- GET TRACK RANGE
    local info      = GetRangeInfo(tracks, as_start, as_end) -- GATHER ALL INFO
    return info
end

local function CreateAreaFromCoordinates()
    if not mouse.ort or not mouse.r_t then
        return
    end -- RETURN IF THERE WAS NO MOUSE CLICK OR CLICK WAS MADE OUTSIDE TRACKS
    if reaper.JS_Window_GetForeground() ~= main_wnd then
        return
    end -- RETURN IF SOME WINDOW IS IN FRONT OF ARRANGE (MOUSE IS OVER ANOTHER WINDOW). PREVENTS DRAWING AS WHILE MOVING WINDOWS IN FRONT OF ARRANGE

    local as_top, as_bot = Check_top_bot(mouse.ort, mouse.orb, mouse.r_t, mouse.r_b) -- RANGE ON MOUSE CLICK HOLD AND RANGE WHILE MOUSE HOLD
    local as_left, as_right = Check_left_right(mouse.op, mouse.p) -- CHECK IF START & END TIMES ARE REVERSED
    local x_s, x_e = Check_left_right(mouse.ox, mouse.x) -- CHECK IF X START & END ARE REVERSED

    if mouse.l_click then -- IF LAST MOUSE CLICK WAS DOWN
        guid = mouse.Shift() and reaper.genGuid() or "single"
    end

    if mouse.l_down then -- ALLOW DRAWING ONLY IF IN UPPER PART OF THE TRACK
        DRAWING = Check_change(as_left, as_right, as_top, as_bot)

        if DRAWING then
            CREATING = true

            if copy then
                copy_mode()
            end -- DISABLE COPY MODE IF ENABLED
            if not mouse.Shift() then
                RemoveAsFromTable(Areas_TB, "single")
            end -- REMOVE ALL CREATED AS AND GHOSTS IF SHIFT IS NOT PRESSED (FOR MULTI CREATING AS)

            local x, y, w, h = x_s, as_top, x_e - x_s, as_bot - as_top
            CreateArea(x, y, w, h, guid, as_left, as_right)
        end
    elseif mouse.l_up and CREATING then
        local last_as = Areas_TB[#Areas_TB]
        local info = GetAreaInfo(last_as)

        Areas_TB[#Areas_TB].info = info -- ADD INFO TO TABLEST NOT NORMAL FAST, LIKE FLICK AND SHIT)

        GetGhosts(info, last_as.time_start, last_as.time_end) -- MAKE ITEM GHOSTS

        table.sort(
            Areas_TB,
            function(a, b)
                return a.y < b.y
            end
        ) -- SORT AREA TABLE BY Y POSITION (LOWEST TO HIGHEST)

        CREATING, guid, DRAWING = nil, nil, nil
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

    local chunk = table.concat(chunk, "\n")

    reaper.SetTrackStateChunk(track, chunk, true)
    reaper.UpdateTimeline()
end

function GetEnvOffset_MatchCriteria(tr, env)
    for i = 1, reaper.CountTrackEnvelopes(tr) do
        local tr_env = reaper.GetTrackEnvelope(tr, i - 1)
        local retval, env_name = reaper.GetEnvelopeName(tr_env)

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
        local retval, first_env_name = reaper.GetEnvelopeName(first_env)
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

function generic_track_offset(as_tr, offset_tr)
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

    if mouse.y > mouse.r_b and GetTrackFromMouseRange(mouse.r_b, mouse.y) then
        m_tr_id = reaper.CSurf_TrackToID(cur_m_tr, false) + 1
    end -- IF MOUSE IS BELOW LAST PROJECT TRACK INCREASE MOUSE ID FOR OFFSET

    local last_project_tr = get_last_visible_track()
    local last_project_tr_id = reaper.CSurf_TrackToID(last_project_tr, false)

    local as_tr_offset = m_tr_id - offset_tr_id -- GET OFFSET BETWEEN MOUSE AND FIRST ITEM POSITION (NOTE : IF WE ARE IN ZONE THEN WE USE LAST_MOUSE_TR DELTA WITH MOUSE_TR
    local as_pos_offset = as_tr_id + as_tr_offset -- ADD MOUSE OFFSET TO CURRENT TRACK ID

    as_pos_offset = find_visible_tracks(as_pos_offset, last_project_tr_id) or as_pos_offset -- FIND FIRST AVAILABLE VISIBLE TRACK IF HIDDEN

    local new_as_tr =
        as_pos_offset < last_project_tr_id and -- POSITION ITEMS TO MOUSE POSITION
        reaper.CSurf_TrackFromID(as_pos_offset, false) or
        last_project_tr

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
        local as_start, as_end = tbl.time_start, tbl.time_end

        for i = 1, #tbl.info do
            local info = tbl.info[i]
            local first_tr = find_highest_tr()

            if info.items then
                local item_track = info.track
                local item_data = info.items
                if copy then
                    DrawItemGhosts(info.items, item_track, as_start, as_end, pos_offset, first_tr)
                end
            elseif info.env_name then
                local env_track = info.track
                local env_name = info.env_name
                -- local env_first_tr  = find_highest_tr("env")
                local env_data = info.env_points

                if copy then
                    DrawEnvGhosts(env_track, env_name, as_start, as_end, pos_offset, first_tr)
                end
            end
        end
    end
    if copy then
        refresh_reaper()
    end
end

function DrawItemGhosts(item_data, item_track, as_start, as_end, pos_offset, first_track)
    local zoom_lvl,
        Arr_start_time,
        Arr_end_time,
        Arr_pixel,
        x_view_start,
        y_view_start,
        x_view_end,
        y_view_end,
        state,
        scroll = Project_info()

    local offset_track, under_last_tr = generic_track_offset(item_track, first_track)
    --local off_h                       = under_last_tr and TBH[offset_track].h * under_last_tr or 0  -- IF OFFSET TRACKS ARE BELOW LAST PROJECT TRACK MULTIPLY HEIGHT BY THAT NUMBER AND ADD IT TO GHOST
    local off_h = under_last_tr and reaper.GetMediaTrackInfo_Value(offset_track, "I_WNDH") * under_last_tr or 0 -- USE THIS INSTEAD OF THB[] SINCE IT MAYBE GOT ENVELOPES WHICH ARE INCLUDED IN THIS API
    if TBH[offset_track] then -- THIS IS NEEDED FOR PASTE FUNCTION OR IT WILL CRASH
        local track_t, track_b, track_h = TBH[offset_track].t + off_h, TBH[offset_track].b, TBH[offset_track].h
        for i = 1, #item_data do
            local item = item_data[i]
            local item_start, item_lenght = item_blit(item, as_start, as_end, pos)
            local item_ghost_id = tostring(item) .. as_start
            local mouse_offset = pos_offset + (mouse.p - as_start) + item_start
            reaper.JS_Composite(
                track_window,
                round(mouse_offset * zoom_lvl) - Arr_pixel, -- X
                track_t - y_view_start + 0, -- Y
                round(item_lenght * zoom_lvl), -- W
                track_h, -- H
                ghosts[item_ghost_id].bm,
                0, -- x
                0, -- y
                ghosts[item_ghost_id].l, -- w
                ghosts[item_ghost_id].h - 19 -- h
            )
        end
    end
end

function DrawEnvGhosts(env_track, env_name, as_start, as_end, pos_offset, first_env_tr, env_first_tr)
    local zoom_lvl,
        Arr_start_time,
        Arr_end_time,
        Arr_pixel,
        x_view_start,
        y_view_start,
        x_view_end,
        y_view_end,
        state,
        scroll = Project_info()
    local offset_track, under_last_tr = generic_track_offset(env_track, first_env_tr)
    local off_h = under_last_tr and TBH[offset_track].h * under_last_tr or 0 -- IF OFFSET TRACKS ARE BELOW LAST PROJECT TRACK MULTIPLY HEIGHT BY THAT NUMBER AND ADD IT TO GHOST

    local env_offset = GetEnvOffset_MatchCriteria(offset_track, env_name)

    --env_offset = reaper.ValidatePtr(mouse.tr,"TrackEnvelope*") and env_mouse_offset(offset_track, env_name, env_first_tr) or env_offset

    if TBH[env_offset] then -- THIS IS NEEDED FOR PASTE FUNCTION OR IT WILL CRASH
        local track_t, track_b, track_h = TBH[env_offset].t + off_h, TBH[env_offset].b, TBH[env_offset].h

        local env_ghost_id = tostring(env_track) .. as_start
        if ghosts[env_ghost_id] then
            local mouse_offset = pos_offset + (mouse.p - as_start) + ghosts[env_ghost_id].p

            reaper.JS_Composite(
                track_window,
                round(mouse_offset * zoom_lvl) - Arr_pixel, -- X
                (track_t - y_view_start), -- Y
                round((as_end - as_start) * zoom_lvl), -- W
                track_h, -- H
                ghosts[env_ghost_id].bm,
                0, -- x
                0, -- y
                ghosts[env_ghost_id].l, -- w
                ghosts[env_ghost_id].h -- h
            )
        end
    end
end

function mouse_coord()
    local zoom_lvl,
        Arr_start_time,
        Arr_end_time,
        Arr_pixel,
        x_view_start,
        y_view_start,
        x_view_end,
        y_view_end,
        state,
        scroll = Project_info()
    local x, y = reaper.GetMousePosition()
    local mouse_time_pos = ((x - x_view_start) / zoom_lvl) + Arr_start_time
    mouse_time_pos = (mouse_time_pos > 0) and mouse_time_pos or 0
    local pos = (reaper.GetToggleCommandState(1157) == 1) and reaper.SnapToGrid(0, mouse_time_pos) or mouse_time_pos -- FINAL POSITION IS SNAP IF ENABLED OF FREE MOUSE POSITION
    x = (reaper.GetToggleCommandState(1157) == 1) and (round(pos * zoom_lvl) + x_view_start) - Arr_pixel or x
    return x, y, pos
end

------------------------ INTERCEPT TEST
function copy_mode(key)
    copy = next(ghosts) ~= nil and not copy
    if not copy then
        for k, v in pairs(ghosts) do
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
        GetTracksXYH_Info() -- REFRESH MAIN TABLE TRACKS (IF PASTE CREATED NEW TRACKS)
    end
end

function del()
    local tbl = active_as and {active_as} or Areas_TB
    if #tbl ~= 0 then
        AreaDo(tbl, "del")
    end
end

function remove()
    if copy then
        copy_mode()
    end -- DISABLE COPY MODE
    RemoveAsFromTable(Areas_TB, "Delete")
    active_as = nil
    refresh_reaper()
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

            if tonumber(key.DOWN.name) then -- ACTIVE AS
                local num = tonumber(key.DOWN.name)
                active_as = Areas_TB[num] and Areas_TB[num] or nil
                for k, v in pairs(ghosts) do
                    reaper.JS_Composite_Unlink(track_window, v.bm)
                end -- REFRESH GHOSTS
            end
        elseif key.HOLD then
        elseif key.UP then
        end
    end
end

function find_highest_tr(job)
    local as_tbl = active_as and {active_as} or Areas_TB

    for i = 1, #as_tbl do
        local tbl = as_tbl[i]

        for j = 1, #tbl.info do
            -- if not tbl.info[j].items and not tbl.info.env_name and job == "track" then
            --local as_tr = tbl.info[j].track
            -- return as_tr
            if tbl.info[j].items or not job then
                return tbl.info[j].track
            elseif tbl.info[j].env_name or job then
                return tbl.info[j].track
            end
        end
    end
end

local reaper_cursors =  {
                          {187,"MOVE"},  -- MOVE
                          {185,"DRAW"},  -- DRAW
                          {417,"EDGE L"},  -- LEFT EDGE
                          {418,"EDGE R"},  -- RIGHT EDGE
                          {184,"FADE L"},  -- FADE RIGHT
                          {105,"FADE R"},   -- FADE LEFT
                        }

function project_mouse_info()
    local cur_cursor = reaper.JS_Mouse_GetCursor()
    for i = 1, #reaper_cursors do
        local cursor = reaper.JS_Mouse_LoadCursor( reaper_cursors[i][1] )
        if cur_cursor == cursor then
          return reaper_cursors[i][2]
        end
    end
end

local function validate_removed_track()
    if #Areas_TB == 0 then
        return
    end
    for i = #Areas_TB, 1, -1 do
        for j = #Areas_TB[i].info, 1, -1 do
            if not reaper.ValidatePtr(Areas_TB[i].info[j].track, "MediaTrack*") then
                table.remove(Areas_TB[i].info, j)
                if #Areas_TB[i].info == 0 then
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
            validate_removed_track()
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

local function Main()
    xpcall(
        function()
            GetTracksXYH_Info() -- GET XYH INFO OF ALL TRACKS
            mouse = GetMouseInfo(mouse_coord())
            if GetTrackFromPoint() then
                mouse.tr, mouse.r_t, mouse.r_b = GetTrackFromPoint()
            end

            check_keys()
            
            GetTrackZoneInfo()
            
            
           --[[ local detail, UH, LH = GetTrackZoneInfo()
            
            if detail == "EDGE L" or detail == "EDGE R" then
              if LH then
                reaper.JS_WindowMessage_PassThrough(track_window, "WM_LBUTTONDOWN", false)
                BLOCK = true
              else
                reaper.JS_WindowMessage_PassThrough(track_window, "WM_LBUTTONDOWN", true)
                BLOCK = nil
              end
            elseif mouse.l_up and BLOCK then
             -- reaper.JS_WindowMessage_PassThrough(track_window, "WM_LBUTTONDOWN", true)
              --reaper.JS_WindowMessage_PassThrough(track_window, "WM_LBUTTONUP",   false)
              BLOCK = nil
            end
            ]]
            if not ZONE and not BLOCK then
                CreateAreaFromCoordinates()
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
    for k, v in pairs(ghosts) do
        reaper.JS_LICE_DestroyBitmap(v.bm)
    end
    if reaper.ValidatePtr(track_window, "HWND") then
        refresh_reaper()
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
