--@noindex
--NoIndex: true
local r = reaper
local running_os = r.GetOS()
reaper_path = r.GetResourcePath()
local info = debug.getinfo(1, 'S');
local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. "?.lua;"

if DBG then dofile("C:/Users/Gokily/Documents/ReaGit/ReaScripts/Debug/LoadDebug.lua") end

easingFunctions = require("easing")
dofile(r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.7.6')

local tracker_script_id = r.NamedCommandLookup("_RS6b5bc650ef11c3470124d998b9eadea9e9778b16")

local SPLITTER

local pi, max, min, floor, cos, sin, atan, ceil, abs, sqrt = math.pi, math.max, math.min, math.floor, math.cos, math.sin,
    math.atan, math.ceil, math.abs, math.sqrt

FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

menu_file = script_path .. "menu_file.txt"
pie_file = script_path .. "pie_file.txt"
midi_cc_file = script_path .. "midi_cc_file.txt"
png_path = "/Data/toolbar_icons/"
png_path_150 = "/Data/toolbar_icons/150/"
png_path_200 = "/Data/toolbar_icons/200/"
png_path_track_icons = "/Data/track_icons/"
png_path_custom = "/Scripts/Sexan_Scripts/Pie3000/CustomImages/"

ANIMATION = true
ACTIVATE_ON_CLOSE = true
HOLD_TO_OPEN = true
RESET_POSITION = true
LIMIT_MOUSE = false
REVERT_TO_START = false
SWIPE_TRESHOLD = 45
SWIPE = false
SWIPE_CONFIRM = 50
ADJUST_PIE_NEAR_EDGE = false
SHOW_SHORTCUT = true
SELECT_THING_UNDER_MOUSE = false
CLOSE_ON_ACTIVATE = false
MIDI_TRACE_DEBUG = false
KILL_ON_ESC = false
STYLE = 1
OSX_DISABLE_MIDI_TRACING = false

local def_color_dark = 0x414141ff
local def_out_ring = 0x2a2a2aff
local def_menu_prev = def_color_dark --0x212121ff
local ARC_COLOR = 0x11AAFF88
local def_color = def_color_dark
local def_font_col = 0xd7d9d9ff
local spinner_col = 0xff0000ff
bg_col = 0x1d1f27ff

DEF_COLOR = def_color

local FONT_SIZE = 14
local FONT_LARGE = 16
local ICON_FONT_VERY_SMALL_SIZE = 14
local ICON_FONT_SMALL_SIZE = 25
local ICON_FONT_LARGE_SIZE = 40
local ICON_FONT_PREVIEW_SIZE = 16
local ICON_FONT_CLICKED_SIZE = 32
local GUI_FONT_SIZE = 14
local BUTTON_TEXT_STYLE_LARGE = 14

ICON_FONT_VERY_SMALL = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_VERY_SMALL_SIZE)
ICON_FONT_SMALL = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_SMALL_SIZE)
ICON_FONT_LARGE = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_LARGE_SIZE)
ICON_FONT_PREVIEW = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_PREVIEW_SIZE)
ICON_FONT_CLICKED = r.ImGui_CreateFont(script_path .. 'fontello1.ttf', ICON_FONT_CLICKED_SIZE)
SYSTEM_FONT = r.ImGui_CreateFont('sans-serif', FONT_SIZE, r.ImGui_FontFlags_Bold())
SYSTEM_FONT2 = r.ImGui_CreateFont('sans-serif', FONT_LARGE, r.ImGui_FontFlags_Bold())
GUI_FONT = r.ImGui_CreateFont(script_path .. "Roboto-Medium.ttf", GUI_FONT_SIZE)
BUTTON_TEXT_FONT = r.ImGui_CreateFont(script_path .. "Roboto-Medium.ttf", BUTTON_TEXT_STYLE_LARGE)

r.ImGui_Attach(ctx, BUTTON_TEXT_FONT)
r.ImGui_Attach(ctx, GUI_FONT)
r.ImGui_Attach(ctx, SYSTEM_FONT)
r.ImGui_Attach(ctx, SYSTEM_FONT2)
r.ImGui_Attach(ctx, ICON_FONT_VERY_SMALL)
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
            CLOSE_ON_ACTIVATE = save_data.close_on_activate
            MIDI_TRACE_DEBUG = save_data.midi_trace_debug
            KILL_ON_ESC = save_data.kill_on_esc
            STYLE = save_data.style ~= nil and save_data.style or STYLE
            OSX_DISABLE_MIDI_TRACING = save_data.osx_midi_tracing
        end
    end
end

local KEYS_IGNORE_LIST = {
    ["escape"] = true,
    ["leftshift"] = true,
    ["righthift"] = true,
    ["leftalt"] = true,
    ["rightalt"] = true,
    ["leftctrl"] = true,
    ["rightctrl"] = true,
    ["leftsuper"] = true,
    ["rightsuper"] = true,
}

local KEYS = {}
for name, func in pairs(r) do
    name = name:match('^ImGui_Key_(.+)$')
    if name and not KEYS_IGNORE_LIST[name:lower()] then KEYS[func()] = name end
end

function GetImguiKeys()
    return KEYS
end

function IterateActions(sectionID)
    local i = 0
    return function()
        local retval, name = r.kbd_enumerateActions(sectionID, i)
        if #name ~= 0 then
            i = i + 1
            return retval, name
        end
    end
end

local SECTION_FILTER = {
    [0] = 0,
    [32060] = 32060,
    [32062] = 32062,
    [32061] = 32061,
    [32063] = 32063,
}

function GetActions(s)
    local actions = {}
    local pairs_actions = {}
    for cmd, name in IterateActions(s) do
        if name ~= "Script: Sexan_Pie3000.lua" then
            table.insert(actions, { cmd = cmd, name = name, type = SECTION_FILTER[s] })
            pairs_actions[name] = { cmd = cmd, name = name, type = SECTION_FILTER[s] }
        end
    end
    table.sort(actions, function(a, b) return a.name < b.name end)
    return actions, pairs_actions
end

local ACTIONS_TBL, ACTIONS_TBL_PAIRS = GetActions(0)
local MIDI_ACTIONS_TBL, MIDI_ACTIONS_TBL_PAIRS = GetActions(32060)
local MIDI_INLINE_ACTIONS_TBL, MIDI_INLINE_ACTIONS_TBL_PAIRS = GetActions(32062)
local MIDI_EVENT_ACTIONS_TBL, MIDI_EVENT_ACTIONS_TBL_PAIRS = GetActions(32061)
local EXPLORER_ACTIONS_TBL, EXPLORER_ACTIONS_TBL_PAIRS = GetActions(32063)

function GetMainActions()
    return ACTIONS_TBL, ACTIONS_TBL_PAIRS
end

function GetMidiActions()
    return MIDI_ACTIONS_TBL, MIDI_INLINE_ACTIONS_TBL, MIDI_EVENT_ACTIONS_TBL, MIDI_ACTIONS_TBL_PAIRS,
        MIDI_INLINE_ACTIONS_TBL_PAIRS, MIDI_EVENT_ACTIONS_TBL_PAIRS
end

function GetExplorerActions()
    return EXPLORER_ACTIONS_TBL, EXPLORER_ACTIONS_TBL_PAIRS
end

local function GetToggleState(name, cmd)
    if not name then return end
    local section
    if MIDI_ACTIONS_TBL_PAIRS[name] then
        section = MIDI_ACTIONS_TBL_PAIRS[name].type
    end
    if MIDI_INLINE_ACTIONS_TBL_PAIRS[name] then
        section = MIDI_INLINE_ACTIONS_TBL_PAIRS[name].type
    end

    if MIDI_EVENT_ACTIONS_TBL_PAIRS[name] then
        section = MIDI_EVENT_ACTIONS_TBL_PAIRS[name].type
    end

    if EXPLORER_ACTIONS_TBL_PAIRS[name] then
        section = EXPLORER_ACTIONS_TBL_PAIRS[name].type
    end
    if ACTIONS_TBL_PAIRS[name] then
        section = ACTIONS_TBL_PAIRS[name].type
    end

    if section then
        if r.GetToggleCommandStateEx(section, cmd) == 1 then
            return true
        end
    end
end

function Release()
    if not KEY then return end
    r.JS_VKeys_Intercept(KEY, -1)
    r.SNM_SetIntConfigVar("alwaysallowkb", ALLOW_KB_VAR)
end

local CC_LIST = {
    [0] = "Main",
    [-1] = "Velocity",
    [-2] = "Off Velocity",
    [-3] = "Pitch",
    [-4] = "Program",
    [-5] = "Channel Pressure",
    [-6] = "Bank/Program Select",
    [-7] = "Text Events",
    [-8] = "Notation Events",
    [-9] = "Sysex",
    [-10] = "Media Item Lane",
    ------------------------------------
    "00 Bank Select MSB",
    "01 Mod Wheel MSB",
    "02 Breath MSB",
    "03",
    "04 Foot Pedal MSB",
    "05 Portamento MSB",
    "06 Data Entry MSB",
    "07 Volume MSB",
    "08 Balance MSB",
    "09",
    "10 Pan Position MSB",
    "11 Expression MSB",
    "12 Control 1 MSB",
    "13 Control 2 MSB",
    "14",
    "15",
    "16 GP Slider 1",
    "17 GP Slider 2",
    "18 GP Slider 3",
    "19 GP Slider 4",
    "20",
    "21",
    "22",
    "23",
    "24",
    "25",
    "26",
    "27",
    "28",
    "29",
    "30",
    "31",
    "32 Bank Select LSB",
    "33 Mod Wheel LSB",
    "34 Breath LSB",
    "35",
    "36 Foot Pedal LSB",
    "37 Portamento LSB",
    "38 Data Entry LSB",
    "39 Volume LSB",
    "40 Balance LSB",
    "41",
    "42 Pan Position LSB",
    "43 Expression LSB",
    "44 Control 1 LSB",
    "45 Control 2 LSB",
    "46",
    "47",
    "48",
    "49",
    "50",
    "51",
    "52",
    "53",
    "54",
    "55",
    "56",
    "57",
    "58",
    "59",
    "60",
    "61",
    "62",
    "63",
    "64 Hold Pedal (on/off)",
    "65 Portamento (on/off)",
    "66 Sostenuto (on/off)",
    "67 Soft Pedal (on/off)",
    "68 Legato Pedal (on/off)",
    "69 Hold 2 Pedal (on/off)",
    "70 Sound Variation",
    "71 Timbre/Resonance",
    "72 Sound Release",
    "73 Sound Attack",
    "74 Brightness/Cutoff Freq",
    "75 Sound Control 6",
    "76 Sound Control 7",
    "77 Sound Control 8",
    "78 Sound Control 9",
    "79 Sound Control 10",
    "80 GP Button 1 (on/off)",
    "81 GP Button 2 (on/off)",
    "82 GP Button 3 (on/off) 83 GP Button 4 (on/off)",
    "83",
    "84",
    "85",
    "86",
    "87",
    "88",
    "89",
    "90",
    "91 Effects Level",
    "92 Tremolo Level",
    "93 Chorus Level",
    "94 Celeste Level",
    "95 Phaser Level",
    "96 Data Button Inc",
    "97 Data Button Dec",
    "98 Non-Reg Parm LSB",
    "99 Non-Reg Parm MSB",
    "100 Reg Parm LSB",
    "101 Reg Parm MSB",
    "102",
    "103",
    "104",
    "105",
    "106",
    "107",
    "108",
    "109",
    "110",
    "111",
    "112",
    "113",
    "114",
    "115",
    "116",
    "117",
    "118",
    "119",
    ------
    "00/32 Bank Select 14-bit",
    "01/33 Mod Wheel 14-bit",
    "02/34 Breath 14-bit",
    "03/35 14-bit",
    "04/36 Foot Pedal 14-bit",
    "05/37 Portamento 14-bit",
    "06/38 Data Entry 14-bit",
    "07/39 Volume 14-bit",
    "08/40 Balance 14-bit",
    "09/41 14-bit",
    "10/42 Pan Position 14-bit",
    "11/43 Expression 14-bit",
    "12/44 Control 1 14-bit",
    "13/45 Control 2 14-bit",
    "14/46 14-bit",
    "15/47 14-bit",
    "16/48 GP Slider 1 14-bit",
    "17/49 GP Slider 2 14-bit",
    "18/50 GP Slider 3 14-bit",
    "19/51 GP Slider 4 14-bit",
    "20/52 14-bit",
    "21/53 14-bit",
    "22/54 14-bit",
    "23/55 14-bit",
    "24/56 14-bit",
    "25/57 14-bit",
    "26/58 14-bit",
    "27/59 14-bit",
    "28/60 14-bit",
    "29/61 14-bit",
    "30/62 14-bit",
    "31/63 14-bit",
}

function GetCCList()
    return CC_LIST
end

local ENV_LIST = {
    [0] = "Main",
    "Volume",
    "Pan",
    "Width",
    "Volume (Pre-FX)",
    "Pan (Pre-FX)",
    "Width (Pre-FX)",
    "Trim Volume",
    "Mute",
    "Playrate",
    "Tempo map"
}

function GetEnvList()
    return ENV_LIST
end

local cc_lanes = {
    [-1]    = "global",
    [0x200] = "velocity",
    [0x201] = "pitch",
    [0x202] = "program",
    [0x203] = "channel pressure",
    [0x204] = "bank/program select",
    [0x205] = "text events",
    [0x206] = "sysex",
    [0x207] = "off velocity",
    [0x208] = "notation events",
    [0x210] = "media item lane",
}

local function MidiLaneDetect(hwnd)
    local mouse_wnd = r.JS_Window_FromPoint(r.GetMousePosition())
    local x, y = r.JS_Window_ScreenToClient(mouse_wnd, r.GetMousePosition())
    r.JS_WindowMessage_Send(mouse_wnd, "WM_LBUTTONDOWN", 1, 0, x, y)
    r.JS_WindowMessage_Send(mouse_wnd, "WM_RBUTTONDOWN", 1, 0, x, y)
    r.JS_WindowMessage_Send(mouse_wnd, "WM_RBUTTONUP", 0, 0, x, y)
    r.JS_WindowMessage_Send(mouse_wnd, "WM_LBUTTONUP", 0, 0, x, y)
    local lane = r.MIDIEditor_GetSetting_int(hwnd, "last_clicked_cc_lane")
    local sel_lane = "global"

    if cc_lanes[lane] then
        sel_lane = cc_lanes[lane]
    else
        if lane < 128 then
            sel_lane = CC_LIST[lane + 1]:lower()
        elseif lane > 255 then
            local cc = lane - 0x100 + 121
            sel_lane = CC_LIST[cc]:lower()
        end
    end
    return sel_lane
end

local MIDI_WND_IDS = {
    { id = 0x000003EB, name = "midipianoview" },
    { id = 0x000003E9, name = "midiview" },
}

function IsOSX()
    if running_os:match("OSX") or running_os:match("macOS") then
        return true
    end
end

local GetPixel = r.JS_LICE_GetPixel
function DetectMIDIContext(midi_debug)
    local function IsInside(left, top, right, bottom)
        if START_X > left and START_X < right and START_Y > top and START_Y < bottom then
            return true
        end
    end
    -- FAST
    local function FasterSearch(bmp, target, start_px)
        local step = 10
        local bot
        local px_start = start_px
        while not bot do
            px_start = px_start + step
            if GetPixel(bmp, 0, px_start) ~= target then
                if GetPixel(bmp, 0, px_start - 1) == target then
                    bot = px_start
                end
                step = -1
            end
            if px_start > 10000 then
                r.ShowConsoleMsg("CC LANES NOT DETECTED")
                break
            end -- prevent infinite loop
        end
        return bot
    end
    -- EXTREMELLY FAST BUT BROKEN
    local function BinaryPixelSearch(bmp, target, w, px_start, px_end)
        local point = (px_start + px_end) // 2
        if GetPixel(bmp, w - 1, point) == target then
            if GetPixel(bmp, w - 1, point - 1) ~= target or GetPixel(bmp, w - 1, point + 1) ~= target then
                return point
            end
            return BinaryPixelSearch(bmp, target, w, px_start, point)
        else
            return BinaryPixelSearch(bmp, target, w, point, px_end)
        end
    end
    -- SLOW
    local function CalculateLanes(bitmap, w, h)
        local start_color = GetPixel(bitmap, 1, 1)
        local top_px, BOT_PX
        for i = 1, h do
            local color = GetPixel(bitmap, w - 1, i)
            if color ~= start_color then
                if not top_px then
                    top_px = i
                end
            else
                if top_px then
                    if not BOT_PX then
                        BOT_PX = i
                        break
                    end
                end
            end
        end
        return BOT_PX
    end

    -- TAKE SCREENSHOT OF THE THE RIGHT SCROLLBAR

    local function ScreenshotOSX(x, y, w, h)
        x, y = r.ImGui_PointConvertNative(ctx, x, y, false)
        local filename = os.tmpname() -- a shell-safe value
        local command = 'screencapture -x -R %d,%d,%d,%d -t png "%s"'
        os.execute(command:format(x, y, w, h, filename))
        local png = r.JS_LICE_LoadPNG(filename)
        os.remove(filename)
        return png
    end

    -- TAKE SCREENSHOT OF THE THE RIGHT SCROLLBAR
    local function takeScreenshot(window, dpi_scale)
        local retval, left, top, right, bottom = r.JS_Window_GetRect(window)
        local bot_px
        if retval then
            local w, h = right - left, bottom - top
            local destBmp
            if not IsOSX() then
                destBmp = r.JS_LICE_CreateBitmap(true, 1, h)
                local srcDC = r.JS_GDI_GetWindowDC(window)
                local destDC = r.JS_LICE_GetDC(destBmp)
                r.JS_GDI_Blit(destDC, 0, 0, srcDC, w - 1, 0, w, h)
                r.JS_GDI_ReleaseDC(window, srcDC)
            else
                h = top - bottom
                destBmp = ScreenshotOSX(right - 1, top, 1, h)
            end

            bot_px = FasterSearch(destBmp, GetPixel(destBmp, 0, ceil(64 * dpi_scale)), ceil(65 * dpi_scale)) // DPI_OS

            r.JS_LICE_DestroyBitmap(destBmp)
        end
        return bot_px
    end

    local HWND = r.MIDIEditor_GetActive()
    DPI_OS = r.ImGui_GetWindowDpiScale(ctx)
    local retval_dpi, dpi = r.get_config_var_string("uiscale")

    local dpi_scale = tonumber(dpi)
    if not HWND then return end
    local main_retval, main_left, main_top, main_right, main_bottom = r.JS_Window_GetClientRect(HWND)

    local child_hwnd = r.JS_Window_FindChildByID(HWND, MIDI_WND_IDS[2].id)
    local piano_hwnd = r.JS_Window_FindChildByID(HWND, MIDI_WND_IDS[1].id)
    if not BOT_PX and not OSX_DISABLE_MIDI_TRACING then
        BOT_PX = takeScreenshot(child_hwnd, dpi_scale)
    end

    local retval, left, top, right, bottom = r.JS_Window_GetRect(child_hwnd)
    left, top = r.ImGui_PointConvertNative(ctx, left, top, false)
    right, bottom = r.ImGui_PointConvertNative(ctx, right, bottom, false)
    local track_list = main_right - right > 1

    if not BOT_PX then BOT_PX = bottom - top end
    --local top_offset = ceil(64*dpi_scale)
    if midi_debug then
        r.ImGui_DrawList_AddRect(draw_list, left, top + ceil(64 * dpi_scale), right, top + BOT_PX, 0xff000050, 0, 0, 1)
        r.ImGui_DrawList_AddText(draw_list, left + 20, top + ceil(64 * dpi_scale) + 20, 0xffffffff, "MIDI NOTES")

        r.ImGui_DrawList_AddRect(draw_list, left, top + BOT_PX, right, bottom, 0xff000050, 0, 0, 1)
        r.ImGui_DrawList_AddText(draw_list, left + 20, top + BOT_PX + 5 + 20, 0xffffffff, "CC LANES")

        r.ImGui_DrawList_AddRect(draw_list, left, top, right, top + ceil(65 * dpi_scale), 0xff000050, 0, 0, 1)
        r.ImGui_DrawList_AddText(draw_list, left + 20, top + 20, 0xffffffff, "RULER")

        if track_list then
            r.ImGui_DrawList_AddRect(draw_list, right, top, main_right, bottom, 0xff000050, 0, 0, 2)
            r.ImGui_DrawList_AddText(draw_list, right + 20, top + 20, 0xffffffff, "TRACK LIST")
        end
    end
    --if piano then
    local p_retval, p_left, p_top, p_right, p_bottom = r.JS_Window_GetRect(piano_hwnd)
    p_left, p_top = r.ImGui_PointConvertNative(ctx, p_left, p_top, false)
    p_right, p_bottom = r.ImGui_PointConvertNative(ctx, p_right, p_bottom, false)
    if midi_debug then
        r.ImGui_DrawList_AddRect(draw_list, p_left, top + ceil(64 * dpi_scale), p_right, top + BOT_PX + 5, 0xff000050,
            0, 0, 1)
        r.ImGui_DrawList_AddText(draw_list, p_left + 20, top + ceil(64 * dpi_scale) + 20, 0xffffffff, "PIANO ROLL")

        r.ImGui_DrawList_AddRect(draw_list, p_left, top + BOT_PX + 5, p_right, bottom, 0xff000050, 0, 0, 1)
        r.ImGui_DrawList_AddText(draw_list, p_left + 20, top + BOT_PX + 5 + 20, 0xffffffff, "CC CP")
    end

    if IsInside(p_left, top + ceil(64 * dpi_scale), p_right, top + BOT_PX + 5) then
        return "midipianoroll"
    elseif IsInside(p_left, top + BOT_PX + 5, p_right, bottom) then
        -- MIDI_LANE_CONTEXT = "cp"
        -- local lane_cp = MidiLaneDetect(HWND)
        -- if lane_cp then return "cp " .. lane_cp end
    end
    --end
    if track_list and IsInside(right, top, main_right, bottom) then
        return "miditracklist"
    end
    if IsInside(left, top + ceil(63 * dpi_scale), right, top + BOT_PX) then
        return "midi"
    end
    -- RULLER
    if IsInside(left, top, right, top + ceil(64 * dpi_scale)) then
        return "midiruler"
    end
    -- LANES (WHOLE SECTION)
    if IsInside(left, top + BOT_PX, right, bottom) then
        MIDI_LANE_CONTEXT = "lane"
        return MidiLaneDetect(HWND)
    end
end

function DetectEnvContext(track, env_info, cp)
    local env_num = env_info:match("%S+ (%S+)$")
    local env
    if env_num then
        env = r.GetTrackEnvelope(track, env_num)
        local retval, name = r.GetEnvelopeName(env)
        if retval then
            if ENV_LIST[name] then
                local context = cp and "cp " .. name:lower() or name:lower()
                return context, env
            end
        end
    end
    return (cp and "envcp" or "envelope"), env
end

function DetectMediaExplorer(parent)
    return "mediaexplorer", parent
end

function PrintTraceback(err)
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

function PDefer(func)
    r.defer(function()
        local status, err = xpcall(func, debug.traceback)
        if not status then
            PrintTraceback(err)
            Release()
        end
    end)
end

function DrawTooltip(str)
    if not r.ImGui_IsItemHovered(ctx) then return end
    if r.ImGui_BeginTooltip(ctx) then
        r.ImGui_Text(ctx, str)
        r.ImGui_EndTooltip(ctx)
    end
end

function DrawDND(x, y, radius, col, dd_type)
    r.ImGui_DrawList_AddCircle(draw_list, x, y, radius, col, 128, 4)
end

function EasingAnimation(begin_val, end_val, duration_in_sec, ease_function, call_time, delay)
    local time = max(r.time_precise() - call_time, 0.01) - (delay and delay or 0)
    if time <= 0 then return begin_val end
    local change = end_val - begin_val
    if time >= duration_in_sec then return end_val end
    local new_val = max(ease_function(time, begin_val, change, duration_in_sec))
    return new_val
end

function IsColorLuminanceHigh(org_color)
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

function ImageUVOffset(img_obj, resize, cols, rows, frame, x, y, prog, need_single_frame)
    local w, h = r.ImGui_Image_GetSize(img_obj)
    local factor = resize and h / resize
    if resize and h > resize then
        h = h // factor
        w = w // factor
    end

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

local function StateSpinner(cx, cy, col, radius, is_dd)
    local item_arc_span = (2 * pi) / 2
    for i = 1, 2 do
        local ang_min = (item_arc_span) * (i - (0.2)) + (r.time_precise() % (pi * 2))
        local ang_max = (item_arc_span) * (i + (0.2)) + (r.time_precise() % (pi * 2))
        r.ImGui_DrawList_PathArcTo(draw_list, cx, cy, radius + 5, ang_min, ang_max)
        r.ImGui_DrawList_PathStroke(draw_list, STYLE == 3 and 0xff0000ff or (dark_theme and 0x40ffb3ff or 0xff2233ff),
            nil, is_dd and 4 or 5)
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
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 4)
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
            r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, xs + bw / 2 - str_w / 2,
                ys + (bh / 2) - (txt_h * (h_cnt - (i - 1))) + (h_cnt * txt_h) / 2, LerpAlpha(0xffffffff, CENTER_BTN_PROG),
                str_tbl[i])
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

local function DrawShortcut(pie, button_pos, selected)
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, selected and 3 or 1)
    r.ImGui_PushFont(ctx, GUI_FONT)
    --r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(),0x8cdbffff)
    local key_w, key_h = r.ImGui_CalcTextSize(ctx, KEYS[pie.key])
    local style_offset = 1
    if button_pos.side then
        if button_pos.side == "R" then
            style_offset = 0
        else
            style_offset = 2
        end
    end
    local xx = button_pos.kx - ((key_w + 15) / 2) * style_offset
    local txt_c = xx + ((key_w + 15) / 2)

    if KEYS[pie.key] then
        r.ImGui_SetCursorScreenPos(ctx, button_pos.kx - ((key_w + 15) / 2) * style_offset, button_pos.ky)
        r.ImGui_InvisibleButton(ctx, KEYS[pie.key], (key_w + 15), key_h + 2)
        local xs, ys = r.ImGui_GetItemRectMin(ctx)
        local xe, ye = r.ImGui_GetItemRectMax(ctx)
        -- SHADOW
        r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe + 4, ye + 4, LerpAlpha(0x44, CENTER_BTN_PROG), 7,
            r.ImGui_DrawFlags_RoundCornersAll())
        -- RING
        r.ImGui_DrawList_AddRectFilled(draw_list, xs - 2, ys - 2, xe + 2, ye + 2,
            LerpAlpha(def_out_ring, CENTER_BTN_PROG), 7,
            r.ImGui_DrawFlags_RoundCornersAll())
        -- MAIN
        r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, LerpAlpha(0x1d1f27ff, CENTER_BTN_PROG), 5,
            r.ImGui_DrawFlags_RoundCornersAll())
        -- SHADOW
        r.ImGui_DrawList_AddTextEx(draw_list, nil, GUI_FONT_SIZE * CENTER_BTN_PROG, txt_c - (key_w / 2) + 1,
            button_pos.ky + 1, LerpAlpha(0xFF, CENTER_BTN_PROG), KEYS[pie.key])
        -- MAIN
        r.ImGui_DrawList_AddTextEx(draw_list, nil, GUI_FONT_SIZE * CENTER_BTN_PROG, txt_c - (key_w / 2), button_pos.ky,
            LerpAlpha(0x8cc3ffff, CENTER_BTN_PROG), KEYS[pie.key])
    end
    r.ImGui_PopFont(ctx)
end

local function PieButtonDrawlist(pie, button_radius, selected, hovered, button_pos)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local button_center = { x = xs + (w / 2), y = ys + (h / 2) }

    if not SETUP then
        button_radius = selected and button_radius + (10 * BUTTON_PROG) or button_radius
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

    --local icon_col = LerpAlpha(0xffffffff, CENTER_BTN_PROG)
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
        LerpAlpha(dark_theme and 0x44 or 0x33, CENTER_BTN_PROG), 128)

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
    if (tonumber(pie.cmd) and GetToggleState(pie.cmd_name, pie.cmd)) or pie.toggle_state then
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
                    LerpAlpha(ring_col, CENTER_BTN_PROG), 128)
                -- MAIN CIRCLE
                r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y,
                    menu_preview_radius * CENTER_BTN_PROG,
                    LerpAlpha(def_menu_prev, CENTER_BTN_PROG), 128)
            else
                -- DRAW EMPTY
                r.ImGui_DrawList_AddCircle(draw_list, button_pos.x, button_pos.y,
                    (menu_preview_radius + 1.5) * CENTER_BTN_PROG,
                    LerpAlpha(ring_col, CENTER_BTN_PROG), 128, 2)
            end
        end
    end
    -- MENU PREVIEW CIRCLE -------------------------------------------------

    -- KEY CIRCLE   -----------------------------------------------------------
    if SHOW_SHORTCUT then
        if pie.key then
            DrawShortcut(pie, button_pos, selected, 2)
        end
    end
    -- KEY CIRCLE   -----------------------------------------------------------

    -- ICONS AND PNG
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, selected and 3 or 1)

    if icon then
        local luma_high = IsColorLuminanceHigh(col)
        local icon_col = LerpAlpha(luma_high and 0xff or 0xffffffff, CENTER_BTN_PROG)
        r.ImGui_PushFont(ctx, icon_font)
        local icon_w, icon_h = r.ImGui_CalcTextSize(ctx, icon)
        local i_x, i_y = button_center.x - icon_w / 2, button_center.y - icon_h / 2
        if not luma_high then
            r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * CENTER_BTN_PROG, i_x + 2, i_y + 2, 0xaa, icon)
        end
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * CENTER_BTN_PROG, i_x, i_y, icon_col, icon)
        r.ImGui_PopFont(ctx)
    end

    if png and r.file_exists(reaper_path .. png) then
        if not r.ImGui_ValidatePtr(pie.img_obj, 'ImGui_Image*') then
            pie.img_obj = r.ImGui_CreateImage(reaper_path .. png)
        end
        local is_toolbar_icon = png:find("toolbar_icons")
        ImageUVOffset(pie.img_obj, pie.rescale, is_toolbar_icon and 3 or 1, 1,
            is_toolbar_icon and 0 or (selected and 2 or 0), button_center.x, button_center.y, CENTER_BTN_PROG)
    end
end

local function lerp(a, b, t) return a + (b - a) * t end

local function Animate_On_Cordinates(a, b, duration_in_sec, time)
    local final_time = min((time / duration_in_sec - floor(time / duration_in_sec)) * 1, 1)
    local new_val = lerp(a, b, final_time)
    return new_val
end

local function DrawClassicButton(pie, selected, hovered)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local button_pos = {
        kx = xs > CENTER.x and xe + (selected and 15 or 5) or xs - (selected and 15 or 5),
        ky = ys + 5,
        side =
            xs > CENTER.x and "R" or "L"
    }

    local button_center = { x = xs + (w / 2), y = ys + (h / 2) }

    local color, name, png, icon = pie.col, pie.name, pie.png, pie.icon
    local ring_col = (hovered and ALT) and 0xff0000ff or def_out_ring
    color = color == 0xff and def_color or color

    color = (hovered and ALT) and 0xff0000ff or color

    local icon_font = selected and ICON_FONT_SMALL or ICON_FONT_VERY_SMALL
    local icon_font_size = selected and ICON_FONT_SMALL_SIZE or ICON_FONT_VERY_SMALL_SIZE
    local col = (selected or hovered) and IncreaseDecreaseBrightness(color, 30) or color

    local click_highlight
    if SETUP then
        click_highlight = hovered
    else
        click_highlight = selected
    end

    local sel_size = (selected or (pie.key and r.ImGui_IsKeyDown(ctx, pie.key))) and 10 or 0
    if SETUP and selected then
        sel_size = 6
        local scale = (sin(r.time_precise() * 5) * 0.15) + 1.02
        local sel_size_2 = sel_size + 5
        r.ImGui_DrawList_AddRect(draw_list, (xs - sel_size_2 * scale) - 1, (ys - sel_size_2 * scale) - 1,
            (xe + sel_size_2 * scale) + 1,
            (ye + sel_size_2 * scale) + 1,
            LerpAlpha(0xffffffaa, (sin(r.time_precise() * 5) * 0.5) + 0.7), 5, r.ImGui_DrawFlags_RoundCornersAll(),
            2.5 * scale)
    end

    if click_highlight and r.ImGui_IsMouseDown(ctx, 0) or (pie.key and r.ImGui_IsKeyDown(ctx, pie.key)) then
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)
        r.ImGui_DrawList_AddRectFilled(draw_list, (xs - sel_size) - 6, (ys - sel_size) - 6, (xe + sel_size) + 6,
            (ye + sel_size) + 6,
            0xffffff77, 5, r.ImGui_DrawFlags_RoundCornersAll())
        col = IncreaseDecreaseBrightness(col, 20)
        sel_size = selected and sel_size - 5 or sel_size
    end

    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, selected and 3 or 2)

    -- SHADOW
    r.ImGui_DrawList_AddRectFilled(draw_list, (xs - sel_size), (ys - sel_size), (xe + sel_size) + 4, (ye + sel_size) + 4,
        LerpAlpha(dark_theme and 0x44 or 0x33, CENTER_BTN_PROG), 5, r.ImGui_DrawFlags_RoundCornersAll())

    -- OUTER RING
    r.ImGui_DrawList_AddRectFilled(draw_list, (xs - sel_size) - 1, (ys - sel_size) - 1, (xe + sel_size) + 1,
        (ye + sel_size) + 1,
        LerpAlpha(ring_col, CENTER_BTN_PROG), 5, r.ImGui_DrawFlags_RoundCornersAll())

    -- MAIN
    r.ImGui_DrawList_AddRectFilled(draw_list, (xs - sel_size) + 1, (ys - sel_size) + 1, (xe + sel_size) - 1,
        (ye + sel_size) - 1,
        LerpAlpha(def_color, CENTER_BTN_PROG), 5, r.ImGui_DrawFlags_RoundCornersAll())

    -- COLOR
    r.ImGui_DrawList_AddRectFilled(draw_list, (xs - sel_size) + 3, (ys - sel_size) + 3, (xe + sel_size) - 3,
        (ye + sel_size) - 3,
        LerpAlpha(col, CENTER_BTN_PROG), 5, r.ImGui_DrawFlags_RoundCornersAll())

    if (tonumber(pie.cmd) and GetToggleState(pie.cmd_name, pie.cmd)) or pie.toggle_state then
        -- for i = 1, 2 do
        local new_x = Animate_On_Cordinates(xs - 35, xe, 2, (r.time_precise() * 0.5) - (1)) // 1

        local end_x = new_x + 35 > xe and xe or new_x + 35
        local start_x = new_x < xs and xs or new_x

        r.ImGui_DrawList_AddLine(draw_list, start_x, ys - 2 - sel_size, end_x, ys - 2 - sel_size,
            dark_theme and 0x40ffb3ff or 0xff2233ff, 5)

        local new_x = Animate_On_Cordinates(xs - 35, xe, 2, (-r.time_precise() * 0.5) - (1)) // 1

        local end_x = new_x + 35 > xe and xe or new_x + 35
        local start_x = new_x < xs and xs or new_x

        r.ImGui_DrawList_AddLine(draw_list, start_x, ye + 2 + sel_size, end_x, ye + 2 + sel_size,
            dark_theme and 0x40ffb3ff or 0xff2233ff, 5)
    end

    if pie.menu then
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)

        r.ImGui_DrawList_AddRectFilled(draw_list, (xs - sel_size + w / 2) - 20, (ys - sel_size) - 8,
            (xe + sel_size - w / 2) + 20,
            (ys - sel_size) + 5,
            LerpAlpha(ring_col, CENTER_BTN_PROG), 5, r.ImGui_DrawFlags_RoundCornersAll())

        r.ImGui_DrawList_AddRectFilled(draw_list, (xs - sel_size + w / 2) - 18, (ys - sel_size) - 6,
            (xe + sel_size - w / 2) + 18,
            (ys - sel_size) + 3,
            LerpAlpha(def_color, CENTER_BTN_PROG), 5, r.ImGui_DrawFlags_RoundCornersAll())
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 3)

        r.ImGui_DrawList_AddTriangleFilled(draw_list, (xs - sel_size + w / 2) - 10, (ys - sel_size) - 6,
            (xe + sel_size - w / 2) + 10, (ys - sel_size) - 6, (xs + w / 2), (ys + (selected and 0 or 3)), 0xCCCCCCff)
        r.ImGui_DrawList_AddTriangleFilled(draw_list, (xs - sel_size + w / 2) - (selected and 2 or 4),
            (ys - sel_size) - 4, (xe + sel_size - w / 2) + (selected and 2 or 4), (ys - sel_size) - 4, (xs + w / 2),
            (ys + (selected and -4 or 0)), 0x525356ff)
    end

    if SHOW_SHORTCUT then
        if pie.key then
            DrawShortcut(pie, button_pos, selected)
        end
    end

    local is_luma_high = IsColorLuminanceHigh(col)
    local txt_col = LerpAlpha(is_luma_high and 0xff or 0xffffffff, CENTER_BTN_PROG)
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, selected and 3 or 2)
    if icon then
        r.ImGui_PushFont(ctx, icon_font)
        local icon_w, icon_h = r.ImGui_CalcTextSize(ctx, icon)
        local i_x, i_y = xs + (selected and 0 or 9), button_center.y - icon_h / 2
        if not is_luma_high then
            r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * CENTER_BTN_PROG, i_x + 2, i_y + 2, 0xaa, icon)
        end
        r.ImGui_DrawList_AddTextEx(draw_list, nil, icon_font_size * CENTER_BTN_PROG, i_x, i_y, txt_col, icon)
        r.ImGui_PopFont(ctx)
    end

    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local font_size = r.ImGui_GetFontSize(ctx)

    local txt_x = xs + (icon and 12 or 0) + (w / 2) - (label_size / 2)
    local txt_y = ys + (h / 2) - (font_size / 2)

    if not is_luma_high then
        r.ImGui_DrawList_AddTextEx(draw_list, nil, font_size, txt_x + 1, txt_y + 1, LerpAlpha(0xff, CENTER_BTN_PROG),
            name)
    end
    r.ImGui_DrawList_AddTextEx(draw_list, nil, font_size, txt_x, txt_y, LerpAlpha(txt_col, CENTER_BTN_PROG), name)
end

local function DrawButtonTextStyle(pie, center)
    local function RoughlyEquals(a, b)
        return abs(a - b) < 0.00001
    end

    local function NearestValue(table, number)
        local smallestSoFar, smallestIndex
        local last_tbl_idx
        for i, y in ipairs(table) do
            if not smallestSoFar or (abs(number - y[1]) < smallestSoFar) then
                smallestSoFar = abs(number - y[1])
                smallestIndex = y[2]
                last_tbl_idx = i
            end
        end
        return smallestIndex, last_tbl_idx
    end
    r.ImGui_PushFont(ctx, SYSTEM_FONT)
    local CENTER = center or CENTER

    local item_arc_span = ((2 * pi) / #pie)

    local RADIUS = pie.RADIUS * CENTER_BTN_PROG
    local RADIUS_MIN = RADIUS / 2.2

    local ap1_t = atan((CENTER.y - RADIUS) - CENTER.y, (CENTER.x - RADIUS_MIN) - CENTER.x)
    local ap2_t = atan((CENTER.y - RADIUS) - CENTER.y, (CENTER.x + RADIUS_MIN) - CENTER.x)

    local ap1_b = atan((CENTER.y + RADIUS) - CENTER.y, (CENTER.x - RADIUS_MIN) - CENTER.x)
    local ap2_b = atan((CENTER.y + RADIUS) - CENTER.y, (CENTER.x + RADIUS_MIN) - CENTER.x)

    local ap_c = atan((CENTER.y + RADIUS) - CENTER.y, 0)

    local pie_even = #pie % 2 == 0

    local inside
    if pie.active and AngleInRange(DRAG_ANGLE, ap1_t, ap2_t) then
        inside = { ap1_t, ap2_t, "TOP" }
    elseif pie.active and pie_even and AngleInRange(DRAG_ANGLE, ap2_b, ap1_b) then
        inside = { ap2_b, ap1_b, "BOT" }
    elseif pie.active and AngleInRange(DRAG_ANGLE, ap2_t, pie_even and ap1_b or ap_c) then
        inside = { ap2_t, ap2_b, "LEFT" }
        CUR_HOR = "LEFT"
    elseif pie.active and AngleInRange(DRAG_ANGLE, pie_even and ap1_b or ap_c, ap1_t) then
        inside = { ap1_b, ap1_t, "RIGHT" }
        CUR_HOR = "RIGHT"
    end

    local closest_tbl = {}
    local LAST_HOR_SEL
    for i = 1, #pie do
        local angle = item_arc_span * i

        local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, pie[i].name)
        txt_w = txt_w + 50
        local button_pos = {
            x = CENTER.x + (RADIUS_MIN + ((RADIUS - RADIUS_MIN) / 1.6) * MAIN_PROG) * cos(angle + START_ANG),
            y = CENTER.y + (RADIUS_MIN + ((RADIUS - RADIUS_MIN) / 1.6) * MAIN_PROG) * sin(angle + START_ANG),
        }

        if RoughlyEquals(angle % pi, 0) then
            button_pos.x = button_pos.x - txt_w / 2
            if i == #pie then
                button_pos.y = button_pos.y - (txt_h * 2.2)
            else
                button_pos.y = button_pos.y + txt_h
            end
        else
            button_pos.y = button_pos.y - 25 // 2
            if angle > pi then
                button_pos.x = button_pos.x - txt_w
            end
        end
        local boundry_hovered

        if not SETUP then
            r.ImGui_SetCursorScreenPos(ctx, button_pos.x, button_pos.y)
            r.ImGui_PushID(ctx, "pie_btn" .. i)
            r.ImGui_InvisibleButton(ctx, pie[i].name, txt_w, 25)
            r.ImGui_PopID(ctx)
        else
            r.ImGui_SetCursorScreenPos(ctx, button_pos.x, button_pos.y)
            r.ImGui_PushID(ctx, "pie_btn" .. i)
            if r.ImGui_InvisibleButton(ctx, pie[i].name, txt_w, 25) then
                if ALT then
                    REMOVE = { tbl = pie, i = i }
                else
                    pie.selected = i
                    LAST_MSG = pie[i].name
                end
            end
            boundry_hovered = r.ImGui_IsItemHovered(ctx)
            r.ImGui_PopID(ctx)
            DNDSwapSRC(pie, i)
            DNDSwapDST(pie, i, pie[i])
            if not pie[i].menu then
                DndAddTargetAction(pie, pie[i])
            else
                if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) and not ALT then
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
        if not SETUP then
            local xs, ys = r.ImGui_GetItemRectMin(ctx)
            local xe, ye = r.ImGui_GetItemRectMax(ctx)

            if inside then
                if (inside[3] == "TOP" or inside[3] == "BOT") then
                    local a_cur = atan((ys + txt_h / 2) - CENTER.y, (xs + txt_w / 2) - CENTER.x)
                    local is_in_angle = AngleInRange(a_cur, inside[1], inside[2])
                    pie.selected = is_in_angle and i
                    if is_in_angle then
                        LAST_HOR_SEL = { xs = xs, xe = xe, ys = ys, ye = ye }
                    end
                else
                    if not RoughlyEquals(angle % pi, 0) then
                        local x_pos = inside[3] == "LEFT" and xe or xs
                        local a_cur = atan((ys + txt_h / 2) - CENTER.y, (x_pos) - CENTER.x)
                        if AngleInRange(a_cur, inside[1], inside[2]) then
                            closest_tbl[#closest_tbl + 1] = { ys, i, { xs = xs, xe = xe, ys = ys, ye = ye } }
                        end
                    end
                end
            end
        end
        if (pie[i].key and r.ImGui_IsKeyReleased(ctx, pie[i].key)) then
            LAST_ACTION = i
            KEY_TRIGGER = true
        end

        if pie.selected == i and not CLOSE then
            LAST_ACTION = i
        end
        DrawClassicButton(pie[i], pie.selected == i, boundry_hovered)
    end
    -- FIND LAST CLOSEST ANGLE
    if not SETUP then
        if #closest_tbl ~= 0 then
            local near, idx = NearestValue(closest_tbl, MY)
            if near then
                pie.selected, LAST_HOR_SEL = near, closest_tbl[idx][3]
            end
        end
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)

        if inside then
            if inside[3] == "TOP" or inside[3] == "BOT" then
                if LAST_HOR_SEL then
                    local ys = inside[3] == "TOP" and LAST_HOR_SEL.ye + 15 or LAST_HOR_SEL.ys - 15
                    r.ImGui_DrawList_PathLineTo(draw_list, CENTER.x - 5, CENTER.y)
                    r.ImGui_DrawList_PathLineTo(draw_list, CENTER.x - 15, ys)
                    r.ImGui_DrawList_PathLineTo(draw_list, CENTER.x + 15, ys)
                    r.ImGui_DrawList_PathLineTo(draw_list, CENTER.x + 5, CENTER.y)
                    r.ImGui_DrawList_PathFillConvex(draw_list, ARC_COLOR)
                    r.ImGui_DrawList_PathClear(draw_list)


                    r.ImGui_DrawList_PathLineTo(draw_list, LAST_HOR_SEL.xs - 15, LAST_HOR_SEL.ys - 15)
                    r.ImGui_DrawList_PathLineTo(draw_list, LAST_HOR_SEL.xe + 15, LAST_HOR_SEL.ys - 15)
                    r.ImGui_DrawList_PathLineTo(draw_list, LAST_HOR_SEL.xe + 15, LAST_HOR_SEL.ye + 15)
                    r.ImGui_DrawList_PathLineTo(draw_list, LAST_HOR_SEL.xs - 15, LAST_HOR_SEL.ye + 15)

                    r.ImGui_DrawList_PathFillConvex(draw_list, ARC_COLOR)
                    r.ImGui_DrawList_PathClear(draw_list)
                end
            else
                if LAST_HOR_SEL then
                    local xs = inside[3] == "LEFT" and LAST_HOR_SEL.xs - 15 or LAST_HOR_SEL.xe + 15
                    local ys = inside[3] == "LEFT" and LAST_HOR_SEL.ys - 15 or LAST_HOR_SEL.ye + 15
                    local xe = inside[3] == "LEFT" and LAST_HOR_SEL.xe + 15 or LAST_HOR_SEL.xs - 15
                    local ye = inside[3] == "LEFT" and LAST_HOR_SEL.ye + 15 or LAST_HOR_SEL.ys - 15

                    r.ImGui_DrawList_PathLineTo(draw_list, xs, ys)
                    r.ImGui_DrawList_PathLineTo(draw_list, xe, ys)
                    r.ImGui_DrawList_PathLineTo(draw_list, xe, ye)
                    r.ImGui_DrawList_PathLineTo(draw_list, xs, ye)
                    r.ImGui_DrawList_PathFillConvex(draw_list, ARC_COLOR)
                    r.ImGui_DrawList_PathClear(draw_list)
                    r.ImGui_DrawList_PathLineTo(draw_list, CENTER.x, CENTER.y - 5)
                    r.ImGui_DrawList_PathLineTo(draw_list, xs, ys)
                    r.ImGui_DrawList_PathLineTo(draw_list, xs, ye)
                    r.ImGui_DrawList_PathLineTo(draw_list, CENTER.x, CENTER.y)
                    r.ImGui_DrawList_PathLineTo(draw_list, CENTER.x, CENTER.y + 5)
                    r.ImGui_DrawList_PathFillConvex(draw_list, ARC_COLOR)
                    r.ImGui_DrawList_PathClear(draw_list)
                end
            end
        end
    end
    r.ImGui_PopFont(ctx)
end

local function DrawModernStyle(pie, center)
    local CENTER = center or CENTER
    local item_arc_span = ((2 * pi) / #pie)

    local RADIUS = pie.RADIUS * CENTER_BTN_PROG
    local RADIUS_MIN = RADIUS / 2.2

    for i = 1, #pie do
        local button_wh = 25
        if pie[i].png and r.file_exists(reaper_path .. pie[i].png) then
            if not r.ImGui_ValidatePtr(pie[i].img_obj, 'ImGui_Image*') then
                pie[i].img_obj = r.ImGui_CreateImage(reaper_path .. pie[i].png)
            end
            local img_data = ImageUVOffset(pie[i].img_obj, pie[i].rescale,
                pie[i].png:find("toolbar_icons") and 3 or 1, 1, 0, 0, 0, 0, true)
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
            kx = pie[i].key and
                CENTER.x + (RADIUS_MIN + ((RADIUS - RADIUS_MIN) / 1.3) * MAIN_PROG) * cos(angle + START_ANG),
            ky = pie[i].key and
                CENTER.y - (button_wh + (pie[i].menu and 32 or 25)) -
                ((pie.selected == i and (SETUP and 5 or 15) or 0) * BUTTON_PROG) +
                (RADIUS_MIN + ((RADIUS - RADIUS_MIN) / 1.3) * MAIN_PROG) * sin(angle + START_ANG),
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
            DNDSwapSRC(pie, i)
            DNDSwapDST(pie, i, pie[i])
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

        if pie.selected and not CLOSE then
            LAST_ACTION = i
        end

        DrawArc(pie, center, item_arc_span, ang_min, ang_max, RADIUS, RADIUS_MIN)
        PieButtonDrawlist(pie[i], button_wh, (pie.selected == i), boundry_hovered, button_pos)
    end
end

local function GetMouseDelta()
    local drag_delta = { MX - CENTER.x, MY - CENTER.y }
    if r.ImGui_IsMouseDown(ctx, 0) then
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

    local tracker_state = r.GetToggleCommandState(tracker_script_id)

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
            pie.selected = nil
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
    r.ImGui_SetCursorScreenPos(ctx, CENTER.x - 6, CENTER.y + RADIUS_MIN - 23)
    if r.ImGui_InvisibleButton(ctx, "##tracker_on_off", 12, 12) then
        r.Main_OnCommand(tracker_script_id, 0)
    end
    local is_tracker_hovered = r.ImGui_IsItemHovered(ctx)
    LAST_MSG = is_tracker_hovered and (tracker_state == 1 and "TRACKER ON" or "TRACKER OFF") or LAST_MSG

    r.ImGui_SetCursorScreenPos(ctx, CENTER.x - (button_wh / 2), CENTER.y - (button_wh / 2))
    r.ImGui_InvisibleButton(ctx, "##CENTER", button_wh, button_wh)
    if SETUP and #PIE_LIST == 0 then
        r.ImGui_SetCursorScreenPos(ctx, CENTER.x - RADIUS_MIN, CENTER.y - RADIUS_MIN)
        r.ImGui_InvisibleButton(ctx, "##CENTERBoundry", (RADIUS_MIN * 2), RADIUS_MIN * 2)
        DndAddAsContext(pie)
    end
    local center_pressed = (r.ImGui_IsMouseDown(ctx, 0) and not pie.active and r.ImGui_IsWindowFocused(ctx) and not is_tracker_hovered)
    center_pressed = #PIE_LIST > 0 and center_pressed
    if center_pressed then
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 4)
        r.ImGui_DrawList_AddCircle(draw_list, CENTER.x, CENTER.y, (RADIUS_MIN - 5), 0xffffff77, 128, 24)
    end

    -- DRAW CENTER CIRCLE -------------------------------------------------
    TextSplitByWidth(LAST_MSG, button_wh, button_wh)

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
    -- TRACKER SHADOW
    r.ImGui_DrawList_AddCircleFilled(draw_list, CENTER.x, CENTER.y + RADIUS_MIN - 17,
        7 - (center_pressed and 5 or 0), LerpAlpha(0x44, CENTER_BTN_PROG), 64)
    -- TRACKER OUTER RING
    r.ImGui_DrawList_AddCircleFilled(draw_list, CENTER.x, CENTER.y + RADIUS_MIN - 17, 6.5 - (center_pressed and 5 or 0),
        LerpAlpha(def_out_ring, CENTER_BTN_PROG), 64)
    -- TRACKER ON/OFF
    r.ImGui_DrawList_AddCircleFilled(draw_list, CENTER.x, CENTER.y + RADIUS_MIN - 17, 5,
        LerpAlpha(
            tracker_state == 1 and IncreaseDecreaseBrightness(0x55f67eDD, is_tracker_hovered and 30 or 0) or
            IncreaseDecreaseBrightness(0xd31111aa, is_tracker_hovered and 30 or 0), CENTER_BTN_PROG), 64)

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
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, mini_rad + 1.5 * MAIN_PROG,
                LerpAlpha(def_out_ring, MAIN_PROG), 64)

            -- MAIN BG
            r.ImGui_DrawList_AddCircleFilled(draw_list, button_pos.x, button_pos.y, mini_rad * MAIN_PROG,
                prev_i == i and 0x23EE9cff or def_menu_prev, 64)

            -- PREVIOUS MENU POSITION HIGHLIGHT
            if prev_i == i then
                r.ImGui_DrawList_AddCircle(draw_list, button_pos.x, button_pos.y, mini_rad * MAIN_PROG, 0x25283eEE, 0, 2)
            end
        end

        if not SETUP then
            if r.ImGui_IsMouseReleased(ctx, 0) and not pie.active and not is_tracker_hovered then
                SWITCH_PIE = PIE_LIST[#PIE_LIST].pid
                table.remove(PIE_LIST, #PIE_LIST)
            end
        else
            if r.ImGui_IsMouseDoubleClicked(ctx, 0) and not pie.active and not is_tracker_hovered then
                SWITCH_PIE = PIE_LIST[#PIE_LIST].pid
                table.remove(PIE_LIST, #PIE_LIST)
            end
        end
    end
end

local function DropDownMenuPopup(pie)
    LAST_ACTION = nil
    --local SPLITTER_DD
    -- if not r.ImGui_ValidatePtr(SPLITTER_DD, 'ImGui_DrawListSplitter*') then
    --   SPLITTER_DD = r.ImGui_CreateDrawListSplitter(draw_list)
    --end
    -- r.ImGui_DrawListSplitter_Split(SPLITTER_DD, 3)
    local longest_label, longest_key, dummy_h = 0, 0, 0
    for i = 1, #pie do
        local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, pie[i].name)
        dummy_h = txt_h
        if longest_label < txt_w then
            longest_label = txt_w
        end
        if pie[i].key then
            local key_w = r.ImGui_CalcTextSize(ctx, "   -   " .. KEYS[pie[i].key])
            if longest_key < key_w then
                longest_key = key_w
            end
        end
    end

    local max_w = longest_label + longest_key
    local xx, yy = r.ImGui_GetCursorPos(ctx)
    r.ImGui_Dummy(ctx, max_w + 34, dummy_h)

    r.ImGui_SetCursorPos(ctx, xx, yy)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x3aCCffff)
    r.ImGui_SeparatorText(ctx, "\t" .. pie.name .. "\t")
    r.ImGui_PopStyleColor(ctx)
    for i = 1, #pie do
        local selected = (SETUP and (pie.selected == i)) and true
        local key_released = (pie[i].key and r.ImGui_IsKeyReleased(ctx, pie[i].key) and r.ImGui_IsWindowFocused(ctx)) and
            true
        local key_down = (pie[i].key and r.ImGui_IsKeyDown(ctx, pie[i].key) and r.ImGui_IsWindowFocused(ctx)) and true
        local key_pressed = (pie[i].key and r.ImGui_IsKeyPressed(ctx, pie[i].key) and r.ImGui_IsWindowFocused(ctx)) and
            true

        if pie[i].icon then
            r.ImGui_PushFont(ctx, ICON_FONT_VERY_SMALL)
            r.ImGui_Text(ctx, pie[i].icon)
            r.ImGui_PopFont(ctx)
            r.ImGui_SameLine(ctx, 5)
        end

        r.ImGui_SetCursorPosX(ctx, 25)
        if pie[i].col ~= 0xff then
            r.ImGui_ColorButton(ctx, "##", pie[i].col,
                r.ImGui_ColorEditFlags_NoTooltip() | r.ImGui_ColorEditFlags_NoBorder(), 5, 14)
            r.ImGui_SameLine(ctx)
        end

        -- r.ImGui_DrawList_AddRectFilled(draw_list,)

        r.ImGui_SetCursorPosX(ctx, 35)
        local sxx, syy = r.ImGui_GetCursorScreenPos(ctx)
        if (tonumber(pie[i].cmd) and GetToggleState(pie[i].cmd_name, pie[i].cmd)) then
            StateSpinner(sxx - 20, syy + 8, LerpAlpha(spinner_col, CENTER_BTN_PROG),
                2 * CENTER_BTN_PROG, true)
        end
        if SETUP and ALT then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderHovered(), 0xCC0000ff)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderActive(), 0xff0000ff)
        end

        if pie[i].menu then
            r.ImGui_PushID(ctx, pie[i].name .. i)
            if not SETUP then
                if r.ImGui_BeginMenu(ctx, pie[i].name, true) then
                    DropDownMenuPopup(pie[i])
                    r.ImGui_EndMenu(ctx)
                end
            else
                if r.ImGui_Selectable(ctx, pie[i].name, selected, r.ImGui_SelectableFlags_AllowDoubleClick()) then
                    if ALT then
                        REMOVE = { tbl = pie, i = i }
                    else
                        if r.ImGui_IsMouseDoubleClicked(ctx, 0) then
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
                        else
                            pie.selected = i
                            LAST_MSG = pie[i].name
                        end
                    end
                end
                if SETUP then
                    DNDSwapSRC(pie, i)
                    DNDSwapDST(pie, i, pie[i])
                end
                r.ImGui_SameLine(ctx, -1, max_w + 34)
                r.ImGui_PushFont(ctx, ICON_FONT_VERY_SMALL)
                r.ImGui_Text(ctx, utf8.char(146))
                r.ImGui_PopFont(ctx)
            end
            r.ImGui_PopID(ctx)
            --if key_pressed then
            if key_released then
                local menu_x, menu_y = r.ImGui_GetCursorScreenPos(ctx)
                local w, h = r.ImGui_GetItemRectSize(ctx)
                local x, y = r.ImGui_PointConvertNative(ctx, menu_x + w // 2, menu_y - h // 2)
                r.JS_Mouse_SetPosition(x, y)
            end
        else
            r.ImGui_PushID(ctx, pie[i].name .. i)
            local rv_sel = r.ImGui_Selectable(ctx, pie[i].name, SETUP and selected or key_down)
            r.ImGui_PopID(ctx)
            if SETUP then
                DNDSwapSRC(pie, i)
                DNDSwapDST(pie, i, pie[i])
                DndAddTargetAction(pie, pie[i])
            end
            if (r.ImGui_IsItemHovered(ctx) or key_released) and not SETUP then
                LAST_ACTION = pie[i]
            end
            if (rv_sel or key_released) and not SETUP then
                DROP_DOWN_CONFIRM = true
            end
        end

        if SETUP then
            if ALT then
                r.ImGui_PopStyleColor(ctx, 2)
            end
            if not pie[i].menu then
                DndAddTargetAction(pie, pie[i])
            end
            if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 0) then
                if ALT then
                    REMOVE = { tbl = pie, i = i }
                else
                    pie.selected = i
                    LAST_MSG = pie[i].name
                end
            end
        end

        if pie[i].key then
            local txt_w = r.ImGui_CalcTextSize(ctx, pie[i].name)
            r.ImGui_SameLine(ctx, txt_w + 30)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x3aCCffff)
            r.ImGui_Selectable(ctx, "   - " .. KEYS[pie[i].key], false)
            r.ImGui_PopStyleColor(ctx)
            if r.ImGui_IsKeyReleased(ctx, pie[i].key) and r.ImGui_IsWindowFocused(ctx) then
                LAST_ACTION = pie[i]
                KEY_TRIGGER = true
            end
        end
    end
    --r.ImGui_DrawListSplitter_Merge(SPLITTER_DD)
end

local pad_x_sel, pad_y_sel = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
local pad_x_sep, pad_y_sep = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_SeparatorTextPadding())
local sep_boarder = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_SeparatorTextBorderSize())
local wnd_padding = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())
local item_s_x, item_s_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
local function OpenDropDownStyle(pie)
    if SETUP then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x44)
    else
        r.ImGui_PushFont(ctx, GUI_FONT)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0xdd)
    end

    local font_size = r.ImGui_GetFontSize(ctx)
    local longest_label, longest_key = 0, 0
    for i = 1, #pie do
        local txt_w = r.ImGui_CalcTextSize(ctx, pie[i].name)
        if longest_label < txt_w then
            longest_label = txt_w
        end
        if pie[i].key then
            local key_w = r.ImGui_CalcTextSize(ctx, "   -   " .. KEYS[pie[i].key])
            if longest_key < key_w then
                longest_key = key_w
            end
        end
    end

    local max_w = (longest_label + longest_key) < 100 and 100 or (longest_label + longest_key)
    local txt_separator_h = max(font_size + (pad_y_sep * 2) + sep_boarder)
    local xx, yy = r.ImGui_GetCursorScreenPos(ctx)
    if SETUP then
        r.ImGui_SetNextWindowPos(ctx, CENTER.x - (max_w + 50) // 2, yy)
    else
        r.ImGui_SetNextWindowPos(ctx, START_X - 80, START_Y - 10)
        if r.ImGui_IsWindowAppearing(ctx) then
            r.ImGui_SetNextWindowFocus(ctx)
        end
    end
    if wnd_hovered then
        if LAST_ACTION then LAST_ACTION = nil end
    end
    if r.ImGui_BeginChild(ctx, "DropDownSetup", max_w + 50, txt_separator_h + (#pie * font_size) + (wnd_padding * 2) + item_s_y * (#pie), true) then
        local tracker_state = r.GetToggleCommandState(tracker_script_id)
        local prev_x, prev_y = r.ImGui_GetCursorPos(ctx)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), tracker_state == 1 and 0x00ff00cc or 0xff0000cc)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), tracker_state == 1 and 0x00ff00dd or 0xff0000dd)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), tracker_state == 1 and 0x00ff00ff or 0xff0000ff)
        r.ImGui_SetCursorPos(ctx, 26, 14)
        if r.ImGui_Button(ctx, "##", 10, 10) then
            r.Main_OnCommand(tracker_script_id, 0)
        end
        r.ImGui_PopStyleColor(ctx, 3)
        r.ImGui_SetCursorPos(ctx, prev_x, prev_y)
        if r.ImGui_IsItemHovered(ctx) then
            if r.ImGui_BeginTooltip(ctx) then
                r.ImGui_Text(ctx, (tracker_state == 1 and "TRACKER ON" or "TRACKER OFF"))
                r.ImGui_EndTooltip(ctx)
            end
        end
        DropDownMenuPopup(pie)
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
    if not SETUP then
        r.ImGui_PopFont(ctx)
    end
end

function DrawPie(pie, center)
    -- DRAW GUIDELINE WHERE MOUSE WAS BEFORE GUI WAS ADJUSTED TO BE IN THE SCREEN (ON EDGES)
    if OUT_SCREEN then
        r.ImGui_DrawList_AddLine(draw_list, PREV_X, PREV_Y, START_X, START_Y, dark_theme and 0x40ffb3aa or 0xff0000ff, 5)
    end
    GetMouseDelta()
    if not r.ImGui_ValidatePtr(SPLITTER, "ImGui_DrawListSplitter*") then
        SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    end
    r.ImGui_DrawListSplitter_Split(SPLITTER, 5)
    if STYLE ~= 3 then
        DrawCenter(pie, center)
    end
    if STYLE == 1 then
        DrawModernStyle(pie, center)
    elseif STYLE == 2 then
        DrawButtonTextStyle(pie, center)
    elseif STYLE == 3 then
        OpenDropDownStyle(pie)
    end
    r.ImGui_DrawListSplitter_Merge(SPLITTER)

    if r.ImGui_IsMouseReleased(ctx, 0) then
        if CX then
            CX, CY = nil, nil
            CUR_POS_DELTA, CUR_DRAG_DIST = nil, nil
        end
    end
end
