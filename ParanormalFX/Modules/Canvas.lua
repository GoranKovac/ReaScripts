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
    if not TRACK then return end
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

local function ResetView(force)
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

    if HOME then ResetView() end

    if CTRL and Z then
        r.Main_OnCommand(40029, 0)
        -- CHECK IF TRACK CHANGED
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
            r.TrackFX_SetNamedConfigParm(TRACK, item_id, "renamed_name", SAVED_NAME)
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
                r.TrackFX_SetParam(TRACK, item_id, RC_DATA.tbl[i].wetparam, 1)
            end
        end
        if RC_DATA.tbl[RC_DATA.i].p > 0 then
            if r.ImGui_MenuItem(ctx, 'ADJUST LANE VOLUME TO UNITY') then
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local _, first_idx_in_row, p_cnt = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, -1)

                for i = first_idx_in_row, RC_DATA.i do
                    local item_id = CalcFxID(parrent_container, i)
                    r.TrackFX_SetParam(TRACK, item_id, RC_DATA.tbl[i].wetparam, 1 / p_cnt)
                end
            end
            r.ImGui_Separator(ctx)
            if r.ImGui_MenuItem(ctx, 'UNBYPASS LANE') then
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local _, first_idx_in_row = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, -1)
                local _, last_idx_in_row = FindNextPrevRow(RC_DATA.tbl, RC_DATA.i, 1)

                for i = first_idx_in_row, last_idx_in_row do
                    local item_id = CalcFxID(parrent_container, i)
                    r.TrackFX_SetEnabled(TRACK, item_id, true)
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
                    local fx_guid = r.TrackFX_GetFXGUID(TRACK, id)
                    if fx_guid then lane_tbl[#lane_tbl + 1] = fx_guid end
                end

                local cont_insert_id = CalculateInsertContainerPosFromBlacklist()
                local cont_pos = r.TrackFX_AddByName(TRACK, "Container", false, cont_insert_id)
                UpdateFxData()
                for i = #lane_tbl, 1, -1 do
                    local cont_id = 0x2000000 + cont_pos + 1 + (r.TrackFX_GetCount(TRACK) + 1)
                    parrent_container = GetFx(RC_DATA.tbl[RC_DATA.i].pid)
                    local child_id = GetFx(lane_tbl[i]).FX_ID
                    r.TrackFX_CopyToTrack(TRACK, child_id, TRACK, cont_id, true)
                    UpdateFxData()
                end
                UpdateFxData()
                parrent_container = GetFx(RC_DATA.tbl[RC_DATA.i].pid)
                local original_pos = CalcFxID(parrent_container, first_idx_in_row)
                -- MOVE CONTAINER TO ORIGINAL TARGET
                r.TrackFX_CopyToTrack(TRACK, 0x2000000 + cont_pos + 1, TRACK, original_pos, true)
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
    if RC_DATA.type ~= "ROOT" then
        if r.ImGui_MenuItem(ctx, 'RENAME') then
            RENAME_DATA = { tbl = RC_DATA.tbl, i = RC_DATA.i }
            OPEN_RENAME = true
        end

        if not RC_DATA.tbl[RC_DATA.i].exclude_ara then
            if r.ImGui_MenuItem(ctx, 'REPLACE') then
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local item_add_id = CalcFxID(parrent_container, RC_DATA.i)
                REPLACE_FX_POS = { tbl = RC_DATA.tbl, i = RC_DATA.i, id = item_add_id }
                OPEN_FX_LIST = true
            end
            r.ImGui_Separator(ctx)

            if r.ImGui_MenuItem(ctx, 'ENCLOSE INTO CONTAINER') then
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
                if r.ImGui_MenuItem(ctx, can_explode and 'EXPLODE CONTAINER' or "EXPLODE (NOT SUPPORTED)") then
                    ExplodeContainer(RC_DATA.tbl, RC_DATA.i)
                end
                if not can_explode or no_childs then r.ImGui_EndDisabled(ctx) end
            end
        end
        r.ImGui_Separator(ctx)

        if r.ImGui_BeginMenu(ctx, "FX SETTINGS") then
            if r.ImGui_BeginMenu(ctx, "OVERSAMPLING") then
                local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
                local item_id = CalcFxID(parrent_container, RC_DATA.i)
                local retval1, buf1 = r.TrackFX_GetNamedConfigParm(TRACK, item_id, "chain_oversample_shift")
                local retval2, buf2 = r.TrackFX_GetNamedConfigParm(TRACK, item_id, "instance_oversample_shift")

                for i = 1, 2 do
                    if r.ImGui_BeginMenu(ctx, i == 1 and "CHAIN" or "INSTANCE") then
                        for j = 0, 2 do
                            local name = j == 0 and "NONE" or j == 1 and "96kHz" or "192kHz"
                            if r.ImGui_MenuItem(ctx, name, nil, (i == 1 and buf1 or buf2) == tostring(j)) then
                                r.TrackFX_SetNamedConfigParm(TRACK, item_id,
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
            local retval, buf = r.TrackFX_GetNamedConfigParm(TRACK, item_id, "force_auto_bypass")
            if r.ImGui_MenuItem(ctx, "AUTO BYPASS ON SILENCE", nil, buf == "1" and true or false) then
                r.TrackFX_SetNamedConfigParm(TRACK, item_id, "force_auto_bypass", buf == "0" and "1" or "0")
            end
            r.ImGui_EndMenu(ctx)
        end
        r.ImGui_Separator(ctx)
    end

    if r.ImGui_MenuItem(ctx, 'DELETE') then
        if RC_DATA.type == "ROOT" then
            RemoveAllFX()
        else
            r.PreventUIRefresh(1)
            r.Undo_BeginBlock()
            local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
            local item_id = CalcFxID(parrent_container, RC_DATA.i)
            CheckNextItemParallel(RC_DATA.i, parrent_container)
            r.TrackFX_Delete(TRACK, item_id)
            EndUndoBlock("DELETE FX:" .. RC_DATA.tbl[RC_DATA.i].name)
            r.PreventUIRefresh(-1)
        end
        ValidateClipboardFX()
    end
    if RC_DATA.type == "ROOT" or RC_DATA.type == "Container" then
        r.ImGui_Separator(ctx)
        if r.ImGui_MenuItem(ctx, 'SAVE AS CHAIN') then
            OPEN_FM = true
            FM_TYPE = "SAVE"
            Init_FM_database()
            if RC_DATA.type == "ROOT" then
                CreateFxChain()
            else
                CreateFxChain(RC_DATA.tbl[RC_DATA.i].guid)
            end
        end
    end
    if RC_DATA.type ~= "ROOT" and not RC_DATA.tbl[RC_DATA.i].exclude_ara then
        r.ImGui_Separator(ctx)
        if r.ImGui_MenuItem(ctx, 'COPY') then
            local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
            local item_id = CalcFxID(parrent_container, RC_DATA.i)
            local is_collapsed = CheckCollapse(RC_DATA.tbl[RC_DATA.i], 1, 1)
            local data = tableToString(
                {
                    tbl = RC_DATA.tbl,
                    i = RC_DATA.i,
                    track_guid = r.GetTrackGUID(TRACK),
                    fx_id = item_id,
                    guid = RC_DATA.tbl[RC_DATA.i].guid,
                    collapsed = is_collapsed,
                    type = RC_DATA.tbl[RC_DATA.i].type
                }
            )
            r.SetExtState("PARANORMALFX2", "COPY_BUFFER", data, false)
            r.SetExtState("PARANORMALFX2", "COPY_BUFFER_ID", r.genGuid(), false)
        end
        if r.ImGui_MenuItem(ctx, 'CUT') then
            local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
            local item_id = CalcFxID(parrent_container, RC_DATA.i)
            local is_collapsed = CheckCollapse(RC_DATA.tbl[RC_DATA.i], 1, 1)
            local data = tableToString(
                {
                    tbl = RC_DATA.tbl,
                    i = RC_DATA.i,
                    track_guid = r.GetTrackGUID(TRACK),
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
            if r.ImGui_MenuItem(ctx, 'PASTE-REPLACE') then
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
                r.TrackFX_SetNamedConfigParm(TRACK, PM_RC_DATA.fx_id, "param." .. PM_RC_DATA.p_id .. ".acs." .. ACS_TBL[i],
                    ACS_defaults[i])
            end
        end
    elseif PM_RC_DATA.type == "LFO" then
        if r.ImGui_MenuItem(ctx, "RESET TO LFO DEFAULT") then
            for i = 1, #LFO_TBL do
                r.TrackFX_SetNamedConfigParm(TRACK, PM_RC_DATA.fx_id, "param." .. PM_RC_DATA.p_id .. ".lfo." .. LFO_TBL[i],
                    LFO_defaults[i])
            end
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
        DrawFXList()
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
            local _, buf = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID,
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
                    r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs." .. ACS_TBL[i],
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
            local _, buf = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID,
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
                    r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo." .. LFO_TBL[i],
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
    local columns = 5
    if ImGui.BeginTable(ctx, 'ALL_PARAMETERS', columns, tbl_flags) then
        ImGui.TableSetupColumn(ctx, 'PARAMETER', r.ImGui_TableColumnFlags_WidthStretch())
        ImGui.TableSetupColumn(ctx, 'PMD')
        ImGui.TableSetupColumn(ctx, 'ACS')
        ImGui.TableSetupColumn(ctx, 'LFO')
        ImGui.TableSetupColumn(ctx, 'SHAPE')
        --!ImGui.TableSetupColumn(ctx, 'ENV')
        --ImGui.TableSetupColumn(ctx, 'INP')
        --ImGui.TableSetupColumn(ctx, 'TYP')
        ImGui.TableHeadersRow(ctx)
        for p_id = 0, r.TrackFX_GetNumParams(TRACK, PM_INSPECTOR_FXID) do
            local _, p_name = r.TrackFX_GetParamName(TRACK, PM_INSPECTOR_FXID, p_id)
            local _, mod = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active")
            local _, mod_vis = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.visible")
            local _, acs = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active")
            local _, lfo = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active")
            local _, lfo_speed = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.speed")
            local _, lfo_shape = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.shape")
            local fx_env = r.GetFXEnvelope(TRACK, PM_INSPECTOR_FXID, p_id, false)
            --!local has_points = (fx_env and r.CountEnvelopePoints(fx_env) > 2)
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
                                r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active",
                                    "0")
                                r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active",
                                    "0")
                                r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active",
                                    "0")
                                EndUndoBlock("PARAMETER MODULATION UNSET FX ALL PARAMETERS")
                            else
                                r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.visible",
                                    mod_vis == "0" and "1" or "0")
                            end
                        end
                        if ALT then
                            r.ImGui_PopStyleColor(ctx, 2)
                        end
                        r.ImGui_PopID(ctx)
                    elseif column == 1 then
                        if r.ImGui_Checkbox(ctx, "##PM" .. PM_INSPECTOR_FXID .. p_id, mod == "1") then
                            r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active",
                                mod == "0" and "1" or "0")
                        end
                    elseif column == 2 then
                        if r.ImGui_Checkbox(ctx, "##ACS" .. PM_INSPECTOR_FXID .. p_id, acs == "1") then
                            r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active",
                                acs == "0" and "1" or "0")
                            local _, acs_ch = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID,
                                "param." .. p_id .. ".acs.chan")
                            --! IF NO CHANNELS HAVE BEEN ASSIGNED SET DEFAULT TO 1/2
                            if acs_ch == "-1" then
                                r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.chan",
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
                            r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active",
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
                            r.GetFXEnvelope(TRACK, PM_INSPECTOR_FXID, p_id, true)
                            local enabled_previously
                            --! WEIRD HACK TO BRING ENVELOPE BACK VISIBLE WHEN CHUNK IS NOT RESPONDING
                            if not is_visible and fx_env then
                                r.TrackList_AdjustWindows(false)
                                enabled_previously = true
                            end
                            if env_chunk then
                                if not ALT then
                                    local vis = env_chunk:match("VIS (%d+)")
                                    if vis == "1" then
                                        env_chunk = env_chunk:gsub("VIS 1", "VIS 0", 1)
                                        r.SetCursorContext(2, fx_env)
                                    elseif vis == "0" and not enabled_previously then
                                        env_chunk = env_chunk:gsub("VIS 0", "VIS 1", 1)
                                    end
                                    if not enabled_previously then
                                        r.SetEnvelopeStateChunk(fx_env, env_chunk, false)
                                    end
                                elseif ALT and is_visible then
                                    r.SetCursorContext(2, fx_env)
                                    r.Main_OnCommand(40065, 0)
                                    r.SetCursorContext(2)
                                end
                            end
                            r.TrackList_AdjustWindows(false)
                        end
                        if has_points then
                            r.ImGui_PopStyleColor(ctx)
                        end
                    end
                end
            end
        end
        ImGui.EndTable(ctx)
    end
end

function DrawPMInspector()
    if not TRACK then return end
    if not PM_INSPECTOR_FXID then return end
    local WX, WY = r.ImGui_GetWindowPos(ctx)

    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)
    r.ImGui_SetNextWindowPos(ctx, WX + 5, WY + 65)
    local total_columns = 2
    if r.ImGui_BeginChild(ctx, "PM_INSPECTOR", 350, 400, true) then
        INSPECTOR_HOVERED = r.ImGui_IsWindowHovered(ctx)
        local retval, buf = r.TrackFX_GetFXName(TRACK, PM_INSPECTOR_FXID)
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
            local rv, p_name = r.TrackFX_GetParamName(TRACK, LASTTOUCH_FX_ID, LASTTOUCH_P_ID)
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
                                r.TrackFX_SetNamedConfigParm(TRACK, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".mod.visible", "1")
                            end
                        elseif column == 1 then
                            if r.ImGui_Button(ctx, "SET##ALL", -FLT_MIN, 0) then
                                r.Undo_BeginBlock()
                                r.TrackFX_SetNamedConfigParm(TRACK, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".mod.visible", "1")
                                r.TrackFX_SetNamedConfigParm(TRACK, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".mod.active", "1")
                                r.TrackFX_SetNamedConfigParm(TRACK, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".acs.active", "1")
                                r.TrackFX_SetNamedConfigParm(TRACK, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".acs.chan", "2")
                                r.TrackFX_SetNamedConfigParm(TRACK, LASTTOUCH_FX_ID,
                                    "param." .. LASTTOUCH_P_ID .. ".lfo.active", "1")
                                EndUndoBlock("SET ALL PARAMETER")
                            end
                        elseif column == 2 then
                            if PM_INSPECTOR_FXID == LASTTOUCH_FX_ID then
                                if r.ImGui_Button(ctx, "SHOW##ENV") then
                                    local fx_env = r.GetFXEnvelope(TRACK, PM_INSPECTOR_FXID, LASTTOUCH_FX_ID, false)

                                    local retval, env_chunk, is_visible
                                    if not fx_env then
                                        fx_env = r.GetFXEnvelope(TRACK, PM_INSPECTOR_FXID, LASTTOUCH_FX_ID, true)
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
            for p_id = 0, r.TrackFX_GetNumParams(TRACK, PM_INSPECTOR_FXID) do
                local rv, p_name = r.TrackFX_GetParamName(TRACK, PM_INSPECTOR_FXID, p_id)
                local _, mod = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active")
                local _, acs = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active")
                local _, lfo = r.TrackFX_GetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active")
                local fx_env = r.GetFXEnvelope(TRACK, PM_INSPECTOR_FXID, p_id, false)
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
                            r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active",
                                "0")
                            r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".acs.active",
                                "0")
                            r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".lfo.active",
                                "0")
                            EndUndoBlock("PARAMETER MODULATION UNSET FX ALL PARAMETERS")
                        else
                            r.Undo_BeginBlock()

                            local toggle = mod == "1" and "0"
                            r.TrackFX_SetNamedConfigParm(TRACK, PM_INSPECTOR_FXID, "param." .. p_id .. ".mod.active",
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
    r.ImGui_SetNextWindowPos(ctx, WX + 5, WY + 65)

    if r.ImGui_BeginChild(ctx, "USERSETTIGS", 220, 718, true) then
        SETTINGS_HOVERED = r.ImGui_IsWindowHovered(ctx)
        local COLOR = GetColorTbl()
        if r.ImGui_Button(ctx, "RESCAN FX LIST") then
            RescanFxList()
        end
        SettingsTooltips("FX LIST IS CACHED TO FILE FOR FASTER LOADING TIMES\nNEEDS MANUAL TRIGGER FOR UPDATING")

        r.ImGui_SeparatorText(ctx, "UI")
        if r.ImGui_BeginListBox(ctx, "FONT", nil, 38) then
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
        r.ImGui_SeparatorText(ctx, "LAYOUT")
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
        r.ImGui_SeparatorText(ctx, "COLORING")
        --_, AUTO_COLORING = r.ImGui_Checkbox(ctx, "AUTO COLORING", AUTO_COLORING)
        --r.ImGui_Separator(ctx)
        _, COLOR["wire"] = r.ImGui_ColorEdit4(ctx, "WIRE COLOR", COLOR["wire"], r.ImGui_ColorEditFlags_NoInputs())
        --if AUTO_COLORING then r.ImGui_BeginDisabled(ctx, true) end
        _, COLOR["n"] = r.ImGui_ColorEdit4(ctx, "FX COLOR", COLOR["n"], r.ImGui_ColorEditFlags_NoInputs())
        _, COLOR["Container"] = r.ImGui_ColorEdit4(ctx, "CONTAINER COLOR", COLOR["Container"],
            r.ImGui_ColorEditFlags_NoInputs())
        _, COLOR["bypass"] = r.ImGui_ColorEdit4(ctx, "BYPASS COLOR", COLOR["bypass"], r.ImGui_ColorEditFlags_NoInputs())
        _, COLOR["offline"] = r.ImGui_ColorEdit4(ctx, "OFFLINE COLOR", COLOR["offline"],
            r.ImGui_ColorEditFlags_NoInputs())
        --if AUTO_COLORING then r.ImGui_EndDisabled(ctx) end

        _, COLOR["parallel"] = r.ImGui_ColorEdit4(ctx, "+ || COLOR", COLOR["parallel"],
            r.ImGui_ColorEditFlags_NoInputs())
        _, COLOR["knob_vol"] = r.ImGui_ColorEdit4(ctx, "KNOB VOLUME", COLOR["knob_vol"],
            r.ImGui_ColorEditFlags_NoInputs())
        _, COLOR["knob_drywet"] = r.ImGui_ColorEdit4(ctx, "KNOB DRY/WET", COLOR["knob_drywet"],
            r.ImGui_ColorEditFlags_NoInputs())
        _, COLOR["sine_anim"] = r.ImGui_ColorEdit4(ctx, "ANIMATED HIGLIGHT", COLOR["sine_anim"],
            r.ImGui_ColorEditFlags_NoInputs())
        r.ImGui_SeparatorText(ctx, "BEHAVIORS")
        _, TOOLTIPS = r.ImGui_Checkbox(ctx, "SHOW TOOLTIPS", TOOLTIPS)
        _, SHOW_C_CONTENT_TOOLTIP = r.ImGui_Checkbox(ctx, "PEEK COLLAPSED CONTAINER", SHOW_C_CONTENT_TOOLTIP)
        SettingsTooltips("HOVERING OVER CONTAINER COLLAPSED BUTTON \nWILL DRAW PREVIEW OF CONTAINER CONTENT")
        _, ESC_CLOSE = r.ImGui_Checkbox(ctx, "CLOSE ON ESC", ESC_CLOSE)
        _, ANIMATED_HIGLIGHT = r.ImGui_Checkbox(ctx, "ANIMATED HIGHLIGHT", ANIMATED_HIGLIGHT)
        SettingsTooltips("+ || BUTTONS HAVE ANIMATED COLOR\nFOR BETTER VISIBILITY WHEN DRAGGING")
        _, CTRL_DRAG_AUTOCONTAINER = r.ImGui_Checkbox(ctx, "CTRL-DRAG AUTOCONTAINER", CTRL_DRAG_AUTOCONTAINER)
        SettingsTooltips("CTRL-DRAG COPYING FX OVER ANOTHER FX\nWILL ENCLOSE BOTH IN CONTAINER")
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
            local NEW_COLOR = {
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
    if not TRACK then return end
    r.ImGui_SetCursorPos(ctx, 5, r.ImGui_IsWindowDocked(ctx) and 5 or 25)
    -- NIFTY HACK FOR COMMENT BOX NOT OVERLAP UI BUTTONS
    if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)

    local retval, tr_ID = r.GetTrackName(TRACK)
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
        local color_over_time = ((sin(r.time_precise() * 4) - 0.5) * 40) // 1
        local color = OFF_SCREEN and 0xff or IncreaseDecreaseBrightness(0x992222ff, color_over_time, "no_alpha")
        DrawListButton2("&", color, r.ImGui_IsItemHovered(ctx), true)
        TooltipUI("RESET VIEW\nRIGHT CLICK RESETS VIEW AND ZOOM")
        r.ImGui_SameLine(ctx)
        -- MUTE
        if r.ImGui_InvisibleButton(ctx, "M##mute", CalculateItemWH({ name = "PIN" }), def_btn_h) then
            if PIN then
                r.SetTrackUIMute(SEL_LIST_TRACK, -1, 0)
            else
                r.SetTrackUIMute(TRACK, -1, 0)
            end
        end
        local mute_color = r.GetMediaTrackInfo_Value(PIN and SEL_LIST_TRACK or TRACK, "B_MUTE")
        DrawListButton2("O", mute_color == 0 and 0xff or 0xff2222ff, r.ImGui_IsItemHovered(ctx), true)

        r.ImGui_SameLine(ctx, 0, 3)
        -- SOLO
        if r.ImGui_InvisibleButton(ctx, "S##solo", CalculateItemWH({ name = "PIN" }), def_btn_h) then
            if PIN then
                r.SetTrackUISolo(SEL_LIST_TRACK, -1, 0)
            else
                r.SetTrackUISolo(TRACK, -1, 0)
            end
        end
        local solo_color = r.GetMediaTrackInfo_Value(PIN and SEL_LIST_TRACK or TRACK, "I_SOLO")
        DrawListButton2("P", solo_color == 0 and 0xff or 0xf1c524ff, r.ImGui_IsItemHovered(ctx), true)
        r.ImGui_SameLine(ctx)

        -- PIN
        local pin_color = PIN and 0x49cc85FF or 0xff
        local pin_icon = PIN and "L" or "M"
        if r.ImGui_InvisibleButton(ctx, "M", 22, def_btn_h) then
            SEL_LIST_TRACK = TRACK
            PIN = not PIN
        end
        DrawListButton2(pin_icon, pin_color, r.ImGui_IsItemHovered(ctx), true)
        TooltipUI(
            "LOCKS TO SELECTED TRACK\nMULTIPLE SCRIPTS CAN HAVE DIFFERENT SELECTIONS\nCAN BE CHANGED VIA TRACKLIST")

        r.ImGui_SameLine(ctx)
        -- TRACK LIST
        --! NEED TO FIX OFFSET
        local vertical_mw = r.ImGui_GetMouseWheel(ctx)
        local mwheel_val
        if r.ImGui_BeginMenu(ctx, tr_ID .. "##main") then
            for i = 0, r.CountTracks(0) do
                local track = i == 0 and r.GetMasterTrack(0) or r.GetTrack(0, i - 1)
                if not mwheel_val then
                    mwheel_val = track == TRACK and i
                end
                local _, track_id = r.GetTrackName(track)
                if r.ImGui_Selectable(ctx, track_id, track == TRACK) then
                    if PIN then
                        SEL_LIST_TRACK = track
                    else
                        r.SetOnlyTrackSelected(track)
                    end
                end
                -- if i > 0 and track ~= TRACK then
                --     DragAndDropSidechainSource(track, track_id)
                -- end
            end
            if vertical_mw ~= 0 then
                vertical_mw = vertical_mw > 0 and -1 or 1
                if mwheel_val then
                    local new_val = (mwheel_val + vertical_mw)
                    local mw_track = new_val == 0 and r.GetMasterTrack(0) or r.GetTrack(0, new_val - 1)
                    if mw_track then
                        if PIN then
                            SEL_LIST_TRACK = mw_track
                        else
                            r.SetOnlyTrackSelected(mw_track)
                        end
                    end
                end
            end
            if not child_hovered then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndMenu(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_EndChild(ctx)
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
    if not TRACK then return end
    CheckKeys()
    Popups()
end
