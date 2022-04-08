-- @description EDIT GROUPS
-- @author Sexan
-- @license GPL v3
-- @version 0.27
-- @changelog
--   + check if media items track is in group before proceding

local reaper = reaper

if not reaper.APIExists("JS_ReaScriptAPI_Version") then
    reaper.MB( "JS_ReaScriptAPI is required for this script. Please download it from ReaPack", "SCRIPT REQUIREMENTS", 0 )
    reaper.ReaPack_BrowsePackages('JS_ReaScriptAPI:')
    return reaper.defer(function() end)
elseif not reaper.ImGui_GetVersion then
    reaper.MB( "ReaImGui is required for this script. Please download it from ReaPack", "SCRIPT REQUIREMENTS", 0 )
    reaper.ReaPack_BrowsePackages( 'ReaImGui:')
    return reaper.defer(function() end)
end

local _, _, sectionID, cmdID, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID, cmdID, 1)
reaper.RefreshToolbar2(sectionID, cmdID)

function Round(num) return math.floor(num + 0.5) end
function MSG(m) reaper.ShowConsoleMsg(tostring(m) .. "\n") end

local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
reaper.JS_WindowMessage_Intercept(track_window, "WM_LBUTTONDOWN", true) -- INTERCEPT L MOUSE DOWN
reaper.JS_WindowMessage_Intercept(track_window, "WM_LBUTTONUP", true) -- INTERCEPT L MOUSE UP
reaper.JS_WindowMessage_Intercept(track_window, "WM_RBUTTONUP", true) -- INTERCEPT R MOUSE UP

local reaper_cursors = {
    [105] ='FADE L',
    [184] ='FADE R',
    [417] ='TRIM L',
    [418] ='TRIM R',
    [450] = 'DUAL TRIM',
    [529] = 'CROSSFADE',
    [183] = 'START OFFSET',
    [98181] = 'VOLUME',
    [187] = 'MOVE',
}

local function TrackCursors()
    local cur_cursor = reaper.JS_Mouse_GetCursor() -- returns han
    for k in pairs(reaper_cursors) do
        if cur_cursor == reaper.JS_Mouse_LoadCursor(k) then return true end
    end
end

OLD_GROUP = -1
local prevTime = 0
local prevTime2 = 0
local prevTime3 = 0
function Track_mouse_LCLICK()
    local pOK, _, time = reaper.JS_WindowMessage_Peek(track_window, "WM_LBUTTONDOWN")
    if pOK and time > prevTime then
        prevTime = time
        if TrackCursors() then
            if not Find_Group(reaper.GetMediaItemTrack( reaper.BR_ItemAtMouseCursor() )) then return end
            SelectAllItems(false)
            CLICKED_ITEM = reaper.BR_ItemAtMouseCursor()
            DEST_TRACK = CLICKED_ITEM and reaper.GetMediaItemTrack( CLICKED_ITEM )
            CUR_GROUP = Find_Group(DEST_TRACK)
        else
            CUR_GROUP = 0
        end

    end
    local pOK2, _, time2 = reaper.JS_WindowMessage_Peek(track_window, "WM_LBUTTONUP")
    if pOK2 and time2 > prevTime2 then
        prevTime2 = time2
        local UP_ITEM = reaper.BR_ItemAtMouseCursor()
        if UP_ITEM then
            if not Find_Group(reaper.GetMediaItemTrack( UP_ITEM )) then return end
            if reaper.GetMediaItemInfo_Value( UP_ITEM, "B_UISEL" ) == 1 then
                CLICKED_ITEM = reaper.BR_ItemAtMouseCursor()
                DEST_TRACK = CLICKED_ITEM and reaper.GetMediaItemTrack( CLICKED_ITEM )
                CUR_GROUP = Find_Group(DEST_TRACK)
            end
        else
            CUR_GROUP = 0
        end
    end
    local pOK3, _, time3 = reaper.JS_WindowMessage_Peek(track_window, "WM_RBUTTONUP")
    if pOK3 and time3 > prevTime3 then
        prevTime3 = time3
        local UP_ITEM = reaper.GetSelectedMediaItem(0,0)
        if UP_ITEM then
            if not Find_Group(reaper.GetMediaItemTrack( UP_ITEM )) then return end
            CLICKED_ITEM = UP_ITEM
            DEST_TRACK = CLICKED_ITEM and reaper.GetMediaItemTrack( CLICKED_ITEM )
            CUR_GROUP = Find_Group(DEST_TRACK)
        else
            CUR_GROUP = 0
        end
    end
end

local GROUP_FLAGS = {
    "VOLUME_LEAD",
    "VOLUME_FOLLOW",
    "VOLUME_VCA_LEAD",
    "VOLUME_VCA_FOLLOW",
    "PAN_LEAD",
    "PAN_FOLLOW",
    "WIDTH_LEAD",
    "WIDTH_FOLLOW",
    "MUTE_LEAD",
    "MUTE_FOLLOW",
    "SOLO_LEAD",
    "SOLO_FOLLOW",
    "RECARM_LEAD",
    "RECARM_FOLLOW",
    "POLARITY_LEAD",
    "POLARITY_FOLLOW",
    "AUTOMODE_LEAD",
    "AUTOMODE_FOLLOW",
    "VOLUME_REVERSE",
    "PAN_REVERSE",
    "WIDTH_REVERSE",
    "NO_LEAD_WHEN_FOLLOW",
    "VOLUME_VCA_FOLLOW_ISPREFX",
}

local GROUPS = {}
GROUPS.enabled_mask = 0

local GROUP_NAMES = {}
for i = 1, 64 do GROUP_NAMES[i] = "GROUP " .. i end

function Set_Group_EDIT_ENABLE(group, enable)
    if not enable then -- BITS ARE 1
        GROUPS.enabled_mask = GROUPS.enabled_mask | (1 << (group - 1))
        GROUPS.enabled_mask = GROUPS.enabled_mask ~ (1 << (group - 1)) -- SET BITS TO 0 (DISABLE)
    elseif enable then -- BITS ARE 0
        GROUPS.enabled_mask = GROUPS.enabled_mask | (1 << (group - 1)) -- SET BITS TO 1 (ENABLE)
    end
end

function CheckGroupEnable(group)
    return GROUPS.enabled_mask & (1 << (group - 1)) ~= 0 and true
end

function Find_Group(val)
    for i = 1, 64 do
        for k, v in pairs(GROUPS[i]) do
            if v == val then
                if CheckGroupEnable(i) then return i end
            end
        end
    end
end

local function In_Group(tbl, val)
    for i = 1, #tbl do if tbl[i] == val then return true end end
end

local function Fill_groups()
    for i = 1 , 64 do GROUPS[i] = {} end -- refresh table
    for k = 1, reaper.CountTracks(0) do
        local track = reaper.GetTrack(0, k-1)
        for i = 1 , #GROUPS do
            for j = 1, #GROUP_FLAGS do
                local G32 = reaper.GetSetTrackGroupMembership( track, GROUP_FLAGS[j], 0, 0 )
                local G64 = reaper.GetSetTrackGroupMembershipHigh( track, GROUP_FLAGS[j], 0, 0 )
                if G32 & (1 << (i - 1)) ~= 0 then
                    if not In_Group(GROUPS[i],track) then table.insert(GROUPS[i],track) end
                end
                if G64 & (1 << (i-32 - 1)) ~= 0 then
                    if not In_Group(GROUPS[i],track) then table.insert(GROUPS[i],track) end
                end
            end
        end
    end
end

local function FreeGroup()
    for i = 1 , 64 do if next(GROUPS[i]) == nil then GROUP_NAMES[i] = "GROUP " .. i return i end end
end

local function GetEnvGuidFromName(track, env_name )
    if not track then return end
    local env = reaper.GetTrackEnvelopeByName(track, env_name )
    if env then
        local _, env_guid = reaper.GetSetEnvelopeInfo_String( env, "GUID", "", false )
        return env_guid
    end
end

local function Get_Total_lanes(track)
    local item = reaper.GetTrackMediaItem(track, 0) -- get any item for checking lanes
    if not item then return 1 end
    local _, chunk = reaper.GetItemStateChunk( item, "", false )
    local lane_h = tonumber(chunk:match("YPOS %S+ (%S+)")) and tonumber(chunk:match("YPOS %S+ (%S+)")) or 1
    return lane_h
end

local function Calculate_New_Razors_from_lanes(track, razor_data)
    local lane_h = Get_Total_lanes(track)
    local new_top = razor_data.lanes.top * lane_h
    local new_bot = razor_data.lanes.bot * lane_h
    return new_top, new_bot
end

local function Set_Razor_Data(track, razors)
    local razor_str = ""
    for r = 1, #razors do
        for i = 1, #razors[r].env do
            local env_guid = GetEnvGuidFromName(track, razors[r].env[i])
            if env_guid then -- ENVELOPE
                razor_str = razor_str .. razors[r][1] .. " " .. razors[r][2] .. " "  .. env_guid .. " " .. "0 1" .. ","
            elseif razors[r].env[i] == '""' then -- NORMAL TRACK
                local new_top, new_bot = Calculate_New_Razors_from_lanes(track, razors[r])
                if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 0 and new_top ~= 0 then return end -- SINCE NORMAL TRACK ADDS RAZORS NO MATTER WHAT JUST SKIP IT IF TOP IS NOT 0
                razor_str = razor_str .. razors[r][1] .. " " .. razors[r][2] .. " " .. "'' " .. new_top .. " " .. new_bot .. ","
            end
        end
    end
    reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS_EXT", razor_str, true)
end

local function Get_Razor_string(track)
    local all_razors = {}
    local _, razor_str = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS_EXT', '', false)
    if razor_str == "" then return nil end
    if razor_str:match(',') then
        for razor in razor_str:gmatch('([^,]+)') do
            table.insert(all_razors, razor)
        end
    else
        table.insert(all_razors, razor_str)
    end
    return all_razors
end

local function Get_Razor_Data(track)
    if not track then return end
    local razors_tbl = Get_Razor_string(track)
    if not razors_tbl then return nil end
    local razor_info = {}
    for r = 1, #razors_tbl do
        local razor_envelopes = {}
        razor_info[r] = {}
        for i in string.gmatch(razors_tbl[r], "%S+") do
            table.insert(razor_info[r],tonumber(i))
            if not tonumber(i) then razor_envelopes[#razor_envelopes+1] = i end
        end
        if #razor_envelopes ~= 0 then
            for i = 1, #razor_envelopes do
                local env_guid = razor_envelopes[i]:match("({.-})")
                if env_guid then
                    local env = reaper.GetTrackEnvelopeByChunkName( track, env_guid )
                    local _, env_name = reaper.GetEnvelopeName( env )
                    razor_envelopes[i] = env_name
                end
            end
        end
        local lane_h = Get_Total_lanes(track)
        razor_info[r].lanes = { top = Round(razor_info[r][3] / lane_h) , bot = Round(razor_info[r][4] / lane_h)} -- CALCULATE RAZOR LANE FROM COORDS (1, 2, 3 ETC) FOR EASIER CALCULATION LATER
        razor_info[r].env = next(razor_envelopes) and razor_envelopes
    end
    razor_info.track = track
    return razor_info
end

local function Get_track_under_mouse()
    local x, y = reaper.GetMousePosition()
    local track, env_info = reaper.GetTrackFromPoint(x, y)
    if track then return track end
end

local function GetAndSelectItemsInGroups(track, item)
    local track_set = nil
    local sel_item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local sel_item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local sel_item_end = sel_item_lenght + sel_item_start

    for i = 1, reaper.CountTrackMediaItems(track) do
        local item_in_group = reaper.GetTrackMediaItem(track, i - 1)
        local item_lenght = reaper.GetMediaItemInfo_Value(item_in_group, "D_LENGTH")
        local item_start = reaper.GetMediaItemInfo_Value(item_in_group, "D_POSITION")
        local item_end = item_lenght + item_start
        if (item_start >= sel_item_start) and (item_start < sel_item_end) and (item_end <= sel_item_end) then
            reaper.SetMediaItemSelected(item_in_group, true)
            reaper.SetTrackSelected(track, true )
            track_set = true
        end
    end
    return track_set
end

function SelectAllItems(set)
    for i = reaper.CountSelectedMediaItems(0), 1, -1 do
        reaper.SetMediaItemSelected(reaper.GetSelectedMediaItem(0, i - 1), set)
    end
end

local function SelectTracksInGROUP(group)
    if group == nil then return end
    local tr_tbl = GROUPS[group]
    if not tr_tbl then return end
    if next(tr_tbl) == nil then return end
    reaper.Main_OnCommand(40297,0)
    for k,v in pairs(tr_tbl) do
        reaper.SetTrackSelected(v, true)
    end
end

local lastProjectChangeCount = reaper.GetProjectStateChangeCount(0)
local function Is_razor_created()
    local razor_action = nil
    local projectChangeCount = reaper.GetProjectStateChangeCount(0)
    if lastProjectChangeCount ~= projectChangeCount then
        if reaper.Undo_CanUndo2( 0 ) then
            local last_action = reaper.Undo_CanUndo2( 0 ):lower()
            if last_action:match("razor") then razor_action = true
            elseif last_action:match("group membership") then Fill_groups() -- REFRESH GROUPS WHEN CHANGE IN GROUPS DETECTED
            elseif last_action:match("remove tracks") or last_action:match("paste tracks") then Fill_groups() -- REFRESH GROUPS WHEN CHANGE IN GROUPS DETECTED
            end
        end
        lastProjectChangeCount = projectChangeCount
    end
    return razor_action
end

local function Edit_groups()
    if RAZOR then DEST_TRACK = RAZOR.track end

    if RAZOR or CLICKED_ITEM then
        local CNT_TBL = CLICKED_ITEM and {} or nil
        reaper.PreventUIRefresh(1)
        for j = 1, #GROUPS do
            if CheckGroupEnable(j) then
                if CLICKED_ITEM then CNT_TBL[j] = {} end
                for k = 1, #GROUPS[j] do
                    if In_Group(GROUPS[j], DEST_TRACK) then
                        if RAZOR then Set_Razor_Data(GROUPS[j][k], RAZOR) end
                        if CLICKED_ITEM then CNT_TBL[j][#CNT_TBL[j]+1] = GetAndSelectItemsInGroups(GROUPS[j][k], CLICKED_ITEM) end
                    end
                end
            end
        end

        if CNT_TBL then
            local max, most_tracks_group = 1, 0
            for k, v in pairs(CNT_TBL) do
                if #v > max then max = #v most_tracks_group = k end
            end
            CUR_GROUP = most_tracks_group
        end
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()

        if RAZOR then RAZOR = nil end
        if CLICKED_ITEM then CLICKED_ITEM = nil end
        if DEST_TRACK then DEST_TRACK = nil end
    end
end

local function Main()
    MOUSE_TR = Get_track_under_mouse()
    if Is_razor_created() then RAZOR = Get_Razor_Data(MOUSE_TR) end
    Track_mouse_LCLICK()
    Edit_groups()
end

local function SetGroup(track, group, set)
    if group <= 32 then
        local add = set and (1 << (group - 1)) or 0
        reaper.GetSetTrackGroupMembership( track, GROUP_FLAGS[1], (1 << (group - 1)), add )
    else
        local add = set and (1 << (group-32 - 1)) or 0
        reaper.GetSetTrackGroupMembershipHigh( track, GROUP_FLAGS[1], (1 << (group-32 - 1)), add )
    end
end

local function AddSelectedTracksTo_GROUP(group, set)
    for i = 1, reaper.CountSelectedTracks(0) do
        SetGroup( reaper.GetSelectedTrack(0, i -1), group, set)
    end
    Fill_groups()
end

local ctx
local dock = 0
function ImGui_Create_CTX()
    ctx = reaper.ImGui_CreateContext('My script', reaper.ImGui_ConfigFlags_DockingEnable())
    reaper.ImGui_SetNextWindowDockID(ctx, dock)
end

local function Rename(i)
    local RV
    if reaper.ImGui_IsWindowAppearing(ctx) then
        reaper.ImGui_SetKeyboardFocusHere(ctx)
        NEW_NAME = GROUP_NAMES[i]
    end
    RV, NEW_NAME = reaper.ImGui_InputText(ctx, 'Name' , NEW_NAME, reaper.ImGui_InputTextFlags_AutoSelectAll())
    if reaper.ImGui_Button(ctx, 'OK') or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter()) then
        NEW_NAME = NEW_NAME:gsub("^%s*(.-)%s*$", "%1") -- remove trailing and leading
        if #NEW_NAME ~= 0 then SAVED_NAME = NEW_NAME end
        if SAVED_NAME then
            GROUP_NAMES[i] = SAVED_NAME
        end
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Cancel') then
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

function ContextMenu(i)
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then reaper.ImGui_CloseCurrentPopup(ctx) end
    if reaper.ImGui_MenuItem(ctx, 'Group settings') then reaper.Main_OnCommand( 40772, 0 ) end
    if reaper.ImGui_MenuItem(ctx, 'Add selected tracks') then AddSelectedTracksTo_GROUP(i, true) end
    if reaper.ImGui_MenuItem(ctx, 'Remove selected tracks') then AddSelectedTracksTo_GROUP(i, false) end
    if reaper.ImGui_Selectable(ctx, 'Rename Group', nil, reaper.ImGui_SelectableFlags_DontClosePopups()) then
        local x, y = reaper.ImGui_GetCursorScreenPos( ctx )
        reaper.ImGui_SetNextWindowPos( ctx, x, y)
        reaper.ImGui_OpenPopup(ctx, 'Rename')
    end
    if reaper.ImGui_BeginPopupModal(ctx, 'Rename', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        Rename(i)
        reaper.ImGui_EndPopup(ctx)
    end
end

function Draw_Color_Rect(color)
    local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
    local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, min_x, min_y, max_x, max_y, 0x11FFFF80)
end

function GUI()
    Main()
    if reaper.ImGui_Begin(ctx, 'EDIT GROUPS', false, reaper.ImGui_WindowFlags_NoCollapse()) then
        if reaper.ImGui_Button(ctx, 'ADD TO NEW GROUP', -1) then AddSelectedTracksTo_GROUP(FreeGroup(), true) end
        if reaper.ImGui_BeginListBox(ctx, '##Group List',-1,-1) then
            for i = 1, 64 do
                local has_tracks = next(GROUPS[i]) ~= nil
                if has_tracks then
                    if reaper.ImGui_Checkbox( ctx, '##'..i, CheckGroupEnable(i) ) then
                        Set_Group_EDIT_ENABLE(i, not CheckGroupEnable(i))
                    end
                    reaper.ImGui_SameLine(ctx)
                    if reaper.ImGui_Button(ctx, GROUP_NAMES[i], -1) then CUR_GROUP = i SelectTracksInGROUP(i) end
                    if CUR_GROUP == i then Draw_Color_Rect() end
                    if reaper.ImGui_BeginPopupContextItem(ctx) then
                        ContextMenu(i)
                        HIGH = i
                        reaper.ImGui_EndPopup(ctx)
                    end
                    if i == HIGH then Draw_Color_Rect() HIGH = nil end
                end
            end
            reaper.ImGui_EndListBox(ctx)
        end
        reaper.ImGui_End(ctx)
    end
    reaper.defer(GUI)
end

function SaveGroup_mask()
    reaper.SetProjExtState(0, "EDIT_GROUPS", "GROUP_NAMES", table.concat(GROUP_NAMES,"\n"))
    reaper.SetProjExtState(0, "EDIT_GROUPS", "MASK", GROUPS.enabled_mask)
end

local function RestoreGroupEnableMASK()
    local rv_mask, stored_mask = reaper.GetProjExtState( 0, "EDIT_GROUPS", "MASK" )
    if rv_mask == 1 and stored_mask ~= nil then
        GROUPS.enabled_mask = stored_mask
    end
    local rv_names, stored_names = reaper.GetProjExtState( 0, "EDIT_GROUPS", "GROUP_NAMES" )
    if rv_names == 1 and stored_names ~= nil then
        local cnt = 1
        for name in string.gmatch(stored_names, "[^\r\n]+") do
            GROUP_NAMES[cnt] = name
            cnt = cnt + 1
        end
    end
end

function DoAtExit()
    SaveGroup_mask()
    reaper.SetToggleCommandState(sectionID, cmdID, 0);
    reaper.RefreshToolbar2(sectionID, cmdID);
    reaper.JS_WindowMessage_Release(track_window, "WM_LBUTTONDOWN")
end

Fill_groups()
RestoreGroupEnableMASK()

ImGui_Create_CTX()
reaper.defer(GUI)

reaper.atexit(DoAtExit)
