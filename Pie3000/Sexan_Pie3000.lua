-- @description Sexan PieMenu 3000
-- @author Sexan
-- @license GPL v3
-- @version 0.35.59
-- @changelog
--  Check for null when deleting menu
-- @provides
--   [main=main,midi_editor] .
--   [main=main,midi_editor] Sexan_Pie3000_Setup.lua
--   [main] Sexan_Pie3000_Tracker_BG.lua
--   CustomImages/*.txt
--   easing.lua
--   Common.lua
--   PieUtils.lua
--   fontello1.ttf
--   Roboto-Medium.ttf
--   [main] Sexan_PieCleanFiles.lua

local r = reaper
local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" .. package.path -- GET DIRECTORY FOR REQUIRE
local sqrt, sin, cos = math.sqrt, math.sin, math.cos

require('PieUtils')
if CheckDeps() then return end

ctx = r.ImGui_CreateContext('Pie 3000', r.ImGui_ConfigFlags_NoSavedSettings())

require('Common')
if STYLE == 3 then
    --HOLD_TO_OPEN = false
    ANIMATION = false
    -- ADJUST_PIE_NEAR_EDGE = false
    SWIPE = false
    LIMIT_MOUSE = false
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
local ACTIONS, ACTIONS_PAIRS                                                                                     = GetMainActions()
local MIDI_ACTIONS, INLINE_ACTIONS, EVENT_ACTIONS, MIDI_ACTIONS_PAIRS, INLINE_ACTIONS_PAIRS, EVENT_ACTIONS_PAIRS =
    GetMidiActions()
local EXPLORER_ACTIONS, EXPLORER_ACTIONS_PAIRS                                                                   = GetExplorerActions()

local PIES, MIDI_PIES

local function Init()
    SCRIPT_START_TIME = r.time_precise()

    START_TIME = r.time_precise()
    ALLOW_KB_VAR = r.SNM_GetIntConfigVar("alwaysallowkb", 1)
    START_X, START_Y = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
    GetMonitorFromPoint()
    CENTER = { x = START_X, y = START_Y }

    PIES = ReadFromFile(pie_file)
    MIDI_PIES = ReadFromFile(midi_cc_file)

    if not PIES or not MIDI_PIES then
        local setup_script = r.NamedCommandLookup("_RS3ad3111ef0e763a1cb125b100b70bc3e50072453")
        r.Main_OnCommand(setup_script, 0)
        return "ERROR"
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
    -- { id = "3E9", name = "midiview" },
    -- { id = "3EB", name = "midipianoview" },
    { id = "3E8", name = "REAPERTrackListWindow" },
    { id = "3ED", name = "REAPERTimeDisplay" },
}

local function GetMouseContext()
    local active_midi = r.MIDIEditor_GetActive()
    local main_wnd = r.GetMainHwnd()
    local x, y = r.GetMousePosition()
    local track, info = r.GetThingFromPoint(x, y)
    local item, take = r.GetItemFromPoint(x, y, true)
    local cur_hwnd = r.JS_Window_FromPoint(x, y)
    local parent = r.JS_Window_GetParent(cur_hwnd)
    local title = r.JS_Window_GetTitle(cur_hwnd)
    local parent_title = r.JS_Window_GetTitle(parent)
    local id = r.JS_Window_GetLongPtr(cur_hwnd, "ID")
    local class_name = r.JS_Window_GetClassName(cur_hwnd)
    local master_track = r.GetMasterTrack(0)

    if info:match("spacer") then
        info = "spacer"
    end
    if info:match("master") then return end

    if info:match("envelope") then
        ENVELOPE_LANE = "lane"
        info, ENV = DetectEnvContext(track, info)
    elseif info:match("envcp") then
        ENVELOPE_LANE = "cp"
        info, ENV = DetectEnvContext(track, info, true)
    elseif info:match("^fx_") then
        RETURN_FOCUS = cur_hwnd
        info = "plugin"
    elseif info:match("^mcp") then
        if info:match("fxlist") then
            info = "mcpfxlist"
        elseif info:match("sendlist") then
            info = "mcpsendlist"
        else
            info = "mcp"
        end
        if track == master_track then
            info = "master" .. info
        end
    elseif info:match("^tcp") then
        if info:match("fxparm") then
            info = "tcpfxparm"
        else
            info = "tcp"
        end
        if track == master_track then
            info = "master" .. info
        end
    end

    if #info == 0 then
        if class_name == "REAPERTCPDisplay" then
            info = "tcpempty"
        elseif class_name == "REAPERMCPDisplay" then
            info = "mcpempty"
        elseif parent == active_midi then
            r.JS_Window_SetFocus(active_midi)
            info = DetectMIDIContext()
            RETURN_FOCUS = active_midi
        elseif parent_title == "Media Explorer" then
            info, RETURN_FOCUS = DetectMediaExplorer(parent)
        elseif tostring(id):upper():match(WND_IDS[1].id) then
            info = "arrangeempty"
        elseif tostring(id):upper():match(WND_IDS[2].id) then
            local window, segment, details = r.BR_GetMouseCursorContext()
            return segment ~= "timeline" and "ruler" .. segment or "ruler"
        end
    end

    if item then
        if take then
            info = r.TakeIsMIDI(take) and "itemmidi" or "item"
        else
            info = "item"
        end
    end

    if info and #info == 0 and CUSTOM_SCRIPT_CONTEXT then
        info = title
    end
    --r.ShowConsoleMsg(tostring(info) .. "\n")
    -- if CUSTOM_SCRIPT_CONTEXT and CUSTOM_SCRIPT_CONTEXT == title then
    --     info = CUSTOM_SCRIPT_CONTEXT
    -- end
    if info then
        info = info:match('^([^%.]+)')
        return info, track, item
    end
end

local status, err = xpcall(function() INFO, TRACK, ITEM = GetMouseContext() end, debug.traceback)
if not status then
    PrintTraceback(err)
    Release()
end

if not INFO then
    Release()
    return
end

if not STANDALONE_PIE then
    if MIDI_LANE_CONTEXT then
        if MIDI_LANE_CONTEXT == "lane" then
            if PIES["midilane"].as_global == true then
                PIE_MENU = PIES["midilane"]
            else
                PIE_MENU = MIDI_PIES[INFO] or PIES["midilane"]
            end
        end
    elseif ENVELOPE_LANE then
        if ENVELOPE_LANE == "lane" then
            if PIES["envelope"].as_global == true then
                PIE_MENU = PIES["envelope"]
            else
                PIE_MENU = PIES[INFO] or PIES["envelope"] -- open default for all others (vst etc)
            end
        elseif ENVELOPE_LANE == "cp" then
            if PIES["envcp"].as_global == true then
                PIE_MENU = PIES["envcp"]
            elseif PIES["envcp"].use_main == true then
                PIE_MENU = PIES[INFO:sub(4)]
            else
                PIE_MENU = PIES[INFO] or PIES["envcp"] -- open default for all others (vst etc)
            end
        end
    else
        PIE_MENU = PIES[INFO]
    end
else
    PIE_MENU = STANDALONE_PIE
    -- if CUSTOM_SCRIPT_CONTEXT then
    --    INFO = CUSTOM_SCRIPT_CONTEXT
    --else
    if MIDI_LANE_CONTEXT then
        INFO = "midilane"
    elseif ENVELOPE_LANE then
        if ENVELOPE_LANE == "lane" then
            INFO = "envelope"
        elseif ENVELOPE_LANE == "cp" then
            INFO = "envcp"
        end
    end
    --end
end

if not PIE_MENU then
    Release()
    return
end
if PIE_MENU.use_main then
    PIE_MENU = PIES[PIE_MENU.main_name]
end

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
    if ENV then
        r.SetCursorContext(2, ENV)
        r.UpdateArrange()
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
    local MOUSE_RANGE = ((PIE_MENU.RADIUS / sqrt(2)) * 2) // 1

    if DRAG_DIST > (MOUSE_RANGE ^ 2) then
        MX = (START_X + (MOUSE_RANGE) * cos(DRAG_ANGLE)) // 1
        MY = (START_Y + (MOUSE_RANGE) * sin(DRAG_ANGLE)) // 1
        ConvertAndSetCursor(MX, MY)
    end
end

local FLAGS =
-- r.ImGui_WindowFlags_NoBackground() |
    r.ImGui_WindowFlags_NoDecoration() |
    r.ImGui_WindowFlags_NoMove() --|
   -- r.ImGui_WindowFlags_TopMost()

if not MIDI_TRACE_DEBUG then
    FLAGS = FLAGS | r.ImGui_WindowFlags_NoBackground()
end

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
        if STYLE == 3 then
            if wnd_hovered and r.ImGui_IsMouseClicked(ctx, 0) then
                CloseScript()
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

local function FindAction(name, no_warning)
    if not STANDALONE_PIE then
        if (PIES[INFO] and PIES[INFO].is_midi) or MIDI_LANE_CONTEXT then
            if MIDI_ACTIONS_PAIRS[name] then
                return tonumber(MIDI_ACTIONS_PAIRS[name].cmd), MIDI_ACTIONS_PAIRS[name].type
            end
            if INLINE_ACTIONS_PAIRS[name] then
                return tonumber(INLINE_ACTIONS_PAIRS[name].cmd), INLINE_ACTIONS_PAIRS[name].type
            end

            if EVENT_ACTIONS_PAIRS[name] then
                return tonumber(EVENT_ACTIONS_PAIRS[name].cmd), EVENT_ACTIONS_PAIRS[name].type
            end
        elseif (PIES[INFO] and PIES[INFO].is_explorer) then
            if EXPLORER_ACTIONS_PAIRS[name] then
                return tonumber(EXPLORER_ACTIONS_PAIRS[name].cmd), EXPLORER_ACTIONS_PAIRS[name].type
            end
        else
            if ACTIONS_PAIRS[name] then
                return tonumber(ACTIONS_PAIRS[name].cmd), ACTIONS_PAIRS[name].type
            end
        end
        if not no_warning then
            r.ShowMessageBox(name .. "\nIs not for this Context or does not Exist", "WARNING", 0)
        else
            ACTION_CONTEXT_WARNING = true
        end
    else
        if INFO:match("^midi") or INFO:match("pianoroll") or MIDI_LANE_CONTEXT then
            if MIDI_ACTIONS_PAIRS[name] then
                return tonumber(MIDI_ACTIONS_PAIRS[name].cmd), MIDI_ACTIONS_PAIRS[name].type
            end
            if INLINE_ACTIONS_PAIRS[name] then
                return tonumber(INLINE_ACTIONS_PAIRS[name].cmd), INLINE_ACTIONS_PAIRS[name].type
            end

            if EVENT_ACTIONS_PAIRS[name] then
                return tonumber(EVENT_ACTIONS_PAIRS[name].cmd), EVENT_ACTIONS_PAIRS[name].type
            end
        elseif INFO:match("mediaexplorer") then
            if EXPLORER_ACTIONS_PAIRS[name] then
                return tonumber(EXPLORER_ACTIONS_PAIRS[name].cmd), EXPLORER_ACTIONS_PAIRS[name].type
            end
        else
            if ACTIONS_PAIRS[name] then
                return tonumber(ACTIONS_PAIRS[name].cmd), ACTIONS_PAIRS[name].type
            end
        end
        if not no_warning then
            r.ShowMessageBox(name .. "\nIs not for this Context or does not Exist", "WARNING", 0)
        else
            ACTION_CONTEXT_WARNING = true
        end
    end
end

local function CheckActionContext(name)
    if STYLE ~= 3 then
        if PREV_ACTION ~= PIE_MENU[LAST_ACTION] then
            ACTION_CONTEXT_WARNING = nil
            FindAction(name, true)
            PREV_ACTION = PIE_MENU[LAST_ACTION]
        end
    else
        if PREV_ACTION ~= name then
            ACTION_CONTEXT_WARNING = nil
            FindAction(name, true)
            PREV_ACTION = name
        end
    end

    if ACTION_CONTEXT_WARNING then
        if r.ImGui_BeginTooltip(ctx) then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xff0000ff)
            r.ImGui_Text(ctx, "ACTION BELONGS TO DIFFERENT CONTEXT OR DOESN'T EXIST")
            r.ImGui_PopStyleColor(ctx)
            r.ImGui_EndTooltip(ctx)
        end
    end
end


local MAIN_HWND = r.GetMainHwnd()
local function ExecuteAction(action_tbl)
    local action = action_tbl.cmd_name
    local pie_func = action_tbl.func
    if pie_func then
        if CLOSE and ACTIVATE_ON_CLOSE then
            if LAST_TRIGGERED ~= pie_func then
                LAST_TRIGGERED = pie_func
                _G[pie_func](action_tbl)
            end
        end
        if r.ImGui_IsMouseReleased(ctx, 0) then
            local START_ACTION_TIME = r.time_precise()
            LAST_TRIGGERED = pie_func
            _G[pie_func](action_tbl)
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
            LAST_TRIGGERED = pie_func
            _G[pie_func](action_tbl)
            KEY_TRIGGER = nil
            if not HOLD_TO_OPEN then
                if CLOSE_ON_ACTIVATE then
                    DONE = true
                end
            end
        end
    else
        if action then
            CheckActionContext(action)
            --if STYLE == 3 and DROP_DOWN_CONFIRM then
            --    TERMINATE = true
            --end
            if CLOSE and ACTIVATE_ON_CLOSE then
                if LAST_TRIGGERED ~= action then
                    LAST_TRIGGERED = action
                    local cmd_id = FindAction(action)
                    if (PIES[INFO] and PIES[INFO].is_midi) or MIDI_LANE_CONTEXT then
                        if cmd_id then
                            r.MIDIEditor_OnCommand(r.MIDIEditor_GetActive(), cmd_id)
                        end
                    else
                        if cmd_id then
                            if PIES[INFO].is_explorer then
                                r.JS_WindowMessage_Send(RETURN_FOCUS, "WM_COMMAND", cmd_id, 0, 0, 0)
                            else
                                r.Main_OnCommand(cmd_id, 0)
                            end
                        end
                    end
                end
            end
            if r.ImGui_IsMouseReleased(ctx, 0) then
                local START_ACTION_TIME = r.time_precise()
                LAST_TRIGGERED = action
                local cmd_id = FindAction(action)
                if (PIES[INFO] and PIES[INFO].is_midi) or MIDI_LANE_CONTEXT then
                    if cmd_id then
                        r.MIDIEditor_OnCommand(r.MIDIEditor_GetActive(), cmd_id)
                    end
                else
                    if cmd_id then
                        if PIES[INFO].is_explorer then
                            r.JS_WindowMessage_Send(RETURN_FOCUS, "WM_COMMAND", cmd_id, 0, 0, 0)
                        else
                            r.Main_OnCommand(cmd_id, 0)
                        end
                    end
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
                local cmd_id = FindAction(action)

                if PIES[INFO].name == "MIDI" then
                    if cmd_id then
                        r.MIDIEditor_OnCommand(r.MIDIEditor_GetActive(), cmd_id)
                    end
                else
                    if cmd_id then
                        if PIES[INFO].is_explorer then
                            r.JS_WindowMessage_Send(RETURN_FOCUS, "WM_COMMAND", cmd_id, 0, 0, 0)
                        else
                            r.Main_OnCommand(cmd_id, 0)
                        end
                    end
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
end

local function DoAction()
    if STYLE ~= 3 and PIE_MENU[LAST_ACTION].menu then
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
        ExecuteAction(STYLE == 3 and LAST_ACTION or PIE_MENU[LAST_ACTION])
    end
end
r.set_action_options(4)
local function Main()
    TrackShortcutKey()
    if TERMINATE then
        Release()
        return
    end

    --r.ShowConsoleMsg(CONTEXT_LIMIT .. " - " .. INFO .. "\n")

    if CONTEXT_LIMIT and not INFO:match(CONTEXT_LIMIT) then
        Release()
        r.ShowConsoleMsg("Pie works under " .. CONTEXT_LIMIT:upper() .. " context only.\n")
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
    if KILL_ON_ESC and ESC then DONE = true end
    --r.ShowConsoleMsg(tostring(DONE) .. "\n")
    if r.ImGui_Begin(ctx, 'PIE 3000', false, FLAGS) then
        wnd_hovered = r.ImGui_IsWindowHovered(ctx, r.ImGui_HoveredFlags_RootWindow())
        draw_list = r.ImGui_GetWindowDrawList(ctx)
        MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())

        if MIDI_TRACE_DEBUG then
            DetectMIDIContext(true)
        end

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
        if RETURN_FOCUS then
            r.JS_Window_SetFocus(RETURN_FOCUS)
        end
        if REVERT_TO_START then
            local org_mouse_x, org_mouse_y = OUT_SCREEN and PREV_X or START_X, OUT_SCREEN and PREV_Y or START_Y
            ConvertAndSetCursor(org_mouse_x, org_mouse_y)
        end
    end
end
--r.set_action_options(4) -- toggle

function Exit()
    r.set_action_options(8)
    Release()
end

r.atexit(Exit)
DeferLoop(Main)
