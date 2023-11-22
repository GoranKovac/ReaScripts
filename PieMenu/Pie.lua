local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

require('PieUtils')
local easingFunctions = require("easing")

local reaper = reaper
local ctx, awesomefont

local function Key_held() return reaper.JS_VKeys_GetState(START_TIME - 2):byte(KEY) == 1 end

local function Release()
    if not KEY then return end
    reaper.JS_VKeys_Intercept(KEY, -1)
    reaper.SNM_SetIntConfigVar("alwaysallowkb", CUR_PREF)
end

local function Handle_errors(err)
    reaper.ShowConsoleMsg(err .. '\n' .. debug.traceback())
    Release()
end

local function Exec_Action(action)
    if not action or type(action) == "table" then return end
    if type(action) == "string" then action = reaper.NamedCommandLookup(action) end
    reaper.Main_OnCommand(action, 0)
end

local pi, max, floor, cos, sin, atan, ceil = math.pi, math.max, math.floor, math.cos, math.sin, math.atan, math.ceil
local function Easing_Anim(begin_val, end_val, duration_in_sec, ease_function, call_time, delay)
    local time = max(reaper.time_precise() - call_time, 0.01) - (delay and delay or 0)
    if time <= 0 then return begin_val end
    local change = end_val - begin_val
    if time >= duration_in_sec then return end_val end
    local new_val = max(ease_function(time, begin_val, change, duration_in_sec))
    return new_val
end

local function RGBA2NUM(red, green, blue, time, start_time)
    local blue = blue * 256
    local green = green * 256 * 256
    local red = red * 256 * 256 * 256
    local alpha = floor(Easing_Anim(0, 255, time, easingFunctions.inExpo, start_time and start_time or START_TIME))
    return red + green + blue + alpha
end

local function NearestValue(number)
    local table = { 5, 1, 3, 0 }
    local smallestSoFar, smallestIndex
    for i, y in ipairs(table) do
        if not smallestSoFar or (math.abs(number - y) < smallestSoFar) then
            smallestSoFar = math.abs(number - y)
            smallestIndex = i
        end
    end
    return table[smallestIndex]
end

local function GetLongestName(tbl)
    local max_n = 1
    for i = 1, #tbl do
        local w = reaper.ImGui_CalcTextSize(ctx, tbl[i].name)
        if w > max_n then max_n = w end
    end
    return max_n
end

local RADIUS_MIN = 50.0
local RADIUS_INTERACT_MIN = 35
local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

local function PiePopupSelectMenu(tbl, btns)
    local action = nil
    local mx, my = reaper.ImGui_PointConvertNative(ctx, reaper.GetMousePosition())

    local RADIUS_MAX = 40 * #tbl

    local wx, wy = reaper.ImGui_GetWindowPos(ctx)
    local center_x, center_y = wx + reaper.ImGui_GetWindowWidth(ctx) / 2, wy + reaper.ImGui_GetWindowHeight(ctx) / 2

    local drag_delta = { mx - center_x, my - center_y }
    local drag_dist = drag_delta[1] ^ 2 + drag_delta[2] ^ 2

    local item_arc_span = 2 * pi / #tbl
    local drag_angle = atan(drag_delta[2], drag_delta[1])

    if drag_angle < -0.5 * item_arc_span then drag_angle = drag_angle + 2.0 * pi end

    local mouse_ang_min, mouse_ang_max = drag_angle - 0.4, drag_angle + 0.4

    if (drag_dist >= RADIUS_INTERACT_MIN ^ 2) then
        if LAST_HOVER == -1 then HOOVER_TIME2 = reaper.time_precise() end
        local radius = Easing_Anim(0, RADIUS_MIN, 0.25, easingFunctions.outQuad, HOOVER_TIME2)
        reaper.ImGui_DrawList_PathArcTo(draw_list, center_x, center_y, radius, mouse_ang_min, mouse_ang_max)
        reaper.ImGui_DrawList_PathStroke(draw_list, 0x4772B3FF, reaper.ImGui_DrawFlags_None(), 15)
    else
        LAST_HOVER = -1
    end
    RADIUS_ANIM = Easing_Anim(0, RADIUS_MAX, 0.4, easingFunctions.inOutBack, START_TIME)
    RADIUS_ANIM2 = Easing_Anim(0, RADIUS_MIN * 4.2, 0.4, easingFunctions.inOutBack, START_TIME)

    for i = 0, #tbl - 1 do
        local item = i + 1
        local item_label = tbl[item].name
        local item_ang_min = item_arc_span * (i + 0.02) -
            item_arc_span * 0.5 -- FIXME: Could calculate padding angle based on how many pixels they'll take
        local item_ang_max = item_arc_span * (i + 0.98) - item_arc_span * 0.5

        local hovered = false
        if not MENU and drag_dist >= RADIUS_INTERACT_MIN ^ 2 then -- and RADIUS_ANIM == RADIUS_MAX
            if drag_angle >= item_ang_min and drag_angle <= item_ang_max then
                hovered = i
                if LAST_HOVER ~= i then
                    HOVER_TIME = reaper.time_precise()
                    LAST_HOVER = i
                end
            end
        end
        if not btns then
            reaper.ImGui_DrawList_PathArcTo(draw_list, center_x, center_y, RADIUS_ANIM2, item_ang_min, item_ang_max)
            reaper.ImGui_DrawList_PathStroke(draw_list, hovered and 0x4772B3FF or 0x181818FF,
                reaper.ImGui_DrawFlags_None(), 100)
        end

        local text_size = { reaper.ImGui_CalcTextSize(ctx, item_label) }
        local button_pos = {
            center_x + cos((item_ang_min + item_ang_max) * 0.5) * (RADIUS_MIN + RADIUS_ANIM) * 0.5 - text_size[1] * 0.5,
            center_y + sin((item_ang_min + item_ang_max) * 0.5) * (RADIUS_MIN + RADIUS_ANIM) * 0.5 - text_size[2] * 0.5,
        }

        local hover_anim = LAST_HOVER == i and Easing_Anim(5, 10, 0.2, easingFunctions.outQuad, HOVER_TIME) or 0
        if btns then
            local x1, y1 = button_pos[1] - 25, button_pos[2] - 5
            local x2, y2 = button_pos[1] + text_size[1] + 15, button_pos[2] + text_size[2] + 5
            reaper.ImGui_DrawList_AddRectFilled(draw_list, x1 - hover_anim, y1 - hover_anim, x2 + hover_anim,
                y2 + hover_anim, LAST_HOVER == i and 0x4772B3FF or RGBA2NUM(24, 24, 24, 0.2), 5)

            if type(tbl[item].cmd) == "table" then
                if LAST_HOVER == i or MENU == i then
                    local long_label = GetLongestName(tbl[item].cmd) < 60 and 60 or GetLongestName(tbl[item].cmd)
                    local T_B_L_R = {
                        [0] = { x = x2 + 15, y = y1 - 10 },                                            -- R
                        [3] = { x = x1 - long_label - 15, y = y1 - 10 },                               -- L
                        [5] = { x = x1 - 10, y = button_pos[2] - text_size[2] * #tbl[item].cmd - 40 }, -- T
                        [1] = { x = x1 - 10, y = button_pos[2] + 30 },                                 -- B
                    }
                    local closest = NearestValue(floor((item_arc_span * i) + 0.5))
                    reaper.ImGui_SetNextWindowPos(ctx, T_B_L_R[closest].x, T_B_L_R[closest].y)
                    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), RGBA2NUM(71, 114, 179, 0.3, HOVER_TIME)) --0x4772B3FF
                    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 5)
                    if reaper.ImGui_BeginChild(ctx, '##submenu' .. i, long_label + 5, Easing_Anim(0, text_size[2] * #tbl[item].cmd + 25, 0.3, easingFunctions.outQuad, HOVER_TIME), nil, reaper.ImGui_WindowFlags_NoScrollbar()) then
                        MENU = reaper.ImGui_IsWindowHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem()) and
                            i
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),
                            RGBA2NUM(255, 255, 255, 0.3, HOVER_TIME))
                        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SelectableTextAlign(), 0.5, 0)
                        for j = 1, #tbl[item].cmd do
                            reaper.ImGui_Selectable(ctx, tbl[item].cmd[j].name, false)
                            if reaper.ImGui_IsItemHovered(ctx) then action = tbl[item].cmd[j].cmd end
                        end
                        reaper.ImGui_PopStyleVar(ctx)
                        reaper.ImGui_PopStyleColor(ctx)
                        reaper.ImGui_EndChild(ctx)
                    end
                    reaper.ImGui_PopStyleColor(ctx)
                    reaper.ImGui_PopStyleVar(ctx)
                end
            end
        end

        reaper.ImGui_PushFont(ctx, awesomefont)
        reaper.ImGui_DrawList_AddText(draw_list, button_pos[1] - 20, button_pos[2] - 1, RGBA2NUM(255, 255, 255, 0.2),
            tbl[item].icon)
        reaper.ImGui_PopFont(ctx)
        reaper.ImGui_DrawList_AddText(draw_list, button_pos[1], button_pos[2], RGBA2NUM(255, 255, 255, 0.2), item_label)

        if hovered then action = tbl[item].cmd end
    end
    return action
end

local function GetMouseContext()
    local x, y = reaper.GetMousePosition()
    local track, info = reaper.GetThingFromPoint(x, y)
    local item, take = reaper.GetItemFromPoint(x, y, true)
    if info:match("envelope") or info:match("envcp") then info = "envelope" end
    info = info:match('^([^%.]+)')
    if item then info = "item" end
    return info --track, item, env_name
end

local function Main()
    if not Key_held() then
        if CLICKED_ITEM ~= SEL_ITEM then Exec_Action(SEL_ITEM) end
        return
    end
    reaper.ImGui_SetNextWindowSize(ctx, 1000, 1000)
    if reaper.ImGui_Begin(ctx, '##PIE', false, reaper.ImGui_WindowFlags_NoBackground() | reaper.ImGui_WindowFlags_NoDecoration() | reaper.ImGui_WindowFlags_AlwaysAutoResize() | reaper.ImGui_WindowFlags_NoMove()) then
        local pie_menu = PIES[MOUSE_INFO]
        local action = PiePopupSelectMenu(pie_menu, true)
        if action then
            if reaper.ImGui_IsMouseClicked(ctx, 0) then
                CLICKED_ITEM = action
                Exec_Action(CLICKED_ITEM)
            end
            SEL_ITEM = action
        end
        reaper.ImGui_End(ctx)
    end
    reaper.defer(function() xpcall(Main, Handle_errors) end)
end

local function GUI_Init()
    ctx = reaper.ImGui_CreateContext('My script', reaper.ImGui_ConfigFlags_NoSavedSettings())
    awesomefont = reaper.ImGui_CreateFont(script_path .. 'PieICONS.ttf', 16)
    reaper.ImGui_Attach(ctx, awesomefont)
    local wnd_x, wnd_y = reaper.ImGui_PointConvertNative(ctx, reaper.GetMousePosition())
    reaper.ImGui_SetNextWindowPos(ctx, wnd_x - 500, wnd_y - 500)
end

local fn = script_path .. "pie_menus.txt"
local function Init()
    CUR_PREF = reaper.SNM_GetIntConfigVar("alwaysallowkb", 1)
    START_TIME = reaper.time_precise()
    local key_state = reaper.JS_VKeys_GetState(START_TIME - 2)
    for i = 1, 255 do
        if key_state:byte(i) ~= 0 then
            reaper.JS_VKeys_Intercept(i, 1);
            KEY = i
        end
    end
    if not KEY then return end
    MOUSE_INFO = GetMouseContext()
    if not MOUSE_INFO then return end
    local pie_txt = Read_from_file(fn)
    if not pie_txt then
        dofile(script_path .. 'PieSetup.lua')
        return
    end
    PIES = StringToTable(pie_txt)
    reaper.SNM_SetIntConfigVar("alwaysallowkb", 1)
    GUI_Init()
    Main()
end

reaper.atexit(Release)
xpcall(Init, Handle_errors)
