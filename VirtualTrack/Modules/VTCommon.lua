--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
	 * NoIndex: true
--]]

local reaper = reaper

local VT_TB = {}
local TBH

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
            "Error: " .. err .. "\n\n" ..
            "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 2) .. "\n\n" ..
            "Reaper:       \t" .. reaper.GetAppVersion() .. "\n" ..
            "Platform:     \t" .. reaper.GetOS()
        )
    end
end

function GetCrash()
    return crash
end

function GetSingleTrackEnvelopeXYH(env, tr_t, tr_vis)
    local _, env_name = reaper.GetEnvelopeName(env)
    local env_h = reaper.GetEnvelopeInfo_Value(env, "I_TCPH")
    local env_t = reaper.GetEnvelopeInfo_Value(env, "I_TCPY") + tr_t
    local env_b = env_t + env_h
    local env_vis = reaper.GetEnvelopeInfo_Value(env, "I_TCPH_USED") ~= 0 and true or false
    if env_name == "Tempo map" then if tr_vis == false then env_vis = false end end -- HIDE TEMPO MAP IF MASTER IS HIDDEN
    TBH[env] = {t = env_t, b = env_b, h = env_h, vis = env_vis, name = env_name}
end

function GetSingleTrackXYH(tr, ismaster)
    local _, tr_name = reaper.GetTrackName(tr)
    local tr_vis = not ismaster and reaper.IsTrackVisible(tr, false) or (reaper.GetMasterTrackVisibility()&1 == 1 and true or false )
    local tr_h = reaper.GetMediaTrackInfo_Value(tr, "I_TCPH")
    local tr_t = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY")
    local tr_b = tr_t + tr_h
    TBH[tr] = {t = tr_t, b = tr_b, h = tr_h, vis = tr_vis, name = tr_name}
    for j = 1, reaper.CountTrackEnvelopes(tr) do
        local env = reaper.GetTrackEnvelope(tr, j - 1)
        GetSingleTrackEnvelopeXYH(env, tr_t, tr_vis)
    end
end

function GetTracksXYH()
    if reaper.CountTracks(0) == 0 then
        if TBH and next(TBH) ~= nil then TBH = {} end
        return
    end
    TBH = {}
    for i = 0, reaper.CountTracks(0) do
        local tr = i ~= 0 and reaper.GetTrack(0, i - 1) or reaper.GetMasterTrack(0)
        GetSingleTrackXYH(tr, i == 0)
    end
end

local function Store_To_PEXT(el)
    local storedTable = {}
    storedTable.info = el.info;
    storedTable.idx = math.floor(el.idx)
    local serialized = tableToString(storedTable)
    if reaper.ValidatePtr(el.rprobj, "MediaTrack*") then
        reaper.GetSetMediaTrackInfo_String(el.rprobj, "P_EXT:VirtualTrack", serialized, true)
    elseif reaper.ValidatePtr(el.rprobj, "TrackEnvelope*") then
        reaper.GetSetEnvelopeInfo_String(el.rprobj, "P_EXT:VirtualTrack", serialized, true)
    end
end

function StoreInProject()
    for _, v in pairs(VT_TB) do
        Store_To_PEXT(v)
    end
end

local function Restore_From_PEXT(el)
    local rv, stored
    if reaper.ValidatePtr(el.rprobj, "MediaTrack*") then
        rv, stored = reaper.GetSetMediaTrackInfo_String(el.rprobj, "P_EXT:VirtualTrack", "", false)
    elseif reaper.ValidatePtr(el.rprobj, "TrackEnvelope*") then
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

function Create_undo_name(func, track, idx)
    return "VT:" .. math.floor(idx) .. "|".. "TRACK:" .. tostring(track) .. "|" .. "ACTION:" .. func
end

function Get_TBH_Info(tr)
    if not tr then return TBH end
    if TBH[tr] then
       return TBH[tr].t, TBH[tr].h, TBH[tr].b
    end
end

function Get_VT_TB()
    return VT_TB
end

function Get_TBH()
    return TBH
end

local function ValidateRemovedTracks()
    if next(VT_TB) == nil then return end
    for k, v in pairs(VT_TB) do
        if not TBH[k] then
            v:cleanup()
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
    local active, visible, armed, inLane, laneHeight, defaultShape, minValue, maxValue, centerValue, type_, faderScaling = reaper.BR_EnvGetProperties(br_env)
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
    reaper.BR_EnvFree(br_env, false)
    return properties[val]
end

function Get_Env_Chunk(env)
    local _, env_chunk = reaper.GetEnvelopeStateChunk(env, "")
    return {env_chunk}
end

local function Set_Env_Chunk(env, data)
    reaper.SetEnvelopeStateChunk(env, data[1], false)
end

local match = string.match
function Make_Empty_Env(env)
    local env_chunk = Get_Env_Chunk(env)[1]
    local env_center_val = Env_prop(env, "centerValue")
    local env_fader_scaling = Env_prop(env,"faderScaling") == true and "VOLTYPE 1\n" or ""
    local env_name_from_chunk = match(env_chunk, "[^\r\n]+")
    local empty_chunk_template = env_name_from_chunk .."\nACT 1 -1\nVIS 1 1 1\nLANEHEIGHT 0 0\nARM 1\nDEFSHAPE 0 -1 -1\n" .. env_fader_scaling .. "PT 0 " .. env_center_val .. " 0\n>"
    local current_bpm = reaper.Master_GetTempo()
    local empty_tempo_template = env_name_from_chunk .. "\nACT 1 -1\nVIS 1 0 1\nLANEHEIGHT 0 0\nARM 1\nDEFSHAPE 0 -1 -1\nPT 0.000000000000 " .. current_bpm .. " 0\n>"
    empty_chunk_template = env_name_from_chunk == "<TEMPOENVEX" and empty_tempo_template or empty_chunk_template
    Set_Env_Chunk(env, {empty_chunk_template})
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
        reaper.Main_OnCommand(41613, 0) -- need to clear midi pooling
        reaper.SetMediaItemInfo_Value(empty_item, "B_UISEL", 0)
        new_items[#new_items+1] = empty_item
    end
    return new_items
end

local function GetChunkTableForObject(track)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        return Get_Track_Items(track)
    elseif reaper.ValidatePtr(track, "TrackEnvelope*") then
        return Get_Env_Chunk(track)
    end
    return nil;
end

local function SaveCurrentState(track, tbl)
    local name = tbl.info[tbl.idx].name
    local chunk_tbl = GetChunkTableForObject(track)
    tbl.info[tbl.idx] = chunk_tbl
    tbl.info[tbl.idx].name = name
    Store_To_PEXT(tbl)
end

function Set_Virtual_Track(track, tbl, idx)
    SaveCurrentState(track, tbl)
    SwapVirtualTrack(track, tbl, idx)
end

function SwapVirtualTrack(track, tbl, idx)
    Clear(track)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        Create_item(track, tbl.info[idx])
    elseif reaper.ValidatePtr(track, "TrackEnvelope*") then
        Set_Env_Chunk(track, tbl.info[idx])
    end
    tbl.idx = idx;
end

function CreateNew(track, tbl)
    SaveCurrentState(track, tbl)
    Clear(track)
    tbl.info[#tbl.info + 1] = {}
    tbl.idx = #tbl.info
    tbl.info[#tbl.info].name = "Version - " .. #tbl.info
end

function Duplicate(track, tbl)
    SaveCurrentState(track, tbl)
    local name = tbl.info[tbl.idx].name
    tbl.info[#tbl.info + 1] = GetChunkTableForObject(track)
    tbl.idx = #tbl.info
    tbl.info[#tbl.info].name = "Duplicate - " .. name
end

function Clear(track)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        local num_items = reaper.CountTrackMediaItems(track)
        for i = num_items, 1, -1 do
            local item = reaper.GetTrackMediaItem(track, i - 1)
            reaper.DeleteTrackMediaItem(track, item)
        end
    elseif reaper.ValidatePtr(track, "TrackEnvelope*") then
        Make_Empty_Env(track)
    end
end

function Delete(track, tbl)
    if tbl.idx == 1 then return end
    table.remove(tbl.info, tbl.idx)
    tbl.idx = tbl.idx <= #tbl.info and tbl.idx or #tbl.info
    SwapVirtualTrack(track, tbl, tbl.idx)
end

function Rename(track, tbl)
    local retval, name = reaper.GetUserInputs("Name Version ", 1, "Version Name :", tbl.info[tbl.idx].name)
    if not retval then return end
    tbl.info[tbl.idx].name = name
end

function Mute_view_test(track)
    reaper.PreventUIRefresh(1)
    for i = 1, reaper.CountTrackMediaItems(track) do
        local item = reaper.GetTrackMediaItem(track, i - 1)
        if reaper.IsMediaItemSelected( item ) then
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", 0)
        else
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
        end
    end
    reaper.PreventUIRefresh(-1)
end

local function GetItemLane(item, lanes)
    local y = reaper.GetMediaItemInfo_Value(item, 'F_FREEMODE_Y')
    local idx = math.floor(y * lanes) + 1
    return idx
end

local function StoreLaneData(track, tbl)
    local num_items = reaper.CountTrackMediaItems(track)
    for j = 1, #tbl.info do
        local lane_chunk = {}
        for i = 1, num_items do
            local item = reaper.GetTrackMediaItem(track, i-1)
            if GetItemLane(item, #tbl.info) == j then
                local item_chunk = Get_Item_Chunk(item)
                item_chunk = Exclude_Pattern(item_chunk)
                lane_chunk[#lane_chunk + 1] = item_chunk
            end
        end
        local name = tbl.info[j].name
        tbl.info[j] = lane_chunk
        tbl.info[j].name = name
    end
    Store_To_PEXT(tbl)
end

function ShowAll(track, tbl)
    local fimp = reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE")
    local toggle = fimp == 2 and 0 or 2
    if fimp == 0 then
        SaveCurrentState(track, tbl)
    elseif fimp == 2 then
        StoreLaneData(track, tbl)
    end
    Clear(track)
    if toggle == 2 then
        for i = 1, #tbl.info do
            local items = Create_item(track, tbl.info[i])
            for j = 1, #items do
                reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_H", 1 / #tbl.info)
                reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_Y", ((i - 1) / #tbl.info))
            end
        end
    elseif toggle == 0 then
        Create_item(track, tbl.info[tbl.idx])
    end
    reaper.SetMediaTrackInfo_Value(track, "I_FREEMODE", toggle)
    reaper.UpdateTimeline()
end

local function CreateVTElements(direct)
    for track in pairs(TBH) do
        if not VT_TB[track] then
            local Element = Get_class_tbl()
            local tr_data = GetChunkTableForObject(track)
            tr_data.name = "MAIN"
            VT_TB[track] = Element:new(track, {tr_data}, direct)
            Restore_From_PEXT(VT_TB[track])
        end
    end
end

function Create_VT_Element()
    GetTracksXYH()
    ValidateRemovedTracks()
    if reaper.CountTracks(0) == 0 then return end
    CreateVTElements(0)
end

function SetupSingleElement(rprobj)
    TBH = {}
    if reaper.ValidatePtr(rprobj, "MediaTrack*") then
        GetSingleTrackXYH(rprobj)
    elseif reaper.ValidatePtr(rprobj, "TrackEnvelope*") then
        local tr = reaper.GetEnvelopeInfo_Value(rprobj, "P_TRACK")
        if tr then
            local ismaster = tr == reaper.GetMasterTrack()
            local tr_vis = not ismaster and reaper.IsTrackVisible(tr, false) or (reaper.GetMasterTrackVisibility()&1 == 1 and true or false )
            local tr_t = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY")
            GetSingleTrackEnvelopeXYH(rprobj, tr_t, tr_vis)
        end
    end
    if #TBH then
        CreateVTElements(1)
        return 1
    end
    return 0
end
