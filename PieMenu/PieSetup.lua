local reaper = reaper


local info = debug.getinfo(1, 'S');
local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. "?.lua;"
package.path = package.path .. ";" .. reaper.GetResourcePath() .. "\\Scripts\\LuaDBG\\?.lua;" -- DEBUG FILES PATH

require('PieUtils')
local ctx = reaper.ImGui_CreateContext('My script')
local awesomefont = reaper.ImGui_CreateFont(script_path .. 'PieICONS.ttf', 18)
reaper.ImGui_Attach(ctx, awesomefont)

local fn = script_path .. "pie_menus.txt"
local pie_txt = Read_from_file(fn)
local PIES = StringToTable(pie_txt) or {
        ["arrange"] = {},
        ["tcp"] = {},
        ["mcp"] = {},
        ["envelope"] = {},
        ["item"] = {}
    }

local current_tab = "arrange"

local function iterate_actions(sectionID)
    local i = 0
    return function()
        local retval, name = reaper.CF_EnumerateActions(sectionID, i, '')
        if retval > 0 then
            i = i + 1
            return retval, name
        end
    end
end

local function Get_all_actions()
    local actions = {}
    for id, name in iterate_actions(0) do
        table.insert(actions, { id = id, name = name })
    end
    table.sort(actions, function(a, b) return a.name < b.name end)
    return actions
end

local function Filter_actions(actions, filter_text)
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

local actions = Get_all_actions()
local filtered_actions = actions
local filter = ''

function Filter_BOX()
    local ret, sel_action = false, nil
    rv, filter = reaper.ImGui_InputText(ctx, '##input', filter)
    if rv then
        filtered_actions = Filter_actions(actions, filter)
    end
    local r_s = reaper.ImGui_GetItemRectSize(ctx)
    reaper.ImGui_SameLine(ctx);
    local isOpen = false;
    local isFocused = reaper.ImGui_IsItemFocused(ctx)
    isOpen = #filter > 0;
    if isOpen then
        reaper.ImGui_SetNextWindowPos(ctx, reaper.ImGui_GetItemRectMin(ctx), ({ reaper.ImGui_GetItemRectMax(ctx) })[2])
        reaper.ImGui_SetNextWindowFocus(ctx)
        if reaper.ImGui_BeginChild(ctx, "##popupp", r_s, 200) then
            isFocused = reaper.ImGui_IsWindowFocused(ctx);
            for i = 1, #filtered_actions do
                if reaper.ImGui_Selectable(ctx, filtered_actions[i].name, false) then
                    ret, sel_action = true, filtered_actions[i]
                    filter = ''
                end
            end
            reaper.ImGui_EndChild(ctx)
            isOpen = isOpen and isFocused
        end
        return ret, sel_action
    end
end

local pi, cos, sin, atan = math.pi, math.cos, math.sin, math.atan

local OLD_BUTTON
local function DrawPie(tbl)
    local item_arc_span = 2 * pi / #tbl
    local wx, wy = reaper.ImGui_GetWindowPos(ctx)
    local center_x, center_y = wx + reaper.ImGui_GetWindowWidth(ctx) * 0.25,
        wy + reaper.ImGui_GetWindowHeight(ctx) * 0.05
    local RADIUS = 350

    for k, v in ipairs(tbl) do
        local item_label = tbl[k].name or ""
        local item_ang_min = item_arc_span * ((k - 1) + 0.02) - item_arc_span * 0.5
        local item_ang_max = item_arc_span * ((k - 1) + 0.98) - item_arc_span * 0.5

        local text_size = { reaper.ImGui_CalcTextSize(ctx, item_label) }
        local button_pos = {
            center_x + cos((item_ang_min + item_ang_max) * 0.5) * (RADIUS) * 0.5 - text_size[1] * 0.5,
            center_y + sin((item_ang_min + item_ang_max) * 0.5) * (RADIUS) * 0.5 - text_size[2] * 0.5,
        }
        local x1, y1 = button_pos[1] - 25, button_pos[2] - 5
        reaper.ImGui_SetCursorScreenPos(ctx, x1 - 20 + 140, y1 + 250)
        reaper.ImGui_PushFont(ctx, awesomefont)
        reaper.ImGui_Text(ctx, tbl[k].icon)
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_SetCursorScreenPos(ctx, x1 + 140, y1 + 250)
        if SEL_BUTTON == k then
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x11FFFF80)
            PUSHCOL = true
        end
        if reaper.ImGui_Button(ctx, item_label, (text_size[1] + 10), (text_size[2] + 10)) then SEL_BUTTON = k end
        if PUSHCOL then
            reaper.ImGui_PopStyleColor(ctx)
            PUSHCOL = nil
        end
        if reaper.ImGui_BeginDragDropSource(ctx) then
            reaper.ImGui_SetDragDropPayload(ctx, 'DND_BUTTON', tostring(k))
            reaper.ImGui_Text(ctx, tbl[k].name)
            SEL_BUTTON = k
            reaper.ImGui_EndDragDropSource(ctx)
        end

        if reaper.ImGui_BeginDragDropTarget(ctx) then
            RV_P, PAYLOAD = reaper.ImGui_AcceptDragDropPayload(ctx, 'DND_BUTTON')
            if RV_P then
                local payload_n = tonumber(PAYLOAD)
                tbl[k] = tbl[payload_n]
                tbl[payload_n] = v
                SEL_BUTTON = k
            end
            reaper.ImGui_EndDragDropTarget(ctx)
        end
    end
end

ICON = ''
local letters = {}
for i = 65, 90 do letters[#letters + 1] = string.char(i) end

local function Icon_display(font, icon, button_size)
    local icon = icon == '' and 'a' or icon
    reaper.ImGui_PushFont(ctx, font)
    local rv = reaper.ImGui_Button(ctx, icon, button_size, button_size)
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_SameLine(ctx)
    --reaper.ImGui_Text(ctx, "Icon")
    return rv
end

local function Icon_Selector(font, button_size)
    local ret, icon = false, nil
    reaper.ImGui_SetNextWindowSize(ctx, 265, 310, reaper.ImGui_Cond_Once())
    if reaper.ImGui_BeginPopupModal(ctx, 'Icon Selector', nil) then
        --Buttons
        reaper.ImGui_PushFont(ctx, font)
        local item_spacing_x, item_spacing_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
        item_spacing_x = item_spacing_y
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), item_spacing_y, item_spacing_y)
        local buttons_count = #letters
        local window_visible_x2 = ({ reaper.ImGui_GetWindowPos(ctx) })[1] +
            ({ reaper.ImGui_GetWindowContentRegionMax(ctx) })[1]
        for n = 0, #letters - 1 do
            local letter = letters[n + 1]
            reaper.ImGui_PushID(ctx, n)
            if reaper.ImGui_Button(ctx, letter, button_size, button_size) then
                ret, icon = true, letter
                reaper.ImGui_CloseCurrentPopup(ctx)
            end
            local last_button_x2 = reaper.ImGui_GetItemRectMax(ctx)
            local next_button_x2 = last_button_x2 + item_spacing_x + button_size
            if n + 1 < buttons_count and next_button_x2 < window_visible_x2 then
                reaper.ImGui_SameLine(ctx)
            end
            reaper.ImGui_PopID(ctx)
        end
        reaper.ImGui_PopFont(ctx)

        --Close
        reaper.ImGui_Separator(ctx)
        if reaper.ImGui_Button(ctx, 'Cancel') then
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_PopStyleVar(ctx)
        reaper.ImGui_EndPopup(ctx)
    end
    return ret, icon
end

local function Icon_Frame()
    if Icon_display(awesomefont, ICON, 42) then
        reaper.ImGui_OpenPopup(ctx, 'Icon Selector')
    end

    local rv, icon = Icon_Selector(awesomefont, 42)
    return rv, icon
end

local function GUI()
    flags = 0
    reaper.ImGui_SetNextWindowSize(ctx, 800, 600)
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 800, 600, 800, 600)
    if not hovered_titlebar then flags = flags | reaper.ImGui_WindowFlags_NoMove() end
    local visible, open = reaper.ImGui_Begin(ctx, 'PIE SETUP', true, flags)
    if visible then
        if OLD_BUTTON ~= SEL_BUTTON then
            NAME, ACTION, ICON = SEL_BUTTON and PIES[current_tab][SEL_BUTTON].name or "",
                SEL_BUTTON and PIES[current_tab][SEL_BUTTON].cmd or "",
                SEL_BUTTON and PIES[current_tab][SEL_BUTTON].icon or ""
            OLD_BUTTON = SEL_BUTTON
        end
        hovered_titlebar = reaper.ImGui_IsItemHovered(ctx)
        if reaper.ImGui_BeginTabBar(ctx, 'MyTabBar', reaper.ImGui_TabBarFlags_None()) then
            if reaper.ImGui_BeginTabItem(ctx, 'ARRANGE') then
                if current_tab ~= "arrange" then SEL_BUTTON = nil end
                current_tab = "arrange"
                reaper.ImGui_EndTabItem(ctx)
            end
            if reaper.ImGui_BeginTabItem(ctx, 'TCP') then
                if current_tab ~= "tcp" then SEL_BUTTON = nil end
                current_tab = "tcp"
                reaper.ImGui_EndTabItem(ctx)
            end
            if reaper.ImGui_BeginTabItem(ctx, 'MCP') then
                if current_tab ~= "mcp" then SEL_BUTTON = nil end
                current_tab = "mcp"
                reaper.ImGui_EndTabItem(ctx)
            end
            if reaper.ImGui_BeginTabItem(ctx, 'ENVELOPE') then
                if current_tab ~= "envelope" then SEL_BUTTON = nil end
                current_tab = "envelope"
                reaper.ImGui_EndTabItem(ctx)
            end
            if reaper.ImGui_BeginTabItem(ctx, 'ITEM') then
                if current_tab ~= "item" then SEL_BUTTON = nil end
                current_tab = "item"
                reaper.ImGui_EndTabItem(ctx)
            end
            reaper.ImGui_EndTabBar(ctx)
        end

        if reaper.ImGui_BeginChild(ctx, "LEFT", 300) then
            if reaper.ImGui_Button(ctx, "ADD BUTTON", 90, 20) then
                NAME = "EMPTY" .. #PIES[current_tab]
                PIES[current_tab][#PIES[current_tab] + 1] = { name = NAME, cmd = ACTION, icon = ICON }
                SEL_BUTTON = #PIES[current_tab]
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "REMOVE", 60, 20) then
                if SEL_BUTTON then
                    table.remove(PIES[current_tab], SEL_BUTTON)
                    SEL_BUTTON = nil
                end
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, "ADD MENU BUTTON", 120, 20) then
                NAME = "EMPTY MENU" .. #PIES[current_tab]
                PIES[current_tab][#PIES[current_tab] + 1] = { name = NAME, cmd = {}, icon = ICON }
                SEL_BUTTON = #PIES[current_tab]
                ACTION_NAME = ""
                ACTION_CMD = ""
            end
            if SEL_BUTTON then
                local rv_i, icon = Icon_Frame()
                if rv_i then
                    ICON = icon
                    PIES[current_tab][SEL_BUTTON].icon = ICON
                end
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_BeginGroup(ctx)
                rv_bn, NAME = reaper.ImGui_InputText(ctx, "NAME", NAME)
                if rv_bn then
                    if #NAME == 0 then NAME = '- MISSING NAME -' end
                    PIES[current_tab][SEL_BUTTON].name = NAME
                end
                if type(ACTION) ~= "table" and type(PIES[current_tab][SEL_BUTTON].cmd) ~= "table" then
                    reaper.ImGui_InputText(ctx, "##", PIES[current_tab][SEL_BUTTON].cmd,
                        reaper.ImGui_InputTextFlags_ReadOnly())
                end
                local rv, action = Filter_BOX()
                if rv and SEL_BUTTON then
                    if type(PIES[current_tab][SEL_BUTTON].cmd) ~= "table" then
                        PIES[current_tab][SEL_BUTTON].name = action.name
                        PIES[current_tab][SEL_BUTTON].cmd = action.id
                        NAME = action.name
                    else
                        ACTION_NAME = action.name
                        ACTION_CMD = action.id
                        PIES[current_tab][SEL_BUTTON].cmd[#PIES[current_tab][SEL_BUTTON].cmd + 1] = {
                            name = ACTION_NAME,
                            cmd = ACTION_CMD
                        }
                        SELECTED_LIST_ITEM = #PIES[current_tab][SEL_BUTTON].cmd
                    end
                end
                reaper.ImGui_EndGroup(ctx)
            end
            if type(ACTION) == "table" then
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter()) then
                    if SELECTED_LIST_ITEM and ACTION_NAME ~= "" then
                        PIES[current_tab][SEL_BUTTON].cmd[SELECTED_LIST_ITEM] = {
                            name = ACTION_NAME,
                            cmd = ACTION_CMD,
                            icon = ICON
                        }
                    end
                end
                if SELECTED_LIST_ITEM then
                    reaper.ImGui_SetNextItemWidth(ctx, 250)
                    rv_an, ACTION_NAME = reaper.ImGui_InputText(ctx, "ACTION_NAME", ACTION_NAME)
                    if rv_an then
                        if #ACTION_NAME == 0 then ACTION_NAME = '- MISSING NAME -' end
                        PIES[current_tab][SEL_BUTTON].cmd[SELECTED_LIST_ITEM].name = ACTION_NAME
                    end
                end
                if reaper.ImGui_BeginListBox(ctx, '##Group List', 250, 200) then
                    if reaper.ImGui_IsWindowHovered(ctx) and not reaper.ImGui_IsAnyItemHovered(ctx) and not hovered_titlebar and reaper.ImGui_IsMouseClicked(ctx, 0) then
                        SELECTED_LIST_ITEM = nil
                        ACTION_NAME = ''
                        ACTION_CMD = ''
                    end
                    if SEL_BUTTON then
                        for k, v in ipairs(PIES[current_tab][SEL_BUTTON].cmd) do
                            if reaper.ImGui_Selectable(ctx, v.name, SELECTED_LIST_ITEM == k) then
                                SELECTED_LIST_ITEM = k
                                ACTION_NAME = v.name
                                ACTION_CMD = v.cmd
                            end
                        end
                    end
                    reaper.ImGui_EndListBox(ctx)
                end
                if reaper.ImGui_Button(ctx, "REMOVE FROM LIST", 250, 20) then
                    if SELECTED_LIST_ITEM then
                        table.remove(PIES[current_tab][SEL_BUTTON].cmd, SELECTED_LIST_ITEM)
                        SELECTED_LIST_ITEM = nil
                        ACTION_NAME = ""
                        ACTION_CMD = ""
                    end
                end
            end
            reaper.ImGui_EndChild(ctx)
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_BeginChild(ctx, "PIEDRAW") then
            if reaper.ImGui_IsWindowHovered(ctx) and not reaper.ImGui_IsAnyItemHovered(ctx) and not hovered_titlebar and reaper.ImGui_IsMouseClicked(ctx, 0) then
                SEL_BUTTON = nil
                SELECTED_LIST_ITEM = nil
            end
            DrawPie(PIES[current_tab])
            reaper.ImGui_EndChild(ctx)
        end
        reaper.ImGui_End(ctx)
    end
    if open then
        reaper.defer(GUI)
    else
        Store_Pie_To_TXT()
        reaper.ImGui_DestroyContext(ctx)
    end
end

function Store_Pie_To_TXT()
    local pies = TableToString(PIES)
    Save_to_file(pies, fn)
end

reaper.defer(GUI())
