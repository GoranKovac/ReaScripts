--@noindex
--NoIndex: true
local r = reaper

local info = debug.getinfo(1, 'S');
local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. "?.lua;"

require('PieUtils')
if CheckDeps() then return end
local ctx = r.ImGui_CreateContext('PIE 3000 SETUP')

local FONT_SIZE = 15
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
    ["tcp"] = {},
    ["mcp"] = {},
    ["envelope"] = {},
    ["item"] = {}
}

local draw_list = r.ImGui_GetWindowDrawList(ctx)

local pi, max, floor, cos, sin, atan, ceil, abs = math.pi, math.max, math.floor, math.cos, math.sin, math.atan, math
    .ceil, math.abs

local START_ANG = (3 * pi) / 2
local RADIUS = 150
local def_color = 0x25283eFF
local ARC_COLOR = 0x11AAFF88

local PIES = ReadFromFile(pie_file) or {
    ["arrange"] = { RADIUS = RADIUS, name = "ARRANGE", guid = r.genGuid() },
    ["tcp"] = { RADIUS = RADIUS, name = "TCP", guid = r.genGuid() },
    ["mcp"] = { RADIUS = RADIUS, name = "MCP", guid = r.genGuid() },
    ["envelope"] = { RADIUS = RADIUS, name = "ENVELOPE", guid = r.genGuid() },
    ["item"] = { RADIUS = RADIUS, name = "ITEM", guid = r.genGuid() }
}

local MENUS = ReadFromFile(menu_file) or {}

local function LinkMenus(tbl)
    for k, v in ipairs(tbl) do
        for i = 1, #v do
            if type(v[i]) == "table" then
                local parent = InTbl(MENUS, v[i].guid)
                if parent then
                     v[i] = parent
                     LinkMenus(v[i])
                end
            end
        end
    end
end

LinkMenus(MENUS)

local CUR_TAB = "arrange"
local CUR_PIE = PIES[CUR_TAB]

local function LinkPieMenusWithSrcMenus(tbl)
    for k,v in pairs(tbl) do
        for i = 1, #v do
            if v[i].menu then       
                local parent = InTbl(MENUS, v[i].guid)
                if parent then
                   -- AAA = parent
                    v[i] = parent
                end
            end
        end
    end
end

LinkPieMenusWithSrcMenus(PIES)

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
local FILTER = ''

local function FilterBox()    
    rv_f, FILTER = r.ImGui_InputTextWithHint(ctx, "##input", "Search Actions", FILTER)
    if rv_f then
        FILTERED_TBL = FilterActions(ACTIONS_TBL, FILTER)
    end
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

local function DndAddTargetAction()
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND ACTION')
        local name, cmd = payload:match("(.+)|(.+)")
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local insert_pos = #CUR_PIE ~= 0 and #CUR_PIE or 1
            table.insert(CUR_PIE, insert_pos, { icon = "", name = "EMPTY", cmd = cmd, cmd_name = name, col = def_color })
            CUR_PIE.selected = insert_pos
        end
    end
end

local function DndAddTargetMenu()
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND Menu')
        local menu_id = tonumber(payload)
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local insert_pos = #CUR_PIE ~= 0 and #CUR_PIE or 1
            table.insert(CUR_PIE, insert_pos, MENUS[menu_id])
            CUR_PIE.selected = insert_pos
        end
    end
end

local function ActionsTab()
    if r.ImGui_BeginChild(ctx, "Action_menus", 500, -1) then
        if r.ImGui_BeginTabBar(ctx, "ACTIONS MENUS TAB") then
            if r.ImGui_BeginTabItem(ctx, "Actions") then
                r.ImGui_SetNextItemWidth(ctx, 500)
                FilterBox()
                if r.ImGui_BeginListBox(ctx, "##Actions List", 500, -1) then
                    for i = 1, #FILTERED_TBL do
                        if r.ImGui_Selectable(ctx, FILTERED_TBL[i].name, LAST_SEL == i) then
                            LAST_SEL = i
                        end
                        if r.ImGui_IsItemActive(ctx) then LAST_SEL = i end
                        DndSourceAction(FILTERED_TBL[i])
                    end
                    r.ImGui_EndListBox(ctx)
                end
                r.ImGui_EndTabItem(ctx)
            end
            if r.ImGui_BeginTabItem(ctx, "Menus") then
                r.ImGui_SetNextItemWidth(ctx, 476)
                FilterBox()
                r.ImGui_SameLine(ctx)
                if r.ImGui_Button(ctx, '+') then
                    MENUS[#MENUS+1] = { guid = r.genGuid(), RADIUS = 150, icon = "", name = "MENU " .. #MENUS, col = def_color, menu = "is_menu" }
                end
                if r.ImGui_BeginListBox(ctx, "##Menu List", 500, -1) then
                    for i = 1, #MENUS do
                        r.ImGui_PushID(ctx,i)
                        if r.ImGui_Selectable(ctx, MENUS[i].name, LAST_MENU_SEL == i, r.ImGui_SelectableFlags_AllowDoubleClick()) then
                        end
                            if r.ImGui_IsItemHovered(ctx) and  r.ImGui_IsMouseDoubleClicked(ctx,0) then
                                LAST_MENU_SEL = i
                                TAB_MENU = true
                                CUR_PIE = MENUS[i]
                            elseif r.ImGui_IsItemHovered(ctx) and  r.ImGui_IsMouseClicked( ctx, 0 ) then
                                if ALT then
                                    DEL = {MENUS, i}
                                else
                                    LAST_MENU_SEL = i
                                end
                            end
                        DndSourceMenu(MENUS[i], i)
                        r.ImGui_PopID(ctx)
                    end
                    r.ImGui_EndListBox(ctx)
                end
                r.ImGui_EndTabItem(ctx)
            end
            r.ImGui_EndTabBar(ctx)
        end
        r.ImGui_EndChild(ctx)
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

local function DrawFlyButton(pie, selected, hovered, center)
    local active = hovered or selected
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local button_center = { x = xs + (w / 2), y = ys + (h / 2) }

    local name, color = pie.name, pie.col
    
    local icon = #pie.icon ~= 0 and pie.icon or nil

    local icon_col = 0xffffffff
    local icon_font = active and ICON_FONT_LARGE or ICON_FONT_SMALL
    local icon_font_size = active and ICON_FONT_LARGE_SIZE or ICON_FONT_SMALL_SIZE

    local button_edge_col = 0x25283eff

    local menu_preview_radius = 7
    local menu_preview_color = 0x25283eff
    local state_spinner_col = 0xff0000ff

    local col = active and IncreaseDecreaseBrightness(color, 30) or color
    col = (hovered and ALT) and 0xff2222FF or col


    local button_radius = active and 35 or 25

    if hovered and r.ImGui_IsMouseDown(ctx, 0) then
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius), 0xffffff77, 128, 14)
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)
    -- BG
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, button_radius, col, 128)
    -- EDGE
    r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius - 1), button_edge_col, 128, 3)

    -- DRAW MENU ITEMS PREVIEW
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    if pie.menu then
        local item_arc_span = (2 * pi) / #pie --.menu
        for i = 1, #pie do--.menu do
            local cur_angle = (item_arc_span * (i - 1) + START_ANG) % (2 * pi)
            local button_pos = {
                x = button_center.x + (button_radius - 2) * cos(cur_angle),
                y = button_center.y + (button_radius - 2) * sin(cur_angle),
            }
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, menu_preview_radius,
                menu_preview_color, 0)
        end
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)

    if selected then
        r.ImGui_PushFont(ctx, SYSTEM_FONT)
        local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, name:upper())
        r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, WX + center.x - txt_w / 2, WY + center.y - txt_h / 2,
            0xffffffff,
            name:upper())
        r.ImGui_PopFont(ctx)
    end

    if icon then
        r.ImGui_PushFont(ctx, icon_font)
        local icon_w, icon_h = r.ImGui_CalcTextSize(ctx, icon)
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size, button_center.x - icon_w / 2,
            button_center.y - icon_h / 2, icon_col, icon)
        r.ImGui_PopFont(ctx)
    end
end


local function StyleFly(pie, center, drag_angle, active)
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)

    local item_arc_span = ((2 * pi) / #pie)
    local center_x, center_y = center.x, center.y

    local RADIUS = pie.RADIUS
    local RADIUS_MIN = RADIUS / 2.2

    local arc_col = ARC_COLOR

    for i = 1, #pie do
       -- local ang_min = (item_arc_span) * (i - (0.5)) + START_ANG
        --local ang_max = (item_arc_span) * (i + (0.5)) + START_ANG
        local angle = item_arc_span * i

        local button_pos = {
            x = center_x + (RADIUS_MIN + 50) * cos(angle + START_ANG) - 22,
            y = center_y + (RADIUS_MIN + 50) * sin(angle + START_ANG) - 22,
        }

        r.ImGui_SetCursorPos(ctx, button_pos.x, button_pos.y)
        r.ImGui_PushID(ctx, i)
        r.ImGui_InvisibleButton(ctx, "##AAA", 45, 45)
        if r.ImGui_IsItemClicked(ctx, 0) then
            if ALT then
                DEL = { pie, i }
            else
                pie.selected = i
            end
        end
        if pie[i].menu then
            if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked( ctx, 0 ) then
                local src_menu, menu_id = InTbl(MENUS, pie[i].guid)
                if src_menu then
                    --CUR_PIE = src_menu
                    LAST_MENU_SEL = menu_id
                    TAB_MENU = true
                    --break
                end
            end
        end
        r.ImGui_PopID(ctx)
        DNDSwapSRC(pie, i)
        DNDSwapDST(pie, i, pie[i])
        DrawFlyButton(pie[i], pie.selected == i, r.ImGui_IsItemHovered(ctx), center)
    end
end

local function DrawCenter(pie, center)
    local drag_delta = { MX - (WX + center.x), MY - (WY + center.y) }
    local drag_dist = (drag_delta[1] ^ 2) + (drag_delta[2] ^ 2)
    local drag_angle = (atan(drag_delta[2], drag_delta[1])) % (pi * 2)

    local RADIUS = pie.RADIUS
    local RADIUS_MIN = RADIUS / 2.2

    local active = (drag_dist >= RADIUS_MIN ^ 2)

    local main_clicked = (r.ImGui_IsMouseDown(ctx, 0) and not active)

    r.ImGui_DrawList_AddCircleFilled(draw_list, WX + center.x, WY + center.y, RADIUS_MIN - 10, def_color, 64)
    r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, RADIUS_MIN - 10, 0x25283eff, 0, 4)

    if main_clicked then
        r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, (RADIUS_MIN - 10), 0xffffff77, 128, 14)
    end

    if not pie.selected then
        r.ImGui_PushFont(ctx, SYSTEM_FONT)
        local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, pie.name)
        r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, WX + center.x - txt_w / 2, WY + center.y - txt_h / 2,
            0xffffffff,
            pie.name)
        r.ImGui_PopFont(ctx)
    end
    if not active and r.ImGui_IsMouseReleased(ctx, 0) then
        pie.selected = nil
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)

    return drag_angle, active
end

local function DrawPie(tbl)
    local x = r.ImGui_GetContentRegionAvail(ctx)
    local center = { x = x / 2, y = 360 }

    WX, WY = r.ImGui_GetWindowPos(ctx)
    MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())

    SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    r.ImGui_DrawListSplitter_Split(SPLITTER, 3)
    local drag_angle, active = DrawCenter(tbl, center)
    StyleFly(tbl, center, drag_angle, active)
   
    r.ImGui_DrawListSplitter_Merge(SPLITTER)
end

ICON = ''
local letters = {}
for i = 33, 254 do letters[#letters + 1] = utf8.char(i) end

local function IconSelector(font, button_size)
    local ret, icon = false, nil
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x - 26, y + 23)
    r.ImGui_SetNextWindowSize(ctx, 265, 310)
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
    icon = #icon == 0 and '' or icon
    r.ImGui_PushFont(ctx, font)
    r.ImGui_PushID(ctx, "ICON")
    local rv
    if r.ImGui_Button(ctx, icon, button_size + 10, button_size) then
        if not ALT then
            rv = true
        else
            tbl.icon = ""
        end
    end
    r.ImGui_PopID(ctx)
    r.ImGui_PopFont(ctx)
    r.ImGui_SameLine(ctx)
    return rv
end

local function IconFrame(pie)
    if IconDisplay(ICON_FONT_PREVIEW, pie[pie.selected], pie[pie.selected].icon, 20) then
        r.ImGui_OpenPopup(ctx, 'Icon Selector')
    end
    local rv, icon = IconSelector(ICON_FONT_PREVIEW, 30)
    return rv, icon
end

local function ButtonInfo(pie)
    r.ImGui_SetNextItemWidth(ctx, 200)
    RV_R, pie.RADIUS = r.ImGui_SliderInt(ctx, "RADIUS", pie.RADIUS, 100, 270)
    RADIUS_ACTIVE = r.ImGui_IsItemActive(ctx)

    if CUR_PIE.menu then
        RV_MI, CUR_PIE.name = r.ImGui_InputTextWithHint( ctx, "Menu Name", "Menu name", CUR_PIE.name)     
    end
    -- if r.ImGui_Button(ctx, "ADD BUTTON") then
    --     table.insert(pie,#pie~= 0 and #pie or 1,{ icon = "", name = "EMPTY ", cmd = "", cmd_name = "", col = def_color })
    --   --  pie[#pie + 1] = { icon = "", name = "EMPTY ", cmd = "", cmd_name = "", col = def_color }
    -- end
    -- r.ImGui_SameLine(ctx)
    -- if r.ImGui_Button(ctx, "ADD MENU") then
    --     pie[#pie + 1] = { guid = r.genGuid(), icon = "", name = "MENU ", col = def_color, menu = { pid = pie.guid, guid = r.genGuid(), RADIUS = 150 } }
    -- end
    if not pie.selected then return end
    r.ImGui_BeginGroup(ctx)
    RV_COL, pie[pie.selected].col = r.ImGui_ColorEdit4(ctx, 'MyColor##3', pie[pie.selected].col,
        r.ImGui_ColorEditFlags_NoInputs() | r.ImGui_ColorEditFlags_NoLabel())
    r.ImGui_SameLine(ctx)
    local rv_i, icon = IconFrame(pie)
    if rv_i then
        pie[pie.selected].icon = icon
    end
    r.ImGui_SameLine(ctx)
    rv_i, pie[pie.selected].name = r.ImGui_InputTextWithHint(ctx, "##ButtonName", "Button name", pie[pie.selected].name)
    if pie[pie.selected].cmd then
        r.ImGui_BeginDisabled(ctx, true)
        rv_c, pie[pie.selected].cmd_name = r.ImGui_InputTextWithHint(ctx, "Action Name", "NO ACTION ASSIGNED",
            pie[pie.selected].cmd_name)
        r.ImGui_EndDisabled(ctx)
    end
    r.ImGui_EndGroup(ctx)
end

local function Tabs()
    if r.ImGui_BeginTabBar(ctx, "MAIN TAB") then
        if r.ImGui_BeginTabItem(ctx, "ARRANGE") then
            CUR_TAB = "arrange"
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "TCP") then
            CUR_TAB = "tcp"
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "MCP") then
            CUR_TAB = "mcp"
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "ENVELOPE") then
            CUR_TAB = "envelope"
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "ITEM") then
            CUR_TAB = "item"
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "CUSTOM MENU", true , TAB_MENU and r.ImGui_TabItemFlags_SetSelected()) then
            TAB_MENU = nil
            CUR_TAB = "menu"
            r.ImGui_EndTabItem(ctx)
        end
        if CUR_TAB ~= LAST_TAB then
            if CUR_TAB ~= "menu" then
                CUR_PIE = PIES[CUR_TAB]
                SEL_TBL = SELECTED[CUR_TAB]
            else
                CUR_PIE = MENUS[LAST_MENU_SEL]
            end
            LAST_TAB = CUR_TAB
        end
        r.ImGui_EndTabBar(ctx)
    end
end
local function CheckKeys()
    ALT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Alt()
    CTRL = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut()
    SHIFT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shift()
    DEL_KEY = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete())
end

function MakePieFile()
    local pies = TableToString(PIES)
    local menus = TableToString(MENUS)
    SaveToFile(pies, pie_file)
    SaveToFile(menus, menu_file)
end

local function Main()
    local visible, open = r.ImGui_Begin(ctx, '##Pie3000Setup', true, flags)
    if visible then
        CheckKeys()
        Tabs()
        ActionsTab()
        r.ImGui_SameLine(ctx)
        if r.ImGui_BeginChild(ctx, "##PIEDRAW", 0, 0) then
            if CUR_PIE then
                ButtonInfo(CUR_PIE)
                DrawPie(CUR_PIE)
            end
            r.ImGui_EndChild(ctx)
        end
        DndAddTargetAction()
        DndAddTargetMenu()
        if DEL then
            if DEL[1].selected and DEL[1].selected == DEL[2] then
                DEL[1].selected = nil
            end
            table.remove(DEL[1], DEL[2])
            DEL = nil
        end
        r.ImGui_End(ctx)
    end

    if open then
        r.defer(Main)
    else
        MakePieFile()
    end
end

r.defer(Main)
