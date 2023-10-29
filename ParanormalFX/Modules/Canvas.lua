--@noindex
--NoIndex: true

local r = reaper
local ImGui = {}
for name, func in pairs(reaper) do
    name = name:match('^ImGui_(.+)$')
    if name then ImGui[name] = func end
end

local def_vertical_y_center = 100

function InitCanvas()
    return { view_x = 0, view_y = 0, off_x = 0, off_y = def_vertical_y_center, scale = 1 }
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

local function CheckKeys()
    ALT = ImGui.GetKeyMods(ctx) == ImGui.Mod_Alt()
    CTRL = ImGui.GetKeyMods(ctx) == ImGui.Mod_Shortcut()
    SHIFT = ImGui.GetKeyMods(ctx) == ImGui.Mod_Shift()

    HOME = ImGui.IsKeyPressed(ctx, ImGui.Key_Home())
    SPACE = ImGui.IsKeyPressed(ctx, ImGui.Key_Space())
    ESC = ImGui.IsKeyPressed(ctx, ImGui.Key_Escape())

    Z = ImGui.IsKeyPressed(ctx, ImGui.Key_Z())
    C = ImGui.IsKeyPressed(ctx, ImGui.Key_C())

    if HOME then CANVAS.off_x, CANVAS.off_y = 0, def_vertical_y_center end

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
    if RC_DATA.type ~= "ROOT" and not RC_DATA.is_helper then
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

            if r.ImGui_MenuItem(ctx, 'ENCLOSE INTO CONTAINER') then
                r.Undo_BeginBlock()
                r.PreventUIRefresh(1)
                MoveTargetsToNewContainer(RC_DATA.tbl, RC_DATA.i)
                r.PreventUIRefresh(-1)
                EndUndoBlock("MOVE FX AND ENCLOSE INTO CONTAINER")
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
            local is_collapsed = CheckCollapse(RC_DATA.tbl[RC_DATA.i],1,1)
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
            local is_collapsed = CheckCollapse(RC_DATA.tbl[RC_DATA.i],1,1)
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

        --if RC_DATA.para_info and RC_DATA.para_info > 0 then
        --local parrent_container = GetParentContainerByGuid(RC_DATA.tbl[RC_DATA.i])
        --local item_id = CalcFxID(parrent_container, RC_DATA.i)
        -- local _, para = r.TrackFX_GetNamedConfigParm(TRACK, RC_DATA.tbl[RC_DATA.i].FX_ID, "parallel")
        -- rv_mp = r.ImGui_Checkbox(ctx, "MIDI PARALLEL", para == "2")
        -- if rv_mp then
        --     local new_p_val
        --     if RC_DATA.i == 1 then
        --         -- FIRST IN CHAIN CAN ONLY BE 0 OR 2
        --         new_p_val = para == "0" and "2" or "0"
        --     else
        --         -- ANY OTHER IN CHAIN CAN BE 1 OR 2
        --         new_p_val = para == "1" and "2" or "1"
        --     end
        --     r.TrackFX_SetNamedConfigParm(TRACK, RC_DATA.tbl[RC_DATA.i].FX_ID, "parallel", new_p_val)
        -- end
        --end
        -- SHOW ONLY WHEN CLIPBOARD IS AVAILABLE
        if CLIPBOARD.tbl and CLIPBOARD.guid ~= RC_DATA.tbl[RC_DATA.i].guid then
            --! DO NOT ALLOW PASTING ON SELF
            if r.ImGui_MenuItem(ctx, 'PASTE-REPLACE') then
                Paste(true, RC_DATA.tbl[RC_DATA.i].p > 0, RC_DATA.tbl[RC_DATA.i].p == 0)
            end
        end
    end
end

local function Popups()
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }

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
end

local function StoreSettings()
    local data = tableToString(
        {
            show_c_content_tooltips = SHOW_C_CONTENT_TOOLTIP,
            tooltips = TOOLTIPS,
            animated_highlight = ANIMATED_HIGLIGHT,
            ctrl_autocontainer = CTRL_DRAG_AUTOCONTAINER,
            esc_close = ESC_CLOSE,
            custom_font = CUSTOM_FONT,
            auto_color = AUTO_COLORING,
            spacing = S_SPACING_Y,
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
        r.ImGui_PushFont(ctx, SELECTED_FONT)
        if r.ImGui_BeginTooltip(ctx) then
            r.ImGui_Text(ctx, str)
            r.ImGui_EndTooltip(ctx)
        end
        r.ImGui_PopFont(ctx)
        r.ImGui_PopStyleColor(ctx)
    end
end

function DrawUserSettings()
    local WX, WY = r.ImGui_GetWindowPos(ctx)

    if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)
    r.ImGui_SetNextWindowPos(ctx, WX + 5, WY + 65)

    if r.ImGui_BeginChild(ctx, "USERSETTIGS", 220, 628, 1) then
        if r.ImGui_Button(ctx, "RESCAN FX LIST") then
            local FX_LIST, CAT, DEV_LIST = GetFXTbl()
            local serialized_fx = TableToString(FX_LIST)
            WriteToFile(FX_FILE, serialized_fx)

            local serialized_cat = TableToString(CAT)
            WriteToFile(FX_CAT_FILE, serialized_cat)

            local serialized_dev_list = TableToString(DEV_LIST)
            WriteToFile(FX_DEV_LIST_FILE, serialized_dev_list)

            UpdateFXBrowserData()
            WANT_REFRESH = true
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
        r.ImGui_SetNextItemWidth(ctx, 100)
        _, S_SPACING_Y = r.ImGui_SliderInt(ctx, "SPACING", S_SPACING_Y, 0, 20)
        r.ImGui_SetNextItemWidth(ctx, 100)

        _, ADD_BTN_H = r.ImGui_SliderInt(ctx, "+ HEIGHT", ADD_BTN_H, 10, 22)
        r.ImGui_SetNextItemWidth(ctx, 100)

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
            SHOW_C_CONTENT_TOOLTIP = true
            TOOLTIPS = true
            ANIMATED_HIGLIGHT = true
            ESC_CLOSE = false
            DEFAULT_DND = true
            CTRL_DRAG_AUTOCONTAINER = false
            CUSTOM_FONT = nil
            SELECTED_FONT = DEFAULT_FONT
            S_SPACING_Y = 4
            CUSTOM_BTN_H = 22
            Knob_Radius = CUSTOM_BTN_H // 2
            ROUND_CORNER = 2
            WireThickness = 1
            ADD_BTN_W = 55
            ADD_BTN_H = 14
            COLOR = {
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
        r.ImGui_PushFont(ctx, SELECTED_FONT)
        r.ImGui_Text(ctx, str)
        r.ImGui_PopFont(ctx)
        r.ImGui_EndTooltip(ctx)
    end
end

local sin = math.sin
local m_wheel_i = 1
function UI()
    if not TRACK then return end
    r.ImGui_SetCursorPos(ctx, 5, 25)
    -- NIFTY HACK FOR COMMENT BOX NOT OVERLAP UI BUTTONS
    if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)

    local retval, tr_ID = r.GetTrackName(TRACK)
    local tr_name_w = CalculateItemWH({ name = tr_ID })
    if r.ImGui_BeginChild(ctx, "TopButtons", 170 + tr_name_w + 40, def_btn_h + (s_window_y * 2), 1) then
        local child_hovered = r.ImGui_IsWindowHovered(ctx,
            r.ImGui_HoveredFlags_ChildWindows() |  r.ImGui_HoveredFlags_AllowWhenBlockedByPopup() |
            r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem())
        --r.ImGui_PushFont(ctx, ICONS_FONT2)
        if r.ImGui_Button(ctx, "D", 22, def_btn_h) then
            if OPEN_SETTINGS then
                StoreSettings()
            end
            OPEN_SETTINGS = not OPEN_SETTINGS
        end
        TooltipUI("SETTINGS")
        DrawListButton("$", 0xff, r.ImGui_IsItemHovered(ctx), true)
        r.ImGui_SameLine(ctx)
        if r.ImGui_InvisibleButton(ctx, "H", 22, def_btn_h) then
            CANVAS.off_x, CANVAS.off_y = 0, def_vertical_y_center
        end
        local color_over_time = ((sin(r.time_precise() * 4) - 0.5) * 40) // 1
        local color = OFF_SCREEN and 0xff or IncreaseDecreaseBrightness(0x992222ff, color_over_time, "no_alpha")
        DrawListButton("&", color, r.ImGui_IsItemHovered(ctx), true)
        TooltipUI("RESET VIEW")
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
        DrawListButton("O", mute_color == 0 and 0xff or 0xff2222ff, r.ImGui_IsItemHovered(ctx), true)

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
        DrawListButton("P", solo_color == 0 and 0xff or 0xf1c524ff, r.ImGui_IsItemHovered(ctx), true)
        r.ImGui_SameLine(ctx)

        -- PIN
        local pin_color = PIN and 0x49cc85FF or 0xff
        local pin_icon = PIN and "L" or "M"
        if r.ImGui_InvisibleButton(ctx, "M", 22, def_btn_h) then
            SEL_LIST_TRACK = TRACK
            PIN = not PIN
        end
        DrawListButton(pin_icon, pin_color, r.ImGui_IsItemHovered(ctx), true)
        TooltipUI(
            "LOCKS TO SELECTED TRACK\nMULTIPLE SCRIPTS CAN HAVE DIFFERENT SELECTIONS\nCAN BE CHANGED VIA TRACKLIST")
        r.ImGui_SameLine(ctx)
        --r.ImGui_PopFont(ctx)
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
