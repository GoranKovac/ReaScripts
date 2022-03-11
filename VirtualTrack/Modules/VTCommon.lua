--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]
local reaper = reaper
local VT_TB, TBH = {}, nil

local function GetSingleTrackEnvelopeXYH(env, tr_t, tr_vis)
    local _, env_name = reaper.GetEnvelopeName(env)
    local env_h = reaper.GetEnvelopeInfo_Value(env, "I_TCPH")
    local env_t = reaper.GetEnvelopeInfo_Value(env, "I_TCPY") + tr_t
    local env_b = env_t + env_h
    local env_vis = reaper.GetEnvelopeInfo_Value(env, "I_TCPH_USED") ~= 0 and true or false
    if env_name == "Tempo map" then if tr_vis == false then env_vis = false end end -- HIDE TEMPO MAP IF MASTER IS HIDDEN
    TBH[env] = { t = env_t, b = env_b, h = env_h, vis = env_vis, name = env_name }
end

local function GetSingleTrackXYH(tr, ismaster)
    local _, tr_name = reaper.GetTrackName(tr)
    local tr_vis = not ismaster and reaper.IsTrackVisible(tr, false) or (reaper.GetMasterTrackVisibility() & 1 == 1 and true or false)
    local tr_h = reaper.GetMediaTrackInfo_Value(tr, "I_TCPH")
    local tr_t = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY")
    local tr_b = tr_t + tr_h
    TBH[tr] = { t = tr_t, b = tr_b, h = tr_h, vis = tr_vis, name = tr_name }
    for j = 1, reaper.CountTrackEnvelopes(tr) do
        local env = reaper.GetTrackEnvelope(tr, j - 1)
        GetSingleTrackEnvelopeXYH(env, tr_t, tr_vis)
    end
end

local function GetTracksXYH()
    TBH = {}
    if reaper.CountTracks(0) == 0 then return end
    for i = 0, reaper.CountTracks(0) do
        local tr = i ~= 0 and reaper.GetTrack(0, i - 1) or reaper.GetMasterTrack(0)
        GetSingleTrackXYH(tr, i == 0)
    end
end

local function Store_To_PEXT(el)
    local storedTable = {}
    storedTable.info = el.info;
    storedTable.idx = math.floor(el.idx)
    storedTable.comp_idx = math.floor(el.comp_idx)
    storedTable.lane_mode = math.floor(el.lane_mode)
    local serialized = tableToString(storedTable)
    if reaper.ValidatePtr(el.rprobj, "MediaTrack*") then
        reaper.GetSetMediaTrackInfo_String(el.rprobj, "P_EXT:VirtualTrack", serialized, true)
    elseif reaper.ValidatePtr(el.rprobj, "TrackEnvelope*") then
        reaper.GetSetEnvelopeInfo_String(el.rprobj, "P_EXT:VirtualTrack", serialized, true)
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
            el.comp_idx = storedTable.comp_idx
            el.lane_mode = storedTable.lane_mode
        end
    end
end

function Get_TBH_Info(tr) return TBH[tr] and TBH[tr].t, TBH[tr].h, TBH[tr].b end

function Get_VT_TB() return VT_TB end

function Get_TBH() return TBH end

local function ValidateRemovedTracks()
    if next(VT_TB) == nil then return end
    for k, v in pairs(VT_TB) do
        if not TBH[k] then
            v:cleanup()
            VT_TB[k] = nil
        end
    end
end

local patterns = { "SEL 0", "SEL 1" }
local function Exclude_Pattern(chunk)
    for i = 1, #patterns do chunk = string.gsub(chunk, patterns[i], "") end
    return chunk
end

local function Get_Item_Chunk(item)
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

local function Env_prop(env, val)
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
    env_chunk = env_chunk:gsub("(PT [%d%.]+ [%d%.]+ [%d%.]+ [%d%.]+) [%d%.]+", "%1 0") -- MAKE ALL POINTS UNSELECTED (5th digit is SEL 0 or 1)
    env_chunk = env_chunk:gsub("<BIN VirtualTrack.->", "") -- remove our P_EXT from this chunk!
    return { env_chunk }
end

local function Set_Env_Chunk(env, data)
    local env_lane_height = Env_prop(env, "laneHeight")
    data[1] = data[1]:gsub("LANEHEIGHT 0 0", "LANEHEIGHT " .. env_lane_height .. " 0")
    reaper.SetEnvelopeStateChunk(env, data[1], false)
end

local match = string.match
local function Make_Empty_Env(env)
    local env_chunk = Get_Env_Chunk(env)[1]
    local env_center_val = Env_prop(env, "centerValue")
    local env_fader_scaling = Env_prop(env, "faderScaling") == true and "VOLTYPE 1\n" or ""
    local env_name_from_chunk = match(env_chunk, "[^\r\n]+")
    local empty_chunk_template = env_name_from_chunk .. "\nACT 1 -1\nVIS 1 1 1\nLANEHEIGHT 0 0\nARM 1\nDEFSHAPE 0 -1 -1\n" .. env_fader_scaling .. "PT 0 " .. env_center_val .. " 0\n>"
    local current_bpm = reaper.Master_GetTempo()
    local empty_tempo_template = env_name_from_chunk .. "\nACT 1 -1\nVIS 1 0 1\nLANEHEIGHT 0 0\nARM 1\nDEFSHAPE 0 -1 -1\nPT 0.000000000000 " .. current_bpm .. " 0\n>"
    empty_chunk_template = env_name_from_chunk == "<TEMPOENVEX" and empty_tempo_template or empty_chunk_template
    Set_Env_Chunk(env, { empty_chunk_template })
end

local function Create_item(tr, data)
    local new_items = {}
    for i = 1, #data do
        local chunk = data[i]
        local empty_item = reaper.AddMediaItemToTrack(tr)
        reaper.SetItemStateChunk(empty_item, chunk, false)
        reaper.GetSetMediaItemInfo_String(empty_item, "GUID", reaper.genGuid(), true)
        for j = 1, reaper.CountTakes(empty_item) do
            local take_dst = reaper.GetMediaItemTake(empty_item, j - 1)
            reaper.GetSetMediaItemTakeInfo_String(take_dst, "GUID", reaper.genGuid(), true)
        end
        reaper.SetMediaItemInfo_Value(empty_item, "B_UISEL", 1)
        reaper.Main_OnCommand(41613, 0) -- need to clear midi pooling
        reaper.SetMediaItemInfo_Value(empty_item, "B_UISEL", 0)
        new_items[#new_items + 1] = empty_item
    end
    return new_items
end

local function GetChunkTableForObject(track)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        return Get_Track_Items(track)
    elseif reaper.ValidatePtr(track, "TrackEnvelope*") then
        return Get_Env_Chunk(track)
    end
    return nil
end

function UpdateInternalState(tbl)
    local name = tbl.info[tbl.idx].name
    local chunk_tbl = GetChunkTableForObject(tbl.rprobj)
    if chunk_tbl then
        tbl.info[tbl.idx] = chunk_tbl
        tbl.info[tbl.idx].name = name
        return true
    end
    return false
end

function StoreStateToDocument(tbl) Store_To_PEXT(tbl) end

local function SaveCurrentState(track, tbl)
    if UpdateInternalState(tbl) == true then return Store_To_PEXT(tbl) end
    return false
end

function StoreInProject()
    local rv = true
    for k, v in pairs(VT_TB) do
        rv = (SaveCurrentState(k, v) and rv == true) and true or false
    end
    if rv == true then reaper.MarkProjectDirty(0) end -- at least mark the project dirty, even if we don't offer undo here
end

function SwapVirtualTrack(tbl, idx)
    if reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then
        Clear(tbl) -- ONLY MEDIA TRACKS NEED TO BE CLEARD SINCE WE ARE INSERTING ITEMS INTO IT, ENVELOPES JUST SWAP CHUNKS
        Create_item(tbl.rprobj, tbl.info[idx])
    elseif reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then
        Set_Env_Chunk(tbl.rprobj, tbl.info[idx])
    end
    tbl.idx = idx;
end

local function Get_Store_CurrentTrackState(tbl, name)
    tbl.info[#tbl.info + 1] = GetChunkTableForObject(tbl.rprobj)
    tbl.idx = #tbl.info
    tbl.info[#tbl.info].name = name == "Version - " and name .. #tbl.info or name
end

function CreateNew(tbl)
    Clear(tbl)
    Get_Store_CurrentTrackState(tbl, "Version - ")
end

function Duplicate(tbl)
    local name = "Duplicate - " .. tbl.info[tbl.idx].name
    Get_Store_CurrentTrackState(tbl, name)
end

function Delete(tbl)
    if tbl.idx == 1 then return end
    table.remove(tbl.info, tbl.idx)
    tbl.idx = tbl.idx <= #tbl.info and tbl.idx or #tbl.info
    SwapVirtualTrack(tbl, tbl.idx)
end

function Clear(tbl)
    if reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then
        local num_items = reaper.CountTrackMediaItems(tbl.rprobj)
        for i = num_items, 1, -1 do
            local item = reaper.GetTrackMediaItem(tbl.rprobj, i - 1)
            reaper.DeleteTrackMediaItem(tbl.rprobj, item)
        end
    elseif reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then
        Make_Empty_Env(tbl.rprobj)
    end
end

function Rename(tbl)
    local retval, name = reaper.GetUserInputs("Name Version ", 1, "Version Name :", tbl.info[tbl.idx].name)
    if not retval then return end
    tbl.info[tbl.idx].name = name
end

local function GetItemLane(item)
    local y = reaper.GetMediaItemInfo_Value(item, 'F_FREEMODE_Y')
    local h = reaper.GetMediaItemInfo_Value(item, 'F_FREEMODE_H')
    return round(y / h) + 1
end

function Mute_view(tbl, num)
    reaper.PreventUIRefresh(1)
    if GetLinkVal() and reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then
        SwapVirtualTrack(tbl, num)
        return
    end
    for i = 1, reaper.CountTrackMediaItems(tbl.rprobj) do
        local item = reaper.GetTrackMediaItem(tbl.rprobj, i - 1)
        if GetItemLane(item) == num then
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", 0)
        else
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
        end
    end
    tbl.idx = num
    StoreStateToDocument(tbl)
    reaper.PreventUIRefresh(-1)
end

local function StoreLaneData(tbl)
    local num_items = reaper.CountTrackMediaItems(tbl.rprobj)
    for j = 1, #tbl.info do
        local lane_chunk = {}
        for i = 1, num_items do
            local item = reaper.GetTrackMediaItem(tbl.rprobj, i - 1)
            if GetItemLane(item) == j then
                local item_chunk = Get_Item_Chunk(item)
                item_chunk = Exclude_Pattern(item_chunk)
                lane_chunk[#lane_chunk + 1] = item_chunk
            end
        end
        local name = tbl.info[j].name
        tbl.info[j] = lane_chunk
        tbl.info[j].name = name
    end
end

local function Get_Razor_Data(track)
    if not reaper.ValidatePtr(track, "MediaTrack*") then return end
    local _, area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS_EXT', '', false)
    if area == "" then return nil end
    local area_info = {}
    for i in string.gmatch(area, "%S+") do table.insert(area_info, tonumber(i)) end
    local razor_t, razor_b = area_info[3], area_info[4]
    local razor_h = razor_b - razor_t
    local razor_lane = round(razor_b / razor_h)
    return area_info, razor_lane
end

local function Get_items_in_razor(rprobj, item)
    if not item then return end
    local area_info, razor_lane = Get_Razor_Data(rprobj)
    local tsStart, tsEnd = area_info[1], area_info[2]
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_dur = item_start + item_len
    if GetItemLane(item) == razor_lane then
        if (tsStart >= item_start and tsStart <= item_dur) or
            (tsEnd >= item_start and tsEnd <= item_dur) or
            (tsStart <= item_start and tsEnd >= item_dur) then
            return item
        end
    end
end

local function Razor_item_position(rprobj, item)
    local area_info = Get_Razor_Data(rprobj)
    local tsStart, tsEnd = area_info[1], area_info[2]
    local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_dur = item_lenght + item_start

    local new_start, new_item_lenght, offset
    if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
        ----- IF TS START IS IN ITEM BUT TS END IS OUTSIDE THEN COPY ONLY PART FROM TS START TO ITEM END
        new_start, new_item_lenght, offset = item_start, tsEnd - item_start, 0
        return new_start, new_item_lenght, offset, item
    elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
        ------ IF BOTH TS START AND TS END ARE IN ITEM COPY PART FROM TS START TO TS END
        new_start, new_item_lenght, offset = tsStart, item_dur - tsStart, (tsStart - item_start)
        return new_start, new_item_lenght, offset, item
    elseif tsStart >= item_start and tsEnd <= item_dur then
        ------ IF BOTH TS START AND TS END ARE OUT OF ITEM BUT ITEM IS IN TS COPY ITEM START END
        new_start, new_item_lenght, offset = tsStart, tsEnd - tsStart, (tsStart - item_start)
        return new_start, new_item_lenght, offset, item
    elseif tsStart <= item_start and tsEnd > item_dur then
        new_start, new_item_lenght, offset = item_start, item_lenght, 0
        return new_start, new_item_lenght, offset, item
    end
end

local function Make_item_from_razor(tbl, item)
    if not item then return end
    local filename, clonedsource
    local take = reaper.GetMediaItemTake(item, 0)
    local source = reaper.GetMediaItemTake_Source(take)
    local media_type = reaper.GetMediaSourceType(source, "")
    local item_volume = reaper.GetMediaItemInfo_Value(item, "D_VOL")
    local createdItem = reaper.AddMediaItemToTrack(tbl.rprobj)
    local createdTake = reaper.AddTakeToMediaItem(createdItem)
    if media_type:find("MIDI") then
        local _, midi_chunk = reaper.GetItemStateChunk(item, "")
        midi_chunk = midi_chunk:gsub("{.-}", "") -- Reaper auto-generates all GUIDs
        reaper.SetItemStateChunk(createdItem, midi_chunk, false)
    else
        filename = reaper.GetMediaSourceFileName(source, "")
        clonedsource = reaper.PCM_Source_CreateFromFile(filename)
    end
    local new_item_start, new_item_lenght, offset = Razor_item_position(tbl.rprobj, item)
    reaper.SetMediaItemInfo_Value(createdItem, "D_POSITION", new_item_start)
    reaper.SetMediaItemInfo_Value(createdItem, "D_LENGTH", new_item_lenght)
    local TakeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    reaper.SetMediaItemTakeInfo_Value(createdTake, "D_STARTOFFS", TakeOffset + offset)
    if media_type:find("MIDI") == nil then reaper.SetMediaItemTake_Source(createdTake, clonedsource) end
    reaper.SetMediaItemInfo_Value(createdItem, "D_VOL", item_volume)
    reaper.SetMediaItemInfo_Value(createdItem, "F_FREEMODE_Y", (tbl.comp_idx - 1) / #tbl.info)
    reaper.SetMediaItemInfo_Value(createdItem, "F_FREEMODE_H", 1 / #tbl.info)
    reaper.SetMediaItemInfo_Value(createdItem, "B_MUTE", 1)
    reaper.SetMediaItemSelected(createdItem, true)
    reaper.Main_OnCommand(40930, 0) -- TRIM BEHIND ONLY WORKS ON SELECTED ITEMS
    reaper.SetMediaItemSelected(createdItem, false)
    local _, created_chunk = reaper.GetItemStateChunk(createdItem, "")
    created_chunk = Exclude_Pattern(created_chunk)
    return createdItem, created_chunk
end

function Copy_area(tbl, lane_mode)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end -- PREVENT DOING THIS ON ENVELOPES
    if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 0 then return end -- PREVENT DOING THIS ON ENVELOPES
    local area_info, razor_lane = Get_Razor_Data(tbl.rprobj)
    if tbl.comp_idx == 0 or tbl.comp_idx == razor_lane then return end -- PREVENT COPY ONTO ITSELF
    if not area_info then return end
    reaper.Undo_BeginBlock2(0)
    reaper.PreventUIRefresh(1)
    local current_razor_toggle_state = reaper.GetToggleCommandState(42421)
    if current_razor_toggle_state == 1 then reaper.Main_OnCommand(42421, 0) end -- TURN OFF ALWAYS TRIM BEHIND RAZORS (if enabled in project)
    ------------------------ HACK FOR COPY PASTE REMOVING EMPTY LANE
    local hack_item = reaper.AddMediaItemToTrack(tbl.rprobj)
    reaper.SetMediaItemInfo_Value(hack_item, "F_FREEMODE_Y", (tbl.comp_idx - 1) / #tbl.info)
    reaper.SetMediaItemInfo_Value(hack_item, "F_FREEMODE_H", 1 / #tbl.info)
    -----------------------------------------------------------------------
    for i = 1, reaper.CountTrackMediaItems(tbl.rprobj) do
        local razor_item = Get_items_in_razor(tbl.rprobj, reaper.GetTrackMediaItem(tbl.rprobj, i - 1))
        Make_item_from_razor(tbl, razor_item)
    end
    if current_razor_toggle_state == 1 then reaper.Main_OnCommand(42421, 0) end -- TURN ON ALWAYS TRIM BEHIND RAZORS (if enabled in project)
    reaper.DeleteTrackMediaItem(tbl.rprobj, hack_item) -- REMOVE EMPTY ITEM CREATED TO HACK AROUND COPY PASTE DELETING EMPTY LANE
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock2(0, "VT: " .. "COPY AREA TO COMP", -1)
    reaper.UpdateArrange()
end

local function Unmute_All_track_items(track)
    reaper.PreventUIRefresh(1)
    for i = 1, reaper.CountTrackMediaItems(track) do -- DO IN REVERSE TO AVOID CRASHES ON ITERATING MULTIPLE ITEMS
        local item = reaper.GetMediaItem(0, i - 1)
        reaper.SetMediaItemInfo_Value(item, "B_MUTE", 0)
    end
    reaper.PreventUIRefresh(-1)
end

function Unmuted_lane(tbl)
    for i = 1, reaper.CountTrackMediaItems(tbl.rprobj) do
        local item = reaper.GetTrackMediaItem(tbl.rprobj, i - 1)
        if reaper.GetMediaItemInfo_Value(item, "B_MUTE") == 0 then
            return GetItemLane(item)
        end
    end
end

function CheckTrackLaneModeState(tbl)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end
    local current_state = reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE")
    if current_state == 2 and tbl.lane_mode ~= 2 then
        reaper.PreventUIRefresh(1)
        Clear(tbl)
        for i = 1, #tbl.info do
            local items = Create_item(tbl.rprobj, tbl.info[i])
            for j = 1, #items do
                reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_Y", ((i - 1) / #tbl.info))
                reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_H", 1 / #tbl.info)
            end
        end
        Mute_view(tbl, tbl.idx)
        reaper.PreventUIRefresh(-1)
        tbl.lane_mode = 2
        StoreStateToDocument(tbl)
    end
end

function ShowAll(tbl)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end
    local fimp = reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE")
    local toggle = fimp == 2 and 0 or 2
    tbl.lane_mode = toggle
    if fimp == 2 then
        Unmute_All_track_items(tbl.rprobj) -- UNMUTE ALL ITEMS FROM MUTE_VIEW FUNCTION BEFORE STORING
        StoreLaneData(tbl)
    end
    Clear(tbl)
    if toggle == 2 then
        for i = 1, #tbl.info do
            local items = Create_item(tbl.rprobj, tbl.info[i])
            for j = 1, #items do
                reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_Y", ((i - 1) / #tbl.info))
                reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_H", 1 / #tbl.info)
            end
        end
        Mute_view(tbl, tbl.idx)
    elseif toggle == 0 then
        tbl.comp_idx = 0 -- DISABLE COMPING
        Create_item(tbl.rprobj, tbl.info[tbl.idx])
    end
    reaper.SetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE", toggle)
    reaper.UpdateTimeline()
end

local function CreateVTElements(direct)
    for track in pairs(TBH) do
        if not VT_TB[track] then
            local Element = Get_class_tbl()
            local tr_data = GetChunkTableForObject(track)
            tr_data.name = "Version - 1"
            VT_TB[track] = Element:new(track, { tr_data }, direct)
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

local function GetTrackXYH(rprobj)
    if reaper.ValidatePtr(rprobj, "MediaTrack*") then
        GetSingleTrackXYH(rprobj)
    elseif reaper.ValidatePtr(rprobj, "TrackEnvelope*") then
        local tr = reaper.GetEnvelopeInfo_Value(rprobj, "P_TRACK")
        if tr then
            local ismaster = tr == reaper.GetMasterTrack()
            local tr_vis = not ismaster and reaper.IsTrackVisible(tr, false) or (reaper.GetMasterTrackVisibility() & 1 == 1 and true or false)
            local tr_t = reaper.GetMediaTrackInfo_Value(tr, "I_TCPY")
            GetSingleTrackEnvelopeXYH(rprobj, tr_t, tr_vis)
        end
    end
end

local function SetupSingleElement(rprobj)
    TBH = {}
    GetTrackXYH(rprobj)
    if #TBH then CreateVTElements(1) return 1 end
    return 0
end

function OnDemand()
    local rprobj = GetMouseTrack_BR()
    if rprobj then
        if SetupSingleElement(rprobj) and #Get_VT_TB() then
            return rprobj
        end
    end
end

local projectStateChangeCount = reaper.GetProjectStateChangeCount(0)
function UpdateChangeCount() projectStateChangeCount = reaper.GetProjectStateChangeCount(0) end

function CheckUndoState()
    local changeCount = reaper.GetProjectStateChangeCount()
    if changeCount ~= projectStateChangeCount then
        projectStateChangeCount = changeCount
        local success = false
        local last_action = reaper.Undo_CanRedo2(0)
        if last_action and last_action:find("VT: ") then success = true end
        if not success then last_action = reaper.Undo_CanUndo2(0) end
        for _, v in pairs(VT_TB) do
            local oldidx = v.idx
            Restore_From_PEXT(v)
            if oldidx ~= v.idx then
                v:update_xywh() -- update buttons
            end
        end
    end
end

function GetLinkVal()
    local retval, link = reaper.GetProjExtState(0, "VirtualTrack", "LINK")
    if retval ~= 0 then return link == "true" and true or false end
    return false
end

function SetLinkVal(tbl)
    local cur_value = GetLinkVal() == true and "false" or "true"
    reaper.SetProjExtState(0, "VirtualTrack", "LINK", cur_value)
    StoreStateToDocument(tbl)
end

local function CheckIfTableIDX_Exists(parent_tr, child_tr)
    if #VT_TB[parent_tr].info ~= #VT_TB[child_tr].info then
        for i = 1, #VT_TB[parent_tr].info do
            if not VT_TB[child_tr].info[i] then CreateNew(VT_TB[child_tr]) end
        end
        StoreStateToDocument(VT_TB[child_tr])
    end
    if #VT_TB[child_tr].info ~= #VT_TB[parent_tr].info then
        for i = 1, #VT_TB[child_tr].info do
            if not VT_TB[parent_tr].info[i] then CreateNew(VT_TB[parent_tr]) end
        end
        StoreStateToDocument(VT_TB[parent_tr])
    end
end

function GetLinkedTracksVT_INFO(tracl_tbl, on_demand) -- WE SEND ON DEMAND FROM DIRECT SCRIPT
    if not GetLinkVal() then return tracl_tbl end -- IF LINK IS OFF RETURN ORIGINAL TBL
    local all_linked_tracks = {}
    for track in pairs(tracl_tbl) do
        if reaper.ValidatePtr(track, "MediaTrack*") then
            all_linked_tracks[track] = track
            for i = 1, reaper.CountTrackEnvelopes(track) do
                local env = reaper.GetTrackEnvelope(track, i - 1)
                all_linked_tracks[env] = env
            end
        elseif reaper.ValidatePtr(track, "TrackEnvelope*") then
            local parent_tr = reaper.GetEnvelopeInfo_Value(track, "P_TRACK")
            all_linked_tracks[parent_tr] = parent_tr
            for i = 1, reaper.CountTrackEnvelopes(parent_tr) do
                local env = reaper.GetTrackEnvelope(parent_tr, i - 1)
                all_linked_tracks[env] = env
            end
        end
    end
    for track in pairs(all_linked_tracks) do
        if not on_demand then
            if not VT_TB[track] then table.remove(all_linked_tracks, track) end
        else
            if not VT_TB[track] then SetupSingleElement(track) end
        end
    end
    for linked_track in pairs(all_linked_tracks) do
        for track in pairs(tracl_tbl) do
            CheckIfTableIDX_Exists(track, linked_track)
        end
    end
    return all_linked_tracks
end

function SetCompLane(tbl)
    tbl.comp_idx = tbl.comp_idx == 0 and MouseInfo(VT_TB).last_menu_lane or 0
    StoreStateToDocument(tbl)
end

local function GetFolderChilds(track)
    if not reaper.ValidatePtr(track, "MediaTrack*") then return end
    if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") <= 0 then return end -- ignore tracks and last folder child
    local depth, children = 0, {}
    local folderID = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = folderID + 1, reaper.CountTracks(0) - 1 do -- start from first track after folder
        local child = reaper.GetTrack(0, i)
        local currDepth = reaper.GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
        children[child] = child
        depth = depth + currDepth
        if depth <= -1 then break end --until we are out of folder
    end
    return children
end

local function GetSelectedTracks()
    if reaper.CountSelectedTracks(0) < 2 then return end -- MULTISELECTION START ONLY IF 2 OR MORE TRACKS ARE SELECTED
    local selected_tracks = {}
    for i = 1, reaper.CountSelectedTracks(0) do
        local track = reaper.GetSelectedTrack(0, i - 1)
        selected_tracks[track] = track
    end
    return selected_tracks
end

function GetSelectedTracksData(rprobj, on_demand)
    local tracks = GetSelectedTracks()
    if not tracks then return { [rprobj] = rprobj } end
    if tracks then
        if not tracks[rprobj] then tracks[rprobj] = rprobj end -- insert current track into selection also
        if on_demand then
            for track in pairs(tracks) do GetTrackXYH(track) end
            CreateVTElements(1)
        end
        return tracks
    end
end
