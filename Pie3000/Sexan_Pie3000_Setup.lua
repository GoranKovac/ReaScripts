--@noindex
--NoIndex: true
local r = reaper

local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

SETUP = true
STATE = "PIE"

require('PieUtils')

if CheckDeps() then return end

ctx = r.ImGui_CreateContext('Pie XYZ Setup', r.ImGui_ConfigFlags_NoSavedSettings())
r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)

require('Common')

DeferLoop = DBG and DEBUG.defer or PDefer

PIE_LIST = {}

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
    ["ruler"] = { RADIUS = RADIUS_START, name = "RULLER", guid = r.genGuid() },
}

local context_cur_item = 1
local menu_items = {
    { "arrange",      "ARRANGE" },
    { "arrangeempty", "ARRANGE EMPTY" },
    { "tcp",          "TCP" },
    { "tcpempty",     "TCP EMPTY" },
    { "mcp",          "MCP" },
    { "mcpempty",     "MCP EMPTY" },
    { "envelope",     "ENVELOPE" },
    { "envcp",        "ECP" },
    { "item",         "ITEM" },
    { "trans",        "TRANSPORT" },
    { "ruler",        "RULER" },
}

local PIES = ReadFromFile(pie_file) or Deepcopy(DEFAULT_PIE)

if not PIES["ruler"] then
    PIES["ruler"] = { RADIUS = RADIUS_START, name = "RULLER", guid = r.genGuid() }
end

local MENUS = ReadFromFile(menu_file) or {}

function GetMenus()
    return MENUS
end

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

LinkMenus(MENUS)

local CUR_PIE = PIES["arrange"]
local TEMP_MENU = {
    guid = "TEMP",
    RADIUS = RADIUS_START,
    name = "",
    col = 0xff,
    menu = true
}

local CUR_MENU_PIE = MENUS[1] or TEMP_MENU
LAST_MENU_SEL = MENUS[1] and 1 or nil

local KEYS = { "" }
for name, func in pairs(r) do
    name = name:match('^ImGui_Key_(.+)$')
    if name then KEYS[func()] = name end
end

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
local PNG_TBL_150 = IterateFiles(png_path_150)
local PNG_TBL_200 = IterateFiles(png_path_200)

local function ExportToLuaFile(guid, name)
    local lua_string =
    [=[
local r = reaper
local script_path = r.GetResourcePath() .. "/Scripts/Sexan_Scripts/Pie3000/"
package.path = script_path .. "?.lua;"

require('PieUtils')

local menu_file = script_path .. "menu_file.txt"

local MENUS = ReadFromFile(menu_file) or {}
for i = 1, #MENUS do
    if MENUS[i].guid == "%s" then
        STANDALONE_PIE = MENUS[i]
        break
    end
end
if STANDALONE_PIE then
    require('Sexan_Pie3000')
else
    r.ShowConsoleMsg("Menu does not exist")
end
]=]

    local folder = r.GetResourcePath() .. "/Scripts/"
    local path = folder .. "Pie3000_" .. name:gsub("%s", "_") .. ".lua"
    local file = io.open(path, "w")
    if file then
        file:write(lua_string:format(guid))
        file:close()
        local ret = r.AddRemoveReaScript(true, 0, path, 1)
        if ret then
            ADDED_TO_ACTIONS = true
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

local function MakePieFile()
    local pies = TableToString(PIES)
    local menus = TableToString(MENUS)
    SaveToFile(pies, pie_file)
    SaveToFile(menus, menu_file)
end

local ROUNDING = {
    ["L"] = r.ImGui_DrawFlags_RoundCornersLeft(),
    ["R"] = r.ImGui_DrawFlags_RoundCornersRight(),
    ["A"] = r.ImGui_DrawFlags_RoundCornersAll(),
}

local function GeneralDrawlistButton(name, active, round_side)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local color = active and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_ButtonActive()) or
        r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Button())
    color = r.ImGui_IsItemHovered(ctx) and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_ButtonHovered()) or color
    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye,
        r.ImGui_GetColorEx(ctx, color), ROUNDING[round_side] and 5 or nil, ROUNDING[round_side] or nil)

    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local font_size = r.ImGui_GetFontSize(ctx)

    local txt_x = xs + (w / 2) - (label_size / 2)
    local txt_y = ys + (h / 2) - (font_size / 2)
    r.ImGui_DrawList_AddTextEx(draw_list, nil, font_size, txt_x, txt_y, 0xffffffff, name)
end

local function TabButtons()
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 2)
    if r.ImGui_BeginChild(ctx, "custom_tab", nil, 30) then
        r.ImGui_SetCursorPosX(ctx, 30)
        if r.ImGui_InvisibleButton(ctx, "APPLY", 100, 26) then
            MakePieFile()
        end
        GeneralDrawlistButton("APPLY", nil, "A")
        r.ImGui_SameLine(ctx)

        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), 0, 0)
        r.ImGui_SetCursorPosX(ctx, math.floor(r.ImGui_GetContentRegionAvail(ctx) / 2) - 130)
        if r.ImGui_InvisibleButton(ctx, "Pie", 100, 26) then
            STATE = "PIE"
            UPDATE_FILTER = true
        end
        GeneralDrawlistButton("Pie", (STATE == "PIE"), "L")
        r.ImGui_SameLine(ctx)
        if r.ImGui_InvisibleButton(ctx, "Menu Editor", 100, 26) then
            STATE = "EDITOR"
            UPDATE_FILTER = true
        end
        GeneralDrawlistButton("Menu Editor", STATE == "EDITOR")

        r.ImGui_SameLine(ctx)
        if r.ImGui_InvisibleButton(ctx, "Settings", 100, 26) then
            STATE = "SETTINGS"
        end
        GeneralDrawlistButton("Settings", STATE == "SETTINGS", "R")

        if STATE == "EDITOR" and CUR_MENU_PIE.guid ~= "TEMP" then
            r.ImGui_SameLine(ctx, nil, 100)
            if r.ImGui_InvisibleButton(ctx, "Export to Action", 100, 26) then
                ExportToLuaFile(CUR_MENU_PIE.guid, CUR_MENU_PIE.name)
            end
            GeneralDrawlistButton("Export to Action", SETTINGS ~= nil, "A")
        end

        r.ImGui_PopStyleVar(ctx)
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_Separator(ctx)
end

function ModalWarning(is_menu)
    local rv
    r.ImGui_SetNextWindowPos(ctx, vp_center[1], vp_center[2], nil, 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'WARNING', nil, r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_NoMove()) then
        if is_menu then
            r.ImGui_Text(ctx, "This will DELETE Menu from all used Contexts/Submenus.\n\t\t\t\tAre you sure?")
        else
            r.ImGui_Text(ctx, "This will Clear/Delete whole context\nAre you sure?")
        end
        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'OK', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            rv = true
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'CANCEL', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
            r.ImGui_CloseCurrentPopup(ctx)
            if is_menu then
                CLEAR_MENU_PIE = nil
                CLEAR_MENU_PIE_ID = nil
            else
                CLEAR_PIE = nil
            end
        end
        r.ImGui_EndPopup(ctx)
    end
    return rv
end

function DeleteMenu(tbl, guid)
    for i = #tbl, 1, -1 do
        if tbl[i].menu then
            if tbl[i].guid == guid then
                tbl.selected = nil
                table.remove(tbl, i)
            end
        end
        if type(tbl[i]) == "table" then
            DeleteMenu(tbl[i], guid)
        end
    end
end

local function DeleteMenuFromPie(guid, tbl)
    for _, v in pairs(tbl) do
        if type(v) == "table" then
            DeleteMenu(v, guid)
        end
    end
    if #PIE_LIST ~= 0 then
        for i = #PIE_LIST, 1, -1 do
            if PIE_LIST[i][1].guid == guid then
                table.remove(PIE_LIST, i)
            end
        end
    end
    if #PIE_LIST ~= 0 then
        CUR_PIE = PIE_LIST[#PIE_LIST][1]
    else
        CUR_PIE = PIES[menu_items[context_cur_item][1]]
    end
end

local function Popups()
    -- if MENU_CONTEXT then
    --     MENU_CONTEXT = nil
    --     r.ImGui_OpenPopup(ctx, "MENU CONTEXT")
    -- end

    if OPEN_WARNING then
        OPEN_WARNING = nil
        r.ImGui_OpenPopup(ctx, "WARNING")
    end

    if ADDED_TO_ACTIONS then
        r.ImGui_OpenPopup(ctx, "ADDED TO ACTIONS")
        ADDED_TO_ACTIONS = nil
    end
    r.ImGui_SetNextWindowPos(ctx, vp_center[1], vp_center[2], nil, 0.5, 0.5)
    if r.ImGui_BeginPopup(ctx, "ADDED TO ACTIONS") then
        r.ImGui_Text(ctx, "\n\t\tADDED " .. "Pie3000_" .. CUR_MENU_PIE.name .. " TO ACTION LIST\t\t\n\n")
        r.ImGui_EndPopup(ctx)
    end

    -- if r.ImGui_BeginPopup(ctx, "MENU CONTEXT") then
    --     if r.ImGui_MenuItem( ctx, "USE AS CONTEXT") then
    --         CONTEXT_APPLY_WARNING = true
    --         r.ImGui_OpenPopup(ctx, "CONTEXT APPLY WARNING")
    --     end
    --     r.ImGui_EndPopup(ctx)
    -- end

    if CONTEXT_APPLY_WARNING then
        CONTEXT_APPLY_WARNING = nil
        r.ImGui_OpenPopup(ctx, "CONTEXT APPLY WARNING")
    end
    

    r.ImGui_SetNextWindowPos(ctx, vp_center[1], vp_center[2], nil, 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'CONTEXT APPLY WARNING', nil, r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_NoMove()) then
        r.ImGui_Text(ctx, "This will OVERWRITE ".. PIES[menu_items[context_cur_item][1]].name .. " context"..".\n\t\t\t\tAre you sure?")
       
        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'OK', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            local cur_context = PIES[menu_items[context_cur_item][1]]
            for i = #cur_context, 1, -1 do
                cur_context[i] = nil
            end
            for i = 1, #MENU_CONTEXT_TBL do
                cur_context[i] = Deepcopy(MENU_CONTEXT_TBL[i])
            end
            MENU_CONTEXT_TBL = nil
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'CANCEL', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
            MENU_CONTEXT_TBL = nil
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_EndPopup(ctx)
    end
   

    if CLEAR_PIE or CLEAR_MENU_PIE then
        if ModalWarning(CLEAR_MENU_PIE) then
            if CLEAR_PIE then
                for i = #CLEAR_PIE, 1, -1 do
                    CLEAR_PIE[i] = nil
                end
                CLEAR_PIE = nil
            elseif CLEAR_MENU_PIE then
                local guid = CLEAR_MENU_PIE.guid
                table.remove(MENUS, CLEAR_MENU_PIE_ID)
                DeleteMenuFromPie(guid, PIES)
                DeleteMenuFromPie(guid, MENUS)
                if MENUS[CLEAR_MENU_PIE_ID] then
                    CUR_MENU_PIE = MENUS[CLEAR_MENU_PIE_ID]
                    LAST_MENU_SEL = CLEAR_MENU_PIE_ID
                else
                    CUR_MENU_PIE = MENUS[#MENUS] or TEMP_MENU
                    LAST_MENU_SEL = #MENUS or nil
                end
                CLEAR_MENU_PIE = nil
                CLEAR_MENU_PIE_ID = nil
                UPDATE_FILTER = true
            end
        end
    end
end

local txt = "PRESS KEY"
local function DetectShortcut(pie)
    r.ImGui_SetNextWindowPos(ctx, vp_center[1], vp_center[2], nil, 0.5, 0.5)
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

local PNG_FILTER = ''
local png_tbl = PNG_TBL
local function PngSelector(pie, button_size)
    local ret, png = false, nil
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x - 3, y + 5)
    r.ImGui_SetNextWindowSize(ctx, 500, 400)
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), bg_col)
    if r.ImGui_BeginPopup(ctx, "Png Selector") then
        r.ImGui_BeginGroup(ctx)
        r.ImGui_Text(ctx, "PNG Size")
        r.ImGui_SameLine(ctx)
        if r.ImGui_Checkbox(ctx, "100", png_tbl == PNG_TBL) then
            RefreshImgObj(PNG_TBL)
            png_tbl = PNG_TBL
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Checkbox(ctx, "150", png_tbl == PNG_TBL_150) then
            RefreshImgObj(PNG_TBL_150)
            png_tbl = PNG_TBL_150
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Checkbox(ctx, "200", png_tbl == PNG_TBL_200) then
            RefreshImgObj(PNG_TBL_200)
            png_tbl = PNG_TBL_200
        end
        r.ImGui_EndGroup(ctx)

        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
        rv_f, PNG_FILTER = r.ImGui_InputTextWithHint(ctx, "##input2", "Search PNG", PNG_FILTER)
        FILTERED_PNG = FilterActions(png_tbl, PNG_FILTER)
        local item_spacing_x, item_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
        item_spacing_x = item_spacing_y
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), item_spacing_y, item_spacing_y)
        local buttons_count = #FILTERED_PNG
        local window_visible_x2 = ({ r.ImGui_GetWindowPos(ctx) })[1] +
            ({ r.ImGui_GetWindowContentRegionMax(ctx) })[1]
        if r.ImGui_BeginChild(ctx, "filtered_pngs_list", 0, 0) then
            for n = 0, #FILTERED_PNG - 1 do
                local image = FILTERED_PNG[n + 1].name
                r.ImGui_PushID(ctx, n)
                if not r.ImGui_ValidatePtr(FILTERED_PNG[n + 1].img_obj, 'ImGui_Image*') then
                    FILTERED_PNG[n + 1].img_obj = r.ImGui_CreateImage(image)
                end
                local uv = ImageUVOffset(FILTERED_PNG[n + 1].img_obj, 3, 1, 0, 0, 0, 1, true)
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
    r.ImGui_PopStyleColor(ctx)
    return ret, png
end

local function PngDisplay(tbl, img_obj, button_size)
    local rv
    r.ImGui_PushID(ctx, "PNG")

    if img_obj then
        if not r.ImGui_ValidatePtr(img_obj, 'ImGui_Image*') then
            img_obj = r.ImGui_CreateImage(tbl.png)
        end
        local uv = ImageUVOffset(img_obj, 3, 1, 0, 0, 0, 1, true)
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

ICON = ''
local letters = {}
for i = 33, 254 do letters[#letters + 1] = utf8.char(i) end

local function IconSelector(font, button_size)
    local ret, icon = false, nil
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x - 3, y + 5)
    r.ImGui_SetNextWindowSize(ctx, 500, 470)
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), bg_col)
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
    r.ImGui_PopStyleColor(ctx)
    return ret, icon
end

local function IconDisplay(font, tbl, icon, button_size)
    r.ImGui_PushFont(ctx, icon and font or GUI_FONT)
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

local function NewProperties(pie)
    if STATE == "SETTINGS" then return end
    if r.ImGui_BeginChild(ctx, "PROPERTIES", 0, 140, true) then
        if pie.selected then
            LAST_MSG = pie[pie.selected].name
            r.ImGui_Text(ctx, pie[pie.selected].menu and pie[pie.selected].name or pie[pie.selected].cmd_name)
            r.ImGui_Separator(ctx)
            r.ImGui_BeginGroup(ctx)
            r.ImGui_PushID(ctx, "col_remove")
            if r.ImGui_Button(ctx, "X", 0, 50) then pie[pie.selected].col = 0xff end
            r.ImGui_PopID(ctx)
            r.ImGui_SameLine(ctx)
            if r.ImGui_ColorButton(ctx, "Button Color", pie[pie.selected].col, nil, 50, 50) then
                r.ImGui_OpenPopup(ctx, "ColorPickerXYZ")
            end
            r.ImGui_EndGroup(ctx)
            r.ImGui_SameLine(ctx)
            r.ImGui_SetNextWindowPos(ctx, r.ImGui_GetCursorScreenPos(ctx))
            if r.ImGui_BeginPopupContextItem(ctx, "ColorPickerXYZ", r.ImGui_ButtonFlags_MouseButtonLeft()) then
                rv, pie[pie.selected].col = r.ImGui_ColorPicker4(ctx, '##MyColor##5', pie[pie.selected].col,
                    r.ImGui_ColorEditFlags_PickerHueBar() | r.ImGui_ColorEditFlags_NoSidePreview() |
                    r.ImGui_ColorEditFlags_NoInputs())
                r.ImGui_EndPopup(ctx)
            end
            r.ImGui_SameLine(ctx)
            r.ImGui_BeginGroup(ctx)

            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), bg_col)
            r.ImGui_SetCursorPosX(ctx, 120)
            local rv_i, icon = IconFrame(pie, 50)
            if rv_i then
                pie[pie.selected].icon = icon
                if pie[pie.selected].png then
                    pie[pie.selected].png = nil
                    pie[pie.selected].img_obj = nil
                end
            end
            r.ImGui_SameLine(ctx)
            local rv_png, png = PngFrame(pie, 50)
            if rv_png then
                pie[pie.selected].png = png
                if pie[pie.selected].icon then
                    pie[pie.selected].icon = nil
                end
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "CLEAR", 50, 50) then
                pie[pie.selected].png = nil
                pie[pie.selected].img_obj = nil
                pie[pie.selected].icon = nil
            end
            r.ImGui_PopStyleColor(ctx)
            r.ImGui_EndGroup(ctx)
            -- ICON / PNG
            r.ImGui_PushID(ctx, "txt_remove")
            r.ImGui_Separator(ctx)
            if r.ImGui_Button(ctx, "X") then pie[pie.selected].name = "" end
            r.ImGui_PopID(ctx)

            r.ImGui_SameLine(ctx)
            --RV_COL, pie[pie.selected].col = r.ImGui_ColorEdit4(ctx, 'MyColor##3', pie[pie.selected].col,
            --    r.ImGui_ColorEditFlags_NoInputs() | r.ImGui_ColorEditFlags_NoLabel())
            --r.ImGui_SameLine(ctx)
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
            DetectShortcut(pie)
        else
            LAST_MSG = pie.name
            r.ImGui_Text(ctx, "Radius")
            r.ImGui_SameLine(ctx)
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            RV_R, pie.RADIUS = r.ImGui_SliderInt(ctx, "##RADIUS", pie.RADIUS, 50, 270)
            if STATE == "PIE" then
                if #PIE_LIST == 0 then
                    if pie.name == "ARRANGE" or pie.name == "TCP" or pie.name == "MCP" then
                        if r.ImGui_Checkbox(ctx, "USE AS EMPTY CONTEXT", pie.sync) then
                            pie.sync = not pie.sync
                        end
                    end
                    if r.ImGui_Button(ctx, "Clear Context") then
                        OPEN_WARNING = true
                        CLEAR_PIE = pie
                    end
                    r.ImGui_SameLine(ctx)
                    if r.ImGui_Button(ctx, "Create Menu from Context") then
                        MENUS[#MENUS + 1] = {
                            guid = r.genGuid(),
                            RADIUS = 150,
                            name = CUR_PIE.name .. " CONTEXT MENU",
                            col = 0xff,
                            menu = true,
                            guid_list = {}
                        }
                        for i = 1, #CUR_PIE do
                            MENUS[#MENUS][i] = Deepcopy(CUR_PIE[i])
                        end
                    end
                else
                    -- r.ImGui_SameLine(ctx)
                    -- if r.ImGui_Button(ctx, "Show in Editor") then
                    --     for i = 1, #MENUS do
                    --         if MENUS[i].guid == pie.guid then
                    --             LAST_MENU_SEL = i
                    --             CUR_MENU_PIE = MENUS[i]
                    --             FOCUS_MENU = true
                    --         end
                    --     end
                    --     STATE = "EDITOR"
                    --     UPDATE_FILTER = true
                    -- end
                end
            else
                if pie and pie.guid ~= "TEMP" then
                    r.ImGui_Text(ctx, "Name  ")
                    r.ImGui_SameLine(ctx)
                    r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
                    rv_i, pie.name = r.ImGui_InputTextWithHint(ctx, "##ButtonName", "Button name", pie.name)
                    if r.ImGui_Button(ctx, "Delete Menu") and LAST_MENU_SEL then
                        OPEN_WARNING = true
                        CLEAR_MENU_PIE = pie
                        CLEAR_MENU_PIE_ID = LAST_MENU_SEL
                    end
                end
            end
        end
        r.ImGui_EndChild(ctx)
    end
end

local function Settings()
    if STATE ~= "SETTINGS" then return end
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
    if r.ImGui_Checkbox(ctx, "Limit mouse movement to radius", LIMIT_MOUSE) then
        LIMIT_MOUSE = not LIMIT_MOUSE
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "Re-Center mouse position on menu open", RESET_POSITION) then
        RESET_POSITION = not RESET_POSITION
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "Revert mouse position to starting position on close", REVERT_TO_START) then
        REVERT_TO_START = not REVERT_TO_START
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "Re-Adjust Pie position near edges of screen", ADJUST_PIE_NEAR_EDGE) then
        ADJUST_PIE_NEAR_EDGE = not ADJUST_PIE_NEAR_EDGE
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "Show shortcut buttons", SHOW_SHORTCUT) then
        SHOW_SHORTCUT = not SHOW_SHORTCUT
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "Select thing under mouse", SELECT_THING_UNDER_MOUSE) then
        SELECT_THING_UNDER_MOUSE = not SELECT_THING_UNDER_MOUSE
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "SWIPE (Menus only)", SWIPE) then
        SWIPE = not SWIPE
        WANT_SAVE = true
    end
    if SWIPE then
        RV_SW, SWIPE_TRESHOLD = r.ImGui_SliderInt(ctx, "Threshold in Pixel (Move speed)", SWIPE_TRESHOLD, 20, 100)
        RV_SWC, SWIPE_CONFIRM = r.ImGui_SliderInt(ctx, "Confirm Delay MS", SWIPE_CONFIRM, 20, 150)
        if RV_SW or RV_SWC then
            WANT_SAVE = true
        end
    end

    if WANT_SAVE then
        local data = TableToString(
            {
                animation = ANIMATION,
                hold_to_open = HOLD_TO_OPEN,
                activate_on_close = ACTIVATE_ON_CLOSE,
                limit_mouse = LIMIT_MOUSE,
                reset_position = RESET_POSITION,
                revert_to_start = REVERT_TO_START,
                swipe = SWIPE,
                swipe_treshold = SWIPE_TRESHOLD,
                swipe_confirm = SWIPE_CONFIRM,
                show_shortcut = SHOW_SHORTCUT,
                select_thing_under_mouse = SELECT_THING_UNDER_MOUSE,
                adjust_pie_near_edge = ADJUST_PIE_NEAR_EDGE,

            }, true)
        r.SetExtState("PIE3000", "SETTINGS", data, true)
        WANT_SAVE = nil
    end
end

local function ContextSelector()
    local w, h = r.ImGui_GetItemRectSize(ctx)
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x, y)
    r.ImGui_SetNextWindowSize(ctx, w, 220)
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), bg_col)
    if r.ImGui_BeginPopup(ctx, "Context Selector") then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), bg_col)
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), 0, 0)
        for i = 1, #menu_items do
            if r.ImGui_Button(ctx, menu_items[i][2], -FLT_MIN) then
                SWITCH_PIE = PIES[menu_items[i][1]]
                PIE_LIST = {}
                context_cur_item = i
                r.ImGui_CloseCurrentPopup(ctx)
            end
        end
        r.ImGui_PopStyleVar(ctx)
        r.ImGui_PopStyleColor(ctx)
        r.ImGui_EndPopup(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
end

local function CustomDropDown()
    if r.ImGui_Button(ctx, menu_items[context_cur_item][2], -FLT_MIN) then
        r.ImGui_OpenPopup(ctx, 'Context Selector')
    end
    ContextSelector()
end

local function BreadCrumbs(tbl)
    if not r.ImGui_ValidatePtr(SPLITTER_BC, 'ImGui_DrawListSplitter*') then
        SPLITTER_BC = r.ImGui_CreateDrawListSplitter(draw_list)
    end
    r.ImGui_DrawListSplitter_Split(SPLITTER_BC, 20)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), 0, 0)

    for j = 0, #tbl do
        local color = j == #tbl and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_ButtonActive()) or
            r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Button())
        color = j == 0 and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Button()) or color

        local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, j == 0 and "H" or PIE_LIST[j].name)
        r.ImGui_PushID(ctx, "btn_bx" .. j)
        if r.ImGui_InvisibleButton(ctx, "##BC", txt_w + (j == 0 and 18 or 30), 20) then
            if j == 0 then
                SWITCH_PIE = PIES[menu_items[context_cur_item][1]]
                CLEAR_PIE_LIST = 0
            else
                CLEAR_PIE_LIST = j
                SWITCH_PIE = PIE_LIST[j].pid
            end
        end
        color = r.ImGui_IsItemHovered(ctx) and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_ButtonHovered()) or color
        r.ImGui_PopID(ctx)
        local xs, ys = r.ImGui_GetItemRectMin(ctx)
        local xe, ye = r.ImGui_GetItemRectMax(ctx)
        local w, h = r.ImGui_GetItemRectSize(ctx)

        local off = 4
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER_BC, #tbl - j)
        for i = 1, 0, -1 do
            r.ImGui_DrawList_PathLineTo(draw_list, xs + (off * i), ys)
            r.ImGui_DrawList_PathLineTo(draw_list, xe + (off * i), (ye - h))
            if j < #tbl then
                r.ImGui_DrawList_PathLineTo(draw_list, (xe + 10) + (off * i), (ye - h + h / 2))
            end
            r.ImGui_DrawList_PathLineTo(draw_list, xe + (off * i), ye)
            r.ImGui_DrawList_PathLineTo(draw_list, xe + (off * i), ye)
            r.ImGui_DrawList_PathLineTo(draw_list, xs + (off * i), ys + h)
            r.ImGui_DrawList_PathFillConvex(draw_list, i == 0 and color or bg_col)
        end
        local txt_x = xs + (w / 2) - (txt_w / 2) + (j == 0 and -3 or 5)
        local txt_y = ys + (h / 2) - (txt_h / 2)
        if j == 0 then
            r.ImGui_PushFont(ctx, ICON_FONT_PREVIEW)
        end
        r.ImGui_DrawList_AddTextEx(draw_list, nil, j == 0 and 16 or 14, txt_x, txt_y,
            0xffffffff, j == 0 and "H" or PIE_LIST[j].name)
        if j == 0 then
            r.ImGui_PopFont(ctx)
        end
        r.ImGui_SameLine(ctx)
    end
    r.ImGui_DrawListSplitter_Merge(SPLITTER_BC)
    r.ImGui_PopStyleVar(ctx)
end

function DNDSwapSRC(tbl, k)
    if r.ImGui_BeginDragDropSource(ctx) then
        r.ImGui_SetDragDropPayload(ctx, 'DND_SWAP', tostring(k))
        r.ImGui_Text(ctx, tbl[k].name)
        r.ImGui_EndDragDropSource(ctx)
    end
end

function DNDSwapDST(tbl, k, v)
    if r.ImGui_BeginDragDropTarget(ctx) then
        RV_P, PAYLOAD = r.ImGui_AcceptDragDropPayload(ctx, 'DND_SWAP')
        if RV_P then
            local payload_n = tonumber(PAYLOAD)
            tbl[k] = tbl[payload_n]
            tbl[payload_n] = v
        end
        r.ImGui_EndDragDropTarget(ctx)
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

function DndAddTargetAction(pie, button)
    if pie.guid == "TEMP" then return end
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

function DndAddTargetMenu(pie, button, i)
    if pie.guid == "TEMP" then return end
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

function DndAddAsContext(pie)
    if pie.guid == "TEMP" then return end
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND Menu')
        local menu_id = tonumber(payload)
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            MENU_CONTEXT_TBL = MENUS[menu_id]
            CONTEXT_APPLY_WARNING = true
        end
    end
end

local function HasMenu(tbl)
    local nested = {}
    if not tbl then return nested end
    for j = 1, #tbl do
        if tbl[j].menu then
            for i = 1, #MENUS do
                if MENUS[i] == tbl[j] then
                    nested[tbl[j]] = true
                end
            end
        end
    end
    return nested
end

local FILTERED_EDIT_MENU_TBL = MENUS
local EDITOR_MENU_FILTER = ''

local function MenuEditList(pie)
    if r.ImGui_BeginChild(ctx, "EDITMENULIST", 180, 0, true) then
        -- if EDITOR_MENU_FILTER ~= PREV_EDITOR_MENU_FILTER then
        --     PREV_EDITOR_MENU_FILTER = EDITOR_MENU_FILTER
        --     UPDATE_FILTER = true
        -- end
        if r.ImGui_Button(ctx, 'Create New Menu', -FLT_MIN, 0) then
            MENUS[#MENUS + 1] = {
                guid = r.genGuid(),
                RADIUS = 150,
                name = "MENU " .. #MENUS,
                col = 0xff,
                menu = true,
                guid_list = {}
            }
            LAST_MENU_SEL = #MENUS
            SWITCH_PIE = MENUS[#MENUS]
            UPDATE_FILTER = true
        end
        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
        rv_emf, EDITOR_MENU_FILTER = r.ImGui_InputTextWithHint(ctx, "##input2", "Search Menu List", EDITOR_MENU_FILTER)
        if rv_emf or UPDATE_FILTER then
            UPDATE_CNT = UPDATE_FILTER and UPDATE_CNT + 1 or UPDATE_CNT
            FILTERED_EDIT_MENU_TBL = FilterActions(MENUS, EDITOR_MENU_FILTER)
        end
        if not r.ImGui_ValidatePtr(MENU_EDIT_CLIPPER, 'ImGui_ListClipper*') then
            MENU_EDIT_CLIPPER = r.ImGui_CreateListClipper(ctx)
        end
        r.ImGui_ListClipper_Begin(MENU_EDIT_CLIPPER, #FILTERED_EDIT_MENU_TBL)
        while r.ImGui_ListClipper_Step(MENU_EDIT_CLIPPER) do
            local display_start, display_end = r.ImGui_ListClipper_GetDisplayRange(MENU_EDIT_CLIPPER)
            for i = display_start, display_end - 1 do
                local inserted_menus = HasMenu(FILTERED_EDIT_MENU_TBL[LAST_MENU_SEL])
                local CROSS_MENU = pie and HasReference(FILTERED_EDIT_MENU_TBL[i + 1], pie.guid) or nil
                local SAME_MENU = pie == FILTERED_EDIT_MENU_TBL[i + 1]
                r.ImGui_PushID(ctx, i + 1)
                if r.ImGui_Selectable(ctx, (inserted_menus[FILTERED_EDIT_MENU_TBL[i + 1]] and " - " or "") .. FILTERED_EDIT_MENU_TBL[i + 1].name .. (CROSS_MENU and " - HAS REFERENCE" or ""), LAST_MENU_SEL == i + 1) then
                    LAST_MENU_SEL = i + 1
                    SWITCH_PIE = FILTERED_EDIT_MENU_TBL[i + 1]
                end
                r.ImGui_PopID(ctx)
                local xs, ys = r.ImGui_GetItemRectMin(ctx)
                local xe, ye = r.ImGui_GetItemRectMax(ctx)
                -- SELECTED
                if pie and pie.guid == FILTERED_EDIT_MENU_TBL[i + 1].guid then
                    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x22FF2255)
                end
                -- ALREADY HAS REFERENCE
                if CROSS_MENU then
                    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0xFF222255)
                end
                if inserted_menus[FILTERED_EDIT_MENU_TBL[i + 1]] then
                    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x8cbef944)
                end
                if not CROSS_MENU and not SAME_MENU then
                    DndSourceMenu(FILTERED_EDIT_MENU_TBL[i + 1], i + 1)
                end
            end
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_SameLine(ctx)
end

local function Pie()
    if STATE == "SETTINGS" then return end
    r.ImGui_BeginGroup(ctx)
    if STATE == "PIE" then
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 0)
        if r.ImGui_BeginChild(ctx, "##PIEDRAWTOP", -400, 20, true) then
            CustomDropDown()
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_PopStyleVar(ctx)
    end
    if STATE == "EDITOR" then MenuEditList(CUR_MENU_PIE) end
    if r.ImGui_BeginChild(ctx, "##PIEDRAW", -400, 0, true) then
        if STATE == "PIE" then 
            BreadCrumbs(PIE_LIST)
            r.ImGui_SameLine(ctx, 0, 3)
            if r.ImGui_Button(ctx, '+') then
                MENUS[#MENUS + 1] = {
                    guid = r.genGuid(),
                    RADIUS = 150,
                    name = "MENU " .. #MENUS,
                    col = 0xff,
                    menu = true,
                    guid_list = {}
                }
                table.insert(CUR_PIE, MENUS[#MENUS])
                CUR_PIE.selected = #CUR_PIE
                UPDATE_FILTER = true
            end
        end
        local WW, WH = r.ImGui_GetWindowSize(ctx)
        local WX, WY = r.ImGui_GetWindowPos(ctx)
        CENTER = { x = WX + WW / 2, y = WY + WH / 2 }
        DrawPie(STATE == "PIE" and CUR_PIE or CUR_MENU_PIE)
        r.ImGui_EndChild(ctx)
    end
    DndAddTargetAction(STATE == "PIE" and CUR_PIE or CUR_MENU_PIE)
    DndAddTargetMenu(STATE == "PIE" and CUR_PIE or CUR_MENU_PIE)
    r.ImGui_EndGroup(ctx)
end

local function IterateActions(sectionID)
    local i = 0
    return function()
        local retval, name = r.kbd_enumerateActions(sectionID, i)
        if #name ~= 0 then
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

local ACTIONS_TBL = GetActions()
local FILTERED_ACTION_TBL = ACTIONS_TBL
local FILTERED_MENU_TBL = MENUS
local ACTION_FILTER = ''
local MENU_FILTER = ''

local function ActionsTab(pie)
    if r.ImGui_BeginTabBar(ctx, "ACTIONS MENUS TAB") then
        if r.ImGui_BeginTabItem(ctx, "Actions") then
            -- if ACTION_FILTER ~= PREV_ACTION_FILTER then
            --     UPDATE_FILTER = true
            --     PREV_ACTION_FILTER = ACTION_FILTER
            -- end
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            rv_af, ACTION_FILTER = r.ImGui_InputTextWithHint(ctx, "##inputA", "Search Actions", ACTION_FILTER)
            if rv_af or UPDATE_FILTER then
                UPDATE_CNT = UPDATE_FILTER and UPDATE_CNT + 1 or UPDATE_CNT
                FILTERED_ACTION_TBL = FilterActions(ACTIONS_TBL, ACTION_FILTER)
            end
            if r.ImGui_BeginChild(ctx, "##CLIPPER_ACTION", nil, nil, nil, r.ImGui_WindowFlags_AlwaysHorizontalScrollbar()) then
                if not r.ImGui_ValidatePtr(ACTION_CLIPPER, 'ImGui_ListClipper*') then
                    ACTION_CLIPPER = r.ImGui_CreateListClipper(ctx)
                end
                r.ImGui_ListClipper_Begin(ACTION_CLIPPER, #FILTERED_ACTION_TBL) -- We have 1000 elements, evenly spaced
                while r.ImGui_ListClipper_Step(ACTION_CLIPPER) do
                    local display_start, display_end = r.ImGui_ListClipper_GetDisplayRange(ACTION_CLIPPER)
                    for i = display_start, display_end - 1 do
                        if r.ImGui_Selectable(ctx, FILTERED_ACTION_TBL[i + 1].name, LAST_SEL == i + 1) then
                            LAST_SEL = i + 1
                        end
                        DndSourceAction(FILTERED_ACTION_TBL[i + 1])
                    end
                end
                r.ImGui_EndChild(ctx)
            end
            r.ImGui_EndTabItem(ctx)
        end
        if STATE == "PIE" then
            if r.ImGui_BeginTabItem(ctx, "Menus") then
                -- if MENU_FILTER ~= PREV_MENU_FILTER then
                --     PREV_MENU_FILTER = MENU_FILTER
                --     UPDATE_FILTER = true
                -- end
                r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
                rv_mf, MENU_FILTER = r.ImGui_InputTextWithHint(ctx, "##inputM", "Search Menus", MENU_FILTER)
                if rv_mf or UPDATE_FILTER then
                    UPDATE_CNT = UPDATE_FILTER and UPDATE_CNT + 1 or UPDATE_CNT
                    FILTERED_MENU_TBL = FilterActions(MENUS, MENU_FILTER)
                end
                if r.ImGui_BeginChild(ctx, "##CLIPPER_MENUS") then
                    if not r.ImGui_ValidatePtr(MENU_CLIPPER, 'ImGui_ListClipper*') then
                        MENU_CLIPPER = r.ImGui_CreateListClipper(ctx)
                    end
                    r.ImGui_ListClipper_Begin(MENU_CLIPPER, #FILTERED_MENU_TBL)
                    while r.ImGui_ListClipper_Step(MENU_CLIPPER) do
                        local display_start, display_end = r.ImGui_ListClipper_GetDisplayRange(MENU_CLIPPER)
                        for i = display_start, display_end - 1 do
                            local CROSS_MENU = pie and HasReference(FILTERED_MENU_TBL[i + 1], pie.guid) or nil
                            local SAME_MENU = pie == FILTERED_MENU_TBL[i + 1]
                            r.ImGui_PushID(ctx, i)
                            if r.ImGui_Selectable(ctx, FILTERED_MENU_TBL[i + 1].name .. (CROSS_MENU and " - CANNOT ADD HAS REFERENCE" or ""), ((LAST_MENU_SEL == i + 1) or MENU_CONTEXT_TBL == FILTERED_MENU_TBL[i + 1]), r.ImGui_SelectableFlags_AllowDoubleClick()) then
                            end                            
                            r.ImGui_PopID(ctx)

                            -- if not DRAW_PREVIEW then                                
                            --     if r.ImGui_IsItemHovered(ctx,0) then
                            --         DRAW_PREVIEW = FILTERED_MENU_TBL[i + 1]
                            --     end
                            -- end

                            -- if r.ImGui_IsItemHovered(ctx,0) and r.ImGui_IsMouseReleased(ctx,1) then
                            --     MENU_CONTEXT = true
                            --     MENU_CONTEXT_TBL = FILTERED_MENU_TBL[i + 1]
                            -- end
                            local xs, ys = r.ImGui_GetItemRectMin(ctx)
                            local xe, ye = r.ImGui_GetItemRectMax(ctx)
                            -- SELECTED
                            if pie and pie.guid == FILTERED_MENU_TBL[i + 1].guid then
                                r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x22FF2255)
                            end
                            -- ALREADY HAS REFERENCE
                            if CROSS_MENU then
                                r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0xFF222255)
                            end
                            if not CROSS_MENU and not SAME_MENU then
                                DndSourceMenu(FILTERED_MENU_TBL[i + 1], i + 1)
                            end
                        end
                    end
                    r.ImGui_EndChild(ctx)
                end
                r.ImGui_EndTabItem(ctx)
            end
        end
        r.ImGui_EndTabBar(ctx)
    end
end

local function Properties(pie)
    if r.ImGui_BeginChild(ctx, "##PROPERTIES_WND", 0, 0, true) then
        ActionsTab(pie)
        r.ImGui_EndChild(ctx)
    end
end

local function Editor()
    if STATE == "SETTINGS" then return end
    r.ImGui_SameLine(ctx)
    r.ImGui_BeginGroup(ctx)
    r.ImGui_SeparatorText(ctx, "Button Properties")
    NewProperties(STATE == "PIE" and CUR_PIE or CUR_MENU_PIE)
    Properties(CUR_PIE)
    r.ImGui_EndGroup(ctx)
end

local function Delete()
    if REMOVE then
        table.remove(REMOVE.tbl, REMOVE.i)
        REMOVE.tbl.selected = nil
        REMOVE = nil
    end
end

UPDATE_CNT = 0
local function Main()
    if SWITCH_PIE then
        if STATE == "EDITOR" then
            CUR_MENU_PIE = SWITCH_PIE
        elseif STATE == "PIE" then
            CUR_PIE = SWITCH_PIE
        end
        SWITCH_PIE = nil
    end

    if CLEAR_PIE_LIST then
        if CLEAR_PIE_LIST == 0 then
            PIE_LIST = {}
        else
            for i = #PIE_LIST, 1, -1 do
                if i > CLEAR_PIE_LIST then
                    table.remove(PIE_LIST, i)
                end
            end
        end
        CLEAR_PIE_LIST = nil
    end

    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), bg_col)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ScrollbarBg(), bg_col)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 900, 500, FLT_MAX, FLT_MAX)
    local visible, open = r.ImGui_Begin(ctx, 'Pie XYZ 3000 Setup', true)
    if visible then
        draw_list = r.ImGui_GetWindowDrawList(ctx)
        vp_center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
        MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
        CheckKeys()
        r.ImGui_PushFont(ctx, GUI_FONT)
        TabButtons()
        Settings()
        Pie()
        Editor()
        Popups()
        Delete()
        r.ImGui_PopFont(ctx)
        r.ImGui_End(ctx)
    end
    r.ImGui_PopStyleColor(ctx, 2)

    if open then
        DeferLoop(Main)
    else
        MakePieFile()
    end
    if UPDATE_CNT >= 3 then
        UPDATE_FILTER = nil
        UPDATE_CNT = 0
    end
end

DeferLoop(Main)
