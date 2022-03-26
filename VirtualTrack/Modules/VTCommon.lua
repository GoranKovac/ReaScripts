--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.03
	 * NoIndex: true
--]]

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])"):gsub("[\\|/]Modules", "")
local reaper = reaper
local VT_TB, TBH, GROUP_LIST, CUR_GROUP = {}, nil, nil, 1

local function Update_tempo_map()
    if reaper.CountTempoTimeSigMarkers(0) then
        local _, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, 0)
        reaper.SetTempoTimeSigMarker(0, 0, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo)
    end
    reaper.UpdateTimeline()
end

local ctx = reaper.ImGui_CreateContext('My script', reaper.ImGui_ConfigFlags_NoSavedSettings())

function Draw_Color_Rect()
    local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
    local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, min_x, min_y, max_x, max_y, 0x11FFFF80)
end

local function rename222()
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
    end
    reaper.ImGui_InputText(ctx, 'Name')
    if reaper.ImGui_Button(ctx, 'OK') then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Cancel') then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function Popup()
    reaper.ImGui_TextColored( ctx, 0x3EFF00FF, "    VIRTUAL TRACK     " )
    Draw_Color_Rect()
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_BeginMenu(ctx, "      " .. SEL_TRACK_TBL.info[SEL_TRACK_TBL.idx].name, true) then
        for i = 1, #SEL_TRACK_TBL.info do
            if reaper.ImGui_MenuItem(ctx, SEL_TRACK_TBL.info[i].name, nil, i == SEL_TRACK_TBL.idx) then SwapVirtualTrack(nil, i) end
        end
        reaper.ImGui_EndMenu(ctx)
    end
    reaper.ImGui_Separator(ctx)
    local is_button_enabled = SEL_TRACK_TBL.comp_idx == 0
    local comp_enabled = SEL_TRACK_TBL.comp_idx ~= 0
    if reaper.ImGui_MenuItem(ctx, 'Create New', nil, nil, is_button_enabled) then CreateNew() end
    if reaper.ImGui_MenuItem(ctx, 'Delete', nil, nil, (#SEL_TRACK_TBL.info > 1 and is_button_enabled)) then Delete() end
    if reaper.ImGui_MenuItem(ctx, 'Duplicate', nil, nil, is_button_enabled) then Duplicate() end
    if reaper.ImGui_Selectable(ctx, 'Rename', nil, reaper.ImGui_SelectableFlags_DontClosePopups()) then
        reaper.ImGui_OpenPopup(ctx, 'Rename Version')
    end
    if reaper.ImGui_BeginPopupModal(ctx, 'Rename Version', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        rename222()
        reaper.ImGui_EndPopup(ctx)
    end
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") then
        local group_names = SEL_TRACK_TBL.group ~= 0 and "" or "None"
        for i = 1, #GROUP_LIST do
             if CheckGroup(i, SEL_TRACK_TBL.group) then group_names = group_names .. i .. " " end
        end
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Selectable(ctx, 'GROUPS', nil, reaper.ImGui_SelectableFlags_DontClosePopups()) then
            reaper.ImGui_OpenPopup(ctx, 'GROUP_WINDOW')
        end
        if reaper.ImGui_BeginPopupModal(ctx, 'GROUP_WINDOW', true, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            STORE_GROUPS = true
            Group_GUI()
            reaper.ImGui_EndPopup(ctx)
        elseif STORE_GROUPS then
            Store_GROUPS_TO_Project_EXT_STATE()
        end
        local is_group_enabled = GROUP_LIST[CUR_GROUP].enabled == true
        if is_group_enabled then reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x3EFF00FF) end -- MAKE TEXT GREEN WHEN ENABLED
        if reaper.ImGui_MenuItem(ctx, 'ENABLED', nil, is_group_enabled) then
            GROUP_LIST[CUR_GROUP].enabled = not GROUP_LIST[CUR_GROUP].enabled
            Store_GROUPS_TO_Project_EXT_STATE()
        end
        if is_group_enabled then Draw_Color_Rect() reaper.ImGui_PopStyleColor(ctx) end
    end
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") and SEL_TRACK_TBL.lane_mode == 2 then
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_MenuItem(ctx, 'New Empty COMP', nil, nil, is_button_enabled) then NewComp() end
        if comp_enabled then reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x3EFF00FF) end -- MAKE TEXT GREEN WHEN ENABLED
        if reaper.ImGui_MenuItem(ctx, 'Enable COMP', nil, comp_enabled) then SetCompLane() end
        if comp_enabled then Draw_Color_Rect() reaper.ImGui_PopStyleColor(ctx) end
    end
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") then
        reaper.ImGui_Separator(ctx)
        local is_lane_mode = SEL_TRACK_TBL.lane_mode == 2
        if is_lane_mode then reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x3EFF00FF) end -- MAKE TEXT GREEN WHEN ENABLED
        if reaper.ImGui_MenuItem(ctx, 'Show All', nil, SEL_TRACK_TBL.lane_mode == 2, is_button_enabled) then ShowAll() end
        if is_lane_mode then Draw_Color_Rect() reaper.ImGui_PopStyleColor(ctx) end
    end
end

function Add_Tracks()
    local sel_tracks = {}
    local stored_tbl = Get_Stored_PEXT_STATE_TBL()
    for i = 1,  reaper.CountSelectedTracks(0) do
        local track = reaper.GetSelectedTrack(0, i - 1)
        if stored_tbl[track] then
            sel_tracks[track] = stored_tbl[track]
        end
    end
    for _, v in pairs(sel_tracks) do
        SetGroup(v, CUR_GROUP, true)
    end
    TRACK_GROUPS = GetTrackGroup(CUR_GROUP)
end

function ToolTip(text)
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
        reaper.ImGui_PushTextWrapPos(ctx, 200)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end

function Group_GUI()
    reaper.ImGui_SetNextItemWidth(ctx, 147) -- OPTIONAL if you want to set docker width
    if reaper.ImGui_BeginCombo(ctx, '##docker', GROUP_LIST[CUR_GROUP].name or GROUP_LIST[1].name) then -- putting ## in the id section will make it without any name text in the UI
        for i = 1, #GROUP_LIST do -- Iterate for each element in the combo list
            local is_selected = i == CUR_GROUP
            if reaper.ImGui_Selectable(ctx, GROUP_LIST[i].name, is_selected) then --this create each of the combo item. Be carefull if they have the same name you have ID problems. This is why I put ..'##'..i at the end. try to remove it and click on repeted nameded elements.
                CUR_GROUP = i
                TRACK_GROUPS = GetTrackGroup(i)
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end

    reaper.ImGui_SameLine(ctx)

    RV, GROUP_LIST[CUR_GROUP].enabled = reaper.ImGui_Checkbox(ctx, 'ENABLED', GROUP_LIST[CUR_GROUP].enabled)
    ToolTip('Enable or disable current group')

    if reaper.ImGui_BeginListBox(ctx, '##listbox',-1) then -- -1 set width to the end of the window
        for k, v in pairs(TRACK_GROUPS) do -- Iterate for each element in the combo list
            if reaper.ValidatePtr( k, "MediaTrack*" ) then
                local _, buf = reaper.GetTrackName( k )
                if reaper.ImGui_Selectable(ctx, buf..'##', v.Select) then --this create each of items. Be carefull if they have the same name you have ID problems. This is why I put ..'##'..i at the end. try to remove it and click on repeted nameded elements.
                    if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 0 then
                        for _, info in pairs(TRACK_GROUPS) do info.Select = false end
                    end
                    v.Select = not v.Select
                end
            else
                TRACK_GROUPS[k] = nil
            end
        end
        reaper.ImGui_EndListBox(ctx)
    end

    if reaper.ImGui_Button(ctx, 'Add Track', -1) then Add_Tracks() end -- -1 set width to the end of the window
    ToolTip('Add selected tracks from TCP or MCP view')

    if reaper.ImGui_Button(ctx, 'Remove Track', -1) then -- -1 set width to the end of the window
        for _, v in pairs(TRACK_GROUPS) do
            if v.Select then
                SetGroup(v, CUR_GROUP, false)
            end
        end
        TRACK_GROUPS = GetTrackGroup(CUR_GROUP)
    end
    ToolTip('Remove tracks from list view')
end

function GUI()
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetNextWindowPos(ctx, reaper.ImGui_PointConvertNative(ctx, reaper.GetMousePosition()))
        reaper.ImGui_OpenPopup(ctx, 'Menu')
    end
    if reaper.ImGui_BeginPopup(ctx, 'Menu') then
        Popup()
        reaper.ImGui_EndPopup(ctx)
        reaper.defer(GUI)
    else
        reaper.ImGui_DestroyContext(ctx)
        STORE_DATA = true
    end
    if STORE_DATA then
        for track, tr_tbl in pairs(CURRENT_TRACKS) do StoreStateToDocument(tr_tbl) end
        if UPDATE_TEMPO then Update_tempo_map() end
        UpdateChangeCount()
    end
end

function Show_menu(rprobj, on_demand)
    MouseInfo().last_menu_lane = MouseInfo().lane-- SET LAST LANE BEFORE MENU OPENED
    MouseInfo().last_menu_tr = MouseInfo().tr -- SET LAST TRACK BEFORE MENU OPENED
    CheckTrackLaneModeState(VT_TB[rprobj])
    GROUP_LIST = Restore_GROUPS_FROM_Project_EXT_STATE()
    TRACK_GROUPS = GetTrackGroup(CUR_GROUP) or {}
    CURRENT_TRACKS = GetSelectedTracksData(rprobj, on_demand) -- THIS ADDS NEW TRACKS TO VT_TB FOR ON DEMAND SCRIPT AND RETURNS TRACK SELECTION
    UPDATE_TEMPO = rprobj == reaper.GetMasterTrack(0) and true or false
    SEL_TRACK_TBL = rprobj == reaper.GetMasterTrack(0) and VT_TB[reaper.GetTrackEnvelopeByName( rprobj, "Tempo map" )] or VT_TB[rprobj]
    for track, tr_tbl in pairs(CURRENT_TRACKS) do UpdateInternalState(tr_tbl) end
    GUI()
end

local prev_Arr_end_time, prev_proj_state, last_scroll, last_scroll_b, last_pr_t, last_pr_h
function Arrange_view_info()
    local last_pr_tr = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
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
        if TBH[last_pr_tr] and TBH[last_pr_tr].h ~= last_pr_h or TBH[last_pr_tr].t ~= last_pr_t then
            last_pr_h = TBH[last_pr_tr].h
            last_pr_t = TBH[last_pr_tr].t
            return true
        end
    end
end

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
    local storedTable = {
        info = el.info,
        idx = math.floor(el.idx),
        comp_idx = math.floor(el.comp_idx),
        lane_mode = math.floor(el.lane_mode),
        def_icon = el.def_icon,
        group = el.group,
    }
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
            el.def_icon = storedTable.def_icon
            el.group = storedTable.group
            return true
        end
    end
end

function Get_Stored_PEXT_STATE_TBL()
    local stored_tbl = {}
    for i = 1, reaper.CountTracks(0) do
        local track = reaper.GetTrack(0, i - 1)
        stored_tbl[track] = {}
        stored_tbl[track].rprobj = track
        if not Restore_From_PEXT(stored_tbl[track]) then stored_tbl[track] = nil end
        for j = 1, reaper.CountTrackEnvelopes(track) do
            local env = reaper.GetTrackEnvelope(track, j - 1)
            stored_tbl[env] = {}
            stored_tbl[env].rprobj = env
            if not Restore_From_PEXT(stored_tbl[env]) then stored_tbl[env] = nil end
        end
    end
    return stored_tbl
end

function Get_TBH_Info(tr) return TBH[tr] and TBH[tr].t, TBH[tr].h, TBH[tr].b end

function Get_VT_TB() return VT_TB end

function Get_TBH() return TBH end

function ValidateRemovedTracks()
    if next(VT_TB) == nil then return end
    for k, v in pairs(VT_TB) do
        if not TBH[k] then
            v:cleanup()
            VT_TB[k] = nil
        end
    end
end

local function GetItemLane(item)
    local y = reaper.GetMediaItemInfo_Value(item, 'F_FREEMODE_Y')
    local h = reaper.GetMediaItemInfo_Value(item, 'F_FREEMODE_H')
    return round(y / h) + 1
end

local function Get_Item_Chunk(item, keep_color)
    local _, chunk = reaper.GetItemStateChunk(item, "", false)
    chunk = keep_color and chunk or chunk:gsub("TAKECOLOR %S+ %S+", "") -- KEEP COLOR TEMPORARY ONLY WHEN IN LANE MODE
    chunk = chunk:gsub("SEL.-\n", "") -- REMOVE SELECTED FIELD IN CHUNK (WE DO NOT STORE SELECTED STATE)
    return chunk
end

local function Get_Track_Items(track)
    local items_chunk = {}
    local num_items = reaper.CountTrackMediaItems(track)
    for i = 1, num_items, 1 do
        local item = reaper.GetTrackMediaItem(track, i - 1)
        items_chunk[#items_chunk + 1] = Get_Item_Chunk(item)
    end
    return items_chunk
end

local function Get_Track_Lane_Items(track)
    if not reaper.GetTrackMediaItem(track, 0) then return end
    local tr_data = {}
    local num_items, item_for_height = reaper.CountTrackMediaItems(track), reaper.GetTrackMediaItem(track, 0)
    local total_lanes = round(1 / reaper.GetMediaItemInfo_Value(item_for_height, 'F_FREEMODE_H')) -- WE CHECK LANE HEIGHT WITH ANY ITEM ON TRACK
    for i = 1, total_lanes do
        tr_data[i] = {}
        for j = 1, num_items do
            local item = reaper.GetTrackMediaItem(track, j - 1)
            if GetItemLane(item) == i then
                tr_data[i][#tr_data[i] + 1] = Get_Item_Chunk(item)
            end
        end
    end
    return tr_data
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
    env_chunk = env_chunk:gsub("(PT %S+ %S+ %S+ %S+) %S+", "%1 0") -- MAKE ENVELOPE POINTS UNSELECTED (5th FIELD IS SEL)
    env_chunk = env_chunk:gsub("<BIN VirtualTrack.->", "") -- remove our P_EXT from this chunk!
    return { env_chunk }
end

local function Set_Env_Chunk(env, data)
    if data == nil then return end
    data[1] = data[1]:gsub("LANEHEIGHT.-\n", "") -- MAKE LANE HEIGHT CURRENT HEIGHT (REAPER GENERATES CURRENT LANE HEIGHT IF ITS REMOVED)
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
    if data == nil then return end
    local new_items = {}
    for i = 1, #data do
        local empty_item = reaper.AddMediaItemToTrack(tr)
        reaper.SetItemStateChunk(empty_item, data[i], false)
        new_items[#new_items + 1] = empty_item
    end
    return new_items
end

local function GetChunkTableForObject(track, check_lane_mode_on_startup)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        --! FIXME: HANDLE FIMP ?
        if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 and check_lane_mode_on_startup then -- WE ONLY DO THIS ON SCRIPT STARTUP IF TRACK IS IN LANE MODE TO STORE LANES AS VERSIONS
            return Get_Track_Lane_Items(track), true
        elseif reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 0 then
            return Get_Track_Items(track), false
        end
    elseif reaper.ValidatePtr(track, "TrackEnvelope*") then
        return Get_Env_Chunk(track), false
    end
    return nil
end

local function StoreLaneData(tbl)
    local num_items = reaper.CountTrackMediaItems(tbl.rprobj)
    for i = 1, #tbl.info do
        local lane_chunk = {}
        for j = 1, num_items do
            local item = reaper.GetTrackMediaItem(tbl.rprobj, j - 1)
            if GetItemLane(item) == i then
                local item_chunk = Get_Item_Chunk(item)
                lane_chunk[#lane_chunk + 1] = item_chunk
            end
        end
        local name = tbl.info[i].name
        tbl.info[i] = lane_chunk
        tbl.info[i].name = name
    end
end

function UpdateInternalState(tbl)
    if not tbl or not tbl.info[tbl.idx] then return false end
    if tbl.lane_mode == 2 then -- ONLY HAPPENS ON MEDIA TRACKS
        StoreLaneData(tbl)
        return true
    else
        local name = tbl.info[tbl.idx].name
        local chunk_tbl = GetChunkTableForObject(tbl.rprobj)
        if chunk_tbl then
            tbl.info[tbl.idx] = chunk_tbl
            tbl.info[tbl.idx].name = name
            return true
        end
    end
    return false
end

function StoreStateToDocument(tbl) Store_To_PEXT(tbl) end

local function SaveCurrentState(tbl)
    if UpdateInternalState(tbl) == true then return Store_To_PEXT(tbl) end
    return false
end

function StoreInProject()
    local rv = true
    for _, v in pairs(VT_TB) do
        rv = (SaveCurrentState(v) and rv == true) and true or false
    end
    if rv == true then reaper.MarkProjectDirty(0) end -- at least mark the project dirty, even if we don't offer undo here
end

function SwapVirtualTrack(tbl, idx)
    local selected_tracks = tbl and {tbl} or CURRENT_TRACKS
    for track, tr_tbl in pairs(selected_tracks) do
        if reaper.ValidatePtr(tr_tbl.rprobj, "MediaTrack*") then
            if tr_tbl.lane_mode == 0 then
                Clear(tr_tbl)
                Create_item(tr_tbl.rprobj, tr_tbl.info[idx])
            elseif tr_tbl.lane_mode == 2 then
                SetInsertLaneChunk(tr_tbl, idx)
            end
        elseif reaper.ValidatePtr(tr_tbl.rprobj, "TrackEnvelope*") then
            Clear(tr_tbl)
            Set_Env_Chunk(tr_tbl.rprobj, tr_tbl.info[idx])
        end
        tr_tbl.idx = idx;
    end
end

local function Get_Store_CurrentTrackState(tbl, name)
    local data = GetChunkTableForObject(tbl.rprobj)
    table.insert(tbl.info, 1, data) --! ORDER NEWEST TO OLDEST
    --tbl.info[#tbl.info + 1] = data --! ORDER OLDEST TO NEWEST (CAUSES PROBLEMS WITH IF LAST LANE IS EMPTY ATM)
    tbl.idx = 1
    tbl.info[1].name = name == "Version " and name .. #tbl.info or name
end

function Set_LaneView_mode(tbl)
    Clear(tbl)
    SetItemsInLanes(tbl)
    reaper.SetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE", 2)
    SetInsertLaneChunk(tbl, tbl.idx)
    SetLaneImageColors(tbl)
end

function CreateNew(tbl, name)
    reaper.PreventUIRefresh(1)
    local selected_tracks = tbl and {tbl} or CURRENT_TRACKS
    for track, tr_tbl in pairs(selected_tracks) do
        Clear(tr_tbl)
        local version_name = name and name or "Version "
        Get_Store_CurrentTrackState(tr_tbl, version_name)
        if tr_tbl.lane_mode == 2 then Set_LaneView_mode(tr_tbl) end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function Duplicate(tbl)
    reaper.PreventUIRefresh(1)
    local selected_tracks = tbl and {tbl} or CURRENT_TRACKS
    for track, tr_tbl in pairs(selected_tracks) do
        Clear(tr_tbl) -- if its not clear for some reason it does not change guids (probably because of updateinternalstate)
        local name = tr_tbl.info[tr_tbl.idx].name .. " DUP"
        local duplicate_tbl = Deepcopy(tr_tbl.info[tr_tbl.idx]) -- DEEP COPY TABLE SO ITS UNIQUE (LUA DOES SHALLOW BY DEFAULT)
        for i = 1, #duplicate_tbl do duplicate_tbl[i] = duplicate_tbl[i]:gsub("{.-}", "") end --! GENERATE NEW GUIDS FOR NEW ITEM (fixes duplicate make pooled items)
        table.insert(tr_tbl.info, 1, duplicate_tbl) --! ORDER NEWEST TO OLDEST
        tr_tbl.idx = 1
        tr_tbl.info[tr_tbl.idx].name = name
        SwapVirtualTrack(tr_tbl, tr_tbl.idx)
        if reaper.ValidatePtr(tr_tbl.rprobj, "MediaTrack*") then
            if tr_tbl.lane_mode == 2 then Set_LaneView_mode(tr_tbl) end
        end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function Delete(tbl)
    reaper.PreventUIRefresh(1)
    local selected_tracks = tbl and {tbl} or CURRENT_TRACKS
    for track, tr_tbl in pairs(selected_tracks) do
        if #tr_tbl.info == 1 then return end
        table.remove(tr_tbl.info, tr_tbl.idx)
        tr_tbl.idx = tr_tbl.idx <= #tr_tbl.info and tr_tbl.idx or #tr_tbl.info
        if tr_tbl.lane_mode == 2 then
            Set_LaneView_mode(tr_tbl)
        elseif tr_tbl.lane_mode == 0 then
            SwapVirtualTrack(tr_tbl, tr_tbl.idx)
        end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function Clear(tbl)
    reaper.PreventUIRefresh(1)
    if reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then
        reaper.SetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE", 0) -- ALWAYS TURN OFF LANES WHEN CLEARING ITEMS
        local num_items = reaper.CountTrackMediaItems(tbl.rprobj)
        for i = num_items, 1, -1 do
            local item = reaper.GetTrackMediaItem(tbl.rprobj, i - 1)
            reaper.DeleteTrackMediaItem(tbl.rprobj, item)
        end
    elseif reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then
        Make_Empty_Env(tbl.rprobj)
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function Rename(tbl, name)
    if not name then return end
    local selected_tracks = tbl and {tbl} or CURRENT_TRACKS
    for track, tr_tbl in pairs(selected_tracks) do
        tr_tbl.info[tr_tbl.idx].name = name
    end
end

function SetInsertLaneChunk(tbl, lane)
    local _, track_chunk = reaper.GetTrackStateChunk(tbl.rprobj, "", false)
    local lane_mask = 2^(lane-1)
    if not track_chunk:find("LANESOLO") then -- IF ANY LANE IS NOT SOLOED LANESOLO PART DOES NOT EXIST YET AND WE NEED TO INJECT IT
        local insert_pos = string.find(track_chunk, "\n") -- INSERT AFTER FIRST NEW LINE <TRACK IN THIS CASE
        track_chunk = track_chunk:sub(1, insert_pos) .. string.format("LANESOLO %i 0", lane_mask .. "\n") ..track_chunk:sub(insert_pos + 1)
    else
        track_chunk = track_chunk:gsub("(LANESOLO )%d+", "%1" ..lane_mask)
    end
    reaper.SetTrackStateChunk(tbl.rprobj, track_chunk, false)
end

function Get_Razor_Data(track)
    if not reaper.ValidatePtr(track, "MediaTrack*") then return end
    local _, razor_area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS_EXT', '', false)
    if razor_area == "" then return nil end
    local razor_info = {}
    for i in string.gmatch(razor_area, "%S+") do table.insert(razor_info, tonumber(i)) end
    local razor_t, razor_b = razor_info[3], razor_info[4]
    local razor_h = razor_b - razor_t
    razor_info.razor_lane = round(razor_b / razor_h)
    return razor_info
end

function Set_Razor_Data(tbl, razor_data)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end
    local razor_str = razor_data[1] .. " " .. razor_data[2] .. " " .. "'' " .. razor_data[3] .. " " .. razor_data[4]
    reaper.GetSetMediaTrackInfo_String(tbl.rprobj, "P_RAZOREDITS_EXT", razor_str, true)
end

local function Get_items_in_Lane(item, time_Start, time_End, lane)
    if not item then return end
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_len
    if GetItemLane(item) == lane then
        if (time_Start < item_end and time_End > item_start) then return item end
    end
end

local function Razor_item_position(item, time_Start, time_End)
    local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = item_lenght + item_start
    local new_start = time_Start <= item_start and item_start or time_Start
    local new_lenght = time_End >= item_end and item_end - new_start or time_End - new_start
    local new_offset = time_Start <= item_start and 0 or (time_Start - item_start)
    return new_start, new_lenght, new_offset
end

local function Delete_items_or_area(item, time_Start, time_End)
    local first_to_delete = reaper.SplitMediaItem(item, time_End)
    local last_to_delete = reaper.SplitMediaItem(item, time_Start)
    if first_to_delete and last_to_delete then
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( last_to_delete ), last_to_delete)
    elseif last_to_delete and not first_to_delete then
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( last_to_delete ), last_to_delete)
    elseif first_to_delete and not last_to_delete then
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( item ), item)
    elseif not first_to_delete and not last_to_delete then
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track( item ), item)
    end
end

function Set_Take_marker(item, name, pos)
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local new_pos = pos and pos or item_start
    local take = reaper.GetActiveTake(item)
    local rate = reaper.GetMediaItemTakeInfo_Value( take, "D_PLAYRATE" )
    local offset = reaper.GetMediaItemTakeInfo_Value( take, "D_STARTOFFS" )
    reaper.SetTakeMarker(take, -1, name, (new_pos - item_start + offset) * rate)
  end

local function Make_item_from_razor(tbl, item, razor_info)
    if not item then return end
    local time_Start, time_End, razor_lane = razor_info[1], razor_info[2], razor_info.razor_lane
    local item_chunk = Get_Item_Chunk(item, true):gsub("{.-}", "") -- GENERATE NEW GUIDS FOR NEW ITEM, WE KEEP COLOR HERE TO GET IT IN COMP LANE (ITS REMOVED WHEN COMP IS OFF)
    local new_item_start, new_item_lenght, new_item_offset = Razor_item_position(item, time_Start, time_End)
    local item_start_offset = tonumber(item_chunk:match("SOFFS (%S+)"))
    local item_play_rate = tonumber(item_chunk:match("PLAYRATE (%S+)"))
    local auto_crossfade = reaper.GetToggleCommandState(40041)
    local rv, def_auto_crossfade_value = reaper.get_config_var_string("defsplitxfadelen")
    local crossfade_offset = auto_crossfade == 1 and def_auto_crossfade_value or 0
    local created_chunk = item_chunk:gsub("(POSITION) %S+", "%1 " .. new_item_start - crossfade_offset):gsub("(LENGTH) %S+", "%1 " .. new_item_lenght + (crossfade_offset * 2)):gsub("(SOFFS) %S+", "%1 " .. item_start_offset + (new_item_offset * item_play_rate) - crossfade_offset)
    local createdItem = reaper.AddMediaItemToTrack(tbl.rprobj)
    reaper.SetItemStateChunk(createdItem, created_chunk, false)
    reaper.SetMediaItemInfo_Value(createdItem, "F_FREEMODE_Y", (tbl.comp_idx - 1) / #tbl.info)
    reaper.SetMediaItemInfo_Value(createdItem, "F_FREEMODE_H", 1 / #tbl.info)
    --Set_Take_marker(createdItem, tbl.info[razor_lane].name)
    --reaper.SetMediaItemSelected(createdItem, true)
    --reaper.Main_OnCommand(40930, 0) -- TRIM BEHIND ONLY WORKS ON SELECTED ITEMS
    --reaper.SetMediaItemSelected(createdItem, false)
    return createdItem, created_chunk
end

function Copy_area(tbl, razor_info)
    if reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then return end -- PREVENT DOING THIS ON ENVELOPES
    if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 0 then return end -- PREVENT DOING IN NON LANE MODE
    if tbl.comp_idx == 0 or tbl.comp_idx == razor_info.razor_lane then return end -- PREVENT COPY ONTO ITSELF
    Set_Razor_Data(tbl, razor_info) -- JUST SET RAZOR ON OTHER TRACKS (ONLY FOR VISUAL)
    --local current_razor_toggle_state = reaper.GetToggleCommandState(42421)
    --if current_razor_toggle_state == 1 then reaper.Main_OnCommand(42421, 0) end -- TURN OFF ALWAYS TRIM BEHIND RAZORS (if enabled in project)
    local new_items, to_delete = {}, {}
    for i = 1, reaper.CountTrackMediaItems(tbl.rprobj) do
        new_items[#new_items + 1] = Get_items_in_Lane(reaper.GetTrackMediaItem(tbl.rprobj, i-1), razor_info[1], razor_info[2], razor_info.razor_lane) -- COPY ITEMS FROM RAZOR LANE
        to_delete[#to_delete + 1] = Get_items_in_Lane(reaper.GetTrackMediaItem(tbl.rprobj, i-1), razor_info[1], razor_info[2], tbl.comp_idx) -- WE ARE GONNA DELETE ON COMPING LANE IF RAZOR IS EMPTY
    end
    for i = 1, #to_delete do Delete_items_or_area(to_delete[i], razor_info[1], razor_info[2]) end -- DELETE ITEMS CONTENT (IF RAZOR IS EMPTY) COMPING "SILENCE"
    for i = 1, #new_items do Make_item_from_razor(tbl, new_items[i], razor_info) end
    --if current_razor_toggle_state == 1 then reaper.Main_OnCommand(42421, 0) end -- TURN ON ALWAYS TRIM BEHIND RAZORS (if enabled in project)
end

function SetItemsInLanes(tbl)
    for i = 1, #tbl.info do
        local items = Create_item(tbl.rprobj, tbl.info[i])
        for j = 1, #items do
            reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_Y", ((i - 1) / #tbl.info))
            reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_H", 1 / #tbl.info)
        end
    end
end

function CheckTrackLaneModeState(c_tbl)
    if not reaper.ValidatePtr(c_tbl.rprobj, "MediaTrack*") then return end
    local current_track_mode = math.floor(reaper.GetMediaTrackInfo_Value(c_tbl.rprobj, "I_FREEMODE"))
    if current_track_mode ~= c_tbl.lane_mode then
        UpdateInternalState(c_tbl)
        current_track_mode = current_track_mode ~= 1 and current_track_mode or 2
        reaper.PreventUIRefresh(1)
        c_tbl.lane_mode = current_track_mode
        if current_track_mode == 2 then
            Set_LaneView_mode(c_tbl)
        elseif current_track_mode == 0 then
            SwapVirtualTrack(c_tbl, c_tbl.idx)
        end
        StoreStateToDocument(c_tbl)
        reaper.PreventUIRefresh(-1)
    end
end

function ShowAll(tbl)
    reaper.PreventUIRefresh(1)
    local selected_tracks = tbl and {tbl} or CURRENT_TRACKS
    for track, tr_tbl in pairs(selected_tracks) do
        if not reaper.ValidatePtr(tr_tbl.rprobj, "MediaTrack*") then return end
        local fimp = reaper.GetMediaTrackInfo_Value(tr_tbl.rprobj, "I_FREEMODE")
        tr_tbl.lane_mode = fimp == 2 and 0 or 2
        if fimp == 2 then StoreLaneData(tr_tbl) end
        if fimp == 0 then -- IF LANE MODE IS OFF TURN IT ON
            Set_LaneView_mode(tr_tbl)
        elseif fimp == 2 then -- IF LANE MODE IS ON TURN IT OFF
            SetCompLane(tr_tbl,0) -- TURN OFF COMPING
            SwapVirtualTrack(tr_tbl, tr_tbl.idx)
        end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateTimeline()
    reaper.UpdateArrange()
end

local function CreateVTElements(direct)
    for track in pairs(TBH) do
        if not VT_TB[track] then
            local Element = Get_class_tbl()
            local tr_data, lane = GetChunkTableForObject(track, true)
            tr_data = lane and tr_data or {tr_data}
            for i = 1, #tr_data do tr_data[i].name = "Version " .. i end
            VT_TB[track] = Element:new(track, tr_data, direct)
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
    local rprobj
    local _, demand_mode = reaper.GetProjExtState(0, "VirtualTrack", "ONDEMAND_MODE")
    if demand_mode == "mouse" then
        rprobj = Get_track_under_mouse()
    elseif demand_mode == "track" then
        local sel_env = reaper.GetSelectedEnvelope( 0 )
        rprobj = sel_env and sel_env or reaper.GetSelectedTrack(0,0)
    end
    if rprobj then
        if SetupSingleElement(rprobj) and #Get_VT_TB() then return rprobj end
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
            if oldidx ~= v.idx then v:update_xywh() end
        end
    end
end

function SetCompLane(tbl, lane)
    local new_lane = lane and lane or MouseInfo().last_menu_lane
    local selected_tracks = tbl and {tbl} or CURRENT_TRACKS
    for track, tr_tbl in pairs(selected_tracks) do
        tr_tbl.comp_idx = tr_tbl.comp_idx == 0 and new_lane or 0
        SetCompActiveIcon(tr_tbl)
        StoreStateToDocument(tr_tbl)
    end
end

function GetChild_ParentTrack_FromStored_PEXT(tracl_tbl)
    local all_childs_parents = {}
    for track in pairs(tracl_tbl) do
        if reaper.ValidatePtr(track, "MediaTrack*") then
            if not all_childs_parents[track] then all_childs_parents[track] = track end
            for i = 1, reaper.CountTrackEnvelopes(track) do
                local env = reaper.GetTrackEnvelope(track, i - 1)
                if Get_Stored_PEXT_STATE_TBL()[env] then
                    if not all_childs_parents[env] then all_childs_parents[env] = env end
                end
            end
        elseif reaper.ValidatePtr(track, "TrackEnvelope*") then
            local parent_tr = reaper.GetEnvelopeInfo_Value(track, "P_TRACK")
            if not all_childs_parents[parent_tr] then all_childs_parents[parent_tr] = parent_tr end
            for i = 1, reaper.CountTrackEnvelopes(parent_tr) do
                local env = reaper.GetTrackEnvelope(parent_tr, i - 1)
                if Get_Stored_PEXT_STATE_TBL()[env] then
                    if not all_childs_parents[env] then all_childs_parents[env] = env end
                end
            end
        end
    end
    return all_childs_parents
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

function Same_Envelope_AS_Mouse(tr_tbl)
    local same_envelopes = nil
    local all_childs = GetChild_ParentTrack_FromStored_PEXT(tr_tbl)
    if reaper.ValidatePtr(MouseInfo().last_menu_tr, "TrackEnvelope*") then
        same_envelopes = {}
        local m_retval, m_name = reaper.GetEnvelopeName(MouseInfo().last_menu_tr)
        for track in pairs(all_childs) do
            if reaper.ValidatePtr(track, "TrackEnvelope*") and all_childs[track] then
                local env_retval, env_name = reaper.GetEnvelopeName(track)
                if m_name == env_name then
                    same_envelopes[track] = env_name
                end
            end
        end
    end
    return same_envelopes
end

local function GetSelectedTracks()
    if reaper.CountSelectedTracks(0) < 2 then return end -- MULTISELECTION START ONLY IF 2 OR MORE TRACKS ARE SELECTED
    local selected_tracks = {}
    for i = 1, reaper.CountSelectedTracks(0) do
        local track = reaper.GetSelectedTrack(0, i - 1)
        selected_tracks[track] = track
    end
    local same_envelope_as_mouse = Same_Envelope_AS_Mouse(selected_tracks)
    return same_envelope_as_mouse and same_envelope_as_mouse or selected_tracks
end

function GetSelectedTracksData(rprobj, on_demand)
    local tracks = GetSelectedTracks()
    local tracks_tbl = {}
    if not tracks then return { [rprobj] = VT_TB[rprobj] } end
    if tracks then
        if not tracks[rprobj] then tracks[rprobj] = rprobj end -- insert current track into selection also
        if on_demand then
            for track in pairs(tracks) do GetTrackXYH(track) end
            CreateVTElements(1)
            for track in pairs(tracks) do
                if not tracks_tbl[track] then tracks_tbl[track] = VT_TB[track] end
            end
        end
        return tracks_tbl
    end
end

local function GetLaneColorOption() return GetEXTState_VAL("LANE_COLORS") end

function NewComp(tbl)
    reaper.PreventUIRefresh(1)
    local selected_tracks = tbl and {tbl} or CURRENT_TRACKS
    for track, tr_tbl in pairs(selected_tracks) do
        local comp_cnt = 1
        for i = 1, #tr_tbl.info do
            if tr_tbl.info[i].name and tr_tbl.info[i].name:find("COMP") then comp_cnt = comp_cnt + 1 end
        end
        local comp_name = "COMP - " .. comp_cnt
        CreateNew(tr_tbl, comp_name)
        SetCompLane(tr_tbl, 1)
    end
    reaper.PreventUIRefresh(-1)
end

function GetEXTState_VAL(val)
    if reaper.HasExtState( "VirtualTrack", "options" ) then
        local state = reaper.GetExtState( "VirtualTrack", "options" )
        return state:match(val .." (%S+)") == "true" and true or false
    end
end

function SetLaneImageColors(tbl)
    if not GetLaneColorOption() then return end
    local num_items = reaper.CountTrackMediaItems(tbl.rprobj)
    for i = 1, #tbl.info do
        local t = i / 12
        local r, g, b = GenPalette(t + 0.33)
        local calculate_color = reaper.ColorToNative(r, g, b)
        for j = 1, num_items do
            local item = reaper.GetTrackMediaItem(tbl.rprobj, j - 1)
            local take = reaper.GetActiveTake( item )
            if GetItemLane(item) == i then
                reaper.SetMediaItemTakeInfo_Value(take, "I_CUSTOMCOLOR", calculate_color|0x1000000)
            end
        end
    end
end

local icon_path = script_folder .. "/Images/comp_test.png"
function SetCompActiveIcon(tbl)
    if tbl.comp_idx ~= 0 then
        local retval, current_icon = reaper.GetSetMediaTrackInfo_String( tbl.rprobj, "P_ICON", 0, false )
        tbl.def_icon = retval and current_icon or ""
        reaper.GetSetMediaTrackInfo_String( tbl.rprobj, "P_ICON" , icon_path, true )
    else
        if tbl.def_icon ~= nil then
            reaper.GetSetMediaTrackInfo_String( tbl.rprobj, "P_ICON" , tbl.def_icon, true )
            tbl.def_icon = nil
        end
    end
end

function SetGroup(tbl, val, add)
    local bit = 2^(val - 1)
    if add then
        if tbl.group & bit == 0 then tbl.group = tbl.group | bit end
    else
        if tbl.group & bit ~= 0 then tbl.group = tbl.group ~ bit end
    end
    --tbl.group = tbl.group & bit and tbl.group ~ bit or tbl.group & bit
    StoreStateToDocument(tbl)
end

function CheckGroup(val, group)
    local bit = 2^(val - 1)
    return bit & group ~= 0 and true
end

function GetTrackGroup(val)
    local stored_tbl = Get_Stored_PEXT_STATE_TBL()
    if not stored_tbl then return end
    local groups = {}
    for k, v in pairs(stored_tbl) do
        if reaper.ValidatePtr(k, "MediaTrack*") then
            reaper.SetTrackSelected( k, false )
            if CheckGroup(val, v.group) then
                reaper.SetTrackSelected( k, true )
                if not groups[k] then groups[k] = v end
            end
        end
    end
    return groups
end

-- function Start_GROUP(tbl)
--     local cur_group = tbl.group ~= 0 and math.floor(math.log(tbl.group,2) + 1) or 1
--     CUR_GROUP = cur_group
-- end

function Enable_Disable_Groups(group)
    for i = 1, #GROUP_LIST-32 do
        if CheckGroup(i, group) then
            GROUP_LIST[i].enabled = not GROUP_LIST[i].enabled
        end
    end
end

function Store_GROUPS_TO_Project_EXT_STATE()
    local storedTable = { groups = GROUP_LIST }
    local serialized = tableToString(storedTable)
    reaper.SetProjExtState( 0, "VirtualTrack", "GROUPS", serialized )
end

function Restore_GROUPS_FROM_Project_EXT_STATE()
    local group_list = {}
    local rv, stored = reaper.GetProjExtState( 0, "VirtualTrack", "GROUPS" )
    if rv == 1 and stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then return storedTable.groups end
    end
    for i = 1, 32 do
        group_list[i] = { name = "GROUP " .. i, enabled = true }
    end
    return group_list
end
