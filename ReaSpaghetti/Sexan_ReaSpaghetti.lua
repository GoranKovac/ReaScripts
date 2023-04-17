-- @description ReaSpaghetti Visual Scripter
-- @author Sexan
-- @license GPL v3
-- @version 0.34
-- @changelog
--  Fix naming function I/O not renaming self inputs/outputs
-- @provides
--   api_file.txt
--   Modules/*.lua
--   Examples/*.reanodes
--   ExportedActions/dummy.lua
--   Docs/*.pdf
--   Examples/SCHWA/*.png
--   [main] Sexan_ReaSpaghetti.lua

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
PATH = debug.getinfo(1).source:match("@?(.*[\\|/])")
NATIVE_SEPARATOR = package.config:sub(1, 1)

local r = reaper

local crash = function(e)
    r.ShowConsoleMsg(e .. '\n' .. debug.traceback())
end

-- IMGUI SETUP
ctx = r.ImGui_CreateContext('My script')

require("Modules/Defaults")

FONT = r.ImGui_CreateFont('sans-serif', FONT_SIZE, r.ImGui_FontFlags_Bold())
FONT_STATIC = r.ImGui_CreateFont('sans-serif', FONT_SIZE_STATIC)
r.ImGui_Attach(ctx, FONT)
r.ImGui_Attach(ctx, FONT_STATIC)

r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
local WND_FLAGS = r.ImGui_WindowFlags_NoScrollbar()
    | r.ImGui_WindowFlags_NoScrollWithMouse()
    | r.ImGui_WindowFlags_MenuBar()

FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()
-- IMGUI SETUP

local profiler2 = require("Modules/profiler")
INSPECT = require("Modules/inspect")
--local profiler = require("Modules/ProFi")

FLUX = require("Modules/flux")
BEZIER = require("Modules/path2d_bezier3")
BEZIER_HIT = require("Modules/path2d_bezier3_hit")
require("Modules/APIParser")
require("Modules/UI")
require("Modules/Utils")
require("Modules/FileManager")
require("Modules/Canvas")
require("Modules/NodeDraw")
require("Modules/Flow")
require("Modules/CustomFunctions")
require("Modules/ExportToAction")

if STANDALONE_RUN then
    return
end

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
    local visible = r.ImGui_BeginChild(ctx, "Canvas", 0, 0, 1,
        r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse())
    if visible then
        FunctionTabs()
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 0)
        if r.ImGui_BeginChild(ctx, "Canvas2", 0, 0, 1, r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse()) then
            r.ImGui_PopStyleVar(ctx)
            -- WE NEED TO CENTER CANVAS IN ITS WINDOW (IN ORDER TO NODE TO BE IN CENTER)
            if not CANVAS then CANVAS = InitCanvas() end
            Popups()
            CanvasLoop()
            UI_Buttons()
            r.ImGui_EndChild(ctx)
            CheckWindowPayload()
            r.ImGui_EndChild(ctx)
        end
    end
end

local FRAME_CNT = 0
DIRTY = nil
local function loop()
    --UI_UPDATE = FRAME_CNT % WIDGETS_LIVE_UPDATE_SPEED == 0 and true or false
    --profiler:start()
    --profiler2.start()
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
    --profiler:stop()
    --profiler:writeReport(PATH .. 'MyProfilingReport.txt')
    ------------------------------------------------
    -- profiler2.stop()
    --profiler2.report(PATH .. "profiler.log")
    --FRAME_CNT = FRAME_CNT + 1
end

InitApi()
InitStartFunction()
r.defer(function() xpcall(loop, crash) end)
