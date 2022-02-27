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
 * v0.29 (2022-02-26)
   + more cleanuo
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

local VT_TB = {}
local TBH
local function GetTracksXYH()
    if reaper.CountTracks(0) == 0 then return end
    TBH = {}
    for i = 1, reaper.CountTracks(0) do
        local tr = reaper.GetTrack(0, i - 1)
        local tr_vis = reaper.IsTrackVisible(tr, false)
        local tr_h = reaper.GetMediaTrackInfo_Value(tr, "I_TCPH")
        local tr_t = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY")
        local tr_b = tr_t + tr_h
        TBH[tr] = {t = tr_t, b = tr_b, h = tr_h, vis = tr_vis}
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

function Get_TBH_Info(tr)
    if not tr then return TBH end
    if TBH[tr] then
       return TBH[tr].t, TBH[tr].h, TBH[tr].b
    end
end

local function ValidateRemovedTracks()
    if next(VT_TB) == nil then return end
    for k, v in pairs(VT_TB) do
        if not TBH[k] then
            reaper.JS_LICE_DestroyBitmap(v.bm)
            VT_TB[k] = nil
        end
    end
end

local patterns = {"SEL 0", "SEL 1"}
local function Exclude_Pattern(chunk)
    for i = 1, #patterns do
        chunk = string.gsub(chunk, patterns[i], "")
    end
    return chunk
end

local function Get_Item_Chunk(item)
    if not item then return end
    local _, chunk = reaper.GetItemStateChunk(item, "", false)
    return chunk
end

local function Get_Track_Items(track, job)
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
    local properties = {
        ["active"] = active,
        ["visible"] = visible,
        ["armed"] = armed,
        ["inLane"] = inLane,
        ["defaultShape"] = defaultShape,
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
    reaper.SetEnvelopeStateChunk( env, data, false)
end

local match = string.match
function Make_Empty_Env(env)
    local env_chunk = Get_Env_Chunk(env)
    local env_center_val = Env_prop(env, "centerValue")
    local env_name_from_chunk = match(env_chunk, "[^\r\n]+")
    local empty_chunk_template = env_name_from_chunk .."\nACT 1 -1\nVIS 1 1 1\nLANEHEIGHT 0 0\nARM 1\nDEFSHAPE 0 -1 -1\nPT 0 " .. env_center_val .. " 0\n>"
    Set_Env_Chunk(env, empty_chunk_template)
end

local function Remove_Track_FX(track)
    for i = 1, reaper.TrackFX_GetCount(track) do
        reaper.TrackFX_Delete(track, i - 1)
    end
end

local function Get_FX_Chunk(track)
    local _, track_chunk = reaper.GetTrackStateChunk(track, "", false)
    if not track_chunk:find("<FXCHAIN") then
        return
    end -- DO NOT ALLOW CREATING FIRST EMPTY FX
    local fx_start = track_chunk:find("<FXCHAIN") + 9
    local fx_end = track_chunk:find("<ITEM") and track_chunk:find("<ITEM") - 4 or -6
    local fx_chunk = track_chunk:sub(fx_start, fx_end)
    return fx_chunk, track_chunk
end

local function Set_FX_Chunk(track, tbl)
    local chunk = tbl.fx[num].chunk
    local fx_chunk, track_chunk = Get_FX_Chunk(track)
    local fx_chunk = literalize(fx_chunk)
    local track_chunk = string.gsub(track_chunk, fx_chunk, chunk)
    reaper.SetTrackStateChunk(track, track_chunk, false)
    tbl.fx.fx_num = idx
end

local function Create_item(tr, data)
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

local function SaveCurrentState(track, tbl)
    local chunk_tbl = reaper.ValidatePtr(track, "MediaTrack*") and Get_Track_Items(track) or Get_Env_Chunk(track)
    tbl.info[tbl.idx] = chunk_tbl
    return chunk_tbl
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

function CreateNew(track, tbl)
    Duplicate(track,tbl)
    Clear(track)
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
    if tbl.idx == 1 then return end
    table.remove(tbl.info, tbl.idx)
    tbl.idx = tbl.idx <= #tbl.info and tbl.idx or #tbl.info
    SwapVirtualTrack(track, tbl, tbl.idx)
end

local function get_fipm_value(tr, num)
    if not num then return end
    local _, track_h = Get_TBH_Info(tr)
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

local function Store_To_PEXT(el)
    local storedTable = {}
    storedTable.info = el.info;
    storedTable.idx = math.floor(el.idx)
    local serialized = tableToString(storedTable)
    if reaper.ValidatePtr(el.rprobj, "MediaTrack*") then
        reaper.GetSetMediaTrackInfo_String(el.rprobj, "P_EXT:VirtualTrack", serialized, true)
    else
        reaper.GetSetEnvelopeInfo_String(el.rprobj, "P_EXT:VirtualTrack", serialized, true)
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

local function Create_VT_Element()
    GetTracksXYH()
    ValidateRemovedTracks()
    if reaper.CountTracks(0) == 0 then return end
    for track in pairs(TBH) do
        if not VT_TB[track] then
            local Element = Get_class_tbl()
            local tr_data = reaper.ValidatePtr(track, "MediaTrack*") and Get_Track_Items(track) or Get_Env_Chunk(track)
            VT_TB[track] = Element:new(0, 0, 20, 20, track, {tr_data})
            Restore_From_PEXT(VT_TB[track])
        end
    end
end

local function RunLoop()
    Create_VT_Element()
    Draw(VT_TB)
    reaper.defer(RunLoop)
end

local function Main()
    xpcall(RunLoop, crash)
end

function Exit()
    for k, v in pairs(VT_TB) do
        Store_To_PEXT(VT_TB[k])
        reaper.JS_LICE_DestroyBitmap(v.bm)
    end
end
reaper.atexit(Exit)
Main()
