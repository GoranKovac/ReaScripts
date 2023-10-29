-- @description Sexan ParaNormal FX Router
-- @author Sexan
-- @license GPL v3
-- @version 1.33.41
-- @changelog
--  Remove right click restriction from helpers
-- @provides
--   Modules/*.lua
--   Fonts/*.ttf
--   JSFX/*.jsfx
--   FXChains/*.RfxChain
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

FX_FILE           = script_path .. "/FX_LIST.txt"
FX_CAT_FILE       = script_path .. "/FX_CAT_FILE.txt"
FX_DEV_LIST_FILE  = script_path .. "/FX_DEV_LIST_FILE.txt"

package.path      = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

if not r.GetAppVersion():match("^7%.") then
    r.ShowMessageBox("This script requires Reaper V7", "WRONG REAPER VERSION", 0)
    return
end

if not r.ImGui_GetVersion then
    r.ShowMessageBox("ReaImGui is required.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
    return r.ReaPack_BrowsePackages('dear imgui')
else
    -- local v, v1, v2 = r.ImGui_GetVersion():match("(%d+)%.(%d+)%.(%d+)")
    -- local old
    -- if tonumber(v) < 1 then
    --     old = true
    -- elseif tonumber(v1) < 89 then
    --     old = true
    -- elseif tonumber(v2) < 6 then
    --     old = true
    -- end
    -- if old then
    --     r.ShowMessageBox("Script requires ReaImGui version 1.89.6\nPlease update in Reapack", "OLD REAIMGUI VERSION", 0)
    --     return r.ReaPack_BrowsePackages('dear imgui')
    -- end
end

function ThirdPartyDeps()
    local saike_splitter_path = reaper_path .. "/Effects/Saike Tools/Basics/BandSplitter.jsfx"
    local reapack_process
    local repos = {
        { name = "Saike Tools", url = 'https://raw.githubusercontent.com/JoepVanlier/JSFX/master/index.xml' },
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
        r.ShowMessageBox("Added Third-Party ReaPack Repositories", "ADDING REPACK REPOSITORIES", 0)
        r.ReaPack_ProcessQueue(true)
        reapack_process = nil
    end

    if not reapack_process then
        -- FX BROWSER
        if r.file_exists(saike_splitter_path) then
        else
            r.ShowMessageBox("Sai'ke 4 Pole Band Splitter is needed.\nPlease Install it in next window",
                "MISSING DEPENDENCIES", 0)
            r.ReaPack_BrowsePackages('saike 4 pole bandsplitter')
            r.SetExtState("PARANORMALFX2", "UPDATEFX", "true", false)
            return 'error saike splitter'
        end
    end
end

if ThirdPartyDeps() then return end

ctx = ImGui.CreateContext('ParaNormalFX Router')

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

DEF_PARALLEL                 = "2"
ESC_CLOSE                    = false
AUTO_COLORING                = false
CUSTOM_FONT                  = nil
ANIMATED_HIGLIGHT            = true
DEFAULT_DND                  = true
CTRL_DRAG_AUTOCONTAINER      = false
TOOLTIPS                     = true
SHOW_C_CONTENT_TOOLTIP       = true
--V_LAYOUT                     = false

--local fx_browser_script_path = "C:/Users/Gokily/Documents/ReaGit/ReaScripts/FX/Sexan_FX_Browser_ParserV7.lua"
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
--require("Modules/DrawingHorizontal")
require("Modules/Canvas")
require("Modules/ContainerCode")
require("Modules/Functions")

if r.HasExtState("PARANORMALFX2", "SETTINGS") then
    local stored = r.GetExtState("PARANORMALFX2", "SETTINGS")
    if stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            -- SETTINGS
            SHOW_C_CONTENT_TOOLTIP = storedTable.show_c_content_tooltips ~= nil and storedTable.show_c_content_tooltips
            TOOLTIPS = storedTable.tooltips ~= nil and storedTable.tooltips
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
            COLOR["offline"] = storedTable.offline_color and storedTable.offline_color or COLOR["offline"]
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
        storedTable.CONTAINERS = GetTRContainerData()
    end
    local serialized = tableToString(storedTable)
    if r.ValidatePtr(last_track, "MediaTrack*") then
        r.GetSetMediaTrackInfo_String(last_track, "P_EXT:PARANORMAL_FX2", serialized, true)
    end
end

function RestoreFromPEXT()
    local rv, stored
    if r.ValidatePtr(TRACK, "MediaTrack*") then
        rv, stored = r.GetSetMediaTrackInfo_String(TRACK, "P_EXT:PARANORMAL_FX2", "", false)
    end
    if rv == true and stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            if r.ValidatePtr(TRACK, "MediaTrack*") then
                CANVAS = storedTable.CANVAS
                SetTRContainerData(storedTable.CONTAINERS)
            end
            return true
        end
    end
end

local FX_LIST, CAT = ReadFXFile(FX_FILE, FX_CAT_FILE, FX_DEV_LIST_FILE)

function MakeFXFiles()
    local GEN_FX_LIST, GEN_CAT, GEN_DEVELOPER_LIST = GetFXTbl()
    local serialized_fx = TableToString(GEN_FX_LIST)
    WriteToFile(FX_FILE, serialized_fx)

    local serialized_cat = TableToString(GEN_CAT)
    WriteToFile(FX_CAT_FILE, serialized_cat)

    local serialized_dev_list = TableToString(GEN_DEVELOPER_LIST)
    WriteToFile(FX_DEV_LIST_FILE, serialized_dev_list)

    FX_LIST, CAT = GEN_FX_LIST, GEN_CAT
end

if not FX_LIST and not CAT or r.HasExtState("PARANORMALFX2", "UPDATEFX") then
    MakeFXFiles()
    if r.HasExtState("PARANORMALFX2", "UPDATEFX") then
        r.DeleteExtState("PARANORMALFX2", "UPDATEFX", false)
    end
end

--UpdateChainsTrackTemplates(CAT)

function GetFXBrowserData()
    return FX_LIST, CAT
end

function UpdateFXBrowserData()
    FX_LIST, CAT = ReadFXFile(FX_FILE, FX_CAT_FILE, FX_DEV_LIST_FILE)
end

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

local function Main()

    if WANT_REFRESH then
        WANT_REFRESH = nil
        UpdateChainsTrackTemplates(CAT)
    end

    TRACK = PIN and SEL_LIST_TRACK or r.GetSelectedTrack2(0, 0, true)

    if LAST_TRACK ~= TRACK then
        ResetStrippedNames()
        StoreToPEXT(LAST_TRACK)
        LAST_TRACK = TRACK
        if not RestoreFromPEXT() then
            CANVAS = InitCanvas()
            InitTrackContainers()
        end
    end
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

    ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg(), 0x111111FF)
    ImGui.SetNextWindowSizeConstraints(ctx, 500, 500, FLT_MAX, FLT_MAX)
    ImGui.SetNextWindowSize(ctx, 500, 500, ImGui.Cond_FirstUseEver())
    
    local visible, open = r.ImGui_Begin(ctx, 'PARANORMAL FX ROUTER###PARANORMALFX', true, WND_FLAGS)
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
            not r.ImGui_IsPopupOpen(ctx, "INSERT_POINTS_MENU") and
            not DND_MOVE_FX and
            not DND_ADD_FX then
            r.ImGui_OpenPopup(ctx, 'FX LIST')
        end
        IS_DRAGGING_RIGHT_CANVAS = r.ImGui_IsMouseDragging(ctx, 1, 2)
        FX_OPENED = r.ImGui_IsPopupOpen(ctx, "FX LIST")
        RENAME_OPENED = r.ImGui_IsPopupOpen(ctx, "RENAME")
        FILE_MANAGER_OPENED = r.ImGui_IsPopupOpen(ctx, "File Dialog")

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
    StoreToPEXT(LAST_TRACK)
end

r.atexit(Exit)
pdefer(Main)
