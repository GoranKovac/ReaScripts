--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.03
	 * NoIndex: true
--]]
local reaper = reaper
local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])"):gsub("[\\|/]Modules", "")
local main_wnd = reaper.GetMainHwnd()                            -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local VT_TB, GROUP_LIST, CUR_GROUP = {}, nil, 1

local Element = {}
function Element:new(rprobj, info, fx_data)
    local elm = {}
    elm.rprobj, elm.info = rprobj, info
    elm.fx = fx_data or nil
    elm.idx = 1
    elm.comp_idx = reaper.ValidatePtr(rprobj, "MediaTrack*") and 0 or nil
    elm.lane_mode = reaper.ValidatePtr(rprobj, "MediaTrack*") and 0 or nil
    elm.group  = reaper.ValidatePtr(rprobj, "MediaTrack*") and 0 or nil
    elm.fx_idx = reaper.ValidatePtr(rprobj, "MediaTrack*") and 1 or nil
    elm.def_icon = nil
    setmetatable(elm, self)
    self.__index = self
    return elm
end

OPTIONS = {
    ["TOOLTIPS"] = true,
    ["LANE_COLORS"] = true,
    ["RAZOR_FOLLOW_SWAP"] = false,
}

if reaper.HasExtState( "VirtualTrack", "options" ) then
    local state = reaper.GetExtState( "VirtualTrack", "options" )
    OPTIONS["LANE_COLORS"]          = state:match("LANE_COLORS (%S+)") == "true" and true or false
    OPTIONS["TOOLTIPS"]             = state:match("TOOLTIPS (%S+)") == "true" and true or false
    OPTIONS["RAZOR_FOLLOW_SWAP"]    = state:match("RAZOR_FOLLOW_SWAP (%S+)") == "true" and true or false
end

local function Update_tempo_map()
    if reaper.CountTempoTimeSigMarkers(0) then
        local _, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, 0)
        reaper.SetTempoTimeSigMarker(0, 0, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo)
    end
    reaper.UpdateTimeline()
end
local ctx
function ImGui_Create_CTX()
    ctx = reaper.ImGui_CreateContext('My script', reaper.ImGui_ConfigFlags_NoSavedSettings())
end

function Draw_Color_Rect(color)
    local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
    local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, min_x, min_y, max_x, max_y, 0x11FFFF80)
end

function ToolTip(text)
    if not OPTIONS["TOOLTIPS"] then return end
    if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenBlockedByPopup()) then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
        reaper.ImGui_PushTextWrapPos(ctx, 200)
        reaper.ImGui_Text(ctx, text)
        reaper.ImGui_PopTextWrapPos(ctx)
        reaper.ImGui_EndTooltip(ctx)
    end
end

function UpdateTrackCheck(folder)
    if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenBlockedByPopup()) then
        if folder ~= OLD_FOLDER_ACTION then
            OLD_FOLDER_ACTION = folder
            Get_Selected_OR_Folder_tracks(folder)
        end
    end
end

function ReaperRename()
    local cur_name = SEL_TRACK_TBL.info[SEL_TRACK_TBL.idx].name
    local retval, saved_name = reaper.GetUserInputs( "VIRTUAL TRACK - RENAME", 1, "New Version name : ", cur_name )
    if not retval then return end
    Rename(saved_name)
end

local function GUIRename(track_type)
    local cur_name
    if track_type == "FX" then cur_name = SEL_TRACK_TBL.fx[1].name
    elseif track_type == "TRACK" then cur_name = SEL_TRACK_TBL.info[ACTION_ID].name
    --elseif track_type == "FOLDER" then end
    end
    local RV
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
        NEW_NAME = cur_name
    end
    RV, NEW_NAME = reaper.ImGui_InputText(ctx, 'Name' , NEW_NAME, reaper.ImGui_InputTextFlags_AutoSelectAll())
    if reaper.ImGui_Button(ctx, 'OK') or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter()) then
        NEW_NAME = NEW_NAME:gsub("^%s*(.-)%s*$", "%1") -- remove trailing and leading
        if #NEW_NAME ~= 0 then SAVED_NAME = NEW_NAME end
        if SAVED_NAME then
            if track_type == "TRACK" then Rename(SAVED_NAME)
            elseif track_type == "FX" then RenameFX(SAVED_NAME)
            end
        end
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Cancel') then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

local function save_options()
    local store_string = ""
    for k, v in pairs(OPTIONS) do store_string = store_string .. tostring(k) .. " " .. tostring(v) .. " " end
    reaper.SetExtState( "VirtualTrack", "options", store_string, true )
end

local function GUIOptions()
    local current_lane_colors = OPTIONS["LANE_COLORS"]
    local current_tooltips = OPTIONS["TOOLTIPS"]
    local current_razor_follow_swap = OPTIONS["RAZOR_FOLLOW_SWAP"]
    if reaper.ImGui_Checkbox(ctx, "TOOLTIPS", current_tooltips) then
        OPTIONS["TOOLTIPS"] = not OPTIONS["TOOLTIPS"]
        save_options()
    end
    if reaper.ImGui_Checkbox(ctx, "LANE COLORS", current_lane_colors) then
        OPTIONS["LANE_COLORS"] = not OPTIONS["LANE_COLORS"]
        save_options()
    end
    ToolTip("Enable unique color for each lane in lane mode")
    if reaper.ImGui_Checkbox(ctx, "RAZOR FOLLOW VERSION SWAP", current_razor_follow_swap) then
        OPTIONS["RAZOR_FOLLOW_SWAP"] = not OPTIONS["RAZOR_FOLLOW_SWAP"]
        save_options()
    end
    ToolTip("Razor follow version selection in lane mode for easier comping")
    if reaper.ImGui_Button(ctx, 'Donate', -1) then Open_url("https://www.paypal.com/paypalme/GoranK101") end
end

local function ctx_modifiers()
    local shift = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift() ~= 0 and true
    local ctrl = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Ctrl() ~= 0 and true
    local alt = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Alt() ~= 0 and true
    local win = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Super() ~= 0 and true
    return shift, ctrl, alt, win
end

OLD_FOLDER_ACTION = false
function Get_Selected_OR_Folder_tracks(folder)
    FOLDER_CHILDS = GetFolderChilds(SEL_TRACK_TBL.rprobj)
    if FOLDER_CHILDS then _, _, CURRENT_FOLDER_LANE_MODE, CURRENT_FOLDER_COMP_IDX = Find_Highest(FOLDER_CHILDS) end
    CURRENT_TRACKS = CheckGroupMaskBits(GROUP_LIST.enabled_mask, SEL_TRACK_TBL.group) and GetTracksOfMask(SEL_TRACK_TBL.group) or GetSelectedTracksData(SEL_TRACK_TBL)
    if folder then CURRENT_TRACKS = FOLDER_CHILDS end
end

function ContextMenu(idx, track_type)
    ACTION_ID = idx
    if reaper.ImGui_MenuItem(ctx, 'Delete') then
        if track_type == "FX" then DeleteFX()
        elseif track_type == "TRACK" then Delete()
        elseif track_type == "FOLDER" then Delete()
        end
    end
    if reaper.ImGui_MenuItem(ctx, 'Duplicate') then
        if track_type == "FX" then DuplicateFX()
        elseif track_type == "TRACK" then Duplicate()
        elseif track_type == "FOLDER" then Duplicate()
        end
    end
    if reaper.ImGui_Selectable(ctx, 'Rename', nil, reaper.ImGui_SelectableFlags_DontClosePopups()) then
        reaper.ImGui_OpenPopup(ctx, 'Rename Version')
    end
    if reaper.ImGui_BeginPopupModal(ctx, 'Rename Version', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        GUIRename(track_type)
        reaper.ImGui_EndPopup(ctx)
    end
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") and (SEL_TRACK_TBL.lane_mode == 2 or CURRENT_FOLDER_LANE_MODE == 2) then
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_MenuItem(ctx, 'SET as COMP', nil, nil, (SEL_TRACK_TBL.comp_idx == 0 and (CURRENT_FOLDER_COMP_IDX == 0 or CURRENT_FOLDER_COMP_IDX == nil))) then SetCompLane() end
    end
end

local MW_CNT = 0
function MenuGUI()
    --local shift, ctrl, alt, win = ctx_modifiers()
    local is_folder = reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") and reaper.GetMediaTrackInfo_Value(SEL_TRACK_TBL.rprobj, "I_FOLDERDEPTH") == 1

    local vertical = reaper.ImGui_GetMouseWheel( ctx )
    if vertical ~= 0 then WHEEL_INCREMENT = vertical > 0 and 1 or -1 end

    local is_button_enabled = SEL_TRACK_TBL.comp_idx == 0
    local comp_enabled = SEL_TRACK_TBL.comp_idx ~= 0

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then reaper.ImGui_CloseCurrentPopup(ctx) end
    ------------------------------------------------------------------------------------
    if reaper.ImGui_Selectable(ctx, 'VIRTUAL TRACK', true, reaper.ImGui_SelectableFlags_DontClosePopups() | reaper.ImGui_SelectableFlags_AllowDoubleClick()) and reaper.ImGui_IsMouseDoubleClicked( ctx, 0 )then
        reaper.ImGui_OpenPopup(ctx, 'OPTIONS')
    end
    ToolTip("Double click for options")
    UpdateTrackCheck()
    ------------------------------------------------------------------------------------
    if reaper.ImGui_BeginPopupModal(ctx, 'OPTIONS', true, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        GUIOptions()
        reaper.ImGui_EndPopup(ctx)
    end
    ------------------------------------------------------------------------------------
    reaper.ImGui_Separator(ctx)
    is_button_enabled = reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "TrackEnvelope*") and true or is_button_enabled
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") then
        if reaper.ImGui_BeginMenu(ctx, "TRACK", true) then
            --is_button_enabled = reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "TrackEnvelope*") and true or is_button_enabled
            if reaper.ImGui_MenuItem(ctx, 'Create New', nil, nil, is_button_enabled) then CreateNew() end
            reaper.ImGui_Separator(ctx)
            if vertical == 0 and WHEEL_INCREMENT then
                SEL_TRACK_TBL.idx = (SEL_TRACK_TBL.idx - WHEEL_INCREMENT <= #SEL_TRACK_TBL.info and SEL_TRACK_TBL.idx - WHEEL_INCREMENT >= 1) and SEL_TRACK_TBL.idx - WHEEL_INCREMENT or SEL_TRACK_TBL.idx
                SwapVirtualTrack(SEL_TRACK_TBL.idx)
                WHEEL_INCREMENT = nil
            end
            for i = #SEL_TRACK_TBL.info, 1, -1 do
                local new_i = math.abs(i - #SEL_TRACK_TBL.info) + 1 --! WE ARE REVERSING SINCE DELETING WILL ITERATING WILL BREAK STUFF (DELETING IS WITH PAIRS)
                if reaper.ImGui_MenuItem(ctx, new_i .. " " .. SEL_TRACK_TBL.info[new_i].name, nil, new_i == SEL_TRACK_TBL.idx) then SwapVirtualTrack(new_i) end
                    local x, y = reaper.ImGui_GetCursorScreenPos( ctx )
                    reaper.ImGui_SetNextWindowPos( ctx, x, y)
                    if reaper.ImGui_BeginPopupContextItem(ctx) then
                        HIGH = new_i
                        Draw_Color_Rect()
                        ContextMenu(new_i, "TRACK")
                    reaper.ImGui_EndPopup(ctx)
                end
                if new_i == HIGH then Draw_Color_Rect() HIGH = nil end
                if comp_enabled and new_i == SEL_TRACK_TBL.comp_idx then Draw_Color_Rect() end
            end
            reaper.ImGui_EndMenu(ctx)
        end
    else
        if reaper.ImGui_MenuItem(ctx, 'Create New', nil, nil, is_button_enabled) then CreateNew() end
            reaper.ImGui_Separator(ctx)
            if vertical == 0 and WHEEL_INCREMENT then
                SEL_TRACK_TBL.idx = (SEL_TRACK_TBL.idx - WHEEL_INCREMENT <= #SEL_TRACK_TBL.info and SEL_TRACK_TBL.idx - WHEEL_INCREMENT >= 1) and SEL_TRACK_TBL.idx - WHEEL_INCREMENT or SEL_TRACK_TBL.idx
                SwapVirtualTrack(SEL_TRACK_TBL.idx)
                WHEEL_INCREMENT = nil
            end
            for i = #SEL_TRACK_TBL.info, 1, -1 do
                local new_i = math.abs(i - #SEL_TRACK_TBL.info) + 1 --! WE ARE REVERSING SINCE DELETING WILL ITERATING WILL BREAK STUFF (DELETING IS WITH PAIRS)
                if reaper.ImGui_MenuItem(ctx, i .. " " .. SEL_TRACK_TBL.info[new_i].name, nil, new_i == SEL_TRACK_TBL.idx) then SwapVirtualTrack(new_i) end
                    local x, y = reaper.ImGui_GetCursorScreenPos( ctx )
                    reaper.ImGui_SetNextWindowPos( ctx, x, y)
                    if reaper.ImGui_BeginPopupContextItem(ctx) then
                        HIGH = new_i
                        Draw_Color_Rect()
                        ContextMenu(new_i, "TRACK")
                    reaper.ImGui_EndPopup(ctx)
                end
                if new_i == HIGH then Draw_Color_Rect() HIGH = nil end
                if comp_enabled and new_i == SEL_TRACK_TBL.comp_idx then Draw_Color_Rect() end
            end
    end
    UpdateTrackCheck()
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") then
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_BeginMenu(ctx, "FX", true) then
            if reaper.ImGui_MenuItem(ctx, 'Create New FX', nil, nil, is_button_enabled) then CreateFX() end
            UpdateTrackCheck()
            reaper.ImGui_Separator(ctx)
            if vertical == 0 and WHEEL_INCREMENT then
                SEL_TRACK_TBL.fx_idx = (SEL_TRACK_TBL.fx_idx - WHEEL_INCREMENT <= #SEL_TRACK_TBL.fx and SEL_TRACK_TBL.fx_idx - WHEEL_INCREMENT >= 1) and SEL_TRACK_TBL.fx_idx - WHEEL_INCREMENT or SEL_TRACK_TBL.fx_idx
                SwapFX(SEL_TRACK_TBL.fx_idx)
                WHEEL_INCREMENT = nil
            end
            for i = #SEL_TRACK_TBL.fx , 1, -1 do
                local new_i = math.abs(i - #SEL_TRACK_TBL.fx) + 1 --! WE ARE REVERSING SINCE DELETING WILL ITERATING WILL BREAK STUFF (DELETING IS WITH PAIRS)
                if reaper.ImGui_MenuItem(ctx, i .. " " .. SEL_TRACK_TBL.fx[new_i].name, nil, new_i == SEL_TRACK_TBL.fx_idx) then FX_OPEN = true SwapFX(new_i) reaper.TrackFX_Show( SEL_TRACK_TBL.rprobj, 0, 1 ) end
                local x, y = reaper.ImGui_GetCursorScreenPos( ctx )
                reaper.ImGui_SetNextWindowPos( ctx, x, y)
                if reaper.ImGui_BeginPopupContextItem(ctx) then
                    HIGH = new_i
                    ContextMenu(new_i, "FX")
                    reaper.ImGui_EndPopup(ctx)
                end
                if new_i == HIGH then Draw_Color_Rect() HIGH = nil end
            end
            reaper.ImGui_EndMenu(ctx)
        end
        UpdateTrackCheck()
        reaper.ImGui_Separator(ctx)
    end
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") then
        if SEL_TRACK_TBL.lane_mode == 2 then
            if reaper.ImGui_MenuItem(ctx, 'New Empty COMP', nil, nil, is_button_enabled) then NewComp() end
            if comp_enabled then
                if reaper.ImGui_MenuItem(ctx, 'DISABLE COMP', nil, comp_enabled) then SetCompLane(nil, 0) end
                Draw_Color_Rect()
            end
            reaper.ImGui_Separator(ctx)
        end
        local is_lane_mode = SEL_TRACK_TBL.lane_mode == 2
        if is_lane_mode then reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x3EFF00FF) end -- MAKE TEXT GREEN WHEN ENABLED
        if reaper.ImGui_MenuItem(ctx, 'Show All', nil, SEL_TRACK_TBL.lane_mode == 2 , is_button_enabled) then ShowAll(SEL_TRACK_TBL.lane_mode) end
        if is_lane_mode then Draw_Color_Rect() reaper.ImGui_PopStyleColor(ctx) end
    end
    UpdateTrackCheck()

    if is_folder then
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_BeginMenu(ctx, "FOLDER TRACKS", true) then
            if reaper.ImGui_MenuItem(ctx, 'Create New', nil, nil, CURRENT_FOLDER_COMP_IDX == 0) then CreateNew() UpdateTrackCheck(true) end
            UpdateTrackCheck(true)
            reaper.ImGui_Separator(ctx)
            local number_of_folder_versions, current_folder_idx = Find_Highest(FOLDER_CHILDS) -- FIND WHICH CHILD HAST MOST VERSIONS AND USE THAT FOR VERSION NUMBERING
            if vertical == 0 and WHEEL_INCREMENT then
                MW_CNT = current_folder_idx
                MW_CNT = (MW_CNT - WHEEL_INCREMENT <= number_of_folder_versions and MW_CNT - WHEEL_INCREMENT >= 1) and MW_CNT - WHEEL_INCREMENT or MW_CNT
                SwapVirtualTrack(MW_CNT)
                WHEEL_INCREMENT = nil
            end
            ------------------------------------------------------------------------------------
            for i = number_of_folder_versions, 1, -1 do
                local new_i = math.abs(i - number_of_folder_versions) + 1 --! WE ARE REVERSING SINCE DELETING WILL ITERATING WILL BREAK STUFF (DELETING IS WITH PAIRS)
                if reaper.ImGui_MenuItem(ctx, new_i, nil, new_i == current_folder_idx) then UpdateTrackCheck(true) SwapVirtualTrack(new_i) end
                local x, y = reaper.ImGui_GetCursorScreenPos( ctx )
                reaper.ImGui_SetNextWindowPos( ctx, x, y)
                if reaper.ImGui_BeginPopupContextItem(ctx) then
                    HIGH = new_i
                    ContextMenu(new_i, "FOLDER")
                    reaper.ImGui_EndPopup(ctx)
                    Get_Selected_OR_Folder_tracks(true)
                end
                if new_i == HIGH then Draw_Color_Rect() HIGH = nil end
            end
            reaper.ImGui_EndMenu(ctx)
        end
        UpdateTrackCheck(true)
        if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") then
            if CURRENT_FOLDER_LANE_MODE == 2 then
                if reaper.ImGui_MenuItem(ctx, 'New Empty COMP', nil, nil, CURRENT_FOLDER_COMP_IDX == 0) then NewComp() end
                if CURRENT_FOLDER_COMP_IDX ~= 0 then
                    if reaper.ImGui_MenuItem(ctx, 'DISABLE COMP', nil, comp_enabled) then SetCompLane(nil, 0) end
                    Draw_Color_Rect()
                end
                reaper.ImGui_Separator(ctx)
            end
            if reaper.ImGui_MenuItem(ctx, 'Show All', nil, CURRENT_FOLDER_LANE_MODE == 2, CURRENT_FOLDER_COMP_IDX == 0) then ShowAll(CURRENT_FOLDER_LANE_MODE) end
            UpdateTrackCheck(true)
           if CURRENT_FOLDER_LANE_MODE == 2 then Draw_Color_Rect() end
        end
    end
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") then
        reaper.ImGui_Separator(ctx)
        local ACTIVE_GROUPS = Get_active_groups(SEL_TRACK_TBL.group)
        local groups_button_name = SEL_TRACK_TBL.group == 0 and "- None" or table.concat(ACTIVE_GROUPS, "-")
        ------------------------------------------------------------------------------------
        if reaper.ImGui_Selectable(ctx, 'GROUPS ' .. groups_button_name, nil, reaper.ImGui_SelectableFlags_DontClosePopups()) then
            TRACK_GROUPS = GetTracksOfGroup(CUR_GROUP) or {}
            _, ALL_VT_TRACKS = Get_Stored_PEXT_STATE_TBL()
            reaper.ImGui_OpenPopup(ctx, 'GROUP_WINDOW')
        end
        ToolTip("Open Track GOUP Window")
        UpdateTrackCheck()
        ------------------------------------------------------------------------------------
        if reaper.ImGui_BeginPopupModal(ctx, 'GROUP_WINDOW', true, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
            Group_GUI()
            reaper.ImGui_EndPopup(ctx)
        end
        local is_track_in_group = SEL_TRACK_TBL.group ~= 0
        local is_group_enabled = CheckGroupMaskBits(GROUP_LIST.enabled_mask, SEL_TRACK_TBL.group)
        if is_group_enabled then reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x3EFF00FF) end -- MAKE TEXT GREEN WHEN ENABLED
        ------------------------------------------------------------------------------------
        if reaper.ImGui_MenuItem(ctx, 'ENABLED', nil, is_group_enabled, is_track_in_group) then
            Set_MaskGroup_Enabled_Disabled(SEL_TRACK_TBL.group, not is_group_enabled)
        end
        if is_group_enabled then Draw_Color_Rect() reaper.ImGui_PopStyleColor(ctx) end
        ToolTip("Enable or Disable active groups")
        UpdateTrackCheck()
        ------------------------------------------------------------------------------------
    end
end

function Add_REMOVE_Tracks_To_Group(tbl, add)
    for track in pairs(tbl) do
        local is_found = add and tbl[track].AddSelect or tbl[track].DelSelect
        if is_found then
            ADD_REMOVE_GROUP_TO_TRACK(tbl[track], CUR_GROUP, add)
            if tbl[track].rprobj == SEL_TRACK_TBL.rprobj then ADD_REMOVE_GROUP_TO_TRACK(SEL_TRACK_TBL, CUR_GROUP, add) end -- UPDATE MOUSE TRACK
            StoreStateToDocument(tbl[track])
        end
    end
    TRACK_GROUPS = GetTracksOfGroup(CUR_GROUP)
end

function Group_GUI()
    local shift, ctrl, alt, win = ctx_modifiers()
    reaper.ImGui_SetNextItemWidth(ctx, 200)
    local vertical = reaper.ImGui_GetMouseWheel( ctx )
    if vertical ~= 0 then WHEEL_INCREMENT = vertical end
    if vertical == 0 and WHEEL_INCREMENT then
        SEL_TRACK_TBL.idx = (SEL_TRACK_TBL.idx - WHEEL_INCREMENT <= #SEL_TRACK_TBL.info and SEL_TRACK_TBL.idx - WHEEL_INCREMENT >= 1) and SEL_TRACK_TBL.idx - WHEEL_INCREMENT or SEL_TRACK_TBL.idx
        SwapVirtualTrack(SEL_TRACK_TBL.idx)
        WHEEL_INCREMENT = nil
    end
    ------------------------------------------------------------------------------------
    if reaper.ImGui_BeginCombo(ctx, '##docker', GROUP_LIST[CUR_GROUP].name or GROUP_LIST[1].name) then
        for i = 1, #GROUP_LIST do
            if reaper.ImGui_Selectable(ctx, GROUP_LIST[i].name, CUR_GROUP == i) then
                CUR_GROUP = i
                TRACK_GROUPS = GetTracksOfGroup(i)
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end
    reaper.ImGui_SameLine(ctx)
    ------------------------------------------------------------------------------------
    local is_group_enabled = CheckSingleGroupBit(GROUP_LIST.enabled_mask, CUR_GROUP)
    if reaper.ImGui_Checkbox(ctx, 'ENABLED', is_group_enabled) then
        Set_SingleGroup_Enabled_Disabled(CUR_GROUP, not is_group_enabled)
    end
    ToolTip('Enable or disable current group')
    ------------------------------------------------------------------------------------
    if reaper.ImGui_BeginListBox(ctx, '##listbox', 160) then
        for i = 1, #ALL_VT_TRACKS do
            if reaper.ValidatePtr(ALL_VT_TRACKS[i].rprobj, "MediaTrack*" ) then
                local _, buf = reaper.GetTrackName( ALL_VT_TRACKS[i].rprobj )
                if reaper.ImGui_Selectable(ctx, buf..'##', ALL_VT_TRACKS[i].AddSelect) then
                    if not shift then
                        for _, info in pairs(ALL_VT_TRACKS) do info.AddSelect = false end
                    end
                    ALL_VT_TRACKS[i].AddSelect = not ALL_VT_TRACKS[i].AddSelect
                end
                if reaper.ImGui_IsItemHovered( ctx ) then
                    if reaper.ImGui_IsMouseDown( ctx, 1 ) then
                        ALL_VT_TRACKS[i].AddSelect = true
                    end
                end
            end
        end
        reaper.ImGui_EndListBox(ctx)
    end
    ToolTip('Right-Click drag selects, Left-Click single selects/deselects')
    ------------------------------------------------------------------------------------
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_BeginListBox(ctx, '##listbox2', 160) then
        for k, v in pairs(TRACK_GROUPS) do
            if reaper.ValidatePtr( k, "MediaTrack*" ) then
                local _, buf = reaper.GetTrackName( k )
                if reaper.ImGui_Selectable(ctx, buf..'##', v.DelSelect) then
                    if (reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_KeyModFlags_Shift()) == 0 then
                        for _, info in pairs(TRACK_GROUPS) do info.DelSelect = false end
                    end
                    v.DelSelect = not v.DelSelect
                end
                if reaper.ImGui_IsItemHovered( ctx ) then
                    if reaper.ImGui_IsMouseDown( ctx, 1 ) then
                        TRACK_GROUPS[k].DelSelect = true
                    end
                end
            end
        end
        reaper.ImGui_EndListBox(ctx)
    end
    ToolTip('Right-Click drag selects, Left-Click single selects/deselects')
    ------------------------------------------------------------------------------------
    if reaper.ImGui_Button(ctx, 'Add Track', 160) then Add_REMOVE_Tracks_To_Group(ALL_VT_TRACKS, true) end
    ToolTip('Add selected tracks from TCP or MCP view')
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Remove Track',160) then Add_REMOVE_Tracks_To_Group(TRACK_GROUPS, false) end
    ToolTip('Remove tracks from list view')
end
function GUI()
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetNextWindowPos(ctx, reaper.ImGui_PointConvertNative(ctx, reaper.GetMousePosition()))
        reaper.ImGui_OpenPopup(ctx, 'Menu')
    end

    if reaper.ImGui_BeginPopup(ctx, 'Menu') then
        MenuGUI()
        reaper.ImGui_EndPopup(ctx)
        reaper.defer(GUI)
    else
        reaper.ImGui_DestroyContext(ctx)
        STORE_DATA = true
    end
    if STORE_DATA then
        Store_GROUPS_TO_Project_EXT_STATE()
        if UPDATE_TEMPO then Update_tempo_map() end
        UpdateChangeCount()
    end
end

function Show_menu(tbl, skip_gui_command)
    GROUP_LIST = Restore_GROUPS_FROM_Project_EXT_STATE()
    UPDATE_TEMPO = tbl.rprobj == reaper.GetMasterTrack(0) and true or false
    if tbl.rprobj == reaper.GetMasterTrack(0) then
        CreateVT_Element(reaper.GetTrackEnvelopeByName( tbl.rprobj, "Tempo map" ))
        tbl = VT_TB[reaper.GetTrackEnvelopeByName( tbl.rprobj, "Tempo map" )]
    end
    SEL_TRACK_TBL = tbl
    RAZOR_INFO = reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") and Get_Razor_Data(SEL_TRACK_TBL.rprobj) or nil
    local is_folder = reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "MediaTrack*") and reaper.GetMediaTrackInfo_Value(SEL_TRACK_TBL.rprobj, "I_FOLDERDEPTH") == 1
    Get_Selected_OR_Folder_tracks(is_folder) -- CHECK IF SELECTED TRACK IS FOLDER
    for track in pairs(CURRENT_TRACKS) do
        CheckTrackLaneModeState(CURRENT_TRACKS[track])
        UpdateCurrentFX_State(CURRENT_TRACKS[track])
        --SaveCurrentState(CURRENT_TRACKS[track])
    end -- UPDATE INTERNAL TABLE BEFORE OPENING MENU
    --UpdateCurrentFX_State(SEL_TRACK_TBL) -- store and update current track
    --SaveCurrentState(SEL_TRACK_TBL) -- store and update current track
    if not skip_gui_command then
        ImGui_Create_CTX()
        reaper.defer(GUI)
    else
        _G[skip_gui_command]()
    end
end

local function Store_To_PEXT(el)
    local storedTable = {}
    storedTable.info = el.info
    storedTable.idx = math.floor(el.idx)
    if reaper.ValidatePtr(el.rprobj, "MediaTrack*") then
        storedTable.comp_idx =  math.floor(el.comp_idx)
        storedTable.lane_mode =  math.floor(el.lane_mode)
        storedTable.def_icon = el.def_icon
        storedTable.group =  math.floor(el.group)
        storedTable.fx_idx =  math.floor(el.fx_idx)
        storedTable.fx = el.fx
    end
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
            if reaper.ValidatePtr(el.rprobj, "MediaTrack*") then
                el.comp_idx = storedTable.comp_idx
                el.lane_mode = storedTable.lane_mode
                el.def_icon = storedTable.def_icon
                el.group = storedTable.group
                el.fx_idx = storedTable.fx_idx
                el.fx = storedTable.fx
            end
            return true
        end
    end
end

function Get_Stored_PEXT_STATE_TBL()
    local stored_tbl, stored_tbl_sorted = {}, {}
    for i = 1, reaper.CountTracks(0) do
        local track = reaper.GetTrack(0, i - 1)
        stored_tbl[track] = {}
        stored_tbl[track].rprobj = track
        if not Restore_From_PEXT(stored_tbl[track]) then stored_tbl[track] = nil end
        table.insert(stored_tbl_sorted, stored_tbl[track])
        for j = 1, reaper.CountTrackEnvelopes(track) do
            local env = reaper.GetTrackEnvelope(track, j - 1)
            stored_tbl[env] = {}
            stored_tbl[env].rprobj = env
            if not Restore_From_PEXT(stored_tbl[env]) then stored_tbl[env] = nil end
            table.insert(stored_tbl_sorted, stored_tbl[env])
        end
    end
    return stored_tbl, stored_tbl_sorted
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
    if num_items == 0 then return end -- NO ITEMS IN LANE MODE MEANS THERE IS ONLY VERSION 1
    local item_for_height = reaper.GetTrackMediaItem(tbl.rprobj, 0)
    local total_lanes = round(1 / reaper.GetMediaItemInfo_Value(item_for_height, 'F_FREEMODE_H')) -- WE CHECK LANE HEIGHT WITH ANY ITEM ON TRACK

    if tbl.lane_mode == 0 then -- IF ORIGINAL LANE MODE IS NORMAL TRACK
        SwapVirtualTrack(tbl.idx, tbl.rprobj) -- SWAP TO CURRENT VERSION
        return
    end

    for i = 1 , total_lanes do
        local lane_chunk = {}
        for j = 1, num_items do
            local item = reaper.GetTrackMediaItem(tbl.rprobj, j - 1)
            if GetItemLane(item) == i then
                local item_chunk = Get_Item_Chunk(item)
                lane_chunk[#lane_chunk + 1] = item_chunk
            end
        end
        local name = tbl.info[i] and tbl.info[i].name or "Version " .. i
        -- if not tbl.info[i] then
        --     tbl.info[i] = lane_chunk
        --     tbl.info[i].name = name
        -- else
            tbl.info[i] = lane_chunk
            tbl.info[i].name = name
        --end
    end
end

function UpdateCurrentFX_State(tbl)
    if reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then return end
    local name = tbl.fx[tbl.fx_idx].name
    local chunk_tbl = GetFX_Chunk(tbl.rprobj)
    if chunk_tbl then
        tbl.fx[tbl.fx_idx] = chunk_tbl
        tbl.fx[tbl.fx_idx].name = name
        return true
    end
    return false
end

function UpdateInternalState(tbl)
    if not tbl or not tbl.info[tbl.idx] then return false end
    --if tbl.lane_mode == 2 then -- ONLY HAPPENS ON MEDIA TRACKS
    if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 2 then -- CHECK ACTUAL TRACK STATE
        StoreLaneData(tbl)
        return true
    elseif reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 0 then
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

function SaveCurrentState(tbl)
    if UpdateInternalState(tbl) == true then Store_To_PEXT(tbl) end
end

function CycleVersionsUP()
    reaper.PreventUIRefresh(1)
    local selected_tracks = CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        if tr_tbl.idx - 1 < 1 then return end
        SwapVirtualTrack(tr_tbl.idx - 1, tr_tbl.rprobj)
        if tr_tbl.lane_mode == 2 and OPTIONS["RAZOR_FOLLOW_SWAP"] and RAZOR_INFO then Create_Razor_From_LANE(tr_tbl, RAZOR_INFO) end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function CycleVersionsDOWN()
    reaper.PreventUIRefresh(1)
    local selected_tracks = CURRENT_TRACKS
    local biggest = Find_Highest(selected_tracks) -- FIND WHICH TRACK HAST MOST VERSIONS AND USE THAT FOR IDX CYCLE
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        if tr_tbl.idx + 1 > biggest then return end
        SwapVirtualTrack(tr_tbl.idx + 1, tr_tbl.rprobj)
        if tr_tbl.lane_mode == 2 and OPTIONS["RAZOR_FOLLOW_SWAP"] and RAZOR_INFO then Create_Razor_From_LANE(tr_tbl, RAZOR_INFO) end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function ActivateLaneUndeMouse()
    local LAST_MOUSE_LANE = MouseInfo(SEL_TRACK_TBL.rprobj)
    if not LAST_MOUSE_LANE then return end
    if LAST_MOUSE_LANE == SEL_TRACK_TBL.idx then return end -- DO NOT CONTINUE IF ALREADY AT SAME LANE
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    for track in pairs(CURRENT_TRACKS) do
        local tr_tbl = CURRENT_TRACKS[track]
        SwapVirtualTrack(LAST_MOUSE_LANE, tr_tbl.rprobj)
        if tr_tbl.lane_mode == 2 and OPTIONS["RAZOR_FOLLOW_SWAP"] and RAZOR_INFO then Create_Razor_From_LANE(tr_tbl, RAZOR_INFO) end
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Activate Lane ", -1)
    reaper.PreventUIRefresh(-1)
end

function SwapVirtualTrack(idx, tr)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        --if tr_tbl.info[idx] then
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
       -- if tr_tbl.info[idx] then
            tr_tbl.idx = idx
            StoreStateToDocument(tr_tbl)
       -- end
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Select Versions ", -1)
    reaper.PreventUIRefresh(-1)
end

function ConvertToMediaTrack(rprobj)
    return reaper.ValidatePtr(rprobj, "TrackEnvelope*") and reaper.GetEnvelopeInfo_Value(rprobj, "P_TRACK") or rprobj
end

function RenameFX(name, tr)
    if not name then return end
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        tr_tbl.fx[ACTION_ID].name = name
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Rename FX version", -1)
end

function ClearFX(tr)
    for i = 1, reaper.TrackFX_GetCount(tr) do
        reaper.TrackFX_Delete(tr, i - 1)
    end
end

function DeleteFX(tr)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[ConvertToMediaTrack(track)]
        if #tr_tbl.fx > 1 then
            table.remove(tr_tbl.fx, ACTION_ID)
            tr_tbl.fx_idx = tr_tbl.fx_idx <= #tr_tbl.fx and tr_tbl.fx_idx or #tr_tbl.fx
            SwapFX(tr_tbl.fx_idx, tr_tbl.rprobj)
            StoreStateToDocument(tr_tbl)
        end
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Delete FX Version ", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function DuplicateFX(tr)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track, value in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[ConvertToMediaTrack(track)]
        local name = value.fx[ACTION_ID].name .. " DUP"
        local duplicate_tbl = Deepcopy(value.fx[value.fx_idx])
        table.insert(tr_tbl.fx, duplicate_tbl) --! ORDER NEWEST TO OLDEST
        tr_tbl.fx_idx = #tr_tbl.fx
        tr_tbl.fx[#tr_tbl.fx].name = name
        SwapFX(tr_tbl.fx_idx, tr_tbl.rprobj)
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Duplicate FX", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function SwapFX(fx_idx, tr)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[ConvertToMediaTrack(track)]
        if tr_tbl.fx[fx_idx][1] == nil then return end
        SetFX_Chunk(tr_tbl, fx_idx)
        tr_tbl.fx_idx = fx_idx
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Select FX Versions ", -1)
    reaper.PreventUIRefresh(-1)
end

function CreateFX(tr, name)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[ConvertToMediaTrack(track)]
        ClearFX(tr_tbl.rprobj)
        table.insert(tr_tbl.fx, 1, {})
        tr_tbl.fx_idx = 1
        tr_tbl.fx[1].name = name and name or "FX Ver " .. #tr_tbl.fx
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Create FX Versions ", -1)
    reaper.PreventUIRefresh(-1)
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

function CreateNew(tr, name)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        Clear(tr_tbl)
        local version_name = name and name or "Version "
        Get_Store_CurrentTrackState(tr_tbl, version_name)
        if tr_tbl.lane_mode == 2 then Set_LaneView_mode(tr_tbl) end
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Create New ", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function Duplicate(tr)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track, value in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        local name = tr_tbl.info[ACTION_ID].name .. " DUP"
        local duplicate_tbl = Deepcopy(tr_tbl.info[tr_tbl.idx]) -- DEEP COPY TABLE SO ITS UNIQUE (LUA DOES SHALLOW BY DEFAULT)
        for i = 1, #duplicate_tbl do duplicate_tbl[i] = duplicate_tbl[i]:gsub("{.-}", "") end --! GENERATE NEW GUIDS FOR NEW ITEM (fixes duplicate make pooled items)
        table.insert(tr_tbl.info, 1, duplicate_tbl) --! ORDER NEWEST TO OLDEST
        tr_tbl.idx = 1
        tr_tbl.info[tr_tbl.idx].name = name
        SwapVirtualTrack(tr_tbl.idx, tr_tbl.rprobj)
        if reaper.ValidatePtr(tr_tbl.rprobj, "MediaTrack*") then
            if tr_tbl.lane_mode == 2 then Set_LaneView_mode(tr_tbl) end
        end
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Duplicate ", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

function Delete(tr)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        if #tr_tbl.info > 1 then
            table.remove(tr_tbl.info, ACTION_ID)
            tr_tbl.idx = tr_tbl.idx <= #tr_tbl.info and tr_tbl.idx or #tr_tbl.info
            if tr_tbl.lane_mode == 2 then
                Set_LaneView_mode(tr_tbl)
            elseif tr_tbl.lane_mode == 0 then
                SwapVirtualTrack(tr_tbl.idx, tr_tbl.rprobj)
            end
            StoreStateToDocument(tr_tbl)
        end
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Delete Version ", -1)
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

function Rename(name, tr)
    if not name then return end
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        --tr_tbl.info[tr_tbl.idx].name = name
        tr_tbl.info[ACTION_ID].name = name
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Rename version", -1)
end

function GetTrackChunk(rprobj)
    local _, track_chunk = reaper.GetTrackStateChunk(rprobj, "", false)
    return track_chunk
end

function SetTrackChunk(rprobj, chunk)
    reaper.SetTrackStateChunk(rprobj, chunk, false)
end

function GetFX_Chunk(rprobj)
    local track_chunk = GetTrackChunk(rprobj)
    local fx_chunk = ChunkTableGetSection(track_chunk, "FXCHAIN")
    return {fx_chunk}
end

function SetFX_Chunk(tbl, fx_idx)
    local new_fx_chunk = tbl.fx[fx_idx][1]
    local current_fx = GetFX_Chunk(tbl.rprobj)[1]
    local plugin_show = current_fx:match("(SHOW %S+)") -- GET CURRENT CHAIN SHOW STATUS
    local plugin_float = current_fx:match("(FLOAT.-\n)") -- GET CURRENT CHAIN FLOATING POSITION

    if FX_OPEN then
        local x, y = reaper.GetMousePosition()
        new_fx_chunk = new_fx_chunk:gsub("(WNDRECT )%S+ %S+", "%1".. x .."%1" ..y) -- OPEN FX UNDER CURSOR WHEN CLICKED ON LIST
    end

    new_fx_chunk = new_fx_chunk:gsub("(SHOW %S+)", plugin_show) -- SET STORED CHAIN SHOW TO CURRENT
    new_fx_chunk = new_fx_chunk:gsub("(FLOAT.-\n)",plugin_float) -- SET STORED CHAIN FLOAT TO CURRENT

    local track_chunk = GetTrackChunk(tbl.rprobj)
    track_chunk = track_chunk:gsub(Literalize(current_fx), new_fx_chunk)
    SetTrackChunk(tbl.rprobj, track_chunk)
end

function SetInsertLaneChunk(tbl, lane)
    if not lane then return end -- IN RARE SITUATIONS LANE IS NOT CALCULATED FROM MOUSE
    local track_chunk = GetTrackChunk(tbl.rprobj)
    local lane_mask = 1 << (lane - 1)
    if not track_chunk:find("LANESOLO") then -- IF ANY LANE IS NOT SOLOED LANESOLO PART DOES NOT EXIST YET AND WE NEED TO INJECT IT
        track_chunk = track_chunk:gsub("<TRACK\n", "<TRACK\n".. string.format("LANESOLO %i 0", lane_mask) .. "\n", 1)
    else
        track_chunk = track_chunk:gsub("(LANESOLO )%d+", "%1" ..lane_mask)
    end
    SetTrackChunk(tbl.rprobj, track_chunk)
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
    razor_info.track = track
    return razor_info
end

local function Calculate_Track_Razor_data(tbl, razor_data)
    local razor_b = razor_data.razor_lane * (1 / #tbl.info)
    local razor_t = -(razor_b - (razor_data.razor_lane * razor_b)) / razor_data.razor_lane
    return razor_t, razor_b
end

function Create_Razor_From_LANE(tbl, razor_data)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end
    local razor_b = tbl.idx * (1 / #tbl.info)
    local razor_t = -(razor_b - (tbl.idx * razor_b)) / tbl.idx
    local razor_str = razor_data[1] .. " " .. razor_data[2] .. " " .. "'' " .. razor_t .. " " .. razor_b
    reaper.GetSetMediaTrackInfo_String(tbl.rprobj, "P_RAZOREDITS_EXT", razor_str, true)
end

function Set_Razor_Data(tbl, razor_data)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end
    if not tbl.info[razor_data.razor_lane] then return end -- DO NOT CREATE RAZOR IF LANE DOES NOT EXIST IN TABLE
    local calc_razor_t, calc_razor_b = Calculate_Track_Razor_data(tbl, razor_data)
    local razor_str = razor_data[1] .. " " .. razor_data[2] .. " " .. "'' " .. calc_razor_t .. " " .. calc_razor_b
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

    local item_fadein = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
    local item_fadeout = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
    local new_start = time_Start <= item_start and item_start or time_Start
    local new_fade_in = item_start + item_fadein - new_start > 0 and item_start + item_fadein - new_start or 0.01
    new_fade_in = new_fade_in > item_fadein and item_fadein or new_fade_in
    local new_lenght = time_End >= item_end and item_end - new_start or time_End - new_start
    local new_fade_out = item_fadeout - (item_end - time_End) > 0 and item_fadeout - (item_end - time_End) or 0.01
    new_fade_out = new_fade_out > item_fadeout and item_fadeout or new_fade_out
    local new_offset = time_Start <= item_start and 0 or (time_Start - item_start)
    return new_start, new_lenght, new_offset, new_fade_in, new_fade_out
end

local function Delete_items_or_area(item, time_Start, time_End)
    local first_to_delete = reaper.SplitMediaItem(item, time_End)
    local last_to_delete = reaper.SplitMediaItem(item, time_Start)
    if last_to_delete then
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(last_to_delete), last_to_delete)
    else
        reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
    end
end

local function Make_item_from_razor(tbl, item, razor_info)
    if not item then return end
    local time_Start, time_End, razor_lane = razor_info[1], razor_info[2], razor_info.razor_lane
    local item_chunk = Get_Item_Chunk(item, true):gsub("{.-}", "") -- GENERATE NEW GUIDS FOR NEW ITEM, WE KEEP COLOR HERE TO GET IT IN COMP LANE (ITS REMOVED WHEN COMP IS OFF)
    local new_item_start, new_item_lenght, new_item_offset, fade_in, fade_out = Razor_item_position(item, time_Start, time_End)
    local item_start_offset = tonumber(item_chunk:match("SOFFS (%S+)"))
    local item_play_rate = tonumber(item_chunk:match("PLAYRATE (%S+)"))
    ----------------------------------
    local auto_crossfade = reaper.GetToggleCommandState(40041)
    local is_midi = item_chunk:match("MIDI")
    local rv, def_auto_crossfade_value = reaper.get_config_var_string("defsplitxfadelen")
    local crossfade_offset = (auto_crossfade == 0 or is_midi) and 0 or def_auto_crossfade_value
    ----------------------------------
    local created_chunk = item_chunk:gsub("(POSITION) %S+", "%1 " .. new_item_start - crossfade_offset):gsub("(LENGTH) %S+", "%1 " .. new_item_lenght + (crossfade_offset * 2)):gsub("(SOFFS) %S+", "%1 " .. item_start_offset + (new_item_offset * item_play_rate) - crossfade_offset)
    local createdItem = reaper.AddMediaItemToTrack(tbl.rprobj)
    reaper.SetItemStateChunk(createdItem, created_chunk, false)
    reaper.SetMediaItemInfo_Value(createdItem, "D_FADEINLEN", fade_in)
    reaper.SetMediaItemInfo_Value(createdItem, "D_FADEOUTLEN", fade_out)
    reaper.SetMediaItemInfo_Value(createdItem, "F_FREEMODE_Y", (tbl.comp_idx - 1) / #tbl.info)
    reaper.SetMediaItemInfo_Value(createdItem, "F_FREEMODE_H", 1 / #tbl.info)
    return createdItem, created_chunk
end

function CopyToCOMP(tr)
    if not RAZOR_INFO then return end
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        if reaper.ValidatePtr(tr_tbl.rprobj, "TrackEnvelope*") then return end -- PREVENT DOING THIS ON ENVELOPES
        if tr_tbl.lane_mode == 0 then return end -- PREVENT DOING IN NON LANE MODE
        if tr_tbl.comp_idx == 0 or tr_tbl.comp_idx == RAZOR_INFO.razor_lane then return end -- PREVENT COPY ONTO ITSELF OR IF COMP DISABLED
        if RAZOR_INFO.track ~= tr_tbl.rprobj then Set_Razor_Data(tr_tbl, RAZOR_INFO) end-- JUST SET RAZOR ON OTHER TRACKS (ONLY FOR VISUAL) , do not add on self
        local new_items, to_delete = {}, {}
        for i = 1, reaper.CountTrackMediaItems(tr_tbl.rprobj) do
            if tr_tbl.info[RAZOR_INFO.razor_lane] then -- only add if razor lane is within lane numbers else skip it
                new_items[#new_items + 1] = Get_items_in_Lane(reaper.GetTrackMediaItem(tr_tbl.rprobj, i-1), RAZOR_INFO[1], RAZOR_INFO[2], RAZOR_INFO.razor_lane) -- COPY ITEMS FROM RAZOR LANE
                to_delete[#to_delete + 1] = Get_items_in_Lane(reaper.GetTrackMediaItem(tr_tbl.rprobj, i-1), RAZOR_INFO[1], RAZOR_INFO[2], tr_tbl.comp_idx) -- WE ARE GONNA DELETE ON COMPING LANE IF RAZOR IS EMPTY
            end
        end
        for i = 1, #to_delete do Delete_items_or_area(to_delete[i], RAZOR_INFO[1], RAZOR_INFO[2]) end -- DELETE ITEMS CONTENT (IF RAZOR IS EMPTY) COMPING "SILENCE"
        for i = 1, #new_items do Make_item_from_razor(tr_tbl, new_items[i], RAZOR_INFO) end
        --SetInsertLaneChunk(tr_tbl, tr_tbl.idx) --! HACK TO LEAVE SOLO LANES UNSELECTED (NUMBER HIGHER THAN ACTUAL LANE NUMBERS)
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Copy to comp lane ", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
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

function CheckTrackLaneModeState(tr_tbl)
    reaper.PreventUIRefresh(1)
    if not reaper.ValidatePtr(tr_tbl.rprobj, "MediaTrack*") then return end
    local current_track_mode = math.floor(reaper.GetMediaTrackInfo_Value(tr_tbl.rprobj, "I_FREEMODE"))
    if current_track_mode ~= tr_tbl.lane_mode then
        if current_track_mode == 2 then StoreLaneData(tr_tbl) end
        local original_track_mode = SEL_TRACK_TBL.lane_mode
        tr_tbl.lane_mode = original_track_mode
        if original_track_mode == 2 then
            Set_LaneView_mode(tr_tbl)
        elseif original_track_mode == 0 then
            SwapVirtualTrack(tr_tbl.idx, tr_tbl.rprobj)
        end
    end
    SaveCurrentState(tr_tbl)
    reaper.PreventUIRefresh(-1)
end

function ShowAll(lane_mode)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = CURRENT_TRACKS--tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        if not reaper.ValidatePtr(tr_tbl.rprobj, "MediaTrack*") then return end
        local fimp = reaper.GetMediaTrackInfo_Value(tr_tbl.rprobj, "I_FREEMODE")
        tr_tbl.lane_mode = lane_mode == 2 and 0 or 2
        if fimp == 2 then StoreLaneData(tr_tbl) end -- MAKE SURE TO CHECK WITH API IF IN LANE MODE BEFORE STORING (ELSE DATA WILL BE BROKEN)
        if lane_mode == 0 then -- IF LANE MODE IS OFF TURN IT ON
            Set_LaneView_mode(tr_tbl)
        elseif lane_mode == 2 then -- IF LANE MODE IS ON TURN IT OFF
            SetCompLane(tr_tbl.rprobj, 0) -- TURN OFF COMPING
            SwapVirtualTrack(tr_tbl.idx, tr_tbl.rprobj)
        end
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "Show all ", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateTimeline()
    reaper.UpdateArrange()
end

function CreateVT_Element(rprobj)
    if not VT_TB[rprobj] then
        local tr_data, lane = GetChunkTableForObject(rprobj, true)
        tr_data = lane and tr_data or {tr_data}
        for i = 1, #tr_data do tr_data[i].name = "Version " .. i end

        local fx_data = reaper.ValidatePtr(rprobj, "MediaTrack*") and { GetFX_Chunk(rprobj) }
        if fx_data then
            for i = 1, #fx_data do fx_data[i].name = "FX Ver " .. i end
        end

        VT_TB[rprobj] = Element:new(rprobj, tr_data, fx_data)
        Restore_From_PEXT(VT_TB[rprobj])
    end
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
        CreateVT_Element(rprobj)
        if next(VT_TB) then return VT_TB[rprobj] end
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
        for _, v in pairs(VT_TB) do Restore_From_PEXT(v) end
    end
end

function SetCompLane(tr, lane)
    reaper.Undo_BeginBlock2(0)
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        --local new_lane = lane and lane or tr_tbl.idx
        tr_tbl.comp_idx = lane and lane or ACTION_ID--tr_tbl.comp_idx == 0 and new_lane or 0
        SetCompActiveIcon(tr_tbl)
        StoreStateToDocument(tr_tbl)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "SetCompLane ", -1)
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

function Same_Envelope_AS_Mouse(tr_tbl)
    local same_envelopes = nil
    local all_childs = GetChild_ParentTrack_FromStored_PEXT(tr_tbl)
    if reaper.ValidatePtr(SEL_TRACK_TBL.rprobj, "TrackEnvelope*") then
        same_envelopes = {}
        local m_retval, m_name = reaper.GetEnvelopeName(SEL_TRACK_TBL.rprobj)
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

function GetSelectedTracksData(tbl)
    local tracks = GetSelectedTracks()
    local tracks_tbl = {}
    if not tracks then return { [tbl.rprobj] = tbl } end
    if tracks then
        if not tracks[tbl.rprobj] then tracks[tbl.rprobj] = tbl.rprobj end -- insert current track into selection also
        for track in pairs(tracks) do
            CreateVT_Element(track)
            if not tracks_tbl[track] then tracks_tbl[track] = VT_TB[track] end
        end
        return tracks_tbl
    end
end

function NewComp(tr)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock2()
    local selected_tracks = tr and {CURRENT_TRACKS[tr]} or CURRENT_TRACKS
    for track in pairs(selected_tracks) do
        local tr_tbl = selected_tracks[track]
        local comp_cnt = 1
        for i = 1, #tr_tbl.info do
            if tr_tbl.info[i].name and tr_tbl.info[i].name:find("COMP") then comp_cnt = comp_cnt + 1 end
        end
        local comp_name = "COMP - " .. comp_cnt
        CreateNew(tr_tbl.rprobj, comp_name)
        SetCompLane(tr_tbl.rprobj, 1)
    end
    reaper.Undo_EndBlock2(0, "VT: " .. "NewComp ", -1)
    reaper.PreventUIRefresh(-1)
end

function SetLaneImageColors(tbl)
    if not OPTIONS["LANE_COLORS"] then return end
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
        if tbl.def_icon == nil then
            local retval, current_icon = reaper.GetSetMediaTrackInfo_String( tbl.rprobj, "P_ICON", 0, false )
            tbl.def_icon = retval and current_icon or ""
            reaper.GetSetMediaTrackInfo_String(tbl.rprobj, "P_ICON" , icon_path, true)
        end
    else
        if tbl.def_icon ~= nil then
            reaper.GetSetMediaTrackInfo_String(tbl.rprobj, "P_ICON" , tbl.def_icon, true)
            tbl.def_icon = nil
        end
    end
end

function GetTracksOfGroup(val)
    local stored_tbl = Get_Stored_PEXT_STATE_TBL()
    if not stored_tbl then return end
    local groups = {}
    for k, v in pairs(stored_tbl) do
        if CheckSingleGroupBit(v.group, val) then -- GET ONLY SPECIFIED GROUP
            if not groups[k] then groups[k] = v end
        end
    end
    return groups
end

function GetTracksOfMask(val)
    local stored_tbl = Get_Stored_PEXT_STATE_TBL()
    if not stored_tbl then return end
    local groups = {}
    local active_groups = Get_active_groups(val)
    for i = #active_groups, 1, -1 do
       if not CheckSingleGroupBit(GROUP_LIST.enabled_mask, active_groups[i]) then table.remove(active_groups,i) end -- IF GROUP IS NOT ENABLED REMOVE IT FROM TABLE
    end
    for i = 1, #active_groups do
        for k, v in pairs(stored_tbl) do
            if reaper.ValidatePtr(k, "MediaTrack*") then
                if CheckGroupMaskBits(v.group, active_groups[i]) then -- GET ONLY TRACKS OF ENABLED GROUPS
                    if not groups[k] then groups[k] = v end
                end
            end
        end
    end
    return groups
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
    for i = 1, 64 do
        group_list[i] = { name = "GROUP " .. i}
    end
    group_list.enabled_mask = 0xFFFFFFFFFFFFFFFFF
    return group_list
end

function Set_MaskGroup_Enabled_Disabled(bits, enable)
    if not enable then -- BITS ARE 1
        GROUP_LIST.enabled_mask = GROUP_LIST.enabled_mask | bits -- SET ALL BITS IN GROUP TO 1
        GROUP_LIST.enabled_mask = GROUP_LIST.enabled_mask ~ bits -- SET ALL BITS TO IN GROUP 0 (DISABLE GROUP)
    elseif enable then -- BITS ARE 0
        GROUP_LIST.enabled_mask = GROUP_LIST.enabled_mask | bits -- SET BITS TO 1 (ENABLE GROUP)
    end
end

function Set_SingleGroup_Enabled_Disabled(bit, enable)
    if not enable then -- BITS ARE 1
        GROUP_LIST.enabled_mask = GROUP_LIST.enabled_mask | (1 << (bit - 1))
        GROUP_LIST.enabled_mask = GROUP_LIST.enabled_mask ~ (1 << (bit - 1)) -- SET BITS TO 0 (REMOVE GROUP)
    elseif enable then -- BITS ARE 0
        GROUP_LIST.enabled_mask = GROUP_LIST.enabled_mask | (1 << (bit - 1)) -- SET BITS TO 1 (ADD GROUP)
    end
end

function ADD_REMOVE_GROUP_TO_TRACK(tbl, bit, enable)
    if not enable then -- BITS ARE 1
        tbl.group = tbl.group | (1 << (bit - 1)) -- SET BIT TO 1 TO MAKE SURE ITS 1
        tbl.group = tbl.group ~ (1 << (bit - 1)) -- SET BIT TO 0 (REMOVE GROUP)
    elseif enable then -- BITS ARE 0
        tbl.group = tbl.group | (1 << (bit - 1)) -- SET BIT TO 1 (ADD GROUP)
    end
end

function Get_active_groups(n)
    local b = 1
    local bit_array = {}
    while n ~= 0 do
        if n & 1 == 1 then table.insert(bit_array, b) end
        b = b + 1
        n = n >> 1
    end
    return bit_array
end

function CheckSingleGroupBit(group, bit)
    if not group or not bit then return false end
    return group & (1 << (bit - 1)) ~= 0 and true
end

function CheckGroupMaskBits(group, bits)
    if not group or not bits then return false end
    return group & bits ~= 0 and true or false
end

local function GetMouseTrackXYH(track)
	if reaper.ValidatePtr(track, "MediaTrack*") then
        local tr_t = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
		local tr_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
		return tr_t, tr_h, tr_t + tr_h
    elseif reaper.ValidatePtr(track, "TrackEnvelope*") then
		local p_tr = reaper.GetEnvelopeInfo_Value(track, "P_TRACK")
		local p_tr_t = reaper.GetMediaTrackInfo_Value(p_tr, "I_TCPY")
		local env_t = reaper.GetEnvelopeInfo_Value(track, "I_TCPY") + p_tr_t
		local env_h = reaper.GetEnvelopeInfo_Value(track, "I_TCPH")
		return env_t, env_h, env_t + env_h
	end
end

function To_client(x,y)
    local cx, cy = reaper.JS_Window_ScreenToClient( track_window, x, y )
    return cx, cy
end

function Get_track_under_mouse()
	local x, y = reaper.GetMousePosition()
    local _, cy = To_client(x, y)
    local track, env_info = reaper.GetTrackFromPoint(x, y)
    if track and env_info == 0 then
        return track
    elseif track and env_info == 1 then
        for i = 1, reaper.CountTrackEnvelopes(track) do
            local env = reaper.GetTrackEnvelope(track, i - 1)
			local env_t, _, env_b = GetMouseTrackXYH(env)
            if env_t <= cy and env_b >= cy then return env end
        end
    end
end

local lane_offset = 14 -- schwa decided this number by carefully inspecting pixels in paint.net
function Get_lane_from_mouse_coordinates(mouse_tr)
	if mouse_tr == nil then return end
	if not reaper.ValidatePtr(mouse_tr, "MediaTrack*") then return end
    local _, my = reaper.GetMousePosition()
	local item_for_height = reaper.GetTrackMediaItem(mouse_tr, 0)
	if not item_for_height then return 1 end
	local _, cy = To_client(0, my)
    local total_lanes = round(1 / reaper.GetMediaItemInfo_Value(item_for_height, 'F_FREEMODE_H')) -- WE CHECK LANE HEIGHT WITH ANY ITEM ON TRACK
	local t, h, b = GetMouseTrackXYH(mouse_tr)
	if cy > t and cy < b then
		local lane = math.floor(((cy - t) / (h - lane_offset)) * total_lanes) + 1
		lane = lane <= total_lanes and lane or total_lanes
		return lane
	end
end

function MouseInfo(mouse_tr)
	local mouse_lane = Get_lane_from_mouse_coordinates(mouse_tr)
    return mouse_lane
end

function Find_Highest(tbl)
    local cur_lane_mode
    local cur_comp_idx = 0
    local highest, cur_idx = 0, 0
    for _, v in pairs(tbl)do
        if #v.info > highest then
            highest = #v.info
            cur_idx = v.idx
            cur_lane_mode = v.lane_mode
        end
    end
    for _, v in pairs(tbl)do
        if v.comp_idx ~= 0 then
            cur_comp_idx = v.comp_idx -- IS ANY CHILD IN COMP MODE
            break
        end
    end
    return highest, cur_idx, cur_lane_mode, cur_comp_idx
end

function GetFolderChilds(track)
    if not reaper.ValidatePtr(track, "MediaTrack*") then return end
    if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then return end
    if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") <= 0 then return end -- ignore tracks and last folder child
    local depth, children = 0, {}
    local folderID = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = folderID + 1, reaper.CountTracks(0) - 1 do -- start from first track after folder
        local child = reaper.GetTrack(0, i)
        local currDepth = reaper.GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
        --if currDepth ~= 1 then --! EXCLUDE SUB FOLDERS
            CreateVT_Element(child)
            children[child] = VT_TB[child]
        --end
        depth = depth + currDepth
        if depth <= -1 then break end --until we are out of folder
    end
    return children
end