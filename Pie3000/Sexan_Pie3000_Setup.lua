--@noindex
--NoIndex: true
local r = reaper

local info = debug.getinfo(1, 'S');
local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. "?.lua;"

if DBG then dofile("C:/Users/Gokily/Documents/ReaGit/ReaScripts/Debug/LoadDebug.lua") end

require('PieUtils')
if CheckDeps() then return end
local ctx = r.ImGui_CreateContext('PIE 3000 SETUP')
r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

local png_path = r.GetResourcePath() .. "/Data/toolbar_icons/150/"

local PIE_LIST = {}

local ANIMATION = true
local ACTIVATE_ON_CLOSE = true
local HOLD_TO_OPEN = true

local def_color_dark = 0x414141ff --0x353535ff
local def_out_ring = 0x2a2a2aff
local def_menu_prev = 0x212121ff
local ARC_COLOR = 0x11AAFF88
local def_color = def_color_dark

local function CalculateThemeColor(org_color)
    local alpha = org_color & 0xFF
    local blue = (org_color >> 8) & 0xFF
    local green = (org_color >> 16) & 0xFF
    local red = (org_color >> 24) & 0xFF

    local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
    return luminance < 0.5 and true or false
end

local function GetThemeBG()
    return r.GetThemeColor("col_tr1_bg", 0)
end

local dark_theme = CalculateThemeColor(GetThemeBG())
if dark_theme then
    local def_light = def_color_dark --0x9ca2a2ff
    def_out_ring = 0x818989ff
    def_menu_prev = def_light
    def_color = def_light
end

local KEYS = { "" }
for name, func in pairs(r) do
    name = name:match('^ImGui_Key_(.+)$')
    if name then KEYS[func()] = name end
end
table.sort(KEYS)

local keys_str = table.concat(KEYS, "\0") .. "\0"

if r.HasExtState("PIE3000", "SETTINGS") then
    local stored = r.GetExtState("PIE3000", "SETTINGS")
    if stored ~= nil then
        local save_data = StringToTable(stored)
        if save_data ~= nil then
            ANIMATION = save_data.animation
            ACTIVATE_ON_CLOSE = save_data.activate_on_close
            HOLD_TO_OPEN = save_data.hold_to_open
            --ADJUST_TO_THEME = save_data.adjust_to_theme
            --def_color_dark = save_data.def_color_dark
            --def_color_light = save_data.def_color_light
            --ARC_COLOR = save_data.arc_color
            --DEFAULT_COLOR = save_data.default_color
        end
    end
end

local FONT_SIZE = 14
local FONT_LARGE = 16
local ICON_FONT_SMALL_SIZE = 25
local ICON_FONT_LARGE_SIZE = 40
local ICON_FONT_CLICKED_SIZE = 32
local ICON_FONT_PREVIEW_SIZE = 16

ICON_FONT_SMALL = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_SMALL_SIZE)
ICON_FONT_LARGE = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_LARGE_SIZE)
ICON_FONT_PREVIEW = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_PREVIEW_SIZE)
SYSTEM_FONT = r.ImGui_CreateFont('sans-serif', FONT_SIZE, r.ImGui_FontFlags_Bold())
SYSTEM_FONT2 = r.ImGui_CreateFont('sans-serif', FONT_LARGE, r.ImGui_FontFlags_Bold())

r.ImGui_Attach(ctx, SYSTEM_FONT)
r.ImGui_Attach(ctx, SYSTEM_FONT2)
r.ImGui_Attach(ctx, ICON_FONT_SMALL)
r.ImGui_Attach(ctx, ICON_FONT_LARGE)
r.ImGui_Attach(ctx, ICON_FONT_PREVIEW)

local pie_file = script_path .. "pie_file.txt"
local menu_file = script_path .. "menu_file.txt"
local SELECTED = {
    ["arrange"] = {},
    ["arrangeempty"] = {},
    ["tcp"] = {},
    ["tcpempty"] = {},
    ["mcp"] = {},
    ["mcpempty"] = {},
    ["envelope"] = {},
    ["envcp"] = {},
    ["item"] = {},
    ["trans"] = {},
}

local draw_list = r.ImGui_GetWindowDrawList(ctx)

local pi, max, floor, cos, sin, atan, ceil, abs = math.pi, math.max, math.floor, math.cos, math.sin, math.atan, math
    .ceil, math.abs

local START_ANG = (3 * pi) / 2
local RADIUS_START = 150

local DEFAULT_PIE = {
    ["arrange"] = { RADIUS = RADIUS_START, name = "ARRANGE", guid = r.genGuid() },
    ["arrangeempty"] = { RADIUS = RADIUS_START, name = "ARRANGE EMPTY", guid = r.genGuid() },
    ["tcp"] = { RADIUS = RADIUS_START, name = "TCP", guid = r.genGuid() },
    ["tcpempty"] = { RADIUS = RADIUS_START, name = "TCP EMPTY", guid = r.genGuid() },
    ["mcp"] = { RADIUS = RADIUS_START, name = "MCP", guid = r.genGuid() },
    ["mcpempty"] = { RADIUS = RADIUS_START, name = "MCP EMPTY", guid = r.genGuid() },
    ["envelope"] = { RADIUS = RADIUS_START, name = "ENVELOPE", guid = r.genGuid() },
    ["envcp"] = { RADIUS = RADIUS_START, name = "ENV CP", guid = r.genGuid() },
    ["item"] = { RADIUS = RADIUS_START, name = "ITEM", guid = r.genGuid() },
    ["trans"] = { RADIUS = RADIUS_START, name = "TRANSPORT", guid = r.genGuid() },
    ["midi"] = { RADIUS = RADIUS_START, name = "MIDI", guid = r.genGuid() },
}

local PIES = ReadFromFile(pie_file) or Deepcopy(DEFAULT_PIE)

local context_cur_item = 0
local cur_menu_item = 0
local menu_items = {
    "arrange",
    "arrangeempty",
    "tcp",
    "tcpempty",
    "mcp",
    "mcpempty",
    "envelope",
    "envcp",
    "item",
    "trans",
}


MENUS = ReadFromFile(menu_file) or {}

local function LinkMenus(tbl)
    for k, v in ipairs(tbl) do
        tbl[k].guid_list = {}
        for i = 1, #v do
            if type(v[i]) == "table" then
                local parent = InTbl(MENUS, v[i].guid)
                if parent then
                    table.insert(tbl[k].guid_list, v[i].guid)
                    v[i] = parent
                    LinkMenus(v[i])
                end
            end
        end
    end
end

local function HasReference(tbl, guid, remove)
    if not tbl.guid_list then return end
    for i = #tbl.guid_list, 1, -1 do
        if tbl.guid_list[i] == guid then
            if remove then
                table.remove(tbl.guid_list, i)
            else
                return i
            end
        end
    end
end

local function ClearMenusAfterDelete(guid, tbl)
    for k, v in ipairs(tbl) do
        for i = #v, 1, -1 do
            HasReference(v[i], guid, true)
            if type(v[i]) == "table" then
                local parent = v[i].guid == guid
                if parent then
                    v.selected = nil
                    table.remove(v, i)
                end
                ClearMenusAfterDelete(v[i], guid)
            end
        end
    end
end

LinkMenus(MENUS)

local CUR_PIE = PIES["arrange"]
local CUR_MENU_PIE = MENUS[1]

local function LinkPieMenusWithSrcMenus(tbl)
    for k, v in pairs(tbl) do
        for i = 1, #v do
            if v[i].menu then
                local parent = InTbl(MENUS, v[i].guid)
                if parent then
                    v[i] = parent
                end
            end
        end
    end
end

LinkPieMenusWithSrcMenus(PIES)

-- local function CalculateThemeColor(org_color)
--     local alpha = org_color & 0xFF
--     local blue = (org_color >> 8) & 0xFF
--     local green = (org_color >> 16) & 0xFF
--     local red = (org_color >> 24) & 0xFF

--     local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
--     return luminance > 0.5 and def_color_dark or def_color_light
-- end

-- local function GetThemeBG()
--     return r.GetThemeColor("col_tr1_bg", 0)
-- end

--local def_color = ADJUST_TO_THEME and CalculateThemeColor(GetThemeBG()) or DEFAULT_COLOR

local function IterateFiles(dir)
    local tbl = {}
    for index = 0, math.huge do
        local file = r.EnumerateFiles(dir, index)
        if not file then break end
        if file:find(".png", nil, true) and not file:match("animation") then
            tbl[#tbl + 1] = { name = dir .. file }
        end
    end
    return tbl
end

local PNG_TBL = IterateFiles(png_path)

local function IterateActions(sectionID)
    local i = 0
    return function()
        local retval, name = r.CF_EnumerateActions(sectionID, i, '')
        if retval > 0 then
            i = i + 1
            return retval, name
        end
    end
end

local function GetActions()
    local actions = {}
    for cmd, name in IterateActions(0) do
        table.insert(actions, { cmd = cmd, name = name })
    end
    table.sort(actions, function(a, b) return a.name < b.name end)
    return actions
end

local function FilterActions(actions, filter_text)
    local t = {}
    for i = 1, #actions do
        local action = actions[i]
        local name = action.name:lower()
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then
            table.insert(t, action)
        end
    end
    return t
end

local ACTIONS_TBL = GetActions()
local FILTERED_TBL = ACTIONS_TBL
local FILTERED_MENU_TBL = MENUS
local ACTION_FILTER = ''
local MENU_FILTER = ''

local FILTERED_PNG = PNG_TBL

local function FilterBox(tbl, f_type)
    if f_type == "action" then
        rv_f, ACTION_FILTER = r.ImGui_InputTextWithHint(ctx, "##input", "Search Actions", ACTION_FILTER)
    else
        rv_f, MENU_FILTER = r.ImGui_InputTextWithHint(ctx, "##input", "Search Menus", MENU_FILTER)
    end
    if rv_f or update_filter then
        if f_type == "action" then
            FILTERED_TBL = FilterActions(tbl, ACTION_FILTER)
        elseif f_type == "menu" then
            FILTERED_MENU_TBL = FilterActions(tbl, MENU_FILTER)
        end
    end
    if update_filter then update_filter = nil end
end

local function DndSourceAction(tbl)
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptBeforeDelivery()) then
        r.ImGui_SetDragDropPayload(ctx, 'DND ACTION', tbl.name .. "|" .. tbl.cmd)
        r.ImGui_Text(ctx, tbl.name)
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function DndSourceMenu(tbl, i)
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptBeforeDelivery()) then
        r.ImGui_SetDragDropPayload(ctx, 'DND Menu', i)
        r.ImGui_Text(ctx, tbl.name)
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function DndAddTargetAction(pie, button)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND ACTION')
        local name, cmd = payload:match("(.+)|(.+)")
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            if not button then
                local insert_pos = #pie ~= 0 and #pie or 1
                table.insert(pie, insert_pos,
                    { name = name, cmd = cmd, cmd_name = name, col = 0xff })
                pie.selected = insert_pos
            else
                button.cmd = cmd
                button.cmd_name = name
                button.name = name
            end
        end
    end
end

local function DndAddTargetMenu(pie, button, i)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND Menu')
        local menu_id = tonumber(payload)
        r.ImGui_EndDragDropTarget(ctx)
        local prev_guid
        if ret then
            if pie ~= MENUS[menu_id] then
                CROSS_MENU = HasReference(MENUS[menu_id], pie.guid)
                if not CROSS_MENU then
                    local insert_pos = #pie ~= 0 and #pie or 1
                    if not button then
                        table.insert(pie, insert_pos, MENUS[menu_id])
                    else
                        prev_guid = pie[1].guid
                        button[1] = MENUS[menu_id]
                    end
                    if pie.guid_list then
                        if not button then
                            table.insert(pie.guid_list, MENUS[menu_id].guid)
                        else
                            for j = 1, #pie.guid_list do
                                if pie.guid_list[j] == prev_guid then
                                    pie.guid_list[j] = MENUS[menu_id].guid
                                end
                            end
                        end
                    end
                    pie.selected = insert_pos
                end
            else
                SELF_INSERT = true
            end
        end
    end
end

local function ActionsTab(pie)
    if r.ImGui_BeginTabBar(ctx, "ACTIONS MENUS TAB") then
        if r.ImGui_BeginTabItem(ctx, "Actions") then
            if prev_search ~= "action" then
                update_filter = true
                prev_search = "action"
            end
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            FilterBox(ACTIONS_TBL, "action")
            if r.ImGui_BeginChild(ctx, "##CLIPPER_ACTION", 500) then
                if not r.ImGui_ValidatePtr(ACTION_CLIPPER, 'ImGui_ListClipper*') then
                    ACTION_CLIPPER = r.ImGui_CreateListClipper(ctx)
                end
                r.ImGui_ListClipper_Begin(ACTION_CLIPPER, #FILTERED_TBL) -- We have 1000 elements, evenly spaced
                while r.ImGui_ListClipper_Step(ACTION_CLIPPER) do
                    local display_start, display_end = r.ImGui_ListClipper_GetDisplayRange(ACTION_CLIPPER)
                    for i = display_start, display_end - 1 do
                        if r.ImGui_Selectable(ctx, FILTERED_TBL[i + 1].name, LAST_SEL == i + 1) then
                            LAST_SEL = i + 1
                        end
                        DndSourceAction(FILTERED_TBL[i + 1])
                    end
                end
                r.ImGui_EndChild(ctx)
            end
            r.ImGui_EndTabItem(ctx)
        end
        if not EDITOR and r.ImGui_BeginTabItem(ctx, "Menus", nil, FOCUS_MENU and r.ImGui_TabItemFlags_SetSelected()) then
            if FOCUS_MENU then FOCUS_MENU = nil end
            if prev_search ~= "menu" then
                update_filter = true
                prev_search = "menu"
            end
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            FilterBox(MENUS, "menu")
            -- r.ImGui_SameLine(ctx)
            -- if r.ImGui_Button(ctx, '+') then
            --     MENUS[#MENUS + 1] = {
            --         guid = r.genGuid(),
            --         RADIUS = 150,
            --         --png = "",
            --         --icon = "",
            --         name = "MENU " .. #MENUS,
            --         col = 0xff,
            --         menu =
            --         "is_menu",
            --         guid_list = {}
            --     }
            --     update_filter = true
            -- end
            if r.ImGui_BeginListBox(ctx, "##Menu List", 500, -1) then
                for i = 1, #FILTERED_MENU_TBL do
                    local CROSS_MENU = pie and HasReference(FILTERED_MENU_TBL[i], pie.guid) or nil
                    local SAME_MENU = pie == FILTERED_MENU_TBL[i]
                    r.ImGui_PushID(ctx, i)
                    if r.ImGui_Selectable(ctx, FILTERED_MENU_TBL[i].name .. (CROSS_MENU and " - CANNOT ADD HAS REFERENCE" or ""), LAST_MENU_SEL == i, r.ImGui_SelectableFlags_AllowDoubleClick()) then
                    end
                    local xs, ys = r.ImGui_GetItemRectMin(ctx)
                    local xe, ye = r.ImGui_GetItemRectMax(ctx)
                    -- SELECTED
                    if pie and pie.guid == FILTERED_MENU_TBL[i].guid then
                        r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x22FF2255)
                    end
                    -- ALREADY HAS REFERENCE
                    if CROSS_MENU or SAME_MENU then
                        r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0xFF222255)
                    end
                    --     if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
                    --         LAST_MENU_SEL = i
                    --         TAB_MENU = true
                    --         pie = FILTERED_MENU_TBL[i]
                    --     elseif r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseClicked(ctx, 0) then
                    --         if ALT then
                    --             for j = 1, #MENUS do
                    --                 if MENUS[j] == FILTERED_MENU_TBL[i] then
                    --                     DEL = { MENUS, j, true }
                    --                     update_filter = true
                    --                     break
                    --                 end
                    --             end
                    --             --DEL = { FILTERED_MENU_TBL, i, true }
                    --         else
                    --             for j = 1, #MENUS do
                    --                 if MENUS[j] == FILTERED_MENU_TBL[i] then
                    --                     --DEL = { MENUS, j, true }
                    --                     LAST_MENU_SEL = i
                    --                     break
                    --                 end
                    --             end
                    --         end
                    --     end
                    if not CROSS_MENU and not SAME_MENU then
                        DndSourceMenu(FILTERED_MENU_TBL[i], i)
                    end
                    r.ImGui_PopID(ctx)
                end
                r.ImGui_EndListBox(ctx)
            end
            r.ImGui_EndTabItem(ctx)
        end
        r.ImGui_EndTabBar(ctx)
    end
end

local function AdjustBrightness(channel, delta)
    if channel + delta < 255 then
        return channel + delta
    else
        return 255
    end
end

local function IncreaseDecreaseBrightness(color, amt, no_alpha)
    function AdjustBrightness(channel, delta)
        if channel + delta < 255 then
            return channel + delta
        else
            return 255
        end
    end

    local alpha = color & 0xFF
    local blue = (color >> 8) & 0xFF
    local green = (color >> 16) & 0xFF
    local red = (color >> 24) & 0xFF

    red = AdjustBrightness(red, amt)
    green = AdjustBrightness(green, amt)
    blue = AdjustBrightness(blue, amt)
    alpha = no_alpha and alpha or AdjustBrightness(alpha, amt)

    return (alpha) | (blue << 8) | (green << 16) | (red << 24)
end

function RoughlyEquals(a, b)
    return abs(a - b) < 0.00001
end

local function DNDSwapSRC(tbl, k)
    if r.ImGui_BeginDragDropSource(ctx) then
        r.ImGui_SetDragDropPayload(ctx, 'DND_SWAP', tostring(k))
        r.ImGui_Text(ctx, tbl[k].name)
        SEL_BUTTON = k
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function DNDSwapDST(tbl, k, v)
    if r.ImGui_BeginDragDropTarget(ctx) then
        RV_P, PAYLOAD = r.ImGui_AcceptDragDropPayload(ctx, 'DND_SWAP')
        if RV_P then
            local payload_n = tonumber(PAYLOAD)
            tbl[k] = tbl[payload_n]
            tbl[payload_n] = v
            SEL_BUTTON = k
        end
        r.ImGui_EndDragDropTarget(ctx)
    end
end

local function ImageUVOffset(img_obj, cols, rows, frame, x, y, need_single_frame)
    local w, h = r.ImGui_Image_GetSize(img_obj)

    local xs, ys = x - (w / cols) / 2, y - (h / rows) / 2
    local xe, ye = w / cols + xs, h / rows + ys

    local uv_step_x, uv_step_y = 1 / cols, 1 / rows

    local col_frame = frame --frame % cols
    local row_frame = (frame / cols) // 1

    local uv_xs = col_frame * uv_step_x
    local uv_ys = row_frame * uv_step_y
    local uv_xe = uv_xs + uv_step_x
    local uv_ye = uv_ys + uv_step_y

    if need_single_frame then
        return { xe - xs, ye - ys, uv_xs, uv_ys, uv_xe, uv_ye }
    else
        r.ImGui_DrawList_AddImage(draw_list, img_obj, xs, ys, xe, ye, uv_xs, uv_ys, uv_xe, uv_ye)
    end
end

local function LerpAlpha(col, prog)
    local rr, gg, bb, aa = r.ImGui_ColorConvertU32ToDouble4(col)
    return r.ImGui_ColorConvertDouble4ToU32(rr, gg, bb, aa * prog)
end

local function DrawFlyButton(pie, selected, hovered, center)
    local active = hovered or selected
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local button_center = { x = xs + (w / 2), y = ys + (h / 2) }

    local name, color = pie.name, pie.col == 0xff and def_color or pie.col

    --local icon = #pie.icon ~= 0 and pie.icon or nil
    local icon = pie.icon --~= 0 and pie.icon or nil
    -- local png = (pie.png and #pie.png ~= 0) and pie.png or nil
    local png = pie.png

    if png then
        --def_color = 0x202020ff
        color = def_color
    end

    local icon_col = 0xffffffff
    local icon_font = active and ICON_FONT_LARGE or ICON_FONT_SMALL
    local icon_font_size = active and ICON_FONT_LARGE_SIZE or ICON_FONT_SMALL_SIZE

    --local button_edge_col = 0x060912ff --IncreaseDecreaseBrightness(def_color, -30)--0x25283eff

    local menu_preview_radius = 8
    --local menu_preview_color = def_color --0x25283eff
    local state_spinner_col = 0xff0000ff

    --local col = active and IncreaseDecreaseBrightness(color, 30) or color
    --col = (hovered and ALT) and def_color or col


    local button_radius = active and 35 or 25

    if hovered and r.ImGui_IsMouseDown(ctx, 0) then
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius + 4), 0xffffff77, 128, 14)
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)

    if selected then
        local scale = (sin(r.time_precise() * 5) * 0.05) + 1.01
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y,
            (pie.menu and button_radius + 15 or button_radius + 8) * scale,
            LerpAlpha(0xffffffaa, (sin(r.time_precise() * 5) * 0.5) + 0.7),
            128, 2.5)
    end

    -- BG
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, button_radius + 4, def_out_ring, 128)

    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, button_radius, def_color, 128)

    if png then
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, button_radius - 1.5,
            pie.col == 0xff and def_color or pie.col, 128, 2.5)
    end

    -- CUSTOM BG
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, button_radius - 4, color, 128)

    -- DRAW MENU ITEMS PREVIEW
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    if pie.menu then
        local menu_num = #pie == 0 and 12 or #pie
        local item_arc_span = (2 * pi) / menu_num --.menu
        for i = 1, menu_num do                    --.menu do
            local cur_angle = (item_arc_span * (i - 1) + START_ANG) % (2 * pi)
            local button_pos = {
                x = button_center.x + (button_radius + 2) * cos(cur_angle),
                y = button_center.y + (button_radius + 2) * sin(cur_angle),
            }
            if #pie ~= 0 then
                r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, menu_preview_radius,
                    def_menu_prev, 0)
            end
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, (menu_preview_radius + 1.5),
                dark_theme and def_out_ring or def_color, 128)
            if #pie ~= 0 then
                r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, menu_preview_radius,
                    def_menu_prev,
                    128)
            end
        end
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)

    if selected then
        LAST_MSG = name
        -- r.ImGui_PushFont(ctx, SYSTEM_FONT)
        -- local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, name:upper())
        -- local t_x, t_y = WX + center.x - txt_w / 2, WY + center.y - txt_h / 2
        -- r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, t_x + 1, t_y + 1, 0xaa, name:upper())
        -- r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, t_x, t_y, 0xffffffff, name:upper())
        -- r.ImGui_PopFont(ctx)
    end

    if icon and not png then
        r.ImGui_PushFont(ctx, icon_font)
        local icon_w, icon_h = r.ImGui_CalcTextSize(ctx, icon)
        local i_x, i_y = button_center.x - icon_w / 2, button_center.y - icon_h / 2
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size, i_x + 2, i_y + 2, 0xaa, icon)
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size, i_x, i_y, icon_col, icon)
        r.ImGui_PopFont(ctx)
    end

    if png then
        if not r.ImGui_ValidatePtr(pie.img_obj, 'ImGui_Image*') then
            pie.img_obj = r.ImGui_CreateImage(png)
        end
        ImageUVOffset(pie.img_obj, 3, 1, hovered and 2 or 0, button_center.x, button_center.y)
    end
end


local function StyleFly(pie, center, drag_angle, active)
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)

    local item_arc_span = ((2 * pi) / #pie)
    local center_x, center_y = center.x, center.y

    local RADIUS = pie.RADIUS
    local RADIUS_MIN = RADIUS / 2.2

    --local arc_col = ARC_COLOR

    for i = 1, #pie do
        -- local ang_min = (item_arc_span) * (i - (0.5)) + START_ANG
        --local ang_max = (item_arc_span) * (i + (0.5)) + START_ANG
        local angle = item_arc_span * i

        local button_pos = {
            x = center_x + (RADIUS_MIN + 60) * cos(angle + START_ANG) - 22,
            y = center_y + (RADIUS_MIN + 60) * sin(angle + START_ANG) - 22,
        }

        r.ImGui_SetCursorPos(ctx, button_pos.x, button_pos.y)
        r.ImGui_PushID(ctx, i)
        r.ImGui_InvisibleButton(ctx, "##AAA", 45, 45)
        if r.ImGui_IsItemClicked(ctx, 0) then
            if ALT then
                DEL = { pie, i, nil, pie[i].menu }
            else
                pie.selected = i
            end
        end
        if pie[i].menu then
            if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
                local src_menu, menu_id = InTbl(MENUS, pie[i].guid)
                if src_menu then
                    LAST_MENU_SEL = menu_id
                    TAB_MENU = true
                end
                table.insert(PIE_LIST, {
                    src_menu
                })
                cur_menu_item = #PIE_LIST
                SWITCH_PIE = src_menu
            end
            DndAddTargetMenu(pie, pie[i])
        else
            DndAddTargetAction(pie, pie[i])
        end
        r.ImGui_PopID(ctx)
        DNDSwapSRC(pie, i)
        DNDSwapDST(pie, i, pie[i])
        DrawFlyButton(pie[i], pie.selected == i, r.ImGui_IsItemHovered(ctx), center)
    end
end

local function WrappText(txt, center)
    local bw, bh = r.ImGui_GetItemRectSize(ctx)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)

    r.ImGui_PushTextWrapPos(ctx, center.x + bw / 2)
    r.ImGui_SetCursorScreenPos(ctx, xs, ys + (bh / 2) - (LAST_TXT_H and (LAST_TXT_H / 2) or 0))

    r.ImGui_PushClipRect(ctx, xs, ys, xe, ye, false)
    r.ImGui_Text(ctx, txt)
    r.ImGui_PopClipRect(ctx)

    local w, h = r.ImGui_GetItemRectSize(ctx)
    LAST_TXT_H = h <= bh and h or bh
    r.ImGui_PopTextWrapPos(ctx)
end

local function TextSplitByWidth(text, width , height)
    local str_tbl = {}
    local str = {}
    local total = 0
    for word in text:gmatch("%S+") do
        local w = r.ImGui_CalcTextSize(ctx, word .. " ")
        if total + w < width then
            str[#str + 1] = word
            total = total + w
        else
            str_tbl[#str_tbl + 1] = table.concat(str, " ")
            str = {}
            str[#str + 1] = word
            total = r.ImGui_CalcTextSize(ctx, word .. " ")
        end
    end

    if #str ~= 0 then
        str_tbl[#str_tbl + 1] = table.concat(str, " ")
    end

    local bw, bh = r.ImGui_GetItemRectSize(ctx)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)

    local _, txt_h = r.ImGui_CalcTextSize(ctx, text)
    r.ImGui_PushClipRect(ctx, xs, ys, xe, ye, false)
    local f_size = r.ImGui_GetFontSize(ctx)
    local h_cnt = 0
    for i = 1, #str_tbl do
        if (txt_h *i) < height-2 then
            h_cnt = h_cnt + 1
        end
    end
    for i = 1, #str_tbl do
        local str_w = r.ImGui_CalcTextSize(ctx, str_tbl[i])
        r.ImGui_SetCursorScreenPos(ctx, xs + bw / 2 - str_w / 2,
            ys + (bh / 2) - (txt_h * (h_cnt - (i - 1))) + (h_cnt * txt_h) / 2)
            if (txt_h * i-1) + f_size < height then
                r.ImGui_Text(ctx, str_tbl[i])
            end
    end
    r.ImGui_PopClipRect(ctx)
end

-- local function TextSplitByWidth2(text, width)
--     local str_tbl = {}
--     local total = 0
--     local start = 1
--     for i=1, #text do
--         local c = text:sub(i,i)
--         local w = r.ImGui_CalcTextSize(ctx, c)
--         if total + w >= width then
--             str_tbl[#str_tbl+1] = text:sub(start,i)
--             start = i
--             total = 0
--         else
--             total = total + w
--         end
--     end
--     local last_str = text:sub(start, #text)
--     if last_str ~= str_tbl[#str_tbl] then
--         str_tbl[#str_tbl +1] = last_str
--     end

--     local bw, bh = r.ImGui_GetItemRectSize(ctx)
--     local xs, ys = r.ImGui_GetItemRectMin(ctx)
--     local _, txt_h = r.ImGui_CalcTextSize(ctx, text)
--     for i = 1, #str_tbl do
--         local str_w = r.ImGui_CalcTextSize(ctx, str_tbl[i])
--         r.ImGui_SetCursorScreenPos(ctx, xs + bw/2 - str_w/2, ys + (bh/2) - (txt_h * (#str_tbl-(i-1))) + (#str_tbl*txt_h)/2)
--         r.ImGui_Text(ctx, str_tbl[i])
--     end
--     return s
-- end

local function DrawCenter(pie, center)
    local drag_delta = { MX - (WX + center.x), MY - (WY + center.y) }
    local drag_dist = (drag_delta[1] ^ 2) + (drag_delta[2] ^ 2)
    local drag_angle = (atan(drag_delta[2], drag_delta[1])) % (pi * 2)

    local RADIUS = pie.RADIUS
    local RADIUS_MIN = RADIUS / 2.2

    local button_wh = (RADIUS_MIN / math.sqrt(2)) * 2

    r.ImGui_SetCursorScreenPos(ctx, WX + center.x - (button_wh / 2), WY + center.y - (button_wh / 2))

    local active = (drag_dist >= RADIUS_MIN ^ 2)

    local main_clicked = (r.ImGui_IsMouseDown(ctx, 0) and not active)
    if not pie.selected then
        local scale = (sin(r.time_precise() * 5) * 0.05) + 1.01
        r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, (RADIUS_MIN + 4) * scale,
            LerpAlpha(0xffffffaa, (sin(r.time_precise() * 5) * 0.5) + 0.7),
            128, 2.5)
    end

    r.ImGui_DrawList_AddCircleFilled(draw_list, WX + center.x, WY + center.y, RADIUS_MIN, def_out_ring, 64)  --def_out_ring
    r.ImGui_DrawList_AddCircleFilled(draw_list, WX + center.x, WY + center.y, RADIUS_MIN - 4, def_color, 64) -- def_color

    -- if pie.png then
    --     r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, (RADIUS_MIN - 4),
    --         pie.col == 0xff and def_color or pie.col, 128, 2.5)
    -- end

    if main_clicked then
        r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, (RADIUS_MIN - 10), 0xffffff77, 128, 14)
    end

    r.ImGui_InvisibleButton(ctx, "##CENTER", button_wh, button_wh)
    --if not pie.selected then
    r.ImGui_PushFont(ctx, SYSTEM_FONT)
    local msg = LAST_MSG or pie.name
    --local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, msg)
    TextSplitByWidth(msg, button_wh, button_wh)
    --WrappText(msg, center)
    --r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, WX + center.x - txt_w / 2,
    --    WY + center.y - (txt_h / 2) - (#PIE_LIST ~= 0 and 30 or 0),        0xffffffff,        msg)
    r.ImGui_PopFont(ctx)
    --end
    if not active and r.ImGui_IsMouseReleased(ctx, 0) then
        pie.selected = nil
    end

    -- if pie.png then
    --     if not r.ImGui_ValidatePtr(pie.img_obj, 'ImGui_Image*') then
    --         pie.img_obj = r.ImGui_CreateImage(pie.png)
    --     end
    --     ImageUVOffset(pie.img_obj, 3, 1, 0, WX + center.x, WY + center.y)
    -- end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    LAST_MSG = nil
    return drag_angle, active
end

-- local context_cur_item = 0
-- cur_menu_item = 0
-- local menu_items = {
--     "arrange",
--     "arrangeempty",
--     "tcp",
--     "tcpempty",
--     "mcp",
--     "mcpempty",
--     "envelope",
--     "envcp",
--     "item",
--     "trans",
-- }

function DrawListButton(name, color, hover, active)
    local function CalculateFontColor(org_color)
        local alpha = org_color & 0xFF
        local blue = (org_color >> 8) & 0xFF
        local green = (org_color >> 16) & 0xFF
        local red = (org_color >> 24) & 0xFF

        local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
        return luminance > 0.5 and 0xFF or 0xFFFFFFFF
    end
    local rect_col = color
    rect_col = active and 0x38aa53ff or rect_col
    rect_col = hover and IncreaseDecreaseBrightness(rect_col, 50) or rect_col
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye,
        r.ImGui_GetColorEx(ctx, rect_col), 5, r.ImGui_DrawFlags_RoundCornersAll())

    r.ImGui_PushFont(ctx, SYSTEM_FONT)

    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local font_size = r.ImGui_GetFontSize(ctx)
    local font_color = CalculateFontColor(color)

    local txt_x = xs + (w / 2) - (label_size / 2)

    local txt_y = ys + (h / 2) - (font_size / 2)
    r.ImGui_DrawList_AddTextEx(draw_list, nil, font_size, txt_x, txt_y, r.ImGui_GetColorEx(ctx, font_color), name)

    r.ImGui_PopFont(ctx)
end

local function DrawPie(tbl, pos)
    local WW, WH = r.ImGui_GetWindowSize(ctx)
    if r.ImGui_BeginChild(ctx, "##PIEDRAW", WW - 535 - pos, 0, true) then
        r.ImGui_SameLine(ctx)
        r.ImGui_SetNextItemWidth(ctx, 110)
        if not EDITOR then
            rv_menu, context_cur_item = r.ImGui_Combo(ctx, "##Context", context_cur_item,
                table.concat(menu_items, "\0") .. "\0",
                100)
            if rv_menu then
                SWITCH_PIE = PIES[menu_items[context_cur_item + 1]]
                PIE_LIST = {}
            end
            for i = 0, #PIE_LIST do
                r.ImGui_SameLine(ctx)
                r.ImGui_PushID(ctx, "##menu_btn" .. i)
                local txt_w = r.ImGui_CalcTextSize(ctx, i == 0 and "MAIN" or PIE_LIST[i][1].name)
                if i == 0 then
                    if r.ImGui_InvisibleButton(ctx, "MAIN", txt_w + 25, 20) then
                        SWITCH_PIE = PIES[menu_items[context_cur_item + 1]]
                        cur_menu_item = 0
                        CLEAR_PIE_LIST = 0
                    end
                else
                    r.ImGui_Text(ctx, ">")
                    r.ImGui_SameLine(ctx)
                    if r.ImGui_InvisibleButton(ctx, PIE_LIST[i][1].name, txt_w + 25, 20) then
                        cur_menu_item = i
                        CLEAR_PIE_LIST = i
                        SWITCH_PIE = PIE_LIST[i][1]
                    end
                end
                DrawListButton(i == 0 and "MAIN" or PIE_LIST[i][1].name, 0x294a7aff, r.ImGui_IsItemHovered(ctx),
                    cur_menu_item == i)
                r.ImGui_PopID(ctx)
            end
            if CLEAR_PIE_LIST then
                for i = #PIE_LIST, 1, -1 do
                    if i > CLEAR_PIE_LIST then table.remove(PIE_LIST, i) end
                end
                CLEAR_PIE_LIST = nil
            end

            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, '+') then
                MENUS[#MENUS + 1] = {
                    guid = r.genGuid(),
                    RADIUS = 150,
                    name = "MENU " .. #MENUS,
                    col = 0xff,
                    menu = "is_menu",
                    guid_list = {}
                }
                table.insert(tbl, MENUS[#MENUS])
                tbl.selected = #tbl
                update_filter = true
            end
        end
        if not EDITOR then
            if not r.ImGui_ValidatePtr(SPLITTER_PIE, 'ImGui_DrawListSplitter*') then
                SPLITTER_PIE = r.ImGui_CreateDrawListSplitter(draw_list)
            end
        else
            if not r.ImGui_ValidatePtr(SPLITTER_EDITOR, 'ImGui_DrawListSplitter*') then
                SPLITTER_EDITOR = r.ImGui_CreateDrawListSplitter(draw_list)
            end
        end
        SPLITTER = EDITOR and SPLITTER_EDITOR or SPLITTER_PIE
        local x, y = r.ImGui_GetContentRegionAvail(ctx)
        local center = { x = x / 2, y = y / 1.7 }

        WX, WY = r.ImGui_GetWindowPos(ctx)
        MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())

        r.ImGui_DrawListSplitter_Split(SPLITTER, 3)
        local drag_angle, active = DrawCenter(tbl, center)
        StyleFly(tbl, center, drag_angle, active)

        r.ImGui_DrawListSplitter_Merge(SPLITTER)

        r.ImGui_SetCursorPosY(ctx, WH - 85)
        if r.ImGui_Button(ctx, "Apply Changes") then
            MakePieFile()
        end

        r.ImGui_EndChild(ctx)
    end
end

ICON = ''
local letters = {}
for i = 33, 254 do letters[#letters + 1] = utf8.char(i) end

local function IconSelector(font, button_size)
    local ret, icon = false, nil
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x - 3, y + 5)
    r.ImGui_SetNextWindowSize(ctx, 500, 470)
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    if r.ImGui_BeginPopup(ctx, "Icon Selector") then
        r.ImGui_PushFont(ctx, font)
        local item_spacing_x, item_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
        item_spacing_x = item_spacing_y
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), item_spacing_y, item_spacing_y)
        local buttons_count = #letters
        local window_visible_x2 = ({ r.ImGui_GetWindowPos(ctx) })[1] +
            ({ r.ImGui_GetWindowContentRegionMax(ctx) })[1]
        for n = 0, #letters - 1 do
            local letter = letters[n + 1]
            r.ImGui_PushID(ctx, n)
            if r.ImGui_Button(ctx, letter, button_size, button_size) then
                ret, icon = true, letter
                r.ImGui_CloseCurrentPopup(ctx)
            end
            local last_button_x2 = r.ImGui_GetItemRectMax(ctx)
            local next_button_x2 = last_button_x2 + item_spacing_x + button_size
            if n + 1 < buttons_count and next_button_x2 < window_visible_x2 then
                r.ImGui_SameLine(ctx)
            end
            r.ImGui_PopID(ctx)
        end
        r.ImGui_PopFont(ctx)
        r.ImGui_PopStyleVar(ctx)
        r.ImGui_EndPopup(ctx)
    end
    return ret, icon
end

local function IconDisplay(font, tbl, icon, button_size)
    r.ImGui_PushFont(ctx, icon and font or nil)
    r.ImGui_PushID(ctx, "ICON")
    local rv
    if r.ImGui_Button(ctx, icon or "ICON", button_size, button_size) then
        if not ALT then
            rv = true
        else
            tbl.icon = nil
        end
    end
    r.ImGui_PopID(ctx)
    r.ImGui_PopFont(ctx)
    return rv
end

local function IconFrame(pie, size)
    if IconDisplay(ICON_FONT_LARGE, pie[pie.selected], pie[pie.selected].icon, size or 20) then
        r.ImGui_OpenPopup(ctx, 'Icon Selector')
    end
    local rv, icon = IconSelector(ICON_FONT_PREVIEW, 24)
    return rv, icon
end

-- local function DrawImageButtonList(button_size, col, png_tbl)
--     local xx, yy = r.ImGui_GetCursorPos(ctx)
--     local w, h = button_size, button_size

--     local ret

--     r.ImGui_Dummy(ctx, w, h) -- PLACE HOLDER
--     local minx, miny = r.ImGui_GetItemRectMin(ctx)
--     local maxx, maxy = r.ImGui_GetItemRectMax(ctx)
--     if r.ImGui_IsRectVisibleEx(ctx, minx, miny, maxx, maxy) then
--         if not r.ImGui_ValidatePtr(png_tbl.img_obj, 'ImGui_Image*') then
--             png_tbl.img_obj = r.ImGui_CreateImage(png_tbl.img)
--         end
--         local uv = ImageUVOffset(png_tbl.img_obj, 3, 1, 0, 0, 0, true)
--         r.ImGui_SetCursorPos(ctx, xx, yy)
--         r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), col)
--         if r.ImGui_ImageButton(ctx, "##png_select", png_tbl.img_obj, w, h, uv[3], uv[4], uv[5], uv[6]) then
--             ret = true
--         end
--         r.ImGui_PopStyleColor(ctx)
--     end
--     return ret
-- end

local PNG_FILTER = ''
local function PngSelector(pie, button_size)
    local ret, png = false, nil
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x - 3, y + 5)
    r.ImGui_SetNextWindowSize(ctx, 500, 400)
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    if r.ImGui_BeginPopup(ctx, "Png Selector") then
        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
        rv_f, PNG_FILTER = r.ImGui_InputTextWithHint(ctx, "##input2", "Search PNG", PNG_FILTER)
        FILTERED_PNG = FilterActions(PNG_TBL, PNG_FILTER)
        local item_spacing_x, item_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
        item_spacing_x = item_spacing_y
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), item_spacing_y, item_spacing_y)
        local buttons_count = #FILTERED_PNG
        local window_visible_x2 = ({ r.ImGui_GetWindowPos(ctx) })[1] + ({ r.ImGui_GetWindowContentRegionMax(ctx) })[1]
        if r.ImGui_BeginChild(ctx, "filtered_pngs_list", 0, 0) then
            for n = 0, #FILTERED_PNG - 1 do
                local image = FILTERED_PNG[n + 1].name
                r.ImGui_PushID(ctx, n)
                -- if DrawImageButtonList(button_size, 0x333333ff, PNG_TBL[n + 1]) then
                --     pie.img_obj = nil
                --     ret, png = true, image
                --     r.ImGui_CloseCurrentPopup(ctx)
                -- end
                if not r.ImGui_ValidatePtr(FILTERED_PNG[n + 1].img_obj, 'ImGui_Image*') then
                    FILTERED_PNG[n + 1].img_obj = r.ImGui_CreateImage(image)
                end
                local uv = ImageUVOffset(FILTERED_PNG[n + 1].img_obj, 3, 1, 0, 0, 0, true)
                if r.ImGui_ImageButton(ctx, "##png_select", FILTERED_PNG[n + 1].img_obj, button_size, button_size, uv[3], uv[4], uv[5], uv[6]) then
                    pie.img_obj = nil
                    ret, png = true, image
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                local last_button_x2 = r.ImGui_GetItemRectMax(ctx)
                local next_button_x2 = last_button_x2 + item_spacing_x + button_size
                if n + 1 < buttons_count and next_button_x2 < window_visible_x2 then
                    r.ImGui_SameLine(ctx)
                end
                r.ImGui_PopID(ctx)
            end
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_PopStyleVar(ctx)
        r.ImGui_EndPopup(ctx)
    end
    return ret, png
end

local function PngDisplay(tbl, img_obj, button_size)
    local rv
    r.ImGui_PushID(ctx, "PNG")

    if img_obj then
        if not r.ImGui_ValidatePtr(img_obj, 'ImGui_Image*') then
            img_obj = r.ImGui_CreateImage(tbl.png)
        end
        local uv = ImageUVOffset(img_obj, 3, 1, 0, 0, 0, true)
        if r.ImGui_ImageButton(ctx, "##prev_png", img_obj, button_size - 6, button_size - 6, uv[3], uv[4], uv[5], uv[6]) then
            if not ALT then
                rv = true
            else
                tbl.png = nil
                tbl.img_obj = nil
            end
        end
    else
        if r.ImGui_Button(ctx, "IMG", button_size, button_size) then
            rv = true
        end
    end
    r.ImGui_PopID(ctx)
    return rv
end

local function PngFrame(pie, size)
    if PngDisplay(pie[pie.selected], pie[pie.selected].img_obj, size or 20) then
        for i = 1, #PNG_TBL do
            PNG_TBL[i].img_obj = nil
        end
        PNG_FILTER = ''
        r.ImGui_OpenPopup(ctx, 'Png Selector')
    end
    local rv, png = PngSelector(pie[pie.selected], 24)
    return rv, png
end

local function CheckKeys()
    ALT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Alt()
    CTRL = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut()
    SHIFT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shift()
    DEL_KEY = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete())
    ESC = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape())
end

function MakePieFile()
    local pies = TableToString(PIES)
    local menus = TableToString(MENUS)
    SaveToFile(pies, pie_file)
    SaveToFile(menus, menu_file)
end

local function pdefer(func)
    r.defer(function()
        local status, err = xpcall(func, debug.traceback)
        if not status then
            local byLine = "([^\r\n]*)\r?\n?"
            local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
            local stack = {}
            for line in string.gmatch(err, byLine) do
                local str = string.match(line, trimPath) or line
                stack[#stack + 1] = str
            end
            r.ShowConsoleMsg(
                "Error: " .. stack[1] .. "\n\n" ..
                "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 3) .. "\n\n" ..
                "Reaper:       \t" .. r.GetAppVersion() .. "\n" ..
                "Platform:     \t" .. r.GetOS()
            )
        end
    end)
end

local txt = "PRESS KEY"
local function DetectShortcut(pie)
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], nil, 0.5, 0.5)
    local close
    if r.ImGui_BeginPopup(ctx, "DETECT_SHORTCUT") then
        for k, v in pairs(KEYS) do
            if r.ImGui_IsKeyPressed(ctx, k) then
                if v == "Escape" then
                    close = true
                    break
                end
                key = k
                break
            end
        end
        r.ImGui_Text(ctx, "\n\t\t" .. txt .. "\t\t\n\n")
        if close then
            r.ImGui_CloseCurrentPopup(ctx)
        end
        if key then
            r.ImGui_CloseCurrentPopup(ctx)
            pie[pie.selected].key = key
            key = nil
            txt = "PRESS KEY"
        end
        r.ImGui_EndPopup(ctx)
    end
end

local function Properties(pie)
    if r.ImGui_BeginChild(ctx, "##PROPERTIES_WND", 0, 0, true) then
        ActionsTab(pie)
        r.ImGui_EndChild(ctx)
    end
end

function ModalWarning()
    local rv
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'WARNING', nil, r.ImGui_WindowFlags_AlwaysAutoResize()) then
        r.ImGui_Text(ctx, "This will Clear/Delete whole context\nAre you sure?")
        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'OK', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            rv = true
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'CANCEL', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
            r.ImGui_CloseCurrentPopup(ctx)
            CLEAR_PIE = nil
        end
        r.ImGui_EndPopup(ctx)
    end
    return rv
end

local function Delete()
    if DEL then
        if DEL[1].selected and DEL[1].selected == DEL[2] then
            DEL[1].selected = nil
        end
        -- is menu
        if DEL[3] then
            --  DELETE MENU EVERYWHERE
            ClearMenusAfterDelete(DEL[1][DEL[2]].guid, MENUS)
            ClearMenusAfterDelete(DEL[1][DEL[2]].guid, PIES)
        end

        if DEL[4] then
            -- CLEAR REFERENCES ONLY
            HasReference(DEL[1], DEL[1][DEL[2]].guid, true)
            --ClearMenusAfterDelete(DEL[1][DEL[2]].guid, MENUS, true)
            --ClearMenusAfterDelete(DEL[1][DEL[2]].guid, PIES)
        end
        table.remove(DEL[1], DEL[2])
        DEL = nil
    end
    if CLEAR_PIE then
        if ModalWarning() then
            for i = #CLEAR_PIE, 1, -1 do
                CLEAR_PIE[i] = nil
            end
            CLEAR_PIE = nil
        end
    end
end

local function NewProperties(pie)
    if r.ImGui_BeginChild(ctx, "PROPERTIES", 0, 185, true) then
        if pie.selected then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0)
            local rv_i, icon = IconFrame(pie, 50)
            if rv_i then
                pie[pie.selected].icon = icon
            end
            r.ImGui_SameLine(ctx)
            local rv_png, png = PngFrame(pie, 50)
            if rv_png then
                pie[pie.selected].png = png
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "CLEAR", 50, 50) then
                pie[pie.selected].png = nil
                pie[pie.selected].img_obj = nil
                pie[pie.selected].icon = nil
            end
            r.ImGui_PopStyleColor(ctx)
            -- ICON / PNG
            r.ImGui_PushID(ctx, "col_remove")
            r.ImGui_SeparatorText(ctx, "NAME / COLOR")
            if not pie[pie.selected].menu then
                -- r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
                -- r.ImGui_BeginDisabled(ctx, true)
                r.ImGui_Text(ctx, pie[pie.selected].cmd_name)
                -- rv_i, pie[pie.selected].cmd_name = r.ImGui_InputTextWithHint(ctx, "##ActName", "Action name",
                --     pie[pie.selected].cmd_name)
                -- r.ImGui_EndDisabled(ctx)
            end

            if r.ImGui_Button(ctx, "X") then pie[pie.selected].col = 0xff end
            r.ImGui_PopID(ctx)

            r.ImGui_SameLine(ctx)
            RV_COL, pie[pie.selected].col = r.ImGui_ColorEdit4(ctx, 'MyColor##3', pie[pie.selected].col,
                r.ImGui_ColorEditFlags_NoInputs() | r.ImGui_ColorEditFlags_NoLabel())
            r.ImGui_SameLine(ctx)
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            rv_i, pie[pie.selected].name = r.ImGui_InputTextWithHint(ctx, "##ButtonName", "Button name",
                pie[pie.selected].name)
            r.ImGui_PushID(ctx, "sct_remove")
            if r.ImGui_Button(ctx, "X") then pie[pie.selected].key = nil end
            r.ImGui_PopID(ctx)
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, pie[pie.selected].key and "Key " .. KEYS[pie[pie.selected].key] or "ASSIGN KEY", -FLT_MIN) then
                r.ImGui_OpenPopup(ctx, "DETECT_SHORTCUT")
            end
            r.ImGui_Separator(ctx)
            if r.ImGui_Button(ctx, "Delete Button") then
                DEL = { pie, pie.selected, nil, pie[pie.selected].menu }
            end
            DetectShortcut(pie)
        else
            r.ImGui_SeparatorText(ctx, "RADIUS")
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            RV_R, pie.RADIUS = r.ImGui_SliderInt(ctx, "##RADIUS", pie.RADIUS, 50, 270)
            if not EDITOR and #PIE_LIST == 0 then
                if pie.name == "ARRANGE" or pie.name == "TCP" or pie.name == "MCP" then
                    if r.ImGui_Checkbox(ctx, "USE AS EMPTY CONTEXT", pie.sync) then
                        pie.sync = not pie.sync
                    end
                end
                if r.ImGui_Button(ctx, "Clear Context") then
                    OPEN_WARNING = true
                    CLEAR_PIE = pie
                end
            end
        end
        r.ImGui_EndChild(ctx)
    end
end

local function MenuEditList(pie)
    if r.ImGui_BeginChild(ctx, "EDITMENULIST", 250, 0, true) then
        if FOCUS_MENU then FOCUS_MENU = nil end
        if prev_search ~= "menu" then
            update_filter = true
            prev_search = "menu"
        end

        if r.ImGui_Button(ctx, 'Create New Menu', -FLT_MIN, 0) then
            MENUS[#MENUS + 1] = {
                guid = r.genGuid(),
                RADIUS = 150,
                name = "MENU " .. #MENUS,
                col = 0xff,
                menu =
                "is_menu",
                guid_list = {}
            }
            LAST_MENU_SEL = #MENUS
            update_filter = true
        end
        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
        FilterBox(MENUS, "menu")
        -- r.ImGui_SameLine(ctx)
        if r.ImGui_BeginListBox(ctx, "##Menu List", 500, -1) then
            for i = 1, #FILTERED_MENU_TBL do
                local CROSS_MENU = pie and HasReference(FILTERED_MENU_TBL[i], pie.guid) or nil
                local SAME_MENU = pie == FILTERED_MENU_TBL[i]
                r.ImGui_PushID(ctx, i)
                if r.ImGui_Selectable(ctx, FILTERED_MENU_TBL[i].name .. (CROSS_MENU and " - CANNOT ADD HAS REFERENCE" or ""), LAST_MENU_SEL == i, r.ImGui_SelectableFlags_AllowDoubleClick()) then
                end
                local xs, ys = r.ImGui_GetItemRectMin(ctx)
                local xe, ye = r.ImGui_GetItemRectMax(ctx)
                -- SELECTED
                if pie and pie.guid == FILTERED_MENU_TBL[i].guid then
                    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x22FF2255)
                end
                -- ALREADY HAS REFERENCE
                if CROSS_MENU then
                    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0xFF222255)
                end
                if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
                    LAST_MENU_SEL = i
                    SWITCH_PIE = FILTERED_MENU_TBL[i]
                elseif r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseClicked(ctx, 0) then
                    if ALT then
                        for j = 1, #MENUS do
                            if MENUS[j] == FILTERED_MENU_TBL[i] then
                                DEL = { MENUS, j, true }
                                update_filter = true
                                break
                            end
                        end
                        --DEL = { FILTERED_MENU_TBL, i, true }
                    else
                        for j = 1, #MENUS do
                            if MENUS[j] == FILTERED_MENU_TBL[i] then
                                --DEL = { MENUS, j, true }
                                LAST_MENU_SEL = i
                                break
                            end
                        end
                    end
                end
                if not CROSS_MENU and not SAME_MENU then
                    DndSourceMenu(FILTERED_MENU_TBL[i], i)
                end
                r.ImGui_PopID(ctx)
            end
            r.ImGui_EndListBox(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
end

local function Main2()
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 900, 500, FLT_MAX, FLT_MAX)

    local visible, open = r.ImGui_Begin(ctx, 'Pie 3000 Setup', true)
    if visible then
        WX, WY = r.ImGui_GetWindowPos(ctx)
        CheckKeys()
        if r.ImGui_BeginTabBar(ctx, "MAIN_TAB_BAR") then
            if r.ImGui_BeginTabItem(ctx, "Pie") then
                if EDITOR then EDITOR = nil end
                if SWITCH_PIE then
                    CUR_PIE = SWITCH_PIE
                    SWITCH_PIE = nil
                end
                DrawPie(CUR_PIE, 0)
                DndAddTargetAction(CUR_PIE)
                DndAddTargetMenu(CUR_PIE)
                r.ImGui_SameLine(ctx)
                r.ImGui_BeginGroup(ctx)
                r.ImGui_SeparatorText(ctx, "Button Properties")
                NewProperties(CUR_PIE)
                r.ImGui_SeparatorText(ctx, "Drag'n'Drop into Pie Window")
                Properties(CUR_PIE)
                r.ImGui_EndGroup(ctx)
                r.ImGui_EndTabItem(ctx)
            end
            if r.ImGui_BeginTabItem(ctx, "Custom Menu Editor") then
                if not EDITOR then EDITOR = true end
                if SWITCH_PIE then
                    CUR_MENU_PIE = SWITCH_PIE
                    SWITCH_PIE = nil
                end
                DrawPie(CUR_MENU_PIE, 258)
                DndAddTargetAction(CUR_MENU_PIE)
                DndAddTargetMenu(CUR_MENU_PIE)
                r.ImGui_SameLine(ctx)
                MenuEditList(CUR_MENU_PIE)
                r.ImGui_SameLine(ctx)
                r.ImGui_BeginGroup(ctx)
                r.ImGui_SeparatorText(ctx, "Button Properties")
                NewProperties(CUR_MENU_PIE)
                r.ImGui_SeparatorText(ctx, "Drag'n'Drop into Pie Window")
                Properties(CUR_MENU_PIE)
                r.ImGui_EndGroup(ctx)
                r.ImGui_EndTabItem(ctx)
            end
            if r.ImGui_BeginTabItem(ctx, "Settings") then
                if r.ImGui_Checkbox(ctx, "Hold to OPEN", HOLD_TO_OPEN) then
                    HOLD_TO_OPEN = not HOLD_TO_OPEN
                    WANT_SAVE = true
                end
                if r.ImGui_Checkbox(ctx, "Activate Action on Close", ACTIVATE_ON_CLOSE) then
                    ACTIVATE_ON_CLOSE = not ACTIVATE_ON_CLOSE
                    WANT_SAVE = true
                end
                if r.ImGui_Checkbox(ctx, "Animation", ANIMATION) then
                    ANIMATION = not ANIMATION
                    WANT_SAVE = true
                end
                if WANT_SAVE then
                    local data = TableToString(
                        {
                            animation = ANIMATION,
                            hold_to_open = HOLD_TO_OPEN,
                            activate_on_close = ACTIVATE_ON_CLOSE,

                        }, true)
                    r.SetExtState("PIE3000", "SETTINGS", data, true)
                    WANT_SAVE = nil
                end
                r.ImGui_EndTabItem(ctx)
            end

            r.ImGui_EndTabBar(ctx)
        end
        r.ImGui_End(ctx)
    end
    if OPEN_WARNING then
        OPEN_WARNING = nil
        r.ImGui_OpenPopup(ctx, "WARNING")
    end
    Delete()

    if open then
        if DBG then
            DEBUG.defer(Main2)
        else
            pdefer(Main2)
        end
    else
        MakePieFile()
    end
end

if DBG then
    DEBUG.defer(Main2)
else
    pdefer(Main2)
end
