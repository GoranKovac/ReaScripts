-- @description Sexan PieMenu 3000
-- @author Sexan
-- @license GPL v3
-- @version 0.1.41
-- @changelog
--  fix crash when randomly trying to open/close script a million times a second
-- @provides
--   [main] Sexan_Pie3000_Setup.lua
--   easing.lua
--   PieUtils.lua
--   fontello1.ttf

local r = reaper

local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local pie_file = script_path .. "pie_file.txt"
require('PieUtils')

if CheckDeps() then return end
local easingFunctions = require("easing")

ANIMATION = true
ACTIVATE_ON_CLOSE = true
HOLD_TO_OPEN = true

if r.HasExtState("PIE3000", "SETTINGS") then
    local stored = r.GetExtState("PIE3000", "SETTINGS")
    if stored ~= nil then
        local save_data = StringToTable(stored)
        if save_data ~= nil then
            ANIMATION = save_data.animation
            ACTIVATE_ON_CLOSE = save_data.activate_on_close
            HOLD_TO_OPEN = save_data.hold_to_open
        end
    end
end

local PIE_LIST = {}

local KEYS = {}
for name, func in pairs(r) do
    name = name:match('^ImGui_Key_(.+)$')
    if name then KEYS[#KEYS+1] = {name = name , func = func} end
end
table.sort(KEYS, function(a,b) return a.name < b.name end)

local pi, max, min, floor, cos, sin, atan, ceil, abs = math.pi, math.max, math.min, math.floor, math.cos, math.sin,
    math.atan, math.ceil, math.abs

local START_ANG = (3 * pi) / 2

local function Release()
    if not KEY then return end
    r.JS_VKeys_Intercept(KEY, -1)
    -- r.SNM_SetIntConfigVar("alwaysallowkb", CUR_PREF)
end

local SCRIPT_START_TIME = r.time_precise()
local function KeyHeld() return r.JS_VKeys_GetState(SCRIPT_START_TIME - 1):byte(KEY) == 1 end

local function GetMouseContext()
    local x, y = r.GetMousePosition()
    local track, info = r.GetThingFromPoint(x, y)
    if #info == 0 then return end
    --! TRANSPORT
    if info:match("trans") then return end
    local item, take = r.GetItemFromPoint(x, y, true)
    if info:match("envelope") or info:match("envcp") then info = "envelope" end
    info = info:match('^([^%.]+)')
    if item then info = "item" end

    return info
end
local FLAGS =
    r.ImGui_WindowFlags_NoBackground() |
    r.ImGui_WindowFlags_NoDecoration() |
    r.ImGui_WindowFlags_AlwaysAutoResize() |
    r.ImGui_WindowFlags_NoMove()

local FONT_SIZE = 15
local FONT_LARGE = 16
local ICON_FONT_SMALL_SIZE = 25
local ICON_FONT_LARGE_SIZE = 40
local ICON_FONT_CLICKED_SIZE = 32

local ARC_COLOR = 0x11AAFF88

local function GUI_Init()
    ctx = r.ImGui_CreateContext('Pie 3000', r.ImGui_ConfigFlags_NoSavedSettings())
    draw_list = r.ImGui_GetWindowDrawList(ctx)
    ICON_FONT_SMALL = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_SMALL_SIZE)
    ICON_FONT_LARGE = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_LARGE_SIZE)
    ICON_FONT_CLICKED = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_CLICKED_SIZE)
    SYSTEM_FONT = r.ImGui_CreateFont('sans-serif', FONT_SIZE, r.ImGui_FontFlags_Bold())
    SYSTEM_FONT2 = r.ImGui_CreateFont('sans-serif', FONT_LARGE, r.ImGui_FontFlags_Bold())
    r.ImGui_Attach(ctx, SYSTEM_FONT)
    r.ImGui_Attach(ctx, SYSTEM_FONT2)
    r.ImGui_Attach(ctx, ICON_FONT_SMALL)
    r.ImGui_Attach(ctx, ICON_FONT_LARGE)
    r.ImGui_Attach(ctx, ICON_FONT_CLICKED)
    START_X, START_Y = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
    r.ImGui_SetNextWindowPos(ctx, START_X - 2500, START_Y - 2500)
end

local function Init()
    PIES = ReadFromFile(pie_file)
    if not PIES then
        dofile(script_path .. 'Sexan_Pie3000_Setup.lua')
        return "ERROR"
    end
    CUR_PREF = r.SNM_GetIntConfigVar("alwaysallowkb", 1)
    START_TIME = r.time_precise()
    MOUSE_INFO = GetMouseContext()
    if not MOUSE_INFO then return "ERROR" end
    if #PIES[MOUSE_INFO] == 0 then return "ERROR" end
    --if HOLD_TO_OPEN then
    local key_state = r.JS_VKeys_GetState(START_TIME - 2)
    for i = 1, 255 do
        if key_state:byte(i) ~= 0 then
            r.JS_VKeys_Intercept(i, 1);
            KEY = i
            break
        end
    end
    if not KEY then return "ERROR" end
    --end
    -- r.SNM_SetIntConfigVar("alwaysallowkb", 1)
    GUI_Init()
end

if Init() == "ERROR" then return end

PIE_MENU = PIES[MOUSE_INFO]
PIE_LIST[0] = PIE_MENU

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
            Release()
        end
    end)
end

local function EasingAnim(begin_val, end_val, cur_val, duration_in_sec, ease_function, call_time, delay, open, close)
    begin_val = begin_val or 0
    if close then
        end_val = begin_val
        begin_val = cur_val
        duration_in_sec = duration_in_sec / 1.8
    end
    local time = max(r.time_precise() - call_time, 0.01) - (delay and delay or 0)
    if time <= 0 then return begin_val end
    if not begin_val then return 0 end
    local change = end_val - begin_val
    if time >= duration_in_sec then
        DONE = (CLOSE and close) and true
        return end_val
    end
    local new_val = max(ease_function(time, begin_val, change, duration_in_sec))
    return new_val
end

local function LerpAlpha(col, prog)
    local rr, gg, bb, aa = r.ImGui_ColorConvertU32ToDouble4(col)
    return r.ImGui_ColorConvertDouble4ToU32(rr, gg, bb, aa * prog)
end

local function IncreaseDecreaseBrightness(color, amt, no_alpha)
    local function AdjustBrightness(channel, delta)
        return channel + delta < 255 and channel + delta or 255
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

local function CalculateFontColor(org_color)
    local alpha = org_color & 0xFF
    local blue = (org_color >> 8) & 0xFF
    local green = (org_color >> 16) & 0xFF
    local red = (org_color >> 24) & 0xFF

    local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
    return luminance > 0.5 and 0xFF or 0xFFFFFFFF
end

local function lerpRGBA(color1, color2, t)
    local r1, g1, b1, a1 = r.ImGui_ColorConvertU32ToDouble4(color1)
    local r2, g2, b2, a2 = r.ImGui_ColorConvertU32ToDouble4(color2)
    local color = {};
    local rn = r1 + ((r2 - r1) * t);
    local gn = g1 + ((g2 - g1) * t);
    local bn = b1 + ((b2 - b1) * t);
    local an = a1 + ((a2 - a1) * t);
    return r.ImGui_ColorConvertDouble4ToU32(rn, gn, bn, an);
end

local function AngleInRange(alpha, lower, upper)
    return (alpha - lower + 0.005) % (2 * pi) <= (upper - 0.005 - lower) % (2 * pi)
end

local function StateSpinner(cx, cy, col, radius)
    local item_arc_span = (2 * pi) / 2
    for i = 1, 2 do
        local ang_min = (item_arc_span) * (i - (0.2)) + (r.time_precise() % (pi * 2))
        local ang_max = (item_arc_span) * (i + (0.2)) + (r.time_precise() % (pi * 2))
        r.ImGui_DrawList_PathArcTo(draw_list, cx, cy, radius + 5, ang_min, ang_max)
        r.ImGui_DrawList_PathStroke(draw_list, col, nil, 5)
    end
end

local function AccessibilityMode()
    CTRL = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl())
    local start_ang = (3 * pi) / 2
    if CTRL then
        if not SET then
            r.JS_Mouse_SetPosition(START_X, START_Y - (pie_tbl.RADIUS * 1.8))
            SET = true
            S_ROT_X = START_X
            CUR_DELTA = 0
        else
            local cx = MX
            CUR_DELTA = CUR_DELTA + (cx - S_ROT_X)
            local ang = ((CUR_DELTA) / 100) % (pi * 2)
            if last_ang ~= ang then
                local nx = (START_X + (pie_tbl.RADIUS * 1.8) * cos(ang + start_ang)) // 1
                local ny = (START_Y + (pie_tbl.RADIUS * 1.8) * sin(ang + start_ang)) // 1
                r.JS_Mouse_SetPosition(nx, ny)
                last_ang = ang
                S_ROT_X = nx
            end
        end
    else
        if SET then
            SET = nil
            r.JS_Mouse_SetPosition(START_X, START_Y)
        end
    end
end

local function ExecuteAction(action, name)
    if action then
        if type(action) == "string" then action = r.NamedCommandLookup(action) end
        if CLOSE and ACTIVATE_ON_CLOSE then
            if not triggered then
                r.Main_OnCommand(action, 0)
                triggered = true
            end
        end
        if r.ImGui_IsMouseReleased(ctx, 0) then
            r.Main_OnCommand(action, 0)
        end
    end
end

local function DrawFlyButton(pie, hovered, prog, center, key)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local button_center = { x = xs + (w / 2), y = ys + (h / 2) }

    local name, color = pie.name, pie.col
    color = color == 255 and 0x25283eff or color
    local icon = #pie.icon ~= 0 and pie.icon or nil

    local icon_col = LerpAlpha(0xffffffff, prog)
    local icon_font = hovered and ICON_FONT_LARGE or ICON_FONT_SMALL
    local icon_font_size = hovered and ICON_FONT_LARGE_SIZE or ICON_FONT_SMALL_SIZE

    local button_edge_col = 0x25283eff

    local menu_preview_radius = 7
    local menu_preview_color = 0x25283eff
    local state_spinner_col = 0xff0000ff

    --local button_radius = hovered and 35 or 25
    local col = hovered and IncreaseDecreaseBrightness(color, 30) or color
    local has_key = (pie.key and pie.key ~= 0)
    -- if has_key and r.ImGui_IsKeyDown( ctx, KEYS[pie.key].func() ) then
    --     hovered = true
    -- end

    if hovered then
        if not pie.hover then
            pie.hover_time = r.time_precise()
            pie.hover = true
        end
    else
        if pie.hover then
            pie.hover_time = nil
            pie.hover = nil
        end
    end

    local button_radius = hovered and
        EasingAnim(25, 35, 25, 0.15, easingFunctions.outCubic, pie.hover_time, nil, pie.hover) or 25
    --local button_prog = ANIMATION and max(0, button_radius / (hovered and 35 or 25)) or 1

    if hovered and r.ImGui_IsMouseDown(ctx, 0) then
        button_radius = button_radius - 5
        icon_font = ICON_FONT_CLICKED
        icon_font_size = ICON_FONT_CLICKED_SIZE
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius), 0xffffff77, 128, 14)
        col = IncreaseDecreaseBrightness(col, 20)
    end

    col = LerpAlpha(col, PROG)

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)
    -- BG
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, (button_radius) * PROG,
        LerpAlpha(col, PROG), 123)
    -- EDGE
    r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius - 1) * PROG,
        LerpAlpha(button_edge_col, PROG), 128, 3)

    if (tonumber(pie.cmd) and r.GetToggleCommandState(pie.cmd) == 1) then
        StateSpinner(button_center.x, button_center.y, LerpAlpha(state_spinner_col, PROG), button_radius * PROG)
    end

    -- DRAW MENU ITEMS PREVIEW
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    if pie.menu then
        local item_arc_span = (2 * pi) / #pie
        for i = 1, #pie do
            local cur_angle = (item_arc_span * (i - 1) + START_ANG) % (2 * pi)
            local button_pos = {
                x = button_center.x + ((button_radius - 2) * PROG) * cos(cur_angle),
                y = button_center.y + ((button_radius - 2) * PROG) * sin(cur_angle),
            }
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, menu_preview_radius * PROG,
                LerpAlpha(menu_preview_color, PROG), 0)
        end
    end

    if has_key then
        r.ImGui_DrawList_AddCircleFilled(draw_list, WX + key.kx, WY + key.ky, (button_radius - 12)* PROG,
                LerpAlpha(menu_preview_color, PROG), 0)
                r.ImGui_DrawList_AddCircle(draw_list,WX + key.kx, WY + key.ky, (button_radius - 13)* PROG,
        LerpAlpha(0xffffff55, PROG), 128, 3)
        r.ImGui_PushFont(ctx, SYSTEM_FONT)
        local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, KEYS[pie.key].name:upper())
        r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, WX + key.kx - txt_w / 2, WY + key.ky - txt_h / 2,
        LerpAlpha(0xffffffff,PROG),
            KEYS[pie.key].name:upper())
        r.ImGui_PopFont(ctx)
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)

    if hovered then
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
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * PROG, button_center.x - icon_w / 2,
            button_center.y - icon_h / 2, icon_col, icon)
        r.ImGui_PopFont(ctx)
    end
end

local function StyleFly(pie, center, drag_angle)
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)

    local item_arc_span = ((2 * pi) / #pie)
    local center_x, center_y = center.x, center.y

    pie.cv = ANIMATION and
        EasingAnim(0, pie.RADIUS, pie.cv, 0.3 / (SWITCH_PIE and 1.5 or 1),
            PROG == 1 and easingFunctions.outCubic or easingFunctions.inOutCubic, START_TIME, nil, nil, CLOSE)

    local RADIUS = ANIMATION and pie.cv or pie.RADIUS
    local RADIUS_MIN = RADIUS / 2.2
    local prog = ANIMATION and max(0, pie.cv / pie.RADIUS) or 1

    local main_clicked = (r.ImGui_IsMouseDown(ctx, 0) and not pie.active and #PIE_LIST ~= 0)
    
    if not pie.active then
        if #PIE_LIST ~= 0 then
            r.ImGui_PushFont(ctx, SYSTEM_FONT2)
            local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, PIE_LIST[#PIE_LIST].name)
            r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_LARGE * PROG, WX + center_x - (txt_w / 2) * PROG,
                WY + center_y - (txt_h * 1.8) * PROG, LerpAlpha(0xFFFFFFFF, PROG), PIE_LIST[#PIE_LIST].name)
            r.ImGui_PopFont(ctx)

            r.ImGui_PushFont(ctx, main_clicked and ICON_FONT_CLICKED or ICON_FONT_LARGE)
            local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, utf8.char(143))
            r.ImGui_DrawList_AddTextEx(draw_list, nil,
                main_clicked and ICON_FONT_CLICKED_SIZE or ICON_FONT_LARGE_SIZE * PROG, WX + center_x - txt_w / 2 * PROG,
                WY + center_y - 8 * PROG,
                LerpAlpha(0xFFFFFFFF, PROG), utf8.char(143))
            r.ImGui_PopFont(ctx)
            if r.ImGui_IsMouseReleased(ctx, 0) and not CLOSE then
                SWITCH_PIE = PIE_LIST[#PIE_LIST].pid
                table.remove(PIE_LIST, #PIE_LIST)
                return
            end
        else
            r.ImGui_PushFont(ctx, SYSTEM_FONT2)
            local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, MOUSE_INFO:upper())
            r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_LARGE * prog, WX + center_x - (txt_w / 2) * prog,
                WY + center_y - (txt_h / 2) * prog, LerpAlpha(0xFFFFFFFF, prog), MOUSE_INFO:upper())
            r.ImGui_PopFont(ctx)
        end
    end

    for i = 1, #pie do
        local has_key = pie[i].key and pie[i].key ~= 0

        local ang_min = (item_arc_span) * (i - (0.5)) + START_ANG
        local ang_max = (item_arc_span) * (i + (0.5)) + START_ANG
        local angle = item_arc_span * i

        pie.hovered = AngleInRange(drag_angle, ang_min, ang_max) or (has_key and r.ImGui_IsKeyDown( ctx, KEYS[pie[i].key].func() ))
        pie.selected = (pie.hovered and pie.active) or (has_key and r.ImGui_IsKeyDown( ctx, KEYS[pie[i].key].func() ))

        local button_pos = {
            x = center_x + (RADIUS_MIN + 50) * cos(angle + START_ANG) - 15,
            y = center_y + (RADIUS_MIN + 50) * sin(angle + START_ANG) - 15,
            kx = center_x + (RADIUS_MIN + 50 + (pie.selected and 62 or 43)+ (pie[i].menu and 5 or 0)) * cos(angle + START_ANG),
            ky = center_y + (RADIUS_MIN + 50+ (pie.selected and 62 or 43)+ (pie[i].menu and 5 or 0)) * sin(angle + START_ANG),
        }

        -- local prev_x = (#PIE_LIST ~= 0 and not CLOSE ) and
        -- EasingAnim(PIE_LIST[#PIE_LIST].cx, button_pos.x, 0, 0.15, easingFunctions.outQuart, SWAP_TIME) or button_pos.x
        -- local prev_y = (#PIE_LIST ~= 0 and not CLOSE ) and
        -- EasingAnim(PIE_LIST[#PIE_LIST].cy, button_pos.y, 0, 0.15, easingFunctions.outQuart, SWAP_TIME) or button_pos.y

        r.ImGui_SetCursorPos(ctx, prev_x or button_pos.x, prev_y or button_pos.y)
        r.ImGui_PushID(ctx, i)
        r.ImGui_InvisibleButton(ctx, "##AAA", 30, 30)
        r.ImGui_PopID(ctx)

        if pie.selected then
            r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
            r.ImGui_DrawList_PathArcTo(draw_list, WX + center_x, WY + center_y, (RADIUS - RADIUS_MIN) + 100, ang_min,
                ang_max, 12)
            r.ImGui_DrawList_PathArcTo(draw_list, WX + center_x, WY + center_y, RADIUS_MIN - 1.5, ang_max, ang_min, 12)
            r.ImGui_DrawList_PathFillConvex(draw_list, ARC_COLOR)
        end

        DrawFlyButton(pie[i], pie.selected, prog, center, button_pos)

        if pie.selected then
            ExecuteAction(pie[i].cmd, pie[i].name)
        end

        if pie[i].key and pie[i].key ~= 0 then
            if r.ImGui_IsKeyReleased( ctx, KEYS[pie[i].key].func() ) then
                if pie[i].cmd then
                    r.Main_OnCommand(pie[i].cmd, 0)
                elseif pie[i].menu then
                    table.insert(PIE_LIST, {
                        col = pie[i].col,
                        icon = pie[i].icon,
                        name = pie[i].name,
                        pid = pie,
                        prev_i = i,
                        cx = button_pos.x,
                        cy = button_pos.y,
                    })
                    SWAP_TIME = r.time_precise()
                    SWITCH_PIE = pie[i]
                    r.JS_Mouse_SetPosition(START_X, START_Y)
                    break
                end
               -- r.ShowConsoleMsg(KEYS[pie[i].key].name .."\n")
            end
        end

        if pie.selected and pie[i].menu and not CLOSE then
            if r.ImGui_IsMouseReleased(ctx, 0) then
                if pie[i].guid ~= "MAIN" then
                    table.insert(PIE_LIST, {
                        col = pie[i].col,
                        icon = pie[i].icon,
                        name = pie[i].name,
                        pid = pie,
                        prev_i = i,
                        cx = button_pos.x,
                        cy = button_pos.y,
                    })
                    SWAP_TIME = r.time_precise()
                    SWITCH_PIE = pie[i]
                    r.JS_Mouse_SetPosition(START_X, START_Y)
                    break
                end
            end
        end
    end
end

local function DrawCenter(center)
    local drag_delta = { MX - (WX + center.x), MY - (WY + center.y) }
    local drag_dist = (drag_delta[1] ^ 2) + (drag_delta[2] ^ 2)
    local drag_angle = (atan(drag_delta[2], drag_delta[1])) % (pi * 2)

    local main_color = #PIE_LIST ~= 0 and
        IncreaseDecreaseBrightness(PIE_LIST[#PIE_LIST].col == 255 and 0x25283eFF or PIE_LIST[#PIE_LIST].col, 20) or
        0x25283eFF

    PIE_MENU.cv = ANIMATION and
        EasingAnim(0, PIE_MENU.RADIUS, PIE_MENU.cv, 0.3, easingFunctions.inOutCubic,
            CLOSE and START_TIME or SCRIPT_START_TIME, nil, nil, CLOSE)
    PROG = ANIMATION and max(0, PIE_MENU.cv / PIE_MENU.RADIUS) or 1

    local RADIUS = ANIMATION and PIE_MENU.cv or PIE_MENU.RADIUS
    local RADIUS_MIN = RADIUS / 2.2

    PIE_MENU.active = ((drag_dist >= RADIUS_MIN ^ 2) and PROG > 0.8)

    local main_clicked = (r.ImGui_IsMouseDown(ctx, 0) and not PIE_MENU.active and #PIE_LIST ~= 0)
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)

    r.ImGui_DrawList_AddCircleFilled(draw_list, WX + center.x, WY + center.y, RADIUS_MIN - 10 - (main_clicked and 5 or 0),
        LerpAlpha(main_color, PROG), 64)
    r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, RADIUS_MIN - 10 - (main_clicked and 5 or 0),
        LerpAlpha(0x25283eff, PROG), 0,
        4)

    if main_clicked then
        r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, (RADIUS_MIN - 10), 0xffffff77, 128, 14)
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    if #PIE_LIST ~= 0 then
        local mini_rad = EasingAnim(1, 13, 0, 0.3, easingFunctions.outCubic, START_TIME)
        local prev_pie = PIE_LIST[#PIE_LIST].pid
        local prev_i = PIE_LIST[#PIE_LIST].prev_i
        local item_arc_span = (2 * pi) / #prev_pie
        for i = 1, #prev_pie do
            local cur_angle = (item_arc_span * (i) + START_ANG) % (2 * pi)
            local button_pos = {
                x = WX + center.x + ((RADIUS_MIN - 12 - (main_clicked and 5 or 0)) * PROG) * cos(cur_angle),
                y = WY + center.y + ((RADIUS_MIN - 12 - (main_clicked and 5 or 0)) * PROG) * sin(cur_angle),
            }
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y,
                prev_i == i and mini_rad * PROG or mini_rad * PROG, prev_i == i and 0x23EE9cff or 0x25283eEE, 0)
            if prev_i == i then
                r.ImGui_DrawList_AddCircle(draw_list, button_pos.x, button_pos.y, mini_rad * PROG, 0x25283eEE, 0, 2)
            end
        end
    end
    return drag_angle
end

local function DrawPie(pie, center)
    SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    r.ImGui_DrawListSplitter_Split(SPLITTER, 3)
    local drag_ang = DrawCenter(center)
    if DONE then return end
    StyleFly(pie, center, drag_ang)
    r.ImGui_DrawListSplitter_Merge(SPLITTER)
end
local function CheckKeys()
    ALT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Alt()
    CTRL = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut()
    SHIFT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shift()
    DEL_KEY = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete())
    ESC = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape())
end

local function CloseScript()
    if not CLOSE then
        START_TIME = r.time_precise()
        CLOSE = true
        FLAGS = FLAGS | r.ImGui_WindowFlags_NoInputs()
        DONE = not ANIMATION and true
        if not ANIMATION then DONE = true end
    end
end

local function TrackShortcutKey()
    if HOLD_TO_OPEN then
        if not KeyHeld() then
            CloseScript()
        end
    else
        if not KeyHeld() then
            if not KEY_START_STATE then
                KEY_START_STATE = true
            end
        else
            if KEY_START_STATE then
                if KeyHeld() == KEY_START_STATE then
                    CloseScript()
                end
            end
        end
    end
end

local function Main()
   -- r.ShowConsoleMsg(r.JS_VKeys_GetState(SCRIPT_START_TIME - 2):byte(KEY) .. "\n")
    if r.JS_Window_FindEx(nil, nil, "#32768", "") then DONE = true end -- context menu detected
    TrackShortcutKey()
    if SWITCH_PIE then
        PIE_MENU = SWITCH_PIE
        r.JS_Mouse_SetPosition(START_X, START_Y)
        START_TIME = r.time_precise()
        SWITCH_PIE = nil
        SWAP = nil
    end

    r.ImGui_SetNextWindowSize(ctx, 5000, 5000)
    if r.ImGui_Begin(ctx, 'PIE 3000', false, FLAGS) then
        CheckKeys()
        if ESC then DONE = true end
        WX, WY = r.ImGui_GetWindowPos(ctx)
        MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
        --AccessibilityMode()
        local center = { x = r.ImGui_GetWindowWidth(ctx) / 2, y = r.ImGui_GetWindowHeight(ctx) / 2 }
        if not DONE then DrawPie(PIE_MENU, center) end
        r.ImGui_End(ctx)
    end
    if not DONE then
        pdefer(Main)
    end
    --SCRIPT_START_TIME = r.time_precise()
end

r.atexit(Release)
pdefer(Main)
