local r = reaper
local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

local WireCol = 0xBBBBBBFF                                                           -- WIRE COLOR
local WireThickness = 2                                                              -- WIRE THICKNESS
local FadeContWires = false                                                          -- ENABLE DISABLE CONTAINER WIRE FADING
local WireContFadeAmt = 0x44444400                                                   -- WIRE IN CONTAINERS FADE AMOUNT
local ContWireThicAmt = 0.5                                                          -- CONTAINER WIRE THICKNESS AMMOUNT OF REDUCTION
local ChildBorderSize = 1                                                            -- CONTAINER BOARDER SIZE
local ChildBorderCol = 0x555555FF                                                    -- CONTAINER BOARDER COLOR
local ROUND_CORNER = 2
local custom_btn_h = 25                                                              -- BUTTON HEIGHT, SHOULD BE NOTHING OR NUMBER:

local item_spacing_v = 45                                                            -- VERTICAL SPACING BETEWEEN ITEMS
local add_bnt_size = 55                                                              -- + BUTTON SIZE

local COLOR = {
    ["n"]           = 0x315e94ff, --0x66a9faff,
    ["cont_header"] = 0x00aaaaFF,
    ["midi"]        = 0x8833AAFF,
    ["del"]         = 0xFF2222FF,
    ["start_chain"] = 0x1cbf66ff,
    ["add"]         = 0x192432ff,
    ["parallel"]    = 0x192432ff,
}

local CANVAS = {
    view_x = 0,
    view_y = 0,
    off_x = 0,
    off_y = 50,
    scale = 1,
}

local DEBUG = false
local ctx = r.ImGui_CreateContext('ParaNormalFX')

require("Sexan_FX_Browser")

r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
local WND_FLAGS = nil
--r.ImGui_WindowFlags_NoScrollbar()
--| r.ImGui_WindowFlags_NoScrollWithMouse()

local draw_list = r.ImGui_GetWindowDrawList(ctx)
local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

local TRACK, TRACK_FX_CNT
local line_points
--local PLUGIN

local def_s_frame_x, def_s_frame_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
local def_s_spacing_x, def_s_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
local def_s_window_x, def_s_window_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())

local s_frame_x, s_frame_y = def_s_frame_x, def_s_frame_y
local s_spacing_x, s_spacing_y = def_s_spacing_x, item_spacing_v and item_spacing_v or def_s_spacing_y
local s_window_x, s_window_y = def_s_window_x, def_s_window_y

local function InTbl(tbl, guid)
    local found
    for i = 0, #tbl do
        if tbl[i].guid == guid then found = tbl[i] end
        if tbl[i].sub_fx then
            local sub_tbl = InTbl(tbl[i].sub_fx, guid, "SUB_SEARCH")
            if sub_tbl then found = sub_tbl end
        end
    end
    return found
end
local function adjustBrightness(channel, delta)
    return math.min(255, math.max(0, channel + delta))
end

local function HexTest(color, amt)
    local alpha = color & 0xFF
    local blue = (color >> 8) & 0xFF
    local green = (color >> 16) & 0xFF
    local red = (color >> 24) & 0xFF
    alpha = adjustBrightness(alpha, amt)
    blue = adjustBrightness(blue, amt)
    green = adjustBrightness(green, amt)
    red = adjustBrightness(red, amt)
    return (alpha) | (blue << 8) | (green << 16) | (red << 24)
end

local FX_LIST, CAT = GetFXTbl()

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

local function DrawChildMenu(tbl, path)
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                DrawChildMenu(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                if TRACK then
                    --r.ShowConsoleMsg(tbl[i] .. "\n")
                    -- r.ShowConsoleMsg(path .. os_separator .. tbl[i] .. "\n")
                    r.TrackFX_AddByName(TRACK, table.concat({ path, os_separator, tbl[i] }), false, FX_ID[1])
                end
            end
        end
    end
end

function DrawFXMenus()
    for i = 1, #CAT do
        if r.ImGui_BeginMenu(ctx, CAT[i].name) then
            if CAT[i].name == "FX CHAINS" then
                DrawChildMenu(CAT[i].list)
            end
            for j = 1, #CAT[i].list do
                if CAT[i].name ~= "FX CHAINS" then
                    if r.ImGui_BeginMenu(ctx, CAT[i].list[j].name) then
                        for p = 1, #CAT[i].list[j].fx do
                            if CAT[i].list[j].fx[p] then
                                if r.ImGui_Selectable(ctx, CAT[i].list[j].fx[p]) then
                                    if TRACK then
                                        if FX_ID then
                                            r.TrackFX_AddByName(TRACK, CAT[i].list[j].fx[p], false, FX_ID[1])
                                            LAST_USED_FX = CAT[i].list[j].fx[p]
                                            if FX_ID[2] then
                                                local fx_id = FX_ID[1] < 0 and math.abs(FX_ID[1] + 1000) or FX_ID[1]
                                                r.TrackFX_SetNamedConfigParm(TRACK, fx_id, "parallel", 1)
                                            end
                                        end
                                    end
                                end
                                if r.ImGui_BeginDragDropSource(ctx) then
                                    r.ImGui_SetDragDropPayload(ctx, 'DRAG ADD FX', CAT[i].list[j].fx[p])
                                    r.ImGui_Button(ctx, CAT[i].list[j].fx[p])
                                    r.ImGui_EndDragDropSource(ctx)
                                end
                            end
                        end
                        r.ImGui_EndMenu(ctx)
                    end
                end
            end
            r.ImGui_EndMenu(ctx)
        end
    end
    if r.ImGui_Selectable(ctx, "CONTAINER") then
        if FX_ID then
            r.TrackFX_AddByName(TRACK, "Container", false, FX_ID[1])
            if FX_ID[2] then
                local fx_id = FX_ID[1] < 0 and math.abs(FX_ID[1] + 1000) or FX_ID[1]
                r.TrackFX_SetNamedConfigParm(TRACK, fx_id, "parallel", 1)
            end
        end
    end
    if r.ImGui_BeginDragDropSource(ctx) then
        r.ImGui_SetDragDropPayload(ctx, 'DRAG ADD FX', "Container")
        r.ImGui_Button(ctx, "CONTAINER")
        r.ImGui_EndDragDropSource(ctx)
    end
    if LAST_USED_FX then
        if r.ImGui_Selectable(ctx, "RECENT: " .. LAST_USED_FX) then
            if FX_ID then
                r.TrackFX_AddByName(TRACK, LAST_USED_FX, false, FX_ID[1])
                if FX_ID[2] then
                    local fx_id = FX_ID[1] < 0 and math.abs(FX_ID[1] + 1000) or FX_ID[1]
                    r.TrackFX_SetNamedConfigParm(TRACK, fx_id, "parallel", 1)
                end
            end
        end
        if r.ImGui_BeginDragDropSource(ctx) then
            r.ImGui_SetDragDropPayload(ctx, 'DRAG ADD FX', LAST_USED_FX)
            r.ImGui_Button(ctx, LAST_USED_FX)
            r.ImGui_EndDragDropSource(ctx)
        end
    end
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
                    if FX_ID then
                        r.TrackFX_AddByName(TRACK, filtered_fx[i], false, FX_ID[1])
                        LAST_USED_FX = filtered_fx[i]
                        if FX_ID[2] then
                            local fx_id = FX_ID[1] < 0 and math.abs(FX_ID[1] + 1000) or FX_ID[1]
                            r.TrackFX_SetNamedConfigParm(TRACK, fx_id, "parallel", 1)
                        end
                        FX_ID = nil
                    end
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                if r.ImGui_BeginDragDropSource(ctx) then
                    r.ImGui_SetDragDropPayload(ctx, 'DRAG ADD FX', filtered_fx[i])
                    r.ImGui_Button(ctx, filtered_fx[i])
                    r.ImGui_EndDragDropSource(ctx)
                end
            end
            r.ImGui_EndChild(ctx)
        end
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            r.TrackFX_AddByName(TRACK, filtered_fx[ADDFX_Sel_Entry], false, FX_ID[1])
            LAST_USED_FX = filtered_fx[ADDFX_Sel_Entry]
            if FX_ID[2] then
                local fx_id = FX_ID[1] < 0 and math.abs(FX_ID[1] + 1000) or FX_ID[1]
                r.TrackFX_SetNamedConfigParm(TRACK, fx_id, "parallel", 1)
            end
            ADDFX_Sel_Entry = nil
            r.ImGui_CloseCurrentPopup(ctx)
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry - 1
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry + 1
        end
    else
        DrawFXMenus()
    end
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        FX_ID = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

local function UpdateScroll()
    --if not IS_DRAGGING_RIGHT_CANVAS then return end
    local btn = r.ImGui_MouseButton_Right()
    if r.ImGui_IsMouseDragging(ctx, btn) then
        r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeAll())
        local drag_x, drag_y = r.ImGui_GetMouseDragDelta(ctx, nil, nil, btn)
        CANVAS.off_x, CANVAS.off_y = CANVAS.off_x + drag_x, CANVAS.off_y + drag_y
        r.ImGui_ResetMouseDragDelta(ctx, btn)
    end
end

local function CalcFxID(tbl, i, offset)
    if tbl.diff then
        return 0x2000000 + tbl.C_ID + (tbl.diff * i)
    else
        return offset and offset - i or i - 1
    end
end

local function CalculateItemWH(tbl)
    local tw, th = r.ImGui_CalcTextSize(ctx, tbl.name)
    local iw, ih = tw + (s_frame_x * 2), th + (s_frame_y * 2)
    return iw, custom_btn_h and custom_btn_h or ih
end

local para_btn_size = CalculateItemWH({ name = "||" }) -- || BUTTON SIZE
local def_btn_h = custom_btn_h and custom_btn_h or ({ CalculateItemWH({ name = "||" }) })[2]

local function GetLines(A, B)
    local x0 = A.XY[1]
    local y0 = A.type == "Container" and A.XY[2] + A.H - def_btn_h or A.XY[2]

    local x1 = A.XY[1]
    local y1 = A.XY[2] + (B.XY[2] - A.XY[2] - def_btn_h) - (s_spacing_y / 2)

    local x2 = B.XY[1]
    local y2 = y1

    local x3 = B.XY[1]
    local y3 = B.XY[2] - def_btn_h

    local points = {
        x0,
        y0,
        x1 ~= x3 and x1 or nil,
        x1 ~= x3 and y1 or nil,
        x1 ~= x3 and x2 or nil,
        x1 ~= x3 and y2 or nil,
        x3,
        y3,
    }

    return r.new_array(points), points
end

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

    local btn_total_size = (def_btn_h + (s_spacing_y))
    local start_n_add_btn_size = (s_spacing_y + def_btn_h * 2)

    for i = 1, #rows do
        local col_w, col_h = 0, 0
        if #rows[i] > 1 then
            for j = 1, #rows[i] do
                local w = fx_items[rows[i][j]].W and fx_items[rows[i][j]].W + s_spacing_x or
                    CalculateItemWH(fx_items[rows[i][j]]) + s_spacing_x
                local h = fx_items[rows[i][j]].H and fx_items[rows[i][j]].H + s_spacing_y or btn_total_size
                col_w = col_w + w

                if h > col_h then
                    col_h = h
                end
            end
        else
            local w = fx_items[rows[i][1]].W and fx_items[rows[i][1]].W + para_btn_size + s_spacing_x + s_window_y or
                CalculateItemWH(fx_items[rows[i][1]]) + s_spacing_x
            local h = fx_items[rows[i][1]].H and fx_items[rows[i][1]].H + s_spacing_y or btn_total_size
            H = H + h

            if w > col_w then
                col_w = w
            end
        end
        if col_w > W then
            W = col_w
        end
        H = H + col_h
    end
    W = W + (para_btn_size * 2) + s_spacing_x + (s_window_x * 2)
    H = H + start_n_add_btn_size + (s_window_y * 2)
    return W, H
end

local function IterCont(depth, track, container_id, parent_fx_count, previous_diff, guid)
    local c_fx_count = tonumber(({ r.TrackFX_GetNamedConfigParm(track, 0x2000000 + container_id, "container_count") })
        [2])
    local diff = depth == 0 and parent_fx_count + 1 or (parent_fx_count + 1) * previous_diff
    for i = 1, c_fx_count do
        local fx_id = container_id + diff * i
        local fx_guid = r.TrackFX_GetFXGUID(track, 0x2000000 + fx_id)
        local _, fx_type = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "fx_type")

        if fx_type == "Container" then
            if fx_guid == guid then
                --r.ShowConsoleMsg("RECALC " .. diff * (c_fx_count + 1) .. " - " .. fx_id)
                return diff * (c_fx_count + 1), fx_id
            else
                local new_dif, c_id = IterCont(depth + 1, track, fx_id, c_fx_count, diff, guid)
                if new_dif then return new_dif, c_id end
            end
        end
    end
end

local function RecalcDiff(tbl)
    local guid = tbl.guid
    local TRACK_FX_CNT2 = r.TrackFX_GetCount(TRACK)
    for i = 1, TRACK_FX_CNT2 do
        local fx_guid = r.TrackFX_GetFXGUID(TRACK, i - 1)
        local _, fx_type = r.TrackFX_GetNamedConfigParm(TRACK, i - 1, "fx_type")
        if fx_type == "Container" then
            if fx_guid == guid then
                tbl.diff, tbl.C_ID = (TRACK_FX_CNT2 + 1), i
                return --(TRACK_FX_CNT2 + 1), i
            else
                local new_dif, c_id = IterCont(0, TRACK, i, TRACK_FX_CNT2, 0, guid)
                if new_dif then
                    tbl.diff, tbl.C_ID = new_dif, c_id
                    return --new_dif, c_id
                end
            end
        end
    end
end

local function IterateContainer(depth, track, container_id, parent_fx_count, previous_diff)
    local sub_fx = {}
    local def_total_w = CalculateItemWH({ name = "Container" }) + s_window_x * 2

    local s_sub_fx_w, s_sub_fx_h = 0, 0
    local c_fx_count = tonumber(({ r.TrackFX_GetNamedConfigParm(track, 0x2000000 + container_id, "container_count") })
        [2])
    local diff = depth == 0 and parent_fx_count + 1 or (parent_fx_count + 1) * previous_diff

    local cont_fx_id_cnt = container_id + diff * depth
    local _, cont_name = r.TrackFX_GetFXName(track, 0x2000000 + cont_fx_id_cnt)

    local cont_name_size = CalculateItemWH({ name = cont_name }) + s_window_x * 2
    local total_w = cont_name_size > def_total_w and cont_name_size or def_total_w

    for i = 1, c_fx_count do
        local fx_id = container_id + diff * i
        local fx_guid = r.TrackFX_GetFXGUID(track, 0x2000000 + fx_id)
        local ret, fx_type = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "fx_type")
        local _, fx_name = r.TrackFX_GetFXName(track, 0x2000000 + fx_id)
        local _, para = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "parallel")
        local bypass = r.TrackFX_GetEnabled(track, 0x2000000 + fx_id)
        local wetparam = r.TrackFX_GetParamFromIdent(track, 0x2000000 + fx_id, ":wet")
        local wet_val = r.TrackFX_GetParam(track, 0x2000000 + fx_id, wetparam)

        fx_name = fx_name:gsub("(%S+: )", "")

        if DEBUG then
            fx_name = fx_name .. " - ID: " .. 0x2000000 + fx_id
        end

        para = i == 1 and "0" or para

        local name_w = CalculateItemWH({ name = fx_name }) + (s_window_x * 2) + s_spacing_x + para_btn_size * 2 +
            s_window_x

        if name_w > total_w then total_w = name_w end

        sub_fx[#sub_fx + 1] = {
            --C_ID = container_id,
            XY = { 0, 0 },
            name = fx_name,
            guid = fx_guid,
            p = tonumber(para),
            type = fx_type,
            bypass = bypass,
            wetparam = wetparam,
            wet_val = wet_val,
        }

        if fx_type == "Container" then
            local s_sub_fx, s_total_w, s_total_h = IterateContainer(depth + 1, track, fx_id, c_fx_count, diff)

            s_sub_fx_w = s_sub_fx_w + s_total_w
            s_sub_fx_h = s_sub_fx_h + s_total_h

            s_sub_fx[0] = {
                diff = diff * (c_fx_count + 1),
                C_ID = fx_id,
                XY = { 0, 0 },
                name = fx_name,
                guid = fx_guid,
                p = 0,
                type = "MAIN",
                W = s_total_w,
                H = s_total_h,
                bypass = bypass,
                wetparam = wetparam,
                wet_val = wet_val,
            }
            sub_fx[#sub_fx].sub_fx = s_sub_fx
            sub_fx[#sub_fx].W = s_total_w
            sub_fx[#sub_fx].H = s_total_h
        end
    end

    local C_W, C_H = CalcContainerWH(sub_fx)
    if C_W > total_w then total_w = C_W end

    return sub_fx, total_w, C_H
end

local function CheckFX()
    if not TRACK then return end
    PLUGIN = {
        [0] = {
            XY = { 0, 0 },
            name = "FX CHAIN",
            p = 0,
            type = "MAIN",
            guid = "123456789"
        }
    }

    TRACK_FX_CNT = r.TrackFX_GetCount(TRACK)
    for i = 1, TRACK_FX_CNT do
        local sub_fx, cont_w, cont_h

        local fx_guid = r.TrackFX_GetFXGUID(TRACK, i - 1)
        local _, fx_type = r.TrackFX_GetNamedConfigParm(TRACK, i - 1, "fx_type")
        local _, fx_name = r.TrackFX_GetFXName(TRACK, i - 1)
        local _, para = r.TrackFX_GetNamedConfigParm(TRACK, i - 1, "parallel")
        local bypass = r.TrackFX_GetEnabled(TRACK, 0x2000000 + i - 1)
        local wetparam = r.TrackFX_GetParamFromIdent(TRACK, i - 1, ":wet")
        local wet_val = r.TrackFX_GetParam(TRACK, i - 1, wetparam)

        para = i == 1 and "0" or para

        fx_name = fx_name:gsub("(%S+: )", "")

        if DEBUG then
            fx_name = fx_name .. " - ID:" .. i
        end

        if fx_type == "Container" then
            sub_fx, cont_w, cont_h = IterateContainer(0, TRACK, i, TRACK_FX_CNT, 0)
            sub_fx[0] = {
                diff = (TRACK_FX_CNT + 1),
                C_ID = i,
                XY = { 0, 0 },
                name = fx_name,
                guid = fx_guid,
                p = 0,
                type = "MAIN",
                W = cont_w - s_window_x * 2,
                bypass = bypass,
                wetparam = wetparam,
                wet_val = wet_val
            }
        end
        PLUGIN[#PLUGIN + 1] = {
            XY = { 0, 0 },
            name = fx_name,
            guid = fx_guid,
            p = tonumber(para),
            type = fx_type,
            sub_fx = sub_fx,
            W = cont_w and cont_w,
            H = cont_h and cont_h,
            bypass = bypass,
            wetparam = wetparam,
            wet_val = wet_val,
        }
    end
end

function FindTop(tbl, fx_id)
    local depth = 0
    for j = fx_id, 0, -1 do
        if tbl[j] and tbl[j].p == 0 then
            depth = depth + 1
        end
        if depth == 2 then -- PARALLEL PARENT IS 2nd FX with 0 parallel
            return tbl[j]
        end
    end
end

local function FindBot(tbl, fx_id)
    local total_w = 0
    local found
    local id = fx_id + 1
    local cnt = 1
    while not found do
        if not tbl[id] then break end
        if tbl[id].p == 0 then
            found = tbl[id]
        else
            local item_w = tbl[id].W and tbl[id].W + s_spacing_x or CalculateItemWH(tbl[id]) + s_spacing_x
            total_w = total_w + item_w
            id = id + 1
            cnt = cnt + 1
        end
    end
    return found, cnt, total_w
end

local function Tooltip(text)
    if not r.ImGui_IsItemHovered(ctx) then return end
    if r.ImGui_BeginTooltip(ctx) then
        r.ImGui_Text(ctx, text)
        r.ImGui_EndTooltip(ctx)
    end
end

local function DrawButton(btn_sx, btn_sy, item_w, item_h, name, color)
    local multi_color = HexTest(color, r.ImGui_IsItemHovered(ctx) and 50 or 0)
    --multi_color = r.ImGui_IsItemActive(ctx) and HexTest(color|0x224455ff,50) or multi_color
    --local multi_color = hover and color or IncColor(color, r.ImGui_IsItemHovered(ctx) and 50 or 0)
    r.ImGui_DrawList_AddRectFilled(draw_list, btn_sx, btn_sy, btn_sx + item_w, btn_sy + item_h, multi_color, ROUND_CORNER)
    if r.ImGui_IsItemActive(ctx) then
        r.ImGui_DrawList_AddRect(draw_list, btn_sx - 3, btn_sy - 3, btn_sx + item_w + 3, btn_sy + item_h + 3, 0x22FF44FF,
            3, nil, 2)
    end
    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local FONT_SIZE = r.ImGui_GetFontSize(ctx)
    r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, btn_sx + (item_w / 2) - label_size / 2,
        btn_sy + ((item_h / 2)) - FONT_SIZE / 2, 0xffffffff, name)
end

local function SwapParallelInfo(src, dst)
    local _, src_p = r.TrackFX_GetNamedConfigParm(TRACK, src, "parallel")
    local _, dst_p = r.TrackFX_GetNamedConfigParm(TRACK, dst, "parallel")

    r.TrackFX_SetNamedConfigParm(TRACK, src, "parallel", dst_p)
    r.TrackFX_SetNamedConfigParm(TRACK, dst, "parallel", src_p)
end

local function MoveDragAndDropTarget(tbl, i)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'MOVE')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local src_tbl_0_guid, src_id = payload:match("(.+),(.+)")
            local src_tbl_0, src_i = InTbl(PLUGIN, src_tbl_0_guid), tonumber(src_id)

            local src_fx = CalcFxID(src_tbl_0, src_i)
            -- r.ShowConsoleMsg(i - src_i .. "\n")

            local dst_pos --= i + 1
            -- IF ON SAME LEVEL SAME LEVEL
            if src_tbl_0.C_ID == tbl[0].C_ID then
                if (i - src_i) > 0 then
                    dst_pos = i
                elseif (i - src_i) < -1 then
                    dst_pos = i + 1
                end
            else
                dst_pos = i + 1
            end

            if dst_pos then
                local dst_fx = CalcFxID(tbl[0], dst_pos)
                -- REMOVE PARALLEL WHEN MOVING TO SERIAL LINE
                r.TrackFX_SetNamedConfigParm(TRACK, src_fx, "parallel", 0)
                r.TrackFX_CopyToTrack(TRACK, src_fx, TRACK, dst_fx, true)
            end
        end
    end
end

local function InsertPoints(x, i, tbl)
    local prev_x, prev_y = r.ImGui_GetCursorPos(ctx)
    r.ImGui_SetCursorPos(ctx, x - (add_bnt_size / 2), prev_y - (def_btn_h / 2) - (s_spacing_y / 2))

    local btn_sx, btn_sy = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_PushID(ctx, "INSERT_POINT" .. tbl[i].guid)
    if r.ImGui_InvisibleButton(ctx, "##", add_bnt_size, def_btn_h) then
        CLICKED = tbl[i].guid
        local fx_id = CalcFxID(tbl[0], i + 1, -999)
        FX_ID = { fx_id }
        OPEN_POPUP = true
    end
    r.ImGui_PopID(ctx)
    local Aretval, Atype, Apayload, Ais_preview, Ais_delivery = reaper.ImGui_GetDragDropPayload(ctx)
    local color = Atype == 'DRAG ADD FX' and HexTest(COLOR["parallel"], 30) or 0
    if CLICKED and CLICKED == tbl[i].guid then
        color = HexTest(COLOR["parallel"], 30)
    end

    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DRAG ADD FX')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local fx_id = CalcFxID(tbl[0], i + 1, -999)
            r.TrackFX_AddByName(TRACK, payload, false, fx_id)
            LAST_USED_FX = payload
        end
    end

    DrawButton(btn_sx, btn_sy, add_bnt_size, def_btn_h, "", r.ImGui_IsItemHovered(ctx) and COLOR["parallel"] or color,
        true)

    r.ImGui_SetCursorPos(ctx, prev_x, prev_y)
end

local function SetItemPos(tbl, i, x, item_w)
    if tbl[i].p > 0 then
        --! PARALLEL
        r.ImGui_SameLine(ctx)
    else
        --! INSERT POINTS
        r.ImGui_SetCursorPosX(ctx, x - (item_w / 2))
        --! CALCUATE TOTAL OFFSET FOR WHOLE PARALLEL ROW
        if tbl[i + 1] then
            if tbl[i + 1].p > 0 then
                local _, _, total_w = FindBot(tbl, i)
                local text_size = (total_w / 2) + (item_w / 2)
                r.ImGui_SetCursorPosX(ctx, x - text_size)
            end
        end
    end
end

local function AddFX_P(i, tbl)
    r.ImGui_SameLine(ctx)
    local btn_sx, btn_sy = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_PushID(ctx, "ADD_P" .. tbl[i].guid)
    if r.ImGui_InvisibleButton(ctx, "||", para_btn_size, def_btn_h) then
        local fx_id = CalcFxID(tbl[0], i + 1, -999)
        FX_ID = { fx_id, true }
        OPEN_POPUP = true
    end
    r.ImGui_PopID(ctx)
    Tooltip("NEW PARALLEL")
    DrawButton(btn_sx, btn_sy, para_btn_size, def_btn_h, "||", COLOR["parallel"])
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DRAG ADD FX')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local fx_id = CalcFxID(tbl[0], i + 1, -999)
            r.TrackFX_AddByName(TRACK, payload, false, fx_id)
            local fx_pos = fx_id < 0 and math.abs(fx_id + 1000) or fx_id
            r.TrackFX_SetNamedConfigParm(TRACK, fx_pos, "parallel", 1)
            LAST_USED_FX = payload
        end
    end
    -- if r.ImGui_BeginDragDropTarget(ctx) then
    --     local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'MOVE')
    --     r.ImGui_EndDragDropTarget(ctx)
    --     if ret then
    --         local src_tbl_0_guid, src_id = payload:match("(.+),(.+)")
    --         local src_tbl_0, src_i = InTbl(PLUGIN, src_tbl_0_guid), tonumber(src_id)

    --         local src_fx = CalcFxID(src_tbl_0, src_i)

    --         if tbl[i + 1] then
    --             local src = src_fx
    --             local dst = CalcFxID(tbl[0], i + 1)
    --             if tbl[i + 1].p > 0 then SwapParallelInfo(src, dst) end
    --         end

    --         local dst_fx = CalcFxID(tbl[0], i+1)

    --         r.TrackFX_SetNamedConfigParm(TRACK, src_fx, "parallel", 1)
    --         r.TrackFX_CopyToTrack(TRACK, src_fx, TRACK, dst_fx, true)
    --     end
    -- end
end

local function AddFX_S(tbl)
    local btn_sx, btn_sy = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_PushID(ctx, "ADD_S" .. tbl[0].guid)
    if r.ImGui_InvisibleButton(ctx, "+", add_bnt_size, def_btn_h) then
        local fx_id = CalcFxID(tbl[0], #tbl + 1, -1000)
        FX_ID = { fx_id }
        OPEN_POPUP = true
    end
    r.ImGui_PopID(ctx)
    DrawButton(btn_sx, btn_sy, add_bnt_size, def_btn_h, "+", COLOR["add"])
    Tooltip("NEW SERIAL FX")
    if r.ImGui_BeginDragDropTarget(ctx) then
        local fx_id = CalcFxID(tbl[0], #tbl + 1, -1000)
        r.ImGui_EndDragDropTarget(ctx)
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DRAG ADD FX')
        if ret then
            r.TrackFX_AddByName(TRACK, payload, false, fx_id)
            LAST_USED_FX = payload
        end
    end
end

local function CheckFX_P(i, tbl)
    if i == 0 then return end
    if tbl[i].p == 0 then
        if (tbl[i + 1] and tbl[i + 1].p + tbl[i].p == 0) or not tbl[i + 1] then
            AddFX_P(i, tbl)
        end
    else
        if tbl[i + 1] and tbl[i + 1].p + tbl[i].p == 1 or not tbl[i + 1] then
            AddFX_P(i, tbl)
        end
    end
end

local function GenerateLines(tbl, last)
    for i = 0, #tbl do
        local prev_fx = FindTop(tbl, i)
        local cur_fx = tbl[i]
        local next_fx = FindBot(tbl, i) or last

        if prev_fx then
            local arr = GetLines(prev_fx, cur_fx)
            line_points[#line_points + 1] = arr
        end
        if next_fx then
            local arr = GetLines(cur_fx, next_fx)
            line_points[#line_points + 1] = arr
        end
    end
end

local function SwapFX(src_tbl, dst_tbl, src_id, dst_id)
    local src = CalcFxID(src_tbl, src_id)
    local dst = CalcFxID(dst_tbl, dst_id)

    SwapParallelInfo(src, dst)
    r.TrackFX_CopyToTrack(TRACK, src, TRACK, dst, true)

    if src_tbl.C_ID == dst_tbl.C_ID then
        dst = src_id < dst_id and dst_id - 1 or dst_id + 1
        dst = CalcFxID(dst_tbl, dst)
    else
        RecalcDiff(src_tbl)
        RecalcDiff(dst_tbl)
        src = CalcFxID(src_tbl, src_id)
        dst = CalcFxID(dst_tbl, dst_id + 1)
    end
    r.TrackFX_CopyToTrack(TRACK, dst, TRACK, src, true)
end

local function ButtonAction(tbl, i)
    local fx_id = CalcFxID(tbl[0], i)
    if ALT then
        if tbl[i + 1] then
            local src = fx_id
            local dst = CalcFxID(tbl[0], i + 1)
            if tbl[i + 1].p > 0 then SwapParallelInfo(src, dst) end
        end
        r.TrackFX_Delete(TRACK, fx_id)
    else
        AAA = tbl[0]
        r.TrackFX_Show(TRACK, fx_id, 3)
    end
end

local function MoveDragAndDropSource(tbl, i)
    if r.ImGui_BeginDragDropSource(ctx) then
        local data = tbl[0].guid .. "," .. i
        r.ImGui_SetDragDropPayload(ctx, 'MOVE', data)
        r.ImGui_Text(ctx, "MOVE")
        r.ImGui_SameLine(ctx)
        r.ImGui_Button(ctx, tbl[i].name)
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function SwapTargetDragDrop(tbl, i)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'MOVE')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local src_tbl_0_guid, src_id = payload:match("(.+),(.+)")
            local src_tbl_0, src_i = InTbl(PLUGIN, src_tbl_0_guid), tonumber(src_id)

            if src_id == "0" then

            end
            if i == 0 then

            end

            SwapFX(src_tbl_0, tbl[0], src_i, i)
        end
    end
end

local abs = math.abs
function ParaVolume()
    local x, y = r.ImGui_GetMouseDelta(ctx)
    y = y ~= 0 and y // abs(y) / 100 or 0

    local id = HOVER.child and HOVER.CHILD_ID or HOVER.ID
    local wet = r.TrackFX_GetParam(TRACK, id, HOVER.wetparam)
    r.ImGui_VSliderDouble(ctx, "##V", 35, 100, wet, 0.0, 1.0)
    r.TrackFX_SetParam(TRACK, id, HOVER.wetparam, wet - y)
    if not r.ImGui_IsMouseDown(ctx, 0) then
        PX, PY = nil, nil
        HOVER = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

local HOVER
local function AddFXControls(tbl, i, item_w)
    local x, y = r.ImGui_GetCursorPos(ctx)
    if i == 0 then return end
    if not tbl[i + 1] and tbl[i].p == 0 then return end
    if tbl[i + 1] and tbl[i].p + tbl[i + 1].p == 0 then return end
   
    r.ImGui_SetCursorPos(ctx, x + item_w - 5, y-def_btn_h)
    local btn_sx, btn_sy = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_PushID(ctx, "VOL" .. tbl[i].guid)
    r.ImGui_InvisibleButton(ctx, "##", 10, def_btn_h / 2)

    --r.ImGui_DrawList_AddRectFilled(draw_list, bx, by, bx + 10, by + (def_btn_h / 2), COLOR["n"])
    local val = string.format("%.0f", (tbl[i].wet_val * 100) / 1)
    DrawButton(btn_sx, btn_sy, 10, def_btn_h / 2, val, COLOR["n"], (ALT and r.ImGui_IsItemHovered(ctx)), 10)
    r.ImGui_PopID(ctx)

    if not HOVER then
        PX, PY = r.ImGui_GetMousePos(ctx)
        HOVER = r.ImGui_IsItemActive(ctx) and tbl[i] or nil
    end

    if r.ImGui_IsItemActive(ctx) then
        OPEN_TEST = true
    end
    --r.ImGui_SetCursorPos(ctx, x + 15 + off_x, y + off_y - 1)
    if r.ImGui_IsItemHovered(ctx) then
       -- r.ImGui_Text(ctx, string.format("%.0f", (tbl[i].wet_val * 100) / 1))
    end
end

local function Draw(tbl, x)
    if not TRACK then return end
    for i = 0, #tbl do
        local item_w, item_h = CalculateItemWH(tbl[i])

        if tbl[i].W then item_w = tbl[i].W end

        SetItemPos(tbl, i, x, item_w)
        local btn_sx, btn_sy = r.ImGui_GetCursorScreenPos(ctx)

        tbl[i].XY[1] = btn_sx + (item_w / 2)
        tbl[i].XY[2] = btn_sy + item_h

        if tbl[i].type ~= "Container" then
            r.ImGui_BeginGroup(ctx)
            --AddFXControls(tbl, i, btn_sx, btn_sy, (item_w / 2) - 5, def_btn_h + s_spacing_y / 2 - def_btn_h / 4)
            r.ImGui_PushID(ctx, "button" .. tbl[i].guid)
            if r.ImGui_InvisibleButton(ctx, tbl[i].name, (i == 0 and tbl[i].name ~= "FX CHAIN") and -1 or item_w, def_btn_h) then
                ButtonAction(tbl, i)
            end
            r.ImGui_PopID(ctx)
            MoveDragAndDropSource(tbl, i)
            SwapTargetDragDrop(tbl, i)
            local color = (ALT and r.ImGui_IsItemHovered(ctx)) and COLOR["del"] or
                (i == 0 and COLOR["cont_header"] or COLOR["n"])
            DrawButton(btn_sx, btn_sy, item_w, item_h, tbl[i].name, color, (ALT and r.ImGui_IsItemHovered(ctx)))
            r.ImGui_EndGroup(ctx)
        else
            r.ImGui_BeginGroup(ctx)
            r.ImGui_PushID(ctx, "container" .. tbl[i].guid)
            if r.ImGui_BeginChild(ctx, "##", tbl[i].W, tbl[i].H, true, r.ImGui_WindowFlags_NoScrollbar()) then
                Draw(tbl[i].sub_fx, r.ImGui_GetCursorPosX(ctx) + (tbl[i].W / 2) - s_window_x)
                r.ImGui_EndChild(ctx)
            end
            r.ImGui_PopID(ctx)
            AddFXControls(tbl, i, (item_w / 2))
            r.ImGui_EndGroup(ctx)
        end

        if CheckFX_P(i, tbl) then AddFX_P(i, tbl) end

        if tbl[i].p == 0 then
            if tbl[i + 1] and tbl[i + 1].p == 0 or not tbl[i + 1] then
                InsertPoints(x, i, tbl)
            end
        end
        if tbl[i].p == 1 then
            if tbl[i + 1] and tbl[i + 1].p == 0 or not tbl[i + 1] then
                InsertPoints(x, i, tbl)
            end
        end
    end

    r.ImGui_SetCursorPosX(ctx, x - (add_bnt_size / 2))
    local last_x, last_y = r.ImGui_GetCursorScreenPos(ctx)
    AddFX_S(tbl)
    local last = { XY = { last_x + (add_bnt_size / 2), last_y + def_btn_h } }

    GenerateLines(tbl, last)
end

local function CheckKeys()
    ALT = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftAlt())
    CTRL = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl())
    Z = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Z())

    -- UNDO
    if CTRL and Z then r.Main_OnCommand(40029, 0) end
end

local function DrawLines()
    for i = 1, #line_points do
        r.ImGui_DrawList_AddPolyline(draw_list, line_points[i], WireCol, 0, WireThickness)
    end
end

local function Main()
    line_points = {}
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), 0x111111FF)
    local visible, open = r.ImGui_Begin(ctx, 'PARA-NORMAL FX ACTIVITY - ALPHA', true, WND_FLAGS)
    r.ImGui_PopStyleColor(ctx)
    TRACK = r.GetSelectedTrack(0, 0)
    if visible then
        if not r.ImGui_IsPopupOpen(ctx, "FX LIST") and #FILTER ~= 0 then FILTER = '' end

        if OPEN_POPUP then
            OPEN_POPUP = nil
            if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
                r.ImGui_OpenPopup(ctx, "FX LIST")
            end
        end
        if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
            if CLICKED then CLICKED = nil end
        end

        if r.ImGui_BeginPopup(ctx, "FX LIST") then
            FilterBox()
            r.ImGui_EndPopup(ctx)
        end

        if OPEN_TEST then
            OPEN_TEST = nil
            if not r.ImGui_IsPopupOpen(ctx, "TEST") then
                r.ImGui_OpenPopup(ctx, "TEST")
            end
        end

        if HOVER then
            r.ImGui_SetNextWindowPos(ctx, PX - 18, PY - s_window_y - (100 - (HOVER.wet_val * 100) // 1))
        end
        if r.ImGui_BeginPopup(ctx, "TEST") then
            ParaVolume()
            r.ImGui_EndPopup(ctx)
        end

        CheckKeys()
        CheckFX()

        local center = (r.ImGui_GetContentRegionMax(ctx) + s_window_x) / 2

        --if TRACK then r.ImGui_SetCursorPosY(ctx, CANVAS.off_y) end
        --center = center + CANVAS.off_x

        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), s_spacing_x, s_spacing_y)
        if r.ImGui_BeginChild(ctx, "##MAIN", nil, nil, nil, r.ImGui_WindowFlags_NoScrollbar()) then
            if TRACK then r.ImGui_SetCursorPosY(ctx, CANVAS.off_y) end
            center = center + CANVAS.off_x
            Draw(PLUGIN, center)
            r.ImGui_EndChild(ctx)
        end
        DrawLines()
        r.ImGui_PopStyleVar(ctx)

        if not IS_DRAGGING_RIGHT_CANVAS and r.ImGui_IsMouseReleased(ctx, 1) and not r.ImGui_IsAnyItemHovered(ctx) then
            r.ImGui_OpenPopup(ctx, 'FX LIST')
        end
        IS_DRAGGING_RIGHT_CANVAS = r.ImGui_IsMouseDragging(ctx, 1)

        r.ImGui_End(ctx)
    end
    if open then
        r.defer(Main)
    end
    UpdateScroll()
end

function Exit() end

r.atexit(Exit)
r.defer(Main)
