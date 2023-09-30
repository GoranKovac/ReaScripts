-- @description Sexan Para-Normal FX Router
-- @author Sexan
-- @license GPL v3
-- @version 1.23
-- @changelog
--  remove set scroll api set by accident
--  reduce knob size by 1 pixel
-- @provides
--   Icons.ttf

local r = reaper
local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local script_path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]];

local fx_browser_script_path = r.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_Parser.lua"

if not r.APIExists("ImGui_GetVersion") then
    r.ShowConsoleMsg("ReaImGui is required.\nPlease Install it in next window")
    return r.ReaPack_BrowsePackages('dear imgui')
end
if r.file_exists(fx_browser_script_path) then
    require("Sexan_FX_Browser_Parser")
else
    r.ShowConsoleMsg("Sexan FX BROWSER is needed.\nPlease Install it in next window")
    return r.ReaPack_BrowsePackages('sexan fx browser parser')
end

local VOL_PAN_HELPER = "Volume/Pan Smoother"

-- SETTINGS
local item_spacing_vertical = 10 -- VERTICAL SPACING BETEWEEN ITEMS
local add_bnt_size = 55
local custom_btn_h = 22
local ROUND_CORNER = 2
local WireThickness = 1
local Knob_Radius = custom_btn_h // 2
-- SETTINGS

local COLOR = {
    ["n"]         = 0x315e94ff,
    ["Container"] = 0x49cc85FF,

    ["midi"]      = 0x8833AAFF,
    ["del"]       = 0xFF2222FF,
    ["ROOT"]      = 0x49cc85FF,
    ["add"]       = 0x192432ff,
    ["parallel"]  = 0x192432ff,
    ["bypass"]    = 0xdc5454ff,
    ["enabled"]   = 0x49cc85FF,
    ["wire"]      = 0xB0B0B9FF,
}

local LINE_POINTS, FX_DATA, PLUGINS, CANVAS

local function InitCanvas()
    return { view_x = 0, view_y = 0, off_x = 0, off_y = 50, scale = 1 }
end

--CANVAS = InitCanvas()

local FX_LIST, CAT = GetFXTbl()

local ctx = r.ImGui_CreateContext('CONTAINERS_NO_ZOOM')

ICONS_FONT = r.ImGui_CreateFont(script_path .. 'Icons.ttf', 13)
r.ImGui_Attach(ctx, ICONS_FONT)

local draw_list = r.ImGui_GetWindowDrawList(ctx)

local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
local WND_FLAGS = r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse()

local TrackFX_GetNamedConfigParm = r.TrackFX_GetNamedConfigParm
local TrackFX_GetFXGUID = r.TrackFX_GetFXGUID
local TrackFX_GetCount = r.TrackFX_GetCount
local TRACK

local def_s_frame_x, def_s_frame_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
local def_s_spacing_x, def_s_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
local def_s_window_x, def_s_window_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())

local s_frame_x, s_frame_y = def_s_frame_x, def_s_frame_y
local s_spacing_x, s_spacing_y = def_s_spacing_x, item_spacing_vertical and item_spacing_vertical or def_s_spacing_y
local s_window_x, s_window_y = def_s_window_x, def_s_window_y

local function serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0
    local tmp = string.rep(" ", depth)
    if name then
        if type(name) == "number" and math.floor(name) == name then
            name = "[" .. name .. "]"
        elseif not string.match(name, '^[a-zA-z_][a-zA-Z0-9_]*$') then
            name = string.gsub(name, "'", "\\'")
            name = "['" .. name .. "']"
        end
        tmp = tmp .. name .. " = "
    end
    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            tmp = tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end
    return tmp
end

local function tableToString(table)
    return serializeTable(table)
end

local function stringToTable(str)
    local f, err = load("return " .. str)
    return f ~= nil and f() or nil
end

local function Store_To_PEXT(last_track)
    if not last_track then return end
    local storedTable = {}
    if r.ValidatePtr(last_track, "MediaTrack*") then
        storedTable.CANVAS = CANVAS
    end
    local serialized = tableToString(storedTable)
    if r.ValidatePtr(last_track, "MediaTrack*") then
        r.GetSetMediaTrackInfo_String(last_track, "P_EXT:PARANORMAL_FX", serialized, true)
    end
end

local function Restore_From_PEXT()
    local rv, stored
    if r.ValidatePtr(TRACK, "MediaTrack*") then
        rv, stored = r.GetSetMediaTrackInfo_String(TRACK, "P_EXT:PARANORMAL_FX", "", false)
    end
    if rv == true and stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            if r.ValidatePtr(TRACK, "MediaTrack*") then
                CANVAS = storedTable.CANVAS
            end
            return true
        end
    end
end

local crash = function(errObject)
    local byLine = "([^\r\n]*)\r?\n?"
    local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
    local err = errObject and string.match(errObject, trimPath) or "Couldn't get error message."
    local trace = debug.traceback()
    local stack = {}
    for line in string.gmatch(trace, byLine) do
        local str = string.match(line, trimPath) or line
        stack[#stack + 1] = str
    end
    local name = ({ r.get_action_context() })[2]:match("([^/\\_]+)$")
    local ret =
        r.ShowMessageBox(
            name .. " has crashed!\n\n" .. "Would you like to have a crash report printed " .. "to the Reaper console?",
            "Oops",
            4
        )
    if ret == 6 then
        r.ShowConsoleMsg(
            "Error: " .. err .. "\n\n" ..
            "Stack traceback:\n\t" .. r.concat(stack, "\n\t", 2) .. "\n\n" ..
            "Reaper:       \t" .. r.GetAppVersion() .. "\n" ..
            "Platform:     \t" .. r.GetOS()
        )
    end
end

function GetCrash() return crash end

local function Tooltip(str)
    if IS_DRAGGING_RIGHT_CANVAS then return end
    if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_BeginTooltip(ctx)
        r.ImGui_Text(ctx, str)
        r.ImGui_EndTooltip(ctx)
    end
end

local function adjustBrightness(channel, delta)
    return math.min(255, math.max(0, channel + delta))
end

local function SplitColorChannels(color)
    local alpha = color & 0xFF
    local blue = (color >> 8) & 0xFF
    local green = (color >> 16) & 0xFF
    local red = (color >> 24) & 0xFF
    return red, green, blue, alpha
end

local function HexTest(color, amt)
    local red, green, blue, alpha = SplitColorChannels(color)
    alpha = adjustBrightness(alpha, amt)
    blue = adjustBrightness(blue, amt)
    green = adjustBrightness(green, amt)
    red = adjustBrightness(red, amt)
    return (alpha) | (blue << 8) | (green << 16) | (red << 24)
end

local function CalculateFontColor(color)
    local red, green, blue, alpha = SplitColorChannels(color)
    local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;
    if (luminance > 0.5) then
        return 0xFF
    else
        return 0xFFFFFFFF
    end
end

local function MyKnob(label, style, p_value, v_min, v_max, is_vol, is_pan)
    local radius_outer = Knob_Radius
    local pos = { r.ImGui_GetCursorScreenPos(ctx) }
    local center = { pos[1] + radius_outer, pos[2] + radius_outer }
    local line_height = r.ImGui_GetTextLineHeight(ctx)
    local item_inner_spacing = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()) }
    local mouse_delta = { r.ImGui_GetMouseDelta(ctx) }

    local ANGLE_MIN = 3.141592 * 0.75
    local ANGLE_MAX = 3.141592 * 2.25

    r.ImGui_InvisibleButton(ctx, label, radius_outer * 2, radius_outer * 2)
    local value_changed = false
    local is_active = r.ImGui_IsItemActive(ctx)
    local is_hovered = r.ImGui_IsItemHovered(ctx)
    if is_active and mouse_delta[2] ~= 0.0 then
        local step = (v_max - v_min) / (CTRL and 1000 or 200.0)
        p_value = p_value + (-mouse_delta[2] * step)
        if p_value < v_min then p_value = v_min end
        if p_value > v_max then p_value = v_max end
        value_changed = true
    end

    local t = (p_value - v_min) / (v_max - v_min)
    local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
    local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
    local radius_inner = radius_outer / 2.5
    r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer - 1, COLOR["parallel"])
    if style == "knob" then
        r.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos * radius_inner, center[2] + angle_sin * radius_inner,
            center[1] + angle_cos * (radius_outer - 2), center[2] + angle_sin * (radius_outer - 2),
            COLOR["ROOT"], 2.0)
        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner,
            r.ImGui_GetColor(ctx,
                is_active and r.ImGui_Col_FrameBgActive() or is_hovered and r.ImGui_Col_FrameBgHovered() or
                r.ImGui_Col_FrameBg()), 16)
        r.ImGui_DrawList_AddText(draw_list, pos[1], pos[2] + radius_outer * 2 + item_inner_spacing[2],
            r.ImGui_GetColor(ctx, r.ImGui_Col_Text()), label)
    elseif style == "arc" then
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 1.5, ANGLE_MIN, angle)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColorEx(ctx, COLOR["ROOT"]), nil, radius_inner)
        r.ImGui_DrawList_PathClear(draw_list)
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 1.5, ANGLE_MAX, angle)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColorEx(ctx, 0x151515ff), nil, radius_inner)
        r.ImGui_DrawList_PathClear(draw_list)
    elseif style == "dry_wet" then
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 1.5, ANGLE_MIN, angle)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColorEx(ctx, 0x3a87ffff), nil, radius_inner)
        r.ImGui_DrawList_PathClear(draw_list)
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 1.5, ANGLE_MAX, angle)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColorEx(ctx, 0x151515ff), nil, radius_inner)
        r.ImGui_DrawList_PathClear(draw_list)
    end

    if is_active or is_hovered then
        local window_padding = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) }
        r.ImGui_SetNextWindowPos(ctx, pos[1] - window_padding[1],
            pos[2] - line_height - (item_inner_spacing[2] * 2) - window_padding[2])
        r.ImGui_BeginTooltip(ctx)
        if is_vol then
            r.ImGui_Text(ctx, "VOL :" .. ('%.0f'):format(p_value))
        else
            if is_pan then
                r.ImGui_Text(ctx, "PAN :" .. ('%.0f'):format(p_value))
            else
                r.ImGui_Text(ctx, ('%.0f'):format(100 - p_value) .. " DRY / WET " .. ('%.0f'):format(p_value))
            end
        end
        r.ImGui_EndTooltip(ctx)
    end

    return value_changed, p_value
end

local function OpenFX(id)
    local open = r.TrackFX_GetFloatingWindow(TRACK, id)
    r.TrackFX_Show(TRACK, id, open and 2 or 3)
end

local function AddFX(name)
    if not TRACK or not FX_ID then return end
    local idx = FX_ID[1] > 0x2000000 and FX_ID[1] or -1000 - FX_ID[1]
    local new_fx_id = r.TrackFX_AddByName(TRACK, name, false, idx)
    if FX_ID[2] then r.TrackFX_SetNamedConfigParm(TRACK, FX_ID[1], "parallel", "1") end
    LAST_USED_FX = name
    return new_fx_id ~= -1 and new_fx_id or nil
end

local function DragAddDDSource(fx)
    if r.ImGui_BeginDragDropSource(ctx) then
        DRAG_ADD_FX = true
        r.ImGui_SetDragDropPayload(ctx, 'DRAG ADD FX', fx)
        r.ImGui_Text(ctx, CTRL and "REPLACE" or "ADD")
        r.ImGui_SameLine(ctx)
        r.ImGui_Button(ctx, fx)
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

local function Filter_actions(filter_text)
    filter_text = Lead_Trim_ws(filter_text)
    local t = {}
    if filter_text == "" or not filter_text then return t end
    for i = 1, #FX_LIST do
        local action = FX_LIST[i]
        local name = action:lower()
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then t[#t + 1] = action end
    end
    return t
end

local function SetMinMax(Input, Min, Max)
    if Input >= Max then
        Input = Max
    elseif Input <= Min then
        Input = Min
    else
        Input = Input
    end
    return Input
end

local FILTER = ''
local function FilterBox()
    local MAX_FX_SIZE = 300
    r.ImGui_PushItemWidth(ctx, MAX_FX_SIZE)
    if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end
    _, FILTER = r.ImGui_InputTextWithHint(ctx, '##input', "SEARCH FX", FILTER)
    local filtered_fx = Filter_actions(FILTER)
    local filter_h = #filtered_fx == 0 and 0 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx))
    ADDFX_Sel_Entry = SetMinMax(ADDFX_Sel_Entry or 1, 1, #filtered_fx)
    if #filtered_fx ~= 0 then
        if r.ImGui_BeginChild(ctx, "##popupp", MAX_FX_SIZE, filter_h) then
            for i = 1, #filtered_fx do
                if r.ImGui_Selectable(ctx, filtered_fx[i], i == ADDFX_Sel_Entry) then
                    AddFX(filtered_fx[i])
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                DragAddDDSource(filtered_fx[i])
            end
            r.ImGui_EndChild(ctx)
        end
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            AddFX(filtered_fx[ADDFX_Sel_Entry])
            ADDFX_Sel_Entry = nil
            FILTER = ''
            r.ImGui_CloseCurrentPopup(ctx)
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry - 1
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry + 1
        end
    end
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        FILTER = ''
        r.ImGui_CloseCurrentPopup(ctx)
    end
    return #filtered_fx ~= 0
end

local function DrawFxChains(tbl, path)
    local extension = ".RfxChain"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                DrawFxChains(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                AddFX(table.concat({ path, os_separator, tbl[i], extension }))
            end
            DragAddDDSource(table.concat({ path, os_separator, tbl[i], extension }))
        end
    end
end

local function LoadTemplate(template, replace)
    local track_template_path = r.GetResourcePath() .. "/TrackTemplates" .. template
    if replace then
        if not TRACK then return end
        local chunk = GetFileContext(track_template_path)
        r.SetTrackStateChunk(TRACK, chunk, true)
    else
        r.Main_openProject(track_template_path)
    end
end

local function DrawTrackTemplates(tbl, path)
    local extension = ".RTrackTemplate"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                local cur_path = table.concat({ path, os_separator, tbl[i].dir })
                DrawTrackTemplates(tbl[i], cur_path)
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                local template_str = table.concat({ path, os_separator, tbl[i], extension })
                LoadTemplate(template_str) -- ADD NEW TRACK FROM TEMPLATE
            end
        end
    end
end

local function DrawItems(tbl)
    for i = 1, #tbl do
        if r.ImGui_BeginMenu(ctx, tbl[i].name) then
            for j = 1, #tbl[i].fx do
                if tbl[i].fx[j] then
                    if r.ImGui_Selectable(ctx, tbl[i].fx[j]) then
                        AddFX(tbl[i].fx[j])
                    end
                    DragAddDDSource(tbl[i].fx[j])
                end
            end
            r.ImGui_EndMenu(ctx)
        end
    end
end

function DrawFXList()
    local search = FilterBox()
    if search then return end
    for i = 1, #CAT do
        if r.ImGui_BeginMenu(ctx, CAT[i].name) then
            if CAT[i].name == "FX CHAINS" then
                DrawFxChains(CAT[i].list)
            elseif CAT[i].name == "TRACK TEMPLATES" then
                DrawTrackTemplates(CAT[i].list)
            else
                DrawItems(CAT[i].list)
            end
            r.ImGui_EndMenu(ctx)
        end
    end
    if r.ImGui_Selectable(ctx, "CONTAINER") then AddFX("Container") end
    DragAddDDSource("Container")
    --if r.ImGui_Selectable(ctx, "VIDEO PROCESSOR") then AddFX("Video processor") end
    --DragAddDDSource("Video processor")
    if r.ImGui_Selectable(ctx, "VOLUME-PAN UTILITY") then AddFX("JS:Volume/Pan Smoother") end
    DragAddDDSource("JS:Volume/Pan Smoother")
    if LAST_USED_FX then
        if r.ImGui_Selectable(ctx, "RECENT: " .. LAST_USED_FX) then AddFX(LAST_USED_FX) end
        DragAddDDSource(LAST_USED_FX)
    end
end

local function UpdateScroll()
    if not TRACK then return end
    local btn = r.ImGui_MouseButton_Right()
    if r.ImGui_IsMouseDragging(ctx, btn) then
        r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeAll())
        local drag_x, drag_y = r.ImGui_GetMouseDragDelta(ctx, nil, nil, btn)
        CANVAS.off_x, CANVAS.off_y = CANVAS.off_x + drag_x, CANVAS.off_y + drag_y
        r.ImGui_ResetMouseDragDelta(ctx, btn)
    end
end

local function EndUndoBlock(str)
    r.Undo_EndBlock("PARANORMAL: " .. str, 0)
end

local function CalcFxID(tbl, idx)
    if tbl.type == "Container" then
        return 0x2000000 + tbl.ID + (tbl.DIFF * idx)
    elseif tbl.type == "ROOT" then
        return idx - 1
    end
end

local para_btn_size = r.ImGui_CalcTextSize(ctx, "||") + (s_frame_x * 2)
local function CalculateItemWH(tbl)
    local tw, th = r.ImGui_CalcTextSize(ctx, tbl.name)
    local iw, ih = tw + (s_frame_x * 2), th + (s_frame_y * 2)
    return iw, custom_btn_h and custom_btn_h or ih
end

local def_btn_h = custom_btn_h and custom_btn_h or ({ CalculateItemWH({ name = "||" }) })[2]
local mute = para_btn_size
local volume = para_btn_size
local function CalcContainerWH(fx_items)
    local rows = {}
    local W, H = 0, 0
    for i = 1, #fx_items do
        if fx_items[i].p == 0 or (i == 1 and fx_items[i].p > 0) then
            rows[#rows + 1] = {}
            table.insert(rows[#rows], i)
        else
            table.insert(rows[#rows], i)
        end
    end

    local btn_total_size = def_btn_h + (s_spacing_y)
    local start_n_add_btn_size = s_spacing_y + (def_btn_h * 2)

    for i = 1, #rows do
        local col_w, col_h = 0, 0
        if #rows[i] > 1 then
            for j = 1, #rows[i] do
                local w = fx_items[rows[i][j]].W and fx_items[rows[i][j]].W or
                    CalculateItemWH(fx_items[rows[i][j]]) + mute + volume
                local h = fx_items[rows[i][j]].H and
                    fx_items[rows[i][j]].H + s_spacing_y + btn_total_size or
                    (btn_total_size * 2)

                col_w = col_w + w
                if h > col_h then col_h = h end
            end
            col_w = col_w + (s_spacing_x * (#rows[i] - 1))
            col_w = col_w + (para_btn_size // 2)
        else
            local w = fx_items[rows[i][1]].W and fx_items[rows[i][1]].W + mute + s_spacing_x or
                CalculateItemWH(fx_items[rows[i][1]]) + mute + volume + s_spacing_x
            local h = fx_items[rows[i][1]].H and fx_items[rows[i][1]].H + s_spacing_y + btn_total_size or
                btn_total_size * 2
            H = H + h
            if w > col_w then col_w = w end
        end
        if col_w > W then W = col_w end
        H = H + col_h
    end
    W = W + (s_window_x * 2) + s_spacing_x + mute + volume + para_btn_size

    H = H + start_n_add_btn_size + (s_window_y * 2)
    return W, H
end

local function IterateContainer(depth, track, container_id, parent_fx_count, previous_diff, container_guid, target)
    local row = 1
    local child_fx = {
        [0] = {
            IDX = 1,
            name = "DUMMY",
            type = "INSERT_POINT",
            p = 0,
            guid = "insertpoint_0" .. container_guid,
            pid = container_guid,
            ROW = 0,
        }
    }
    local container_fx_count = tonumber(({ TrackFX_GetNamedConfigParm(track, 0x2000000 + container_id,
        "container_count") })[2])
    local diff = depth == 0 and parent_fx_count + 1 or (parent_fx_count + 1) * previous_diff

    -- CALCULATER DEFAULT WIDTH
    local _, parrent_cont_name = r.TrackFX_GetFXName(track, 0x2000000 + container_id)
    local total_w = CalculateItemWH({ name = parrent_cont_name })
    -- CALCULATER DEFAULT WIDTH

    for i = 1, container_fx_count do
        local fx_id = container_id + (diff * i)
        local fx_guid = TrackFX_GetFXGUID(TRACK, 0x2000000 + fx_id)
        local _, fx_name = r.TrackFX_GetFXName(track, 0x2000000 + fx_id)
        local _, fx_type = TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "fx_type")
        local _, para = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "parallel")
        local wetparam = r.TrackFX_GetParamFromIdent(track, 0x2000000 + fx_id, ":wet")
        local wet_val = r.TrackFX_GetParam(track, 0x2000000 + fx_id, wetparam)
        local bypass = r.TrackFX_GetEnabled(track, 0x2000000 + fx_id)
        para = i == 1 and "0" or para -- MAKE FIRST ITEMS ALWAYS SERIAL (FIRST ITEMS ARE SAME IF IN PARALELL OR SERIAL)

        if i > 1 then row = para == "0" and row + 1 or row end

        local name_w = CalculateItemWH({ name = fx_name })

        if name_w > total_w then total_w = name_w end

        child_fx[#child_fx + 1] = {
            FX_ID = fx_id,
            type = fx_type,
            name = fx_name,
            IDX = i,
            pid = container_guid,
            guid = fx_guid,
            p = tonumber(para),
            bypass = bypass,
            ROW = row,
            INSERT_POINT = { pid = container_guid },
            wetparam = wetparam,
            wet_val = wet_val,
        }

        if fx_type == "Container" then
            local sub_tbl, sub_W, sub_H = IterateContainer(depth + 1, track, fx_id, container_fx_count, diff, fx_guid,
                target)
            if sub_tbl then
                child_fx[#child_fx].sub = sub_tbl
                child_fx[#child_fx].depth = depth + 1
                child_fx[#child_fx].DIFF = diff * (container_fx_count + 1)
                child_fx[#child_fx].ID = fx_id -- CONTAINER ID (HERE ITS NOT THE SAME AS IDX WHICH IS FOR FX ITEMS)
                child_fx[#child_fx].W = sub_W
                child_fx[#child_fx].H = sub_H
            end
        end
    end

    total_w = total_w + mute + volume + (s_window_x * 2)

    local C_W, C_H = CalcContainerWH(child_fx)
    if C_W > total_w then total_w = C_W end

    return child_fx, total_w, C_H
end

local function GetFx(guid)
    return FX_DATA[guid]
end

local function GetOrUpdateFX(target)
    local track = TRACK
    PLUGINS[0] = {
        FX_ID = -1,
        name = "FX CHAIN",
        type = "ROOT",
        guid = "ROOT",
        pid = "ROOT",
        ID = -1,
        p = 0,
        ROW = 0,
        bypass = r.GetMediaTrackInfo_Value(TRACK, "I_FXEN") == 1
    }

    local row = 1
    local total_fx_count = TrackFX_GetCount(track)
    for i = 1, total_fx_count do
        local fx_guid = TrackFX_GetFXGUID(TRACK, i - 1)
        local _, fx_type = TrackFX_GetNamedConfigParm(track, i - 1, "fx_type")
        local _, fx_name = r.TrackFX_GetFXName(track, i - 1)
        local _, para = r.TrackFX_GetNamedConfigParm(track, i - 1, "parallel")
        local wetparam = r.TrackFX_GetParamFromIdent(track, i - 1, ":wet")
        local wet_val = r.TrackFX_GetParam(track, i - 1, wetparam)
        local bypass = r.TrackFX_GetEnabled(track, i - 1)

        if i > 1 then row = para == "0" and row + 1 or row end

        para = i == 1 and "0" or para -- MAKE FIRST ITEMS ALWAYS SERIAL (FIRST ITEMS ARE SAME IF IN PARALELL OR SERIAL)

        PLUGINS[#PLUGINS + 1] = {
            FX_ID = i,
            type = fx_type,
            name = fx_name,
            IDX = i,
            guid = fx_guid,
            pid = "ROOT",
            p = tonumber(para),
            bypass = bypass,
            ROW = row,
            INSERT_POINT = { pid = "ROOT" },
            wetparam = wetparam,
            wet_val = wet_val,
        }
        if fx_type == "Container" then
            local sub_plugins, W, H = IterateContainer(0, track, i, total_fx_count, 0, fx_guid, target)
            if sub_plugins then
                PLUGINS[#PLUGINS].sub = sub_plugins
                PLUGINS[#PLUGINS].depth = 0
                PLUGINS[#PLUGINS].DIFF = (total_fx_count + 1)
                PLUGINS[#PLUGINS].ID = i -- CONTAINER ID (AT ROOT LEVEL SAME AS IDX BUT FOR READABILITY WILL KEEP IT)
                PLUGINS[#PLUGINS].W = W
                PLUGINS[#PLUGINS].H = H
            end
        end
    end
end

local function GetParentContainerByGuid(tbl)
    return tbl.type == "ROOT" and tbl or GetFx(tbl.pid)
end

local function DragAddDDTarget(tbl, i, parallel)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DRAG ADD FX')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local parrent_container = GetParentContainerByGuid(tbl[i])
            local item_add_id = CalcFxID(parrent_container, i + 1)
            FX_ID = { item_add_id, parallel }
            --AddFX(payload)
            return AddFX(payload)
        end
    end
end

local function SwapParallelInfo(src, dst)
    local _, src_p = r.TrackFX_GetNamedConfigParm(TRACK, src, "parallel")
    local _, dst_p = r.TrackFX_GetNamedConfigParm(TRACK, dst, "parallel")
    r.TrackFX_SetNamedConfigParm(TRACK, src, "parallel", dst_p)
    r.TrackFX_SetNamedConfigParm(TRACK, dst, "parallel", src_p)
end

local function CheckNextItemParallel(i, parrent_container)
    local src = CalcFxID(parrent_container, i)
    local dst = CalcFxID(parrent_container, i + 1)
    if not r.TrackFX_GetFXGUID(TRACK, dst) then return end
    local _, para = r.TrackFX_GetNamedConfigParm(TRACK, dst, "parallel")
    if para == "1" then SwapParallelInfo(src, dst) end
end

local function RemoveAllFX()
    r.PreventUIRefresh(1)
    r.Undo_BeginBlock()
    for i = r.TrackFX_GetCount(TRACK), 1, -1 do
        r.TrackFX_Delete(TRACK, i - 1)
    end
    r.PreventUIRefresh(-1)
    EndUndoBlock("REMOVE ALL TRACK FX")
end

local function ButtonAction(tbl, i)
    local parrent_container = GetParentContainerByGuid(tbl[i])
    local item_id = CalcFxID(parrent_container, i)
    if ALT then
        if tbl[i].type == "ROOT" then
            RemoveAllFX()
            return
        end
        CheckNextItemParallel(i, parrent_container)
        r.TrackFX_Delete(TRACK, item_id)
    else
        OpenFX(item_id)
    end
end

local function IsChild(parrent_guid, target)
    local found
    local dst = target
    while not found do
        if dst.type == "ROOT" then break end
        if dst.pid == parrent_guid then
            found = parrent_guid
            break
        else
            -- KEEP TRYING UNTIL ROOT IS FOUND
            dst = GetFx(dst.pid)
        end
    end
    return found
end

local function IsItemChildOfContainer(src_fx, dst_fx, insert_point, insert_type)
    -- DO NOT MOVE CONTAINER INTO ITS CHILDS
    if src_fx.type == "Container" then
        local dst_is_child = IsChild(src_fx.guid, dst_fx)
        if dst_is_child then return true end
    end
    if dst_fx.type == "Container" then
        if insert_point then
            --if IsItemChildOfContainer2(dst_fx, insert_point) then return true end
        else
            local src_is_child = IsChild(dst_fx.guid, src_fx)
            if src_is_child then return true end
        end
    end
end

local function Swap(src_parrent_guid, prev_src_id, dst_guid)
    -- UPDATE FX TABLE DATA WITH NEW IDS
    UpdateFxData()
    -- GET NEW PARRENT ID
    local src_parrent = GetFx(src_parrent_guid)
    local src_item_id = CalcFxID(src_parrent, prev_src_id)

    -- GET RECALCULATED DST
    local dst_fx = GetFx(dst_guid)
    local dst_parrent = GetParentContainerByGuid(dst_fx)
    local dst_item_id = CalcFxID(dst_parrent, dst_fx.IDX)

    r.TrackFX_CopyToTrack(TRACK, dst_item_id, TRACK, src_item_id, true)
end

local function MoveDDTarget(tbl, i, is_move, insert_point)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'MOVE')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local src_guid, src_id = payload:match("(.+),(.+)")
            local src_fx = GetFx(src_guid)

            local dst_guid, dst_fx, dst_id = tbl.guid, GetFx(tbl.guid), i

            local src_parrent = GetParentContainerByGuid(src_fx)
            local src_item_id = CalcFxID(src_parrent, src_id)

            local dst_parrent = GetParentContainerByGuid(dst_fx)

            -- MOVING ON SAME LEVEL IS FUNKY WITH DESTINATION ID
            if is_move then
                if src_parrent.guid == dst_parrent.guid then
                    if not CTRL_DRAG then
                        dst_id = tonumber(src_id) > dst_id and dst_id + 1 or dst_id
                    else
                        dst_id = dst_id + 1
                    end
                else
                    dst_id = dst_id + 1
                end
                -- IF NEXT ITEM IS PARALLEL MOVE PARALLEL INFO TO IT
                if not CTRL_DRAG then CheckNextItemParallel(src_id, src_parrent) end
            end
            local dst_item_id = CalcFxID(dst_parrent, dst_id)

            -- DO NOT MOVE CONTAINERS IN ITS CHILDS
            if IsItemChildOfContainer(src_fx, dst_fx, insert_point, is_move) then return end

            r.Undo_BeginBlock()

            if not is_move then
                -- IF SWAPPING FX SWAP THEIR PARALLEL INFO
                SwapParallelInfo(src_item_id, dst_item_id)
            elseif is_move == "serial" and not CTRL_DRAG then
                -- MAKE PARALLEL INFO SERIAL (MOVING TO INSERT POINTS)
                r.TrackFX_SetNamedConfigParm(TRACK, src_item_id, "parallel", "0")
            elseif is_move == "parallel" and not CTRL_DRAG then
                -- DO NOT MOVE PARALLEL TO ITSELF
                if src_fx.guid == dst_fx.guid then return end
                -- MAKE PARALLEL INFO PARALLEL (MOVING TO PARALLEL BUTTON)
                r.TrackFX_SetNamedConfigParm(TRACK, src_item_id, "parallel", "1")
            end

            if is_move then
                r.TrackFX_CopyToTrack(TRACK, src_item_id, TRACK, dst_item_id, not CTRL_DRAG)
                if CTRL_DRAG then
                    -- SET NEW PARALLEL INFO WHEN COPIED
                    local para_info = is_move == "parallel" and "1" or "0"
                    r.TrackFX_SetNamedConfigParm(TRACK, dst_item_id, "parallel", para_info)
                end
                EndUndoBlock("Move Plugins")
                return
            end
            -- SWAP SOURCE AND DESTINATION
            r.TrackFX_CopyToTrack(TRACK, src_item_id, TRACK, dst_item_id, true)
            Swap(src_parrent.guid, src_id, dst_guid)
            EndUndoBlock("Move Plugins")
        end
    end
end

local function MoveDDSource(tbl, i)
    if r.ImGui_BeginDragDropSource(ctx) then
        local data = table.concat({ tbl.guid, i }, ",")
        DRAG_MOVE = true
        r.ImGui_SetDragDropPayload(ctx, "MOVE", data)
        r.ImGui_Text(ctx, CTRL_DRAG and "COPY -" or "MOVE -")
        r.ImGui_SameLine(ctx)
        r.ImGui_Button(ctx, tbl.name)
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function DragAndDropMove(tbl, i)
    MoveDDSource(tbl[i], i)
    MoveDDTarget(tbl[i], i)
end

local function ParallelRowWidth(tbl, i, item_width)
    local total_w, total_h = 0, tbl[i].H and tbl[i].H - s_spacing_y or 0
    local idx = i + 1
    local last_big_idx = i
    while true do
        if not tbl[idx] then break end
        if tbl[idx].p == 0 then
            break
        else
            local width = tbl[idx].W and tbl[idx].W or CalculateItemWH(tbl[idx]) + mute + volume
            local height = tbl[idx].H and tbl[idx].H - s_spacing_y or 0

            if total_h < height then
                total_h = height
                last_big_idx = idx
            end
            total_w = total_w + width + s_spacing_x
            idx = idx + 1
        end
    end
    if last_big_idx then
        tbl[last_big_idx].biggest = true
    end
    return total_w + item_width - para_btn_size
end

local ROUND_FLAG = {
    ["L"] = r.ImGui_DrawFlags_RoundCornersTopLeft()|r.ImGui_DrawFlags_RoundCornersBottomLeft(),
    ["R"] = r.ImGui_DrawFlags_RoundCornersTopRight()|r.ImGui_DrawFlags_RoundCornersBottomRight()
}

local function DrawListButton(name, color, round_side, icon, hover)
    local multi_color = IS_DRAGGING_RIGHT_CANVAS and color or HexTest(color, hover and 50 or 0)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local round_flag = round_side and ROUND_FLAG[round_side] or nil
    local round_amt = round_flag and ROUND_CORNER or 0

    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, r.ImGui_GetColorEx(ctx, multi_color), round_amt,
        round_flag)
    if r.ImGui_IsItemActive(ctx) then
        r.ImGui_DrawList_AddRect(draw_list, xs - 2, ys - 2, xe + 2, ye + 2, 0x22FF44FF, 3, nil, 2)
    end

    if icon then r.ImGui_PushFont(ctx, ICONS_FONT) end

    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local FONT_SIZE = r.ImGui_GetFontSize(ctx)
    local font_color = CalculateFontColor(color)

    r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, xs + (w / 2) - (label_size / 2),
        ys + ((h / 2)) - FONT_SIZE / 2, r.ImGui_GetColorEx(ctx, font_color), name)
    if icon then r.ImGui_PopFont(ctx) end
end

local function AddFX_P(tbl, i)
    r.ImGui_SameLine(ctx)
    r.ImGui_PushID(ctx, tbl[i].guid .. "parallel")
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), (DRAG_ADD_FX and (DRAG_ADD_FX and not CTRL and 1 or 0.3)) or 1) -- alpha

    if r.ImGui_InvisibleButton(ctx, "||", para_btn_size, def_btn_h) then
        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_add_id = CalcFxID(parrent_container, i + 1)
        FX_ID = { item_add_id, "parallel" }
        OPEN_FX_LIST = true
    end
    Tooltip("ADD NEW PARALLEL FX")
    r.ImGui_PopID(ctx)

    if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 1) then
        if tbl[i].p > 0 then
            OPEN_RIGHT_C_CTX_PARALLEL = true
            PARA_DATA = { tbl, i }
        end
    end

    DrawListButton("||", (DRAG_ADD_FX or DRAG_MOVE) and HexTest(COLOR["n"], 10) or COLOR["parallel"])
    if not CTRL then
        DragAddDDTarget(tbl, i, "parallel")
    end
    MoveDDTarget(tbl[i], i, "parallel", tbl[i].INSERT_POINT)
    r.ImGui_PopStyleVar(ctx)
end

local function DrawLines()
    for i = 1, #LINE_POINTS do
        local p_tbl = LINE_POINTS[i]
        r.ImGui_DrawList_AddLine(draw_list, p_tbl[1], p_tbl[2], p_tbl[3], p_tbl[4], COLOR["wire"], WireThickness)
    end
end

local function InsertPointButton(tbl, i, x)
    r.ImGui_SetCursorPosX(ctx, x - (add_bnt_size // 2))
    r.ImGui_PushID(ctx, tbl[i].guid .. "insert_point")
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), DRAG_ADD_FX and (DRAG_ADD_FX and not CTRL and 1 or 0.3) or 1) -- alpha
    if r.ImGui_InvisibleButton(ctx, "+", add_bnt_size, def_btn_h) then
        CLICKED = tbl[i].guid
        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_add_id = CalcFxID(parrent_container, i + 1)
        FX_ID = { item_add_id }
        OPEN_FX_LIST = true
    end
    r.ImGui_PopID(ctx)
    Tooltip("ADD NEW SERIAL FX")
    if not CTRL then
        DragAddDDTarget(tbl, i)
    end
    if i == #tbl or (r.ImGui_IsItemHovered(ctx) and not IS_DRAGGING_RIGHT_CANVAS) or DRAG_MOVE or DRAG_ADD_FX or CLICKED == tbl[i].guid then
        DrawListButton("+", (DRAG_ADD_FX or DRAG_MOVE) and HexTest(COLOR["n"], 10) or COLOR["parallel"])
    end
    r.ImGui_PopStyleVar(ctx)
    MoveDDTarget(tbl[i], i, "serial", tbl[i].INSERT_POINT)
end

local function CheckFX_P(tbl, i)
    if i == 0 then return end
    if tbl[i].p == 0 then
        if (tbl[i + 1] and tbl[i + 1].p + tbl[i].p == 0) or not tbl[i + 1] then
            AddFX_P(tbl, i)
        end
    else
        if tbl[i + 1] and tbl[i + 1].p + tbl[i].p == 1 or not tbl[i + 1] then
            AddFX_P(tbl, i)
        end
    end
end

local function AddInsertPoints(tbl, i, x)
    if tbl[i + 1] and tbl[i + 1].p == 0 or not tbl[i + 1] then
        InsertPointButton(tbl, i, x)
        return true
    end
end

local function TypToColor(tbl)
    local color = COLOR[tbl.type] and COLOR[tbl.type] or COLOR["n"]
    return tbl.bypass and color or HexTest(COLOR["bypass"], -40)
end

local function AutoCreateContainer(tbl, i)
    if not DRAG_ADD_FX then return end
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)

    --local w, h = (xe - xs), (ye - ys)

    if r.ImGui_IsMouseHoveringRect(ctx, xs, ys, xe, ye, false) then
        --r.ShowConsoleMsg()
        r.ImGui_DrawList_AddRect(draw_list, xs - mute, ys - mute // 2, xe + mute, ye + mute // 2,
            r.ImGui_GetColorEx(ctx, COLOR["enabled"]), 2)
    end
    local inserted_fx_id = DragAddDDTarget(tbl, i)
    if inserted_fx_id then
        local parrent_container = GetParentContainerByGuid(tbl[i])
        local target_fx_guid = tbl[i].guid
        local inserted_fx_guid = r.TrackFX_GetFXGUID(TRACK, inserted_fx_id)
        local c_idx = r.TrackFX_AddByName(TRACK, "Container", false,
            inserted_fx_id < 0x2000000 and (-1000 - inserted_fx_id - 1) or inserted_fx_id)
        local C_guid = r.TrackFX_GetFXGUID(TRACK, c_idx)
        --CalcFxID(parrent_container, i + 1)
        --r.ShowConsoleMsg(C_guid)
        for j = 1, 2 do
            UpdateFxData()

            --local src_parrent = GetParentContainerByGuid(target_fx_guid)
            local cont = GetFx(C_guid)

            local src_fx = j == 1 and GetFx(target_fx_guid) or GetFx(inserted_fx_guid)
            -- r.ShowConsoleMsg(src_fx.ID)

            --local dst_parrent = GetParentContainerByGuid(dst_fx)
            -- local src_fx
            --local container = GetFx(C_guid)
            --local c_id = CalcFxID(container, 1)
            --if i == 1 then
            --    src_fx = CalcFxID(parrent_container, GetFx(target_fx_guid).IDX)
            --else
            --    src_fx = CalcFxID(parrent_container, GetFx(target_fx_guid).IDX)
            --end
            local id = 0x2000000 + cont.ID + cont.DIFF

            r.TrackFX_CopyToTrack(TRACK, src_fx.IDX, TRACK, id, true)
        end

        --local c_guid = r.TrackFX_GetFXGUID(TRACK, c_idx)
    end
end

local function DrawVolumePanHelper(tbl, i, w)
    if tbl[i].name:match(VOL_PAN_HELPER) then
        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_id = CalcFxID(parrent_container, i)
        local vol_val = r.TrackFX_GetParam(TRACK, item_id, 0) -- 0 IS VOL IDENTIFIER
        r.ImGui_SameLine(ctx, nil, mute)
        r.ImGui_PushID(ctx, tbl[i].guid .. "helper_vol")
        local rvh_v, v = MyKnob("", "arc", vol_val, -60, 12, true)
        if rvh_v then
            r.TrackFX_SetParam(TRACK, item_id, 0, v)
        end
        local vol_hover = r.ImGui_IsItemHovered(ctx)
        if vol_hover and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
            r.TrackFX_SetParam(TRACK, item_id, 0, 0)
        end

        r.ImGui_PopID(ctx)
        r.ImGui_SameLine(ctx, nil, w - (mute * 4))
        local pan_val = r.TrackFX_GetParam(TRACK, item_id, 1) -- 1 IS PAN IDENTIFIER
        r.ImGui_PushID(ctx, tbl[i].guid .. "helper_pan")
        local rvh_p, p = MyKnob("", "knob", pan_val, -100, 100, nil, true)
        if rvh_p then
            r.TrackFX_SetParam(TRACK, item_id, 1, p)
        end
        local pan_hover = r.ImGui_IsItemHovered(ctx)
        if pan_hover and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
            r.TrackFX_SetParam(TRACK, item_id, 1, 0)
        end

        r.ImGui_PopID(ctx)
        return mute, vol_hover, pan_hover
    end
end

local function DrawButton(tbl, i, name, width, fade, del_color)
    if tbl[i].type == "INSERT_POINT" then return end
    --! LOWER BUTTON ALPHA SO INSERT POINTS STANDOUT
    local SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    r.ImGui_DrawListSplitter_Split(SPLITTER, 2)
    local alpha = (DRAG_ADD_FX and not CTRL) and 0.4 or fade
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), alpha) -- alpha
    r.ImGui_BeginGroup(ctx)
    --! DRAW BYPASS
    r.ImGui_PushID(ctx, tbl[i].guid .. "bypass")
    if r.ImGui_InvisibleButton(ctx, "B", para_btn_size, def_btn_h) then
        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_id = CalcFxID(parrent_container, i)
        if tbl[i].type == "ROOT" then
            r.SetMediaTrackInfo_Value(TRACK, "I_FXEN", tbl[i].bypass and 0 or 1)
        else
            r.TrackFX_SetEnabled(TRACK, item_id, not tbl[i].bypass)
        end
    end
    r.ImGui_PopID(ctx)
    Tooltip("BYPASS")
    local color = tbl[i].bypass and COLOR["enabled"] or COLOR["bypass"]
    --color = bypass_color and bypass_color or color
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)

    DrawListButton("A", color, "L", true)

    --! DRAW VOL/PAN PLUGIN
    local helper, vol_hover, pan_hover = DrawVolumePanHelper(tbl, i, width)
    name = helper and "VOL - PAN" or name


    r.ImGui_PushID(ctx, tbl[i].guid .. "button")
    --! DRAW BUTTON
    r.ImGui_SameLine(ctx, helper and helper, 0)
    if r.ImGui_InvisibleButton(ctx, name, width, def_btn_h) then ButtonAction(tbl, i) end
    r.ImGui_PopID(ctx)
    if (tbl[i].type ~= "Container" and tbl[i].type ~= "ROOT") then
        -- AutoCreateContainer(tbl, i)
    end
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    local btn_hover = r.ImGui_IsItemHovered(ctx) and (not vol_hover or not pan_hover)
    local is_del_color = del_color and del_color or (ALT and btn_hover) and COLOR["del"] or TypToColor(tbl[i])
    DrawListButton(name, is_del_color, --  (ALT and btn_hover) and COLOR["del"] or TypToColor(tbl[i])
        tbl[i].type ~= "ROOT" and "R" or nil, nil, btn_hover)
    DragAndDropMove(tbl, i)

    if CTRL then
        if tbl[i].type ~= "Container" and tbl[i].type ~= "ROOT" then
            local added_fx_idx = DragAddDDTarget(tbl, i, tbl[i].p == 1)
            -- SWAP WITH INSERTED PLUGIN
            if added_fx_idx then
                local parrent_container = GetParentContainerByGuid(tbl[i])
                local item_id = CalcFxID(parrent_container, i)
                r.TrackFX_Delete(TRACK, item_id)
            end
        end
    end


    --! DRAW VOLUME
    if tbl[i].wet_val then
        r.ImGui_SameLine(ctx, nil, 0)
        r.ImGui_PushID(ctx, tbl[i].guid .. "wet/dry")
        local is_vol
        if tbl[i + 1] and tbl[i + 1].p > 0 or tbl[i].p == 1 then
            is_vol = true
        end
        local rv, v = MyKnob("", is_vol and "arc" or "dry_wet", tbl[i].wet_val * 100, 0, 100, is_vol)
        if rv then
            local parrent_container = GetParentContainerByGuid(tbl[i])
            local item_id = CalcFxID(parrent_container, i)
            r.TrackFX_SetParam(TRACK, item_id, tbl[i].wetparam, v / 100)
        end
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
            local parrent_container = GetParentContainerByGuid(tbl[i])
            local item_id = CalcFxID(parrent_container, i)
            r.TrackFX_SetParam(TRACK, item_id, tbl[i].wetparam, 1)
        end
        r.ImGui_PopID(ctx)
    end
    if tbl[i].name == "FX CHAIN" then
        r.ImGui_SameLine(ctx, nil, 0)
        r.ImGui_PushID(ctx, tbl[i].guid .. "enclose")

        if r.ImGui_InvisibleButton(ctx, "e", para_btn_size, def_btn_h) then
            if r.TrackFX_GetCount(TRACK) ~= 0 then
                r.PreventUIRefresh(1)
                r.Undo_BeginBlock()
                r.TrackFX_AddByName(TRACK, "Container", false, -1000)
                for j = r.TrackFX_GetCount(TRACK), 1, -1 do
                    local id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
                    r.TrackFX_CopyToTrack(TRACK, j, TRACK, id, true)
                end
                EndUndoBlock("ENCLOSE ALL INTO CONTAINER")
                r.PreventUIRefresh(-1)
            end
        end
        Tooltip("ENCLOSE ALL INTO CONTAINER")
        r.ImGui_PopID(ctx)

        DrawListButton("K", color, "R", true)
    end
    r.ImGui_EndGroup(ctx)
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_DrawListSplitter_Merge(SPLITTER)
    return btn_hover
end

local function SetItemPos(tbl, i, x, item_w)
    if tbl[i].p > 0 then
        r.ImGui_SameLine(ctx)
    else
        if tbl[i].type == "ROOT" then
            -- START ONLY HAS MUTE
            item_w = item_w + mute + volume
        else
            -- NORMAL FX HAS BYPASS AND VOLUME
            if tbl[i].type ~= "Container" then
                item_w = item_w + mute + volume
            end
        end
        r.ImGui_SetCursorPosX(ctx, x - (item_w // 2))

        if tbl[i + 1] and tbl[i + 1].p > 0 then
            local total_w = ParallelRowWidth(tbl, i, item_w)

            local text_size = (total_w // 2) + (para_btn_size // 2)
            r.ImGui_SetCursorPosX(ctx, x - text_size)
        end
    end
end

local function FindNextPrevRow(tbl, i, next, highest)
    local target
    local idx = i + next
    local row = tbl[i].ROW
    local last_in_row = i
    local number_of_parallels = 1
    while not target do
        if not tbl[idx] then break end
        if row ~= tbl[idx].ROW then
            if highest then
                if tbl[idx].biggest then
                    target = tbl[idx]
                else
                    if tbl[idx].p == 0 then
                        target = tbl[idx]
                        break
                    end
                    idx = idx + next
                end
            else
                target = tbl[idx]
                last_in_row = idx + (-next)
            end
        else
            idx = idx + next
            number_of_parallels = number_of_parallels + 1
        end
    end
    return target, last_in_row, number_of_parallels
end

local function GenerateCoordinates(tbl, i, last)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)

    local x = xs + ((xe - xs) // 2)
    if last then
        return { x = x, ys = ys + s_spacing_y + (def_btn_h), ye = ye }
    end
    tbl[i].x, tbl[i].xs, tbl[i].xe, tbl[i].ys, tbl[i].ye = x, xs, xe, ys, ye
end

local function CreateLines(top, cur, bot)
    if top then
        local x1 = cur.x
        local y1 = top.ye + s_spacing_y + (def_btn_h // 2)
        local x2 = x1
        local y2 = cur.ys
        LINE_POINTS[#LINE_POINTS + 1] = { x1, y1, x2, y2 }
    end
    if bot then
        local x1 = cur.x
        local y1 = cur.ye
        local x2 = x1
        local y2 = bot.ys - s_spacing_y - (def_btn_h // 2)
        LINE_POINTS[#LINE_POINTS + 1] = { x1, y1, x2, y2 }
    end
end

local function AddRowSeparatorLine(A, B, bot)
    if A.FX_ID == B.FX_ID then return end
    local x1 = A.x
    local y1 = bot.ys - s_spacing_y - (def_btn_h // 2)
    local x2 = B.x
    local y2 = bot.ys - s_spacing_y - (def_btn_h // 2)

    LINE_POINTS[#LINE_POINTS + 1] = { x1, y1, x2, y2 }

    x1 = A.x
    y1 = A.ys - s_spacing_y - (def_btn_h // 2)
    x2 = B.x
    y2 = A.ys - s_spacing_y - (def_btn_h // 2)

    LINE_POINTS[#LINE_POINTS + 1] = { x1, y1, x2, y2 }
end

local function DrawPlugins(center, tbl, fade, color_del)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), fade)
    local last
    for i = 0, #tbl do
        local name = tbl[i].name:gsub("(%S+: )", "")
        local width, height = CalculateItemWH(tbl[i])
        width = tbl[i].W and tbl[i].W or width
        height = tbl[i].H and tbl[i].H or height
        SetItemPos(tbl, i, center, width)
        if tbl[i].type ~= "Container" then
            local button_hovered = DrawButton(tbl, i, name, width, fade, color_del)
            color_del = tbl[i].type == "ROOT" and button_hovered and ALT and COLOR["bypass"] or color_del
        end
        if tbl[i].type == "Container" then
            r.ImGui_BeginGroup(ctx)
            r.ImGui_PushID(ctx, tbl[i].guid .. "container")
            if r.ImGui_BeginChild(ctx, "##", width, height, true, WND_FLAGS) then
                local button_hovered = DrawButton(tbl, i, name, -volume, fade, color_del)
                GenerateCoordinates(tbl, i)

                -- HIGLIGHT EVERYCHILD WITH DELETE COLOR IF PARRENT IS GOING TO BE DELETED
                local del_color = color_del and color_del or button_hovered and ALT and COLOR["bypass"]

                r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), tbl[i].bypass and 0.5 or fade)
                local fade_alpha = not tbl[i].bypass and 0.5 or fade
                DrawPlugins(r.ImGui_GetCursorPosX(ctx) + (width // 2) - s_window_x, tbl[i].sub, fade_alpha, del_color)
                r.ImGui_PopStyleVar(ctx)
                r.ImGui_EndChild(ctx)
            end
            r.ImGui_EndGroup(ctx)
            r.ImGui_PopID(ctx)
        end
        GenerateCoordinates(tbl, i)
        CheckFX_P(tbl, i)
        if AddInsertPoints(tbl, i, center) then
            last = GenerateCoordinates(tbl, i, "last")
        end
    end
    r.ImGui_PopStyleVar(ctx)

    local last_row, first_in_row
    for i = 0, #tbl do
        if last_row ~= tbl[i].ROW then
            first_in_row = tbl[i]
            last_row = tbl[i].ROW
        end
        local top = FindNextPrevRow(tbl, i, -1, "HIGHEST")
        local cur = tbl[i]
        local bot = FindNextPrevRow(tbl, i, 1) or last
        CreateLines(top, cur, bot)

        if tbl[i + 1] and tbl[i + 1].ROW ~= last_row or not tbl[i + 1] then
            local last_in_row = tbl[i]
            AddRowSeparatorLine(first_in_row, last_in_row, bot)
            first_in_row = nil
        end
    end
end

-- local function Rename()
--     local tbl, i = R_CLICK_DATA[1], R_CLICK_DATA[2]
--     local RV
--     if r.ImGui_IsWindowAppearing(ctx) then
--         r.ImGui_SetKeyboardFocusHere(ctx)
--         NEW_NAME = tbl[i].name
--     end
--     RV, NEW_NAME = r.ImGui_InputText(ctx, 'Name', NEW_NAME, r.ImGui_InputTextFlags_AutoSelectAll())
--     COMMENT_ACTIVE = r.ImGui_IsItemActive(ctx)
--     if r.ImGui_Button(ctx, 'OK') or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or
--         r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
--         NEW_NAME = NEW_NAME:gsub("^%s*(.-)%s*$", "%1") -- remove trailing and leading
--         if #NEW_NAME ~= 0 then SAVED_NAME = NEW_NAME end
--         if SAVED_NAME then
--             local parrent_container = GetParentContainerByGuid(tbl[i])
--             local item_id = CalcFxID(parrent_container, i)
--             r.TrackFX_SetNamedConfigParm(TRACK, item_id, "renamed_name", SAVED_NAME)
--         end
--         r.ImGui_CloseCurrentPopup(ctx)
--     end
--     r.ImGui_SameLine(ctx)
--     if r.ImGui_Button(ctx, 'Cancel') then r.ImGui_CloseCurrentPopup(ctx) end
--     if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
--         r.ImGui_CloseCurrentPopup(ctx)
--     end
-- end

local function RCCTXMenuParallel()
    if r.ImGui_MenuItem(ctx, 'ADJUST LANE VOLUME TO UNITY') then
        local parrent_container = GetParentContainerByGuid(PARA_DATA[1][PARA_DATA[2]])
        local _, first_idx_in_row, p_cnt = FindNextPrevRow(PARA_DATA[1], PARA_DATA[2], -1)

        for i = first_idx_in_row, PARA_DATA[2] do
            local item_id = CalcFxID(parrent_container, i)
            r.TrackFX_SetParam(TRACK, item_id, PARA_DATA[1][i].wetparam, 1 / p_cnt)
        end
    end
    if r.ImGui_MenuItem(ctx, 'RESET LANE VOLUME') then
        local parrent_container = GetParentContainerByGuid(PARA_DATA[1][PARA_DATA[2]])
        local _, first_idx_in_row = FindNextPrevRow(PARA_DATA[1], PARA_DATA[2], -1)

        for i = first_idx_in_row, PARA_DATA[2] do
            local item_id = CalcFxID(parrent_container, i)
            r.TrackFX_SetParam(TRACK, item_id, PARA_DATA[1][i].wetparam, 1)
        end
    end
end

function RCCTXMenu()
    -- if r.ImGui_MenuItem(ctx, 'Rename') then
    --     OPEN_RENAME = true
    -- end
    --if r.ImGui_MenuItem(ctx, 'Delete') then end
end

local function Popups()
    if OPEN_RIGHT_C_CTX then
        OPEN_RIGHT_C_CTX = nil
        if not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX") then
            r.ImGui_OpenPopup(ctx, "RIGHT_C_CTX")
        end
    end

    if r.ImGui_BeginPopup(ctx, "RIGHT_C_CTX") then
        RCCTXMenu()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_RIGHT_C_CTX_PARALLEL then
        OPEN_RIGHT_C_CTX_PARALLEL = nil
        if not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX_PARALLEL") then
            r.ImGui_OpenPopup(ctx, "RIGHT_C_CTX_PARALLEL")
        end
    end

    if r.ImGui_BeginPopup(ctx, "RIGHT_C_CTX_PARALLEL") then
        RCCTXMenuParallel()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_FX_LIST then
        OPEN_FX_LIST = nil
        if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
            r.ImGui_OpenPopup(ctx, "FX LIST")
        end
    end

    if r.ImGui_BeginPopup(ctx, "FX LIST") then
        DrawFXList()
        r.ImGui_EndPopup(ctx)
    end

    -- if OPEN_RENAME then
    --     OPEN_RENAME = nil
    --     if not r.ImGui_IsPopupOpen(ctx, "RENAME") then
    --         r.ImGui_OpenPopup(ctx, 'RENAME')
    --     end
    -- end

    -- if r.ImGui_BeginPopupModal(ctx, 'RENAME', nil,
    --         r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_TopMost()) then
    --     Rename()
    --     r.ImGui_EndPopup(ctx)
    -- end
    if not r.ImGui_IsPopupOpen(ctx, "FX LIST") and #FILTER ~= 0 then FILTER = '' end
    if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
        if FX_ID then FX_ID = nil end
        if CLICKED then CLICKED = nil end
    end
    if not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX_PARALLEL") then
        if PARA_DATA then PARA_DATA = nil end
    end
end

local function CheckKeys()
    ALT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Alt()
    CTRL = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut()
    SHIFT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shift()
    HOME = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Home())
    SPACE = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Space())
    Z = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Z())

    if HOME then CANVAS.off_x, CANVAS.off_y = 0, 50 end

    if CTRL and Z then r.Main_OnCommand(40029, 0) end -- UNDO
    if r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut() | r.ImGui_Mod_Shift() and Z then
        r.Main_OnCommand(40030, 0)                    -- REDO
    end

    if SPACE and not r.ImGui_IsPopupOpen(ctx, "FX LIST") then r.Main_OnCommand(40044, 0) end -- PLAY STOP

    -- ACTIVATE CTRL ONLY IF NOT PREVIOUSLY DRAGGING
    if not CTRL_DRAG then
        CTRL_DRAG = (not MOUSE_DRAG and CTRL) and r.ImGui_IsMouseDragging(ctx, 0)
    end
    MOUSE_DRAG = r.ImGui_IsMouseDragging(ctx, 0)
end

local function UI()
    r.ImGui_SetCursorPos(ctx, 5, 25)
    -- NIFTY HACK FOR COMMENT BOX NOT OVERLAP UI BUTTONS
    --if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)

    --r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 2)
    if r.ImGui_BeginChild(ctx, "TopButtons", 250, def_btn_h + (s_window_y * 2), 1) then
        local retval, tr_ID = r.GetTrackName(TRACK)
        local _, track_name = r.GetSetMediaTrackInfo_String(TRACK, "P_NAME", "", false)
        --r.ImGui_SetCursorPos(ctx, 0, 0)
        r.ImGui_Button(ctx, "SETTINGS")
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, "TRACK: " .. tr_ID .. track_name:upper())
        r.ImGui_EndChild(ctx)
    end
    -- r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_EndChild(ctx)
end

local function Frame()
    Popups()
    GetOrUpdateFX()
    local center
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), s_spacing_x, s_spacing_y)
    if r.ImGui_BeginChild(ctx, "##MAIN", nil, nil, nil, WND_FLAGS) then --(ctx, "##MAIN", nil, nil, nil,  r.ImGui_WindowFlags_AlwaysHorizontalScrollbar())
        center = (r.ImGui_GetContentRegionMax(ctx) + s_window_x) // 2
        r.ImGui_SetCursorPosY(ctx, CANVAS.off_y)
        center = center + CANVAS.off_x
        local bypass = PLUGINS[0].bypass and 1 or 0.5
        DrawPlugins(center, PLUGINS, bypass)
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    DrawLines()
end

function Iterate_container(depth, track, container_id, parent_fx_count, previous_diff, container_guid)
    local _, c_fx_count = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + container_id, "container_count")
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
        local fx_guid = TrackFX_GetFXGUID(TRACK, 0x2000000 + fx_id)
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
            Iterate_container(depth + 1, track, fx_id, c_fx_count, diff, fx_guid)
            FX_DATA[fx_guid].ID = fx_id
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
        local fx_guid = TrackFX_GetFXGUID(TRACK, i - 1)

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
            Iterate_container(0, TRACK, i, total_fx_count, 0, fx_guid)
        end
    end
end

--LAST_TRACK = r.GetSelectedTrack(0, 0)
local function Main()
    CheckKeys()
    TRACK = r.GetSelectedTrack(0, 0)
    local master = r.GetMasterTrack(0)
    if r.GetMediaTrackInfo_Value(master, "I_SELECTED") == 1 then
        TRACK = master
    end

    if LAST_TRACK ~= TRACK then
        Store_To_PEXT(LAST_TRACK)
        LAST_TRACK = TRACK
        if not Restore_From_PEXT() then
            CANVAS = InitCanvas()
        end
    end
    UpdateFxData()
    LINE_POINTS = {}
    PLUGINS = {}
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), 0x111111FF)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 500, 500, FLT_MAX, FLT_MAX)
    r.ImGui_SetNextWindowSize(ctx, 500, 500, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, 'PARANORMAL FX ROUTER', true, WND_FLAGS)
    r.ImGui_PopStyleColor(ctx)
    if visible then
        if TRACK then
            Frame()
            --UI()
        end
        if not IS_DRAGGING_RIGHT_CANVAS and r.ImGui_IsMouseReleased(ctx, 1) and not r.ImGui_IsAnyItemHovered(ctx) then
            r.ImGui_OpenPopup(ctx, 'FX LIST')
        end
        IS_DRAGGING_RIGHT_CANVAS = r.ImGui_IsMouseDragging(ctx, 1, 2)
        r.ImGui_End(ctx)
    end
    UpdateScroll()
    if open then
        r.defer(Main)
    end

    if r.ImGui_IsMouseReleased(ctx, 0) then
        CTRL_DRAG = nil
        DRAG_MOVE = nil
        DRAG_ADD_FX = nil
    end
end

function Exit() Store_To_PEXT(LAST_TRACK) end

r.atexit(Exit)
r.defer(Main)
