-- @description Sexan PieMenu 3000
-- @author Sexan
-- @license GPL v3
-- @version 0.31.3
-- @changelog
--  Create ImGui window on monitor where cursor is (needs targeting any Reaper Window)
--  Tweak AdjustNearEdge function to properly work on multimonitor setup
--  Tested on Gnome (Linux)
-- @provides
--   [main] Sexan_Pie3000_Setup.lua
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

require('PieUtils')

if CheckDeps() then return end

ctx = r.ImGui_CreateContext('Pie XYZ', r.ImGui_ConfigFlags_NoSavedSettings())

require('Common')

MAIN_PROG = ANIMATION and 0.01 or 1
CENTER_BTN_PROG = ANIMATION and 0.01 or 1
BUTTON_PROG = ANIMATION and 0.01 or 1

DeferLoop = DBG and DEBUG.defer or PDefer

PIE_LIST = {}

local SCRIPT_START_TIME = r.time_precise()

local function GetMonitorFromPoint()
    local x,y = r.GetMousePosition()
    AL, AT, AR, AB = r.my_getViewport(x, y, x, y, x, y, x, y, true)
    LEFT, TOP = r.ImGui_PointConvertNative(ctx, AL, AT)
    RIGHT, BOT = r.ImGui_PointConvertNative(ctx, AR, AB)
end

local function Init()
    START_TIME = r.time_precise()
    ALLOW_KB_VAR = r.SNM_GetIntConfigVar("alwaysallowkb", 1)
    START_X, START_Y = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
    GetMonitorFromPoint()
    CENTER = { x = START_X, y = START_Y }

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
    
    local key_state = r.JS_VKeys_GetState(SCRIPT_START_TIME - 2)
    for i = 1, 255 do
        if key_state:byte(i) ~= 0 then
            r.JS_VKeys_Intercept(i, 1)
            KEY = i
            break
        end
    end
    if not KEY then return "ERROR" end
    r.SNM_SetIntConfigVar("alwaysallowkb", 1)
end

if Init() == "ERROR" then return end

local function GetMouseContext()
    local x, y = r.GetMousePosition()
    local track, info = r.GetThingFromPoint(x, y)
    local item, take = r.GetItemFromPoint(x, y, true)
    local cur_hwnd = r.JS_Window_FromPoint(x, y)
    local class_name = r.JS_Window_GetClassName(cur_hwnd)

    if info:match("spacer") then return end
    if info:match("master") then return end

    if info:match("envelope") then
        info = "envelope"
    elseif info:match("envcp") then
        info = "envcp"
    end

    if #info == 0 then
        if not class_name then return end
        if class_name == "REAPERTCPDisplay" then
            info = "tcpempty"
        elseif class_name == "REAPERMCPDisplay" then
            info = "mcpempty"
        elseif class_name == "REAPERTrackListWindow" then
            info = "arrangeempty"
        elseif class_name == "MIDIWindow" then
            info = "midi"
        elseif class_name == "REAPERTimeDisplay" then
            info = "ruler"
        end
    end

    if item then info = "item" end
    info = info:match('^([^%.]+)')
    return info, track, item
end

local INFO, TRACK, ITEM = GetMouseContext()

PIE_MENU = STANDALONE_PIE or PIES[INFO]
if not PIE_MENU then
    Release()
    return
end

if SELECT_THING_UNDER_MOUSE then
    if ITEM then
        r.Main_OnCommand(40289,0) -- DESELECT ALL ITEMS
        r.SetMediaItemSelected( ITEM, true )
        r.UpdateArrange()
    end
    if TRACK then
        r.SetOnlyTrackSelected( TRACK )
    end
end

local function NearEdge()
    PREV_X, PREV_Y = START_X, START_Y
    --local viewport        =  r.ImGui_GetWindowViewport( ctx ) --r.ImGui_GetMainViewport(ctx)
    --local getViewportPos  =  r.ImGui_Viewport_GetPos
    --local getViewportSize =  r.ImGui_Viewport_GetSize
    
    --local X, Y = getViewportPos(viewport)
    --local W, H = getViewportSize(viewport)
    local len = ((PIE_MENU.RADIUS / math.sqrt(2)) * 2)//1
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
        r.JS_Mouse_SetPosition(START_X, START_Y)
        CENTER = { x = START_X, y = START_Y }
    end
end

if ADJUST_PIE_NEAR_EDGE then NearEdge() end

local function KeyHeld()
    return r.JS_VKeys_GetState(SCRIPT_START_TIME - 1):byte(KEY) == 1
end

local FLAGS =
    r.ImGui_WindowFlags_NoBackground() |
    r.ImGui_WindowFlags_NoDecoration() |
    r.ImGui_WindowFlags_NoMove()

local function DoFullScreen()
    r.ImGui_SetNextWindowPos(ctx, LEFT, TOP)
    r.ImGui_SetNextWindowSize(ctx, RIGHT-LEFT, BOT - TOP)
    VP_CENTER = { r.ImGui_Viewport_GetCenter( r.ImGui_GetWindowViewport( ctx ) ) }
end

local function DoFullScreen2()
    local viewport        = r.ImGui_GetWindowViewport( ctx )r.ImGui_GetMainViewport(ctx)
    r.ImGui_SetNextWindowPos(ctx, r.ImGui_Viewport_GetPos(viewport))
    r.ImGui_SetNextWindowSize(ctx, r.ImGui_Viewport_GetSize(viewport))
    VP_CENTER = { r.ImGui_Viewport_GetCenter(viewport) }
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

local function ExecuteAction(action)
    if action then
        if type(action) == "string" then action = r.NamedCommandLookup(action) end
        if CLOSE and ACTIVATE_ON_CLOSE then
            if LAST_TRIGGERED ~= action then
                LAST_TRIGGERED = action
                r.Main_OnCommand(action, 0)
            end
        end
        if r.ImGui_IsMouseReleased(ctx, 0) then
            LAST_TRIGGERED = action
            r.Main_OnCommand(action, 0)
        elseif KEY_TRIGGER then
            LAST_TRIGGERED = action
            r.Main_OnCommand(action, 0)
            KEY_TRIGGER = nil
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
            r.JS_Mouse_SetPosition(START_X, START_Y)
        end
        SWITCH_PIE = nil
    end

    DoFullScreen()
    if r.ImGui_Begin(ctx, 'PIE XYZ', false, FLAGS) then
        draw_list = r.ImGui_GetWindowDrawList(ctx)
        MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
        CheckKeys()
        DrawPie(PIE_MENU)
        if ANIMATION then AnimationProgress() end
        if LIMIT_MOUSE then LimitMouseToRadius() end
        if LAST_ACTION then DoAction() end
        r.ImGui_End(ctx)
    end

    if not DONE then
        DeferLoop(Main)
    else
        if REVERT_TO_START then 
            r.JS_Mouse_SetPosition(OUT_SCREEN and PREV_X or START_X, OUT_SCREEN and PREV_Y or START_Y)
        end
    end
end

r.atexit(Release)
DeferLoop(Main)
