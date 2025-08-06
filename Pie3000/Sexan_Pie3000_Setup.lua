--@noindex
--NoIndex: true
local r = reaper
local os_separator = package.config:sub(1, 1)
local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" .. package.path -- GET DIRECTORY FOR REQUIRE

SETUP = true
STATE = "PIE"

require('PieUtils')

if CheckDeps() then return end

ctx = r.ImGui_CreateContext('Pie XYZ Setup')
r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigFlags_NavEnableKeyboard(), 1)

require('Common')

DeferLoop = DBG and DEBUG.defer or PDefer

PIE_LIST = {}

local RADIUS_START = 150
local DEFAULT_PIE = {
    ["arrange"] = { RADIUS = RADIUS_START, name = "TRACK", guid = r.genGuid() },
    ["arrangeempty"] = { RADIUS = RADIUS_START, name = "ARRANGE EMPTY", guid = r.genGuid(), use_main = true, main_name = "arrange" },
    -----------------------------
    ["tcp"] = { RADIUS = RADIUS_START, name = "TCP", guid = r.genGuid() },
    ["tcpfxparm"] = { RADIUS = RADIUS_START, name = "TCP FX PARM", guid = r.genGuid(), use_main = true, main_name = "tcp" },
    ["tcpempty"] = { RADIUS = RADIUS_START, name = "TCP EMPTY", guid = r.genGuid(), use_main = true, main_name = "tcp" },
    -----------------------------
    ["mastertcp"] = { RADIUS = RADIUS_START, name = "MASTER TCP", guid = r.genGuid() },
    ["mastertcpfxparm"] = { RADIUS = RADIUS_START, name = "MASTER TCP FX PARM", guid = r.genGuid(), use_main = true, main_name = "mastertcp" },
    -----------------------------
    ["mcp"] = { RADIUS = RADIUS_START, name = "MCP", guid = r.genGuid() },
    ["mcpfxlist"] = { RADIUS = RADIUS_START, name = "MCP FX LIST", guid = r.genGuid(), use_main = true, main_name = "mcp" },
    ["mcpsendlist"] = { RADIUS = RADIUS_START, name = "MCP SEND LIST", guid = r.genGuid(), use_main = true, main_name = "mcp" },
    -----------------------------
    ["mastermcp"] = { RADIUS = RADIUS_START, name = "MASTER MCP", guid = r.genGuid() },
    ["mastermcpfxlist"] = { RADIUS = RADIUS_START, name = "MASTER MCP FX LIST", guid = r.genGuid(), use_main = true, main_name = "mastermcp" },
    ["mastermcpsendlist"] = { RADIUS = RADIUS_START, name = "MASTER MCP SEND LIST", guid = r.genGuid(), use_main = true, main_name = "mastermcp" },
    ["mastermcpempty"] = { RADIUS = RADIUS_START, name = "MASTER MCP EMPTY", guid = r.genGuid(), use_main = true, main_name = "mastermcp" },
    -----------------------------
    ["envelope"] = { RADIUS = RADIUS_START, name = "ENVELOPE", guid = r.genGuid(), as_global = true },
    ["envcp"] = { RADIUS = RADIUS_START, name = "ENV CP", guid = r.genGuid() },
    ["item"] = { RADIUS = RADIUS_START, name = "ITEM", guid = r.genGuid() },
    ["itemmidi"] = { RADIUS = RADIUS_START, name = "MIDI ITEM", guid = r.genGuid() },
    ["trans"] = { RADIUS = RADIUS_START, name = "TRANSPORT", guid = r.genGuid() },
    ["ruler"] = { RADIUS = RADIUS_START, name = "RULER", guid = r.genGuid() },
    ["rulerregion_lane"] = { RADIUS = RADIUS_START, name = "RULER REGION LANE", guid = r.genGuid(), use_main = true, main_name = "ruler" },
    ["rulermarker_lane"] = { RADIUS = RADIUS_START, name = "RULER MARKER LANE", guid = r.genGuid(), use_main = true, main_name = "ruler" },
    ["rulertempo_lane"] = { RADIUS = RADIUS_START, name = "RULER TEMPO LANE", guid = r.genGuid(), use_main = true, main_name = "ruler" },
    ["midi"] = { RADIUS = RADIUS_START, name = "MIDI", guid = r.genGuid(), is_midi = true },
    ["midipianoroll"] = { RADIUS = RADIUS_START, name = "MIDI PIANO ROLL", guid = r.genGuid(), is_midi = true },
    ["miditracklist"] = { RADIUS = RADIUS_START, name = "MIDI TRACK LIST", guid = r.genGuid(), is_midi = true },
    ["midiruler"] = { RADIUS = RADIUS_START, name = "MIDI RULER", guid = r.genGuid(), is_midi = true },
    ["midilane"] = { RADIUS = RADIUS_START, name = "MIDI LANE", guid = r.genGuid(), as_global = true, is_midi = true },
    --["midilanecp"] = { RADIUS = RADIUS_START, name = "MIDI LANE CP", guid = r.genGuid(), as_global = true, is_midi = true },
    ["plugin"] = { RADIUS = RADIUS_START, name = "PLUGIN", guid = r.genGuid() },
    ["spacer"] = { RADIUS = RADIUS_START, name = "SPACER", guid = r.genGuid() },
    ---------------------------------
    ["mediaexplorer"] = { RADIUS = RADIUS_START, name = "MEDIA EXPLORER", guid = r.genGuid(), is_explorer = true },
}

local MAIN_NAMES = {
    ["ARRANGE EMPTY"] = "arrange",
    ["TCP FX PARM"] = "tcp",
    ["TCP EMPTY"] = "tcp",
    ["MASTER TCP FX PARM"] = "mastertcp",
    ["MCP FX LIST"] = "mcp",
    ["MCP SEND LIST"] = "mcp",
    ["MCP EMPTY"] = "mcp",
    ["MASTER MCP FX LIST"] = "mastermcp",
    ["MASTER MCP SEND LIST"] = "mastermcp",
    ["RULER REGION LANE"] = "ruler",
    ["RULER MARKER LANE"] = "ruler",
    ["RULER TEMPO LANE"] = "ruler",
    -- ["ENV CP"] = "envelope",
}

local CC_LIST = GetCCList()
local ENV_LIST = GetEnvList()

for i = 1, #ENV_LIST do
    local name = ENV_LIST[i]
    DEFAULT_PIE[name:lower()] = { RADIUS = RADIUS_START, name = name:upper(), guid = r.genGuid() }
    DEFAULT_PIE["cp " .. name:lower()] = { RADIUS = RADIUS_START, name = "CP " .. name:upper(), guid = r.genGuid() }
end

local DEFAULT_CC_PIE = {}

for i = -10, #CC_LIST do
    if i ~= 0 then
        local name = CC_LIST[i]
        DEFAULT_CC_PIE[name:lower()] = { RADIUS = RADIUS_START, name = name:upper(), guid = r.genGuid(), is_midi = true }
    end
end

local cur_cc_item = 0
local cur_env_item = 0
local context_cur_item = 1
local menu_items = {
    { "arrange",           "TRACK" },
    { "arrangeempty",      "ARRANGE EMPTY",                  "_separator_" },
    { "tcp",               "TCP" },
    { "tcpfxparm",         "TCP FX PARM" },
    { "tcpempty",          "TCP EMPTY",                      "_separator_" },

    { "mastertcp",         "MASTER TCP" },
    { "mastertcpfxparm",   "MASTER TCP FX PARM",             "_separator_" },

    { "mcp",               "MCP" },
    { "mcpfxlist",         "MCP FX LIST" },
    { "mcpsendlist",       "MCP SEND LIST" },
    { "mcpempty",          "MCP EMPTY",                      "_separator_" },

    { "mastermcp",         "MASTER MCP" },
    { "mastermcpfxlist",   "MASTER MCP FX LIST" },
    { "mastermcpsendlist", "MASTER MCP SEND LIST",           "_separator_" },

    { "envelope",          "ENVELOPE" },
    { "envcp",             "ENVELOPE CONTROL PANEL",         "_separator_" },
    { "item",              "ITEM" },
    { "itemmidi",          "MIDI ITEM",                      "_separator_" },
    { "trans",             "TRANSPORT",                      "_separator_" },

    { "ruler",             "RULER", },
    { "rulerregion_lane",  "RULER REGION LANE", },
    { "rulermarker_lane",  "RULER MARKER LANE", },
    { "rulertempo_lane",   "RULER TEMPO LANE",               "_separator_" },

    { "midi",              "MIDI" },
    { "midipianoroll",     "MIDI PIANO ROLL" },
    { "miditracklist",     "MIDI TRACK LIST" },
    { "midiruler",         "MIDI RULER" },
    { "midilane",          "MIDI LANE",                      "_separator_", (OSX_DISABLE_MIDI_TRACING and true or nil) },
    -- { "midilanecp",   "MIDI LANE CP" },
    { "plugin",            "PLUGIN - NEEDS TRACKER" },
    { "spacer",            "SPACER",                         "_separator_" },
    { "mediaexplorer",     "MEDIA EXPLORER - NEEDS TRACKER", "_separator_" },
}

local PIES = ReadFromFile(pie_file) or Deepcopy(DEFAULT_PIE)

local MIDI_CC_PIES = ReadFromFile(midi_cc_file) or Deepcopy(DEFAULT_CC_PIE)

local function BetaAddContextToData()
    --! REMOVE THIS ON FINAL RELEASE, WAS WORKAROUND FOR ADDING STUFF NOT TO BREAK FILES  --------------------------------

    if not PIES["midipianoroll"] then
        PIES["midipianoroll"] = Deepcopy(PIES["pianoroll"])
        PIES["pianoroll"] = nil
    end
    if not PIES["rulerregion_lane"] then
        PIES["rulerregion_lane"] = {
            RADIUS = RADIUS_START,
            name = "RULER REGION LANE",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "ruler"
        }
        PIES["rulermarker_lane"] = {
            RADIUS = RADIUS_START,
            name = "RULER MARKER LANE",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "ruler"
        }
        PIES["rulertempo_lane"] = {
            RADIUS = RADIUS_START,
            name = "RULER TEMPO LANE",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "ruler"
        }
    end
    if not PIES["miditracklist"] then
        PIES["miditracklist"] = { RADIUS = RADIUS_START, name = "MIDI TRACK LIST", guid = r.genGuid(), is_midi = true }
    end
    if not PIES["mediaexplorer"] then
        PIES["mediaexplorer"] = { RADIUS = RADIUS_START, name = "MEDIA EXPLORER", guid = r.genGuid() }
    end
    if not PIES["ruler"] then
        PIES["ruler"] = { RADIUS = RADIUS_START, name = "RULLER", guid = r.genGuid() }
    else
        if PIES["ruler"].name == "RULLER" then PIES["ruler"].name = "RULER" end
    end
    if PIES["arrange"].name == "ARRANGE" then PIES["arrange"].name = "TRACK" end
    if not PIES["midiruler"] then
        PIES["midiruler"] = { RADIUS = RADIUS_START, name = "MIDI RULER", guid = r.genGuid(), is_midi = true }
        PIES["midilane"] = { RADIUS = RADIUS_START, name = "MIDI LANE", guid = r.genGuid(), is_midi = true }
    end
    if not PIES["plugin"] then
        PIES["plugin"] = { RADIUS = RADIUS_START, name = "PLUGIN", guid = r.genGuid() }
    end

    if not PIES["itemmidi"] then
        PIES["itemmidi"] = { RADIUS = RADIUS_START, name = "MIDI ITEM", guid = r.genGuid() }
    end
    if not PIES["spacer"] then
        PIES["spacer"] = { RADIUS = RADIUS_START, name = "SPACER", guid = r.genGuid() }
    end
    -- if not PIES["pianoroll"] then
    --    PIES["pianoroll"] = { RADIUS = RADIUS_START, name = "PIANO ROLL", guid = r.genGuid(), is_midi = true }
    --end

    -- if not PIES["midilanecp"] then
    --     PIES["midilanecp"] = { RADIUS = RADIUS_START, name = "MIDI LANE CP", guid = r.genGuid(), as_global = true, is_midi = true }
    -- end
    --! REMOVE THIS ON FINAL RELEASE, WAS WORKAROUND FOR ADDING STUFF NOT TO BREAK FILES
    if not PIES["mcpfxlist"] then
        PIES["mcpfxlist"] = {
            RADIUS = RADIUS_START,
            name = "MCP FX LIST",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "mcp"
        }
        PIES["mcpsendlist"] = {
            RADIUS = RADIUS_START,
            name = "MCP SEND LIST",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "mcp"
        }
    end

    if not PIES["tcpfxparm"] then
        PIES["tcpfxparm"] = {
            RADIUS = RADIUS_START,
            name = "TCP FX PARM",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "tcp"
        }
        PIES["mcpfxlist"] = {
            RADIUS = RADIUS_START,
            name = "MCP FX LIST",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "mcp"
        }
        PIES["mcpsendlist"] = {
            RADIUS = RADIUS_START,
            name = "MCP SEND LIST",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "mcp"
        }
        for k, v in pairs(PIES) do
            if MAIN_NAMES[v.name] then
                v.use_main = true
                v.main_name = MAIN_NAMES[v.name]
            end
            if v.sync then v.sync = nil end
        end
    end

    if not PIES["mastertcp"] then
        PIES["mastertcp"] = { RADIUS = RADIUS_START, name = "MASTER TCP", guid = r.genGuid() }
        PIES["mastertcpfxparm"] = {
            RADIUS = RADIUS_START,
            name = "MASTER TCP FX PARM",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "mastertcp"
        }
        PIES["mastermcp"] = { RADIUS = RADIUS_START, name = "MASTER MCP", guid = r.genGuid() }
        PIES["mastermcpfxlist"] = {
            RADIUS = RADIUS_START,
            name = "MASTER MCP FX LIST",
            guid = r.genGuid(),
            use_main = true,
            main_name =
            "mastermcp"
        }
        PIES["mastermcpsendlist"] = {
            RADIUS = RADIUS_START,
            name = "MASTER MCP SEND LIST",
            guid = r.genGuid(),
            use_main = true,
            main_name = "mastermcp"
        }
        PIES["mcpfxlist"].main_name = "mcp"
        PIES["mcpsendlist"].main_name = "mcp"
        PIES["tcpfxparm"].main_name = "tcp"
    end

    --! REMOVE LATER
    -- if not MIDI_CC_PIES["00 bank select msb"] then
    --     for i = -10, #CC_LIST do
    --         if i ~= 0 then
    --             local name = CC_LIST[i]
    --             MIDI_CC_PIES[name:lower()] = { RADIUS = RADIUS_START, name = name:upper(), guid = r.genGuid(), is_midi = true }
    --         end
    --     end
    -- end
    -- if not MIDI_CC_PIES["cp off velocity"] then
    --     for i = -10, #CC_LIST do
    --         if i ~= 0 then
    --             local name = CC_LIST[i]
    --             MIDI_CC_PIES["cp " .. name:lower()] = { RADIUS = RADIUS_START, name = "CP " .. name:upper(), guid = r
    --             .genGuid(), is_midi = true }
    --         end
    --     end
    -- end

    if not PIES["width"] then
        for i = 1, #ENV_LIST do
            local name = ENV_LIST[i]
            PIES[name:lower()] = { RADIUS = RADIUS_START, name = name:upper(), guid = r.genGuid() }
        end
    end

    if not PIES["cp width"] then
        for i = 1, #ENV_LIST do
            local name = ENV_LIST[i]
            PIES["cp " .. name:lower()] = { RADIUS = RADIUS_START, name = "CP " .. name:upper(), guid = r.genGuid() }
        end
    end

    if not PIES["playrate"] then
        PIES["playrate"] = { RADIUS = RADIUS_START, name = "PLAYRATE", guid = r.genGuid() }
        PIES["tempo map"] = { RADIUS = RADIUS_START, name = "TEMPO MAP", guid = r.genGuid() }
    end

    if not PIES["cp playrate"] then
        PIES["cp playrate"] = { RADIUS = RADIUS_START, name = "CP PLAYRATE", guid = r.genGuid() }
        PIES["cp tempo map"] = { RADIUS = RADIUS_START, name = "CP TEMPO MAP", guid = r.genGuid() }
    end

    for k, v in pairs(MIDI_CC_PIES) do
        v.is_midi = true
    end
    PIES["midi"].is_midi = true
    PIES["midiruler"].is_midi = true
    PIES["midilane"].is_midi = true
    PIES["mediaexplorer"].is_explorer = true
    --! REMOVE LATER ------------------------------------------------------------------------------------------------------------------------------------------
end

--BetaAddContextToData() --! REMOVE ON FINAL RELEASE

local MENUS = ReadFromFile(menu_file) or {}

function GetMenus()
    return MENUS
end

local function LinkPieMenusWithSrcMenus(tbl)
    for k, v in pairs(tbl) do
        for i = 1, #v do
            if v[i].menu then
                local parent = InTbl(MENUS, v[i].guid)
                if parent then
                    v[i] = parent
                end
            end
        end
    end
end

LinkPieMenusWithSrcMenus(PIES)
LinkPieMenusWithSrcMenus(MIDI_CC_PIES)

local function LinkMenus(tbl)
    for k, v in ipairs(tbl) do
        tbl[k].guid_list = {}
        for i = 1, #v do
            if type(v[i]) == "table" then
                local parent = InTbl(MENUS, v[i].guid)
                if parent then
                    table.insert(tbl[k].guid_list, v[i].guid)
                    v[i] = parent
                    LinkMenus(v[i])
                end
            end
        end
    end
end

LinkMenus(MENUS)

local CUR_PIE = PIES["arrange"]
local TEMP_MENU = {
    guid = "TEMP",
    RADIUS = RADIUS_START,
    name = "",
    col = 0xff,
    menu = true
}

local CUR_MENU_PIE = MENUS[1] or TEMP_MENU
LAST_MENU_SEL = MENUS[1] and 1 or nil

local KEYS = GetImguiKeys()

local function IterateFiles(dir)
    local tbl = {}
    for index = 0, math.huge do
        local file = r.EnumerateFiles(reaper_path .. dir, index)
        if not file then break end
        if file:lower():find("%.png$") and not file:match("animation") then
            tbl[#tbl + 1] = { name = dir .. file }
        end
    end
    return tbl
end

local PNG_TBL = IterateFiles(png_path)
local PNG_TBL_150 = IterateFiles(png_path_150)
local PNG_TBL_200 = IterateFiles(png_path_200)
local PNG_TBL_TRACK_ICONS = IterateFiles(png_path_track_icons)
local PNG_TBL_CUSTOM_IMAGE = IterateFiles(png_path_custom)

local function ExportToLuaFile(guid, name)
    local lua_string =
    [=[
local r = reaper
local script_path = r.GetResourcePath() .. "/Scripts/Sexan_Scripts/Pie3000/"
package.path = script_path .. "?.lua;"

require('PieUtils')

local menu_file = script_path .. "menu_file.txt"

local MENUS = ReadFromFile(menu_file) or {}
for i = 1, #MENUS do
    if MENUS[i].guid == "%s" then
        STANDALONE_PIE = MENUS[i]
        break
    end
end
if STANDALONE_PIE then
    require('Sexan_Pie3000')
else
    r.ShowConsoleMsg("Menu does not exist")
end
]=]

    local folder = r.GetResourcePath() .. "/Scripts/"
    local path = folder .. "Pie3000_" .. name:gsub("%s", "_") .. ".lua"
    local file = io.open(path, "w")
    if file then
        file:write(lua_string:format(guid))
        file:close()
        local ret = r.AddRemoveReaScript(true, 0, path, 1)
        if ret then
            ADDED_TO_ACTIONS = true
        end
    end
end

local function HasReference(tbl, guid, remove)
    if not tbl.guid_list then return end
    for i = #tbl.guid_list, 1, -1 do
        if tbl.guid_list[i] == guid then
            if remove then
                table.remove(tbl.guid_list, i)
            else
                return i
            end
        end
    end
end

local function MakePieFile()
    local pies = TableToString(PIES)
    local menus = TableToString(MENUS)
    local midi_cc_pies = TableToString(MIDI_CC_PIES)
    SaveToFile(pies, pie_file)
    SaveToFile(menus, menu_file)
    SaveToFile(midi_cc_pies, midi_cc_file)
end

local ROUNDING = {
    ["L"] = r.ImGui_DrawFlags_RoundCornersLeft(),
    ["R"] = r.ImGui_DrawFlags_RoundCornersRight(),
    ["A"] = r.ImGui_DrawFlags_RoundCornersAll(),
}

local function GeneralDrawlistButton(name, active, round_side)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local active = active or r.ImGui_IsItemActive(ctx)

    local color = active and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_ButtonActive()) or
        r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Button())
    color = (not active and r.ImGui_IsItemHovered(ctx)) and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_ButtonHovered()) or
        color
    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye,
        r.ImGui_GetColorEx(ctx, color), ROUNDING[round_side] and 5 or nil, ROUNDING[round_side] or nil)

    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local font_size = r.ImGui_GetFontSize(ctx)

    local txt_x = xs + (w / 2) - (label_size / 2)
    local txt_y = ys + (h / 2) - (font_size / 2)
    r.ImGui_DrawList_AddTextEx(draw_list, nil, font_size, txt_x, txt_y, 0xffffffff, name)
end

local function TabButtons()
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 2)
    local fpad_x, fpad_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
    if r.ImGui_BeginChild(ctx, "custom_tab", nil, 30) then
        r.ImGui_SetCursorPosX(ctx, 30)
        local label_size = r.ImGui_CalcTextSize(ctx, "APPLY Changes")
        if r.ImGui_InvisibleButton(ctx, "APPLY", label_size + (fpad_x * 2), 26) then
            MakePieFile()
        end
        GeneralDrawlistButton("APPLY Changes", nil, "A")
        r.ImGui_SameLine(ctx)

        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), 0, 0)
        r.ImGui_SetCursorPosX(ctx, math.floor(r.ImGui_GetContentRegionAvail(ctx) / 2) - 130)
        local label_size = r.ImGui_CalcTextSize(ctx, "Pie")
        if r.ImGui_InvisibleButton(ctx, "Pie", label_size + (fpad_x * 2), 26) then
            STATE = "PIE"
            UPDATE_FILTER = true
            RefreshImgObj(CUR_PIE)
        end
        GeneralDrawlistButton("Pie", (STATE == "PIE"), "L")
        r.ImGui_SameLine(ctx)
        local label_size = r.ImGui_CalcTextSize(ctx, "Menu Editor")
        if r.ImGui_InvisibleButton(ctx, "Menu Editor", label_size + (fpad_x * 2), 26) then
            STATE = "EDITOR"
            UPDATE_FILTER = true
            RefreshImgObj(CUR_MENU_PIE)
        end
        GeneralDrawlistButton("Menu Editor", STATE == "EDITOR")

        r.ImGui_SameLine(ctx)
        local label_size = r.ImGui_CalcTextSize(ctx, "Settings")
        if r.ImGui_InvisibleButton(ctx, "Settings", label_size + (fpad_x * 2), 26) then
            STATE = "SETTINGS"
        end
        GeneralDrawlistButton("Settings", STATE == "SETTINGS", "R")

        if STATE == "EDITOR" and CUR_MENU_PIE.guid ~= "TEMP" then
            r.ImGui_SameLine(ctx, nil, 100)
            local label_size = r.ImGui_CalcTextSize(ctx, "Export to Action")
            if r.ImGui_InvisibleButton(ctx, "Export to Action", label_size + (fpad_x * 2), 26) then
                ExportToLuaFile(CUR_MENU_PIE.guid, CUR_MENU_PIE.name)
            end
            GeneralDrawlistButton("Export to Action", SETTINGS ~= nil, "A")
        end

        r.ImGui_PopStyleVar(ctx)
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_Separator(ctx)
end

function ModalWarning(is_menu)
    local rv
    r.ImGui_SetNextWindowPos(ctx, vp_center[1], vp_center[2], nil, 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'WARNING', nil, r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_NoMove()) then
        if is_menu then
            r.ImGui_Text(ctx, "This will DELETE Menu from all used Contexts/Submenus.\n\t\t\t\tAre you sure?")
        else
            r.ImGui_Text(ctx, "This will Clear/Delete whole context\nAre you sure?")
        end
        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'OK', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            rv = true
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'CANCEL', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
            r.ImGui_CloseCurrentPopup(ctx)
            if is_menu then
                CLEAR_MENU_PIE = nil
                CLEAR_MENU_PIE_ID = nil
            else
                CLEAR_PIE = nil
            end
        end
        r.ImGui_EndPopup(ctx)
    end
    return rv
end

function DeleteMenu(tbl, guid)
    for i = #tbl, 1, -1 do
        if tbl[i].menu then
            if tbl[i].guid == guid then
                tbl.selected = nil
                table.remove(tbl, i)
            end
        end
        if type(tbl[i]) == "table" then
            DeleteMenu(tbl[i], guid)
        end
    end
end

local function DeleteMenuFromPie(guid, tbl)
    for _, v in pairs(tbl) do
        if type(v) == "table" then
            DeleteMenu(v, guid)
        end
    end
    if #PIE_LIST ~= 0 then
        for i = #PIE_LIST, 1, -1 do
            if PIE_LIST[i][1] and PIE_LIST[i][1].guid == guid then
                table.remove(PIE_LIST, i)
            end
        end
    end
    if #PIE_LIST ~= 0 then
        CUR_PIE = PIE_LIST[#PIE_LIST][1]
    else
        CUR_PIE = PIES[menu_items[context_cur_item][1]]
    end
end

local function Popups()
    if OPEN_WARNING then
        OPEN_WARNING = nil
        r.ImGui_OpenPopup(ctx, "WARNING")
    end

    if ADDED_TO_ACTIONS then
        r.ImGui_OpenPopup(ctx, "ADDED TO ACTIONS")
        ADDED_TO_ACTIONS = nil
    end
    r.ImGui_SetNextWindowPos(ctx, vp_center[1], vp_center[2], nil, 0.5, 0.5)
    if r.ImGui_BeginPopup(ctx, "ADDED TO ACTIONS") then
        r.ImGui_Text(ctx, "\n\t\tADDED " .. "Pie3000_" .. CUR_MENU_PIE.name .. " TO ACTION LIST\t\t\n\n")
        r.ImGui_EndPopup(ctx)
    end

    if CONTEXT_APPLY_WARNING then
        CONTEXT_APPLY_WARNING = nil
        r.ImGui_OpenPopup(ctx, "CONTEXT APPLY WARNING")
    end


    r.ImGui_SetNextWindowPos(ctx, vp_center[1], vp_center[2], nil, 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'CONTEXT APPLY WARNING', nil, r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_NoMove()) then
        r.ImGui_Text(ctx,
            "This will OVERWRITE " ..
            PIES[menu_items[context_cur_item][1]].name .. " context" .. ".\n\t\t\t\tAre you sure?")

        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'OK', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            local cur_context = PIES[menu_items[context_cur_item][1]]
            for i = #cur_context, 1, -1 do
                cur_context[i] = nil
            end
            for i = 1, #MENU_CONTEXT_TBL do
                cur_context[i] = MENU_CONTEXT_TBL[i].menu and MENU_CONTEXT_TBL[i] or Deepcopy(MENU_CONTEXT_TBL[i])
            end
            MENU_CONTEXT_TBL = nil
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'CANCEL', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
            MENU_CONTEXT_TBL = nil
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_EndPopup(ctx)
    end


    if CLEAR_PIE or CLEAR_MENU_PIE then
        if ModalWarning(CLEAR_MENU_PIE) then
            if CLEAR_PIE then
                for i = #CLEAR_PIE, 1, -1 do
                    CLEAR_PIE[i] = nil
                end
                CLEAR_PIE = nil
            elseif CLEAR_MENU_PIE then
                local guid = CLEAR_MENU_PIE.guid
                table.remove(MENUS, CLEAR_MENU_PIE_ID)
                DeleteMenuFromPie(guid, PIES)
                DeleteMenuFromPie(guid, MENUS)
                if MENUS[CLEAR_MENU_PIE_ID] then
                    CUR_MENU_PIE = MENUS[CLEAR_MENU_PIE_ID]
                    LAST_MENU_SEL = CLEAR_MENU_PIE_ID
                else
                    CUR_MENU_PIE = MENUS[#MENUS] or TEMP_MENU
                    LAST_MENU_SEL = #MENUS or nil
                end
                CLEAR_MENU_PIE = nil
                CLEAR_MENU_PIE_ID = nil
                UPDATE_FILTER = true
            end
        end
    end
end

local txt = "PRESS KEY"
local function DetectShortcut(pie)
    r.ImGui_SetNextWindowPos(ctx, vp_center[1], vp_center[2], nil, 0.5, 0.5)
    local close
    if r.ImGui_BeginPopup(ctx, "DETECT_SHORTCUT") then
        for k, v in pairs(KEYS) do
            if r.ImGui_IsKeyPressed(ctx, k) then
                if v == "Escape" then
                    close = true
                    break
                end
                key = k
                break
            end
        end
        r.ImGui_Text(ctx, "\n\t\t" .. txt .. "\t\t\n\n")
        if close then
            r.ImGui_CloseCurrentPopup(ctx)
        end
        if key then
            r.ImGui_CloseCurrentPopup(ctx)
            pie[pie.selected].key = key
            key = nil
            txt = "PRESS KEY"
        end
        if ESC then r.ImGui_CloseCurrentPopup(ctx) end
        r.ImGui_EndPopup(ctx)
    end
end

local function FilterActions(actions, filter_text)
    local t = {}
    for i = 1, #actions do
        local action = actions[i]
        local name = action.name:lower()
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then
            table.insert(t, action)
        end
    end
    return t
end

local PNG_FILTER = ''
local png_tbl = PNG_TBL
local function PngSelector(pie, button_size)
    local ret, png = false, nil
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x - 3, y + 5)
    r.ImGui_SetNextWindowSize(ctx, 500, 400)
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), bg_col)
    local png_path_inner, png_name
    if pie.png then
        png_path_inner = pie.png:match("(.+/)(%S+)")
        png_name = pie.png
    end
    if r.ImGui_BeginPopup(ctx, "Png Selector") then
        r.ImGui_BeginGroup(ctx)
        r.ImGui_Text(ctx, "Toolbar Icons")
        r.ImGui_SameLine(ctx)

        if r.ImGui_RadioButton(ctx, "100", CHOOSE == "100") then
            png_tbl = {}
            RefreshImgObj(PNG_TBL)
            IMG_RESCALE_FACTOR = nil
            png_tbl = PNG_TBL
            CHOOSE = "100"
        end

        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, "150", (CHOOSE == "150")) then
            png_tbl = {}
            RefreshImgObj(PNG_TBL_150)
            IMG_RESCALE_FACTOR = nil
            png_tbl = PNG_TBL_150
            CHOOSE = "150"
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, "200", (CHOOSE == "200")) then
            png_tbl = {}
            RefreshImgObj(PNG_TBL_200)
            IMG_RESCALE_FACTOR = nil
            png_tbl = PNG_TBL_200
            CHOOSE = "200"
        end
        r.ImGui_Text(ctx, "Track Icons    ")
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, "100##ti", (CHOOSE == "30")) then
            png_tbl = {}
            RefreshImgObj(PNG_TBL_TRACK_ICONS)
            IMG_RESCALE_FACTOR = 30
            png_tbl = PNG_TBL_TRACK_ICONS
            CHOOSE = "30"
            if png_name and (png_path_inner:match("track_icons") or png_path_inner:match("CustomImages")) then
                ret = true
                png = png_name
            end
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, "150##ti", (CHOOSE == "45")) then
            png_tbl = {}
            RefreshImgObj(PNG_TBL_TRACK_ICONS)
            IMG_RESCALE_FACTOR = 45
            png_tbl = PNG_TBL_TRACK_ICONS
            CHOOSE = "45"
            if png_name and (png_path_inner:match("track_icons") or png_path_inner:match("CustomImages")) then
                ret = true
                png = png_name
            end
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, "200##ti", (CHOOSE == "60")) then
            png_tbl = {}
            RefreshImgObj(PNG_TBL_TRACK_ICONS)
            IMG_RESCALE_FACTOR = 60
            png_tbl = PNG_TBL_TRACK_ICONS
            CHOOSE = "60"
            if png_name and (png_path_inner:match("track_icons") or png_path_inner:match("CustomImages")) then
                ret = true
                png = png_name
            end
        end
        r.ImGui_Text(ctx, "Custom Icons")
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, "100##ci", (CHOOSE == "30CI")) then
            png_tbl = {}
            RefreshImgObj(PNG_TBL_CUSTOM_IMAGE)
            IMG_RESCALE_FACTOR = 30
            png_tbl = PNG_TBL_CUSTOM_IMAGE
            CHOOSE = "30CI"
            if png_name and (png_path_inner:match("track_icons") or png_path_inner:match("CustomImages")) then
                ret = true
                png = png_name
            end
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, "150##ci", (CHOOSE == "45CI")) then
            png_tbl = {}
            RefreshImgObj(PNG_TBL_CUSTOM_IMAGE)
            IMG_RESCALE_FACTOR = 45
            png_tbl = PNG_TBL_CUSTOM_IMAGE
            CHOOSE = "45CI"
            if png_name and (png_path_inner:match("track_icons") or png_path_inner:match("CustomImages")) then
                ret = true
                png = png_name
            end
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_RadioButton(ctx, "200##ci", (CHOOSE == "60CI")) then
            png_tbl = {}
            RefreshImgObj(PNG_TBL_CUSTOM_IMAGE)
            IMG_RESCALE_FACTOR = 60
            png_tbl = PNG_TBL_CUSTOM_IMAGE
            CHOOSE = "60CI"
            if png_name then
                ret = true
                png = png_name
            end
        end
        r.ImGui_EndGroup(ctx)

        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
        rv_f, PNG_FILTER = r.ImGui_InputTextWithHint(ctx, "##input2", "Search PNG", PNG_FILTER)
        FILTERED_PNG = FilterActions(png_tbl, PNG_FILTER)
        local item_spacing_x, item_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
        item_spacing_x = item_spacing_y
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), item_spacing_y, item_spacing_y)
        local buttons_count = #FILTERED_PNG
        local window_visible_x2 = ({ r.ImGui_GetWindowPos(ctx) })[1] +
            ({ r.ImGui_GetWindowContentRegionMax(ctx) })[1]
        if r.ImGui_BeginChild(ctx, "filtered_pngs_list", 0, 0) then
            for n = 0, #FILTERED_PNG - 1 do
                local image = FILTERED_PNG[n + 1].name
                local xx, yy = r.ImGui_GetCursorPos(ctx)

                r.ImGui_PushID(ctx, n)
                r.ImGui_Dummy(ctx, button_size, button_size) -- PLACE HOLDER

                if not r.ImGui_ValidatePtr(FILTERED_PNG[n + 1].img_obj, 'ImGui_Image*') then
                    FILTERED_PNG[n + 1].img_obj = r.ImGui_CreateImage(reaper_path .. image)
                end
                local uv = ImageUVOffset(FILTERED_PNG[n + 1].img_obj, FILTERED_PNG[n + 1].rescale,
                    image:find("toolbar_icons") and 3 or 1, 1, 0, 0, 0, 1, true)

                r.ImGui_SetCursorPos(ctx, xx, yy)
                if r.ImGui_ImageButton(ctx, "##png_select", FILTERED_PNG[n + 1].img_obj, button_size, button_size, uv[3], uv[4], uv[5], uv[6]) then
                    pie.img_obj = nil
                    ret, png = true, image
                    CHOOSE = nil
                    SCROLL_TO_IMG = nil
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                local minx, miny = r.ImGui_GetItemRectMin(ctx)
                local maxx, maxy = r.ImGui_GetItemRectMax(ctx)
                if png_name == image then
                    r.ImGui_DrawList_AddRect(draw_list, minx, miny, maxx, maxy, 0x00ff00ff, 0, 0, 2)
                    if SCROLL_TO_IMG then
                        SCROLL_TO_IMG = nil
                        r.ImGui_SetScrollHereY(ctx)
                    end
                end

                local next_button_x2 = maxx + item_spacing_x + button_size

                if n + 1 < buttons_count and next_button_x2 < window_visible_x2 then
                    r.ImGui_SameLine(ctx)
                end

                r.ImGui_PopID(ctx)
            end
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_PopStyleVar(ctx)
        r.ImGui_EndPopup(ctx)
    end
    r.ImGui_PopStyleColor(ctx)

    return ret, png, IMG_RESCALE_FACTOR
end

local function PngDisplay(tbl, img_obj, button_size)
    local rv
    r.ImGui_PushID(ctx, "PNG")

    if img_obj and r.file_exists(reaper_path .. tbl.png) then
        if not r.ImGui_ValidatePtr(img_obj, 'ImGui_Image*') then
            img_obj = r.ImGui_CreateImage(reaper_path .. tbl.png)
        end
        local uv = ImageUVOffset(img_obj, tbl.rescale,
            tbl.png:find("toolbar_icons") and 3 or 1, 1, 0, 0, 0, 1, true)
        if r.ImGui_ImageButton(ctx, "##prev_png", img_obj, button_size - 6, button_size - 6, uv[3], uv[4], uv[5], uv[6]) then
            if not ALT then
                rv = true
                if tbl.png then
                    local png_path_inner = tbl.png:match("(.+/)(%S+)")
                    if not tbl.rescale then
                        if png_path_inner:match("150") then
                            png_tbl = {}
                            RefreshImgObj(PNG_TBL_150)
                            CHOOSE = "150"
                            png_tbl = PNG_TBL_150
                        elseif png_path_inner:match("200") then
                            png_tbl = {}
                            RefreshImgObj(PNG_TBL_200)
                            CHOOSE = "200"
                            png_tbl = PNG_TBL_200
                        else
                            png_tbl = {}
                            RefreshImgObj(PNG_TBL)
                            CHOOSE = "100"
                            png_tbl = PNG_TBL
                        end
                    else
                        IMG_RESCALE_FACTOR = tbl.rescale
                        if png_path_inner:match("track_icons") then
                            png_tbl = {}
                            CHOOSE = tostring(tbl.rescale)
                            RefreshImgObj(PNG_TBL_TRACK_ICONS)
                            png_tbl = PNG_TBL_TRACK_ICONS
                        elseif png_path_inner:match("CustomImages") then
                            png_tbl = {}
                            CHOOSE = tbl.rescale .. "CI"
                            RefreshImgObj(PNG_TBL_CUSTOM_IMAGE)
                            png_tbl = PNG_TBL_CUSTOM_IMAGE
                        end
                    end
                    SCROLL_TO_IMG = true
                end
            else
                tbl.png = nil
                tbl.img_obj = nil
            end
        end
    else
        if r.ImGui_Button(ctx, "IMG", button_size, button_size) then
            RefreshImgObj(PNG_TBL)
            CHOOSE = "100"
            png_tbl = PNG_TBL
            rv = true
        end
    end
    r.ImGui_PopID(ctx)
    return rv
end

local function PngFrame(pie, size)
    if PngDisplay(pie[pie.selected], pie[pie.selected].img_obj, size or 20) then
        for i = 1, #PNG_TBL do
            PNG_TBL[i].img_obj = nil
        end
        PNG_FILTER = ''
        r.ImGui_OpenPopup(ctx, 'Png Selector')
    end
    local rv, png, rescale = PngSelector(pie[pie.selected], 24)
    return rv, png, rescale
end

ICON = ''
local letters = {}
for i = 33, 254 do letters[#letters + 1] = utf8.char(i) end

local function IconSelector(font, button_size)
    local ret, icon = false, nil
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x - 3, y + 5)
    r.ImGui_SetNextWindowSize(ctx, 500, 470)
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), bg_col)
    if r.ImGui_BeginPopup(ctx, "Icon Selector") then
        r.ImGui_PushFont(ctx, font)
        local item_spacing_x, item_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
        item_spacing_x = item_spacing_y
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), item_spacing_y, item_spacing_y)
        local buttons_count = #letters
        local window_visible_x2 = ({ r.ImGui_GetWindowPos(ctx) })[1] +
            ({ r.ImGui_GetWindowContentRegionMax(ctx) })[1]
        for n = 0, #letters - 1 do
            local letter = letters[n + 1]
            r.ImGui_PushID(ctx, n)
            if r.ImGui_Button(ctx, letter, button_size, button_size) then
                ret, icon = true, letter
                r.ImGui_CloseCurrentPopup(ctx)
            end
            local last_button_x2 = r.ImGui_GetItemRectMax(ctx)
            local next_button_x2 = last_button_x2 + item_spacing_x + button_size
            if n + 1 < buttons_count and next_button_x2 < window_visible_x2 then
                r.ImGui_SameLine(ctx)
            end
            r.ImGui_PopID(ctx)
        end
        r.ImGui_PopFont(ctx)
        r.ImGui_PopStyleVar(ctx)
        r.ImGui_EndPopup(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
    return ret, icon
end

local function IconDisplay(font, tbl, icon, button_size)
    r.ImGui_PushFont(ctx, icon and font or GUI_FONT)
    r.ImGui_PushID(ctx, "ICON")
    local rv
    if r.ImGui_Button(ctx, icon or "ICON", button_size, button_size) then
        if not ALT then
            rv = true
        else
            tbl.icon = nil
        end
    end
    r.ImGui_PopID(ctx)
    r.ImGui_PopFont(ctx)
    return rv
end

local function IconFrame(pie, size)
    if IconDisplay(ICON_FONT_LARGE, pie[pie.selected], pie[pie.selected].icon, size or 20) then
        r.ImGui_OpenPopup(ctx, 'Icon Selector')
    end
    local rv, icon = IconSelector(ICON_FONT_PREVIEW, 24)
    return rv, icon
end

local function NewProperties(pie)
    if STATE == "SETTINGS" then return end
    if r.ImGui_BeginChild(ctx, "PROPERTIES", 0, 147, true) then
        if pie.selected then
            LAST_MSG = pie[pie.selected].name
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0)
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            r.ImGui_InputText(ctx, "##ID",
                pie[pie.selected].menu and pie[pie.selected].name or pie[pie.selected].cmd_name,
                r.ImGui_InputTextFlags_ReadOnly())
            r.ImGui_PopStyleColor(ctx)
            r.ImGui_Separator(ctx)
            r.ImGui_BeginGroup(ctx)
            r.ImGui_PushID(ctx, "col_remove")
            if r.ImGui_Button(ctx, "X", 0, 50) then pie[pie.selected].col = 0xff end
            r.ImGui_PopID(ctx)
            r.ImGui_SameLine(ctx)
            if r.ImGui_ColorButton(ctx, "Button Color", pie[pie.selected].col, nil, 50, 50) then
                r.ImGui_OpenPopup(ctx, "ColorPickerXYZ")
            end
            r.ImGui_EndGroup(ctx)
            r.ImGui_SameLine(ctx)
            r.ImGui_SetNextWindowPos(ctx, r.ImGui_GetCursorScreenPos(ctx))
            if r.ImGui_BeginPopupContextItem(ctx, "ColorPickerXYZ", r.ImGui_ButtonFlags_MouseButtonLeft()) then
                rv, pie[pie.selected].col = r.ImGui_ColorPicker4(ctx, '##MyColor##5', pie[pie.selected].col,
                    r.ImGui_ColorEditFlags_PickerHueBar() | r.ImGui_ColorEditFlags_NoSidePreview()
                )
                r.ImGui_EndPopup(ctx)
            end
            r.ImGui_SameLine(ctx)
            r.ImGui_BeginGroup(ctx)

            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), bg_col)
            r.ImGui_SetCursorPosX(ctx, 120)
            local rv_i, icon = IconFrame(pie, 50)
            if rv_i then
                pie[pie.selected].icon = icon
                if pie[pie.selected].png then
                    pie[pie.selected].rescale = nil
                    pie[pie.selected].png = nil
                    pie[pie.selected].img_obj = nil
                end
            end
            r.ImGui_SameLine(ctx)
            local rv_png, png, rescale = PngFrame(pie, 50)
            if rv_png then
                pie[pie.selected].png = png
                pie[pie.selected].rescale = rescale
                if pie[pie.selected].icon then
                    pie[pie.selected].icon = nil
                end
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, "CLEAR", 50, 50) then
                pie[pie.selected].rescale = nil
                pie[pie.selected].png = nil
                pie[pie.selected].img_obj = nil
                pie[pie.selected].icon = nil
            end
            r.ImGui_PopStyleColor(ctx)
            r.ImGui_EndGroup(ctx)
            -- ICON / PNG
            r.ImGui_PushID(ctx, "txt_remove")
            r.ImGui_Separator(ctx)
            if r.ImGui_Button(ctx, "X") then pie[pie.selected].name = "" end
            r.ImGui_PopID(ctx)
            r.ImGui_SameLine(ctx)
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            rv_i, pie[pie.selected].name = r.ImGui_InputTextWithHint(ctx, "##ButtonName", "Button name",
                pie[pie.selected].name)
            r.ImGui_PushID(ctx, "sct_remove")
            if r.ImGui_Button(ctx, "X") then pie[pie.selected].key = nil end
            r.ImGui_PopID(ctx)
            r.ImGui_SameLine(ctx)
            if r.ImGui_Button(ctx, pie[pie.selected].key and "Key " .. KEYS[pie[pie.selected].key] or "ASSIGN KEY", -FLT_MIN) then
                r.ImGui_OpenPopup(ctx, "DETECT_SHORTCUT")
            end
            DetectShortcut(pie)
        else
            LAST_MSG = pie.name
            r.ImGui_Text(ctx, "Radius")
            r.ImGui_SameLine(ctx)
            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            RV_R, pie.RADIUS = r.ImGui_SliderInt(ctx, "##RADIUS", pie.RADIUS, 50, 270)
            if STATE == "PIE" then
                if #PIE_LIST == 0 then
                    if MAIN_NAMES[pie.name] then
                        if r.ImGui_Checkbox(ctx, "USE MAIN CONTEXT - " .. pie.main_name, pie.use_main) then
                            pie.use_main = not pie.use_main
                        end
                    end

                    if r.ImGui_Button(ctx, "Clear Context") then
                        OPEN_WARNING = true
                        CLEAR_PIE = pie
                    end
                    r.ImGui_SameLine(ctx)
                    if r.ImGui_Button(ctx, "Create Menu from Context") then
                        MENUS[#MENUS + 1] = {
                            guid = r.genGuid(),
                            RADIUS = 150,
                            name = CUR_PIE.name .. " CONTEXT MENU",
                            col = 0xff,
                            menu = true,
                            guid_list = {}
                        }
                        for i = 1, #CUR_PIE do
                            MENUS[#MENUS][i] = CUR_PIE[i].menu and CUR_PIE[i] or Deepcopy(CUR_PIE[i])
                        end
                    end
                    if pie.name == "MIDI LANE" or pie.name == "MIDI LANE CP" or pie.name == "ENVELOPE" or pie.name == "ENV CP" then
                        if r.ImGui_Checkbox(ctx, "Use as Default for all Lanes", pie.as_global) then
                            pie.as_global = not pie.as_global
                        end
                    end
                end
            else
                if pie and pie.guid ~= "TEMP" then
                    r.ImGui_Text(ctx, "Name  ")
                    r.ImGui_SameLine(ctx)
                    r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
                    rv_i, pie.name = r.ImGui_InputTextWithHint(ctx, "##ButtonName", "Button name", pie.name)
                    if r.ImGui_Button(ctx, "Delete Menu") and LAST_MENU_SEL then
                        OPEN_WARNING = true
                        CLEAR_MENU_PIE = pie
                        CLEAR_MENU_PIE_ID = LAST_MENU_SEL
                    end
                end
            end
        end
        r.ImGui_EndChild(ctx)
    end
end

local function Settings()
    if STATE ~= "SETTINGS" then return end
    r.ImGui_SeparatorText(ctx, "OPENING BEHAVIOR")
    r.ImGui_Indent(ctx, 0)

    if STYLE == 3 then
        r.ImGui_BeginDisabled(ctx, true)
    end
    if r.ImGui_Checkbox(ctx, "Animation", ANIMATION) then
        ANIMATION = not ANIMATION
        WANT_SAVE = true
    end
    if STYLE == 3 then
        r.ImGui_EndDisabled(ctx)
    end
    if r.ImGui_Checkbox(ctx, "Hold Key to OPEN Script (DISABLED = TOGGLE Open/Close)", HOLD_TO_OPEN) then
        HOLD_TO_OPEN = not HOLD_TO_OPEN
        WANT_SAVE = true
    end
    if not HOLD_TO_OPEN then
        r.ImGui_Indent(ctx, 0)
        if r.ImGui_Checkbox(ctx, "Close script when Action is Clicked", CLOSE_ON_ACTIVATE) then
            CLOSE_ON_ACTIVATE = not CLOSE_ON_ACTIVATE
            WANT_SAVE = true
        end
        r.ImGui_Unindent(ctx)
    end
    if r.ImGui_Checkbox(ctx, "Select thing (Track/Item) under mouse", SELECT_THING_UNDER_MOUSE) then
        SELECT_THING_UNDER_MOUSE = not SELECT_THING_UNDER_MOUSE
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "Activate hovered action when closing script", ACTIVATE_ON_CLOSE) then
        ACTIVATE_ON_CLOSE = not ACTIVATE_ON_CLOSE
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "Kill the script when ESC key is pressed", KILL_ON_ESC) then
        KILL_ON_ESC = not KILL_ON_ESC
        WANT_SAVE = true
    end
    r.ImGui_Unindent(ctx)
    r.ImGui_SeparatorText(ctx, "GENERAL BEHAVIOR")
    r.ImGui_Indent(ctx, 0)

    if r.ImGui_Checkbox(ctx, "Revert mouse to starting position when script Closes", REVERT_TO_START) then
        REVERT_TO_START = not REVERT_TO_START
        WANT_SAVE = true
    end
    if r.ImGui_Checkbox(ctx, "Re-Center mouse when new/previous menu opens", RESET_POSITION) then
        RESET_POSITION = not RESET_POSITION
        WANT_SAVE = true
    end
    if STYLE == 3 then
        r.ImGui_BeginDisabled(ctx, true)
    end
    if r.ImGui_Checkbox(ctx, "Limit mouse movement to Pie radius", LIMIT_MOUSE) then
        LIMIT_MOUSE = not LIMIT_MOUSE
        WANT_SAVE = true
    end
    if STYLE == 3 then
        r.ImGui_EndDisabled(ctx)
    end
    if r.ImGui_Checkbox(ctx, "Re-Adjust Pie position when mouse is near edges of screen (Fit Pie into Screen)", ADJUST_PIE_NEAR_EDGE) then
        ADJUST_PIE_NEAR_EDGE = not ADJUST_PIE_NEAR_EDGE
        WANT_SAVE = true
    end
    if STYLE == 3 then
        r.ImGui_BeginDisabled(ctx, true)
    end
    if r.ImGui_Checkbox(ctx, "Show shortcut buttons around Pie", SHOW_SHORTCUT) then
        SHOW_SHORTCUT = not SHOW_SHORTCUT
        WANT_SAVE = true
    end

    if r.ImGui_Checkbox(ctx, "SWIPE (Menus only) - Open menu when mouse is swiped in its direction", SWIPE) then
        SWIPE = not SWIPE
        WANT_SAVE = true
    end
    if SWIPE then
        r.ImGui_Indent(ctx, 0)
        RV_SW, SWIPE_TRESHOLD = r.ImGui_SliderInt(ctx, "Threshold in Pixel - How fast mouse should Move", SWIPE_TRESHOLD,
            20, 100)
        RV_SWC, SWIPE_CONFIRM = r.ImGui_SliderInt(ctx, "Confirm Delay MS - Small delay to open menu", SWIPE_CONFIRM, 20,
            150)
        if RV_SW or RV_SWC then
            WANT_SAVE = true
        end
        r.ImGui_Unindent(ctx)
    end
    if STYLE == 3 then
        r.ImGui_EndDisabled(ctx)
    end

    r.ImGui_Unindent(ctx)

    r.ImGui_SeparatorText(ctx, "Pie Style")
    if r.ImGui_RadioButton(ctx, "MODERN", STYLE == 1) then
        STYLE = 1
        WANT_SAVE = true
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_RadioButton(ctx, "TEXT BUTTONS", STYLE == 2) then
        STYLE = 2
        WANT_SAVE = true
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_RadioButton(ctx, "DROP DOWN MENU", STYLE == 3) then
        STYLE = 3
        WANT_SAVE = true
    end
    r.ImGui_Separator(ctx)
    if IsOSX() then
        r.ImGui_SeparatorText(ctx, "OSX Specific")
        r.ImGui_Indent(ctx, 0)
        if r.ImGui_RadioButton(ctx, "DISABLE Midi CC Tracing (stores small png file of midi)", OSX_DISABLE_MIDI_TRACING == true) then
            OSX_DISABLE_MIDI_TRACING = not OSX_DISABLE_MIDI_TRACING
            WANT_SAVE = true
        end
        r.ImGui_Unindent(ctx)
        r.ImGui_Separator(ctx)
    end
    local fpad_x, fpad_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
    local label_size = r.ImGui_CalcTextSize(ctx, "OPEN CUSTOM IMAGES FOLDER")
    if r.ImGui_InvisibleButton(ctx, "OPEN CUSTOM IMAGES FOLDER", label_size + (fpad_x * 2), 26) then
        -- local cmd
        -- if r.GetOS():sub(1, 3) == 'Win' then
        --     cmd = 'cmd.exe /c explorer'
        -- else
        --     cmd = 'open'
        -- end
        r.CF_ShellExecute(r.GetResourcePath() .. png_path_custom:gsub("/", os_separator))
        -- r.ShowConsoleMsg(([[%s "%s"]]):format(cmd, r.GetResourcePath() .. png_path_custom:gsub("/", os_separator)) ..
        -- "\n")
        -- r.ExecProcess(([[%s "%s"]]):format(cmd, r.GetResourcePath() .. png_path_custom:gsub("/", os_separator)), 0)
    end
    GeneralDrawlistButton("OPEN CUSTOM IMAGES FOLDER", nil, "A")
    r.ImGui_SameLine(ctx, 0, 100)
    if r.ImGui_Checkbox(ctx, "MIDI DEBUG", MIDI_TRACE_DEBUG) then
        MIDI_TRACE_DEBUG = not MIDI_TRACE_DEBUG
        WANT_SAVE = true
    end

    if WANT_SAVE then
        local data = TableToString(
            {
                animation = ANIMATION,
                hold_to_open = HOLD_TO_OPEN,
                activate_on_close = ACTIVATE_ON_CLOSE,
                limit_mouse = LIMIT_MOUSE,
                reset_position = RESET_POSITION,
                revert_to_start = REVERT_TO_START,
                swipe = SWIPE,
                swipe_treshold = SWIPE_TRESHOLD,
                swipe_confirm = SWIPE_CONFIRM,
                show_shortcut = SHOW_SHORTCUT,
                select_thing_under_mouse = SELECT_THING_UNDER_MOUSE,
                adjust_pie_near_edge = ADJUST_PIE_NEAR_EDGE,
                close_on_activate = CLOSE_ON_ACTIVATE,
                midi_trace_debug = MIDI_TRACE_DEBUG,
                kill_on_esc = KILL_ON_ESC,
                style = STYLE,
                osx_midi_tracing = OSX_DISABLE_MIDI_TRACING

            }, true)
        r.SetExtState("PIE3000", "SETTINGS", data, true)
        WANT_SAVE = nil
    end
end

local function ContextSelector()
    local w, h = r.ImGui_GetItemRectSize(ctx)
    local x, y = r.ImGui_GetCursorScreenPos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x, y)
    r.ImGui_SetNextWindowSize(ctx, w, 520)
    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), bg_col)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_SeparatorTextPadding(), 0, 0)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), 0, 4)
    if r.ImGui_BeginPopup(ctx, "Context Selector") then
        r.ImGui_Dummy(ctx, 520, 10)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), bg_col)
        for i = 1, #menu_items do
            if not menu_items[i][4] then -- EXCLUDE MIDI LANE ON OSX IF DISABLED
                if r.ImGui_Selectable(ctx, "\t\t\t\t\t\t\t\t\t\t" .. menu_items[i][2], i == context_cur_item) then
                    if menu_items[i][2] == "MIDI LANE" then
                        if cur_cc_item ~= 0 then
                            SWITCH_PIE = menu_items[i][2] == "MIDI LANE" and
                                MIDI_CC_PIES
                                [CC_LIST[cur_cc_item]:lower()]
                        else
                            SWITCH_PIE = PIES[menu_items[i][1]]
                        end
                    else
                        SWITCH_PIE = PIES[menu_items[i][1]]
                    end
                    PIE_LIST = {}
                    context_cur_item = i
                    r.ImGui_CloseCurrentPopup(ctx)
                    UPDATE_FILTER = true
                end
            end
            if menu_items[i][3] and i ~= #menu_items then
                r.ImGui_SeparatorText(ctx, "")
            end
        end
        r.ImGui_Dummy(ctx, 520, 10)
        r.ImGui_PopStyleColor(ctx)
        r.ImGui_EndPopup(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleColor(ctx)
end

local function CustomDropDown()
    if r.ImGui_Button(ctx, menu_items[context_cur_item][2], -FLT_MIN) then
        r.ImGui_OpenPopup(ctx, 'Context Selector')
    end
    ContextSelector()
end

local function BreadCrumbs(tbl)
    if not r.ImGui_ValidatePtr(SPLITTER_BC, 'ImGui_DrawListSplitter*') then
        SPLITTER_BC = r.ImGui_CreateDrawListSplitter(draw_list)
    end
    r.ImGui_DrawListSplitter_Split(SPLITTER_BC, 20)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), 0, 0)

    for j = 0, #tbl do
        local color = j == #tbl and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_ButtonActive()) or
            r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Button())
        color = j == 0 and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Button()) or color

        local txt_w, txt_h = r.ImGui_CalcTextSize(ctx, j == 0 and "H" or PIE_LIST[j].name)
        r.ImGui_PushID(ctx, "btn_bx" .. j)
        if r.ImGui_InvisibleButton(ctx, "##BC", txt_w + (j == 0 and 18 or 30), 20) then
            if j == 0 and #tbl ~= 0 then
                if menu_items[context_cur_item][2] == "MIDI LANE" then
                    SWITCH_PIE = cur_cc_item == 0 and PIES[menu_items[context_cur_item][1]] or
                        MIDI_CC_PIES[CC_LIST[cur_cc_item]:lower()]
                elseif menu_items[context_cur_item][2] == "ENVELOPE" then
                    SWITCH_PIE = cur_env_item == 0 and PIES["envelope"] or PIES[ENV_LIST[cur_env_item]:lower()]
                elseif menu_items[context_cur_item][2] == "ENVELOPE CONTROL PANEL" then
                    SWITCH_PIE = cur_env_item == 0 and PIES["envcp"] or PIES["cp " .. ENV_LIST[cur_env_item]:lower()]
                else
                    SWITCH_PIE = PIES[menu_items[context_cur_item][1]]
                end
                CLEAR_PIE_LIST = 0
                SWITCH_PIE.selected = nil
            else
                if j < #tbl then
                    CLEAR_PIE_LIST = j
                    SWITCH_PIE = PIE_LIST[j + 1].pid
                    SWITCH_PIE.selected = nil
                end
            end
        end
        if j == 0 then
            DrawTooltip("Return to " .. menu_items[context_cur_item][2])
        end
        color = r.ImGui_IsItemHovered(ctx) and r.ImGui_GetStyleColor(ctx, r.ImGui_Col_ButtonHovered()) or color
        r.ImGui_PopID(ctx)
        local xs, ys = r.ImGui_GetItemRectMin(ctx)
        local xe, ye = r.ImGui_GetItemRectMax(ctx)
        local w, h = r.ImGui_GetItemRectSize(ctx)

        local off = 4
        r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER_BC, #tbl - j)
        for i = 1, 0, -1 do
            r.ImGui_DrawList_PathLineTo(draw_list, xs + (off * i), ys)
            r.ImGui_DrawList_PathLineTo(draw_list, xe + (off * i), (ye - h))
            if j < #tbl then
                r.ImGui_DrawList_PathLineTo(draw_list, (xe + 10) + (off * i), (ye - h + h / 2))
            end
            r.ImGui_DrawList_PathLineTo(draw_list, xe + (off * i), ye)
            r.ImGui_DrawList_PathLineTo(draw_list, xe + (off * i), ye)
            r.ImGui_DrawList_PathLineTo(draw_list, xs + (off * i), ys + h)
            r.ImGui_DrawList_PathFillConvex(draw_list, i == 0 and color or bg_col)
        end
        local txt_x = xs + (w / 2) - (txt_w / 2) + (j == 0 and -3 or 5)
        local txt_y = ys + (h / 2) - (txt_h / 2)
        if j == 0 then
            r.ImGui_PushFont(ctx, ICON_FONT_PREVIEW)
        end
        r.ImGui_DrawList_AddTextEx(draw_list, nil, j == 0 and 16 or 14, txt_x, txt_y,
            0xffffffff, j == 0 and "H" or PIE_LIST[j].name)
        if j == 0 then
            r.ImGui_PopFont(ctx)
        end
        r.ImGui_SameLine(ctx)
    end
    r.ImGui_DrawListSplitter_Merge(SPLITTER_BC)
    r.ImGui_PopStyleVar(ctx)
end

function DNDSwapSRC(tbl, k)
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptBeforeDelivery()) then
        r.ImGui_SetDragDropPayload(ctx, 'DND_SWAP', tostring(k))
        r.ImGui_Text(ctx, tbl[k].name)
        r.ImGui_EndDragDropSource(ctx)
    end
end

function DNDSwapDST(tbl, k, v)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local RV_P, PAYLOAD = r.ImGui_AcceptDragDropPayload(ctx, 'DND_SWAP')
        if RV_P then
            local payload_n = tonumber(PAYLOAD)
            tbl[k] = tbl[payload_n]
            tbl[payload_n] = v
        end
        r.ImGui_EndDragDropTarget(ctx)
    end
end

local function DndSourceAction(tbl)
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptBeforeDelivery()) then
        r.ImGui_SetDragDropPayload(ctx, 'DND ACTION', tbl.name .. "|" .. tbl.cmd)
        r.ImGui_Text(ctx, tbl.name)
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function DndSourceMenu(tbl, i)
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptBeforeDelivery()) then
        r.ImGui_SetDragDropPayload(ctx, 'DND Menu', i)
        r.ImGui_Text(ctx, tbl.name)
        r.ImGui_EndDragDropSource(ctx)
    end
end


local pattern = { ".lua", "Script: " }
local function NameStrip(name)
    local new_name = name
    for i = 1, #pattern do
        new_name = new_name:gsub(pattern[i], "")
    end
    new_name = new_name:gsub("_", " ")
    return new_name
end

function DndAddTargetAction(pie, button)
    if pie.guid == "TEMP" then return end
    if r.ImGui_BeginDragDropTarget(ctx) then
        local retv, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND ACTION')
        local name, cmd = payload:match("(.+)|(.+)")
        r.ImGui_EndDragDropTarget(ctx)
        if retv then
            local new_name = NameStrip(name)
            if not button then
                local insert_pos = #pie ~= 0 and #pie or 1
                table.insert(pie, insert_pos,
                    { name = new_name, cmd = cmd, cmd_name = name, col = 0xff })
                pie.selected = insert_pos
            else
                button.cmd = cmd
                button.cmd_name = name
                button.name = new_name
            end
        end
    end
end

function DndAddTargetMenu(pie, button, i)
    if pie.guid == "TEMP" then return end
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND Menu')
        local menu_id = tonumber(payload)
        r.ImGui_EndDragDropTarget(ctx)
        local prev_guid
        if ret then
            if pie ~= MENUS[menu_id] then
                CROSS_MENU = HasReference(MENUS[menu_id], pie.guid)
                if not CROSS_MENU then
                    local insert_pos = #pie ~= 0 and #pie or 1
                    if not button then
                        table.insert(pie, insert_pos, MENUS[menu_id])
                    else
                        prev_guid = pie[1].guid
                        button[1] = MENUS[menu_id]
                    end
                    if pie.guid_list then
                        if not button then
                            table.insert(pie.guid_list, MENUS[menu_id].guid)
                        else
                            for j = 1, #pie.guid_list do
                                if pie.guid_list[j] == prev_guid then
                                    pie.guid_list[j] = MENUS[menu_id].guid
                                end
                            end
                        end
                    end
                    pie.selected = insert_pos
                end
            else
                SELF_INSERT = true
            end
        end
    end
end

function DndAddAsContext(pie)
    if pie.guid == "TEMP" then return end
    if r.ImGui_BeginDragDropTarget(ctx) then
        local retv, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND Menu')
        local menu_id = tonumber(payload)
        r.ImGui_EndDragDropTarget(ctx)
        if retv then
            MENU_CONTEXT_TBL = MENUS[menu_id]
            CONTEXT_APPLY_WARNING = true
        end
    end
end

local function HasMenu(tbl)
    local nested = {}
    if not tbl then return nested end
    for j = 1, #tbl do
        if tbl[j].menu then
            for i = 1, #MENUS do
                if MENUS[i] == tbl[j] then
                    nested[tbl[j]] = true
                end
            end
        end
    end
    return nested
end

local FILTERED_EDIT_MENU_TBL = MENUS
local EDITOR_MENU_FILTER = ''

local function MenuEditList(pie)
    if r.ImGui_BeginChild(ctx, "EDITMENULIST", 180, 0, true) then
        if r.ImGui_Button(ctx, 'Create New Menu', -FLT_MIN, 0) then
            MENUS[#MENUS + 1] = {
                guid = r.genGuid(),
                RADIUS = 150,
                name = "MENU " .. #MENUS,
                col = 0xff,
                menu = true,
                guid_list = {}
            }
            LAST_MENU_SEL = #MENUS
            SWITCH_PIE = MENUS[#MENUS]
            UPDATE_FILTER = true
        end
        r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
        rv_emf, EDITOR_MENU_FILTER = r.ImGui_InputTextWithHint(ctx, "##input2", "Search Menu List", EDITOR_MENU_FILTER)
        if rv_emf or UPDATE_FILTER then
            UPDATE_CNT = UPDATE_FILTER and UPDATE_CNT + 1 or UPDATE_CNT
            FILTERED_EDIT_MENU_TBL = FilterActions(MENUS, EDITOR_MENU_FILTER)
        end
        if not r.ImGui_ValidatePtr(MENU_EDIT_CLIPPER, 'ImGui_ListClipper*') then
            MENU_EDIT_CLIPPER = r.ImGui_CreateListClipper(ctx)
        end
        r.ImGui_ListClipper_Begin(MENU_EDIT_CLIPPER, #FILTERED_EDIT_MENU_TBL)
        while r.ImGui_ListClipper_Step(MENU_EDIT_CLIPPER) do
            local display_start, display_end = r.ImGui_ListClipper_GetDisplayRange(MENU_EDIT_CLIPPER)
            for i = display_start, display_end - 1 do
                local inserted_menus = HasMenu(FILTERED_EDIT_MENU_TBL[LAST_MENU_SEL])
                local CROSS_MENU = pie and HasReference(FILTERED_EDIT_MENU_TBL[i + 1], pie.guid) or nil
                local SAME_MENU = pie == FILTERED_EDIT_MENU_TBL[i + 1]
                r.ImGui_PushID(ctx, i + 1)
                if r.ImGui_Selectable(ctx, (inserted_menus[FILTERED_EDIT_MENU_TBL[i + 1]] and " - " or "") .. FILTERED_EDIT_MENU_TBL[i + 1].name .. (CROSS_MENU and " - HAS REFERENCE" or ""), LAST_MENU_SEL == i + 1) then
                    LAST_MENU_SEL = i + 1
                    SWITCH_PIE = FILTERED_EDIT_MENU_TBL[i + 1]
                end
                r.ImGui_PopID(ctx)
                local xs, ys = r.ImGui_GetItemRectMin(ctx)
                local xe, ye = r.ImGui_GetItemRectMax(ctx)
                -- SELECTED
                if pie and pie.guid == FILTERED_EDIT_MENU_TBL[i + 1].guid then
                    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x22FF2255)
                end
                -- ALREADY HAS REFERENCE
                if CROSS_MENU then
                    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0xFF222255)
                end
                if inserted_menus[FILTERED_EDIT_MENU_TBL[i + 1]] then
                    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x8cbef944)
                end
                if not CROSS_MENU and not SAME_MENU then
                    DndSourceMenu(FILTERED_EDIT_MENU_TBL[i + 1], i + 1)
                end
            end
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_SameLine(ctx)
end

local function EnvLaneSelector(cp)
    local txt_w = r.ImGui_CalcTextSize(ctx, ENV_LIST[cur_env_item])
    local w = txt_w + 25
    if r.ImGui_BeginChild(ctx, "Envlaneeeee", w, 25) then
        local child_hovered = r.ImGui_IsWindowHovered(ctx,
            r.ImGui_HoveredFlags_ChildWindows() |  r.ImGui_HoveredFlags_AllowWhenBlockedByPopup() |
            r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem())
        if r.ImGui_BeginMenu(ctx, ENV_LIST[cur_env_item], true) then
            for i = 0, #ENV_LIST do
                if r.ImGui_MenuItem(ctx, ENV_LIST[i], nil, cur_env_item == i, true) then
                    cur_env_item = i
                    if cp then
                        SWITCH_PIE = i == 0 and PIES["envcp"] or PIES["cp " .. ENV_LIST[cur_env_item]:lower()]
                    else
                        SWITCH_PIE = i == 0 and PIES["envelope"] or PIES[ENV_LIST[cur_env_item]:lower()]
                    end
                end
                if i == 0 then
                    r.ImGui_Separator(ctx)
                end
            end

            if not child_hovered then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndMenu(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
end
local function MidiLaneSelector(cp)
    local txt_w = r.ImGui_CalcTextSize(ctx, CC_LIST[cur_cc_item])
    local w = txt_w + 25
    if r.ImGui_BeginChild(ctx, "laneeeee", w, 25) then
        local child_hovered = r.ImGui_IsWindowHovered(ctx,
            r.ImGui_HoveredFlags_ChildWindows() |  r.ImGui_HoveredFlags_AllowWhenBlockedByPopup() |
            r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem())
        if r.ImGui_BeginMenu(ctx, CC_LIST[cur_cc_item], true) then
            for i = 0, -10, -1 do
                if r.ImGui_MenuItem(ctx, CC_LIST[i], nil, cur_cc_item == i, true) then
                    cur_cc_item = i
                    SWITCH_PIE = i == 0 and PIES["midilane"] or MIDI_CC_PIES[CC_LIST[cur_cc_item]:lower()]
                end
                if i == 0 or i == -10 then r.ImGui_Separator(ctx) end
            end
            if r.ImGui_BeginMenu(ctx, "CC 0-30", true) then
                for i = 1, 30 do
                    if r.ImGui_MenuItem(ctx, CC_LIST[i], nil, cur_cc_item == i, true) then
                        cur_cc_item = i
                        SWITCH_PIE = MIDI_CC_PIES[CC_LIST[cur_cc_item]:lower()]
                    end
                end
                r.ImGui_EndMenu(ctx)
            end
            if r.ImGui_BeginMenu(ctx, "CC 30-60", true) then
                for i = 30, 60 do
                    if r.ImGui_MenuItem(ctx, CC_LIST[i], nil, cur_cc_item == i, true) then
                        cur_cc_item = i
                        SWITCH_PIE = MIDI_CC_PIES[CC_LIST[cur_cc_item]:lower()]
                    end
                end
                r.ImGui_EndMenu(ctx)
            end
            if r.ImGui_BeginMenu(ctx, "CC 60-90", true) then
                for i = 60, 90 do
                    if r.ImGui_MenuItem(ctx, CC_LIST[i], nil, cur_cc_item == i, true) then
                        cur_cc_item = i
                        SWITCH_PIE = MIDI_CC_PIES[CC_LIST[cur_cc_item]:lower()]
                    end
                end
                r.ImGui_EndMenu(ctx)
            end
            if r.ImGui_BeginMenu(ctx, "CC 90-119", true) then
                for i = 90, 119 do
                    if r.ImGui_MenuItem(ctx, CC_LIST[i], nil, cur_cc_item == i, true) then
                        cur_cc_item = i
                        SWITCH_PIE = MIDI_CC_PIES[CC_LIST[cur_cc_item]:lower()]
                    end
                end
                r.ImGui_EndMenu(ctx)
            end
            if r.ImGui_BeginMenu(ctx, "CC 14-Bit", true) then
                for i = 120, #CC_LIST do
                    if r.ImGui_MenuItem(ctx, CC_LIST[i], nil, cur_cc_item == i, true) then
                        cur_cc_item = i
                        SWITCH_PIE = MIDI_CC_PIES[CC_LIST[cur_cc_item]:lower()]
                    end
                end
                r.ImGui_EndMenu(ctx)
            end
            if not child_hovered then
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_EndMenu(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
end

local function Pie()
    if STATE == "SETTINGS" then return end
    r.ImGui_BeginGroup(ctx)
    if STATE == "PIE" then
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 0)
        if r.ImGui_BeginChild(ctx, "##PIEDRAWTOP", -450, 20, true) then
            CustomDropDown()
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_PopStyleVar(ctx)
    end
    if STATE == "EDITOR" then MenuEditList(CUR_MENU_PIE) end
    if r.ImGui_BeginChild(ctx, "##PIEDRAW", -450, 0, true) then
        if STATE == "PIE" then
            BreadCrumbs(PIE_LIST)
            r.ImGui_SameLine(ctx, 0, 3)
            if r.ImGui_Button(ctx, '+') then
                MENUS[#MENUS + 1] = {
                    guid = r.genGuid(),
                    RADIUS = 150,
                    name = "MENU " .. #MENUS,
                    col = 0xff,
                    menu = true,
                    guid_list = {}
                }
                table.insert(CUR_PIE, MENUS[#MENUS])
                CUR_PIE.selected = #CUR_PIE
                UPDATE_FILTER = true
            end
            DrawTooltip("CREATE NEW MENU")
            if menu_items[context_cur_item][2] == "MIDI LANE" then
                MidiLaneSelector()
                -- elseif menu_items[context_cur_item][2] == "MIDI LANE CP" then
                --MidiLaneSelector(true)
            elseif menu_items[context_cur_item][2] == "ENVELOPE" then
                EnvLaneSelector()
            elseif menu_items[context_cur_item][2] == "ENVELOPE CONTROL PANEL" then
                EnvLaneSelector(true)
            end
        end
        local WW, WH = r.ImGui_GetWindowSize(ctx)
        local WX, WY = r.ImGui_GetWindowPos(ctx)
        CENTER = { x = WX + WW / 2, y = WY + WH / 2 }
        DrawPie(STATE == "PIE" and CUR_PIE or CUR_MENU_PIE)
        r.ImGui_EndChild(ctx)
    end
    DndAddTargetAction(STATE == "PIE" and CUR_PIE or CUR_MENU_PIE)
    DndAddTargetMenu(STATE == "PIE" and CUR_PIE or CUR_MENU_PIE)
    r.ImGui_EndGroup(ctx)
end

local ACTIONS_TBL = GetMainActions()                                                       --GetActions(0)
local MIDI_ACTIONS_TBL, MIDI_INLINE_ACTIONS_TBL, MIDI_EVENT_ACTIONS_TBL = GetMidiActions() --GetActions(32060)
local EXPLORER_ACTIONS_TBL = GetExplorerActions()

local FILTERED_ACTION_TBL = ACTIONS_TBL
local FILTERED_MENU_TBL = MENUS
local ACTION_FILTER = ''
local MENU_FILTER = ''

local want_filter = 1

local function GetFilter(flt_idx)
    if flt_idx == 1 then
        return ACTIONS_TBL
    elseif flt_idx == 2 then
        return MIDI_ACTIONS_TBL
    elseif flt_idx == 3 then
        return EXPLORER_ACTIONS_TBL
    elseif flt_idx == 4 then
        return MIDI_INLINE_ACTIONS_TBL
    elseif flt_idx == 5 then
        return MIDI_EVENT_ACTIONS_TBL
    end
end

local function ActionsTab(pie)
    if r.ImGui_BeginTabBar(ctx, "ACTIONS MENUS TAB") then
        if r.ImGui_BeginTabItem(ctx, "Actions") then
            r.ImGui_SameLine(ctx, 0, 55)
            r.ImGui_BeginGroup(ctx)
            if r.ImGui_RadioButton(ctx, "Main", want_filter == 1) then
                want_filter = 1
                UPDATE_FILTER = true
            end
            r.ImGui_SameLine(ctx)
            if r.ImGui_RadioButton(ctx, "Midi", want_filter == 2) then
                want_filter = 2
                UPDATE_FILTER = true
            end
            -- r.ImGui_SameLine(ctx)
            -- if r.ImGui_RadioButton(ctx, "Midi INL", want_filter == 4) then
            --     want_filter = 4
            --     UPDATE_FILTER = true
            -- end
            -- r.ImGui_SameLine(ctx)
            -- if r.ImGui_RadioButton(ctx, "Midi Event", want_filter == 5) then
            --     want_filter = 5
            --     UPDATE_FILTER = true
            -- end
            r.ImGui_SameLine(ctx)
            if r.ImGui_RadioButton(ctx, "ME", want_filter == 3) then
                want_filter = 3
                UPDATE_FILTER = true
            end
            r.ImGui_EndGroup(ctx)

            r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
            rv_af, ACTION_FILTER = r.ImGui_InputTextWithHint(ctx, "##inputA", "Search Actions", ACTION_FILTER)
            if rv_af or UPDATE_FILTER then
                UPDATE_CNT = UPDATE_FILTER and UPDATE_CNT + 1 or UPDATE_CNT
                --local want_midi = CUR_PIE.name:find("MIDI") and not CUR_PIE.name:find("MIDI ITEM")
                FILTERED_ACTION_TBL = FilterActions(
                --want_filter == 2 and MIDI_ACTIONS_TBL or (want_filter == 3 and EXPLORER_ACTIONS_TBL or ACTIONS_TBL),
                    GetFilter(want_filter), ACTION_FILTER)
            end
            if r.ImGui_BeginChild(ctx, "##CLIPPER_ACTION", nil, nil, nil, r.ImGui_WindowFlags_AlwaysHorizontalScrollbar()) then
                if not r.ImGui_ValidatePtr(ACTION_CLIPPER, 'ImGui_ListClipper*') then
                    ACTION_CLIPPER = r.ImGui_CreateListClipper(ctx)
                end
                r.ImGui_ListClipper_Begin(ACTION_CLIPPER, #FILTERED_ACTION_TBL) -- We have 1000 elements, evenly spaced
                while r.ImGui_ListClipper_Step(ACTION_CLIPPER) do
                    local display_start, display_end = r.ImGui_ListClipper_GetDisplayRange(ACTION_CLIPPER)
                    for i = display_start, display_end - 1 do
                        if r.ImGui_Selectable(ctx, FILTERED_ACTION_TBL[i + 1].name, LAST_SEL == i + 1) then
                            LAST_SEL = i + 1
                        end
                        DndSourceAction(FILTERED_ACTION_TBL[i + 1])
                    end
                end
                r.ImGui_EndChild(ctx)
            end
            r.ImGui_EndTabItem(ctx)
        end

        if STATE == "PIE" then
            if r.ImGui_BeginTabItem(ctx, "Menus") then
                r.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
                rv_mf, MENU_FILTER = r.ImGui_InputTextWithHint(ctx, "##inputM", "Search Menus", MENU_FILTER)
                if rv_mf or UPDATE_FILTER then
                    UPDATE_CNT = UPDATE_FILTER and UPDATE_CNT + 1 or UPDATE_CNT
                    FILTERED_MENU_TBL = FilterActions(MENUS, MENU_FILTER)
                end
                if r.ImGui_BeginChild(ctx, "##CLIPPER_MENUS") then
                    if not r.ImGui_ValidatePtr(MENU_CLIPPER, 'ImGui_ListClipper*') then
                        MENU_CLIPPER = r.ImGui_CreateListClipper(ctx)
                    end
                    r.ImGui_ListClipper_Begin(MENU_CLIPPER, #FILTERED_MENU_TBL)
                    while r.ImGui_ListClipper_Step(MENU_CLIPPER) do
                        local display_start, display_end = r.ImGui_ListClipper_GetDisplayRange(MENU_CLIPPER)
                        for i = display_start, display_end - 1 do
                            local CROSS_MENU = pie and HasReference(FILTERED_MENU_TBL[i + 1], pie.guid) or nil
                            local SAME_MENU = pie == FILTERED_MENU_TBL[i + 1]
                            r.ImGui_PushID(ctx, i)
                            if r.ImGui_Selectable(ctx, FILTERED_MENU_TBL[i + 1].name .. (CROSS_MENU and " - CANNOT ADD HAS REFERENCE" or ""), ((LAST_MENU_SEL == i + 1) or MENU_CONTEXT_TBL == FILTERED_MENU_TBL[i + 1]), r.ImGui_SelectableFlags_AllowDoubleClick()) then
                            end
                            r.ImGui_PopID(ctx)

                            local xs, ys = r.ImGui_GetItemRectMin(ctx)
                            local xe, ye = r.ImGui_GetItemRectMax(ctx)
                            -- SELECTED
                            if pie and pie.guid == FILTERED_MENU_TBL[i + 1].guid then
                                r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x22FF2255)
                            end
                            -- ALREADY HAS REFERENCE
                            if CROSS_MENU then
                                r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0xFF222255)
                            end
                            if not CROSS_MENU and not SAME_MENU then
                                DndSourceMenu(FILTERED_MENU_TBL[i + 1], i + 1)
                            end
                        end
                    end
                    r.ImGui_EndChild(ctx)
                end
                r.ImGui_EndTabItem(ctx)
            end
        end
        r.ImGui_EndTabBar(ctx)
    end
end

local function Properties(pie)
    if r.ImGui_BeginChild(ctx, "##PROPERTIES_WND", 0, 0, true) then
        ActionsTab(pie)
        r.ImGui_EndChild(ctx)
    end
end

local function Editor()
    if STATE == "SETTINGS" then return end
    r.ImGui_SameLine(ctx)
    r.ImGui_BeginGroup(ctx)
    r.ImGui_SeparatorText(ctx, "Button Properties")
    NewProperties(STATE == "PIE" and CUR_PIE or CUR_MENU_PIE)
    Properties(CUR_PIE)
    r.ImGui_EndGroup(ctx)
end

local function Delete()
    if REMOVE then
        if REMOVE.tbl[REMOVE.i].menu then
            -- REMOVE GUID REFERENCE WHEN ALT CLICK MENU
            if REMOVE.tbl.guid_list then
                for j = #REMOVE.tbl.guid_list, 1, -1 do
                    if REMOVE.tbl.guid_list[j] == REMOVE.tbl[REMOVE.i].guid then
                        table.remove(REMOVE.tbl.guid_list, j)
                    end
                end
            end
        end
        table.remove(REMOVE.tbl, REMOVE.i)
        REMOVE.tbl.selected = nil
        REMOVE = nil
    end
end

UPDATE_CNT = 0
local function Main()
    if SWITCH_PIE then
        RefreshImgObj(SWITCH_PIE)
        if STATE == "EDITOR" then
            CUR_MENU_PIE = SWITCH_PIE
        elseif STATE == "PIE" then
            CUR_PIE = SWITCH_PIE
        end
        SWITCH_PIE = nil
    end

    if CLEAR_PIE_LIST then
        if CLEAR_PIE_LIST == 0 then
            PIE_LIST = {}
        else
            for i = #PIE_LIST, 1, -1 do
                if i > CLEAR_PIE_LIST then
                    table.remove(PIE_LIST, i)
                end
            end
        end
        CLEAR_PIE_LIST = nil
    end

    r.ImGui_SetNextWindowBgAlpha(ctx, 1)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), bg_col)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ScrollbarBg(), bg_col)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 900, 500, FLT_MAX, FLT_MAX)
    local visible, open = r.ImGui_Begin(ctx, 'Pie XYZ 3000 Setup', true)
    if visible then
        _, PEEK_DND, PEEK_PAYLOAD = r.ImGui_GetDragDropPayload(ctx)
        draw_list = r.ImGui_GetWindowDrawList(ctx)
        vp_center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
        MX, MY = r.ImGui_PointConvertNative(ctx, r.GetMousePosition())
        CheckKeys()
        r.ImGui_PushFont(ctx, GUI_FONT)
        TabButtons()
        Settings()
        Pie()
        Editor()
        Popups()
        Delete()
        r.ImGui_PopFont(ctx)
        r.ImGui_End(ctx)
    end
    r.ImGui_PopStyleColor(ctx, 2)

    if open then
        DeferLoop(Main)
    else
        MakePieFile()
    end
    if UPDATE_CNT >= 3 then
        UPDATE_FILTER = nil
        UPDATE_CNT = 0
    end
end

DeferLoop(Main)
