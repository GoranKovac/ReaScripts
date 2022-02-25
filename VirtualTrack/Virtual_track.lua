--[[
 * ReaScript Name: Virtual Tracks
 * Author: Sexan
 * Licence: GPL v3
 * REAPER: 6.0
 * Extensions: None
 * Version: 0.1
 * Provides: Modules/*.lua
--]]

--[[
 * Changelog:
 * v0.27 (2022-02-25)
   + Get tracks under mouse only if visible
--]]

local reaper = reaper
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

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

require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local VT_TB = {}

function To_screen(x,y)
    local sx, sy = reaper.JS_Window_ClientToScreen( track_window, x, y )
    return sx, sy
end

function To_client(x,y)
    local cx, cy = reaper.JS_Window_ScreenToClient( track_window, x, y )
    return cx, cy
end

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
    reaper.atexit(Exit)
end

local TBH
local function GetTracksXYH()
    if reaper.CountTracks(0) == 0 then
        if TBH and next(TBH) ~= nil then TBH = {} end
        return
    end
    TBH = {}
    local visible_index = 0
    for i = 1, reaper.CountTracks(0) do
        local tr = reaper.GetTrack(0, i - 1)
        local tr_vis = reaper.IsTrackVisible(tr, false)
        local tr_h = reaper.GetMediaTrackInfo_Value(tr, "I_TCPH")
        local tr_t = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY")
        local tr_b = tr_t + tr_h

        visible_index = tr_vis and visible_index + 1 or visible_index
        local ID = tr_vis and visible_index or nil

        TBH[tr] = {t = tr_t, b = tr_b, h = tr_h, vis = tr_vis, vis_ID = ID}

        for j = 1, reaper.CountTrackEnvelopes(tr) do
            local env = reaper.GetTrackEnvelope(tr, j - 1)
            local env_h = reaper.GetEnvelopeInfo_Value(env, "I_TCPH")
            local env_t = reaper.GetEnvelopeInfo_Value(env, "I_TCPY") + tr_t
            local env_b = env_t + env_h
            local env_vis = Env_prop(env,"visible")
            TBH[env] = {t = env_t, b = env_b, h = env_h, vis = env_vis}
        end
    end
end

function Get_TBH_TBL()
    return TBH
end

function Get_tr_TBH(tr)
    if TBH[tr] then
       return TBH[tr].t, TBH[tr].h, TBH[tr].b
    end
end

function Get_track_under_mouse(x, y)
    local _, cy = To_client(x, y)
    local track, env_info = reaper.GetTrackFromPoint(x, y)

    if track == reaper.GetMasterTrack( 0 ) and reaper.GetMasterTrackVisibility() == 0 then return end -- IGNORE DOCKED MASTER TRACK
    if track and env_info == 0 and TBH[track].vis == true then
        return track, TBH[track].t, TBH[track].b, TBH[track].h
    elseif track and env_info == 1 then
        for i = 1, reaper.CountTrackEnvelopes(track) do
            local env = reaper.GetTrackEnvelope(track, i - 1)
            if TBH[env].t <= cy and TBH[env].b >= cy and TBH[env].vis == true then
                return env, TBH[env].t, TBH[env].b, TBH[env].h
            end
        end
    end
end

function ValidateRemovedTracks()
    if next(VT_TB) == nil then return end
    for k, v in pairs(VT_TB) do
        if not TBH[k] then
            reaper.JS_LICE_DestroyBitmap(v.bm)
            VT_TB[k] = nil
        end
    end
end

local function Exclude_Pattern(chunk)
    local patterns = {"SEL 0", "SEL 1"}
    for i = 1, #patterns do
        chunk = string.gsub(chunk, patterns[i], "")
    end
    return chunk
end

local function Get_folder(track)
    if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") <= 0 then
        return
    end
    local depth, children = 0, {}
    local folderID = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = folderID + 1, reaper.CountTracks(0) - 1 do
        local child = reaper.GetTrack(0, i)
        local currDepth = reaper.GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
        children[#children + 1] = child
        depth = depth + currDepth
        if depth <= -1 then
           break
        end
    end
    return children
end

local function Get_Item_Chunk(item)
    if not item then return end
    local _, chunk = reaper.GetItemStateChunk(item, "", false)
    return chunk
end

local function Get_Track_Items(track, job)
    if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        return
    end
    local items_chunk = {}
    local num_items = reaper.CountTrackMediaItems(track)
    for i = 1, num_items, 1 do
        local item = reaper.GetTrackMediaItem(track, i - 1)
        local item_chunk = Get_Item_Chunk(item)
        item_chunk = Exclude_Pattern(item_chunk)
        items_chunk[#items_chunk + 1] = item_chunk
    end
    return items_chunk
end

function Env_prop(env,val)
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

local function Get_Env_Chunk(env)
    local _, env_chunk = reaper.GetEnvelopeStateChunk(env, "")
    return env_chunk
end

local function Set_Env_Chunk(env, data)
    if not reaper.ValidatePtr(env, "TrackEnvelope*") then return end
    reaper.SetEnvelopeStateChunk( env, data, false)
end

local match = string.match
function Make_Empty_Env(env)
    local env_chunk = Get_Env_Chunk(env)
    local env_center_val = Env_prop(env, "centerValue")
    local env_name_from_chunk = match(env_chunk, "[^\r\n]+")
    local chunk_template = env_name_from_chunk .."\nACT 1 -1\nVIS 1 1 1\nLANEHEIGHT 0 0\nARM 1\nDEFSHAPE 0 -1 -1\nPT 0 " .. env_center_val .. " 0\n>"
    Set_Env_Chunk(env, chunk_template)
end

local function Create_item(tr, data)
    if not data or not reaper.ValidatePtr(tr, "MediaTrack*")  then return end
    local new_items = {}
    for i = 1, #data do
        local chunk = data[i]
        local empty_item = reaper.AddMediaItemToTrack(tr)
        reaper.SetItemStateChunk(empty_item, chunk, false)
        reaper.GetSetMediaItemInfo_String(empty_item, "GUID", reaper.genGuid(), true)

        for j = 1, reaper.CountTakes(empty_item) do
            local take_dst = reaper.GetMediaItemTake(empty_item, j-1)
            reaper.GetSetMediaItemTakeInfo_String(take_dst, "GUID", reaper.genGuid(), true)
        end

        reaper.SetMediaItemInfo_Value(empty_item, "B_UISEL", 1)
        reaper.Main_OnCommand(41613, 0)
        reaper.SetMediaItemInfo_Value(empty_item, "B_UISEL", 0)

        new_items[#new_items+1] = empty_item
    end
    return new_items
end

function Set_Virtual_Track(track, tbl, idx)
    SaveCurrentState(track, tbl)
    SwapVirtualTrack(track, tbl, idx)
end

function SwapVirtualTrack(track, tbl, idx)
    Clear(track)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        Create_item(track, tbl.info[idx])
    else
        Set_Env_Chunk(track, tbl.info[idx])
    end
    tbl.idx = idx;
end

function SaveCurrentState(track, tbl)
    local chunk_tbl = reaper.ValidatePtr(track, "MediaTrack*") and Get_Track_Items(track) or Get_Env_Chunk(track)
    tbl.info[tbl.idx] = chunk_tbl
    return chunk_tbl
end

-- CREATE VERSIONS FROM FOLDER (DO FOR ALL CHILDS)
function Create_folder(track)
    if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then
        return
    end
    local childs = Get_folder(track)
    for i = 1, #childs do
        CreateNew(childs[i], VT_TB[childs[i]]) -- CREATE VERSIONS ON CHILDS
    end
    --CreateNew(track, VT_TB[track]) -- CREATE FOLDER VERSION ()
end

function CreateNew(track, tbl)
    Duplicate(track,tbl)
    Clear(track)
    tbl.info[tbl.idx] = reaper.ValidatePtr(track, "MediaTrack*") and Get_Track_Items(track) or Get_Env_Chunk(track) -- clear it out
end

function Duplicate(track, tbl)
    local chunk_tbl = SaveCurrentState(track, tbl)
    tbl.info[#tbl.info+1] = chunk_tbl
    tbl.idx = #tbl.info;
end

function Clear(track)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        local num_items = reaper.CountTrackMediaItems(track)
        for i = num_items, 1, -1 do
            local item = reaper.GetTrackMediaItem(track, i - 1)
            reaper.DeleteTrackMediaItem(track, item)
        end
    else
        Make_Empty_Env(track)
    end
end

function Delete(track, tbl)
    if tbl.idx == 1 then return end -- PREVENT DELETING ORIGINAL VERSION
    table.remove(tbl.info, tbl.idx)
    tbl.idx = tbl.idx <= #tbl.info and tbl.idx or #tbl.info
    SwapVirtualTrack(track, tbl, tbl.idx)
end

local function get_fipm_value(tr, num)
    if not num then return end
    local _, track_h = Get_tr_TBH(tr)
    local offset = track_h <= 42 and 15 or 0
    local bar_h_FIPM = ((19 - offset) / track_h)
    local item_h_FIPM = (1 - (num - 1) * bar_h_FIPM) / num
    return bar_h_FIPM, item_h_FIPM
end

function ShowAll(track, tbl)
    if not reaper.ValidatePtr(track, "MediaTrack*") then return end
    SaveCurrentState(track, tbl)
    local val = reaper.GetMediaTrackInfo_Value(track, "B_FREEMODE") == 1 and 0 or 1
    Clear(track)
    if val == 1 then
        local FIPM_bar, FIPM_item = get_fipm_value(track, #tbl.info)
        for i = 1, #tbl.info do
            local items = Create_item(track, tbl.info[i])
            for j = 1, #items do
                reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_H", FIPM_item)
                reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_Y", ((i - 1) * (FIPM_item + FIPM_bar)))
            end
        end
    else
        Create_item(track, tbl.info[1])
    end
    reaper.SetMediaTrackInfo_Value(track, "B_FREEMODE", val)
end

local function Find_In_History(tbl, val)
    if not tbl then return end
    for i = 1, #tbl do
        if val:find(tbl[i]) then
            return true
        end
    end
    return false
end

local ignore_history = {
    "unselect all items",
    "remove material behind selected items",
    "change media item selection"
}

local accept_history = {
    "item",
    "recorded media",
    "midi editor: insert notes",
    "change source media",
    "rename source media",
    "take",
    "pencil",
    "adjust"
}

local last_proj_change_count = reaper.GetProjectStateChangeCount(0)

local function Auto_save()
    local proj_change_count = reaper.GetProjectStateChangeCount(0)
    if proj_change_count > last_proj_change_count then
        local last_action = reaper.Undo_CanUndo2(0)
        if last_action == nil then return end
        last_action = last_action:lower()
        if Find_In_History(ignore_history, last_action) then return end
        if Find_In_History(accept_history, last_action) then
            local touched_track = MouseInfo().last_tr
            SaveCurrentState(touched_track, VT_TB[touched_track])
        end
    end
    last_proj_change_count = proj_change_count
end

local function Store_To_PEXT(el)
    local storedTable = {}
    storedTable.info = el.info;
    storedTable.idx = math.floor(el.idx)
    local serialized = tableToString(storedTable)
    if reaper.ValidatePtr(el.rprobj, "MediaTrack*") then
        reaper.GetSetMediaTrackInfo_String(el.rprobj, "P_EXT:VirtualTrack", serialized, true)
    else
        local rv, stored = reaper.GetSetEnvelopeInfo_String(el.rprobj, "P_EXT:VirtualTrack", serialized, true)
    end
end

local function Restore_From_PEXT(el)
    local rv, stored
    if reaper.ValidatePtr(el.rprobj, "MediaTrack*") then
        rv, stored = reaper.GetSetMediaTrackInfo_String(el.rprobj, "P_EXT:VirtualTrack", "", false)
    else
        rv, stored = reaper.GetSetEnvelopeInfo_String(el.rprobj, "P_EXT:VirtualTrack", "", false)
    end
    if rv == true and stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            el.info = storedTable.info
            el.idx = storedTable.idx
        end
    end
end

function Serialize(track, el)
    Store_To_PEXT(el)
end

function Deserialize(track, el)
    Restore_From_PEXT(el)
end

local function Create_VT_Element()
    GetTracksXYH()
    ValidateRemovedTracks()
    if reaper.CountTracks(0) == 0 then return end
    for k, _ in pairs(TBH) do
        if not VT_TB[k] then
            local Element = Get_class_tbl()
            local y = Get_tr_TBH(k)
            local tr_data = reaper.ValidatePtr(k, "MediaTrack*") and Get_Track_Items(k) or Get_Env_Chunk(k)
            VT_TB[k] = Element:new(0, y, 20, 20, k, {tr_data})
            Restore_From_PEXT(VT_TB[k])
        end
    end
end

function Debug_table(tbl)
    A_TBL = {}
    local cnt = 1
    for _, v in pairs(tbl) do
        A_TBL[cnt] = v
        cnt = cnt + 1
    end
end

local function RunLoop()
    Create_VT_Element()
    Draw(VT_TB)
    --Debug_table(TBH)
    Auto_save()
    reaper.defer(RunLoop)
end

local function Main()
    xpcall(RunLoop, crash)
end

function Exit() -- DESTROY ALL BITMAPS ON REAPER EXIT
    for k, v in pairs(VT_TB) do
        Store_To_PEXT(VT_TB[k]) -- STORE TO P_EXT AT EXIT
        reaper.JS_LICE_DestroyBitmap(v.bm) -- DESTROY BITMAPS FROM AS THAT WILL BE DELETED
    end
end
reaper.atexit(Exit)
Main()
