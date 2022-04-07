-- @description EDIT GROUPS
-- @author Sexan
-- @license GPL v3
-- @version 0.18
-- @changelog
--   + support for non-continuous (multiple razors)

local reaper = reaper

if not reaper.APIExists("JS_ReaScriptAPI_Version") then
    reaper.MB( "JS_ReaScriptAPI is required for this script. Please download it from ReaPack", "SCRIPT REQUIREMENTS", 0 )
    reaper.ReaPack_BrowsePackages('JS_ReaScriptAPI:')
    return reaper.defer(function() end)
end

local _, _, sectionID, cmdID, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID, cmdID, 1)
reaper.RefreshToolbar2(sectionID, cmdID)

function Round(num) return math.floor(num + 0.5) end
function MSG(m) reaper.ShowConsoleMsg(tostring(m) .. "\n") end

local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local WML_intercept = reaper.JS_WindowMessage_Intercept(track_window, "WM_LBUTTONDOWN", true) -- INTERCEPT MOUSE L BUTTON
local WML_intercept2 = reaper.JS_WindowMessage_Intercept(track_window, "WM_LBUTTONUP", true) -- INTERCEPT MOUSE L BUTTON

local prevTime , prevTime2 = 0,0
function Track_mouse_LCLICK()
    CLICK, UP = nil, nil
    local pOK2, pass2, time2, wLow2, wHigh2, lLow2, lHigh2 = reaper.JS_WindowMessage_Peek(track_window, "WM_LBUTTONDOWN")
    local pOK, pass, time, wLow, wHigh, lLow, lHigh = reaper.JS_WindowMessage_Peek(track_window, "WM_LBUTTONUP")
    if pOK and time > prevTime then
        prevTime = time
        UP = true
    end
    if pOK2 and time2 > prevTime2 then
        prevTime2 = time2
        CLICK = true
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

local function In_Group(tbl, val)
    for i = 1, #tbl do if tbl[i] == val then return true end end
end

local function In_Any_Group(val)
    for i = 1, 64 do
        if In_Group(GROUPS[i], val) then return true end
    end
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

local function IsAnyGroupFilled()
    for i = 1 , 64 do
        if #GROUPS[i] ~= 0 then return true end
    end
    return false
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

local function GetAndSelectItemsInGroups(tr_tbl, item)
    local sel_item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local sel_item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local sel_item_end = sel_item_lenght + sel_item_start

    for i = 1, reaper.CountTrackMediaItems(tr_tbl) do
        local item_in_group = reaper.GetTrackMediaItem(tr_tbl, i - 1)
        local item_lenght = reaper.GetMediaItemInfo_Value(item_in_group, "D_LENGTH")
        local item_start = reaper.GetMediaItemInfo_Value(item_in_group, "D_POSITION")
        local item_end = item_lenght + item_start
        if (item_start >= sel_item_start) and (item_start < sel_item_end) and (item_end <= sel_item_end) then
            reaper.SetMediaItemSelected(item_in_group, true)
        end
    end
end

local function UnselectAllItems()
    for i = reaper.CountSelectedMediaItems(0), 1, -1 do
        reaper.SetMediaItemSelected(reaper.GetSelectedMediaItem(0, i - 1), false)
    end
end

local function Edit_groups()
    local item_under_cursor = reaper.BR_ItemAtMouseCursor()

    if item_under_cursor then
        local item_track = reaper.GetMediaItemTrack( item_under_cursor )
        if CLICK or UP  then
            CLICKED_ITEM = In_Any_Group(item_track) and item_under_cursor -- IF TRACK IS IN ANY GROUP
            DEST_TRACK = CLICKED_ITEM and item_track -- IF TRACK IS IN ANY GROUP
            if CLICKED_ITEM then UnselectAllItems() end -- UNSELECT ONLY WHEN IN ANY GROUP
        end
    end

    if MARQUEE_ITEM then
        local item = reaper.GetSelectedMediaItem(0,0)
        if item then
            CLICKED_ITEM = item
            DEST_TRACK = reaper.GetMediaItemTrack( item )
        end
    end

    if RAZOR and not CLICKED_ITEM then DEST_TRACK = RAZOR.track end

    if RAZOR or CLICKED_ITEM or MARQUEE_ITEM then
        reaper.PreventUIRefresh(1)
        for j = 1, #GROUPS do
            for k = 1, #GROUPS[j] do
                if In_Group(GROUPS[j], DEST_TRACK) then
                    if RAZOR then Set_Razor_Data(GROUPS[j][k], RAZOR) end
                    if CLICKED_ITEM then GetAndSelectItemsInGroups(GROUPS[j][k], CLICKED_ITEM) end
                end
            end
        end
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()

        if RAZOR then RAZOR = nil end
        if UP then CLICKED_ITEM = nil end
        if MARQUEE_ITEM then
            MARQUEE_ITEM = nil
            CLICKED_ITEM = nil
        end
        DEST_TRACK = nil
    end
end

local lastProjectChangeCount = reaper.GetProjectStateChangeCount(0)
local function Is_razor_created()
    local razor_action = nil
    local projectChangeCount = reaper.GetProjectStateChangeCount(0)
    if lastProjectChangeCount ~= projectChangeCount then
        local last_action = reaper.Undo_CanUndo2( 0 ):lower()
        if last_action:match("razor") then razor_action = true
        elseif last_action:match("group membership") then Fill_groups() -- REFRESH GROUPS WHEN CHANGE IN GROUPS DETECTED
        elseif last_action:match("marquee item selection") then MARQUEE_ITEM = true
        end
        lastProjectChangeCount = projectChangeCount
    end
    return razor_action
end

local function Main()
    MOUSE_TR = Get_track_under_mouse()
    Track_mouse_LCLICK()
    if Is_razor_created() then RAZOR = Get_Razor_Data(MOUSE_TR) end
    Edit_groups()
    reaper.defer(Main)
end

function DoAtExit()
    reaper.SetToggleCommandState(sectionID, cmdID, 0);
    reaper.RefreshToolbar2(sectionID, cmdID);
    reaper.JS_WindowMessage_Release(track_window, "WM_LBUTTONDOWN")
end

Fill_groups()
if not IsAnyGroupFilled() then
    reaper.MB( "All groups are empty, turning script off", "ALL GROUPS ARE EMPTY", 0 )
    DoAtExit()
    return reaper.defer(function() end)
else
    Main()
end
reaper.atexit(DoAtExit)
