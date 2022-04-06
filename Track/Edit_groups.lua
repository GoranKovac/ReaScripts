-- @description EDIT GROUPS
-- @author Sexan
-- @license GPL v3
-- @version 0.1
-- @changelog
--   + initial release


local reaper = reaper
local _, _, sectionID, cmdID, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID, cmdID, 1)
reaper.RefreshToolbar2(sectionID, cmdID)

function Round(num) return math.floor(num + 0.5) end
function MSG(m) reaper.ShowConsoleMsg(tostring(m) .. "\n") end

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
for i = 1 , 64 do GROUPS[i] = {} end

function In_table(tbl, val)
    for i = 1, #tbl do if tbl[i] == val then return true end end
end

local function Fill_groups()
    for k = 1, reaper.CountTracks(0) do
        local track = reaper.GetTrack(0, k-1)
        for i = 1 , #GROUPS do
            for j = 1, #GROUP_FLAGS do
                local G32 = reaper.GetSetTrackGroupMembership( track, GROUP_FLAGS[j], 0, 0 )
                local G64 = reaper.GetSetTrackGroupMembershipHigh( track, GROUP_FLAGS[j], 0, 0 )
                if G32 & (1 << (i - 1)) ~= 0 then
                    if not In_table(GROUPS[i],track) then table.insert(GROUPS[i],track) end
                end
                if G64 & (1 << (i-32 - 1)) ~= 0 then
                    if not In_table(GROUPS[i],track) then table.insert(GROUPS[i],track) end
                end
            end
        end
    end
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

local function Set_Razor_Data(track, razor_data)
    local razor_str = ""
    for i = 1, #razor_data.env do
        local env_guid = GetEnvGuidFromName(track, razor_data.env[i])
        if env_guid then -- ENVELOPE
            razor_str = razor_str .. razor_data[1] .. " " .. razor_data[2] .. " "  .. env_guid .. " " .. "0 1" .. ","
        elseif razor_data.env[i] == '""' then -- NORMAL TRACK
            local new_top, new_bot = Calculate_New_Razors_from_lanes(track, razor_data)
            if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 0 and new_top ~= 0 then return end -- SINCE NORMAL TRACK ADDS RAZORS NO MATTER WHAT JUST SKIP IT IF TOP IS NOT 0
            razor_str = razor_str .. razor_data[1] .. " " .. razor_data[2] .. " " .. "'' " .. new_top .. " " .. new_bot .. ","
        end
    end
    reaper.GetSetMediaTrackInfo_String(track, "P_RAZOREDITS_EXT", razor_str, true)
end

local function Get_Razor_Data(track)
    if not track then return end
    local _, razor_area = reaper.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS_EXT', '', false)
    if razor_area == "" then return nil end
    razor_area = razor_area:gsub(","," ")
    local razor_info = {}
    local razor_envelopes = {}
    for i in string.gmatch(razor_area, "%S+") do
        table.insert(razor_info,tonumber(i))
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
    razor_info.lanes = { top = Round(razor_info[3] / lane_h) , bot = Round(razor_info[4] / lane_h)} -- CALCULATE RAZOR LANE FROM COORDS (1, 2, 3 ETC) FOR EASIER CALCULATION LATER
    razor_info.env = next(razor_envelopes) and razor_envelopes
    return razor_info
end

local function Get_track_under_mouse()
    local x, y = reaper.GetMousePosition()
    local track, env_info = reaper.GetTrackFromPoint(x, y)
    if track then return track end
end


local function Edit_groups()
    SEL_ITEM = reaper.BR_ItemAtMouseCursor()
    MOUSE_TR = Get_track_under_mouse()
    --local sel_track =  reaper.GetMediaItem_Track( SEL_ITEM )
    RAZOR = Get_Razor_Data(MOUSE_TR)
    --reaper.SelectAllMediaItems( 0, false )

    local sel_item_lenght = SEL_ITEM and reaper.GetMediaItemInfo_Value(SEL_ITEM, "D_LENGTH")
    local sel_item_start = SEL_ITEM and reaper.GetMediaItemInfo_Value(SEL_ITEM, "D_POSITION")
    local sel_item_end = SEL_ITEM and sel_item_lenght + sel_item_start

    reaper.PreventUIRefresh(1)
    for j = 1, #GROUPS do
        for k = 1, #GROUPS[j] do
            if In_table(GROUPS[j], MOUSE_TR) then
                if RAZOR then Set_Razor_Data(GROUPS[j][k], RAZOR) end
                if SEL_ITEM then
                    for i = 1, reaper.CountTrackMediaItems(GROUPS[j][k]) do
                        local item_in_group = reaper.GetTrackMediaItem(GROUPS[j][k], i - 1)
                        local item_lenght = reaper.GetMediaItemInfo_Value(item_in_group, "D_LENGTH")
                        local item_start = reaper.GetMediaItemInfo_Value(item_in_group, "D_POSITION")
                        local item_end = item_lenght + item_start
                        if (item_start >= sel_item_start) and (item_start < sel_item_end) and (item_end <= sel_item_end) then
                            reaper.SetMediaItemSelected(item_in_group, true) -- SELECT ITEMS ONLY
                        end
                    end
                end
            end
        end
    end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

local old_state = reaper.GetProjectStateChangeCount(0)
local function Main()
    local changeCount = reaper.GetProjectStateChangeCount(0)
    if old_state ~= changeCount then
        Edit_groups()
        old_state = changeCount
    end
    reaper.defer(Main)
end

function DoAtExit()
    reaper.SetToggleCommandState(sectionID, cmdID, 0);
    reaper.RefreshToolbar2(sectionID, cmdID);
end

Fill_groups()
Main()
reaper.atexit(DoAtExit)
