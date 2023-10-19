-- @description Sexan ParaNormal FX Router
-- @author Sexan
-- @license GPL v3
-- @version 1.6
-- @changelog
--  Fix PASTE-REPLACE not switching parallel info with the target
-- @provides
--   Modules/*.lua
--   Fonts/*.ttf
--   JSFX/*.jsfx
--   [effect] JSFX/*.jsfx

local r     = reaper
local ImGui = {}
for name, func in pairs(reaper) do
    name = name:match('^ImGui_(.+)$')
    if name then ImGui[name] = func end
end
os_separator      = package.config:sub(1, 1)
script_path       = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
local reaper_path = r.GetResourcePath()

package.path      = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

if not r.GetAppVersion():match("^7%.") then
    r.ShowMessageBox("This script requires Reaper V7", "WRONG REAPER VERSION", 0)
    return
end

if not r.ImGui_GetVersion then
    r.ShowMessageBox("ReaImGui is required.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
    return r.ReaPack_BrowsePackages('dear imgui')
end

ctx = ImGui.CreateContext('ParaRefactor')

ImGui.SetConfigVar(ctx, ImGui.ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
WND_FLAGS = ImGui.WindowFlags_NoScrollbar() | ImGui.WindowFlags_NoScrollWithMouse()
FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()

draw_list = r.ImGui_GetWindowDrawList(ctx)

ICONS_FONT_SMALL = ImGui.CreateFont(script_path .. 'Fonts/Icons.ttf', 13)
ImGui.Attach(ctx, ICONS_FONT_SMALL)
ICONS_FONT_LARGE = ImGui.CreateFont(script_path .. 'Fonts/Icons.ttf', 16)
ImGui.Attach(ctx, ICONS_FONT_LARGE)

SYSTEM_FONT = ImGui.CreateFont('sans-serif', 13, ImGui.FontFlags_Bold())
ImGui.Attach(ctx, SYSTEM_FONT)
DEFAULT_FONT = ImGui.CreateFont(script_path .. 'Fonts/ProggyClean.ttf', 13)
ImGui.Attach(ctx, DEFAULT_FONT)

ESC_CLOSE                    = false
AUTO_COLORING                = false
CUSTOM_FONT                  = nil
ANIMATED_HIGLIGHT            = true
DEFAULT_DND                  = true
CTRL_DRAG_AUTOCONTAINER      = false
TOOLTIPS                     = true

local fx_browser_script_path = reaper_path .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"
local fm_script_path         = reaper_path .. "/Scripts/Sexan_Scripts/ImGui_Tools/FileManager.lua"
if r.file_exists(fx_browser_script_path) then
    dofile(fx_browser_script_path)
else
    r.ShowMessageBox("Sexan FX Browser is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
    return r.ReaPack_BrowsePackages('sexan fx browser parser V7')
end
if r.file_exists(fm_script_path) then
    dofile(fm_script_path)
else
    r.ShowMessageBox("Sexan FileManager is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
    return r.ReaPack_BrowsePackages('sexan ImGui FileManager')
end

require("Modules/Utils")
require("Modules/Drawing")
require("Modules/Canvas")
require("Modules/ContainerCode")
require("Modules/Functions")

if r.HasExtState("PARANORMALFX2", "SETTINGS") then
    local stored = r.GetExtState("PARANORMALFX2", "SETTINGS")
    if stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            -- SETTINGS
            TOOLTIPS = storedTable.tooltips~=nil and storedTable.tooltips
            ANIMATED_HIGLIGHT = storedTable.animated_highlight
            CTRL_DRAG_AUTOCONTAINER = storedTable.ctrl_autocontainer
            ESC_CLOSE = storedTable.esc_close
            CUSTOM_FONT = storedTable.custom_font
            AUTO_COLORING = storedTable.auto_color
            S_SPACING_Y = storedTable.spacing
            ADD_BTN_H = storedTable.add_btn_h
            ADD_BTN_W = storedTable.add_btn_w
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

function StoreToPEXT(last_track)
    if not last_track then return end
    local storedTable = {}
    if r.ValidatePtr(last_track, "MediaTrack*") then
        storedTable.CANVAS = CANVAS
    end
    local serialized = tableToString(storedTable)
    if r.ValidatePtr(last_track, "MediaTrack*") then
        r.GetSetMediaTrackInfo_String(last_track, "P_EXT:PARANORMAL_FX", serialized, true)
    end
end

function RestoreFromPEXT()
    local rv, stored
    if r.ValidatePtr(TRACK, "MediaTrack*") then
        rv, stored = r.GetSetMediaTrackInfo_String(TRACK, "P_EXT:PARANORMAL_FX", "", false)
    end
    if rv == true and stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            if r.ValidatePtr(TRACK, "MediaTrack*") then
                CANVAS = storedTable.CANVAS
            end
            return true
        end
    end
end

local FX_LIST, CAT = GetFXTbl()

function GetFXBrowserData()
    return FX_LIST, CAT
end

local function Main()
    if WANT_REFRESH then
        WANT_REFRESH = nil
        FX_LIST, CAT = GetFXTbl()
    end

    TRACK = PIN and SEL_LIST_TRACK or r.GetSelectedTrack2(0, 0, true)

    if LAST_TRACK ~= TRACK then
        ResetStrippedNames()
        StoreToPEXT(LAST_TRACK)
        LAST_TRACK = TRACK
        if not RestoreFromPEXT() then
            CANVAS = InitCanvas()
        end
    end

    ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg(), 0x111111FF)
    ImGui.SetNextWindowSizeConstraints(ctx, 500, 500, FLT_MAX, FLT_MAX)
    ImGui.SetNextWindowSize(ctx, 500, 500, ImGui.Cond_FirstUseEver())
    local visible, open = ImGui.Begin(ctx, 'PARANORMAL FX ROUTER###PARANORMALFX', true, WND_FLAGS)
    ImGui.PopStyleColor(ctx)

    if visible then
        r.ImGui_PushFont(ctx, SELECTED_FONT)
        CanvasLoop()
        CollectFxData()
        Draw()
        UI()
        ClipBoard()
        if OPEN_SETTINGS then DrawUserSettings() end
        if not IS_DRAGGING_RIGHT_CANVAS and r.ImGui_IsMouseReleased(ctx, 1) and
            not r.ImGui_IsAnyItemHovered(ctx) and
            not r.ImGui_IsPopupOpen(ctx, "RIGHT_CLICK_MENU") and
            not r.ImGui_IsPopupOpen(ctx, "OPEN_INSERT_POINTS_MENU") and
            not DND_MOVE_FX and
            not DND_ADD_FX then
            r.ImGui_OpenPopup(ctx, 'FX LIST')
        end
        IS_DRAGGING_RIGHT_CANVAS = r.ImGui_IsMouseDragging(ctx, 1, 2)
        FX_OPENED = r.ImGui_IsPopupOpen(ctx, "FX LIST")
        RENAME_OPENED = r.ImGui_IsPopupOpen(ctx, "RENAME")

        CheckStaleData()
        r.ImGui_PopFont(ctx)
        ImGui.End(ctx)
    end

    if ESC and ESC_CLOSE then open = nil end

    if open then
        pdefer(Main)
    end

    UpdateScroll()
    if FONT_UPDATE then FONT_UPDATE = nil end
end

function Exit()
    if CLIPBOARD.tbl and CLIPBOARD.track == TRACK then
        ClearExtState()
    end
    StoreToPEXT(LAST_TRACK)
end

r.atexit(Exit)
pdefer(Main)
