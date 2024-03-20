--@noindex
--NoIndex: true
local r = reaper

local info = debug.getinfo(1, 'S');
local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. "?.lua;"

if DBG then dofile("C:/Users/Gokily/Documents/ReaGit/ReaScripts/Debug/LoadDebug.lua") end

easingFunctions = require("easing")
dofile(r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.7.6')

local pi, max, min, floor, cos, sin, atan, ceil, abs, sqrt = math.pi, math.max, math.min, math.floor, math.cos, math.sin,
    math.atan, math.ceil, math.abs, math.sqrt

FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

menu_file = script_path .. "menu_file.txt"
pie_file = script_path .. "pie_file.txt"
png_path = r.GetResourcePath() .. "/Data/toolbar_icons/"
png_path_150 = r.GetResourcePath() .. "/Data/toolbar_icons/150/"
png_path_200 = r.GetResourcePath() .. "/Data/toolbar_icons/200/"

ANIMATION = true
ACTIVATE_ON_CLOSE = true
HOLD_TO_OPEN = true
RESET_POSITION = true
LIMIT_MOUSE = false
REVERT_TO_START = false
SWIPE_TRESHOLD = 45
SWIPE = false
SWIPE_CONFIRM = 50
ADJUST_PIE_NEAR_EDGE = true
SHOW_SHORTCUT = true
SELECT_THING_UNDER_MOUSE = false

local def_color_dark = 0x414141ff
local def_out_ring = 0x2a2a2aff
local def_menu_prev = 0x212121ff
local ARC_COLOR = 0x11AAFF88
local def_color = def_color_dark
local def_font_col = 0xd7d9d9ff
local spinner_col = 0xff0000ff
bg_col = 0x1d1f27ff

DEF_COLOR = def_color

local FONT_SIZE = 14
local FONT_LARGE = 16
local ICON_FONT_SMALL_SIZE = 25
local ICON_FONT_LARGE_SIZE = 40
local ICON_FONT_PREVIEW_SIZE = 16
local ICON_FONT_CLICKED_SIZE = 32
local GUI_FONT_SIZE = 14

ICON_FONT_SMALL = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_SMALL_SIZE)
ICON_FONT_LARGE = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_LARGE_SIZE)
ICON_FONT_PREVIEW = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_PREVIEW_SIZE)
ICON_FONT_CLICKED = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_CLICKED_SIZE)
SYSTEM_FONT = r.ImGui_CreateFont('sans-serif', FONT_SIZE, r.ImGui_FontFlags_Bold())
SYSTEM_FONT2 = r.ImGui_CreateFont('sans-serif', FONT_LARGE, r.ImGui_FontFlags_Bold())
GUI_FONT = r.ImGui_CreateFont(script_path .. "Roboto-Medium.ttf", GUI_FONT_SIZE)

r.ImGui_Attach(ctx, GUI_FONT)
r.ImGui_Attach(ctx, SYSTEM_FONT)
r.ImGui_Attach(ctx, SYSTEM_FONT2)
r.ImGui_Attach(ctx, ICON_FONT_SMALL)
r.ImGui_Attach(ctx, ICON_FONT_LARGE)
r.ImGui_Attach(ctx, ICON_FONT_PREVIEW)
r.ImGui_Attach(ctx, ICON_FONT_CLICKED)

local START_ANG = (3 * pi) / 2
MAIN_PROG = 1
CENTER_BTN_PROG = 1
BUTTON_PROG = 1
LAST_MSG = ""

if r.HasExtState("PIE3000", "SETTINGS") then
    local stored = r.GetExtState("PIE3000", "SETTINGS")
    if stored ~= nil then
        local save_data = StringToTable(stored)
        if save_data ~= nil then
            ANIMATION = save_data.animation
            ACTIVATE_ON_CLOSE = save_data.activate_on_close
            HOLD_TO_OPEN = save_data.hold_to_open
            LIMIT_MOUSE = save_data.limit_mouse
            RESET_POSITION = save_data.reset_position
            REVERT_TO_START = save_data.revert_to_start
            SWIPE = save_data.swipe
            SWIPE_TRESHOLD = save_data.swipe_treshold
            SWIPE_CONFIRM = save_data.swipe_confirm
            SHOW_SHORTCUT = save_data.show_shortcut
            SELECT_THING_UNDER_MOUSE = save_data.select_thing_under_mouse
            ADJUST_PIE_NEAR_EDGE = save_data.adjust_pie_near_edge
        end
    end
end

local KEYS = { "" }
for name, func in pairs(r) do
    name = name:match('^ImGui_Key_(.+)$')
    if name then KEYS[func()] = name end
end

function Release()
    if not KEY then return end
    r.JS_VKeys_Intercept(KEY, -1)
    r.SNM_SetIntConfigVar("alwaysallowkb", ALLOW_KB_VAR)
end

function PDefer(func)
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

function EasingAnimation(begin_val, end_val, duration_in_sec, ease_function, call_time, delay)
    local time = max(r.time_precise() - call_time, 0.01) - (delay and delay or 0)
    if time <= 0 then return begin_val end
    local change = end_val - begin_val
    if time >= duration_in_sec then return end_val end
    local new_val = max(ease_function(time, begin_val, change, duration_in_sec))
    return new_val
end

local function IsColorLuminanceHigh(org_color)
    local alpha = org_color & 0xFF
    local blue = (org_color >> 8) & 0xFF
    local green = (org_color >> 16) & 0xFF
    local red = (org_color >> 24) & 0xFF

    local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
    return luminance > 0.5 and true, false
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

local function lerpRGBA(color1, color2, t)
    local r1, g1, b1, a1 = r.ImGui_ColorConvertU32ToDouble4(color1)
    local r2, g2, b2, a2 = r.ImGui_ColorConvertU32ToDouble4(color2)
    local rn = r1 + ((r2 - r1) * t);
    local gn = g1 + ((g2 - g1) * t);
    local bn = b1 + ((b2 - b1) * t);
    local an = a1 + ((a2 - a1) * t);
    return r.ImGui_ColorConvertDouble4ToU32(rn, gn, bn, an);
end

function ImageUVOffset(img_obj, cols, rows, frame, x, y, prog, need_single_frame)
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

local function GetThemeBG()
    return r.GetThemeColor("col_tr1_bg", 0)
end

local theme_luminance_high = IsColorLuminanceHigh(GetThemeBG())

local dark_theme = (theme_luminance_high == false)
if dark_theme or SETUP then
    local def_light = def_color_dark
    def_out_ring = 0x818989ff
    def_menu_prev = def_light
    def_color = def_light
    def_font_col = 0xbcc8c8ff
end

DEF_COLOR = def_color

local function StateSpinner(cx, cy, col, radius)
    local item_arc_span = (2 * pi) / 2
    for i = 1, 2 do
        local ang_min = (item_arc_span) * (i - (0.2)) + (r.time_precise() % (pi * 2))
        local ang_max = (item_arc_span) * (i + (0.2)) + (r.time_precise() % (pi * 2))
        r.ImGui_DrawList_PathArcTo(draw_list, cx, cy, radius + 5, ang_min, ang_max)
        r.ImGui_DrawList_PathStroke(draw_list, col, nil, 5)
    end
end

function Clamp(x, v_min, v_max)
    return max(min(x, v_max), v_min)
end

function Swipe()
    if not SWIPE then return end
    local dx, dy = r.ImGui_GetMouseDelta(ctx)
    local swipe_val = abs(dx) + abs(dy)

    if swipe_val > SWIPE_TRESHOLD then
        SWIPE_TRIGGERED = r.time_precise()
    end

    if SWIPE_TRIGGERED then
        if r.time_precise() - SWIPE_TRIGGERED > (SWIPE_CONFIRM / 1000) then
            SWIPE_TRIGGERED = nil
            return true
        end
    end
end

local function TextSplitByWidth(text, width, height)
    r.ImGui_PushFont(ctx, SYSTEM_FONT)
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

    local h_cnt = 0
    for i = 1, #str_tbl do
        if (txt_h * i) < height - 2 then
            h_cnt = h_cnt + 1
        end
    end
    for i = 1, #str_tbl do
        local str_w = r.ImGui_CalcTextSize(ctx, str_tbl[i])
        if (txt_h * i - 1) + f_size < height then
            r.ImGui_DrawList_AddTextEx( draw_list, nil, FONT_SIZE, xs + bw / 2 - str_w / 2, ys + (bh / 2) - (txt_h * (h_cnt - (i - 1))) + (h_cnt * txt_h) / 2, LerpAlpha(0xffffffff, CENTER_BTN_PROG), str_tbl[i])
           -- r.ImGui_SetCursorScreenPos(ctx, xs + bw / 2 - str_w / 2,
           --     ys + (bh / 2) - (txt_h * (h_cnt - (i - 1))) + (h_cnt * txt_h) / 2)
          --  r.ImGui_Text(ctx, str_tbl[i])
        end
    end
    r.ImGui_PopFont(ctx)
end

local function AngleInRange(alpha, lower, upper)
    return (alpha - lower + 0.005) % (2 * pi) <= (upper - 0.005 - lower) % (2 * pi)
end

function CheckKeys()
    ALT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Alt()
    CTRL = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut()
    SHIFT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shift()
    DEL_KEY = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete())
    ESC = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape())
end

function RefreshImgObj(tbl)
    for i = 1, #tbl do
        if tbl[i].png then
            tbl[i].img_obj = nil
        end
    end
end

function LimitMouseToRadius()
    local MOUSE_RANGE = PIE_MENU.RADIUS * 2

    if DRAG_DIST > (MOUSE_RANGE ^ 2) then
        MX = (START_X + (MOUSE_RANGE) * cos(DRAG_ANGLE)) // 1
        MY = (START_Y + (MOUSE_RANGE) * sin(DRAG_ANGLE)) // 1
        r.JS_Mouse_SetPosition(MX, MY)
    end
end

local function DrawArc(pie, center, item_arc_span, ang_min, ang_max, RADIUS, RADIUS_MIN)
    if SETUP then return end
    local CENTER = center or CENTER
    --! REMOVE SPLITTING ARC WHEN IMGUI GETS UPDATE
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    local splits = 5
    local off = pie.selected and 0.005 or 0.0009
    local step = (item_arc_span / 1.25)
    local new_max = ang_max - step
    local new_min = ang_min
    if #pie < 6 then
        for _ = 1, splits do
            if pie.selected then
                if new_min >= ang_min and new_max <= ang_max + 0.002 then
                    r.ImGui_DrawList_PathArcTo(draw_list, CENTER.x, CENTER.y, RADIUS + 55, new_min,
                        new_max + off, 12)
                    r.ImGui_DrawList_PathArcTo(draw_list, CENTER.x, CENTER.y, RADIUS_MIN,
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
            r.ImGui_DrawList_PathArcTo(draw_list, CENTER.x, CENTER.y, (RADIUS - RADIUS_MIN) + 100, ang_min, ang_max, 12)
            r.ImGui_DrawList_PathArcTo(draw_list, CENTER.x, CENTER.y, RADIUS_MIN, ang_max, ang_min, 12)
            r.ImGui_DrawList_PathFillConvex(draw_list, ARC_COLOR)
        end
    end
end

local function DrawShortcut(pie, button_pos)
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, selected and 3 or 0)
    r.ImGui_PushFont(ctx, GUI_FONT)
    local key_w, key_h = r.ImGui_CalcTextSize( ctx, KEYS[pie.key])
    r.ImGui_SetCursorScreenPos(ctx, button_pos.kx - ((key_w + 15)/2), button_pos.ky)
    r.ImGui_InvisibleButton(ctx, KEYS[pie.key], (key_w + 15), key_h + 2)
    local xs, ys = r.ImGui_GetItemRectMin( ctx )
    local xe, ye = r.ImGui_GetItemRectMax( ctx )
    -- SHADOW
    r.ImGui_DrawList_AddRectFilled( draw_list, xs, ys, xe+4, ye+4, LerpAlpha(0x44, CENTER_BTN_PROG), 7,  r.ImGui_DrawFlags_RoundCornersAll() )            
    -- RING
    r.ImGui_DrawList_AddRectFilled( draw_list, xs-2, ys-2, xe+2, ye+2, LerpAlpha(def_out_ring, CENTER_BTN_PROG), 7,  r.ImGui_DrawFlags_RoundCornersAll() )
    -- MAIN
    r.ImGui_DrawList_AddRectFilled( draw_list, xs, ys, xe, ye, LerpAlpha(def_color, CENTER_BTN_PROG), 5,  r.ImGui_DrawFlags_RoundCornersAll() )
    -- SHADOW
    r.ImGui_DrawList_AddTextEx(draw_list, nil, GUI_FONT_SIZE * CENTER_BTN_PROG, (button_pos.kx - key_w/2)+1, button_pos.ky+1, LerpAlpha(0xFF, CENTER_BTN_PROG), KEYS[pie.key])
    -- MAIN
    r.ImGui_DrawList_AddTextEx(draw_list, nil, GUI_FONT_SIZE * CENTER_BTN_PROG, button_pos.kx - key_w/2, button_pos.ky, LerpAlpha(0xFFFFFFFF, CENTER_BTN_PROG), KEYS[pie.key])            
    r.ImGui_PopFont(ctx)
end 

local function PieButtonDrawlist(pie, button_radius, selected, hovered, button_pos)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local button_center = { x = xs + (w / 2), y = ys + (h / 2) }

    if not SETUP then
        button_radius = selected and button_radius + (15 * BUTTON_PROG) or button_radius
        button_radius = (pie.key and r.ImGui_IsKeyDown(ctx, pie.key)) and button_radius + (15 * 0.8) or button_radius
    else
        button_radius = hovered and button_radius + (5 * BUTTON_PROG) or button_radius
    end

    local menu_preview_radius = 8

    local color, icon, png = pie.col, pie.icon, pie.png
    local ring_col = (hovered and ALT) and 0xff0000ff or def_out_ring
    color = color == 0xff and def_color or color
    
    -- USE DEFAULT BG BUTTON WHEN PNG IS USED
    if png then color = def_color end
    color = hovered and ALT and 0xff0000ff or color

    local icon_col = LerpAlpha(0xffffffff, CENTER_BTN_PROG)
    local icon_font = selected and ICON_FONT_LARGE or ICON_FONT_SMALL
    local icon_font_size = selected and ICON_FONT_LARGE_SIZE or ICON_FONT_SMALL_SIZE

    local col = (selected or hovered) and IncreaseDecreaseBrightness(color, 30) or color
    col = LerpAlpha(col, CENTER_BTN_PROG)

    local click_highlight
    if SETUP then
        click_highlight = hovered
    else
        click_highlight = selected
    end

    if click_highlight and r.ImGui_IsMouseDown(ctx, 0) or (pie.key and r.ImGui_IsKeyDown(ctx, pie.key)) then
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
        button_radius = button_radius - 7
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius + 6), 0xffffff77, 128, 14)
        col = IncreaseDecreaseBrightness(col, 20)
    end

    if SETUP and selected then
        local scale = (sin(r.time_precise() * 5) * 0.05) + 1.02
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius + 10) * scale,
            LerpAlpha(0xffffffaa, (sin(r.time_precise() * 5) * 0.5) + 0.7),
            128, 2.5)
    end
    -- BUTTON CIRCLE -------------------------------------------------
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, selected and 3 or 1)

    -- SHADOW
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x + 1, button_center.y + 1,
        (button_radius + 6) * CENTER_BTN_PROG,
        LerpAlpha(0x44, CENTER_BTN_PROG), 128)

    -- OUTER RING
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, (button_radius + 4) * CENTER_BTN_PROG,
        LerpAlpha(ring_col, CENTER_BTN_PROG), 128)
    -- MAIN
    
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, (button_radius) * CENTER_BTN_PROG,
        LerpAlpha(def_color, CENTER_BTN_PROG), 128)

    if png then
        r.ImGui_DrawList_AddCircle(draw_list, button_center.x, button_center.y, (button_radius - 1.5) * CENTER_BTN_PROG,
            LerpAlpha(pie.col == 0xff and def_color or pie.col, CENTER_BTN_PROG), 128, 2.5)
    end

    -- COLOR BG
    r.ImGui_DrawList_AddCircleFilled(draw_list, button_center.x, button_center.y, (button_radius - 4) * CENTER_BTN_PROG,
        LerpAlpha(col, CENTER_BTN_PROG), 128)
    -- BUTTON CIRCLE -------------------------------------------------

    -- SPINNER FOR ACTION STATE ON/OFF
    if (tonumber(pie.cmd) and r.GetToggleCommandState(pie.cmd) == 1) then
        StateSpinner(button_center.x, button_center.y, LerpAlpha(spinner_col, CENTER_BTN_PROG),
            button_radius * CENTER_BTN_PROG)
    end

    -- MENU PREVIEW CIRCLE -------------------------------------------------
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, selected and 2 or 0)
    if pie.menu then
        local menu_num = #pie == 0 and 12 or #pie
        local item_arc_span = (2 * pi) / menu_num
        for i = 1, menu_num do
            local cur_angle = (item_arc_span * (i - 1) + START_ANG) % (2 * pi)
            local button_pos = {
                x = button_center.x + ((button_radius + 2) * CENTER_BTN_PROG) * cos(cur_angle),
                y = button_center.y + ((button_radius + 2) * CENTER_BTN_PROG) * sin(cur_angle),
            }
            if #pie ~= 0 then
                -- SHADOW
                r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x + 1, button_pos.y + 1,
                    (menu_preview_radius + 3) * CENTER_BTN_PROG,
                    LerpAlpha(0x44, CENTER_BTN_PROG), 128)
                -- OUTER RING
                r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y,
                    (menu_preview_radius + 1.5) * CENTER_BTN_PROG,
                    LerpAlpha(dark_theme and ring_col or def_color, CENTER_BTN_PROG), 128)
                -- MAIN CIRCLE
                r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y,
                    menu_preview_radius * CENTER_BTN_PROG,
                    LerpAlpha(def_menu_prev, CENTER_BTN_PROG), 128)
            else
                -- DRAW EMPTY
                r.ImGui_DrawList_AddCircle(draw_list, button_pos.x, button_pos.y,
                    (menu_preview_radius + 1.5) * CENTER_BTN_PROG,
                    LerpAlpha(dark_theme and ring_col or def_color, CENTER_BTN_PROG), 128, 2)
            end
        end
    end
    -- MENU PREVIEW CIRCLE -------------------------------------------------

    -- KEY CIRCLE   -----------------------------------------------------------
    if SHOW_SHORTCUT then
        if pie.key then
            DrawShortcut(pie, button_pos)
        end
    end
    -- KEY CIRCLE   -----------------------------------------------------------

    -- ICONS AND PNG
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, selected and 3 or 1)

    if icon then
        r.ImGui_PushFont(ctx, icon_font)
        local icon_w, icon_h = r.ImGui_CalcTextSize(ctx, icon)
        local i_x, i_y = button_center.x - icon_w / 2, button_center.y - icon_h / 2
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * CENTER_BTN_PROG, i_x + 2, i_y + 2, 0xaa, icon)
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * CENTER_BTN_PROG, i_x, i_y, icon_col, icon)
        r.ImGui_PopFont(ctx)
    end

    if png and r.file_exists(png) then
        if not r.ImGui_ValidatePtr(pie.img_obj, 'ImGui_Image*') then
            pie.img_obj = r.ImGui_CreateImage(png)
        end
        ImageUVOffset(pie.img_obj, 3, 1, selected and 2 or 0, button_center.x, button_center.y, CENTER_BTN_PROG)
    end
end

local function DrawButtons(pie, center)
    local CENTER = center or CENTER
    local item_arc_span = ((2 * pi) / #pie)

    local RADIUS = pie.RADIUS * CENTER_BTN_PROG
    local RADIUS_MIN = RADIUS / 2.2

    for i = 1, #pie do
        local button_wh = 25
        local png = pie[i].png
        if pie[i].png then
            if not r.ImGui_ValidatePtr(pie[i].img_obj, 'ImGui_Image*') then
                pie[i].img_obj = r.ImGui_CreateImage(png)
            end
            local img_data = ImageUVOffset(pie[i].img_obj, 3, 1, 0, 0, 0, 0, true)
            button_wh = (sqrt(2) * img_data[1]) // 2
        end

        local ang_min = (item_arc_span) * (i - (0.5)) + START_ANG
        local ang_max = (item_arc_span) * (i + (0.5)) + START_ANG
        local angle = item_arc_span * i

        pie.hovered = AngleInRange(DRAG_ANGLE, ang_min, ang_max)
        if not SETUP then
            pie.selected = (pie.hovered and pie.active) and i
            pie.selected = (pie[i].key and r.ImGui_IsKeyDown(ctx, pie[i].key)) and i or pie.selected
        end

        local button_pos = {
            x = CENTER.x + (RADIUS_MIN + ((RADIUS - RADIUS_MIN) / 1.3) * MAIN_PROG) * cos(angle + START_ANG) -
                (button_wh / 2),
            y = CENTER.y + (RADIUS_MIN + ((RADIUS - RADIUS_MIN) / 1.3) * MAIN_PROG) * sin(angle + START_ANG) -
                (button_wh / 2),
            kx = pie[i].key and CENTER.x + (RADIUS_MIN + ((RADIUS - RADIUS_MIN) / 1.3) * MAIN_PROG) * cos(angle + START_ANG),
            ky = pie[i].key and CENTER.y - (button_wh+ (pie[i].menu and 32 or 25))- ((pie.selected == i and (SETUP and 5 or 15) or 0) * BUTTON_PROG) + (RADIUS_MIN + ((RADIUS - RADIUS_MIN) / 1.3) * MAIN_PROG) * sin(angle + START_ANG),
        }


        local boundry_hovered
        if SETUP then
            r.ImGui_SetCursorScreenPos(ctx, button_pos.x - button_wh / 2, button_pos.y - button_wh / 2)
            r.ImGui_PushID(ctx, "btn_boundry" .. i)
            if r.ImGui_InvisibleButton(ctx, i, button_wh * 2, button_wh * 2) then
                if ALT then
                    REMOVE = { tbl = pie, i = i }
                else
                    pie.selected = i
                    LAST_MSG = pie[i].name
                end
            end
            boundry_hovered = r.ImGui_IsItemHovered(ctx)
            r.ImGui_PopID(ctx)
            if not pie[i].menu then
                DndAddTargetAction(pie, pie[i])
            else
                if boundry_hovered and r.ImGui_IsMouseDoubleClicked(ctx, 0) and not ALT then
                    local src_menu, menu_id = InTbl(GetMenus(), pie[i].guid)
                    if STATE == "PIE" then
                        table.insert(PIE_LIST, {
                            col = pie[i].col,
                            icon = pie[i].icon,
                            name = pie[i].name,
                            pid = pie,
                            prev_i = i,
                        })
                    else
                        LAST_MENU_SEL = menu_id
                    end
                    SWITCH_PIE = src_menu
                end
            end
        end
        r.ImGui_SetCursorScreenPos(ctx, button_pos.x, button_pos.y)

        r.ImGui_PushID(ctx, "pie_btn" .. i)
        r.ImGui_InvisibleButton(ctx, i, button_wh, button_wh)
        r.ImGui_PopID(ctx)

        if pie.hovered and pie[i].name ~= LAST_MSG then
            if not SETUP then
                LAST_MSG = pie[i].name
                BUTTON_HOVER_TIME = r.time_precise()
                BUTTON_PROG = ANIMATION and 0 or 1
            end
        end

        if (pie[i].key and r.ImGui_IsKeyReleased(ctx, pie[i].key)) then
            LAST_ACTION = i
            KEY_TRIGGER = true
        end

        if pie.selected then
            LAST_ACTION = i
        end

        DrawArc(pie, center, item_arc_span, ang_min, ang_max, RADIUS, RADIUS_MIN)
        PieButtonDrawlist(pie[i], button_wh, (pie.selected == i), boundry_hovered, button_pos)
    end
end

local function GetMouseDelta()
    local drag_delta = { MX - CENTER.x, MY - CENTER.y }
    if r.ImGui_IsMouseDown(ctx,0) then
        if not CX then
            CX, CY = MX, MY
        end
        CUR_POS_DELTA = { CX - CENTER.x, CY - CENTER.y }
        CUR_DRAG_DIST = (CUR_POS_DELTA[1] ^ 2) + (CUR_POS_DELTA[2] ^ 2)
    end
    DRAG_DIST = (drag_delta[1] ^ 2) + (drag_delta[2] ^ 2)
    DRAG_ANGLE = (atan(drag_delta[2], drag_delta[1])) % (pi * 2)
end

local function DrawCenter(pie, center)
    if SETUP and STATE == "EDITOR" and pie.guid == "TEMP" then return end
    local CENTER = center or CENTER
    local main_color = def_color

    local RADIUS = pie.RADIUS * CENTER_BTN_PROG
    local RADIUS_MIN = RADIUS / 2.2

    local button_wh = (RADIUS_MIN / sqrt(2)) * 2

    if not SETUP then
        pie.active = ((DRAG_DIST >= RADIUS_MIN ^ 2) and CENTER_BTN_PROG > 0.8)    
    else
        pie.active = CX and (CUR_DRAG_DIST >= RADIUS_MIN ^ 2) 
    end
    
    if not pie.active then
        if not SETUP then
            LAST_ACTION = nil
            LAST_MSG = pie.name
            BUTTON_HOVER_TIME = nil
        else
            if r.ImGui_IsMouseReleased(ctx, 0) and not pie.active and r.ImGui_IsWindowFocused(ctx) then
                LAST_MSG = pie.name
                pie.selected = nil
            end
        end
    end

    local col
    if SETUP then
        col = (not pie.selected) and IncreaseDecreaseBrightness(main_color, 15) or main_color
    else
        col = (not pie.active) and IncreaseDecreaseBrightness(main_color, 15) or main_color
    end
    
    if SETUP and not pie.selected then
        local scale = (sin(r.time_precise() * 5) * 0.05) + 1.01
        r.ImGui_DrawList_AddCircle(draw_list, CENTER.x, CENTER.y, (RADIUS_MIN + 5) * scale,
            LerpAlpha(0xffffffaa, (sin(r.time_precise() * 5) * 0.5) + 0.7),
            128, 2.5)
    end

    r.ImGui_SetCursorScreenPos(ctx, CENTER.x - (button_wh / 2), CENTER.y - (button_wh / 2))
    r.ImGui_InvisibleButton(ctx, "##CENTER", button_wh, button_wh)
    if SETUP and #PIE_LIST == 0 then
        DndAddAsContext(pie)
    end
    local center_pressed = (r.ImGui_IsMouseDown(ctx, 0) and not pie.active and r.ImGui_IsWindowFocused(ctx))
    center_pressed = #PIE_LIST > 0 and center_pressed
    if center_pressed then
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 4)
        r.ImGui_DrawList_AddCircle(draw_list, CENTER.x, CENTER.y, (RADIUS_MIN - 5), 0xffffff77, 128, 24)
    end

    -- DRAW CENTER CIRCLE -------------------------------------------------
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 3)

    -- SHADOW
    r.ImGui_DrawList_AddCircleFilled(draw_list, CENTER.x + 1, CENTER.y + 1,
        RADIUS_MIN + 2 - (center_pressed and 5 or 0), LerpAlpha(0x44, CENTER_BTN_PROG), 64)

    -- OUTER RING
    r.ImGui_DrawList_AddCircleFilled(draw_list, CENTER.x, CENTER.y, RADIUS_MIN - (center_pressed and 5 or 0),
        LerpAlpha(def_out_ring, CENTER_BTN_PROG), 64)

    -- MAIN CENTER CIRCLE
    r.ImGui_DrawList_AddCircleFilled(draw_list, CENTER.x, CENTER.y, RADIUS_MIN - 4 - (center_pressed and 5 or 0),
        LerpAlpha(main_color, CENTER_BTN_PROG), 64)

        -- COLOR BG
    r.ImGui_DrawList_AddCircleFilled(draw_list, CENTER.x, CENTER.y, RADIUS_MIN - 8 - (center_pressed and 5 or 0),
        LerpAlpha(col, CENTER_BTN_PROG), 64)

    -- DRAW CENTER CIRCLE -------------------------------------------------

    TextSplitByWidth(LAST_MSG, button_wh, button_wh)

    -- DRAW PREVIOUS MENU PREVIEW
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)
    if #PIE_LIST ~= 0 then
        local mini_rad = 13
        local prev_pie = PIE_LIST[#PIE_LIST].pid
        local prev_i = PIE_LIST[#PIE_LIST].prev_i
        local item_arc_span = (2 * pi) / #prev_pie
        for i = 1, #prev_pie do
            local cur_angle = (item_arc_span * (i) + START_ANG) % (2 * pi)
            local button_pos = {
                x = CENTER.x + ((RADIUS_MIN - 14 - (center_pressed and 5 or 0)) + (10 * MAIN_PROG)) * cos(cur_angle),
                y = CENTER.y + ((RADIUS_MIN - 14 - (center_pressed and 5 or 0)) + (10 * MAIN_PROG)) * sin(cur_angle),
            }

            -- SHADOW
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x + 1.5, button_pos.y + 1.5,
                (mini_rad + 2) * CENTER_BTN_PROG,
                LerpAlpha(0x44, MAIN_PROG), 128)

            -- OUTER RING
            if dark_theme then
                r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, mini_rad + 1.5 * MAIN_PROG,
                    LerpAlpha(def_out_ring, MAIN_PROG), 64)
            end
            -- MAIN BG
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, mini_rad * MAIN_PROG,
                prev_i == i and 0x23EE9cff or def_menu_prev, 64)

            -- PREVIOUS MENU POSITION HIGHLIGHT
            if prev_i == i then
                r.ImGui_DrawList_AddCircle(draw_list, button_pos.x, button_pos.y, mini_rad * MAIN_PROG, 0x25283eEE, 0, 2)
            end
        end

        if not SETUP then
            if r.ImGui_IsMouseReleased(ctx, 0) and not pie.active then
                SWITCH_PIE = PIE_LIST[#PIE_LIST].pid
                table.remove(PIE_LIST, #PIE_LIST)
            end
        else
            if r.ImGui_IsMouseDoubleClicked(ctx, 0) and not pie.active then
                SWITCH_PIE = PIE_LIST[#PIE_LIST].pid
                table.remove(PIE_LIST, #PIE_LIST)
            end
        end
    end
end

function DrawPie(pie, center)
    -- DRAW GUIDELINE WHERE MOUSE WAS BEFORE GUI WAS ADJUSTED TO BE IN THE SCREEN (ON EDGES)
    if OUT_SCREEN then
        r.ImGui_DrawList_AddLine(draw_list, PREV_X, PREV_Y, START_X, START_Y, 0xff0000FF, 5)
    end
    GetMouseDelta()
    SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    r.ImGui_DrawListSplitter_Split(SPLITTER, 5)
    DrawCenter(pie, center)
    DrawButtons(pie, center)
    r.ImGui_DrawListSplitter_Merge(SPLITTER)

    if r.ImGui_IsMouseReleased(ctx,0) then
        if CX then
            CX, CY = nil, nil
            CUR_POS_DELTA, CUR_DRAG_DIST = nil, nil
        end
    end
end
