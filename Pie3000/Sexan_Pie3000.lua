-- @description Sexan PieMenu 3000
-- @author Sexan
-- @license GPL v3
-- @version 0.32.84
-- @changelog
--  Fix Crash on Empty items
--  Option to open as DropDownMenu
-- @provides
--   [main=main,midi_editor] .
--   [main=main,midi_editor] Sexan_Pie3000_Setup.lua
--   easing.lua
--   Common.lua
--   PieUtils.lua
--   fontello1.ttf
--   Roboto-Medium.ttf
--   [main] Sexan_PieCleanFiles.lua
local r = reaper
local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

local sqrt, sin, cos = math.sqrt, math.sin, math.cos

require('PieUtils')
if CheckDeps() then return end

ctx = r.ImGui_CreateContext('Pie XYZ', r.ImGui_ConfigFlags_NoSavedSettings())

require('Common')
if DROP_DOWN_MENU then
    ANIMATION = false
    ADJUST_PIE_NEAR_EDGE = false
    SWIPE = false
end

MAIN_PROG = ANIMATION and 0.01 or 1
CENTER_BTN_PROG = ANIMATION and 0.01 or 1
BUTTON_PROG = ANIMATION and 0.01 or 1

DeferLoop = DBG and DEBUG.defer or PDefer

PIE_LIST = {}

local function GetMonitorFromPoint()
    local x, y = r.GetMousePosition()
    LEFT, TOP, RIGHT, BOT = r.my_getViewport(x, y, x, y, x, y, x, y, true)
end

local function Init()
    SCRIPT_START_TIME = r.time_precise()

    START_TIME = r.time_precise()
    ALLOW_KB_VAR = r.SNM_GetIntConfigVar("alwaysallowkb", 1)
    START_X, START_Y = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
    GetMonitorFromPoint()
    CENTER = { x = START_X, y = START_Y }

    PIES = ReadFromFile(pie_file)
    MIDI_PIES = ReadFromFile(midi_cc_file)
    if not PIES then
        local setup_script = r.NamedCommandLookup("_RS3ad3111ef0e763a1cb125b100b70bc3e50072453")
        r.Main_OnCommand(setup_script, 0)
        return "ERROR"
    end

    for k, v in pairs(PIES) do
        if v.sync then
            PIES[k .. "empty"] = PIES[k]
        end
    end
    local key_state = r.JS_VKeys_GetState(SCRIPT_START_TIME - 1)
    local down_state = r.JS_VKeys_GetDown(SCRIPT_START_TIME)
    for i = 1, 255 do
        if key_state:byte(i) ~= 0 or down_state:byte(i) ~= 0 then
            r.JS_VKeys_Intercept(i, 1)
            KEY = i
            break
        end
    end
    if not KEY then return "ERROR" end
    r.SNM_SetIntConfigVar("alwaysallowkb", 1)
end

if Init() == "ERROR" then return end

local WND_IDS = {
    { id = "3E9", name = "midiview" },
    { id = "3EB", name = "midipianoview" },
    { id = "3E8", name = "REAPERTrackListWindow" },
    { id = "3ED", name = "REAPERTimeDisplay" },

}

local function GetMouseContext()
    local x, y = r.GetMousePosition()
    local track, info = r.GetThingFromPoint(x, y)
    local item, take = r.GetItemFromPoint(x, y, true)
    local cur_hwnd = r.JS_Window_FromPoint(x, y)
    local id = r.JS_Window_GetLongPtr(cur_hwnd, "ID")
    local class_name = r.JS_Window_GetClassName(cur_hwnd)

    -- local is_plugin --= DetectPluginContext(cur_hwnd)
    if info:match("spacer") then return end
    if info:match("master") then return end

    if info:match("envelope") then
        info = "envelope"
    elseif info:match("envcp") then
        info = "envcp"
    elseif info:match("^fx_") then
        info = "plugin"
    end

    if #info == 0 then
        if class_name == "REAPERTCPDisplay" then
            info = "tcpempty"
        elseif class_name == "REAPERMCPDisplay" then
            info = "mcpempty"
        elseif tostring(id):upper():match(WND_IDS[3].id) then
            info = "arrangeempty"
        elseif tostring(id):upper():match(WND_IDS[1].id) then
            -- r.ShowConsoleMsg(tostring(id) .. "\n")
            info = DetectMIDIContext()
        elseif tostring(id):upper():match(WND_IDS[4].id) then
            info = "ruler"
        end
    end

    if item then
        if take then
            info = r.TakeIsMIDI(take) and "itemmidi" or "item"
        else
            info = "item"
        end
    end
    if info then
        info = info:match('^([^%.]+)')
        return info, track, item
    end
end

local INFO, TRACK, ITEM = GetMouseContext()

if not INFO then
    Release()
    return
end

if not STANDALONE_PIE then
    if MIDI_LANE_CONTEXT then
        if PIES["midilane"].as_global == true then
            PIE_MENU = PIES["midilane"]
        else
            -- OPEN DEFAULT MENU IF DOES NOT EXIST
            PIE_MENU = MIDI_PIES[INFO] or PIES["midilane"]
        end
    else
        PIE_MENU = PIES[INFO]
    end
else
    PIE_MENU = STANDALONE_PIE
end

--if INFO == "midilane" then LANE_NAME = "global" end

--PIE_MENU = STANDALONE_PIE or (MIDI_LANE_CONTEXT and MIDI_PIES[INFO] or PIES[INFO])
--PIE_MENU = STANDALONE_PIE or (MIDI_LANE_CONTEXT and MIDI_PIES[INFO] or PIES[INFO])
if not PIE_MENU then
    Release()
    return
end

--if LANE_NAME then
-- PIE_MENU.name = LANE_NAME:upper()
--end

local function ConvertAndSetCursor(x, y)
    local mouse_x, mouse_y = r.ImGui_PointConvertNative(ctx, x, y, true)
    r.JS_Mouse_SetPosition(mouse_x, mouse_y)
end

if SELECT_THING_UNDER_MOUSE then
    if ITEM then
        r.Main_OnCommand(40289, 0) -- DESELECT ALL ITEMS
        r.SetMediaItemSelected(ITEM, true)
        r.UpdateArrange()
    end
    if TRACK then
        r.SetOnlyTrackSelected(TRACK)
    end
end

local function NearEdge()
    PREV_X, PREV_Y = START_X, START_Y

    local len = ((PIE_MENU.RADIUS / sqrt(2)) * 2) // 1
    if START_X - len < LEFT then
        START_X = LEFT + len
        OUT_SCREEN = true
    end
    if START_X + len > RIGHT then
        START_X = RIGHT - len
        OUT_SCREEN = true
    end
    if START_Y - len < TOP then
        START_Y = TOP + len
        OUT_SCREEN = true
    end
    if START_Y + len > BOT then
        START_Y = BOT - len
        OUT_SCREEN = true
    end

    if OUT_SCREEN then
        ConvertAndSetCursor(START_X, START_Y)
        CENTER = { x = START_X, y = START_Y }
    end
end

if ADJUST_PIE_NEAR_EDGE then NearEdge() end

local function KeyHeld()
    return r.JS_VKeys_GetState(SCRIPT_START_TIME - 1):byte(KEY) == 1
end

local function LimitMouseToRadius()
    local MOUSE_RANGE = ((PIE_MENU.RADIUS / sqrt(2)) * 2) // 1 --PIE_MENU.RADIUS * 2

    if DRAG_DIST > (MOUSE_RANGE ^ 2) then
        MX = (START_X + (MOUSE_RANGE) * cos(DRAG_ANGLE)) // 1
        MY = (START_Y + (MOUSE_RANGE) * sin(DRAG_ANGLE)) // 1
        ConvertAndSetCursor(MX, MY)
        --r.JS_Mouse_SetPosition(MX, MY)
    end
end

local FLAGS =
    r.ImGui_WindowFlags_NoBackground() |
    r.ImGui_WindowFlags_NoDecoration() |
    r.ImGui_WindowFlags_NoMove()

local function DoFullScreen()
    r.ImGui_SetNextWindowPos(ctx, LEFT, TOP)
    r.ImGui_SetNextWindowSize(ctx, RIGHT - LEFT, BOT - TOP)
    VP_CENTER = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
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

local function AnimationProgress()
    if CLOSE then
        MAIN_PROG = EasingAnimation(MAIN_PROG, 0.01, 0.3, easingFunctions.inOutCubic, START_TIME)
        CENTER_BTN_PROG = MAIN_PROG
        if MAIN_PROG < 0.1 then DONE = true end
    else
        CENTER_BTN_PROG = EasingAnimation(0, 1, 0.3, easingFunctions.inOutCubic, SCRIPT_START_TIME)
        MAIN_PROG = EasingAnimation(0, 1, 0.3, easingFunctions.outCubic, START_TIME)
        if BUTTON_HOVER_TIME then
            BUTTON_PROG = EasingAnimation(0, 1, 0.15, easingFunctions.outCubic, BUTTON_HOVER_TIME)
        end
    end
end


local MAIN_HWND = r.GetMainHwnd()
local function ExecuteAction(action)
    if action then
        if CLOSE and ACTIVATE_ON_CLOSE then
            if LAST_TRIGGERED ~= action then
                LAST_TRIGGERED = action
                if PIE_MENU.is_midi then
                    r.MIDIEditor_OnCommand(r.MIDIEditor_GetActive(), action)
                else
                    r.Main_OnCommand(action, 0)
                end
            end
        end
        if r.ImGui_IsMouseReleased(ctx, 0) then
            local START_ACTION_TIME = r.time_precise()
            LAST_TRIGGERED = action
            if PIE_MENU.is_midi then
                r.MIDIEditor_OnCommand(r.MIDIEditor_GetActive(), action)
            else
                r.Main_OnCommand(action, 0)
            end
            local AFTER_ACTION_TIME = r.time_precise()

            if AFTER_ACTION_TIME - START_ACTION_TIME > 0.1 then
                r.JS_WindowMessage_Post(MAIN_HWND, "WM_KEYUP", KEY, 0, 0, 0)
            end
            if not HOLD_TO_OPEN then
                if CLOSE_ON_ACTIVATE then
                    DONE = true
                end
            end
        elseif KEY_TRIGGER then
            LAST_TRIGGERED = action
            if PIES[INFO].name == "MIDI" then
                r.MIDIEditor_OnCommand(r.MIDIEditor_GetActive(), action)
            else
                r.Main_OnCommand(action, 0)
            end
            KEY_TRIGGER = nil
            if not HOLD_TO_OPEN then
                if CLOSE_ON_ACTIVATE then
                    DONE = true
                end
            end
        end
    end
end

local function DoAction()
    if PIE_MENU[LAST_ACTION].menu then
        if r.ImGui_IsMouseReleased(ctx, 0) or Swipe() or KEY_TRIGGER then
            table.insert(PIE_LIST, {
                col = PIE_MENU[LAST_ACTION].col,
                icon = PIE_MENU[LAST_ACTION].icon,
                name = PIE_MENU[LAST_ACTION].name,
                pid = PIE_MENU,
                prev_i = LAST_ACTION,
            })
            KEY_TRIGGER = nil
            SWITCH_PIE = PIE_MENU[LAST_ACTION]
        end
    else
        ExecuteAction(PIE_MENU[LAST_ACTION].cmd)
    end
end


local function Main()
    TrackShortcutKey()
    if TERMINATE then
        Release()
        return
    end

    if SWITCH_PIE and not CLOSE then
        if ANIMATION then
            MAIN_PROG = 0.01
            BUTTON_PROG = 0.01
        end
        LAST_ACTION = nil
        START_TIME = r.time_precise()
        PIE_MENU = SWITCH_PIE
        if RESET_POSITION then
            ConvertAndSetCursor(START_X, START_Y)
        end
        SWITCH_PIE = nil
        RefreshImgObj(PIE_MENU)
    end
    if LAST_ACTION then DoAction() end
    DoFullScreen()

    if r.ImGui_Begin(ctx, 'PIE XYZ', false, FLAGS) then
        draw_list = r.ImGui_GetWindowDrawList(ctx)
        MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
        CheckKeys()
        DrawPie(PIE_MENU)
        if ANIMATION then AnimationProgress() end
        if LIMIT_MOUSE then LimitMouseToRadius() end
        r.ImGui_End(ctx)
    end
    if not DONE then
        DeferLoop(Main)
    end

    if DONE then
        if REVERT_TO_START then
            local org_mouse_x, org_mouse_y = OUT_SCREEN and PREV_X or START_X, OUT_SCREEN and PREV_Y or START_Y
            ConvertAndSetCursor(org_mouse_x, org_mouse_y)
        end
    end
end

r.atexit(Release)
DeferLoop(Main)
