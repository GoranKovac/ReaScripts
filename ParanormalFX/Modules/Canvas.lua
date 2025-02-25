--@noindex
--NoIndex: true

local r = reaper
local ImGui = {}
for name, func in pairs(reaper) do
    name = name:match('^ImGui_(.+)$')
    if name then ImGui[name] = func end
end

local def_vertical_x_center, def_vertical_y_center = 50, 100

function InitCanvas()
    local init_x, init_y = 500, 100
    if not V_LAYOUT then
        init_x, init_y = 50, 250
    end
    return { view_x = 0, view_y = 0, off_x = init_x, off_y = init_y, scale = 1 }
end

function UpdateScroll()
    if not TARGET then return end
    local btn = ImGui.MouseButton_Right()
    if ImGui.IsMouseDragging(ctx, btn) then
        ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeAll())
        local drag_x, drag_y = ImGui.GetMouseDragDelta(ctx, nil, nil, btn)
        CANVAS.off_x, CANVAS.off_y = CANVAS.off_x + drag_x, CANVAS.off_y + drag_y
        ImGui.ResetMouseDragDelta(ctx, btn)
    end
end

ZOOM_MIN, ZOOM_MAX, ZOOM_SPEED = 0.2, 1, 1 / 8

function round(num) return (num + 0.5) // 1 end

function updateZoom()
    if not CTRL then return end
    local WX, WY = r.ImGui_GetWindowPos(ctx)
    local new_scale = CANVAS.scale + (r.ImGui_GetMouseWheel(ctx) * ZOOM_SPEED)
    new_scale = math.max(ZOOM_MIN, math.min(ZOOM_MAX, new_scale))

    if new_scale == CANVAS.scale then return end

    local scale_diff = (new_scale / CANVAS.scale)
    local mouse_x, mouse_y = r.ImGui_GetMousePos(ctx)
    mouse_x, mouse_y = (mouse_x - WX) - CANVAS.view_x - CANVAS.off_x,
        (mouse_y - WY) - CANVAS.view_y - CANVAS.off_y
    local diff_x, diff_y = mouse_x - (mouse_x * scale_diff),
        mouse_y - (mouse_y * scale_diff)
    CANVAS.off_x, CANVAS.off_y = (CANVAS.off_x + diff_x),
        (CANVAS.off_y + diff_y)
    CANVAS.scale = new_scale
end

function ResetView(force)
    if V_LAYOUT then
        if force then
            CANVAS.off_x = AW / 2
            CANVAS.off_y = def_vertical_y_center
        else
            FLUX.to(CANVAS, 0.5, { off_x = AW / 2, off_y = def_vertical_y_center * CANVAS.scale }):ease("cubicout")
        end
    else
        if force then
            CANVAS.off_x = def_vertical_x_center
            CANVAS.off_y = AH / 2
        else
            FLUX.to(CANVAS, 0.5, { off_x = def_vertical_x_center * CANVAS.scale, off_y = AH / 2 }):ease("cubicout")
        end
    end
end

local function CheckKeys()
    ALT = ImGui.GetKeyMods(ctx) == ImGui.Mod_Alt()
    CTRL = ImGui.GetKeyMods(ctx) == ImGui.Mod_Shortcut()
    SHIFT = ImGui.GetKeyMods(ctx) == ImGui.Mod_Shift()

    HOME = ImGui.IsKeyPressed(ctx, ImGui.Key_Home())
    SPACE = ImGui.IsKeyPressed(ctx, ImGui.Key_Space())
    ESC = ImGui.IsKeyPressed(ctx, ImGui.Key_Escape())

    Z = ImGui.IsKeyPressed(ctx, ImGui.Key_Z())
    C = ImGui.IsKeyPressed(ctx, ImGui.Key_C())
    B = ImGui.IsKeyPressed(ctx, ImGui.Key_B())

    DEL = ImGui.IsKeyPressed(ctx, ImGui.Key_Delete())

    if HOME then ResetView() end

    -- TOGGLE FX BYPASS
    if CTRL and B then
        if TARGET then
            for k, v in pairs(SEL_TBL) do   
                API.SetEnabled(TARGET, v.FX_ID, not API.GetEnabled(TARGET, v.FX_ID))
            end
        end
    end

    if DEL then
        if TARGET then
            r.PreventUIRefresh(-1)
            r.Undo_BeginBlock()
            for k in pairs(SEL_TBL) do
                UpdateFxData()
                local updated_fx = GetFx(k)
                if updated_fx then
                    local parrent_container = GetParentContainerByGuid(updated_fx)
                    local item_id = CalcFxID(parrent_container, updated_fx.IDX)
                    CheckNextItemParallel(updated_fx.IDX, parrent_container)
                    API.Delete(TARGET, item_id)
                end
            end
            SEL_TBL = {}
            ValidateClipboardFX()
            r.PreventUIRefresh(1)
            EndUndoBlock("DELETE SELECTED FX")
        end
    end

    if CTRL and Z then
        r.Main_OnCommand(40029, 0)
        -- CHECK IF TARGET CHANGED
        TRACK = r.GetSelectedTrack2(0, 0, true)
    end                            -- UNDO
    if ImGui.GetKeyMods(ctx) == ImGui.Mod_Shortcut() | ImGui.Mod_Shift() and Z then
        r.Main_OnCommand(40030, 0) -- REDO
    end

    if SPACE and (not FX_OPENED and not RENAME_OPENED and not FILE_MANAGER_OPENED) then r.Main_OnCommand(40044, 0) end -- PLAY STOP

    -- ACTIVATE CTRL ONLY IF NOT PREVIOUSLY DRAGGING
    if not CTRL_DRAG then
        CTRL_DRAG = (not MOUSE_DRAG and CTRL) and ImGui.IsMouseDragging(ctx, 0)
    end
    MOUSE_DRAG = ImGui.IsMouseDragging(ctx, 0)
end

local function Rename()
    if not RENAME_DATA then return end
    local tbl, i = RENAME_DATA.tbl, RENAME_DATA.i
    local RV
    if r.ImGui_IsWindowAppearing(ctx) then
        r.ImGui_SetKeyboardFocusHere(ctx)
        NEW_NAME = tbl[i].name:gsub("(%S+: )", "")
    end
    RV, NEW_NAME = r.ImGui_InputText(ctx, 'Name', NEW_NAME, r.ImGui_InputTextFlags_AutoSelectAll())
    COMMENT_ACTIVE = r.ImGui_IsItemActive(ctx)
    if r.ImGui_Button(ctx, 'OK') or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or
        r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
        NEW_NAME = NEW_NAME:gsub("^%s*(.-)%s*$", "%1") -- remove trailing and leading
        if #NEW_NAME ~= 0 then SAVED_NAME = NEW_NAME end
        if SAVED_NAME then
            local parrent_container = GetParentContainerByGuid(tbl[i])
            local item_id = CalcFxID(parrent_container, i)
            r.Undo_BeginBlock()
            API.SetNamedConfigParm(TARGET, item_id, "renamed_name", SAVED_NAME)
            EndUndoBlock("RENAME FX: " .. (RENAME_DATA.tbl[RENAME_DATA.i].name))
        end
        RENAME_DATA = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'Cancel') then
        RENAME_DATA = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        RENAME_DATA = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

local function InsertPointsMenu()
    if RC_DATA.lane == "p" then
        if r.ImGui_MenuItem(ctx, 'RESET LANE VOLUME') then
            local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
            local _, first_idx_in_row = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, -1)

            for i = first_idx_in_row, RC_DATA.i do
                local item_id = CalcFxID(parrent_container, i)
                API.SetParam(TARGET, item_id, RC_DATA.tbl[i].wetparam, 1)
            end
        end
        if RC_DATA.tbl[RC_DATA.i].p > 0 then
            if r.ImGui_MenuItem(ctx, 'ADJUST LANE VOLUME TO UNITY') then
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local _, first_idx_in_row, p_cnt = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, -1)

                for i = first_idx_in_row, RC_DATA.i do
                    local item_id = CalcFxID(parrent_container, i)
                    API.SetParam(TARGET, item_id, RC_DATA.tbl[i].wetparam, 1 / p_cnt)
                end
            end
            r.ImGui_Separator(ctx)
            if r.ImGui_MenuItem(ctx, 'UNBYPASS LANE') then
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local _, first_idx_in_row = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, -1)
                local _, last_idx_in_row = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, 1)

                for i = first_idx_in_row, last_idx_in_row do
                    local item_id = CalcFxID(parrent_container, i)
                    API.SetEnabled(TARGET, item_id, true)
                end
            end
            if r.ImGui_MenuItem(ctx, 'ENCLOSE LANE INTO CONTAINER') then
                r.Undo_BeginBlock()
                r.PreventUIRefresh(1)
                local parrent_container = GetFx(RC_DATA.tbl[RC_DATA.i].pid)

                local _, first_idx_in_row = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, -1)
                local _, last_idx_in_row = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, 1)

                local lane_tbl = {}
                for i = first_idx_in_row, last_idx_in_row do
                    local id = CalcFxID(parrent_container, i)
                    local fx_guid = API.GetFXGUID(TARGET, id)
                    if fx_guid then lane_tbl[#lane_tbl + 1] = fx_guid end
                end

                local cont_insert_id = CalculateInsertContainerPosFromBlacklist()
                local cont_pos = API.AddByName(TARGET, "Container", MODE == "ITEM" and cont_insert_id or false,
                    cont_insert_id)
                UpdateFxData()
                for i = #lane_tbl, 1, -1 do
                    local cont_id = 0x2000000 + cont_pos + 1 + (API.GetCount(TARGET) + 1)
                    parrent_container = GetFx(RC_DATA.tbl[RC_DATA.i].pid)
                    local child_id = GetFx(lane_tbl[i]).FX_ID
                    API.CopyToTrack(TARGET, child_id, TARGET, cont_id, true)
                    UpdateFxData()
                end
                UpdateFxData()
                parrent_container = GetFx(RC_DATA.tbl[RC_DATA.i].pid)
                local original_pos = CalcFxID(parrent_container, first_idx_in_row)
                -- MOVE CONTAINER TO ORIGINAL TARGET
                API.CopyToTrack(TARGET, 0x2000000 + cont_pos + 1, TARGET, original_pos, true)
                r.PreventUIRefresh(-1)
                EndUndoBlock("ENCLOSE PARALLEL LANE")
            end
        end
        -- SHOW ONLY WHEN CLIPBOARD IS AVAILABLE
        if CLIPBOARD.tbl then
            if r.ImGui_MenuItem(ctx, 'PASTE') then
                Paste(false, true)
            end
        end
    elseif RC_DATA.lane == "s" then
        if CLIPBOARD.tbl then
            if r.ImGui_MenuItem(ctx, 'PASTE') then
                Paste(false, false, true)
            end
        else
            r.ImGui_CloseCurrentPopup(ctx)
        end
    elseif RC_DATA.lane == "sc" then
        if CLIPBOARD.tbl then
            if r.ImGui_MenuItem(ctx, 'PASTE') then
                Paste(false, false, true, true)
            end
        else
            r.ImGui_CloseCurrentPopup(ctx)
        end
    end
end

local function RightClickMenu()
    local disabled
    if SEL_TBL[RC_DATA.tbl[RC_DATA.i].guid] ~= nil then
        disabled = HasMultiple(SEL_TBL)
    end
    if RC_DATA.type ~= "ROOT" then
        if r.ImGui_MenuItem(ctx, 'RENAME', nil, nil, not disabled) then
            RENAME_DATA = { tbl = RC_DATA.tbl, i = RC_DATA.i }
            OPEN_RENAME = true
        end

        if not RC_DATA.tbl[RC_DATA.i].exclude_ara then
            if r.ImGui_MenuItem(ctx, 'REPLACE', nil, nil, not disabled) then
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local item_add_id = CalcFxID(parrent_container, RC_DATA.i)
                REPLACE_FX_POS = { tbl = RC_DATA.tbl, i = RC_DATA.i, id = item_add_id }
                OPEN_FX_LIST = true
            end
            r.ImGui_Separator(ctx)
            if r.ImGui_MenuItem(ctx, 'ENCLOSE INTO CONTAINER', nil, nil, not disabled) then
                r.Undo_BeginBlock()
                r.PreventUIRefresh(1)
                MoveTargetsToNewContainer(RC_DATA.tbl, RC_DATA.i)
                r.PreventUIRefresh(-1)
                EndUndoBlock("MOVE FX AND ENCLOSE INTO CONTAINER")
            end
            if RC_DATA.type == "Container" then
                local can_explode = CheckIfSafeToExplode(RC_DATA.tbl, RC_DATA.i)
                local no_childs = #RC_DATA.tbl[RC_DATA.i].sub == 0
                if not can_explode or no_childs then r.ImGui_BeginDisabled(ctx, true) end
                if r.ImGui_MenuItem(ctx, can_explode and 'EXPLODE CONTAINER' or "EXPLODE (NOT SUPPORTED)", nil, nil, not disabled) then
                    ExplodeContainer(RC_DATA.tbl, RC_DATA.i)
                end
                if not can_explode or no_childs then r.ImGui_EndDisabled(ctx) end
                if r.ImGui_BeginMenu(ctx, "SURROUND MAPPING") then
                    local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                    local item_id = CalcFxID(parrent_container, RC_DATA.i)                   

                    if r.ImGui_MenuItem(ctx, "Quad - 4ch", nil) then
                        SetContainerSurround(item_id, 4)
                        SetChildSurround(RC_DATA.tbl[RC_DATA.i].sub, 4)
                    end
                    if r.ImGui_MenuItem(ctx, "5.1 - 6ch", nil) then
                        SetContainerSurround(item_id, 6)
                        SetChildSurround(RC_DATA.tbl[RC_DATA.i].sub, 6)
                    end
                    if r.ImGui_MenuItem(ctx, "7.1 - 8ch", nil) then
                        SetContainerSurround(item_id, 8)
                        SetChildSurround(RC_DATA.tbl[RC_DATA.i].sub, 8)
                    end
                    if r.ImGui_MenuItem(ctx, "7.1.4 - 12ch", nil) then
                        SetContainerSurround(item_id, 12)
                        SetChildSurround(RC_DATA.tbl[RC_DATA.i].sub, 12)
                    end
                    r.ImGui_EndMenu(ctx)
                end
            end
        end
        r.ImGui_Separator(ctx)

        if r.ImGui_BeginMenu(ctx, "FX SETTINGS", not disabled) then
            if r.ImGui_BeginMenu(ctx, "OVERSAMPLING") then
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local item_id = CalcFxID(parrent_container, RC_DATA.i)
                local retval1, buf1 = API.GetNamedConfigParm(TARGET, item_id, "chain_oversample_shift")
                local retval2, buf2 = API.GetNamedConfigParm(TARGET, item_id, "instance_oversample_shift")

                for i = 1, 2 do
                    if r.ImGui_BeginMenu(ctx, i == 1 and "CHAIN" or "INSTANCE") then
                        for j = 0, 2 do
                            local name = j == 0 and "NONE" or j == 1 and "96kHz" or "192kHz"
                            if r.ImGui_MenuItem(ctx, name, nil, (i == 1 and buf1 or buf2) == tostring(j)) then
                                API.SetNamedConfigParm(TARGET, item_id,
                                    i == 1 and "chain_oversample_shift" or "instance_oversample_shift", tostring(j))
                            end
                        end
                        r.ImGui_EndMenu(ctx)
                    end
                end
                r.ImGui_EndMenu(ctx)
            end
            local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
            local item_id = CalcFxID(parrent_container, RC_DATA.i)
            local retval, buf = API.GetNamedConfigParm(TARGET, item_id, "force_auto_bypass")
            if r.ImGui_MenuItem(ctx, "AUTO BYPASS ON SILENCE", nil, buf == "1" and true or false) then
                API.SetNamedConfigParm(TARGET, item_id, "force_auto_bypass", buf == "0" and "1" or "0")
            end
            r.ImGui_EndMenu(ctx)
        end
        r.ImGui_Separator(ctx)
    end

    if r.ImGui_MenuItem(ctx, 'DELETE') then
        if SEL_TBL[RC_DATA.tbl[RC_DATA.i].guid] then
            if next(SEL_TBL) then
                r.Undo_BeginBlock()
                r.PreventUIRefresh(1)
                for k in pairs(SEL_TBL) do
                    UpdateFxData()
                    local updated_fx = GetFx(k)
                    local parrent_container_sel = GetParentContainerByGuid(updated_fx)
                    local item_id_sel = CalcFxID(parrent_container_sel, updated_fx.IDX)
                    CheckNextItemParallel(updated_fx.IDX, parrent_container_sel)
                    API.Delete(TARGET, item_id_sel)
                end
                r.PreventUIRefresh(-1)

                EndUndoBlock("DELETE SELECTED FX")
                SEL_TBL = {}
            end

        else
            if RC_DATA.type == "ROOT" then
                RemoveAllFX()
            else
                r.PreventUIRefresh(1)
                r.Undo_BeginBlock()
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local item_id = CalcFxID(parrent_container, RC_DATA.i)
                CheckNextItemParallel(RC_DATA.i, parrent_container)
                API.Delete(TARGET, item_id)
                EndUndoBlock("DELETE FX:" .. RC_DATA.tbl[RC_DATA.i].name)
                r.PreventUIRefresh(-1)
            end
        end
        ValidateClipboardFX()
    end
    if RC_DATA.type == "ROOT" or RC_DATA.type == "Container" then
        r.ImGui_Separator(ctx)
        if r.ImGui_MenuItem(ctx, 'SAVE AS CHAIN', nil, nil, not disabled) then
            --SAVE_NAME = RC_DATA.tbl[RC_DATA.i].name
            OPEN_FM = true
            FM_TYPE = "SAVE"
            local pre_name = RC_DATA.type == "Container" and RC_DATA.tbl[RC_DATA.i].name or nil
            Init_FM_database(pre_name)
            if RC_DATA.type == "ROOT" then
                CreateFxChain()
            else
                CreateFxChain(RC_DATA.tbl[RC_DATA.i].guid)
            end
        end
    end
    if RC_DATA.type ~= "ROOT" and not RC_DATA.tbl[RC_DATA.i].exclude_ara then
        r.ImGui_Separator(ctx)
        if r.ImGui_MenuItem(ctx, 'COPY', nil, nil, not disabled) then
            local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
            local item_id = CalcFxID(parrent_container, RC_DATA.i)
            local is_collapsed = CheckCollapse(RC_DATA.tbl[RC_DATA.i], 1, 1)
            local take_guid
            if MODE == "ITEM" then
                _, take_guid = r.GetSetMediaItemTakeInfo_String(TARGET, "GUID", "", false)
            end
            local data = tableToString(
                {
                    tbl = RC_DATA.tbl,
                    i = RC_DATA.i,
                    track_guid = r.GetTrackGUID(TRACK),
                    take_guid = take_guid,
                    fx_id = item_id,
                    guid = RC_DATA.tbl[RC_DATA.i].guid,
                    collapsed = is_collapsed,
                    type = RC_DATA.tbl[RC_DATA.i].type
                }
            )
            r.SetExtState("PARANORMALFX2", "COPY_BUFFER", data, false)
            r.SetExtState("PARANORMALFX2", "COPY_BUFFER_ID", r.genGuid(), false)
        end
        if r.ImGui_MenuItem(ctx, 'CUT', nil, nil, not disabled) then
            local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
            local item_id = CalcFxID(parrent_container, RC_DATA.i)
            local is_collapsed = CheckCollapse(RC_DATA.tbl[RC_DATA.i], 1, 1)
            local take_guid
            if MODE == "ITEM" then
                _, take_guid = r.GetSetMediaItemTakeInfo_String(TARGET, "GUID", "", false)
            end
            local data = tableToString(
                {
                    tbl = RC_DATA.tbl,
                    i = RC_DATA.i,
                    track_guid = r.GetTrackGUID(TRACK),
                    take_guid = take_guid,
                    fx_id = item_id,
                    guid = RC_DATA.tbl[RC_DATA.i].guid,
                    cut = true,
                    parrent_DIFF = parrent_container.DIFF,
                    parrent_ID = parrent_container.ID,
                    parrent_TYPE = parrent_container.type,
                    collapsed = is_collapsed,
                    type = RC_DATA.tbl[RC_DATA.i].type
                }
            )
            r.SetExtState("PARANORMALFX2", "COPY_BUFFER", data, false)
            r.SetExtState("PARANORMALFX2", "COPY_BUFFER_ID", r.genGuid(), false)
        end

        -- SHOW ONLY WHEN CLIPBOARD IS AVAILABLE
        if CLIPBOARD.tbl and CLIPBOARD.guid ~= RC_DATA.tbl[RC_DATA.i].guid then
            --! DO NOT ALLOW PASTING ON SELF
            if r.ImGui_MenuItem(ctx, 'PASTE-REPLACE', nil, nil, not disabled) then
                Paste(true, RC_DATA.tbl[RC_DATA.i].p > 0, RC_DATA.tbl[RC_DATA.i].p == 0)
            end
        end
    end
end
local ACS_TBL = { "active", "dir", "strength", "attack", "release", "dblo", "dbhi", "x2", "y2", }
local ACS_defaults = { 0, 1, 1, 300, 300, -24, 0, 0.5, 0.5 }

local LFO_TBL = { "active", "dir", "phase", "speed", "strength", "temposync", "free", "shape" }
local LFO_defaults = { 0, 1, 0, 1, 1, 0, 0, 0 }

local function PMMenu()
    if not PM_RC_DATA then return end
    if PM_RC_DATA.type == "ACS" then
        if r.ImGui_MenuItem(ctx, "RESET TO ACS DEFAULT") then
            for i = 1, #ACS_TBL do
                API.SetNamedConfigParm(TARGET, PM_RC_DATA.fx_id,
                    "param." .. PM_RC_DATA.p_id .. ".acs." .. ACS_TBL[i],
                    ACS_defaults[i])
            end
        end
    elseif PM_RC_DATA.type == "LFO" then
        if r.ImGui_MenuItem(ctx, "RESET TO LFO DEFAULT") then
            for i = 1, #LFO_TBL do
                API.SetNamedConfigParm(TARGET, PM_RC_DATA.fx_id,
                    "param." .. PM_RC_DATA.p_id .. ".lfo." .. LFO_TBL[i],
                    LFO_defaults[i])
            end
        end
    elseif PM_RC_DATA.type == "ENV" then
        if r.ImGui_MenuItem(ctx, "DELETE ENVELOPE") then
            r.SetCursorContext(2, PM_RC_DATA.fx_id)
            r.Main_OnCommand(40065, 0)
            r.SetCursorContext(2)
        end
    end
end

local function Popups()
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }

    if OPEN_PM_MENU then
        OPEN_PM_MENU = nil
        if not r.ImGui_IsPopupOpen(ctx, "PM_MENU") then
            r.ImGui_OpenPopup(ctx, "PM_MENU")
        end
    end

    if r.ImGui_BeginPopup(ctx, "PM_MENU", r.ImGui_WindowFlags_NoMove()) then
        PMMenu()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_INSERT_POINTS_MENU then
        OPEN_INSERT_POINTS_MENU = nil
        if not r.ImGui_IsPopupOpen(ctx, "INSERT_POINTS_MENU") then
            r.ImGui_OpenPopup(ctx, "INSERT_POINTS_MENU")
        end
    end

    if r.ImGui_BeginPopup(ctx, "INSERT_POINTS_MENU", r.ImGui_WindowFlags_NoMove()) then
        InsertPointsMenu()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_RIGHT_CLICK_MENU then
        OPEN_RIGHT_CLICK_MENU = nil
        if not r.ImGui_IsPopupOpen(ctx, "RIGHT_CLICK_MENU") then
            r.ImGui_OpenPopup(ctx, "RIGHT_CLICK_MENU")
        end
    end

    if r.ImGui_BeginPopup(ctx, "RIGHT_CLICK_MENU", r.ImGui_WindowFlags_NoMove()) then
        RightClickMenu()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_RENAME then
        OPEN_RENAME = nil
        if not r.ImGui_IsPopupOpen(ctx, "RENAME") then
            r.ImGui_OpenPopup(ctx, 'RENAME')
            local mx, my = r.ImGui_GetMousePos(ctx)
            r.ImGui_SetNextWindowPos(ctx, mx - 100, my)
        end
    end

    if r.ImGui_BeginPopupModal(ctx, 'RENAME', nil,
            r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_TopMost()) then
        Rename()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_FM then
        OPEN_FM = nil
        if not r.ImGui_IsPopupOpen(ctx, "File Dialog") then
            r.ImGui_OpenPopup(ctx, 'File Dialog')
        end
    end
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 400, 300, FLT_MAX, FLT_MAX)
    if r.ImGui_BeginPopupModal(ctx, 'File Dialog', true, r.ImGui_WindowFlags_TopMost() | r.ImGui_WindowFlags_NoScrollbar()) then
        File_dialog()
        FM_Modal_POPUP()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_FX_LIST then
        OPEN_FX_LIST = nil
        if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
            r.ImGui_OpenPopup(ctx, "FX LIST")
        end
    end

    if r.ImGui_BeginPopup(ctx, "FX LIST", r.ImGui_WindowFlags_NoMove()) then
        --r.ImGui_PushFont(ctx, SELECTED_FONT)
        DrawFXList()
        --r.ImGui_PopFont(ctx)
        r.ImGui_EndPopup(ctx)
    end

    if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
        if #FILTER ~= 0 then FILTER = '' end
        if INSERT_FX_SERIAL_POS then INSERT_FX_PARALLEL_POS = nil end
        if INSERT_FX_PARALLEL_POS then INSERT_FX_PARALLEL_POS = nil end
        if INSERT_FX_ENCLOSE_POS then INSERT_FX_ENCLOSE_POS = nil end
        if REPLACE_FX_POS then REPLACE_FX_POS = nil end
        if CLICKED then CLICKED = nil end
    end

    if not r.ImGui_IsPopupOpen(ctx, "RIGHT_CLICK_MENU") and
        not r.ImGui_IsPopupOpen(ctx, "INSERT_POINTS_MENU") then
        if RC_DATA then RC_DATA = nil end
    end

    if not r.ImGui_IsPopupOpen(ctx, "PM_MENU") then
        if PM_RC_DATA then PM_RC_DATA = nil end
    end
end

local function StoreSettings()
    local COLOR = GetColorTbl()
    local data = tableToString(
        {
            v_layout = V_LAYOUT,
            zoom_max = ZOOM_MAX,
            show_c_content_tooltips = SHOW_C_CONTENT_TOOLTIP,
            tooltips = TOOLTIPS,
            animated_highlight = ANIMATED_HIGLIGHT,
            ctrl_autocontainer = CTRL_DRAG_AUTOCONTAINER,
            esc_close = ESC_CLOSE,
            custom_font = CUSTOM_FONT,
            auto_color = AUTO_COLORING,
            spacing = new_spacing_y,
            add_btn_h = ADD_BTN_H,
            add_btn_w = ADD_BTN_W,
            wirethickness = WireThickness,
            wire_color = COLOR["wire"],
            fx_color = COLOR["n"],
            container_color = COLOR["Container"],
            parallel_color = COLOR["parallel"],
            knobvol_color = COLOR["knob_vol"],
            drywet_color = COLOR["knob_drywet"],
            bypass_color = COLOR["bypass"],
            offline_color = COLOR["offline"],
            anim_color = COLOR["sine_anim"],
            background = COLOR["bg"],
            center_reset = CENTER_RESET,
        }
    )
    r.SetExtState("PARANORMALFX2", "SETTINGS", data, true)
end

local function SettingsTooltips(str)
    if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0xFF)
        r.ImGui_PushFont(ctx, CUSTOM_FONT and SYSTEM_FONT_FACTORY or DEFAULT_FONT_FACTORY)
        if r.ImGui_BeginTooltip(ctx) then
            r.ImGui_Text(ctx, str)
            r.ImGui_EndTooltip(ctx)
        end
        r.ImGui_PopFont(ctx)
        r.ImGui_PopStyleColor(ctx)
    end
end

local function DefaultHorizontal()
    --LAST_V_BTN_W = ADD_BTN_W
    --LAST_V_BTN_H = ADD_BTN_H
    --LAST_NEW_Y = new_spacing_y
    --ADD_BTN_W = 22
    ADD_BTN_H = 22
end

local function RevertVertical()
    --ADD_BTN_W = LAST_V_BTN_W
    --ADD_BTN_H = LAST_V_BTN_H
    -- new_spacing_y = LAST_NEW_Y
    --LAST_V_BTN_W, LAST_V_BTN_H, LAST_NEW_Y = nil, nil, nil
end

--PEAK_TBL = { ptr = 0, size = 0, max_size = 25 }

--local ACS_TBL = { "active", "dir", "strength", "attack", "release", "dblo", "dbhi", "x2", "y2", }

local function DNDACS_SRC(p_id)
    if not PM_INSPECTOR_FXID then return end
    --param.X.acs.[active,dir,strength,attack,release,dblo,dbhi,chan,stereo,x2,y2] : parameter modulation ACS state
    if r.ImGui_BeginDragDropSource(ctx) then
        local data = {}
        for i = 1, #ACS_TBL do
            local _, buf = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID,
                "param." .. p_id .. ".acs." .. ACS_TBL[i])
            data[i] = buf
        end
        r.ImGui_Text(ctx, "COPY ACS")
        r.ImGui_SetDragDropPayload(ctx, 'DND ACS', table.concat(data, ","))
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function DNDACS_TARGET(p_id)
    if not PM_INSPECTOR_FXID then return end
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND ACS')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local data = {}
            for val in payload:gmatch('([^,]+)') do
                data[#data + 1] = val
            end
            if #data ~= 0 then
                r.Undo_BeginBlock()

                for i = 1, #ACS_TBL do
                    API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs." .. ACS_TBL[i],
                        data[i])
                end
                EndUndoBlock("ACS COPY SETTINGS")
            end
        end
    end
end

-- local LFO_TBL = { "active", "dir", "phase", "speed", "strength", "temposync", "free", "shape" }
local function DNDLFO_SRC(p_id)
    if not PM_INSPECTOR_FXID then return end
    --param.X.lfo.[active,dir,phase,speed,strength,temposync,free,shape] : parameter moduation LFO state
    if r.ImGui_BeginDragDropSource(ctx) then
        local data = {}
        for i = 1, #LFO_TBL do
            local _, buf = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID,
                "param." .. p_id .. ".lfo." .. LFO_TBL[i])
            data[i] = buf
        end
        r.ImGui_Text(ctx, "COPY LFO")
        r.ImGui_SetDragDropPayload(ctx, 'DND LFO', table.concat(data, ","))
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function DNDLFO_TARGET(p_id)
    if not PM_INSPECTOR_FXID then return end
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND LFO')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local data = {}
            for val in payload:gmatch('([^,]+)') do
                data[#data + 1] = val
            end
            if #data ~= 0 then
                r.Undo_BeginBlock()
                for i = 1, #LFO_TBL do
                    API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo." .. LFO_TBL[i],
                        data[i])
                end
                EndUndoBlock("LFO COPY SETTINGS")
            end
        end
    end
end

local tbl_flags = ImGui.TableFlags_SizingFixedFit()| ImGui.TableFlags_Borders() | ImGui.TableFlags_SizingFixedFit()
local function PMTable()
    if not PM_INSPECTOR_FXID then return end
    local columns = 6
    if ImGui.BeginTable(ctx, 'ALL_PARAMETERS', columns, tbl_flags) then
        ImGui.TableSetupColumn(ctx, 'PARAMETER', r.ImGui_TableColumnFlags_WidthStretch())
        ImGui.TableSetupColumn(ctx, 'PMD')
        ImGui.TableSetupColumn(ctx, 'ACS')
        ImGui.TableSetupColumn(ctx, 'LFO')
        ImGui.TableSetupColumn(ctx, 'SHAPE')
        ImGui.TableSetupColumn(ctx, 'ENV')
        --ImGui.TableSetupColumn(ctx, 'LINK')

        --ImGui.TableSetupColumn(ctx, 'INP')
        --ImGui.TableSetupColumn(ctx, 'TYP')
        ImGui.TableHeadersRow(ctx)
        for p_id = 0, API.GetNumParams(TARGET, PM_INSPECTOR_FXID) do
            local _, p_name = API.GetParamName(TARGET, PM_INSPECTOR_FXID, p_id)
            local _, mod = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active")
            local _, mod_vis = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.visible")
            local _, acs = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active")
            local _, lfo = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active")
            local _, lfo_speed = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.speed")
            local _, lfo_shape = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.shape")
            local _, lfo_temposync = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID,
                "param." .. p_id .. ".lfo.temposync")
            local _, plink = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".plink.active")
            local fx_env = API.GetFXEnvelope(TARGET, PM_INSPECTOR_FXID, p_id, false)
            local has_points = (fx_env and r.CountEnvelopePoints(fx_env) > 2)
            if mod == "1" or acs == "1" or lfo == "1" or has_points then
                ImGui.TableNextRow(ctx)
                for column = 0, columns - 1 do
                    ImGui.TableSetColumnIndex(ctx, column)
                    if column == 0 then
                        r.ImGui_PushID(ctx, PM_INSPECTOR_FXID .. p_id .. "PM_ACTIVE")
                        if ALT then
                            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0xBB2222FF)
                            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), 0xDD2222FF)
                        end
                        if r.ImGui_Button(ctx, p_name, -FLT_MIN, 0.0) then
                            if ALT then
                                r.Undo_BeginBlock()
                                API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active",
                                    "0")
                                API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active",
                                    "0")
                                API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active",
                                    "0")
                                EndUndoBlock("PARAMETER MODULATION UNSET FX ALL PARAMETERS")
                            else
                                API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.visible",
                                    mod_vis == "0" and "1" or "0")
                            end
                        end
                        if ALT then
                            r.ImGui_PopStyleColor(ctx, 2)
                        end
                        r.ImGui_PopID(ctx)
                    elseif column == 1 then
                        if r.ImGui_Checkbox(ctx, "##PM" .. PM_INSPECTOR_FXID .. p_id, mod == "1") then
                            API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active",
                                mod == "0" and "1" or "0")
                        end
                    elseif column == 2 then
                        if r.ImGui_Checkbox(ctx, "##ACS" .. PM_INSPECTOR_FXID .. p_id, acs == "1") then
                            API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active",
                                acs == "0" and "1" or "0")
                            local _, acs_ch = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID,
                                "param." .. p_id .. ".acs.chan")
                            --! IF NO CHANNELS HAVE BEEN ASSIGNED SET DEFAULT TO 1/2
                            if acs_ch == "-1" then
                                API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.chan",
                                    "2")
                            end
                        end
                        DNDACS_SRC(p_id)
                        DNDACS_TARGET(p_id)
                        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 1) then
                            PM_RC_DATA = {
                                type = "ACS",
                                p_id = p_id,
                                fx_id = PM_INSPECTOR_FXID,
                            }
                            OPEN_PM_MENU = true
                        end
                    elseif column == 3 then
                        if r.ImGui_Checkbox(ctx, "##LFO" .. PM_INSPECTOR_FXID .. p_id, lfo == "1") then
                            API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active",
                                lfo == "0" and "1" or "0")
                        end
                        DNDLFO_SRC(p_id)
                        DNDLFO_TARGET(p_id)
                        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 1) then
                            PM_RC_DATA = {
                                type = "LFO",
                                p_id = p_id,
                                fx_id = PM_INSPECTOR_FXID,
                            }
                            OPEN_PM_MENU = true
                        end
                    elseif column == 4 then
                        local xx, yy = r.ImGui_GetCursorScreenPos(ctx)
                        local aw = r.ImGui_GetContentRegionAvail(ctx)
                        if lfo_temposync == "1" then
                            lfo_speed = 1 / r.TimeMap_QNToTime(tonumber(lfo_speed))
                        end
                        local x_speed = ReaperPhase(tonumber(lfo_speed))
                        local points, y_pos = GetWaveType(tonumber(lfo_shape), x_speed, xx, yy, aw, (21 - 2))
                        if y_pos and lfo == "1" then
                            if lfo_shape ~= "0" then
                                for i = 1, #points do
                                    r.ImGui_DrawList_AddLine(draw_list, xx + points[i][1], yy + points[i][2],
                                        xx + points[i][3], yy + points[i][4], 0xFFFFFF88)
                                end
                            else
                                r.ImGui_DrawList_AddPolyline(draw_list, points, 0xFFFFFF88, 0, 1)
                            end
                            r.ImGui_DrawList_AddCircleFilled(draw_list, xx + (x_speed * aw), yy + y_pos + 10, 2.5,
                                0xFF0000FF)
                        end
                    elseif column == 5 then
                        local retval, env_chunk, is_visible
                        if fx_env then
                            retval, env_chunk = r.GetEnvelopeStateChunk(fx_env, "", true)
                            is_visible = env_chunk:find("VIS 1", nil, true) and true or false
                        end
                        if has_points then
                            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x49cc8588)
                        end
                        if r.ImGui_Checkbox(ctx, "##ENV_new" .. PM_INSPECTOR_FXID .. p_id, is_visible) then
                            API.GetFXEnvelope(TARGET, PM_INSPECTOR_FXID, p_id, true)
                            if env_chunk then
                                local vis = env_chunk:match("VIS (%d+)")
                                if vis == "1" then
                                    env_chunk = env_chunk:gsub("VIS 1", "VIS 0", 1)
                                    r.SetCursorContext(2, fx_env)
                                elseif vis == "0" then --and not enabled_previously then
                                    env_chunk = env_chunk:gsub("VIS 0", "VIS 1", 1)
                                end
                                r.SetEnvelopeStateChunk(fx_env, env_chunk, false)
                            end
                            --r.TrackList_AdjustWindows(false)
                        end
                        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 1) and env_chunk then
                            PM_RC_DATA = {
                                type = "ENV",
                                p_id = p_id,
                                fx_id = fx_env,
                            }
                            OPEN_PM_MENU = true
                        end
                        if has_points then
                            r.ImGui_PopStyleColor(ctx)
                        end
                        -- elseif column == 5 then
                        --     if r.ImGui_Checkbox(ctx, "##PLINK" .. PM_INSPECTOR_FXID .. p_id, plink == "1") then
                        --         if plink == "1" then
                        --             API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".plink.active", "")
                        --             API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".plink.effect", "")
                        --             API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".plink.param", "")
                        --         end
                        --     end
                    end
                end
            end
        end
        ImGui.EndTable(ctx)
    end
end

function DrawPMInspector()
    if not TARGET then return end
    if not PM_INSPECTOR_FXID then return end
    local WX, WY = r.ImGui_GetWindowPos(ctx)

    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)
    r.ImGui_SetNextWindowPos(ctx, WX + 5, WY + 85)
    local total_columns = 2
    if r.ImGui_BeginChild(ctx, "PM_INSPECTOR", 350, 400, true) then
        INSPECTOR_HOVERED = r.ImGui_IsWindowHovered(ctx)
        local retval, buf = API.GetFXName(TARGET, PM_INSPECTOR_FXID)
        local aw = r.ImGui_GetContentRegionAvail(ctx)
        r.ImGui_Text(ctx, "PARAMETER INSPECTOR")
        r.ImGui_SameLine(ctx, aw - s_frame_x)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0)
        if r.ImGui_Button(ctx, "X") then
            OPEN_PM_INSPECTOR = nil
        end
        r.ImGui_PopStyleColor(ctx)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x0088FFFF)
        r.ImGui_Text(ctx, buf:upper())
        r.ImGui_PopStyleColor(ctx)

        r.ImGui_Separator(ctx)
        local child_hovered = r.ImGui_IsWindowHovered(ctx,
            r.ImGui_HoveredFlags_ChildWindows() |  r.ImGui_HoveredFlags_AllowWhenBlockedByPopup() |
            r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem())
        if LASTTOUCH_FX_ID and LASTTOUCH_FX_ID == PM_INSPECTOR_FXID and LASTTOUCH_P_ID then
            local rv, p_name = API.GetParamName(TARGET, LASTTOUCH_FX_ID, LASTTOUCH_P_ID)
            if rv then
                if ImGui.BeginTable(ctx, 'LAST_TOUCHED_PARAMETER', total_columns, tbl_flags) then
                    ImGui.TableSetupColumn(ctx, 'LAST TOUCHED', r.ImGui_TableColumnFlags_WidthStretch())
                    ImGui.TableSetupColumn(ctx, 'AUTO-SET')
                    --!ImGui.TableSetupColumn(ctx, 'ENV')
                    ImGui.TableHeadersRow(ctx)
                    ImGui.TableNextRow(ctx)
                    for column = 0, total_columns - 1 do
                        ImGui.TableSetColumnIndex(ctx, column)
                        if column == 0 then
                            if r.ImGui_Button(ctx, p_name, -FLT_MIN) then
                                API.SetNamedConfigParm(TARGET, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".mod.visible", "1")
                            end
                        elseif column == 1 then
                            if r.ImGui_Button(ctx, "SET##ALL", -FLT_MIN, 0) then
                                r.Undo_BeginBlock()
                                API.SetNamedConfigParm(TARGET, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".mod.visible", "1")
                                API.SetNamedConfigParm(TARGET, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".mod.active", "1")
                                API.SetNamedConfigParm(TARGET, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".acs.active", "1")
                                API.SetNamedConfigParm(TARGET, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".acs.chan", "2")
                                API.SetNamedConfigParm(TARGET, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".lfo.active", "1")
                                EndUndoBlock("SET ALL PARAMETER")
                            end
                        elseif column == 2 then
                            if PM_INSPECTOR_FXID == LASTTOUCH_FX_ID then
                                if r.ImGui_Button(ctx, "SHOW##ENV") then
                                    local fx_env = API.GetFXEnvelope(TARGET, PM_INSPECTOR_FXID, LASTTOUCH_FX_ID, false)

                                    local retval, env_chunk, is_visible
                                    if not fx_env then
                                        fx_env = API.GetFXEnvelope(TARGET, PM_INSPECTOR_FXID, LASTTOUCH_FX_ID, true)
                                    else
                                        retval, env_chunk = r.GetEnvelopeStateChunk(fx_env, "", true)
                                        -- is_visible = env_chunk:find("VIS 1", nil, true) and true or false
                                    end

                                    if env_chunk then
                                        local vis = env_chunk:match("VIS (%d+)")
                                        if vis == "1" then
                                            env_chunk = env_chunk:gsub("VIS 1", "VIS 0", 1)
                                        elseif vis == "0" then
                                            env_chunk = env_chunk:gsub("VIS 0", "VIS 1", 1)
                                        end
                                        r.SetEnvelopeStateChunk(fx_env, env_chunk, false)
                                    end
                                end
                                r.TrackList_AdjustWindows(false)
                            end
                        end
                    end
                    ImGui.EndTable(ctx)
                end
            end
        end
        if r.ImGui_BeginMenu(ctx, "PARAMETER LIST") then
            for p_id = 0, API.GetNumParams(TARGET, PM_INSPECTOR_FXID) do
                local rv, p_name = API.GetParamName(TARGET, PM_INSPECTOR_FXID, p_id)
                local _, mod = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active")
                local _, acs = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active")
                local _, lfo = API.GetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active")
                local fx_env = API.GetFXEnvelope(TARGET, PM_INSPECTOR_FXID, p_id, false)
                local has_points = (fx_env and r.CountEnvelopePoints(fx_env) > 2)
                local is_there = mod == "1" or acs == "1" or lfo == "1" or has_points
                if rv and #p_name ~= 0 then
                    if ALT then
                        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderHovered(), 0xBB2222FF)
                        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderActive(), 0xBB2222FF)
                    end
                    if is_there then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Header(), 0x49cc8588) end
                    if r.ImGui_Selectable(ctx, p_name, is_there, r.ImGui_SelectableFlags_DontClosePopups()) then
                        if ALT then
                            r.Undo_BeginBlock()
                            API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active",
                                "0")
                            API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active",
                                "0")
                            API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active",
                                "0")
                            EndUndoBlock("PARAMETER MODULATION UNSET FX ALL PARAMETERS")
                        else
                            r.Undo_BeginBlock()

                            local toggle = mod == "1" and "0"
                            API.SetNamedConfigParm(TARGET, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active",
                                toggle or "1")
                            EndUndoBlock("TOGGLE FX PARAMETER")
                        end
                    end
                    if ALT then
                        r.ImGui_PopStyleColor(ctx, 2)
                    end
                    if is_there then r.ImGui_PopStyleColor(ctx) end
                end
            end
            if not child_hovered then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndMenu(ctx)
        end

        r.ImGui_Separator(ctx)
        PMTable()

        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
end

function DrawUserSettings()
    local WX, WY = r.ImGui_GetWindowPos(ctx)

    if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)
    r.ImGui_SetNextWindowPos(ctx, WX + 5, WY + 85)
    local settings_min_h = 196
    if CLH_LAYOUT then
        settings_min_h = settings_min_h + 157
    end
    if CLH_COLORING then
        settings_min_h = settings_min_h + 230
    end
    if CLH_BEHAVIORS then
        settings_min_h = settings_min_h + 180
    end
    if r.ImGui_BeginChild(ctx, "USERSETTIGS", 220, settings_min_h, true) then --718
        SETTINGS_HOVERED = r.ImGui_IsWindowHovered(ctx)
        local COLOR = GetColorTbl()
        if r.ImGui_Button(ctx, "RESCAN FX LIST") then
            RescanFxList()
        end
        SettingsTooltips("FX LIST IS CACHED TO FILE FOR FASTER LOADING TIMES\nNEEDS MANUAL TRIGGER FOR UPDATING")

        r.ImGui_SeparatorText(ctx, "FONT")
        r.ImGui_PushID(ctx, "SETTINGS_FONT")
        if r.ImGui_BeginListBox(ctx, "", nil, 38) then
            if r.ImGui_Selectable(ctx, "DEFAULT", CUSTOM_FONT == nil) then
                SELECTED_FONT = DEFAULT_FONT
                CUSTOM_FONT = nil
            end
            if r.ImGui_Selectable(ctx, "SYSTEM", CUSTOM_FONT ~= nil) then
                SELECTED_FONT = SYSTEM_FONT
                CUSTOM_FONT = true
            end
            r.ImGui_EndListBox(ctx)
        end
        r.ImGui_PopID(ctx)
        --r.ImGui_SeparatorText(ctx, "LAYOUT")
        --! LAYOUT COLLAPSE
        CLH_LAYOUT = r.ImGui_CollapsingHeader(ctx, "LAYOUT", false)
        if CLH_LAYOUT then
            if r.ImGui_BeginListBox(ctx, "##LAYOUT1234", nil, 38) then
                if r.ImGui_Selectable(ctx, "VERTICAL", V_LAYOUT == true) then
                    if V_LAYOUT ~= true then
                        V_LAYOUT = true
                        RevertVertical()
                        ResetView(true)
                    end
                end
                if r.ImGui_Selectable(ctx, "HORIZONTAL", V_LAYOUT == false) then
                    if V_LAYOUT ~= false then
                        V_LAYOUT = false
                        DefaultHorizontal()
                        ResetView(true)
                    end
                end
                r.ImGui_EndListBox(ctx)
            end
            r.ImGui_SetNextItemWidth(ctx, 50)
            _, ZOOM_MAX = r.ImGui_SliderInt(ctx, "MAX ZOOM", ZOOM_MAX, 1, 3)
            r.ImGui_SetNextItemWidth(ctx, 100)
            _, new_spacing_y = r.ImGui_SliderInt(ctx, "SPACING", new_spacing_y, 0, 20)
            r.ImGui_SetNextItemWidth(ctx, 100)

            if not V_LAYOUT then r.ImGui_BeginDisabled(ctx, true) end
            _, ADD_BTN_H = r.ImGui_SliderInt(ctx, "+ HEIGHT", ADD_BTN_H, 10, 22)
            r.ImGui_SetNextItemWidth(ctx, 100)
            if not V_LAYOUT then r.ImGui_EndDisabled(ctx) end

            _, ADD_BTN_W = r.ImGui_SliderInt(ctx, "+ WIDTH", ADD_BTN_W, 20, 100)
            r.ImGui_SetNextItemWidth(ctx, 50)
            _, WireThickness = r.ImGui_SliderInt(ctx, "WIRE THICKNESS", WireThickness, 1, 5)
        end
        --r.ImGui_SeparatorText(ctx, "COLORING")
        --! LAYOUT COLLAPSE
        CLH_COLORING = r.ImGui_CollapsingHeader(ctx, "COLORING", false)
        if CLH_COLORING then
            --_, AUTO_COLORING = r.ImGui_Checkbox(ctx, "AUTO COLORING", AUTO_COLORING)
            --r.ImGui_Separator(ctx)
            _, COLOR["bg"] = r.ImGui_ColorEdit4(ctx, "BG COLOR", COLOR["bg"], r.ImGui_ColorEditFlags_NoInputs())
            --if AUTO_COLORING then r.ImGui_BeginDisabled(ctx, true) end
            _, COLOR["wire"] = r.ImGui_ColorEdit4(ctx, "WIRE COLOR", COLOR["wire"], r.ImGui_ColorEditFlags_NoInputs())
            --if AUTO_COLORING then r.ImGui_BeginDisabled(ctx, true) end
            _, COLOR["n"] = r.ImGui_ColorEdit4(ctx, "FX COLOR", COLOR["n"], r.ImGui_ColorEditFlags_NoInputs())
            _, COLOR["Container"] = r.ImGui_ColorEdit4(ctx, "CONTAINER COLOR", COLOR["Container"],
                r.ImGui_ColorEditFlags_NoInputs())
            _, COLOR["bypass"] = r.ImGui_ColorEdit4(ctx, "BYPASS COLOR", COLOR["bypass"],
                r.ImGui_ColorEditFlags_NoInputs())
            _, COLOR["offline"] = r.ImGui_ColorEdit4(ctx, "OFFLINE COLOR", COLOR["offline"],
                r.ImGui_ColorEditFlags_NoInputs())
            --if AUTO_COLORING then r.ImGui_EndDisabled(ctx) end

            _, COLOR["parallel"] = r.ImGui_ColorEdit4(ctx, "+ || COLOR", COLOR["parallel"],
                r.ImGui_ColorEditFlags_NoInputs())
            _, COLOR["knob_vol"] = r.ImGui_ColorEdit4(ctx, "KNOB VOLUME", COLOR["knob_vol"],
                r.ImGui_ColorEditFlags_NoInputs())
            _, COLOR["knob_drywet"] = r.ImGui_ColorEdit4(ctx, "KNOB DRY/WET", COLOR["knob_drywet"],
                r.ImGui_ColorEditFlags_NoInputs())
            _, COLOR["sine_anim"] = r.ImGui_ColorEdit4(ctx, "ANIMATED HIGHLIGHT", COLOR["sine_anim"],
                r.ImGui_ColorEditFlags_NoInputs())
        end
        --r.ImGui_SeparatorText(ctx, "BEHAVIORS")
        --! LAYOUT COLORING
        CLH_BEHAVIORS = r.ImGui_CollapsingHeader(ctx, "BEHAVIORS", false)
        if CLH_BEHAVIORS then
            _, TOOLTIPS = r.ImGui_Checkbox(ctx, "SHOW TOOLTIPS", TOOLTIPS)
            _, SHOW_C_CONTENT_TOOLTIP = r.ImGui_Checkbox(ctx, "PEEK COLLAPSED CONTAINER", SHOW_C_CONTENT_TOOLTIP)
            SettingsTooltips("HOVERING OVER CONTAINER COLLAPSED BUTTON \nWILL DRAW PREVIEW OF CONTAINER CONTENT")
            _, ESC_CLOSE = r.ImGui_Checkbox(ctx, "CLOSE ON ESC", ESC_CLOSE)
            _, ANIMATED_HIGLIGHT = r.ImGui_Checkbox(ctx, "ANIMATED HIGHLIGHT", ANIMATED_HIGLIGHT)
            SettingsTooltips("+ || BUTTONS HAVE ANIMATED COLOR\nFOR BETTER VISIBILITY WHEN DRAGGING")
            _, CTRL_DRAG_AUTOCONTAINER = r.ImGui_Checkbox(ctx, "CTRL-DRAG AUTOCONTAINER", CTRL_DRAG_AUTOCONTAINER)
            SettingsTooltips("CTRL-DRAG COPYING FX OVER ANOTHER FX\nWILL ENCLOSE BOTH IN CONTAINER")
            _, CENTER_RESET = r.ImGui_Checkbox(ctx, "CENTER RESET", CENTER_RESET)
            SettingsTooltips("RESET/CENTER VIEW ON TRACK CHANGE, SCRIPT START")

            if r.ImGui_BeginListBox(ctx, "NEW FX\nDND", nil, 38) then
                if r.ImGui_Selectable(ctx, "REPLACE", DEFAULT_DND == true) then
                    DEFAULT_DND = true
                end
                if r.ImGui_Selectable(ctx, "AUTOCONTAINER", DEFAULT_DND == false) then
                    DEFAULT_DND = false
                end
                r.ImGui_EndListBox(ctx)
            end
            SettingsTooltips("DRAGGING NEW FX FROM BROWSER TO ANOTHER FX")
        end
        r.ImGui_Separator(ctx)

        if r.ImGui_Button(ctx, "DEFAULT") then
            V_LAYOUT = true
            ZOOM_MAX = 1
            SHOW_C_CONTENT_TOOLTIP = true
            TOOLTIPS = true
            ANIMATED_HIGLIGHT = true
            ESC_CLOSE = false
            DEFAULT_DND = true
            CTRL_DRAG_AUTOCONTAINER = false
            CUSTOM_FONT = nil
            SELECTED_FONT = DEFAULT_FONT
            new_spacing_y = 10
            Knob_Radius = CUSTOM_BTN_H // 2
            ROUND_CORNER = 2
            WireThickness = 1
            ADD_BTN_W = 55
            ADD_BTN_H = 14
            CENTER_RESET = false
            local NEW_COLOR = {
                ["bg"]           = 0x111111FF,
                ["n"]            = 0x315e94ff,
                ["Container"]    = 0x49cc85FF,
                ["enclose"]      = 0x192432ff,
                ["knob_bg"]      = 0x192432ff,
                ["knob_vol"]     = 0x49cc85FF,
                ["knob_drywet"]  = 0x3a87ffff,
                ["midi"]         = 0x8833AAFF,
                ["del"]          = 0xBB2222FF,
                ["ROOT"]         = 0x49cc85FF,
                ["add"]          = 0x192432ff,
                ["parallel"]     = 0x192432ff,
                ["bypass"]       = 0xdc5454ff,
                ["enabled"]      = 0x49cc85FF,
                ["wire"]         = 0xB0B0B9FF,
                ["dnd"]          = 0x00b4d8ff,
                ["dnd_enclose"]  = 0x49cc85ff,
                ["dnd_replace"]  = 0xdc5454ff,
                ["dnd_swap"]     = 0xcd6dc6ff,
                ["sine_anim"]    = 0x6390c6ff,
                ["phase"]        = 0x9674c5ff,
                ["cut"]          = 0x00ff00ff,
                ["menu_txt_col"] = 0x3aCCffff,
                ["offline"]      = 0x4d5e72ff,
            }
            SetColorTbl(NEW_COLOR)
            ResetView(true)
        end
        r.ImGui_SameLine(ctx)

        if r.ImGui_Button(ctx, "DELETE SAVED") then
            r.DeleteExtState("PARANORMALFX2", "SETTINGS", true)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_EndChild(ctx)
end

local function TooltipUI(str)
    if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_BeginTooltip(ctx)
        r.ImGui_PushFont(ctx, CUSTOM_FONT and SYSTEM_FONT_FACTORY or DEFAULT_FONT_FACTORY)
        r.ImGui_Text(ctx, str)
        r.ImGui_PopFont(ctx)
        r.ImGui_EndTooltip(ctx)
    end
end

function DrawListButton2(name, color, hover, icon, round_side, shrink, active, txt_align)
    local rect_col = IS_DRAGGING_RIGHT_CANVAS and color or IncreaseDecreaseBrightness(color, hover and 50 or 0)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local round_flag = round_side and ROUND_FLAG[round_side] or nil
    local round_amt = round_flag and ROUND_CORNER or 0.5

    r.ImGui_DrawList_AddRectFilled(draw_list, shrink and xs + shrink or xs, ys, shrink and xe - shrink or xe, ye,
        r.ImGui_GetColorEx(ctx, rect_col), round_amt,
        round_flag)
    if r.ImGui_IsItemActive(ctx) or active then
        r.ImGui_DrawList_AddRect(draw_list, xs - 2, ys - 2, xe + 2, ye + 2, 0x22FF44FF, 2, nil, 2)
    end

    if icon then r.ImGui_PushFont(ctx, ICONS_FONT_SMALL_FACTORY) end

    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local font_size = r.ImGui_GetFontSize(ctx)
    local font_color = 0xFFFFFFFF

    local txt_x = xs + (w / 2) - (label_size / 2)
    txt_x = txt_align == "L" and xs or txt_x
    txt_x = txt_align == "R" and xe - label_size - shrink - (name_margin // 2) or txt_x
    txt_x = txt_align == "LC" and xs + (w / 2) - (label_size / 2) - (collapse_btn_size // 4) or txt_x

    local txt_y = ys + (h / 2) - (font_size / 2)
    r.ImGui_DrawList_AddTextEx(draw_list, nil, font_size, txt_x, txt_y, r.ImGui_GetColorEx(ctx, font_color), name)

    if icon then r.ImGui_PopFont(ctx) end
end

local sin = math.sin
local m_wheel_i = 1
function UI()
    if not TARGET then return end
    local top_tabs_offset = 23
    r.ImGui_SetCursorPos(ctx, 5, r.ImGui_IsWindowDocked(ctx) and 5 + top_tabs_offset or 25 + top_tabs_offset)
    -- NIFTY HACK FOR COMMENT BOX NOT OVERLAP UI BUTTONS
    if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)

    local retval, tr_ID --= r.GetTrackName(TARGET)
    if MODE == "TRACK" then
        retval, tr_ID = r.GetTrackName(TARGET)
    else
        tr_ID = r.GetTakeName(TARGET)
    end
    local tr_name_w = CalculateItemWH({ name = tr_ID })
    if r.ImGui_BeginChild(ctx, "TopButtons", 170 + tr_name_w + 40, def_btn_h + (s_window_y * 2), true) then
        UI_HOVERED = r.ImGui_IsWindowHovered(ctx)
        local child_hovered = r.ImGui_IsWindowHovered(ctx,
            r.ImGui_HoveredFlags_ChildWindows() |  r.ImGui_HoveredFlags_AllowWhenBlockedByPopup() |
            r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem())
        if r.ImGui_Button(ctx, "D", 22, def_btn_h) then
            if OPEN_SETTINGS then
                StoreSettings()
            end
            OPEN_SETTINGS = not OPEN_SETTINGS
        end
        TooltipUI("SETTINGS")
        DrawListButton2("$", 0xff, r.ImGui_IsItemHovered(ctx), true)
        r.ImGui_SameLine(ctx)
        if r.ImGui_InvisibleButton(ctx, "H", 22, def_btn_h) then
            ResetView()
        end
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseClicked(ctx, 1) then
            if CANVAS.scale ~= 1 then
                FLUX.to(CANVAS, 0.5, { scale = 1 }):ease("cubicout"):oncomplete(ResetView)
            else
                ResetView()
            end
        end
        local color_over_time = ((sin(r.time_precise() * 4) - 0.5) * 20) // 1
        local color = OFF_SCREEN and 0xff or IncreaseDecreaseBrightness(0x992222ff, color_over_time, "no_alpha")
        DrawListButton2("&", color, r.ImGui_IsItemHovered(ctx), true)
        TooltipUI("RESET VIEW\nRIGHT CLICK RESETS VIEW AND ZOOM")
        r.ImGui_SameLine(ctx)
        -- MUTE
        if r.ImGui_InvisibleButton(ctx, "M##mute", CalculateItemWH({ name = "PIN" }), def_btn_h) then
            if PIN then
                r.SetTrackUIMute(SEL_LIST_TRACK, -1, 0)
            else
                if MODE == "TRACK" then
                    r.SetTrackUIMute(TRACK, -1, 0)
                else
                    if TARGET then
                        local is_mute = r.GetMediaItemInfo_Value(ITEM, "B_MUTE")
                        r.SetMediaItemInfo_Value(ITEM, "B_MUTE", is_mute == 1 and 0 or 1)
                        r.UpdateArrange()
                    end
                end
            end
        end
        local mute_color = MODE == "TRACK" and r.GetMediaTrackInfo_Value(PIN and SEL_LIST_TRACK or TRACK, "B_MUTE") or 0
        mute_color = (MODE == "ITEM" and TARGET) and r.GetMediaItemInfo_Value(ITEM, "B_MUTE") or 0
        DrawListButton2("O", mute_color == 0 and 0xff or 0xff2222ff, r.ImGui_IsItemHovered(ctx), true)

        r.ImGui_SameLine(ctx, 0, 3)
        -- SOLO
        if r.ImGui_InvisibleButton(ctx, "S##solo", CalculateItemWH({ name = "PIN" }), def_btn_h) then
            if PIN then
                r.SetTrackUISolo(SEL_LIST_TRACK, -1, 0)
            else
                if MODE == "TRACK" then
                    r.SetTrackUISolo(TRACK, -1, 0)
                else
                    if TARGET then r.Main_OnCommand(41557, 0) end
                end
            end
        end
        local solo_color = r.GetMediaTrackInfo_Value(PIN and SEL_LIST_TRACK or TRACK, "I_SOLO")
        DrawListButton2("P", solo_color == 0 and 0xff or 0xf1c524ff, r.ImGui_IsItemHovered(ctx), true)
        r.ImGui_SameLine(ctx)

        -- PIN
        local pin_color = PIN and 0x49cc85FF or 0xff
        local pin_icon = PIN and "L" or "M"
        if r.ImGui_InvisibleButton(ctx, "M", 22, def_btn_h) then
            if MODE == "TRACK" then
                SEL_LIST_TRACK = TRACK
            else
                SEL_LIST_TAKE = TARGET
            end
            PIN = not PIN
        end
        DrawListButton2(pin_icon, pin_color, r.ImGui_IsItemHovered(ctx), true)
        TooltipUI(
            "LOCKS TO SELECTED TARGET\nMULTIPLE SCRIPTS CAN HAVE DIFFERENT SELECTIONS\nCAN BE CHANGED VIA DROPDOWN LIST")

        r.ImGui_SameLine(ctx)
        -- TRACK LIST
        --! NEED TO FIX OFFSET
        local vertical_mw = r.ImGui_GetMouseWheel(ctx)
        local mwheel_val
        r.ImGui_PushFont(ctx, CUSTOM_FONT and SYSTEM_FONT_FACTORY or DEFAULT_FONT_FACTORY)
        if r.ImGui_BeginMenu(ctx, tr_ID .. "##main") then
            local count_api = MODE == "TRACK" and r.CountTracks(0) or r.CountTrackMediaItems(TRACK) - 1
            for i = 0, count_api do
                local target
                if MODE == "TRACK" then
                    target = i == 0 and r.GetMasterTrack(0) or r.GetTrack(0, i - 1)
                else
                    target = r.GetActiveTake(r.GetTrackMediaItem(TRACK, i))
                end
                if not mwheel_val then
                    mwheel_val = target == TARGET and i
                end
                local _, target_name
                if MODE == "TRACK" then
                    _, target_name = r.GetTrackName(target)
                else
                    target_name = r.GetTakeName(target)
                end
                r.ImGui_PushID(ctx, target_name .. i)
                if r.ImGui_Selectable(ctx, target_name, target == TARGET) then
                    if PIN then
                        if MODE == "TRACK" then
                            SEL_LIST_TRACK = target
                        else
                            SEL_LIST_TAKE = target
                        end
                    else
                        if MODE == "TRACK" then
                            r.SetOnlyTrackSelected(target)
                        else
                            SetOnlyItemSelected(target)
                        end
                    end
                end
                r.ImGui_PopID(ctx)
                -- if i > 0 and track ~= TRACK then
                --     DragAndDropSidechainSource(track, track_id)
                -- end
            end
            if vertical_mw ~= 0 then
                vertical_mw = vertical_mw > 0 and -1 or 1
                if mwheel_val then
                    local new_val = (mwheel_val + vertical_mw)
                    local mw_target
                    if MODE == "TRACK" then
                        mw_target = new_val == 0 and r.GetMasterTrack(0) or r.GetTrack(0, new_val - 1)
                    else
                        local item = r.GetTrackMediaItem(TRACK, new_val)
                        mw_target = item and r.GetActiveTake(item)
                    end
                    if mw_target then
                        if PIN then
                            if MODE == "TRACK" then
                                SEL_LIST_TRACK = mw_target
                            else
                                SEL_LIST_TAKE = mw_target
                            end
                        else
                            if MODE == "TRACK" then
                                r.SetOnlyTrackSelected(mw_target)
                            else
                                SetOnlyItemSelected(mw_target)
                            end
                        end
                    end
                end
            end
            if not child_hovered then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndMenu(ctx)
        end
        r.ImGui_PopFont(ctx)
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_EndChild(ctx)
end

function CheckOverlap(tbl, i)
    if not MARQUEE then return end
    if tbl.type == "ROOT" then return end
    local function Get_Node_Screen_position(n)
        local x, y = CANVAS.view_x + CANVAS.off_x, CANVAS.view_y + CANVAS.off_y
        local n_x, n_y = x + (n.x * CANVAS.scale), y + (n.y * CANVAS.scale)
        local n_w, n_h = n.w * CANVAS.scale, n.h * CANVAS.scale
        return n_x, n_y, n_x + n_w, n_y + n_h, n_w, n_h
    end
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)

    local MXS, MYS, MXE, MYE = Get_Node_Screen_position(MARQUEE)

    local overlap = MXS < xe and MXE > xs and MYS < ye and MYE > ys
    --if overlap then
    if SHIFT or CTRL then
        if overlap then
            SEL_TBL[tbl.guid] = tbl
        end
    else
        SEL_TBL[tbl.guid] = overlap and tbl or nil
    end

    --end

    --return MXS < xe and MXE > xs and MYS < ye and MYE > ys
end

local min, abs = math.min, math.abs
function Draw_MARQUEE()
    if not r.ImGui_IsWindowHovered(ctx) and not MARQUEE then return end
    if (r.ImGui_IsAnyItemHovered(ctx) and r.ImGui_IsAnyItemActive(ctx)) then return end

    if r.ImGui_IsMouseDragging(ctx, 0) then
        local mpx, mpy = r.ImGui_GetMouseClickedPos(ctx, 0)
        local MQ_dx, MQ_dy = r.ImGui_GetMouseDragDelta(ctx, mpx, mpy, 0)
        MARQUEE = {
            x = (min(mpx, mpx + MQ_dx) - (CANVAS.view_x + CANVAS.off_x)) / CANVAS.scale,
            y = (min(mpy, mpy + MQ_dy) - (CANVAS.view_y + CANVAS.off_y)) / CANVAS.scale,
            w = abs(MQ_dx) / CANVAS.scale,
            h = abs(MQ_dy) / CANVAS.scale,
        }
        r.ImGui_DrawList_AddRectFilled(draw_list, mpx, mpy, mpx + MQ_dx, mpy + MQ_dy, 0xFFFFFF11)
        r.ImGui_DrawList_AddRect(draw_list, mpx, mpy, mpx + MQ_dx, mpy + MQ_dy, 0x607EAAAA)
    else
        if r.ImGui_IsMouseReleased(ctx, 0) and MARQUEE then
            MARQUEE = nil
            MARQUEE_SHIFT = nil
        end
    end
end

function CheckStaleData()
    if r.ImGui_IsMouseReleased(ctx, 0) then
        CTRL_DRAG = nil
        DRAG_PREVIEW = nil
    end
    if not PEAK_INTO_TOOLTIP then
        if PREVIEW_TOOLTIP then PREVIEW_TOOLTIP = nil end
    end
end

function CanvasLoop()
    if not TARGET then return end
    CheckKeys()
    Popups()
end

--profiler.attachToWorld() -- after all functions have been defined