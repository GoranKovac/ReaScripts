-- @description Sexan PieMenu 3000
-- @author Sexan
-- @license GPL v3
-- @version 0.22.5
-- @changelog
--  Export Menus to standalone pies
-- @provides
--   [main] Sexan_Pie3000_Setup.lua
--   easing.lua
--   PieUtils.lua
--   fontello1.ttf
--   Roboto-Medium.ttf
--   [main] Sexan_PieCleanFiles.lua

local r = reaper
local osname = r.GetOS()
if osname:find("OSX") or osname:find("macOS") then
    apple = true
end

if DBG then dofile("C:/Users/Gokily/Documents/ReaGit/ReaScripts/Debug/LoadDebug.lua") end

local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local pie_file = script_path .. "pie_file.txt"
require('PieUtils')

if CheckDeps() then return end
local easingFunctions = require("easing")

local ANIMATION = true
local ACTIVATE_ON_CLOSE = true
local HOLD_TO_OPEN = true
local RESET_POSITION = true
local LIMIT_MOUSE = false
local REVERT_TO_START = false
local SWIPE_TRESHOLD = 45
local SWIPE = false
local SWIPE_CONFIRM = 50

local DRAW_CURSOR = true
local DRAW_CIRCLE_CURSOR = false
--local ADJUST_TO_THEME = true

local def_color_dark = 0x414141ff --0x353535ff
local def_out_ring = 0x2a2a2aff
local def_menu_prev = 0x212121ff
local ARC_COLOR = 0x11AAFF88
local def_color = def_color_dark
local def_font_col = 0xd7d9d9ff



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
    def_font_col = 0xbcc8c8ff
end
--if PNG then def_color = 0x202020ff end
if r.HasExtState("PIE3000", "SETTINGS") then
    local stored = r.GetExtState("PIE3000", "SETTINGS")
    if stored ~= nil then
        local save_data = StringToTable(stored)
        if save_data ~= nil then
            ANIMATION = save_data.animation                 -- or ANIMATION
            ACTIVATE_ON_CLOSE = save_data.activate_on_close -- or ACTIVATE_ON_CLOSE
            HOLD_TO_OPEN = save_data.hold_to_open           -- or HOLD_TO_OPEN
            LIMIT_MOUSE = save_data.limit_mouse
            RESET_POSITION = save_data.reset_position
            REVERT_TO_START = save_data.revert_to_start
            SWIPE = save_data.swipe
            SWIPE_TRESHOLD = save_data.swipe_treshold
            SWIPE_CONFIRM = save_data.swipe_confirm

            --ADJUST_TO_THEME = save_data.adjust_to_theme     -- or ADJUST_TO_THEME
            -- def_color_dark = save_data.def_color_dark-- or def_color_dark
            --def_color_light = save_data.def_color_light-- or def_color_light
            --ARC_COLOR = save_data.arc_color -- or ARC_COLOR
            --DEFAULT_COLOR = save_data.default_color-- or DEFAULT_COLOR
        end
    end
end

--local def_color = ADJUST_TO_THEME and CalculateThemeColor(GetThemeBG()) or DEFAULT_COLOR

local PIE_LIST = {}

local KEYS = {}
for name, func in pairs(r) do
    name = name:match('^ImGui_Key_(.+)$')
    if name then KEYS[func()] = name end
    --if name then KEYS[#KEYS + 1] = { name = name, func = func } end
end
--table.sort(KEYS, function(a, b) return a.name < b.name end)

local pi, max, min, floor, cos, sin, atan, ceil, abs = math.pi, math.max, math.min, math.floor, math.cos, math.sin,
    math.atan, math.ceil, math.abs

local START_ANG = (3 * pi) / 2

local function Release()
    if not KEY then return end
    r.JS_VKeys_Intercept(KEY, -1)
    r.SNM_SetIntConfigVar("alwaysallowkb", CUR_PREF)
end

local SCRIPT_START_TIME = r.time_precise()
local function KeyHeld()
    return r.JS_VKeys_GetState(SCRIPT_START_TIME - 1):byte(KEY) == 1
end

local function GetMouseContext()
    local x, y = r.GetMousePosition()
    local track, info = r.GetThingFromPoint(x, y)
    local cur_hwnd = r.JS_Window_FromPoint(x, y)
    local class_name = r.JS_Window_GetClassName(cur_hwnd)

    if info:match("spacer") then return end
    if info:match("master") then return end
    if #info == 0 then --return end
        if not class_name then return end
        if class_name == "REAPERTCPDisplay" then
            info = "tcpempty"
        elseif class_name == "REAPERMCPDisplay" then
            info = "mcpempty"
        elseif class_name == "REAPERTrackListWindow" then
            info = "arrangeempty"
        elseif class_name == "MIDIWindow" then
            info = "midi"
        end
    end
    --if info:match("trans") then return end
    if info:match("envelope") then
        info = "envelope"
    elseif info:match("envcp") then
        info = "envcp"
    end

    info = info:match('^([^%.]+)')
    local item, take = r.GetItemFromPoint(x, y, true)
    if item then info = "item" end

    return info
end
local FLAGS =
    r.ImGui_WindowFlags_NoBackground() |
    r.ImGui_WindowFlags_NoDecoration() |
    r.ImGui_WindowFlags_NoMove()

local FONT_SIZE = 14
local FONT_LARGE = 16
local ICON_FONT_SMALL_SIZE = 25
local ICON_FONT_LARGE_SIZE = 40
local ICON_FONT_CLICKED_SIZE = 32

local screen_left, screen_top, screen_right, screen_bottom = r.my_getViewport(0, 0, 0, 0, 0, 0, 0, 0, true)

if apple then
    screen_bottom, screen_top = screen_top, screen_bottom
end

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
    --r.ImGui_SetNextWindowPos(ctx, START_X - 750, START_Y - 750)
    r.ImGui_SetNextWindowPos(ctx, screen_left + 1, screen_top + 1)
    r.ImGui_SetNextWindowSize(ctx, screen_right - 2, screen_bottom - 2)
end

local function Init()
    PIES = ReadFromFile(pie_file)
    if not PIES then
        dofile(script_path .. 'Sexan_Pie3000_Setup.lua')
        return "ERROR"
    end
    for k, v in pairs(PIES) do
        if v.sync then
            PIES[k .. "empty"] = PIES[k]
        end
    end
    CUR_PREF = r.SNM_GetIntConfigVar("alwaysallowkb", 1)
    START_TIME = r.time_precise()
    if not STANDALONE_PIE then
        MOUSE_INFO = GetMouseContext()
        if not MOUSE_INFO then return "ERROR" end
    end
    local key_state = r.JS_VKeys_GetState(START_TIME - 2)
    for i = 1, 255 do
        if key_state:byte(i) ~= 0 then
            r.JS_VKeys_Intercept(i, 1);
            KEY = i
            break
        end
    end
    if not KEY then return "ERROR" end

    r.SNM_SetIntConfigVar("alwaysallowkb", 1)
    GUI_Init()
end

if Init() == "ERROR" then return end

PIE_MENU = STANDALONE_PIE or PIES[MOUSE_INFO]

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

local function LerpAlpha(col, prog)
    local rr, gg, bb, aa = r.ImGui_ColorConvertU32ToDouble4(col)
    return r.ImGui_ColorConvertDouble4ToU32(rr, gg, bb, aa * prog)
end

local function ImageUVOffset(img_obj, cols, rows, frame, x, y, prog, need_single_frame)
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
        r.ImGui_DrawList_AddImage(draw_list, img_obj, xs, ys, xe, ye, uv_xs, uv_ys, uv_xe, uv_ye,
            LerpAlpha(0xffffffff, prog))
    end
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

function Clamp(x, v_min, v_max)
    return max(min(x, v_max), v_min)
end

local SWIPE_TRIGGERED
local LAST_SW_VAL = 0
local function Swipe()
    if not SWIPE then return end
    local dx, dy = r.ImGui_GetMouseDelta(ctx)
    local swipe_val = abs(dx + dy)

    local swipe_cur_val = Clamp(swipe_val, 0, SWIPE_TRESHOLD)
    local AAA = swipe_cur_val / SWIPE_TRESHOLD
    if swipe_val > SWIPE_TRESHOLD then
        SWIPE_TRIGGERED = r.time_precise()
    end
    if swipe_cur_val ~= 0 and LAST_SW_VAL <= AAA then
        LAST_SW_VAL = AAA
        RELAX_TIME = r.time_precise()
    end

    if RELAX_TIME then
        SWIPE_ANIM = EasingAnim(LAST_SW_VAL, 0, 0, 1, easingFunctions.linear, RELAX_TIME)
        if SWIPE_ANIM == 0 then
            LAST_SW_VAL = 0
            RELAX_TIME = nil
        end
    end

    if SWIPE_TRIGGERED then
        -- r.ShowConsoleMsg(r.time_precise() - SWIPE_TRIGGERED.."\n")
        if r.time_precise() - SWIPE_TRIGGERED > (SWIPE_CONFIRM / 1000) then
            SWIPE_TRIGGERED = nil
            return true
        end
    end
end

local function ExecuteAction(action, name)
    if action then
        if type(action) == "string" then action = r.NamedCommandLookup(action) end
        if CLOSE and ACTIVATE_ON_CLOSE then
            --if not triggered then
            if LAST_TRIGGERED ~= action then
                r.Main_OnCommand(action, 0)
                LAST_TRIGGERED = action
                --triggered = true
            end
        end
        if r.ImGui_IsMouseReleased(ctx, 0) then
            LAST_TRIGGERED = action
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
    color = color == 0xff and def_color or color
    --local icon = #pie.icon ~= 0 and pie.icon or nil
    local icon = pie.icon
    --local png = (pie.png and #pie.png ~= 0 and pie.png) or nil
    local png = pie.png

    if png then
        color = def_color
    end

    local icon_col = LerpAlpha(0xffffffff, prog)
    local icon_font = hovered and ICON_FONT_LARGE or ICON_FONT_SMALL
    local icon_font_size = hovered and ICON_FONT_LARGE_SIZE or ICON_FONT_SMALL_SIZE

    local menu_preview_radius = 8
    local state_spinner_col = 0xff0000ff

    local col = hovered and IncreaseDecreaseBrightness(color, 30) or color
    local has_key = pie.key

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
        EasingAnim(w / 2, (w / 2) + (png and 10 or 15), w / 2, 0.15, easingFunctions.outCubic, pie.hover_time, nil,
            pie.hover) or w / 2


    --button_radius = png and button_radius + 5 or button_radius
    if hovered and r.ImGui_IsMouseDown(ctx, 0) then
        button_radius = button_radius - 5
        icon_font = ICON_FONT_CLICKED
        icon_font_size = ICON_FONT_CLICKED_SIZE
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius + 6), 0xffffff77, 128, 12)
        col = IncreaseDecreaseBrightness(col, 20)
    end

    col = LerpAlpha(col, PROG)

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, hovered and 3 or 1)
    -- SHADOW TEST
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x + 1, button_center.y + 1, (button_radius + 6) * PROG,
        LerpAlpha(0x44, PROG), 128)

    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, (button_radius + 4) * PROG,
        LerpAlpha(def_out_ring, PROG), 128)
    -- BG
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, (button_radius) * PROG,
        LerpAlpha(def_color, PROG), 128)

    if png then
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius - 1.5) * PROG,
            LerpAlpha(pie.col == 0xff and def_color or pie.col, PROG), 128, 2.5)
    end

    -- custom bg
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, (button_radius - 4) * PROG,
        LerpAlpha(col, PROG), 128)

    if (tonumber(pie.cmd) and r.GetToggleCommandState(pie.cmd) == 1) then
        StateSpinner(button_center.x, button_center.y, LerpAlpha(state_spinner_col, PROG), button_radius * PROG)
    end

    -- DRAW MENU ITEMS PREVIEW
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, hovered and 2 or 0)
    if pie.menu then
        local item_arc_span = (2 * pi) / #pie
        for i = 1, #pie do
            local cur_angle = (item_arc_span * (i - 1) + START_ANG) % (2 * pi)
            local button_pos = {
                x = button_center.x + ((button_radius + 2) * PROG) * cos(cur_angle),
                y = button_center.y + ((button_radius + 2) * PROG) * sin(cur_angle),
            }
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, (menu_preview_radius + 1.5) * PROG,
                LerpAlpha(dark_theme and def_out_ring or def_color, PROG), 128)
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, menu_preview_radius * PROG,
                LerpAlpha(def_menu_prev, PROG), 128)
        end
    end

    if has_key then
        r.ImGui_DrawList_AddCircleFilled(draw_list, WX + key.kx, WY + key.ky, (10) * PROG,
            LerpAlpha(def_menu_prev, PROG), 128)
        r.ImGui_DrawList_AddCircle(draw_list, WX + key.kx, WY + key.ky, (10) * PROG,
            LerpAlpha(0xffffff55, PROG), 128, 3)
        r.ImGui_PushFont(ctx, SYSTEM_FONT)
        local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, KEYS[pie.key])
        r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, WX + key.kx - txt_w / 2, WY + key.ky - txt_h / 2,
            LerpAlpha(0xffffffff, PROG),
            KEYS[pie.key])
        r.ImGui_PopFont(ctx)
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, hovered and 3 or 1)

    if hovered then
        LAST_MSG = name
        --LAST_FONT = SYSTEM_FONT
        --LAST_FONT_SIZE = FONT_SIZE
    end

    if icon and not png then
        r.ImGui_PushFont(ctx, icon_font)
        local icon_w, icon_h = r.ImGui_CalcTextSize(ctx, icon)
        local i_x, i_y = button_center.x - icon_w / 2, button_center.y - icon_h / 2
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * PROG, i_x + 2, i_y + 2, 0xaa, icon)
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * PROG, i_x, i_y, icon_col, icon)
        r.ImGui_PopFont(ctx)
    end

    if png then
        if not r.ImGui_ValidatePtr(pie.img_obj, 'ImGui_Image*') then
            pie.img_obj = r.ImGui_CreateImage(png)
        end
        ImageUVOffset(pie.img_obj, 3, 1, hovered and 2 or 0, button_center.x, button_center.y, PROG)
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

    for i = 1, #pie do
        local has_key = pie[i].key
        local button_w, button_h = 50, 50
        local png = pie[i].png
        if png then
            if not r.ImGui_ValidatePtr(pie[i].img_obj, 'ImGui_Image*') then
                pie[i].img_obj = r.ImGui_CreateImage(png)
            end
            local img_data = ImageUVOffset(pie[i].img_obj, 3, 1, 0, 0, 0, 0, true)
            button_w = math.sqrt(2) * img_data[1]
        end

        local ang_min = (item_arc_span) * (i - (0.5)) + START_ANG
        local ang_max = (item_arc_span) * (i + (0.5)) + START_ANG
        local angle = item_arc_span * i

        pie.hovered = AngleInRange(drag_angle, ang_min, ang_max) or (has_key and r.ImGui_IsKeyDown(ctx, pie[i].key))
        pie.selected = (pie.hovered and pie.active) or (has_key and r.ImGui_IsKeyDown(ctx, pie[i].key))

        local button_pos = {
            x = center_x + (RADIUS_MIN + 50 + button_w / 5) * cos(angle + START_ANG) - button_w / 2,
            y = center_y + (RADIUS_MIN + 50 + button_w / 5) * sin(angle + START_ANG) - button_w / 2,
            kx = center_x +
                (RADIUS_MIN + 50 + (button_w / 5) + (button_w / 2) + (pie[i].menu and 5 or 0)) *
                cos(angle + START_ANG + 0.2),
            ky = center_y +
                (RADIUS_MIN + 50 + (button_w / 5) + (button_w / 2) + (pie[i].menu and 5 or 0)) *
                sin(angle + START_ANG + 0.2),
            -- kx = center_x +
            --     (RADIUS_MIN + 50 + button_w/5 + (pie.selected and 65 or 45) + (pie[i].menu and 5 or 0)) * cos(angle + START_ANG),
            -- ky = center_y +
            --     (RADIUS_MIN + 50 + button_w/5 + (pie.selected and 65 or 45) + (pie[i].menu and 5 or 0)) * sin(angle + START_ANG) ,
        }

        r.ImGui_SetCursorScreenPos(ctx, button_pos.x, button_pos.y)
        r.ImGui_PushID(ctx, i)
        r.ImGui_InvisibleButton(ctx, "##AAA", button_w, button_w)
        r.ImGui_PopID(ctx)

        --! REMOVE SPLITTING ARC WHEN IMGUI GETS UPDATE
        local splits = 5
        local off = pie.selected and 0.005 or 0.0009
        local step = (item_arc_span / 1.25)
        local new_max = ang_max - step
        local new_min = ang_min
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
        --local arc_color = ARC_COLOR
        --arc_color = SWIPE_TRIGGERED and 0xff0000AA or arc_color
        --arc_color = pie[i].menu and lerpRGBA(ARC_COLOR, 0xff0000AA, SWIPE_ANIM or 0) or arc_color
        if #pie < 6 then
            for _ = 1, splits do
                if pie.selected then
                    if new_min >= ang_min and new_max <= ang_max + 0.002 then
                        r.ImGui_DrawList_PathArcTo(draw_list, WX + center_x, WY + center_y, RADIUS + 55, new_min,
                            new_max + off, 12)
                        r.ImGui_DrawList_PathArcTo(draw_list, WX + center_x, WY + center_y, RADIUS_MIN + 5,
                            new_max + off,
                            new_min, 12)
                        r.ImGui_DrawList_PathFillConvex(draw_list, ARC_COLOR)
                    end
                end
                new_min = (new_min + step / (splits - 1))
                new_max = (new_max + step / (splits - 1))
            end
        else
            --! REMOVE SPLITTING ARC WHEN IMGUI GETS UPDATE
            if pie.selected then
                --local color = pie[i].menu and lerpRGBA(ARC_COLOR, 0xff000088, SWIPE_ANIM or 0) or ARC_COLOR
                --color = SWIPE_TRIGGERED and 0xff0000AA or color

                --!AAA
                r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
                r.ImGui_DrawList_PathArcTo(draw_list, WX + center_x, WY + center_y, (RADIUS - RADIUS_MIN) + 100, ang_min,
                    ang_max, 12)
                r.ImGui_DrawList_PathArcTo(draw_list, WX + center_x, WY + center_y, RADIUS_MIN + 5, ang_max, ang_min, 12)
                r.ImGui_DrawList_PathFillConvex(draw_list, ARC_COLOR)
            end
        end

        DrawFlyButton(pie[i], pie.selected, prog, center, button_pos)

        if pie.selected then
            LAST_ACTION = { cmd = pie[i].cmd, name = pie[i].name }
            --ExecuteAction(pie[i].cmd, pie[i].name)
        end

        if pie[i].key and pie[i].key ~= 0 then
            if r.ImGui_IsKeyReleased(ctx, pie[i].key) then
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
            end
        end

        if pie.selected and pie[i].menu and not CLOSE then
            if r.ImGui_IsMouseReleased(ctx, 0) or Swipe() then
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
                    -- r.JS_Mouse_SetPosition(START_X, START_Y)
                    break
                end
            end
        elseif pie.selected and not pie[i].menu then
            SWIPE_ANIM = 0
        end
    end
end

local function TextSplitByWidth(text, width, height)
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
    local f_size = r.ImGui_GetFontSize(ctx)

    --r.ImGui_PushClipRect(ctx, xs, ys, xe, ye, false)

    local h_cnt = 0
    for i = 1, #str_tbl do
        if (txt_h * i) < height - 2 then
            h_cnt = h_cnt + 1
        end
    end
    for i = 1, #str_tbl do
        local str_w = r.ImGui_CalcTextSize(ctx, str_tbl[i])
        if (txt_h * i - 1) + f_size < height then
            r.ImGui_SetCursorScreenPos(ctx, xs + bw / 2 - str_w / 2,
                ys + (bh / 2) - (txt_h * (h_cnt - (i - 1))) + (h_cnt * txt_h) / 2)
            r.ImGui_Text(ctx, str_tbl[i])
        end
    end
    -- r.ImGui_PopClipRect(ctx)
end



local function DrawCenter(center)
    local drag_delta = { MX - (WX + center.x), MY - (WY + center.y) }
    local drag_dist = (drag_delta[1] ^ 2) + (drag_delta[2] ^ 2)
    local drag_angle = (atan(drag_delta[2], drag_delta[1])) % (pi * 2)

    local main_color = def_color
    if #PIE_LIST ~= 0 then
        main_color = PIE_LIST[#PIE_LIST].col == 0xff and def_color or PIE_LIST[#PIE_LIST].col
    end

    if PIE_MENU.png then
        main_color = def_color
    end

    PIE_MENU.cv = ANIMATION and
        EasingAnim(0, PIE_MENU.RADIUS, PIE_MENU.cv, 0.3, easingFunctions.inOutCubic,
            CLOSE and START_TIME or SCRIPT_START_TIME, nil, nil, CLOSE)
    PROG = ANIMATION and max(0, PIE_MENU.cv / PIE_MENU.RADIUS) or 1

    local RADIUS = ANIMATION and PIE_MENU.cv or PIE_MENU.RADIUS
    local RADIUS_MIN = RADIUS / 2.2

    local button_wh = (((RADIUS_MIN) / math.sqrt(2)) * 2)


    PIE_MENU.active = ((drag_dist >= RADIUS_MIN ^ 2) and PROG > 0.8)

    if not PIE_MENU.active then LAST_ACTION = nil end

    local main_clicked = (r.ImGui_IsMouseDown(ctx, 0) and not PIE_MENU.active and #PIE_LIST ~= 0)


    if PROG > 0.2 then
        r.ImGui_SetCursorScreenPos(ctx, WX + center.x - (button_wh / 2), WY + center.y - (button_wh / 2))
        r.ImGui_InvisibleButton(ctx, "##CENTER", button_wh < 2 and 2 or button_wh, button_wh < 2 and 2 or button_wh)
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)

    -- SHADOW
    r.ImGui_DrawList_AddCircleFilled(draw_list, WX + center.x + 1, WY + center.y + 1,
        RADIUS_MIN + 2 - (main_clicked and 5 or 0), LerpAlpha(0x44, PROG), 64)

    r.ImGui_DrawList_AddCircleFilled(draw_list, WX + center.x, WY + center.y, RADIUS_MIN - (main_clicked and 5 or 0),
        LerpAlpha(def_out_ring, PROG), 64)

    r.ImGui_DrawList_AddCircleFilled(draw_list, WX + center.x, WY + center.y, RADIUS_MIN - 4 - (main_clicked and 5 or 0),
        LerpAlpha(main_color, PROG), 64)
    if PIE_MENU.png then
        r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, (RADIUS_MIN - 11) * PROG,
            LerpAlpha(PIE_MENU.col == 0xff and def_color or PIE_MENU.col, PROG), 128, 2.5)
    end

    if main_clicked then
        r.ImGui_DrawList_AddCircle(draw_list, WX + center.x, WY + center.y, (RADIUS_MIN - 10), 0xffffff77, 128, 20)
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
                x = WX + center.x + ((RADIUS_MIN - 5 - (main_clicked and 5 or 0)) * PROG) * cos(cur_angle),
                y = WY + center.y + ((RADIUS_MIN - 5 - (main_clicked and 5 or 0)) * PROG) * sin(cur_angle),
            }
            if dark_theme then
                r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, mini_rad + 1.5 * PROG,
                    LerpAlpha(def_out_ring, PROG), 0)
            end
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y,
                prev_i == i and mini_rad * PROG or mini_rad * PROG, prev_i == i and 0x23EE9cff or def_menu_prev, 0)
            if prev_i == i then
                r.ImGui_DrawList_AddCircle(draw_list, button_pos.x, button_pos.y, mini_rad * PROG, 0x25283eEE, 0, 2)
            end
        end
    end


    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 2)
    -- if PIE_MENU.png and #PIE_MENU.png ~= 0 then
    --     if not r.ImGui_ValidatePtr(PIE_MENU.img_obj, 'ImGui_Image*') then
    --         PIE_MENU.img_obj = r.ImGui_CreateImage(PIE_MENU.png)
    --     end
    --     ImageUVOffset(PIE_MENU.img_obj, 3, 1, 0, WX + center.x, WY + center.y + 15, PROG)
    -- end

    if not PIE_MENU.active then
        if #PIE_LIST ~= 0 then
            LAST_MSG = PIE_LIST[#PIE_LIST].name
            --LAST_FONT = SYSTEM_FONT2
            -- LAST_FONT_SIZE = FONT_LARGE
            -- LAST_MSG_Y = 20

            r.ImGui_PushFont(ctx, main_clicked and ICON_FONT_CLICKED or ICON_FONT_LARGE)
            local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, utf8.char(143))
            r.ImGui_DrawList_AddTextEx(draw_list, nil,
                main_clicked and ICON_FONT_CLICKED_SIZE or ICON_FONT_LARGE_SIZE * PROG, WX + center.x - txt_w / 2 * PROG,
                WY + center.y + 12 * PROG,
                LerpAlpha(def_font_col, PROG), utf8.char(143))
            r.ImGui_PopFont(ctx)
            if r.ImGui_IsMouseReleased(ctx, 0) and not CLOSE then
                SWITCH_PIE = PIE_LIST[#PIE_LIST].pid
                table.remove(PIE_LIST, #PIE_LIST)
            end
        else
            LAST_MSG = PIE_MENU.name
            --LAST_FONT = SYSTEM_FONT2
            --LAST_FONT_SIZE = FONT_LARGE
        end
    end
    if LAST_MSG then
        r.ImGui_PushFont(ctx, SYSTEM_FONT)
        if PROG > 0.2 then
            TextSplitByWidth(LAST_MSG, button_wh, button_wh)
        end
        -- local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, LAST_MSG)
        -- r.ImGui_DrawList_AddTextEx(draw_list, nil, LAST_FONT_SIZE * PROG, WX + center.x + 2 - (txt_w / 2) * PROG,
        --     WY + center.y - (LAST_MSG_Y and LAST_MSG_Y or 0) + 2 - (txt_h / 2) * PROG, LerpAlpha(0x33, PROG), LAST_MSG)
        -- r.ImGui_DrawList_AddTextEx(draw_list, nil, LAST_FONT_SIZE * PROG, WX + center.x - (txt_w / 2) * PROG,
        --     WY + center.y - (LAST_MSG_Y and LAST_MSG_Y or 0) - (txt_h / 2) * PROG, LerpAlpha(def_font_col, PROG),
        --     LAST_MSG)
        r.ImGui_PopFont(ctx)
    end
    LAST_MSG, LAST_FONT, LAST_FONT_SIZE, LAST_MSG_Y = nil, nil, nil, nil
    return drag_angle
end

local function DrawPie(pie, center)
    SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    r.ImGui_DrawListSplitter_Split(SPLITTER, 4)
    if not CLOSE and DRAW_CIRCLE_CURSOR then
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 3)
        r.ImGui_DrawList_AddCircle(draw_list, LIMITED_CX, LIMITED_CY, 14, 0xff0000ff, 64, 5)
        r.ImGui_DrawList_AddCircle(draw_list, LIMITED_CX, LIMITED_CY, 10, 0xff, 64, 5)
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    end
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
        -- TERMINATE IMMEDIATLY IF BUTON WAS HELD UNDER 150MS (TAPPED)
        if HOLD_TO_OPEN and (START_TIME - SCRIPT_START_TIME) < 0.2 then
            TERMINATE = true
        end
        -- if not ANIMATION then DONE = true end
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


local function RefreshImgObj(tbl)
    for i = 1, #tbl do
        if tbl[i].png then
            tbl[i].img_obj = nil
        end
    end
end

--r.JS_WindowMessage_Intercept(intercept_window, "WM_SETCURSOR", false)
local function LimitMouseToRadius()
    local MOUSE_RANGE = 200
    -- if not DRAW_CURSOR then
    --     r.JS_Mouse_SetCursor(nil)
    -- end
    -- local mx,my = r.GetMousePosition()
    local drag_delta = { MX - (START_X), MY - (START_Y) }
    local drag_dist = (drag_delta[1] ^ 2) + (drag_delta[2] ^ 2)
    local drag_angle = (atan(drag_delta[2], drag_delta[1])) % (pi * 2)

    if drag_dist > (MOUSE_RANGE ^ 2) then
        MX = (START_X + (MOUSE_RANGE) * cos(drag_angle)) // 1
        MY = (START_Y + (MOUSE_RANGE) * sin(drag_angle)) // 1
        r.JS_Mouse_SetPosition(MX, MY)
    end
    LIMITED_CX, LIMITED_CY = r.ImGui_PointConvertNative(ctx, MX, MY)
end

local function Main()
    TrackShortcutKey()
    if TERMINATE then
        Release()
        return
    end
    if SWITCH_PIE and not DONE then
        PIE_MENU = SWITCH_PIE
        if RESET_POSITION then
            r.JS_Mouse_SetPosition(START_X, START_Y)
        end
        SWIPE_ANIM = 0
        LAST_SW_VAL = 0
        START_TIME = r.time_precise()
        SWITCH_PIE = nil
        SWAP = nil
        RefreshImgObj(PIE_MENU)
    end

    --r.ImGui_SetNextWindowSize(ctx, screen_right, screen_bottom)
    if r.ImGui_Begin(ctx, 'PIE 3000', false, FLAGS) then
        WX, WY = 0, 0 --r.ImGui_GetWindowPos(ctx)
        MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
        if LIMIT_MOUSE then
            LimitMouseToRadius()
        end
        if not DRAW_CURSOR then
            r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_None())
        end
        --local center = { x = r.ImGui_GetWindowWidth(ctx) / 2, y = r.ImGui_GetWindowHeight(ctx) / 2 }
        CheckKeys()
        if ESC then DONE = true end

        --AccessibilityMode()
        local center = { x = START_X, y = START_Y }
        --if not DONE then DrawPie(PIE_MENU, center) end
        DrawPie(PIE_MENU, center)
        r.ImGui_End(ctx)
    end

    if LAST_ACTION then
        ExecuteAction(LAST_ACTION.cmd, LAST_ACTION.name)
    end
    if REVERT_TO_START and CLOSE and not REVERT_MOUSE then
        REVERT_MOUSE = true
        r.JS_Mouse_SetPosition(START_X, START_Y)
    end
    if not DONE then
        if DBG then
            DEBUG.defer(Main)
        else
            pdefer(Main)
        end
    end
end
r.atexit(Release)
if DBG then
    DEBUG.defer(Main)
else
    pdefer(Main)
end
