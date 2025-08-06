-- @description Sexan ParaNormal FX Router
-- @author Sexan
-- @license GPL v3
-- @version 1.44
-- @changelog
--  Load imgui shims for backward compatibility
-- @provides
--   Modules/*.lua
--   Fonts/*.ttf
--   JSFX/*.jsfx
--   FXChains/*.RfxChain
--   [effect] JSFX/*.jsfx

local r = reaper
dofile(r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.9.3')
local ImGui     = {}
local track_api = {}
local take_api  = {}
for name, func in pairs(r) do
    local track_name = name:match('^TrackFX_(.+)$')
    local take_name = name:match('^TakeFX_(.+)$')
    if track_name then track_api[track_name] = func end
    if take_name then take_api[take_name] = func end
end

take_api["CopyToTrack"] = r.TakeFX_CopyToTake
take_api["GetFXEnvelope"] = r.TakeFX_GetEnvelope
track_api["GetFXEnvelope"] = r.GetFXEnvelope

API = track_api
AW, AH = 0, 0
for name, func in pairs(reaper) do
    name = name:match('^ImGui_(.+)$')
    if name then ImGui[name] = func end
end

os_separator      = package.config:sub(1, 1)
script_path       = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
local reaper_path = r.GetResourcePath()

FX_FILE           = script_path .. "/FX_LIST.txt"
FX_CAT_FILE       = script_path .. "/FX_CAT_FILE.txt"
FX_DEV_LIST_FILE  = script_path .. "/FX_DEV_LIST_FILE.txt"

package.path      = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
if DBG then dofile("C:/Users/Gokily/Documents/ReaGit/ReaScripts/Debug/LoadDebug.lua") end
if not r.GetAppVersion():match("^7%.") then
    r.ShowMessageBox("This script requires Reaper V7", "WRONG REAPER VERSION", 0)
    return
else
    if r.GetAppVersion():match("%.(%d+)") < "11" then
        r.ShowMessageBox("Reaper version V7.11 is minimal requirement.\n", "UPDATE REAPER", 0)
        return
    end
end

-- JSFX paths
local saike_splitter_path = reaper_path .. "/Effects/Saike Tools/Basics/BandSplitter.jsfx"
local lfos_path           = reaper_path .. "/Effects/ReaTeam JSFX/Modulation/snjuk2_LFO.jsfx"
local splitters_path      = reaper_path ..
    "/Effects/Suzuki Scripts/lewloiwc's Splitter Suite/lewloiwc_frequency_splitter.jsfx"


--local fx_browser_script_path = "C:/Users/Gokily/Documents/ReaGit/ReaScripts/FX/Sexan_FX_Browser_ParserV7.lua" -- DEV
--local fm_script_path         = "C:/Users/Gokily/Documents/ReaGit/ReaScripts/ImGui_Tools/FileManager.lua" -- DEV
local fx_browser_script_path = reaper_path .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"
local fm_script_path         = reaper_path .. "/Scripts/Sexan_Scripts/ImGui_Tools/FileManager.lua"

function ThirdPartyDeps()
    local reapack_process
    local repos = {
        { name = "Saike Tools",    url = 'https://raw.githubusercontent.com/JoepVanlier/JSFX/master/index.xml' },
        { name = "Suzuki Scripts", url = "https://github.com/Suzuki-Re/Suzuki-Scripts/raw/master/index.xml" },
    }

    for i = 1, #repos do
        local retinfo, url, enabled, autoInstall = r.ReaPack_GetRepositoryInfo(repos[i].name)
        if not retinfo then
            retval, error = r.ReaPack_AddSetRepository(repos[i].name, repos[i].url, true, 0)
            reapack_process = true
        end
    end

    -- ADD NEEDED REPOSITORIES
    if reapack_process then
        --r.ShowMessageBox("Added Third-Party ReaPack Repositories", "ADDING REPACK REPOSITORIES", 0)
        r.ReaPack_ProcessQueue(true)
        reapack_process = nil
    end
end

local function CheckDeps()
    --'Sexan FX Browser Parser V7' OR 'Sexan ImGui FileManager' OR 'Dear Imgui' OR 'Saike 4-pole BandSplitter'
    ThirdPartyDeps()
    local deps = {}

    if not r.ImGui_GetVersion then
        deps[#deps + 1] = '"Dear Imgui"'
    end
    if not r.file_exists(fx_browser_script_path) then
        deps[#deps + 1] = '"FX Browser Parser V7"'
    end
    if not r.file_exists(fm_script_path) then
        deps[#deps + 1] = '"Sexan ImGui FileManager"'
    end
    if not r.file_exists(lfos_path) then
        deps[#deps + 1] = '"Snjuk2"'
    end
    if not r.file_exists(splitters_path) then
        deps[#deps + 1] = [["lewloiwc's Splitter Suite"]]
    end
    if not r.file_exists(saike_splitter_path) then
        deps[#deps + 1] = '"Saike 4-pole BandSplitter"'
        r.SetExtState("PARANORMALFX2", "UPDATEFX", "true", false)
    end

    if #deps ~= 0 then
        r.ShowMessageBox("Need Additional Packages.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
        r.ReaPack_BrowsePackages(table.concat(deps, " OR "))
        return true
    end
end

if CheckDeps() then return end

dofile(r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.7')
--if ThirdPartyDeps() then return end

ctx = ImGui.CreateContext('ParaNormalFX Router')

ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
WND_FLAGS = ImGui.WindowFlags_NoScrollbar() | ImGui.WindowFlags_NoScrollWithMouse()
FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

draw_list = r.ImGui_GetWindowDrawList(ctx)

ORG_FONT_SIZE = 13
FONT_SIZE = ORG_FONT_SIZE

ICONS_FONT_SMALL = ImGui.CreateFont(script_path .. 'Fonts/Icons.ttf', FONT_SIZE)
ImGui.Attach(ctx, ICONS_FONT_SMALL)
ICONS_FONT_SMALL_FACTORY = ImGui.CreateFont(script_path .. 'Fonts/Icons.ttf', FONT_SIZE)
ImGui.Attach(ctx, ICONS_FONT_SMALL_FACTORY)
ICONS_FONT_LARGE = ImGui.CreateFont(script_path .. 'Fonts/Icons.ttf', 16)
ImGui.Attach(ctx, ICONS_FONT_LARGE)

SYSTEM_FONT = ImGui.CreateFont('sans-serif', FONT_SIZE, ImGui.FontFlags_Bold())
ImGui.Attach(ctx, SYSTEM_FONT)
DEFAULT_FONT = ImGui.CreateFont(script_path .. 'Fonts/ProggyClean.ttf', FONT_SIZE)
ImGui.Attach(ctx, DEFAULT_FONT)

DEFAULT_FONT_FACTORY = ImGui.CreateFont(script_path .. 'Fonts/ProggyClean.ttf', ORG_FONT_SIZE)
ImGui.Attach(ctx, DEFAULT_FONT_FACTORY)
SYSTEM_FONT_FACTORY = ImGui.CreateFont('sans-serif', FONT_SIZE, ImGui.FontFlags_Bold())
ImGui.Attach(ctx, SYSTEM_FONT_FACTORY)

DEF_PARALLEL            = "2"
ESC_CLOSE               = false
AUTO_COLORING           = false
CUSTOM_FONT             = nil
ANIMATED_HIGLIGHT       = true
DEFAULT_DND             = true
CTRL_DRAG_AUTOCONTAINER = false
TOOLTIPS                = true
SHOW_C_CONTENT_TOOLTIP  = true
V_LAYOUT                = true
CENTER_RESET            = false


OPEN_PM_INSPECTOR = false
MODE              = "TRACK"

--profiler = dofile(reaper.GetResourcePath() ..
--  '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
--reaper.defer = profiler.defer

if r.file_exists(fx_browser_script_path) then
    dofile(fx_browser_script_path)
end
if r.file_exists(fm_script_path) then
    dofile(fm_script_path)
end

require("Modules/Utils")
require("Modules/Drawing")
require("Modules/Canvas")
require("Modules/ContainerCode")
require("Modules/Functions")
FLUX = require("Modules/flux")

if r.HasExtState("PARANORMALFX2", "SETTINGS") then
    local stored = r.GetExtState("PARANORMALFX2", "SETTINGS")
    if stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            local COLOR = GetColorTbl()
            -- SETTINGS
            --V_LAYOUT = storedTable.v_layout ~= nil and storedTable.v_layout or V_LAYOUT
            if storedTable.v_layout ~= nil then
                V_LAYOUT = storedTable.v_layout
            end
            SHOW_C_CONTENT_TOOLTIP = storedTable.show_c_content_tooltips ~= nil and storedTable.show_c_content_tooltips
            TOOLTIPS = storedTable.tooltips ~= nil and storedTable.tooltips
            ANIMATED_HIGLIGHT = storedTable.animated_highlight
            CTRL_DRAG_AUTOCONTAINER = storedTable.ctrl_autocontainer
            ESC_CLOSE = storedTable.esc_close
            CUSTOM_FONT = storedTable.custom_font
            AUTO_COLORING = storedTable.auto_color
            new_spacing_y = storedTable.spacing
            ZOOM_MAX = storedTable.zoom_max and storedTable.zoom_max or 1
            ZOOM_DEFAULT = storedTable.zoom_default and storedTable.zoom_default or 1
            ADD_BTN_H = storedTable.add_btn_h
            ADD_BTN_W = storedTable.add_btn_w
            CENTER_RESET = storedTable.center_reset ~= nil and storedTable.center_reset or CENTER_RESET
            WireThickness = storedTable.wirethickness
            COLOR["wire"] = storedTable.wire_color
            COLOR["n"] = storedTable.fx_color
            COLOR["bypass"] = storedTable.bypass_color
            COLOR["Container"] = storedTable.container_color
            COLOR["parallel"] = storedTable.parallel_color
            COLOR["knob_vol"] = storedTable.knobvol_color
            COLOR["knob_drywet"] = storedTable.drywet_color
            COLOR["knob_drywet"] = storedTable.drywet_color
            COLOR["sine_anim"] = storedTable.anim_color
            COLOR["offline"] = storedTable.offline_color and storedTable.offline_color or COLOR["offline"]
            COLOR["bg"] = storedTable.background and storedTable.background or COLOR["bg"]
        end
    end
end

SELECTED_FONT = CUSTOM_FONT and SYSTEM_FONT or DEFAULT_FONT

local function pdefer(func)
    reaper.defer(function()
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
            ClearExtState()
        end
    end)
end

function StoreToPEXT(last_target)
    if not last_target then return end
    local storedTable = {}
    if r.ValidatePtr(last_target, "MediaTrack*") then
        storedTable.CANVAS = CANVAS
        storedTable.CONTAINERS = GetTRContainerData()
    elseif r.ValidatePtr(last_target, "MediaItem_Take*") then
        storedTable.CANVAS = CANVAS
        storedTable.CONTAINERS = GetTRContainerData()
    end
    local serialized = tableToString(storedTable)
    if r.ValidatePtr(last_target, "MediaTrack*") then
        r.GetSetMediaTrackInfo_String(last_target, "P_EXT:PARANORMAL_FX2", serialized, true)
    elseif r.ValidatePtr(last_target, "MediaItem_Take*") then
        r.GetSetMediaItemTakeInfo_String(last_target, "P_EXT:PARANORMAL_FX2", serialized, true)
    end
end

function RestoreFromPEXT(mode)
    local rv, stored
    if mode == "TRACK" and r.ValidatePtr(TRACK, "MediaTrack*") then
        rv, stored = r.GetSetMediaTrackInfo_String(TRACK, "P_EXT:PARANORMAL_FX2", "", false)
    elseif mode == "ITEM" and r.ValidatePtr(TAKE, "MediaItem_Take*") then
        rv, stored = r.GetSetMediaItemTakeInfo_String(TAKE, "P_EXT:PARANORMAL_FX2", "", false)
    end
    if rv == true and stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            if mode == "TRACK" and r.ValidatePtr(TRACK, "MediaTrack*") then
                CANVAS = storedTable.CANVAS
                SetTRContainerData(storedTable.CONTAINERS)
                if CENTER_RESET then
                    ResetView(true)
                end
            elseif mode == "ITEM" and r.ValidatePtr(TAKE, "MediaItem_Take*") then
                CANVAS = storedTable.CANVAS
                SetTRContainerData(storedTable.CONTAINERS)
                if CENTER_RESET then
                    ResetView(true)
                end
            end
            return true
        end
    end
end

local FX_LIST, CAT = ReadFXFile()

if not FX_LIST or not CAT or r.HasExtState("PARANORMALFX2", "UPDATEFX") then
    FX_LIST, CAT = MakeFXFiles()
    if r.HasExtState("PARANORMALFX2", "UPDATEFX") then
        r.DeleteExtState("PARANORMALFX2", "UPDATEFX", false)
    end
end

function GetFXBrowserData()
    return FX_LIST, CAT
end

function UpdateFXBrowserData()
    FX_LIST, CAT = ReadFXFile()
end

function RescanFxList()
    FX_LIST, CAT = MakeFXFiles()
end

UpdateChainsTrackTemplates(CAT)

-- local function CheckReaperIODnd()
--     M_TEST()
--     local mx, my = r.GetMousePosition()
--     if LAST_CLICK and not A_X then
--         A_X, A_Y = mx, my
--     end

--     if A_X then
--         local tr, buf = r.GetThingFromPoint(A_X, A_Y)
--         if buf == "tcp.io" and not REAPER_DND then
--             REAPER_DND = buf == "tcp.io" and tr or nil
--         end
--     end
--     return mx, my
-- end

-- img = r.ImGui_CreateImage( script_path .. "SchwaARM.png")
-- r.ImGui_Attach(ctx, img)

function UpdateZoomFont()
    if not CANVAS then return end
    local new_font_size = (ORG_FONT_SIZE * CANVAS.scale) // 1
    if FONT_SIZE ~= new_font_size then
        if NEXT_FRAME then
            if DEFAULT_FONT then
                r.ImGui_Detach(ctx, ICONS_FONT_SMALL)
                r.ImGui_Detach(ctx, SYSTEM_FONT)
                r.ImGui_Detach(ctx, DEFAULT_FONT)
            end
            ICONS_FONT_SMALL = ImGui.CreateFont(script_path .. 'Fonts/Icons.ttf', new_font_size)
            ImGui.Attach(ctx, ICONS_FONT_SMALL)
            SYSTEM_FONT = ImGui.CreateFont('sans-serif', new_font_size, ImGui.FontFlags_Bold())
            ImGui.Attach(ctx, SYSTEM_FONT)
            DEFAULT_FONT = ImGui.CreateFont(script_path .. 'Fonts/ProggyClean.ttf', new_font_size)
            ImGui.Attach(ctx, DEFAULT_FONT)
            FONT_SIZE = new_font_size
            SELECTED_FONT = CUSTOM_FONT and SYSTEM_FONT or DEFAULT_FONT
            NEXT_FRAME = nil
        end
    end
end

local old_time = r.time_precise()
local start_time = old_time
local old_play = r.GetPlayState() & 1
local old_ex_pos = r.GetCursorPosition()
local function UpdateDeltaTime()
    local now_time = r.time_precise()
    TIME_SINCE_START = now_time - start_time

    if r.GetPlayState() & 1 ~= old_play or old_ex_pos ~= r.GetCursorPosition() then
        start_time = r.time_precise()
        old_play = r.GetPlayState() & 1
        old_ex_pos = r.GetCursorPosition()
    end

    DT = now_time - old_time
    old_time = now_time
    FLUX.update(DT)
end

function test()
    local TR_CONT = GetTRContainerData()
    SetCollapseData(TR_CONT, TMP.tbl, TMP.i)
    if TMP then TMP = nil end
end

local function UpdateTarget()
    if MODE == "ITEM" then
        TARGET = TAKE
        TRACK = TARGET and r.GetMediaItemTake_Track(TARGET)
    else
        TARGET = TRACK
    end
end

local function UpdateLastTargetCanvas()
    if MODE == "TRACK" and LAST_TRACK ~= TRACK then
        ResetStrippedNames()
        StoreToPEXT(LAST_TRACK)
        LAST_TRACK = TRACK
        LASTTOUCH_RV, LASTTOUCH_TR_NUM, LASTTOUCH_FX_ID, LASTTOUCH_P_ID = nil, nil, nil, nil
        if not RestoreFromPEXT(MODE) then
            CANVAS = InitCanvas()
            ResetView(true)
            InitTrackContainers()
        end
    elseif MODE == "ITEM" and LAST_TAKE ~= TAKE then
        ResetStrippedNames()
        StoreToPEXT(LAST_TAKE)
        LAST_TAKE = TAKE
        LASTTOUCH_RV, LASTTOUCH_TR_NUM, LASTTOUCH_FX_ID, LASTTOUCH_P_ID = nil, nil, nil, nil
        if not RestoreFromPEXT(MODE) then
            CANVAS = InitCanvas()
            ResetView(true)
            InitTrackContainers()
        end
    end
end

local function Main()
    UpdateDeltaTime()
    UpdateZoomFont()
    if WANT_REFRESH then
        WANT_REFRESH = nil
        UpdateChainsTrackTemplates(CAT)
    end

    TRACK = PIN and SEL_LIST_TRACK or r.GetSelectedTrack2(0, 0, true)
    ITEM = r.GetSelectedMediaItem(0, 0)
    TAKE = PIN and SEL_LIST_TAKE or (ITEM and r.GetActiveTake(ITEM))
    UpdateTarget()
    --UpdateLastTargetCanvas()

    -- if REAPER_DND then
    --     ImGui.SetNextWindowSizeConstraints(ctx, 500, 500, FLT_MAX, FLT_MAX)
    --     ImGui.SetNextWindowSize(ctx, 150, 150, ImGui.Cond_FirstUseEver())
    --     r.ImGui_SetNextWindowPos(ctx, mx-25, my-25)
    --     if r.ImGui_Begin(ctx, 'REAPERDND', false, r.ImGui_WindowFlags_NoInputs() | r.ImGui_WindowFlags_NoDecoration() |  r.ImGui_WindowFlags_NoBackground() |  r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_NoMove()) then
    --             if r.ImGui_IsMouseDown(ctx,0) then
    --                 r.ShowConsoleMsg("DOWN")
    --             end
    --             r.ImGui_Image( ctx, img, 182//3, 125//3 )
    --         ImGui.End(ctx)
    --     end
    -- end

    ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg(), GetColorTbl()["bg"])
    ImGui.SetNextWindowSizeConstraints(ctx, 500, 500, FLT_MAX, FLT_MAX)
    ImGui.SetNextWindowSize(ctx, 500, 500, ImGui.Cond_FirstUseEver())

    local visible, open = r.ImGui_Begin(ctx, 'PARANORMAL FX ROUTER###PARANORMALFX', true, WND_FLAGS)

    ImGui.PopStyleColor(ctx)
    if visible then
        AW, AH = r.ImGui_GetContentRegionAvail(ctx)
        WX, WY = r.ImGui_GetWindowPos(ctx)
        MX, MY = r.ImGui_GetMousePos(ctx)
        DRAGX, DRAGY = r.ImGui_GetMouseDragDelta(ctx, nil, nil, 0)
        UpdateLastTargetCanvas()

        r.ImGui_PushFont(ctx, CUSTOM_FONT and SYSTEM_FONT_FACTORY or DEFAULT_FONT_FACTORY)

        r.ImGui_Text(ctx, "MODE ")
        r.ImGui_SameLine(ctx)

        if r.ImGui_Checkbox(ctx, "TRACK", MODE == "TRACK") then
            StoreToPEXT(TAKE)
            MODE = "TRACK"
            API = track_api
            ClearExtState()
            UpdateTarget()
            RestoreFromPEXT(MODE)
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Checkbox(ctx, "ITEMS", MODE == "ITEM") then
            StoreToPEXT(TRACK)
            MODE = "ITEM"
            API = take_api
            ClearExtState()
            UpdateTarget()
            RestoreFromPEXT(MODE)
        end

        MonitorLastTouchedFX()
        -- AW, AH = r.ImGui_GetContentRegionAvail(ctx)
        -- WX, WY = r.ImGui_GetWindowPos(ctx)
        -- MX, MY = r.ImGui_GetMousePos(ctx)
        -- DRAGX, DRAGY = r.ImGui_GetMouseDragDelta(ctx, nil, nil, 0)
        --r.ImGui_PushFont(ctx, CUSTOM_FONT and SYSTEM_FONT_FACTORY or DEFAULT_FONT_FACTORY)
        CanvasLoop()
        r.ImGui_PopFont(ctx)
        CollectFxData()
        r.ImGui_PushFont(ctx, SELECTED_FONT)
        if CANVAS then
            Draw()
        end
        r.ImGui_PopFont(ctx)
        UI()
        r.ImGui_PushFont(ctx, CUSTOM_FONT and SYSTEM_FONT_FACTORY or DEFAULT_FONT_FACTORY)
        if OPEN_SETTINGS then
            DrawUserSettings()
            if OPEN_PM_INSPECTOR then OPEN_PM_INSPECTOR = nil end
        end
        if OPEN_PM_INSPECTOR then
            DrawPMInspector()
        else
            if PM_INSPECTOR_FXID then PM_INSPECTOR_FXID = nil end
        end

        if HasMultiple(SEL_TBL) then
            r.ImGui_SetCursorPos(ctx, 270, 25)
            r.ImGui_Button(ctx, "MARQUEE MOVE/COPY IS NOT SUPPORTED")
        end

        ClipBoard()
        r.ImGui_PopFont(ctx)
        --if OPEN_SLOTS then SlotsMenu() end
        if not IS_DRAGGING_RIGHT_CANVAS and r.ImGui_IsMouseReleased(ctx, 1) and
            not r.ImGui_IsAnyItemHovered(ctx) and
            not r.ImGui_IsPopupOpen(ctx, "RIGHT_CLICK_MENU") and
            not r.ImGui_IsPopupOpen(ctx, "INSERT_POINTS_MENU") and
            not DND_MOVE_FX and
            not DND_ADD_FX and
            not INSPECTOR_HOVERED and
            not UI_HOVERED and
            not SETTINGS_HOVERED then
            r.ImGui_OpenPopup(ctx, 'FX LIST')
        end
        IS_DRAGGING_RIGHT_CANVAS = r.ImGui_IsMouseDragging(ctx, 1, 2)
        FX_OPENED = r.ImGui_IsPopupOpen(ctx, "FX LIST")
        RENAME_OPENED = r.ImGui_IsPopupOpen(ctx, "RENAME")
        FILE_MANAGER_OPENED = r.ImGui_IsPopupOpen(ctx, "File Dialog")

        CheckStaleData()
        ImGui.End(ctx)
    end
    if ESC and ESC_CLOSE then open = nil end

    if open then
        if DBG then
            DEBUG.defer(Main)
        else
            pdefer(Main)
        end
    end

    if FONT_UPDATE then FONT_UPDATE = nil end
    NEXT_FRAME = true
    -- if MOUSE_UP then
    --     if A_X then A_X, A_Y = nil,nil end
    --     if REAPER_DND then
    --         REAPER_DND = nil
    --     end
    -- end
end

function Exit()
    if CLIPBOARD.tbl and CLIPBOARD.track == TRACK then
        ClearExtState()
    end
    if MODE == "TRACK" then
        StoreToPEXT(LAST_TRACK)
    else
        StoreToPEXT(LAST_TAKE)
    end
end

r.atexit(Exit)

if DBG then
    DEBUG.defer(Main)
else
    pdefer(Main)
end

--profiler.attachToWorld() -- after all functions have been defined
--profiler.run()
