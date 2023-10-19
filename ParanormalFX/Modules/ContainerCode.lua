--@noindex
--NoIndex: true
local r = reaper
local FX_DATA
CLIPBOARD = {}

function GetFx(guid)
    return FX_DATA[guid]
end

function GetParentContainerByGuid(tbl)
    return tbl.type == "ROOT" and tbl or GetFx(tbl.pid)
end

function CalcFxIDFromParrent(tbl, i)
    local parrent_container = GetParentContainerByGuid(tbl[i])
    local fx_id = CalcFxID(parrent_container, i + 1)
    return fx_id
end

function CalcFxID(tbl, idx)
    if tbl.type == "Container" then
        return 0x2000000 + tbl.ID + (tbl.DIFF * idx)
    elseif tbl.type == "ROOT" then
        return idx - 1
    end
end

local function IsChildOfContainer(parrent, target, parallel_guid)
    local parrent_guid = parrent.guid
    local found
    local dst = target
    while not found do
        if dst.type == "ROOT" then break end
        if dst.pid == parrent_guid then
            if parallel_guid then
                -- ALLOW MOVING ON PARENTS PARALLEL BUTTON (ADDING IT NEXT TO IT)
                if parallel_guid ~= parrent_guid then
                    found = parrent_guid
                    break
                else
                    dst = GetFx(dst.pid)
                end
            else
                found = parrent_guid
                break
            end
        else
            -- KEEP TRYING UNTIL ROOT IS FOUND
            dst = GetFx(dst.pid)
        end
    end
    return found
end

function GetPayload()
    local retval, dndtype, payload = r.ImGui_GetDragDropPayload(ctx)
    if retval then
        return dndtype, payload
    end
end

function IsChildOfParrent(tbl, i, parallel_guid, serial_insert_point)
    local dndtype, payload = GetPayload()
    if dndtype == "DND MOVE FX" then
        if payload ~= "" then
            if tbl[i].type == "ROOT" then return end
            local src_guid, src_i = payload:match("(.+),(.+)")
            local src_fx = GetFx(src_guid)
            -- DRAG STARTED WITH CONTAINER - DO NOT MOVE INTO ITS FX CHILDS
            if IsChildOfContainer(src_fx, tbl[i], parallel_guid) then
                return true
            end
            -- EXCLUDE SERIAL POINTS
            if not serial_insert_point then
                -- DRAG STARTED WITH FX - DO NOT MOVE ON PARRENT CONTAINER
                if IsChildOfContainer(tbl[i], src_fx, parallel_guid) then
                    return true
                end
            end
        end
    end
end

function IsOnSameParallelLane(tbl, i, parallel, serial_insert_point)
    --! ALLOW DRAG COPY
    if not parallel then return false end
    --! IGNORE IF DRAG COPY
    if CTRL_DRAG then return false end
    local dndtype, payload = GetPayload()
    if dndtype == "DND MOVE FX" then
        if payload ~= "" then
            local src_guid, src_i = payload:match("(.+),(.+)")
            local src_fx = GetFx(src_guid)
            if src_fx.ROW == tbl[i].ROW then
                --! ENSURE THAT ITS IN THE SAME PARRENT
                if tbl[i].pid == src_fx.pid then
                    return true
                end
            end
        end
    end
end

function IsSameSerialPos(tbl, i, serial_insert_point)
    --! ONLY SERIAL BUTTON
    if not serial_insert_point then return end
    --! IGNORE IF DRAG COPY
    if CTRL_DRAG then return false end
    local dndtype, payload = GetPayload()
    if dndtype == "DND MOVE FX" then
        if payload ~= "" then
            local src_guid, src_i = payload:match("(.+),(.+)")
            --! PREVIOUS BUTTON
            -- IS NEXT BUTTON OUR DRAG SOURCE
            if tbl[i + 1] and tbl[i + 1].guid == src_guid then
                -- MAKE SURE WE ARE TARGETING ONLY SERIAL LANE
                -- CHECK IF OUR SOURCE (+1) IS SERIAL BY CHECKING IS THE BUTTON AFTER NOT PARALLEL
                if tbl[i + 2] and tbl[i + 2].p == 0 or not tbl[i + 2] then
                    return true
                end
            end
            --! NEXT BUTTON, MAKE SURE ITS NOT PARALLEL
            if src_guid == tbl[i].guid and tbl[i].p == 0 then
                return true
            end
        end
    end
end

function IsOnSelfEncloseButton(tbl, i)
    --! IGNORE IF DRAG_COPY
    if CTRL_DRAG then return false end
    local dndtype, payload = GetPayload()
    if dndtype == "DND MOVE FX" then
        if payload ~= "" then
            local src_guid, src_i = payload:match("(.+),(.+)")
            if src_guid == tbl[i].guid then
                return true
            end
        end
    end
end

local function CheckIsFirstARA(tbl, i, parallel)
    if tbl[i + 1] and tbl[i + 1].exclude_ara then
        tbl[i].no_draw_s = true
        return true
    end
    if parallel then
        if tbl[i] and tbl[i].exclude_ara then
            tbl[i].no_draw_p = true
            return true
        end
    end
end

function ARA_Protection(tbl, i, parallel)
    if CheckIsFirstARA(tbl, i, parallel) then
        -- tbl[i].no_draw_s = true
        --tbl[i].no_draw_p = true
        return true
    end
    if DRAG_PREVIEW and DRAG_PREVIEW.is_ara then
        if tbl[i].type ~= "ROOT" then
            tbl[i].no_draw_s = true
            tbl[i].no_draw_p = true
            return true
        end
    end
end

function CreateContainerAndInsertFX(tbl, i, fx)
    -- ADD CONTAINER AT THE BEGINNING OF THE CHAIN TO MAKE IT EASIER TO INSERT THINGS
    --! CHECK ITS POSITION WITH BLACKLISTED FX (MELODYNE AND SIMILAR NEED TO BE IN SLOT 1 AND CANNOT BE IN CONTAINER)
    --! CREATE CONTAINER IN POSITION ABOVE BLACKLISTED FX
    local cont_insert_id = CalculateInsertContainerPosFromBlacklist()
    local cont_pos = r.TrackFX_AddByName(TRACK, "Container", false, cont_insert_id)
    -- r.TrackFX_AddByName(TRACK, "Container", false, -1000)

    -- SWAP PARALLEL DATA WITH TARGET (MAYBE FIRST IN LANE == 0 OR NEXT IN LANE == 1)
    r.TrackFX_SetNamedConfigParm(TRACK, 0x2000000 + cont_pos + 1, "parallel", tbl[i].p)
    UpdateFxData()

    -- ADD NEW FX TO IT
    --local cont_id = 0x2000000 +  1 + (r.TrackFX_GetCount(TRACK) + 1)
    local cont_id = 0x2000000 + cont_pos + 1 + (r.TrackFX_GetCount(TRACK) + 1)
    r.TrackFX_AddByName(TRACK, fx, false, cont_id)
    UpdateFxData()

    -- MOVE TARGET FX INTO IT
    local target_fx = GetFx(tbl[i].guid)
    local target_parrent = GetFx(tbl[i].pid)
    local target_id = CalcFxID(target_parrent, target_fx.IDX)
    -- MAKE TARGET FX PARALLEL INFO 0 SINCE IT WILL BE IN SERIAL
    r.TrackFX_SetNamedConfigParm(TRACK, target_id, "parallel", "0")
    r.TrackFX_CopyToTrack(TRACK, target_id, TRACK, cont_id, true)

    UpdateFxData()
    -- GET UPDATED PARRENT
    target_parrent = GetFx(tbl[i].pid)
    -- RECALCULATE ORIGINAL TARGET POS
    local original_pos = CalcFxID(target_parrent, i)
    -- MOVE CONTAINER TO ORIGINAL TARGET
    --r.TrackFX_CopyToTrack(TRACK, 0x2000000 + 1, TRACK, original_pos, true)
    r.TrackFX_CopyToTrack(TRACK, 0x2000000 + cont_pos + 1, TRACK, original_pos, true)
end

function MoveTargetsToNewContainer(tbl, i, src_guid, src_i)
    local source_parallel_info = tbl[i].p

    local src_fx
    local src_parrent

    local is_move = (not CTRL_DRAG) and true or false

    -- ENCLOSE RIGHT CLICK OPTION IS CALLED
    if src_guid then
        src_fx = GetFx(src_guid)
        src_parrent = GetFx(src_fx.pid)
        -- SWAP INFO WITH NEXT FX TO KEEP PLUGINS IN PLACE
        if is_move then CheckNextItemParallel(src_i, src_parrent) end
    end
    -- ADD CONTAINER AT THE BEGINNING OF THE CHAIN TO MAKE IT EASIER TO INSERT THINGS
    --! CHECK ITS POSITION WITH BLACKLISTED FX (MELODYNE AND SIMILAR NEED TO BE IN SLOT 1 AND CANNOT BE IN CONTAINER)
    --! CREATE CONTAINER IN POSITION ABOVE BLACKLISTED FX
    local cont_insert_id = CalculateInsertContainerPosFromBlacklist()

    local cont_pos = r.TrackFX_AddByName(TRACK, "Container", false, cont_insert_id)
    -- SWAP PARALLEL DATA WITH TARGET (MAYBE FIRST IN LANE == 0 OR NEXT IN LANE == 1)
    --r.TrackFX_SetNamedConfigParm(TRACK, 0x2000000 + 1, "parallel", source_parallel_info)
    r.TrackFX_SetNamedConfigParm(TRACK, 0x2000000 + cont_pos + 1, "parallel", source_parallel_info)

    UpdateFxData()
    --local cont_id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
    local cont_id = 0x2000000 + cont_pos + 1 + (r.TrackFX_GetCount(TRACK) + 1)

    -- ENCLOSE RIGHT CLICK OPTION IS CALLED
    if src_guid then
        src_fx = GetFx(src_guid)
        src_parrent = GetFx(src_fx.pid)
        local src_id = CalcFxID(src_parrent, src_fx.IDX)

        if is_move then
            -- IF MOVING MAKE SOURCE FX PARALLEL INFO 0 SINCE IT WILL BE IN SERIAL
            r.TrackFX_SetNamedConfigParm(TRACK, src_id, "parallel", "0")
            -- MOVE SOURCE FX INTO IT CONTAINER
            r.TrackFX_CopyToTrack(TRACK, src_id, TRACK, cont_id, true)
        else
            -- COPY SOURCE FX INTO IT CONTAINER
            r.TrackFX_CopyToTrack(TRACK, src_id, TRACK, cont_id, false)
            -- SET COPY PARRALEL INFO 0 SINCE IT WILL BE IN SERIAL
            r.TrackFX_SetNamedConfigParm(TRACK, cont_id, "parallel", "0")
        end
    end
    UpdateFxData()
    --cont_id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
    cont_id = 0x2000000 + cont_pos + 1 + (r.TrackFX_GetCount(TRACK) + 1)

    local target_fx = GetFx(tbl[i].guid)
    local target_parrent = GetFx(tbl[i].pid)
    local target_id = CalcFxID(target_parrent, target_fx.IDX)
    -- MAKE TARGET FX PARALLEL INFO 0 SINCE IT WILL BE IN SERIAL
    r.TrackFX_SetNamedConfigParm(TRACK, target_id, "parallel", "0")
    -- MOVE TARGET INTO CONTAINER
    r.TrackFX_CopyToTrack(TRACK, target_id, TRACK, cont_id, true)

    UpdateFxData()
    -- ORIGINAL FX POS
    local target_pos = i
    -- GET UPDATED PARRENTS
    target_parrent = GetFx(tbl[i].pid)

    -- ENCLOSE RIGHT CLICK OPTION IS CALLED
    if src_guid then
        src_parrent = GetFx(src_fx.pid)
        -- DETERMINE IF FX WAS BEFORE OR AFTER FOR OFFSET
        if src_parrent.guid == target_parrent.guid then
            if is_move then
                target_pos = src_i > i and i or i - 1
            else
                target_pos = i
            end
        else
            target_pos = i
        end
    end
    -- MOVE CONTAINER INTO TARGET POSITION
    local original_pos = CalcFxID(target_parrent, target_pos)
    --local original_pos = CalcFxID(target_parrent, i)
    -- MOVE CONTAINER TO ORIGINAL TARGET
    --r.TrackFX_CopyToTrack(TRACK, 0x2000000 + 1, TRACK, original_pos, true)
    r.TrackFX_CopyToTrack(TRACK, 0x2000000 + cont_pos + 1, TRACK, original_pos, true)
end

-- function CopyTargetsToNewContainer(track, tbl, i, src_guid, src_i)
--     local source_parallel_info = tbl[i].p

--     local src_fx
--     local src_parrent

--     local is_move = false

--     -- ENCLOSE RIGHT CLICK OPTION IS CALLED
--     if src_guid then
--         src_fx = GetFx(src_guid)
--         src_parrent = GetFx(src_fx.pid)
--         -- SWAP INFO WITH NEXT FX TO KEEP PLUGINS IN PLACE
--         if is_move then CheckNextItemParallel(src_i, src_parrent) end
--     end
--     -- ADD CONTAINER AT THE BEGINNING OF THE CHAIN TO MAKE IT EASIER TO INSERT THINGS
--     --! CHECK ITS POSITION WITH BLACKLISTED FX (MELODYNE AND SIMILAR NEED TO BE IN SLOT 1 AND CANNOT BE IN CONTAINER)
--     --! CREATE CONTAINER IN POSITION ABOVE BLACKLISTED FX
--     local cont_insert_id = CalculateInsertContainerPosFromBlacklist()

--     local cont_pos = r.TrackFX_AddByName(track, "Container", false, cont_insert_id)
--     -- SWAP PARALLEL DATA WITH TARGET (MAYBE FIRST IN LANE == 0 OR NEXT IN LANE == 1)
--     --r.TrackFX_SetNamedConfigParm(TRACK, 0x2000000 + 1, "parallel", source_parallel_info)
--     r.TrackFX_SetNamedConfigParm(track, 0x2000000 + cont_pos + 1, "parallel", source_parallel_info)

--     UpdateFxData()
--     --local cont_id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
--     local cont_id = 0x2000000 + cont_pos + 1 + (r.TrackFX_GetCount(track) + 1)

--     -- ENCLOSE RIGHT CLICK OPTION IS CALLED
--     if src_guid then
--         src_fx = GetFx(src_guid)
--         src_parrent = GetFx(src_fx.pid)
--         local src_id = CalcFxID(src_parrent, src_fx.IDX)


--         -- COPY SOURCE FX INTO IT CONTAINER
--         r.TrackFX_CopyToTrack(track, src_id, TRACK, cont_id, false)
--         -- SET COPY PARRALEL INFO 0 SINCE IT WILL BE IN SERIAL
--         r.TrackFX_SetNamedConfigParm(track, cont_id, "parallel", "0")
--     end
--     UpdateFxData()
--     --cont_id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
--     cont_id = 0x2000000 + cont_pos + 1 + (r.TrackFX_GetCount(track) + 1)

--     local target_fx = GetFx(tbl[i].guid)
--     local target_parrent = GetFx(tbl[i].pid)
--     local target_id = CalcFxID(target_parrent, target_fx.IDX)
--     -- MAKE TARGET FX PARALLEL INFO 0 SINCE IT WILL BE IN SERIAL
--     r.TrackFX_SetNamedConfigParm(TRACK, target_id, "parallel", "0")
--     -- MOVE TARGET INTO CONTAINER
--     r.TrackFX_CopyToTrack(TRACK, target_id, TRACK, cont_id, true)

--     UpdateFxData()
--     -- ORIGINAL FX POS
--     local target_pos = i
--     -- GET UPDATED PARRENTS
--     target_parrent = GetFx(tbl[i].pid)

--     -- ENCLOSE RIGHT CLICK OPTION IS CALLED
--     if src_guid then
--         src_parrent = GetFx(src_fx.pid)
--         -- DETERMINE IF FX WAS BEFORE OR AFTER FOR OFFSET
--         if src_parrent.guid == target_parrent.guid then
--             if is_move then
--                 target_pos = src_i > i and i or i - 1
--             else
--                 target_pos = i
--             end
--         else
--             target_pos = i
--         end
--     end
--     -- MOVE CONTAINER INTO TARGET POSITION
--     local original_pos = CalcFxID(target_parrent, target_pos)
--     --local original_pos = CalcFxID(target_parrent, i)
--     -- MOVE CONTAINER TO ORIGINAL TARGET
--     --r.TrackFX_CopyToTrack(TRACK, 0x2000000 + 1, TRACK, original_pos, true)
--     r.TrackFX_CopyToTrack(track, 0x2000000 + cont_pos + 1, track, original_pos, true)
-- end

local function IterateContainerUpdate(depth, track, container_id, parent_fx_count, previous_diff, container_guid)
    local c_ok, c_fx_count = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + container_id, "container_count")
    if not c_ok then return end
    local diff = depth == 0 and parent_fx_count + 1 or (parent_fx_count + 1) * previous_diff
    local child_guids = {}

    FX_DATA["insertpoint_0" .. container_guid] = {
        IDX = 1,
        name = "DUMMY",
        type = "INSERT_POINT",
        guid = "insertpoint_0" .. container_guid,
        pid = container_guid,
        ROW = 0,
    }

    local row = 1
    for i = 1, c_fx_count do
        local fx_id = container_id + diff * i
        local fx_guid = r.TrackFX_GetFXGUID(TRACK, 0x2000000 + fx_id)
        local _, fx_type = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "fx_type")
        local _, para = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "parallel")

        if i > 1 then row = para == "0" and row + 1 or row end

        FX_DATA[fx_guid] = {
            type = fx_type,
            IDX = i,
            pid = container_guid,
            guid = fx_guid,
            ROW = row
        }
        child_guids[#child_guids + 1] = { guid = fx_guid }
        if fx_type == "Container" then
            FX_DATA[fx_guid].depth = depth + 1
            FX_DATA[fx_guid].DIFF = diff * (c_fx_count + 1)
            FX_DATA[fx_guid].ID = fx_id
            IterateContainerUpdate(depth + 1, track, fx_id, c_fx_count, diff, fx_guid)
        end
    end
    return child_guids
end

function UpdateFxData()
    if not TRACK then return end
    FX_DATA = {}
    FX_DATA = {
        ["ROOT"] = {
            type = "ROOT",
            pid = "ROOT",
            guid = "ROOT",
            ROW = 0,
        }
    }
    local row = 1
    local total_fx_count = r.TrackFX_GetCount(TRACK)
    for i = 1, total_fx_count do
        local _, fx_type = r.TrackFX_GetNamedConfigParm(TRACK, i - 1, "fx_type")
        local _, para = r.TrackFX_GetNamedConfigParm(TRACK, i - 1, "parallel")
        local fx_guid = r.TrackFX_GetFXGUID(TRACK, i - 1)
        if i > 1 then row = para == "0" and row + 1 or row end

        FX_DATA[fx_guid] = {
            type = fx_type,
            IDX = i,
            pid = "ROOT",
            guid = fx_guid,
            ROW = row,
        }
        if fx_type == "Container" then
            FX_DATA[fx_guid].depth = 0
            FX_DATA[fx_guid].DIFF = (total_fx_count + 1)
            FX_DATA[fx_guid].ID = i
            IterateContainerUpdate(0, TRACK, i, total_fx_count, 0, fx_guid)
        end
    end
end

function CollectFxData()
    if not TRACK then return end
    UpdateFxData()
end

function UpdateClipboardInfo()
    if CLIPBOARD.cut then
        ClearExtState()
        CLIPBOARD = {}
        return
    end
    -- DONT RECALCULATE IF PASTING ON DIFFERENT TRACK
    if CLIPBOARD.track ~= TRACK then return end
    UpdateFxData()
    local updated = GetFx(CLIPBOARD.tbl[CLIPBOARD.i].guid)
    local parrent = GetFx(updated.pid)

    local item_id = CalcFxID(parrent, updated.IDX)
    CLIPBOARD.id = item_id
end

local old_copy_id

function ClipBoard()
    local x, y = r.ImGui_GetContentRegionMax(ctx)
    r.ImGui_SetCursorPos(ctx, 5, y - 30)
    -- NIFTY HACK FOR COMMENT BOX NOT OVERLAP UI BUTTONS
    if not r.ImGui_BeginChild(ctx, 'hack44', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)

    --r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 2)
    if r.HasExtState("PARANORMALFX2", "COPY_BUFFER") then
        local copy_id = r.GetExtState("PARANORMALFX2", "COPY_BUFFER_ID")
        if old_copy_id ~= copy_id then
            local stored = r.GetExtState("PARANORMALFX2", "COPY_BUFFER")
            if stored ~= nil then
                local storedTable = stringToTable(stored)
                if storedTable ~= nil then
                    CLIPBOARD = {
                        tbl = storedTable.tbl,
                        i = storedTable.i,
                        id = storedTable.fx_id,
                        guid = storedTable.guid,
                        cut = storedTable.cut,
                    }
                    for i = 1, r.CountTracks(0) do
                        local track = r.GetTrack(0, i - 1)
                        if storedTable.track_guid == r.GetTrackGUID(track) then
                            CLIPBOARD.track = track
                            break
                        end
                    end
                end
                old_copy_id = copy_id
            end
        end
    end

    -- if size > 0 then
    if CLIPBOARD.tbl then
        local size = CalculateItemWH({ name = CLIPBOARD.tbl[CLIPBOARD.i].name }) + 190
        if r.ImGui_BeginChild(ctx, "CLIPBOARD", size, def_btn_h + s_window_y, 1) then
            if r.HasExtState("PARANORMALFX2", "COPY_BUFFER") then
                if CLIPBOARD.tbl then
                    local rv, name = r.GetTrackName(CLIPBOARD.track)
                    r.ImGui_Text(ctx, "CLIPBOARD: " .. name .. " - FX: " .. CLIPBOARD.tbl[CLIPBOARD.i].name)
                end
            else
                r.ImGui_Text(ctx, "CLIPBOARD EMPTY ")
            end
            r.ImGui_EndChild(ctx)
        end
    end
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_EndChild(ctx)
end

function Paste(replace, parallel, serial, enclose)
    if not CLIPBOARD.tbl then return end
    --if CLIPBOARD.guid == RC_DATA.tbl[RC_DATA.i].guid then return end
    local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
    local item_id = CalcFxID(parrent_container, (parallel or serial) and RC_DATA.i + 1 or RC_DATA.i)
    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)
    --if enclose then
    --CopyTargetsToNewContainer(CLIPBOARD.track, RC_DATA.tbl, RC_DATA.i, CLIPBOARD.guid, CLIPBOARD.i)
    --else
    --end
    local is_cut = CLIPBOARD.cut and true or false
    if is_cut then
        local src_parrent = GetParentContainerByGuid(CLIPBOARD.tbl[CLIPBOARD.i])
        CheckNextItemParallel(CLIPBOARD.i, src_parrent)
        -- SET PARALLEL INFO BEFORE MOVING
        r.TrackFX_SetNamedConfigParm(TRACK, item_id, "parallel", RC_DATA.tbl[RC_DATA.i].p)
    end

    r.TrackFX_CopyToTrack(CLIPBOARD.track, CLIPBOARD.id, TRACK, item_id, is_cut)
    
    if not is_cut then
       r.TrackFX_SetNamedConfigParm(TRACK, item_id, "parallel", (serial and "0" or RC_DATA.tbl[RC_DATA.i].p))
    end
    
    if replace then
        UpdateFxData()
        local target_fx = GetFx(RC_DATA.tbl[RC_DATA.i].guid)
        local target_parrent = GetFx(target_fx.pid)
        --local del_id = CalcFxID(parrent_container, RC_DATA.i + 1)
        local del_id = CalcFxID(target_parrent, target_fx.IDX)
        r.TrackFX_Delete(TRACK, del_id)
    end

    if parallel and not is_cut then
       r.TrackFX_SetNamedConfigParm(TRACK, item_id, "parallel", 1)
    end

    r.PreventUIRefresh(-1)
    EndUndoBlock((is_cut and "CUT FX: " or "PASTE FX: ") .. RC_DATA.tbl[RC_DATA.i].name)
    UpdateClipboardInfo()
end

function Copy()
    local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
    local item_id = CalcFxID(parrent_container, RC_DATA.i)
    local data = tableToString(
        {
            tbl = RC_DATA.tbl,
            tbl_i = RC_DATA.i,
            track_guid = r.GetTrackGUID(TRACK),
            fx_id = item_id,
            guid = RC_DATA.tbl[RC_DATA.i].guid
        }
    )
    r.SetExtState("PARANORMALFX2", "COPY_BUFFER", data, false)
    r.SetExtState("PARANORMALFX2", "COPY_BUFFER_ID", r.genGuid(), false)
end