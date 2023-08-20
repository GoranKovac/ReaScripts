-- @description ReaSpaghetti Visual Scripter
-- @author Sexan
-- @license GPL v3
-- @version 0.36
-- @changelog
--  Code node
--  File manager modal change
--  Fix wires can be hoovered while over node
--  Initial undo script
--  Ultraschall API
--  Ultraschall parser (to fix native slowdown)
--  Optionals arguments checkbox
--  Imgui default optionals values
--  Initial Animated tooltips
-- @provides
--   api_file.txt
--   Modules/*.lua
--   Examples/*.reanodes
--   ExportedActions/dummy.lua
--   Docs/*.pdf
--   Examples/SCHWA/*.png
--   [main] Sexan_ReaSpaghetti.lua
collectgarbage("generational")

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
PATH = debug.getinfo(1).source:match("@?(.*[\\|/])")
NATIVE_SEPARATOR = package.config:sub(1, 1)

local r = reaper

local crash = function(e)
    r.ShowConsoleMsg(e .. '\n' .. debug.traceback())
end

-- IMGUI SETUP
ctx = r.ImGui_CreateContext('ReaSpaghetti')

require("Modules/Defaults")

FONT = r.ImGui_CreateFont('sans-serif', FONT_SIZE, r.ImGui_FontFlags_Bold())
FONT_STATIC = r.ImGui_CreateFont('sans-serif', FONT_SIZE_STATIC)
FONT_CODE = r.ImGui_CreateFont('monospace', FONT_SIZE, r.ImGui_FontFlags_Bold())

r.ImGui_Attach(ctx, FONT)
r.ImGui_Attach(ctx, FONT_STATIC)
r.ImGui_Attach(ctx, FONT_CODE)

r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
local WND_FLAGS = r.ImGui_WindowFlags_NoScrollbar()
    | r.ImGui_WindowFlags_NoScrollWithMouse()
    | r.ImGui_WindowFlags_MenuBar()

FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()
-- IMGUI SETUP

local profiler2 = require("Modules/profiler")
INSPECT = require("Modules/inspect")
--local profiler = require("Modules/ProFi")

if r.file_exists(r.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua") then
    dofile(r.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua")
    ULTRA_API = true
end

FLUX = require("Modules/flux")
--BEZIER = require("Modules/path2d_bezier3")
--BEZIER_HIT = require("Modules/path2d_bezier3_hit")


require("Modules/Bezier")
require("Modules/Categories")
require("Modules/APIParser")
require("Modules/UI")
require("Modules/Utils")
require("Modules/FileManager")
require("Modules/Canvas")
require("Modules/NodeDraw")
require("Modules/Library")
require("Modules/LuaCompiler")
require("Modules/Undo")
--require("Modules/ParseFlowNative")
--require("Modules/Flow")
--require("Modules/CustomFunctions")
--require("Modules/ExportToAction")
--require("Modules/NativeParser")

--if STANDALONE_RUN then return end

local old_time = r.time_precise()
local function UpdateDeltaTime()
    local now_time = r.time_precise()
    local DT = now_time - old_time
    old_time = now_time
    FLUX.update(DT)
end

local function frame()
    Top_Menu()
    if r.ImGui_BeginChild(ctx, "SideListMain", 240, 0) then
        if r.ImGui_BeginChild(ctx, "SideListChild", 0, -25, 1) then
            Sidebar()
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_SetNextItemWidth(ctx, 200)
        r.ImGui_LabelText(ctx, "##INFO", "Nodes:" .. #GetNodeTBL() .. " Selected:" .. #CntSelNodes())
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 0)
    local visible = r.ImGui_BeginChild(ctx, "Canvas", 0, 0, 1,
        r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse())
    r.ImGui_PopStyleVar(ctx)
    if visible then
        --r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), 0, 0)
        FunctionTabs()
        if r.ImGui_BeginChild(ctx, "Canvas2", 0, 0, 1, r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse()) then
            -- WE NEED TO CENTER CANVAS IN ITS WINDOW (IN ORDER TO NODE TO BE IN CENTER)
            if not CANVAS then
                CANVAS = InitCanvas()
            end
            Popups()
            CanvasLoop()
            UI_Buttons()

            r.ImGui_EndChild(ctx) -- END CANVAS2
            CheckWindowPayload()
        end
        r.ImGui_EndChild(ctx) -- END CANVAS1
    end
end

DIRTY = nil
FRAME_CNT = 0
CODE_UPDATE = false
local function loop()
    if CODE_MODIFIED then
        FRAME_CNT = FRAME_CNT + 1
        if FRAME_CNT % 33 == 0 then
            CODE_UPDATE = true
            FRAME_CNT = 0
        end
    end
    if PROFILE_DEBUG then
        PROFILE_STARTED = true
        profiler2.start()
    end

    UpdateDeltaTime()
    UpdateZoomFont()
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), 0x111111FF)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 1100, 500, FLT_MAX, FLT_MAX)
    r.ImGui_SetNextWindowSize(ctx, 1000, 800, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, 'ReaSpaghetti - ALPHA - ' .. PROJECT_NAME .. '###ReaSpaghetti', true,
        WND_FLAGS)
    r.ImGui_PopStyleColor(ctx)
    TOOLBAR_DRAG = r.ImGui_IsItemHovered(ctx)
    if visible then
        frame()
        r.ImGui_End(ctx)
    end

    if not CLOSE then
        r.defer(function() xpcall(loop, crash) end)
    end

    if not open then
        if AreFunctionsDirty() then
            NEW_WARNIGN = true
            WANT_CLOSE = true
        else
            CLOSE = true
        end
    end
    NEXT_FRAME = true
    if PROFILE_DEBUG and PROFILE_STARTED then
        profiler2.stop()
        profiler2.report(PATH .. "profiler.log")
        PROFILE_DEBUG, PROFILE_STARTED = false, nil
        OpenFile(PATH .. "profiler.log")
    end

    if not DEFERING then
        RUNNING = nil
    end

    DEFERING = nil
end
InitApi()
InitLibrary()
InitStartFunction()
r.defer(function() xpcall(loop, crash) end)
