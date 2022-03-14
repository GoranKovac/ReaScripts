--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])"):gsub("[\\|/]Modules", "")
local reaper, gfx = reaper, gfx
local VT_TB, TBH = {}, nil

local function GetMenuTBL(rprobj)
    local track_menu = {
        [1] = { name = "",                      fname = "" },
        [2] = { name = "Create New Variant",    fname = "CreateNew" },
        [3] = { name = "Duplicate Variant",     fname = "Duplicate" },
        [4] = { name = "Delete Variant",        fname = "Delete" },
        [5] = { name = "Clear Variant",         fname = "Clear" },
        [6] = { name = "Rename Variants",       fname = "Rename" },
        [7] = { name = "Link Track/Envelope",   fname = "SetLinkVal" },
        [8] = { name = "Show All Variants",     fname = "ShowAll" },
    }
    local lane_menu = {
        [1] = { name = "",                      fname = "" },
        [2] = { name = "Set as Comp : ",        fname = "SetCompLane" },
        [3] = { name = "Link Track/Envelope",   fname = "SetLinkVal" },
        [4] = { name = "Show All Variants",     fname = "ShowAll" },
    }

    local folder_menu = {
        [1] = { name = "",                      fname = "" }, -- NORMAL TRACK VERSIONS FOR FOLDER
        [2] = { name = "",                      fname = "" }, -- FOLDER VERSIONS FOR CHILDS
        [3] = { name = "Create New Variant",    fname = "CreateNewFolder" },
        [4] = { name = "Duplicate Variant",     fname = "DuplicateFolder" },
        [5] = { name = "Delete Variant",        fname = "DeleteFolder" },
        [6] = { name = "Clear Variant",         fname = "ClearFolder" },
        [7] = { name = "Rename Variants",       fname = "RenameFolder" },
        [8] = { name = "Link Track/Envelope",   fname = "SetLinkValFolder" },
    }
    -- if reaper.ValidatePtr(rprobj, "MediaTrack*") then
    --     if reaper.GetMediaTrackInfo_Value(rprobj, "I_FREEMODE") == 2 then
    --         --lane_mode = true
    --         track_menu[8].name = "!" .. track_menu[8].name
    --     end
    --     if reaper.GetMediaTrackInfo_Value(rprobj, "I_FOLDERDEPTH") ~= 1 then
    --         return track_menu
    --     elseif reaper.GetMediaTrackInfo_Value(rprobj, "I_FOLDERDEPTH") == 1 then
    --         return folder_menu
    --     end
    -- elseif reaper.ValidatePtr(rprobj, "TrackEnvelope*") then
    --     track_menu[7].name = GetLinkVal() == true and "!" .. track_menu[7].name or track_menu[7].name
    --     table.remove(track_menu, 8) -- REMOVE "ShowAll" KEY IF ENVELOPE
    --     return track_menu
    -- end
    return track_menu, lane_menu
end

local function MakeMenu(tbl)
    local menu_options, lane_options = GetMenuTBL(tbl.rprobj)
    local concat, main_name, lane_mode = "", "", nil
    if reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then
        if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FOLDERDEPTH") ~= 1 then
            main_name = "MAIN Virtual TR : "
            menu_options[7].name = GetLinkVal() == true and "!" .. menu_options[7].name or menu_options[7].name
            lane_options[3] = menu_options[7]
            if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 2 then
                lane_mode = true
                menu_options[8].name = "!" .. menu_options[8].name
            end
        -- elseif reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FOLDERDEPTH") == 1 then
        --     table.remove(menu_options, 8) -- REMOVE "ShowAll"
        --     main_name = "FOLDER Virtual TR : "
        end
    elseif reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then
        main_name = "MAIN Virtual ENV : "
        menu_options[7].name = GetLinkVal() == true and "!" .. menu_options[7].name or menu_options[7].name
        lane_mode = GetLinkVal() and true
        table.remove(menu_options, 8) -- REMOVE "ShowAll" KEY IF ENVELOPE
    end

    local versions= {}
    for i = 1, #tbl.info do
        versions[#versions+1] = i == tbl.idx  and "!" .. i .. " - ".. tbl.info[i].name or i .. " - " .. tbl.info[i].name
    end

    menu_options[1].name = ">" .. main_name .. tbl.info[tbl.idx].name .. "|" .. table.concat(versions, "|") .."|<|"
    lane_options[1] = menu_options[1]
    lane_options[2].name = tbl.comp_idx ~= 0 and "!" .. "Unset as Comp : " .. tbl.info[tbl.comp_idx].name or lane_options[2].name

    local final_menu = lane_mode == true and lane_options or menu_options
    for i = 1, #final_menu do
        concat = concat .. final_menu[i].name .. (i ~= #final_menu and "|" or "")
    end
    return concat, final_menu, lane_mode
end

local function CreateGFXWindow()
    local title = "supper_awesome_mega_menu"
    gfx.init( title, 0, 0, 0, 0, 0 )
    local hwnd = reaper.JS_Window_Find( title, true )
    if hwnd then
        reaper.JS_Window_Show( hwnd, "HIDE" )
    end
    gfx.x = gfx.mouse_x
    gfx.y = gfx.mouse_y
end

local function Update_tempo_map()
    if reaper.CountTempoTimeSigMarkers(0) then
        local retval, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, 0)
        reaper.SetTempoTimeSigMarker(0, 0, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo)
    end
    reaper.UpdateTimeline()
end

function Show_menu(rprobj, on_demand)
    local focused_tracks = GetSelectedTracksData(rprobj, on_demand) -- THIS ADDS NEW TRACKS TO VT_TB FOR ON DEMAND SCRIPT AND RETURNS TRACK SELECTION
    MouseInfo(VT_TB).last_menu_lane = MouseInfo(VT_TB).lane-- SET LAST LANE BEFORE MENU OPENED
    MouseInfo(VT_TB).last_menu_tr = MouseInfo(VT_TB).tr -- SET LAST TRACK BEFORE MENU OPENED
    CheckTrackLaneModeState(VT_TB[rprobj])
    CreateGFXWindow()
    reaper.PreventUIRefresh(1)

    local update_tempo = rprobj == reaper.GetMasterTrack(0) and true or false
    local tbl = rprobj == reaper.GetMasterTrack(0) and VT_TB[reaper.GetTrackEnvelopeByName( rprobj, "Tempo map" )] or VT_TB[rprobj]

    local concat_menu, menu_options, lane_mode = MakeMenu(tbl)
    local m_num = gfx.showmenu(concat_menu)
    if m_num == 0 then return end

    local linked_VT = GetLinkedTracksVT_INFO(focused_tracks, on_demand)
    for track in pairs(linked_VT) do UpdateInternalState(VT_TB[track]) end

    if m_num > #tbl.info then
        m_num = (m_num - #tbl.info) + 1
        reaper.Undo_BeginBlock2(0)
        if menu_options[m_num].fname == "SetLinkVal" or menu_options[m_num].fname == "SetCompLane" then
            _G[menu_options[m_num].fname](VT_TB[rprobj])
        end
        if menu_options[m_num].fname ~= "SetLinkVal" and menu_options[m_num].fname ~= "SetCompLane" then
            for track in pairs(linked_VT) do
                _G[menu_options[m_num].fname](VT_TB[track])
                StoreStateToDocument(VT_TB[track])
            end
        end
        reaper.Undo_EndBlock2(0, "VT: " .. menu_options[m_num].name, -1)
    else
        reaper.Undo_BeginBlock2(0)
        for track in pairs(linked_VT) do
            if not lane_mode then
                SwapVirtualTrack(VT_TB[track], m_num)
            else
                Lane_view(VT_TB[track], m_num)
            end
            StoreStateToDocument(VT_TB[track])
        end
        reaper.Undo_EndBlock2(0, "VT: Recall Version " .. m_num, -1)
    end

    SetUpdateDraw()
    reaper.JS_LICE_Clear(tbl.font_bm, 0x00000000)
    gfx.quit()

    reaper.PreventUIRefresh(-1)
    if update_tempo then Update_tempo_map() end
    reaper.UpdateArrange()
    UpdateChangeCount()
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
        lane_mode = math.floor(el.lane_mode)
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

local function GetItemLane(item)
    local y = reaper.GetMediaItemInfo_Value(item, 'F_FREEMODE_Y')
    local h = reaper.GetMediaItemInfo_Value(item, 'F_FREEMODE_H')
    return round(y / h) + 1
end

local function Get_Item_Chunk(item)
    local _, chunk = reaper.GetItemStateChunk(item, "", false)
    chunk = chunk:gsub("{.-}", "")
    chunk = chunk:gsub("SEL.-\n", "")
    return chunk
end

local function Get_Track_Items(track)
    local items_chunk = {}
    local num_items = reaper.CountTrackMediaItems(track)
    for i = 1, num_items, 1 do
        local item = reaper.GetTrackMediaItem(track, i - 1)
        local item_chunk = Get_Item_Chunk(item)
        items_chunk[#items_chunk + 1] = item_chunk
    end
    return items_chunk
end

local function Get_Track_Lane_Items(track)
    local lane_items_chunk = {}
    local num_items = reaper.CountTrackMediaItems(track)
    local total_lanes = round(1 / reaper.GetMediaItemInfo_Value(reaper.GetTrackMediaItem(track, 0), 'F_FREEMODE_H'))
    for i = 1, total_lanes do
        lane_items_chunk[i] = {}
        for j = 1, num_items do
            local item = reaper.GetTrackMediaItem(track, j - 1)
            if GetItemLane(item) == i then
                lane_items_chunk[i][#lane_items_chunk[i] + 1] = Get_Item_Chunk(item)
            end
        end
    end
    return lane_items_chunk
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
        local empty_item = reaper.AddMediaItemToTrack(tr)
        reaper.SetItemStateChunk(empty_item, data[i], false)
        new_items[#new_items + 1] = empty_item
    end
    return new_items
end

local function GetChunkTableForObject(track)
    if reaper.ValidatePtr(track, "MediaTrack*") then
        if reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 then
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
    for j = 1, #tbl.info do
        local lane_chunk = {}
        for i = 1, num_items do
            local item = reaper.GetTrackMediaItem(tbl.rprobj, i - 1)
            if GetItemLane(item) == j then
                local item_chunk = Get_Item_Chunk(item)
                lane_chunk[#lane_chunk + 1] = item_chunk
            end
        end
        local name = tbl.info[j].name
        tbl.info[j] = lane_chunk
        tbl.info[j].name = name
    end
    --StoreStateToDocument(tbl)
end

function UpdateInternalState(tbl)
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

local function SetInsertLaneChunk(tbl, lane)
    local retval, track_chunk = reaper.GetTrackStateChunk(tbl.rprobj, "", false)
    local lane_mask = 2^(lane-1)
    if not track_chunk:find("LANESOLO") then -- IF ANY LANE IS NOT SOLOED LANESOLO PART DOES NOT EXIST YET AND WE NEED TO INJECT IT
        local insert_pos = string.find(track_chunk, "\n") -- insert after first new line <TRACK in this case
        track_chunk = track_chunk:sub(1, insert_pos) .. string.format("LANESOLO %i 0", lane_mask .. "\n") ..track_chunk:sub(insert_pos + 1)
    else
        track_chunk = track_chunk:gsub("(LANESOLO )%d+", "%1" ..lane_mask)
    end
    reaper.SetTrackStateChunk(tbl.rprobj, track_chunk, false)
end

function Lane_view(tbl, lane)
    reaper.PreventUIRefresh(1)
    if GetLinkVal() and reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then
        SwapVirtualTrack(tbl, lane)
    elseif reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then
        SetInsertLaneChunk(tbl, lane)
    end
    tbl.idx = lane
    reaper.PreventUIRefresh(-1)
end

local function Get_Razor_Data(track)
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

local function Get_items_in_razor(item, time_Start, time_End, razor_lane)
    if not item then return end
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_len
    if GetItemLane(item) == razor_lane then
        if (time_Start < item_end and time_End > item_start) then
            return item
        end
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

local function Make_item_from_razor(tbl, item, time_Start, time_End)
    if not item then return end
    local item_chunk = Get_Item_Chunk(item)
    local new_item_start, new_item_lenght, new_item_offset = Razor_item_position(item, time_Start, time_End)
    local item_start_offset = tonumber(item_chunk:match("SOFFS (%S+)"))
    local item_play_rate = tonumber(item_chunk:match("PLAYRATE (%S+)"))
    local created_chunk = item_chunk:gsub("(POSITION) %S+", "%1 " .. new_item_start):gsub("(LENGTH) %S+", "%1 " .. new_item_lenght):gsub("(SOFFS) %S+", "%1 " .. item_start_offset + (new_item_offset * item_play_rate))
    --! IF NOT LANE MODE THEN RETURN CHUNK END
    --if tbl.lane_mode == 0 then return created_chunk end -- RETURN ONLY CHUNK IF WE ARE IN THE LANE MODE (ADD TO COMP CHUNK)
    local createdItem = reaper.AddMediaItemToTrack(tbl.rprobj)
    reaper.SetItemStateChunk(createdItem, created_chunk, false)
    reaper.SetMediaItemInfo_Value(createdItem, "F_FREEMODE_Y", (tbl.comp_idx - 1) / #tbl.info)
    reaper.SetMediaItemInfo_Value(createdItem, "F_FREEMODE_H", 1 / #tbl.info)
    reaper.SetMediaItemSelected(createdItem, true)
    reaper.Main_OnCommand(40930, 0) -- TRIM BEHIND ONLY WORKS ON SELECTED ITEMS
    reaper.SetMediaItemSelected(createdItem, false)
    return createdItem
end

local OLD_RAZOR_INFO
function Copy_area(tbl)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end -- PREVENT DOING THIS ON ENVELOPES
    if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 0 then return end -- PREVENT DOING THIS ON ENVELOPES
    local razor_info = Get_Razor_Data(tbl.rprobj)
    if not razor_info then return end
    if tbl.comp_idx == 0 or tbl.comp_idx == razor_info.razor_lane then return end -- PREVENT COPY ONTO ITSELF
    if table.concat(razor_info) ~= OLD_RAZOR_INFO then -- PREVENT DOING COPY IF RAZOR DATA HAS NOT CHANGED
        reaper.Undo_BeginBlock2(0)
        reaper.PreventUIRefresh(1)
        local current_razor_toggle_state = reaper.GetToggleCommandState(42421)
        if current_razor_toggle_state == 1 then reaper.Main_OnCommand(42421, 0) end -- TURN OFF ALWAYS TRIM BEHIND RAZORS (if enabled in project)
        ------------------------ HACK FOR COPY PASTE REMOVING EMPTY LANE
        local hack_item = reaper.AddMediaItemToTrack(tbl.rprobj)
        reaper.SetMediaItemInfo_Value(hack_item, "F_FREEMODE_Y", (tbl.comp_idx - 1) / #tbl.info)
        reaper.SetMediaItemInfo_Value(hack_item, "F_FREEMODE_H", 1 / #tbl.info)
        -----------------------------------------------------------------------
        local new_items = {}
        for i = 1, reaper.CountTrackMediaItems(tbl.rprobj) do
            local razor_item = Get_items_in_razor(reaper.GetTrackMediaItem(tbl.rprobj, i-1),razor_info[1], razor_info[2], razor_info.razor_lane)
            new_items[#new_items+1] = razor_item
        end
        for i = 1, #new_items do
            Make_item_from_razor(tbl, new_items[i], razor_info[1], razor_info[2])
        end
        if current_razor_toggle_state == 1 then reaper.Main_OnCommand(42421, 0) end -- TURN ON ALWAYS TRIM BEHIND RAZORS (if enabled in project)
        reaper.DeleteTrackMediaItem(tbl.rprobj, hack_item) -- REMOVE EMPTY ITEM CREATED TO HACK AROUND COPY PASTE DELETING EMPTY LANE
        reaper.PreventUIRefresh(-1)
        reaper.Undo_EndBlock2(0, "VT: " .. "COPY AREA TO COMP", -1)
        reaper.UpdateArrange()
        OLD_RAZOR_INFO = table.concat(razor_info)
    end
end

local function SetItemsInLanes(tbl)
    for i = 1, #tbl.info do
        local items = Create_item(tbl.rprobj, tbl.info[i])
        for j = 1, #items do
            reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_Y", ((i - 1) / #tbl.info))
            reaper.SetMediaItemInfo_Value(items[j], "F_FREEMODE_H", 1 / #tbl.info)
        end
    end
end

function CheckTrackLaneModeState(tbl, script_first_start)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end
    local current_state = reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE")
    if current_state == 2 and tbl.lane_mode ~= 2 then
        reaper.PreventUIRefresh(1)
        if not script_first_start then
            Clear(tbl)
            SetItemsInLanes(tbl)
        end
        Lane_view(tbl, tbl.idx)
        tbl.lane_mode = 2
        StoreStateToDocument(tbl)
        reaper.PreventUIRefresh(-1)
    end
end

--! add hack to prevent empty lanes from removing
function ShowAll(tbl)
    if not reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then return end
    local fimp = reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE")
    local toggle = fimp == 2 and 0 or 2
    tbl.lane_mode = toggle
    if fimp == 2 then StoreLaneData(tbl) end
    Clear(tbl)
    if toggle == 2 then
        SetItemsInLanes(tbl)
        reaper.SetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE", toggle)
        Lane_view(tbl, tbl.idx)
    elseif toggle == 0 then
        reaper.SetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE", toggle)
        tbl.comp_idx = 0 -- DISABLE COMPING
        reaper.gmem_write(1,1) -- DISABLE SWIPE DEFER
        Create_item(tbl.rprobj, tbl.info[tbl.idx])
    end
    reaper.UpdateTimeline()
end

local function CreateVTElements(direct)
    for track in pairs(TBH) do
        if not VT_TB[track] then
            local Element = Get_class_tbl()
            local tr_data, lane = GetChunkTableForObject(track)
            tr_data = lane and tr_data or {tr_data}
            for i = 1, #tr_data do tr_data[i].name = "Version - " .. i end
            VT_TB[track] = Element:new(track, tr_data, direct)
            Restore_From_PEXT(VT_TB[track])
            if lane then CheckTrackLaneModeState(VT_TB[track], true) end
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
        rprobj = GetMouseTrack_BR()
    elseif demand_mode == "track" then
        local sel_env = reaper.GetSelectedEnvelope( 0 )
        rprobj = sel_env and sel_env or reaper.GetSelectedTrack(0,0)
    end
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
    local same_envelopes = {}
    if reaper.ValidatePtr(MouseInfo(VT_TB).last_menu_tr, "TrackEnvelope*") then
        local m_retval, m_name = reaper.GetEnvelopeName(MouseInfo(VT_TB).last_menu_tr)
        for track in pairs(all_linked_tracks) do
            if reaper.ValidatePtr(track, "TrackEnvelope*") and VT_TB[track] then
                local env_retval, env_name = reaper.GetEnvelopeName(track)
                if m_name == env_name then
                    same_envelopes[track] = env_name
                end
            end
        end
    end
    if not GetLinkVal() then
        if reaper.ValidatePtr(MouseInfo(VT_TB).last_menu_tr, "TrackEnvelope*") then -- IF MOUSE TRACK IS UNDER ENVELPE GET ALL SAME ENVELOPES HERE
            return same_envelopes
        else
            return tracl_tbl
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

reaper.gmem_attach('Virtual_Tracks')
local swipe_script_id = reaper.AddRemoveReaScript(true, 0, script_folder .. "Virtual_track_Swipe.lua", true)
local swipe_script = reaper.NamedCommandLookup(swipe_script_id)
--SWIPE = true
function SetCompLane(tbl)
    tbl.comp_idx = tbl.comp_idx == 0 and MouseInfo(VT_TB).last_menu_lane or 0
    StoreStateToDocument(tbl)
    -- if SWIPE then
    --     if tbl.comp_idx ~= 0 then
    --         reaper.gmem_write(1,0)
    --         reaper.Main_OnCommand(swipe_script,0)
    --     else
    --         reaper.gmem_write(1,1)
    --     end
    -- end
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