-- @description Sexan ParaNormal FX Router
-- @author Sexan
-- @license GPL v3
-- @version 1.47
-- @changelog
--  Initial FX CHAINS Storing
-- @provides
--   Icons.ttf
--   ProggyClean.ttf
--   [effect] 3BandSplitterFX.jsfx
--   [effect] BandSelectFX.jsfx
--   Tutorials/*.png

local r = reaper
local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local script_path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]];
local PATH = debug.getinfo(1).source:match("@?(.*[\\|/])")

local ver = r.GetAppVersion():match("(.+)/")
if ver ~= "7.0rc8" then
    r.ShowMessageBox("This script requires Reaper V7.0rc8", "WRONG REAPER VERSION", 0)
    return
end

local fx_browser_script_path = r.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"

if not r.ImGui_GetVersion then
    r.ShowMessageBox("ReaImGui is required.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
    return r.ReaPack_BrowsePackages('dear imgui')
end
if r.file_exists(fx_browser_script_path) then
    require("Sexan_FX_Browser_ParserV7")
else
    r.ShowMessageBox("Sexan FX BROWSER is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
    return r.ReaPack_BrowsePackages('sexan fx browser parser V7')
end

--local profiler2 = require("profiler")

local VOL_PAN_HELPER = "Volume/Pan Smoother"
local PHASE_HELPER = "Channel Polarity Control"

-- SETTINGS
local item_spacing_vertical = 7 -- VERTICAL SPACING BETEWEEN ITEMS

-- FX BUTTON SIZE
local custom_btn_h = 22
local Knob_Radius = custom_btn_h // 2
local ROUND_CORNER = 2
local WireThickness = 1

-- INSERT POINT
local add_bnt_w = 55
local add_btn_h = 14
-- SETTINGS

local SYNC = false
local AUTO_COLORING = false
local CUSTOM_FONT = nil
local ESC_CLOSE = false
CLIPBOARD = {}


local name_margin = 25
local COLOR = {
    ["n"]           = 0x315e94ff,
    ["Container"]   = 0x49cc85FF,
    ["knob_bg"]     = 0x192432ff,
    ["knob_vol"]    = 0x49cc85FF,
    ["knob_drywet"] = 0x3a87ffff,
    ["midi"]        = 0x8833AAFF,
    ["del"]         = 0xFF2222FF,
    ["ROOT"]        = 0x49cc85FF,
    ["add"]         = 0x192432ff,
    ["parallel"]    = 0x192432ff,
    ["bypass"]      = 0xdc5454ff,
    ["enabled"]     = 0x49cc85FF,
    ["wire"]        = 0xB0B0B9FF,
}

local TUTORIALS = {
    [1] = { name = "SCROLL", img = PATH .. "Tutorials/" .. "SCROLL.png", frames = 80, cols = 7, rows = 12,
        desc = "RIGHT DRAG TO HANDSCROLL AND PRESS HOME TO RECENTER THE VIEW"
    },
    [2] = { name = "ADD", img = PATH .. "Tutorials/" .. "ADD.png", frames = 80, cols = 7, rows = 12,
        desc = "LEFT CLICK ON + || OR DRAG FROM BROWSER TO + || TO INSERT NEW FX\nDRAG TO FX TO CREATE AUTOCONTAINER"
    },
    [3] = { name = "MOVE", img = PATH .. "Tutorials/" .. "MOVE.png", frames = 80, cols = 7, rows = 12,
        desc = "DRAG MOVE FX TO + || TO MOVE TO THAT POSITION\nMOVE FX TO FX TO EXCHANGE/SWAP THEM"
    },
    [4] = { name = "MOVE CONTAINERS", img = PATH .. "Tutorials/" .. "MOVE_CONTAINER.png", frames = 80, cols = 7, rows = 12,
        desc = "DRAG MOVE FX TO + || TO MOVE TO THAT POSITION\nMOVE FX TO FX TO EXCHANGE/SWAP THEM"
    },
    [5] = { name = "SWAP", img = PATH .. "Tutorials/" .. "SWAP_EXCHANGE.png", frames = 80, cols = 7, rows = 12,
        desc = "DRAG MOVE FX TO FX TO MAKE EXCHANGE/SWAP THEM"
    },
    [6] = { name = "DRAG COPY", img = PATH .. "Tutorials/" .. "DRAG_COPY.png", frames = 80, cols = 7, rows = 12,
        desc = "CTRL DRAG TO + || TO COPY TO TARGET LOCATION\n DRAG TO FX TO MAKE AUTOCONTAINER"
    },
    [7] = { name = "DELETE", img = PATH .. "Tutorials/" .. "DELETE.png", frames = 80, cols = 7, rows = 12,
        desc = "ALT CLICK ON TARGET TO DELETE IT\n DELETING CONTAINER WILL DELETE CONTENT"
    },
    [8] = { name = "REPLACE", img = PATH .. "Tutorials/" .. "REPLACE.png", frames = 80, cols = 7, rows = 12,
        desc = "RIGHT CLICK CONTEXT MENU OVER TARGET FX TO REPLACE IT WITH NEW FROM BROWSER"
    },
    [9] = { name = "BYPASS", img = PATH .. "Tutorials/" .. "BYPASS.png", frames = 80, cols = 7, rows = 12,
        desc = "BYPASSING CONTAINER DOES NOT MUTE ITS CONTENT BUT JUST ITSELF"
    },
    [10] = { name = "HELPERS", img = PATH .. "Tutorials/" .. "HELPERS.png", frames = 80, cols = 7, rows = 12,
        desc = "HELPER FX WITH GUI FOR VOLUME, POLARITY"
    },
    [11] = { name = "SPLITTER", img = PATH .. "Tutorials/" .. "SPLITTER.png", frames = 80, cols = 7, rows = 12,
        desc = "TRADITIONAL 3-BAND SPLITTING WITH FOLLOWING CONFIGURATION"
    },
    [12] = { name = "PIN", img = PATH .. "Tutorials/" .. "PIN_MULTI_INSTANCE.png", frames = 80, cols = 7, rows = 12,
        desc =
        "PIN TRACK TO LOCK IT TO SELECTED TRACK\n OPEN NEW INSTANCE OF THE SCRIPT AND DO THE SAME\n WHEN PINNED TRACK CAN BE CHANGED VIA DROP DOWN LIST"
    },
    [13] = { name = "COPY TO INSTANCE", img = PATH .. "Tutorials/" .. "COPY_PASTE_INSTANCE.png", frames = 80, cols = 7, rows = 12,
        desc =
        "RIGHT CLICK CONTEXT MENU COPY\n CAN BE USED IN CURRENT INSTANCE OR OTHER INSTANCES OF THE SCRIPT TO PASTE FX TO OTHER TRACK"
    },
    [14] = { name = "SOLO CONTAINER", img = PATH .. "Tutorials/" .. "SOLO_CONTAINER.png", frames = 80, cols = 7, rows = 12,
        desc =
        'SHIFT CLICKING ON BYPASS BUTTON ON CONTAINERS TOGGLES "SOLO"\n RIGHT CLICK CONTEXT MENU ON || BUTTON TO UNBYPASS THE LANE AGAIN'
    },
    [15] = { name = "AUTOCONTAINERS", img = PATH .. "Tutorials/" .. "AUTO_CONTAINERS.png", frames = 80, cols = 7, rows = 12,
        desc =
        "DRAGGING FX FROM BROWSER TO TARGET FX AUTOMATICALLY ENCLOSES THEM INTO NEW CONTAINER\n CTRL DRAG COPY ONTO TARGET FX DOES THE SAME"
    },
    [16] = { name = "VOL DRY/WET", img = PATH .. "Tutorials/" .. "VOL_DRY_WET.png", frames = 80, cols = 7, rows = 12,
        desc = "WHEN FX IS IN PARALLEL THEN IT HAS VOLUME CONTROL\n WHEN FX IS IN SERIAL LANE THEN HAD DRY/WET CONTROL"
    },
}

local pearson_table = {
    9, 159, 180, 252, 71, 6, 13, 164, 232, 35, 226, 155, 98, 120, 154, 69,
    157, 24, 137, 29, 147, 78, 121, 85, 112, 8, 248, 130, 55, 117, 190, 160,
    176, 131, 228, 64, 211, 106, 38, 27, 140, 30, 88, 210, 227, 104, 84, 77,
    75, 107, 169, 138, 195, 184, 70, 90, 61, 166, 7, 244, 165, 108, 219, 51,
    9, 139, 209, 40, 31, 202, 58, 179, 116, 33, 207, 146, 76, 60, 242, 124,
    254, 197, 80, 167, 153, 145, 129, 233, 132, 48, 246, 86, 156, 177, 36, 187,
    45, 1, 96, 18, 19, 62, 185, 234, 99, 16, 218, 95, 128, 224, 123, 253,
    42, 109, 4, 247, 72, 5, 151, 136, 0, 152, 148, 127, 204, 133, 17, 14,
    182, 217, 54, 199, 119, 174, 82, 57, 215, 41, 114, 208, 206, 110, 239, 23,
    189, 15, 3, 22, 188, 79, 113, 172, 28, 2, 222, 21, 251, 225, 237, 105,
    102, 32, 56, 181, 126, 83, 230, 53, 158, 52, 59, 213, 118, 100, 67, 142,
    220, 170, 144, 115, 205, 26, 125, 168, 249, 66, 175, 97, 255, 92, 229, 91,
    214, 236, 178, 243, 46, 44, 201, 250, 135, 186, 150, 221, 163, 216, 162, 43,
    11, 101, 34, 37, 194, 25, 50, 12, 87, 198, 173, 240, 193, 171, 143, 231,
    111, 141, 191, 103, 74, 245, 223, 20, 161, 235, 122, 63, 89, 149, 73, 238,
    134, 68, 93, 183, 241, 81, 196, 49, 192, 65, 212, 94, 203, 10, 200, 47,
}
assert(#pearson_table == 0x100)

local function pearson8(str)
    local hash = 0
    for c in str:gmatch('.') do
        hash = pearson_table[(hash ~ c:byte()) + 1]
    end
    return hash
end

function OpenFile(file)
    local cmd
    if r.GetOS():sub(1, 3) == 'Win' then
        cmd = 'cmd.exe /C start ""'
    else
        cmd = '/bin/sh -c open ""'
    end
    r.ExecProcess(([[%s "%s"]]):format(cmd, file), 0)
end

local function stringToTable(str)
    local f, err = load("return " .. str)
    return f ~= nil and f() or nil
end
if r.HasExtState("PARANORMALFX", "SETTINGS") then
    local stored = r.GetExtState("PARANORMALFX", "SETTINGS")
    if stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then
            -- SETTINGS
            ESC_CLOSE = storedTable.esc_close
            CUSTOM_FONT = storedTable.custom_font
            AUTO_COLORING = storedTable.auto_color
            item_spacing_vertical = storedTable.spacing
            add_btn_h = storedTable.add_btn_h
            add_bnt_w = storedTable.add_bnt_w
            WireThickness = storedTable.wirethickness
            COLOR["wire"] = storedTable.wire_color
            COLOR["n"] = storedTable.fx_color
            COLOR["bypass"] = storedTable.bypass_color and storedTable.bypass_color or COLOR["bypass"]
            COLOR["Container"] = storedTable.container_color
            COLOR["parallel"] = storedTable.parallel_color
            COLOR["knob_vol"] = storedTable.knobvol_color
            COLOR["knob_drywet"] = storedTable.drywet_color
        end
    end
end

local LINE_POINTS, FX_DATA, PLUGINS, CANVAS

local function InitCanvas()
    return { view_x = 0, view_y = 0, off_x = 0, off_y = 50, scale = 1 }
end

local FX_LIST, CAT = GetFXTbl()

ctx = r.ImGui_CreateContext('CONTAINERS_NO_ZOOM')

ICONS_FONT = r.ImGui_CreateFont(script_path .. 'Icons.ttf', 13)
r.ImGui_Attach(ctx, ICONS_FONT)
ICONS_FONT2 = r.ImGui_CreateFont(script_path .. 'Icons.ttf', 16)
r.ImGui_Attach(ctx, ICONS_FONT2)

SYSTEM_FONT = r.ImGui_CreateFont('sans-serif', 13, r.ImGui_FontFlags_Bold())
r.ImGui_Attach(ctx, SYSTEM_FONT)
DEFAULT_FONT = r.ImGui_CreateFont(script_path .. 'ProggyClean.ttf', 13)
r.ImGui_Attach(ctx, DEFAULT_FONT)

require("FileManager")
local SELECTED_FONT = CUSTOM_FONT and SYSTEM_FONT or DEFAULT_FONT

local draw_list = r.ImGui_GetWindowDrawList(ctx)

local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
local WND_FLAGS = r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse()

local TrackFX_GetNamedConfigParm = r.TrackFX_GetNamedConfigParm
local TrackFX_GetFXGUID = r.TrackFX_GetFXGUID
local TrackFX_GetCount = r.TrackFX_GetCount
local TRACK

local def_s_frame_x, def_s_frame_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
local def_s_spacing_x, def_s_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
local def_s_window_x, def_s_window_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())

local s_frame_x, s_frame_y = def_s_frame_x, def_s_frame_y
local s_spacing_x, s_spacing_y = def_s_spacing_x, item_spacing_vertical and item_spacing_vertical or def_s_spacing_y
local s_window_x, s_window_y = def_s_window_x, def_s_window_y

-- lb0 FUNCTION
local find = string.find
local function Chunk_GetFXChainSection(chunk)
    -- If FXChain - return section
    -- If none - return char after MAIN SEND \n

    local s1 = find(chunk, '<FXCHAIN.-\n')
    if s1 then
        local s = s1
        local indent, op, cl = 1, nil, nil
        while indent > 0 do
            op = find(chunk, '\n<', s + 1, true)
            cl = find(chunk, '\n>\n', s + 1, true) + 1
            if op == nil and cl == nil then break end
            if op ~= nil then
                op = op + 1
                if op <= cl then
                    indent = indent + 1
                    s = op
                else
                    indent = indent - 1
                    s = cl
                end
            else
                indent = indent - 1
                s = cl
            end
        end

        local retch = string.sub(chunk, s1, cl)
        return retch, s1, cl
    else
        local s1, e1 = find(chunk, 'MAINSEND.-\n')
        return nil, s1, e1
    end
end

local function ExtractContainer(chunk, guid)
    local r_chunk = chunk:reverse()
    local r_guid = guid:reverse()
    local s1 = find(r_chunk, r_guid, 1, true)
    if s1 then
        local s = s1
        local indent, op, cl = nil, nil, nil
        while (not indent or indent > 0) do
            -- INITIATE START HERE SINCE WE ARE IN CONTAINER ALREADY
            if not indent then indent = 0 end
            cl = find(r_chunk, ('\n<'):reverse(), s + 1, true)
            op = find(r_chunk, ('\n>\n'):reverse(), s + 1, true) + 1
            if op == nil and cl == nil then break end
            --if not indent then if op then indent = 0 end end
            if op ~= nil then
                op = op + 1
                if op <= cl then
                    indent = indent + 1
                    s = op
                else
                    indent = indent - 1
                    s = cl
                end
            else
                indent = indent + 1
                s = cl
            end
        end
        local retch = string.sub(r_chunk, s1, cl):reverse()
        --local cont_start = find(retch, 'BYPASS ')
        local cont_fx_chunk = "BYPASS 0 0 0\n" .. retch .. "\nWAK 0 0"
        return cont_fx_chunk
    end
end

local function Chunk_GetTargetContainerFXSection(chunk, guid)
    -- If FXChain - return section
    -- If none - return char after MAIN SEND \n

    local s1 = find(chunk, '<FXCHAIN.-\n')
    AAA = {}
    BBB = {}
    local ge, cont_found, last_cc
    if s1 then
        local s = s1
        local indent, op, cl = 1, nil, nil
        while indent > 0 do
            op = find(chunk, '\n<', s + 1, true)
            cl = find(chunk, '\n>\n', s + 1, true) + 1

            -- if cont_found and op then
            --     BBB[op] = indent
            --     CONT_END = op - 1
            --     CONT_INDENT = indent
            --     --break
            -- end

            -- local cc = find(chunk, '<CONTAINER', op, true)
            -- if cc then
            --     -- if not AAA[#AAA].pos == cc then
            --     AAA[#AAA + 1] = { indent = indent, pos = cc }
            --     --end
            -- end

            -- if cont_found then
            --     local bs,be = find(chunk, 'BYPASS ', ge+1, true)
            --     if be then
            --         BBB[be] = indent
            --         CONT_END = be
            --         CONT_INDENT = indent
            --         break
            --     end
            -- end
            if op == nil and cl == nil then break end
            if op ~= nil then
                op = op + 1
                if op <= cl then
                    indent = indent + 1
                    s = op
                else
                    indent = indent - 1
                    s = cl
                end
            else
                indent = indent - 1
                s = cl
            end
            local cc = find(chunk, '<CONTAINER', op, true)
            if cc then
                -- if not AAA[#AAA].pos == cc then
                AAA[#AAA + 1] = { indent = indent, pos = cc }
                -- last_cc = cc
            end
            if not cont_found then
                _, ge = find(chunk, guid, s + 1, true)
                if ge then
                    cont_found = true
                    BBB[ge] = indent
                    CONT_END = ge
                    CONT_INDENT = indent
                end
            end
        end
        -- for k, v in next, AAA do
        --     if v == CONT_INDENT then
        --         --r.ShowConsoleMsg("LASJKHFASOLIHGFHPIOA")
        --         CONT_START = k
        --         break
        --     end
        -- end

        for i = #AAA, 1, -1 do
            if AAA[i].indent == CONT_INDENT then
                CONT_START = AAA[i].pos
                break
            end
        end

        -- for k, v in pairs(AAA) do
        --     if v == CONT_INDENT then
        --         --r.ShowConsoleMsg("LASJKHFASOLIHGFHPIOA")
        --         --CONT_START = k
        --     end
        -- end
        if CONT_START then
            local retch = string.sub(chunk, CONT_START, CONT_END)
            local cont_chain = "BYPASS 0 0 0\n" .. retch .. "\nWAK 0 0\n"
            return cont_chain, CONT_START, CONT_END
        end
        --return retch, s1, cl
    else
        -- local s1, e1 = find(chunk, 'MAINSEND.-\n')
        --return nil, s1, e1
    end
end

local function GetFXChainChunk(chunk)
    local number_of_spaces = 2
    local t = {}
    local indent = 0
    local add = false
    for line in chunk:gmatch("[^\n]+") do
        if add then
            indent = indent + 1
            add = false
        end
        if line:find("^<") then
            add = true
        elseif line == ">" then
            indent = indent - 1
        end

        -- ENVELOPE PARAMETER SECTION ENDED > IS FOUND IN SAME INDENTETION
        if PARAM_START and PARAM_START == indent then
            PARAM_START = nil
            PARAM_END = true
        end

        local fx_chunk_name = line:match('<(%S+) ')
        if fx_chunk_name == 'PARMENV' then
            PARAM_START = indent
        end

        -- SKIP ADDING IF ENVELOPE PARAMETER SECTION
        if not PARAM_START and not PARAM_END then
            if not line:match('FXID') and not line:match('FLOATPOS') then
                t[#t + 1] = (string.rep(string.rep(" ", number_of_spaces), indent) or "") .. line
            end
        end
        -- SET IT NIL HERE SO IT DOES NOT ADD ITS LAST > INTO TABLE
        if PARAM_END then PARAM_END = nil end
    end
    return table.concat(t, "\n")
end



-- -- ALAGAMLA MODIFIED FUNCTION
-- local function GetFXChainChunk(chunk)
--     local number_of_spaces = 2
--     local t = {}
--     local indent = 0
--     local add = false
--     local l = 0

--     local CONT_START, CONT_END
--     for line in chunk:gmatch("[^\n]+") do
--         if add then
--             indent = indent + 1
--             add = false
--         end
--         if line:find("^<") then
--             add = true
--         elseif line == ">" then
--             indent = indent - 1
--         end

--         -- CONTAINER ENDED
--         if CONT_START and CONT_START == indent then
--             CONT_END = indent
--             CONT_START = nil
--         end
--         -- ENVELOPE PARAMETER SECTION ENDED
--         if PARAM_START and PARAM_START == indent then
--             PARAM_START = nil
--             PARAM_END = true
--         end

--         local fx_chunk_name = line:match('<(%S+) ')
--         if fx_chunk_name then
--             -- CONTAINER STARTED
--             if fx_chunk_name == "CONTAINER" then
--                 CONT_END = nil
--                 CONT_START = indent
--             elseif fx_chunk_name == 'PARMENV' then
--                 PARAM_START = indent
--             else
--                 -- CONTAINER ENDED BUT NEXT FX IS NOT CONTAINER
--                 if CONT_END and indent == CONT_END then
--                     CONT_END = nil
--                 end
--             end
--         end

--         -- SKIP ADDING IF ENVELOPE PARAMETER SECTION
--         -- ADD LINES NORMALLY IF NOT CONTAINER
--         -- IF CONTAINER AND ENDED THEN EXCLUDE FXID AND FLOATPOS FROM IT
--         if not PARAM_START and not PARAM_END then
--             if not CONT_END or (CONT_END and not line:match('FXID') and not line:match('FLOATPOS')) then
--                 --if not line:match("FXID") then
--                     t[#t + 1] = (string.rep(string.rep(" ", number_of_spaces), indent) or "") .. line
--                 --end
--             end
--         end

--         if PARAM_END then PARAM_END = nil end
--     end
--     return table.concat(t, "\n")
-- end

local function AnimateSpriteSheet(img_obj, frames, cols, rows, speed, start_time)
    local w, h = r.ImGui_Image_GetSize(img_obj)

    local xe, ye = w / cols, h / rows

    local uv_step_x, uv_step_y = 1 / cols, 1 / rows

    local frame = math.floor(((r.time_precise() - start_time) * speed) % frames)

    local col_frame = frame % cols
    local row_frame = math.floor(frame / cols)

    local uv_xs = col_frame * uv_step_x
    local uv_ys = row_frame * uv_step_y
    local uv_xe = uv_xs + uv_step_x
    local uv_ye = uv_ys + uv_step_y

    r.ImGui_Image(ctx, img_obj, xe, ye, uv_xs, uv_ys, uv_xe, uv_ye)
end

local IMG_OBJ
local function Tooltip_Tutorial(tut)
    local x, y = r.ImGui_GetMousePos(ctx)
    r.ImGui_SetNextWindowPos(ctx, x - 400, y + 40)
    if r.ImGui_BeginTooltip(ctx) then
        r.ImGui_Text(ctx, tut.desc)
        if not r.ImGui_ValidatePtr(IMG_OBJ, 'ImGui_Image*') then
            IMG_OBJ = r.ImGui_CreateImage(tut.img)
            start_time = r.time_precise()
        end
        AnimateSpriteSheet(IMG_OBJ, tut.frames, tut.cols, tut.rows, 10, start_time)
        r.ImGui_Separator(ctx)
        r.ImGui_EndTooltip(ctx)
    end
end

local function pdefer(func)
    r.defer(function()
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
            r.DeleteExtState("PARANORMALFX", "COPY_BUFFER", false)
            r.DeleteExtState("PARANORMALFX", "COPY_BUFFER_ID", false)
        end
    end)
end


local function serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0
    local tmp = string.rep(" ", depth)
    if name then
        if type(name) == "number" and math.floor(name) == name then
            name = "[" .. name .. "]"
        elseif not string.match(name, '^[a-zA-z_][a-zA-Z0-9_]*$') then
            name = string.gsub(name, "'", "\\'")
            name = "['" .. name .. "']"
        end
        tmp = tmp .. name .. " = "
    end
    if type(val) == "table" then
        tmp = tmp .. "{"                                                      --.. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            tmp = tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," --.. (not skipnewlines and "\n" or "")
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end
    return tmp
end

local function tableToString(table)
    return serializeTable(table)
end


local function Store_To_PEXT(last_track)
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

local function Restore_From_PEXT()
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

local para_btn_size = r.ImGui_CalcTextSize(ctx, "||") + (s_frame_x * 2)
local function CalculateItemWH(tbl)
    local tw, th = r.ImGui_CalcTextSize(ctx, tbl.name)
    local iw, ih = tw + (s_frame_x * 2), th + (s_frame_y * 2)
    return iw, custom_btn_h and custom_btn_h or ih
end

local function Tooltip(str)
    if IS_DRAGGING_RIGHT_CANVAS then return end
    if r.ImGui_IsItemHovered(ctx) then
        r.ImGui_BeginTooltip(ctx)
        r.ImGui_Text(ctx, str)
        r.ImGui_EndTooltip(ctx)
    end
end

local function adjustBrightness(channel, delta)
    return math.min(255, math.max(0, channel + delta))
end

local function SplitColorChannels(color)
    local alpha = color & 0xFF
    local blue = (color >> 8) & 0xFF
    local green = (color >> 16) & 0xFF
    local red = (color >> 24) & 0xFF
    return red, green, blue, alpha
end

local function ColorToHex(color, amt)
    local red, green, blue, alpha = SplitColorChannels(color)
    alpha = adjustBrightness(alpha, amt)
    blue = adjustBrightness(blue, amt)
    green = adjustBrightness(green, amt)
    red = adjustBrightness(red, amt)
    return (alpha) | (blue << 8) | (green << 16) | (red << 24)
end

local function CalculateFontColor(color)
    local red, green, blue, alpha = SplitColorChannels(color)
    local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;
    if (luminance > 0.5) then
        return 0xFF
    else
        return 0xFFFFFFFF
    end
end

local function MyKnob(label, style, p_value, v_min, v_max, is_vol, is_pan)
    local radius_outer = Knob_Radius
    local pos = { r.ImGui_GetCursorScreenPos(ctx) }
    local center = { pos[1] + radius_outer, pos[2] + radius_outer }
    local line_height = r.ImGui_GetTextLineHeight(ctx)
    local item_inner_spacing = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()) }
    local mouse_delta = { r.ImGui_GetMouseDelta(ctx) }

    local ANGLE_MIN = 3.141592 * 0.75
    local ANGLE_MAX = 3.141592 * 2.25

    r.ImGui_InvisibleButton(ctx, label, radius_outer * 2, radius_outer * 2)
    local value_changed = false
    local is_active = r.ImGui_IsItemActive(ctx)
    local is_hovered = r.ImGui_IsItemHovered(ctx)
    if is_active and mouse_delta[2] ~= 0.0 then
        local step = (v_max - v_min) / (CTRL and 1000 or 200.0)
        p_value = p_value + (-mouse_delta[2] * step)
        if p_value < v_min then p_value = v_min end
        if p_value > v_max then p_value = v_max end
        value_changed = true
    end

    local t = (p_value - v_min) / (v_max - v_min)
    local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
    local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
    local radius_inner = radius_outer / 2.5
    r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer - 1, COLOR["knob_bg"])
    if style == "knob" then
        r.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos * radius_inner, center[2] + angle_sin * radius_inner,
            center[1] + angle_cos * (radius_outer - 2), center[2] + angle_sin * (radius_outer - 2),
            COLOR["ROOT"], 2.0)
        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner,
            r.ImGui_GetColor(ctx,
                is_active and r.ImGui_Col_FrameBgActive() or is_hovered and r.ImGui_Col_FrameBgHovered() or
                r.ImGui_Col_FrameBg()), 16)
        r.ImGui_DrawList_AddText(draw_list, pos[1], pos[2] + radius_outer * 2 + item_inner_spacing[2],
            r.ImGui_GetColor(ctx, r.ImGui_Col_Text()), label)
    elseif style == "arc" then
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 1.5, ANGLE_MIN, angle)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColorEx(ctx, COLOR["knob_vol"]), nil, radius_inner)
        r.ImGui_DrawList_PathClear(draw_list)
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 1.5, ANGLE_MAX, angle)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColorEx(ctx, 0x151515ff), nil, radius_inner)
        r.ImGui_DrawList_PathClear(draw_list)
    elseif style == "dry_wet" then
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 1.5, ANGLE_MIN, angle)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColorEx(ctx, COLOR["knob_drywet"]), nil, radius_inner)
        r.ImGui_DrawList_PathClear(draw_list)
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 1.5, ANGLE_MAX, angle)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColorEx(ctx, 0x151515ff), nil, radius_inner)
        r.ImGui_DrawList_PathClear(draw_list)
    end

    if is_active or is_hovered then
        local window_padding = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) }
        r.ImGui_SetNextWindowPos(ctx, pos[1] - window_padding[1],
            pos[2] - line_height - (item_inner_spacing[2] * 2) - window_padding[2])
        r.ImGui_BeginTooltip(ctx)
        if is_vol then
            r.ImGui_Text(ctx, "VOL " .. ('%.0f'):format(p_value))
        else
            if is_pan then
                r.ImGui_Text(ctx, "PAN " .. ('%.0f'):format(p_value))
            else
                r.ImGui_Text(ctx, ('%.0f'):format(100 - p_value) .. " DRY / WET " .. ('%.0f'):format(p_value))
            end
        end
        r.ImGui_EndTooltip(ctx)
    end

    return value_changed, p_value
end

local function OpenFX(id)
    local open = r.TrackFX_GetFloatingWindow(TRACK, id)
    r.TrackFX_Show(TRACK, id, open and 2 or 3)
end

local function GetFx(guid)
    return FX_DATA[guid]
end

local function GetParentContainerByGuid(tbl)
    return tbl.type == "ROOT" and tbl or GetFx(tbl.pid)
end

local function CalcFxID(tbl, idx)
    if tbl.type == "Container" then
        return 0x2000000 + tbl.ID + (tbl.DIFF * idx)
    elseif tbl.type == "ROOT" then
        return idx - 1
    end
end

local function EndUndoBlock(str)
    r.Undo_EndBlock("PARANORMAL: " .. str, 0)
end

local function AddFX(name)
    if not TRACK or not FX_ID then return end
    if REPLACE then r.Undo_BeginBlock() end
    local idx = FX_ID[1] > 0x2000000 and FX_ID[1] or -1000 - FX_ID[1]
    local new_fx_id = r.TrackFX_AddByName(TRACK, name, false, idx)
    if FX_ID[2] then r.TrackFX_SetNamedConfigParm(TRACK, FX_ID[1], "parallel", "1") end
    if REPLACE then
        r.Undo_BeginBlock()
        local parrent_container = GetParentContainerByGuid(R_CLICK_DATA[1][R_CLICK_DATA[2]])
        local del_id = CalcFxID(parrent_container, R_CLICK_DATA[2] + 1)
        r.TrackFX_Delete(TRACK, del_id)
        REPLACE = nil
        EndUndoBlock("REPLACE")
    end
    LAST_USED_FX = name
    UpdateFxData()
    if CLIPBOARD.tbl then
        UpdateClipboardInfo()
    end
    return new_fx_id ~= -1 and new_fx_id or nil
end

local dummy_preview = {
    [1] = {
        type = "PREVIEW",
        name = "",
        guid = "DRAGADDPREVIEW",
        bypass = 0,
    }
}

local function DragAddDDSource(fx)
    if r.ImGui_BeginDragDropSource(ctx) then
        DRAG_ADD_FX = true
        r.ImGui_SetDragDropPayload(ctx, 'DRAG ADD FX', fx)
        -- r.ImGui_Text(ctx, CTRL and "REPLACE" or "ADD")
        --r.ImGui_SameLine(ctx)
        dummy_preview[1].type = fx == "Container" and "Container" or "PREVIEW"
        DrawButton(dummy_preview, 1, Stripname(fx, true, true):gsub("(%S+:)", ""),
            CalculateItemWH({ name = fx:gsub("(%S+:)", "") }))
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

local tsort = table.sort
function SortTable(tab, val1, val2)
    tsort(tab, function(a, b)
        if (a[val1] < b[val1]) then
            -- primary sort on position -> a before b
            return true
        elseif (a[val1] > b[val1]) then
            -- primary sort on position -> b before a
            return false
        else
            -- primary sort tied, resolve w secondary sort on rank
            return a[val2] < b[val2]
        end
    end)
end

local old_t = {}
local old_filter = ""
local function Filter_actions(filter_text)
    if old_filter == filter_text then return old_t end
    filter_text = Lead_Trim_ws(filter_text)
    local t = {}
    if filter_text == "" or not filter_text then return t end
    for i = 1, #FX_LIST do
        local name = FX_LIST[i]:lower() --:gsub("(%S+:)", "")
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then t[#t + 1] = { score = FX_LIST[i]:len() - filter_text:len(), name = FX_LIST[i] } end
    end
    if #t >= 2 then
        SortTable(t, "score", "name") -- Sort by key priority
    end
    old_t = t
    old_filter = filter_text
    return t
end

local function SetMinMax(Input, Min, Max)
    if Input >= Max then
        Input = Max
    elseif Input <= Min then
        Input = Min
    else
        Input = Input
    end
    return Input
end

local FILTER = ''
local function FilterBox()
    local MAX_FX_SIZE = 300
    r.ImGui_PushItemWidth(ctx, MAX_FX_SIZE)
    if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end
    _, FILTER = r.ImGui_InputTextWithHint(ctx, '##input', "SEARCH FX", FILTER)
    local filtered_fx = Filter_actions(FILTER)
    local filter_h = #filtered_fx == 0 and 0 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx))
    ADDFX_Sel_Entry = SetMinMax(ADDFX_Sel_Entry or 1, 1, #filtered_fx)
    if #filtered_fx ~= 0 then
        if r.ImGui_BeginChild(ctx, "##popupp", MAX_FX_SIZE, filter_h) then
            for i = 1, #filtered_fx do
                if r.ImGui_Selectable(ctx, filtered_fx[i].name, i == ADDFX_Sel_Entry) then
                    AddFX(filtered_fx[i].name)
                    r.ImGui_CloseCurrentPopup(ctx)
                end
                DragAddDDSource(filtered_fx[i].name)
            end
            r.ImGui_EndChild(ctx)
        end
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            AddFX(filtered_fx[ADDFX_Sel_Entry].name)
            ADDFX_Sel_Entry = nil
            FILTER = ''
            r.ImGui_CloseCurrentPopup(ctx)
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry - 1
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry + 1
        end
    end
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        FILTER = ''
        r.ImGui_CloseCurrentPopup(ctx)
    end
    return #filtered_fx ~= 0
end

local function DrawFxChains(tbl, path)
    local extension = ".RfxChain"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                DrawFxChains(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                AddFX(table.concat({ path, os_separator, tbl[i], extension }))
            end
            DragAddDDSource(table.concat({ path, os_separator, tbl[i], extension }))
        end
    end
end

local function LoadTemplate(template, replace)
    local track_template_path = r.GetResourcePath() .. "/TrackTemplates" .. template
    if replace then
        if not TRACK then return end
        local chunk = GetFileContext(track_template_path)
        r.SetTrackStateChunk(TRACK, chunk, true)
    else
        r.Main_openProject(track_template_path)
    end
end

local function DrawTrackTemplates(tbl, path)
    local extension = ".RTrackTemplate"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                local cur_path = table.concat({ path, os_separator, tbl[i].dir })
                DrawTrackTemplates(tbl[i], cur_path)
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                local template_str = table.concat({ path, os_separator, tbl[i], extension })
                LoadTemplate(template_str) -- ADD NEW TRACK FROM TEMPLATE
            end
        end
    end
end

local function DrawItems(tbl, main_cat_name)
    for i = 1, #tbl do
        if r.ImGui_BeginMenu(ctx, tbl[i].name) then
            for j = 1, #tbl[i].fx do
                if tbl[i].fx[j] then
                    local name = tbl[i].fx[j]

                    if main_cat_name == "ALL PLUGINS" and tbl[i].name ~= "INSTRUMENTS" then
                        -- STRIP PREFIX IN "ALL PLUGINS" CATEGORIES EXCEPT INSTRUMENT WHERE THERE CAN BE MIXED ONES
                        name = name:gsub("^(%S+:)", "")
                    elseif main_cat_name == "DEVELOPER" then
                        -- STRIP SUFFIX (DEVELOPER) FROM THESE CATEGORIES
                        name = name:gsub(' %(' .. Literalize(tbl[i].name) .. '%)', "")
                    end
                    if r.ImGui_Selectable(ctx, name) then
                        AddFX(tbl[i].fx[j])
                    end
                    DragAddDDSource(tbl[i].fx[j])
                end
            end
            r.ImGui_EndMenu(ctx)
        end
    end
end
function DrawFXList()
    local search = FilterBox()
    if search then return end
    for i = 1, #CAT do
        if r.ImGui_BeginMenu(ctx, CAT[i].name) then
            if CAT[i].name == "FX CHAINS" then
                DrawFxChains(CAT[i].list)
            elseif CAT[i].name == "TRACK TEMPLATES" then
                DrawTrackTemplates(CAT[i].list)
            else
                DrawItems(CAT[i].list, CAT[i].name)
            end
            r.ImGui_EndMenu(ctx)
        end
    end

    --if r.ImGui_Selectable(ctx, "VIDEO PROCESSOR") then AddFX("Video processor") end
    --DragAddDDSource("Video processor")
    if r.ImGui_BeginMenu(ctx, "UTILITY") then
        if r.ImGui_Selectable(ctx, "VOLUME-PAN") then AddFX("JS:Volume/Pan Smoother") end
        DragAddDDSource("JS:Volume/Pan Smoother")
        if r.ImGui_Selectable(ctx, "POLARITY") then AddFX("JS:Channel Polarity Control") end
        DragAddDDSource("JS:Channel Polarity Control")
        if r.ImGui_Selectable(ctx, "3 BAND SPLITTER FX") then AddFX("JS:3-Band Splitter FX") end
        DragAddDDSource("JS:3-Band Splitter FX")
        if r.ImGui_Selectable(ctx, "BAND SELECT FX") then AddFX("JS:Band Select FX") end
        DragAddDDSource("JS:Band Select FX")
        r.ImGui_EndMenu(ctx)
    end
    if r.ImGui_Selectable(ctx, "CONTAINER") then AddFX("Container") end
    DragAddDDSource("Container")
    if LAST_USED_FX then
        r.ImGui_Separator(ctx)
        if r.ImGui_Selectable(ctx, "RECENT: " .. LAST_USED_FX) then AddFX(LAST_USED_FX) end
        DragAddDDSource(LAST_USED_FX)
    end
end

local function UpdateScroll()
    if not TRACK then return end
    local btn = r.ImGui_MouseButton_Right()
    if r.ImGui_IsMouseDragging(ctx, btn) then
        r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeAll())
        local drag_x, drag_y = r.ImGui_GetMouseDragDelta(ctx, nil, nil, btn)
        CANVAS.off_x, CANVAS.off_y = CANVAS.off_x + drag_x, CANVAS.off_y + drag_y
        r.ImGui_ResetMouseDragDelta(ctx, btn)
    end
end

local def_btn_h = custom_btn_h and custom_btn_h or ({ CalculateItemWH({ name = "||" }) })[2]
local mute = para_btn_size
local volume = para_btn_size
local function CalcContainerWH(fx_items)
    local rows = {}
    local W, H = 0, 0
    for i = 1, #fx_items do
        if fx_items[i].p == 0 or (i == 1 and fx_items[i].p > 0) then
            rows[#rows + 1] = {}
            table.insert(rows[#rows], i)
        else
            table.insert(rows[#rows], i)
        end
    end

    local btn_total_size = def_btn_h + (s_spacing_y)
    --local start_n_add_btn_size = s_spacing_y + (def_btn_h * 2)
    local start_n_add_btn_size = s_spacing_y + (def_btn_h + add_btn_h)
    local insert_point_size = add_btn_h + s_spacing_y


    for i = 1, #rows do
        local col_w, col_h = 0, 0
        if #rows[i] > 1 then
            for j = 1, #rows[i] do
                local w = fx_items[rows[i][j]].W and fx_items[rows[i][j]].W or
                    CalculateItemWH(fx_items[rows[i][j]]) + mute + volume + name_margin
                local h = fx_items[rows[i][j]].H and
                    fx_items[rows[i][j]].H + s_spacing_y + insert_point_size or --+ btn_total_size - (add_btn_h) - (add_btn_h//2) or
                    --(btn_total_size * 2)
                    (btn_total_size + insert_point_size)


                col_w = col_w + w
                if h > col_h then col_h = h end
            end
            col_w = col_w + (s_spacing_x * (#rows[i] - 1))
            col_w = col_w + (para_btn_size // 2)
        else
            local w = fx_items[rows[i][1]].W and fx_items[rows[i][1]].W + mute + s_spacing_x or
                CalculateItemWH(fx_items[rows[i][1]]) + mute + volume + s_spacing_x + name_margin
            local h = fx_items[rows[i][1]].H and fx_items[rows[i][1]].H + s_spacing_y + insert_point_size or
                --btn_total_size * 2
                (btn_total_size + insert_point_size)

            H = H + h
            if w > col_w then col_w = w end
        end
        if col_w > W then W = col_w end
        H = H + col_h
    end
    W = W + (s_window_x * 2) + s_spacing_x + mute + volume + para_btn_size

    H = H + start_n_add_btn_size + (s_window_y * 2)
    return W, H
end

local function IterateContainer(depth, track, container_id, parent_fx_count, previous_diff, container_guid, target)
    local row = 1
    local child_fx = {
        [0] = {
            IDX = 1,
            name = "DUMMY",
            type = "INSERT_POINT",
            p = 0,
            guid = "insertpoint_0" .. container_guid,
            pid = container_guid,
            ROW = 0,
        }
    }
    local container_fx_count = tonumber(({ TrackFX_GetNamedConfigParm(track, 0x2000000 + container_id,
        "container_count") })[2])
    local diff = depth == 0 and parent_fx_count + 1 or (parent_fx_count + 1) * previous_diff

    -- CALCULATER DEFAULT WIDTH
    local _, parrent_cont_name = r.TrackFX_GetFXName(track, 0x2000000 + container_id)
    local total_w = CalculateItemWH({ name = parrent_cont_name })
    -- CALCULATER DEFAULT WIDTH

    for i = 1, container_fx_count do
        local fx_id = container_id + (diff * i)
        local fx_guid = TrackFX_GetFXGUID(TRACK, 0x2000000 + fx_id)
        local _, fx_name = r.TrackFX_GetFXName(track, 0x2000000 + fx_id)
        fx_name = Stripname(fx_name, nil, true)

        local _, fx_type = TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "fx_type")
        local _, para = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "parallel")
        local wetparam = r.TrackFX_GetParamFromIdent(track, 0x2000000 + fx_id, ":wet")
        local wet_val = r.TrackFX_GetParam(track, 0x2000000 + fx_id, wetparam)
        local bypass = r.TrackFX_GetEnabled(track, 0x2000000 + fx_id)
        para = i == 1 and "0" or para -- MAKE FIRST ITEMS ALWAYS SERIAL (FIRST ITEMS ARE SAME IF IN PARALELL OR SERIAL)

        local h = pearson8(fx_name)
        local rr, gg, bb = r.ImGui_ColorConvertHSVtoRGB(h / 0xFF, 1, 1)
        local color = r.ImGui_ColorConvertDouble4ToU32(rr, gg, bb, 1)
        if i > 1 then row = para == "0" and row + 1 or row end

        local name_w = CalculateItemWH({ name = fx_name:gsub("(%S+: )", "") })

        if name_w > total_w then total_w = name_w end

        child_fx[#child_fx + 1] = {
            FX_ID = fx_id,
            type = fx_type,
            name = fx_name:gsub("(%S+: )", ""),
            IDX = i,
            pid = container_guid,
            guid = fx_guid,
            p = tonumber(para),
            bypass = bypass,
            ROW = row,
            INSERT_POINT = { pid = container_guid },
            wetparam = wetparam,
            wet_val = wet_val,
            auto_color = color,
        }

        if fx_type == "Container" then
            local sub_tbl, sub_W, sub_H = IterateContainer(depth + 1, track, fx_id, container_fx_count, diff, fx_guid,
                target)
            if sub_tbl then
                child_fx[#child_fx].sub = sub_tbl
                child_fx[#child_fx].depth = depth + 1
                child_fx[#child_fx].DIFF = diff * (container_fx_count + 1)
                child_fx[#child_fx].ID = fx_id -- CONTAINER ID (HERE ITS NOT THE SAME AS IDX WHICH IS FOR FX ITEMS)
                child_fx[#child_fx].W = sub_W
                child_fx[#child_fx].H = sub_H
            end
        end
    end

    total_w = total_w + mute + volume + (s_window_x * 2)

    local C_W, C_H = CalcContainerWH(child_fx)
    if C_W > total_w then total_w = C_W end

    return child_fx, total_w, C_H
end

local function GetOrUpdateFX(target)
    local track = TRACK
    PLUGINS[0] = {
        FX_ID = -1,
        name = "FX CHAIN",
        type = "ROOT",
        guid = "ROOT",
        pid = "ROOT",
        ID = -1,
        p = 0,
        ROW = 0,
        bypass = r.GetMediaTrackInfo_Value(TRACK, "I_FXEN") == 1
    }

    local row = 1
    local total_fx_count = TrackFX_GetCount(track)
    for i = 1, total_fx_count do
        local fx_guid = TrackFX_GetFXGUID(TRACK, i - 1)
        local _, fx_type = TrackFX_GetNamedConfigParm(track, i - 1, "fx_type")
        local _, fx_name = r.TrackFX_GetFXName(track, i - 1)
        fx_name = Stripname(fx_name, nil, true)
        local _, para = r.TrackFX_GetNamedConfigParm(track, i - 1, "parallel")
        local wetparam = r.TrackFX_GetParamFromIdent(track, i - 1, ":wet")
        local wet_val = r.TrackFX_GetParam(track, i - 1, wetparam)
        local bypass = r.TrackFX_GetEnabled(track, i - 1)

        local h = pearson8(fx_name)
        local rr, gg, bb = r.ImGui_ColorConvertHSVtoRGB(h / 0xFF, 1, 1)
        local color = r.ImGui_ColorConvertDouble4ToU32(rr, gg, bb, 1)

        if i > 1 then row = para == "0" and row + 1 or row end

        para = i == 1 and "0" or para -- MAKE FIRST ITEMS ALWAYS SERIAL (FIRST ITEMS ARE SAME IF IN PARALELL OR SERIAL)

        PLUGINS[#PLUGINS + 1] = {
            FX_ID = i,
            type = fx_type,
            name = fx_name:gsub("(%S+: )", ""),
            IDX = i,
            guid = fx_guid,
            pid = "ROOT",
            p = tonumber(para),
            bypass = bypass,
            ROW = row,
            INSERT_POINT = { pid = "ROOT" },
            wetparam = wetparam,
            wet_val = wet_val,
            auto_color = color,
        }
        if fx_type == "Container" then
            local sub_plugins, W, H = IterateContainer(0, track, i, total_fx_count, 0, fx_guid, target)
            if sub_plugins then
                PLUGINS[#PLUGINS].sub = sub_plugins
                PLUGINS[#PLUGINS].depth = 0
                PLUGINS[#PLUGINS].DIFF = (total_fx_count + 1)
                PLUGINS[#PLUGINS].ID = i -- CONTAINER ID (AT ROOT LEVEL SAME AS IDX BUT FOR READABILITY WILL KEEP IT)
                PLUGINS[#PLUGINS].W = W
                PLUGINS[#PLUGINS].H = H
            end
        end
    end
end

local function CreateAutoContainer(tbl, i, target)
    UpdateFxData()
    r.Undo_BeginBlock()
    local parrent_container = GetFx(tbl[i].pid)

    -- GET INSERTED FX GUID
    local inserted_fx_id = CalcFxID(parrent_container, target)
    local inserted_guid = r.TrackFX_GetFXGUID(TRACK, inserted_fx_id)

    -- INSERT CONTAINER AT BEGINNING
    r.TrackFX_AddByName(TRACK, "Container", false, -1000)

    -- UPDATE AFTER INSERTING CONTAINER
    UpdateFxData()
    parrent_container = GetFx(parrent_container.guid)
    local inserted_fx_tbl = GetFx(inserted_guid)
    local inserted_id = CalcFxID(parrent_container, inserted_fx_tbl.IDX)
    -- SET CONTAINER PARALLEL INFO AS TARGET FX
    r.TrackFX_SetNamedConfigParm(TRACK, 0x2000000 + 1, "parallel", tbl[i].p)
    local id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
    -- SET TARGET PLUGIN IN SERIAL IN CONTAINER
    r.TrackFX_SetNamedConfigParm(TRACK, inserted_id, "parallel", "0")
    -- MOVE FIRST PLUGIN
    r.TrackFX_CopyToTrack(TRACK, inserted_id, TRACK, id, true)

    -- MOVE UPDATE AND MOVE SECOND PLUGIN
    UpdateFxData()
    parrent_container = GetFx(parrent_container.guid)
    local original_fx2 = GetFx(tbl[i].guid)
    local original_fx_id = CalcFxID(parrent_container, original_fx2.IDX)
    -- SET PLUGIN AS SERIAL IN CONTAINER
    id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
    r.TrackFX_CopyToTrack(TRACK, original_fx_id, TRACK, id, true)

    -- MOVE CONTAINER IN ORIGINAL POSITION
    UpdateFxData()
    parrent_container = GetFx(parrent_container.guid)
    local original_pos = CalcFxID(parrent_container, i)
    r.TrackFX_CopyToTrack(TRACK, 0x2000000 + 1, TRACK, original_pos, true)

    EndUndoBlock("AUTOCONTAINER")
end

local function DragAddDDTarget(tbl, i, parallel, additiona_op)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DRAG ADD FX')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local parrent_container = GetParentContainerByGuid(tbl[i])
            local item_add_id = CalcFxID(parrent_container, i + 1)
            FX_ID = { item_add_id, parallel }
            r.Undo_BeginBlock()
            --AddFX(payload)
            local inserted_fx_id = AddFX(payload)
            if inserted_fx_id and additiona_op == "autocontainer" then
                r.PreventUIRefresh(1)
                CreateAutoContainer(tbl, i, inserted_fx_id + 1)
                r.PreventUIRefresh(-1)
                EndUndoBlock("ADDFX AUTOCONTAINER")
                return
            end
            if not additiona_op then EndUndoBlock("ADDFX") end
            return inserted_fx_id
        end
    end
end

local function SwapParallelInfo(src, dst)
    local _, src_p = r.TrackFX_GetNamedConfigParm(TRACK, src, "parallel")
    local _, dst_p = r.TrackFX_GetNamedConfigParm(TRACK, dst, "parallel")
    r.TrackFX_SetNamedConfigParm(TRACK, src, "parallel", dst_p)
    r.TrackFX_SetNamedConfigParm(TRACK, dst, "parallel", src_p)
end

local function CheckNextItemParallel(i, parrent_container)
    local src = CalcFxID(parrent_container, i)
    local dst = CalcFxID(parrent_container, i + 1)
    if not r.TrackFX_GetFXGUID(TRACK, dst) then return end
    local _, para = r.TrackFX_GetNamedConfigParm(TRACK, dst, "parallel")
    if para == "1" then SwapParallelInfo(src, dst) end
end

local function RemoveAllFX()
    r.PreventUIRefresh(1)
    r.Undo_BeginBlock()
    for i = r.TrackFX_GetCount(TRACK), 1, -1 do
        r.TrackFX_Delete(TRACK, i - 1)
    end
    r.PreventUIRefresh(-1)
    EndUndoBlock("REMOVE ALL TRACK FX")
end

local function ButtonAction(tbl, i)
    local parrent_container = GetParentContainerByGuid(tbl[i])
    local item_id = CalcFxID(parrent_container, i)
    if ALT then
        if tbl[i].type == "ROOT" then
            RemoveAllFX()
            return
        end
        CheckNextItemParallel(i, parrent_container)
        r.TrackFX_Delete(TRACK, item_id)
    else
        OpenFX(item_id)
    end
end

local function IsChild(parrent_guid, target)
    local found
    local dst = target
    while not found do
        if dst.type == "ROOT" then break end
        if dst.pid == parrent_guid then
            found = parrent_guid
            break
        else
            -- KEEP TRYING UNTIL ROOT IS FOUND
            dst = GetFx(dst.pid)
        end
    end
    return found
end

local function IsItemChildOfContainer(src_fx, dst_fx, insert_point, insert_type)
    -- DO NOT MOVE CONTAINER INTO ITS CHILDS
    if src_fx.type == "Container" then
        local dst_is_child = IsChild(src_fx.guid, dst_fx)
        if dst_is_child then return true end
    end
    if dst_fx.type == "Container" then
        if insert_point then
            --if IsItemChildOfContainer2(dst_fx, insert_point) then return true end
        else
            local src_is_child = IsChild(dst_fx.guid, src_fx)
            if src_is_child then return true end
        end
    end
end

local function Swap(src_parrent_guid, prev_src_id, dst_guid)
    -- UPDATE FX TABLE DATA WITH NEW IDS
    UpdateFxData()
    -- GET NEW PARRENT ID
    local src_parrent = GetFx(src_parrent_guid)
    local src_item_id = CalcFxID(src_parrent, prev_src_id)

    -- GET RECALCULATED DST
    local dst_fx = GetFx(dst_guid)
    local dst_parrent = GetParentContainerByGuid(dst_fx)
    local dst_item_id = CalcFxID(dst_parrent, dst_fx.IDX)

    r.TrackFX_CopyToTrack(TRACK, dst_item_id, TRACK, src_item_id, true)
end

local function MoveDDTarget(tbl, i, is_move, insert_point)
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'MOVE')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local src_guid, src_id = payload:match("(.+),(.+)")
            local src_fx = GetFx(src_guid)

            local dst_guid, dst_fx, dst_id = tbl.guid, GetFx(tbl.guid), i

            local src_parrent = GetParentContainerByGuid(src_fx)
            local src_item_id = CalcFxID(src_parrent, src_id)

            local dst_parrent = GetParentContainerByGuid(dst_fx)

            -- MOVING ON SAME LEVEL IS FUNKY WITH DESTINATION ID
            if is_move then
                if src_parrent.guid == dst_parrent.guid then
                    if not CTRL_DRAG then
                        dst_id = tonumber(src_id) > dst_id and dst_id + 1 or dst_id
                    else
                        dst_id = dst_id + 1
                    end
                else
                    dst_id = dst_id + 1
                end
                -- IF NEXT ITEM IS PARALLEL MOVE PARALLEL INFO TO IT
                if not CTRL_DRAG then CheckNextItemParallel(src_id, src_parrent) end
            end
            local dst_item_id = CalcFxID(dst_parrent, dst_id)

            -- DO NOT MOVE CONTAINERS IN ITS CHILDS
            if IsItemChildOfContainer(src_fx, dst_fx, insert_point, is_move) then return end

            r.Undo_BeginBlock()

            if not is_move then
                -- IF SWAPPING FX SWAP THEIR PARALLEL INFO
                SwapParallelInfo(src_item_id, dst_item_id)
            elseif is_move == "serial" and not CTRL_DRAG then
                -- MAKE PARALLEL INFO SERIAL (MOVING TO INSERT POINTS)
                r.TrackFX_SetNamedConfigParm(TRACK, src_item_id, "parallel", "0")
            elseif is_move == "parallel" and not CTRL_DRAG then
                -- DO NOT MOVE PARALLEL TO ITSELF
                if src_fx.guid == dst_fx.guid then return end
                -- MAKE PARALLEL INFO PARALLEL (MOVING TO PARALLEL BUTTON)
                r.TrackFX_SetNamedConfigParm(TRACK, src_item_id, "parallel", "1")
            end

            if is_move then
                r.TrackFX_CopyToTrack(TRACK, src_item_id, TRACK, dst_item_id, not CTRL_DRAG)
                if CTRL_DRAG then
                    -- SET NEW PARALLEL INFO WHEN COPIED
                    local para_info = is_move == "parallel" and "1" or "0"
                    r.TrackFX_SetNamedConfigParm(TRACK, dst_item_id, "parallel", para_info)
                end
                -- EndUndoBlock("Move Plugins")
                return dst_item_id
            end
            -- SWAP SOURCE AND DESTINATION
            r.TrackFX_CopyToTrack(TRACK, src_item_id, TRACK, dst_item_id, true)
            Swap(src_parrent.guid, src_id, dst_guid)
            --EndUndoBlock("Move Plugins")
        end
    end
end

function Deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Deepcopy(orig_key)] = Deepcopy(orig_value)
        end
        setmetatable(copy, Deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function MoveDDSource(tbl, i)
    if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_SourceNoPreviewTooltip()) then
        local data = table.concat({ tbl.guid, i }, ",")
        if not DRAG_MOVE then
            DRAG_MOVE = Deepcopy(tbl)
            DRAG_MOVE.move_guid = tbl.guid
            DRAG_MOVE.guid = "MOVE_PREVIEW"
        end
        r.ImGui_SetDragDropPayload(ctx, "MOVE", data)

        dummy_preview[1].type = DRAG_MOVE.type == "Container" and "Container" or "PREVIEW"
        --if DRAG_MOVE.type == "Container" then
        DRAW_PREVIEW = true
        --else
        --local width = CalculateItemWH({ name = tbl.name })
        --DrawButton(dummy_preview, 1, Stripname(tbl.name, true), width, 1)
        --end
        r.ImGui_EndDragDropSource(ctx)
    end
end

local function DragAndDropMove(tbl, i)
    if tbl[i].type == "ROOT" then return end
    MoveDDSource(tbl[i], i)
    if not CTRL_DRAG then
        MoveDDTarget(tbl[i], i)
    else
        local xs, ys = r.ImGui_GetItemRectMin(ctx)
        local xe, ye = r.ImGui_GetItemRectMax(ctx)
        if r.ImGui_IsMouseHoveringRect(ctx, xs, ys, xe, ye, false) then
            r.ImGui_DrawList_AddRectFilled(draw_list, xs - (s_spacing_x) - mute - 0.5, ys - (s_spacing_y // 0.8),
                xe + (s_spacing_x) + (mute // 1.2) + 0.5,
                ys - (s_spacing_y // 2) + 2, r.ImGui_GetColorEx(ctx, COLOR["enabled"]), 2,
                r.ImGui_DrawFlags_RoundCornersTopLeft()|r.ImGui_DrawFlags_RoundCornersTopRight())
            r.ImGui_DrawList_AddRect(draw_list, xs - (s_spacing_x) - mute, ys - (s_spacing_y // 2),
                xe + (s_spacing_x) + (mute // 1.2),
                ye + (s_spacing_y // 2),
                r.ImGui_GetColorEx(ctx, COLOR["enabled"]), 2, nil, 2)
        end

        -- DISABEL DRAG AND DROP YELLOW RECTANGLE HERE SINCE WE ARE DRAWING OUR OWN
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0)
        local inserted_fx_id = MoveDDTarget(tbl[i], i, "serial", tbl[i].INSERT_POINT)
        r.ImGui_PopStyleColor(ctx)
        -- DO AUTO CONTAINER MAGIC
        if inserted_fx_id then
            r.PreventUIRefresh(1)
            CreateAutoContainer(tbl, i, i + 1)
            r.PreventUIRefresh(-1)
        end
        EndUndoBlock("Move Plugins")
    end
end

local function ParallelRowWidth(tbl, i, item_width)
    local total_w, total_h = 0, tbl[i].H and tbl[i].H - s_spacing_y or 0
    local idx = i + 1
    local last_big_idx = i
    while true do
        if not tbl[idx] then break end
        if tbl[idx].p == 0 then
            break
        else
            local width = tbl[idx].W and tbl[idx].W or CalculateItemWH(tbl[idx]) + mute + volume + name_margin
            local height = tbl[idx].H and tbl[idx].H - s_spacing_y or 0

            if total_h < height then
                total_h = height
                last_big_idx = idx
            end
            total_w = total_w + width + s_spacing_x
            idx = idx + 1
        end
    end
    if last_big_idx then
        tbl[last_big_idx].biggest = true
    end
    return total_w + item_width - para_btn_size
end

local ROUND_FLAG = {
    ["L"] = r.ImGui_DrawFlags_RoundCornersTopLeft()|r.ImGui_DrawFlags_RoundCornersBottomLeft(),
    ["R"] = r.ImGui_DrawFlags_RoundCornersTopRight()|r.ImGui_DrawFlags_RoundCornersBottomRight()
}

local function DrawListButton(name, color, round_side, icon, hover)
    local multi_color = IS_DRAGGING_RIGHT_CANVAS and color or ColorToHex(color, hover and 50 or 0)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w = xe - xs
    local h = ye - ys

    local round_flag = round_side and ROUND_FLAG[round_side] or nil
    local round_amt = round_flag and ROUND_CORNER or 0

    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, r.ImGui_GetColorEx(ctx, multi_color), round_amt,
        round_flag)
    if r.ImGui_IsItemActive(ctx) then
        r.ImGui_DrawList_AddRect(draw_list, xs - 2, ys - 2, xe + 2, ye + 2, 0x22FF44FF, 3, nil, 2)
    end

    if icon then r.ImGui_PushFont(ctx, ICONS_FONT) end

    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local FONT_SIZE = r.ImGui_GetFontSize(ctx)
    local font_color = CalculateFontColor(color)

    r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, xs + (w / 2) - (label_size / 2),
        ys + ((h / 2)) - FONT_SIZE / 2, r.ImGui_GetColorEx(ctx, font_color), name)
    if icon then r.ImGui_PopFont(ctx) end
end

local function AddFX_P(tbl, i)
    r.ImGui_SameLine(ctx)
    r.ImGui_PushID(ctx, tbl[i].guid .. "parallel")
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), (DRAG_ADD_FX and (DRAG_ADD_FX and not CTRL and 1 or 0.3)) or 1) -- alpha

    if r.ImGui_InvisibleButton(ctx, "||", para_btn_size, def_btn_h) then
        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_add_id = CalcFxID(parrent_container, i + 1)
        FX_ID = { item_add_id, "parallel" }
        OPEN_FX_LIST = true
    end
    Tooltip("ADD NEW PARALLEL FX")
    r.ImGui_PopID(ctx)

    if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 1) then
        --if tbl[i].p > 0 then
        OPEN_RIGHT_C_CTX_PARALLEL = true
        PARA_DATA                 = { tbl, i }
        R_CLICK_DATA              = { tbl, i }
        --end
    end

    DrawListButton("||",
        (DRAG_ADD_FX or DRAG_MOVE) and ColorToHex(COLOR["n"], 10) or
        r.ImGui_IsItemHovered(ctx) and ColorToHex(COLOR["n"], 10) or COLOR["parallel"])
    if not CTRL then
        DragAddDDTarget(tbl, i, "parallel")
    end
    MoveDDTarget(tbl[i], i, "parallel", tbl[i].INSERT_POINT)
    r.ImGui_PopStyleVar(ctx)
end

local function DrawLines()
    for i = 1, #LINE_POINTS do
        local p_tbl = LINE_POINTS[i]
        r.ImGui_DrawList_AddLine(draw_list, p_tbl[1], p_tbl[2], p_tbl[3], p_tbl[4], COLOR["wire"], WireThickness)
    end
end

local function InsertPointButton(tbl, i, x)
    r.ImGui_SetCursorPosX(ctx, x - (add_bnt_w // 2))
    r.ImGui_PushID(ctx, tbl[i].guid .. "insert_point")
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), DRAG_ADD_FX and (DRAG_ADD_FX and not CTRL and 1 or 0.3) or 1) -- alpha
    if r.ImGui_InvisibleButton(ctx, "+", add_bnt_w, add_btn_h) then                                                   -- if r.ImGui_InvisibleButton(ctx, "+", add_bnt_w, def_btn_h) then
        CLICKED = tbl[i].guid
        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_add_id = CalcFxID(parrent_container, i + 1)
        FX_ID = { item_add_id }
        OPEN_FX_LIST = true
    end
    r.ImGui_PopID(ctx)
    Tooltip("ADD NEW SERIAL FX")
    if not CTRL then
        DragAddDDTarget(tbl, i)
    end
    if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 1) then
        OPEN_RIGHT_C_CTX_INSERT = true
        R_CLICK_DATA            = { tbl, i }
    end
    if i == #tbl or (r.ImGui_IsItemHovered(ctx) and not IS_DRAGGING_RIGHT_CANVAS) or DRAG_MOVE or DRAG_ADD_FX or CLICKED == tbl[i].guid then
        DrawListButton("+",
            (DRAG_ADD_FX or DRAG_MOVE) and ColorToHex(COLOR["parallel"], 10) or
            r.ImGui_IsItemHovered(ctx) and ColorToHex(COLOR["n"], 10) or COLOR["parallel"])
    end
    r.ImGui_PopStyleVar(ctx)
    MoveDDTarget(tbl[i], i, "serial", tbl[i].INSERT_POINT)
end

local function CheckFX_P(tbl, i)
    if i == 0 then return end
    if tbl[i].p == 0 then
        if (tbl[i + 1] and tbl[i + 1].p + tbl[i].p == 0) or not tbl[i + 1] then
            AddFX_P(tbl, i)
        end
    else
        if tbl[i + 1] and tbl[i + 1].p + tbl[i].p == 1 or not tbl[i + 1] then
            AddFX_P(tbl, i)
        end
    end
end

local function AddInsertPoints(tbl, i, x)
    if tbl[i + 1] and tbl[i + 1].p == 0 or not tbl[i + 1] then
        InsertPointButton(tbl, i, x)
        return true
    end
end

local function TypToColor(tbl)
    local color = COLOR[tbl.type] and COLOR[tbl.type] or COLOR["n"]
    return tbl.bypass and color or ColorToHex(COLOR["bypass"], -40)
end

local function AutoContainer(tbl, i)
    if not DRAG_ADD_FX then return end
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)

    --local w, h = (xe - xs), (ye - ys)

    -- DRAW "CONTAINER" RECTANGLE
    if r.ImGui_IsMouseHoveringRect(ctx, xs, ys, xe, ye, false) then
        r.ImGui_DrawList_AddRectFilled(draw_list, xs - (s_spacing_x) - mute - 0.5, ys - (s_spacing_y // 0.8),
            xe + (s_spacing_x) + (mute // 1.2) + 0.5,
            ys - (s_spacing_y // 2) + 2, r.ImGui_GetColorEx(ctx, COLOR["enabled"]), 2,
            r.ImGui_DrawFlags_RoundCornersTopLeft()|r.ImGui_DrawFlags_RoundCornersTopRight())
        r.ImGui_DrawList_AddRect(draw_list, xs - (s_spacing_x) - mute, ys - (s_spacing_y // 2),
            xe + (s_spacing_x) + (mute // 1.2),
            ye + (s_spacing_y // 2),
            r.ImGui_GetColorEx(ctx, COLOR["enabled"]), 2, nil, 2)
    end
    --local parrent_container = GetParentContainerByGuid(tbl[i])

    -- DISABEL DRAG AND DROP YELLOW RECTANGLE HERE SINCE WE ARE DRAWING OUR OWN
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0)
    local inserted_fx_id = DragAddDDTarget(tbl, i, nil, "autocontainer")
    r.ImGui_PopStyleColor(ctx)

    -- DO AUTO CONTAINER MAGIC
    -- if inserted_fx_id then
    --     r.PreventUIRefresh(1)
    --     CreateAutoContainer(tbl, i, inserted_fx_id + 1)
    --     r.PreventUIRefresh(-1)
    --     -- UPDATE AFTER ADDING FX
    --     -- UpdateFxData()
    --     -- r.Undo_BeginBlock()
    --     -- local parrent_container = GetFx(tbl[i].pid)

    --     -- -- GET INSERTED FX GUID
    --     -- inserted_fx_id = CalcFxID(parrent_container, inserted_fx_id + 1)
    --     -- local inserted_guid = r.TrackFX_GetFXGUID(TRACK, inserted_fx_id)

    --     -- -- INSERT CONTAINER AT BEGINNING
    --     -- r.TrackFX_AddByName(TRACK, "Container", false, -1000)

    --     -- -- UPDATE AFTER INSERTING CONTAINER
    --     -- UpdateFxData()
    --     -- parrent_container = GetFx(parrent_container.guid)
    --     -- local inserted_fx_tbl = GetFx(inserted_guid)
    --     -- local inserted_id = CalcFxID(parrent_container, inserted_fx_tbl.IDX)
    --     -- -- SET CONTAINER PARALLEL INFO AS TARGET FX
    --     -- r.TrackFX_SetNamedConfigParm(TRACK, 0x2000000 + 1, "parallel", tbl[i].p)
    --     -- local id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
    --     -- -- SET TARGET PLUGIN IN SERIAL IN CONTAINER
    --     -- r.TrackFX_SetNamedConfigParm(TRACK, inserted_id, "parallel", "0")
    --     -- -- MOVE FIRST PLUGIN
    --     -- r.TrackFX_CopyToTrack(TRACK, inserted_id, TRACK, id, true)

    --     -- -- MOVE UPDATE AND MOVE SECOND PLUGIN
    --     -- UpdateFxData()
    --     -- parrent_container = GetFx(parrent_container.guid)
    --     -- local original_fx2 = GetFx(tbl[i].guid)
    --     -- local original_fx_id = CalcFxID(parrent_container, original_fx2.IDX)
    --     -- -- SET PLUGIN AS SERIAL IN CONTAINER
    --     -- id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
    --     -- r.TrackFX_CopyToTrack(TRACK, original_fx_id, TRACK, id, true)

    --     -- -- MOVE CONTAINER IN ORIGINAL POSITION
    --     -- UpdateFxData()
    --     -- parrent_container = GetFx(parrent_container.guid)
    --     -- local original_pos = CalcFxID(parrent_container, i)
    --     -- r.TrackFX_CopyToTrack(TRACK, 0x2000000 + 1, TRACK, original_pos, true)

    --     -- EndUndoBlock("AUTOCONTAINER")
    -- end
end

local function DrawVolumePanHelper(tbl, i, w)
    -- if not B then return end
    if tbl[i].name:match(VOL_PAN_HELPER) then
        if DRAG_MOVE and DRAG_MOVE.move_guid == tbl[i].guid and not CTRL_DRAG then return end

        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_id = CalcFxID(parrent_container, i)
        local vol_val = r.TrackFX_GetParam(TRACK, item_id, 0) -- 0 IS VOL IDENTIFIER
        r.ImGui_SameLine(ctx, nil, mute)
        r.ImGui_PushID(ctx, tbl[i].guid .. "helper_vol")
        local rvh_v, v = MyKnob("", "arc", vol_val, -60, 12, true)
        if rvh_v then
            r.TrackFX_SetParam(TRACK, item_id, 0, v)
        end
        local vol_hover = r.ImGui_IsItemHovered(ctx)
        if vol_hover and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
            r.TrackFX_SetParam(TRACK, item_id, 0, 0)
        end

        r.ImGui_PopID(ctx)
        r.ImGui_SameLine(ctx, nil, w - (mute * 4))
        local pan_val = r.TrackFX_GetParam(TRACK, item_id, 1) -- 1 IS PAN IDENTIFIER
        r.ImGui_PushID(ctx, tbl[i].guid .. "helper_pan")
        local rvh_p, p = MyKnob("", "knob", pan_val, -100, 100, nil, true)
        if rvh_p then
            r.TrackFX_SetParam(TRACK, item_id, 1, p)
        end
        local pan_hover = r.ImGui_IsItemHovered(ctx)
        if pan_hover and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
            r.TrackFX_SetParam(TRACK, item_id, 1, 0)
        end

        r.ImGui_PopID(ctx)
        return "VOL - PAN", mute, vol_hover, pan_hover
    elseif tbl[i].name:match(PHASE_HELPER) then
        --if DRAG_MOVE and DRAG_MOVE.move_guid == tbl[i].guid and not CTRL_DRAG then return end

        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_id = CalcFxID(parrent_container, i)
        r.ImGui_SameLine(ctx, nil, mute // 4)
        r.ImGui_PushID(ctx, tbl[i].guid .. "helper_phase")
        local phase_val = r.TrackFX_GetParam(TRACK, item_id, 0) -- 1 IS PAN IDENTIFIER
        local pos = { r.ImGui_GetCursorScreenPos(ctx) }
        if r.ImGui_InvisibleButton(ctx, "PHASE", mute, mute) then
            r.TrackFX_SetParam(TRACK, item_id, 0, phase_val == 0 and 3 or 0)
        end
        local phase_hover = r.ImGui_IsItemHovered(ctx)
        local center = { pos[1] + Knob_Radius, pos[2] + Knob_Radius }
        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], Knob_Radius - 2,
            phase_val == 0 and COLOR["knob_bg"] or 0x3a57ffff)
        DrawListButton("P", 0)
        r.ImGui_PopID(ctx)
        return "PHASE " .. (phase_val == 0 and "NORMAL" or "INVERTED"), mute, phase_hover
    end
end

local function FindNextPrevRow(tbl, i, next, highest)
    local target
    local idx = i + next
    local row = tbl[i].ROW
    local last_in_row = i
    local number_of_parallels = 1
    while not target do
        if not tbl[idx] then
            last_in_row = idx + (-next)
            target = tbl[idx]
            break
        end
        if row ~= tbl[idx].ROW then
            if highest then
                if tbl[idx].biggest then
                    target = tbl[idx]
                else
                    if tbl[idx].p == 0 then
                        target = tbl[idx]
                        break
                    end
                    idx = idx + next
                end
            else
                target = tbl[idx]
                last_in_row = idx + (-next)
            end
        else
            idx = idx + next
            number_of_parallels = number_of_parallels + 1
        end
    end
    return target, last_in_row, number_of_parallels
end

local function SoloAllBeforePoint(parrent, cur_fx_id, cur_tbl, cur_i)
    local _, first = FindNextPrevRow(cur_tbl, cur_i, -1)
    local _, last = FindNextPrevRow(cur_tbl, cur_i, 1)
    --if parrent.type == "ROOT" and cur_tbl[cur_i].type ~= "ROOT" then
    --local _, first = FindNextPrevRow(cur_tbl, cur_i, -1)
    --local _, last = FindNextPrevRow(cur_tbl, cur_i, 1)

    for i = first, last do
        local id = CalcFxID(parrent, i)
        r.TrackFX_SetEnabled(TRACK, id, false)
    end
    --r.TrackFX_SetEnabled(TRACK, cur_fx_id, true)
    -- else
    --     local _, c_fx_count = r.TrackFX_GetNamedConfigParm(TRACK, 0x2000000 + parrent.ID, "container_count")
    --     for i = 1, r.TrackFX_GetCount(TRACK) do
    --     end
    --     --     -- r.TrackFX_SetEnabled(TRACK, i - 1, true)
    --     -- end
    -- end
    r.TrackFX_SetEnabled(TRACK, cur_fx_id, true)
end

function DrawButton(tbl, i, name, width, fade, del_color)
    if tbl[i].type == "INSERT_POINT" then return end
    --! LOWER BUTTON ALPHA SO INSERT POINTS STANDOUT
    local SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    r.ImGui_DrawListSplitter_Split(SPLITTER, 2)
    local alpha = (DRAG_ADD_FX and not CTRL) and 0.4 or fade
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), fade) -- alpha
    r.ImGui_BeginGroup(ctx)
    --! DRAW BYPASS
    r.ImGui_PushID(ctx, tbl[i].guid .. "bypass")
    if r.ImGui_InvisibleButton(ctx, "B", para_btn_size, def_btn_h) then
        local parrent_container = GetParentContainerByGuid(tbl[i])
        local item_id = CalcFxID(parrent_container, i)
        --if not SHIFT then
        if tbl[i].type == "ROOT" then
            r.SetMediaTrackInfo_Value(TRACK, "I_FXEN", tbl[i].bypass and 0 or 1)
        else
            if tbl[i].type == "Container" then
                if SHIFT then
                    SoloAllBeforePoint(parrent_container, item_id, tbl, i)
                else
                    r.TrackFX_SetEnabled(TRACK, item_id, not tbl[i].bypass)
                end
            else
                r.TrackFX_SetEnabled(TRACK, item_id, not tbl[i].bypass)
            end
        end
        --else
        --SoloAllBeforePoint(parrent_container, item_id, tbl, i)
        --end
    end
    Tooltip((SHIFT and tbl[i].type == "Container") and "SOLO IN LANE" or "BYPASS")
    r.ImGui_PopID(ctx)
    local color = tbl[i].bypass and COLOR["enabled"] or COLOR["bypass"]
    --color = bypass_color and bypass_color or color
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)

    if DRAG_MOVE and DRAG_MOVE.move_guid == tbl[i].guid and not CTRL_DRAG then
    else
        DrawListButton("A", color, "L", true, r.ImGui_IsItemHovered(ctx))
    end

    --! DRAW VOL/PAN PLUGIN
    local helper_name, helper, vol_hover, pan_hover = DrawVolumePanHelper(tbl, i, width)
    name = helper_name or name

    r.ImGui_PushID(ctx, tbl[i].guid .. "button")
    --! DRAW BUTTON
    r.ImGui_SameLine(ctx, helper and helper, 0)
    if r.ImGui_InvisibleButton(ctx, name, width, def_btn_h) then ButtonAction(tbl, i) end
    r.ImGui_PopID(ctx)
    if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 1) then
        if tbl[i].type ~= "ROOT" then
            OPEN_RIGHT_C_CTX = true
            R_CLICK_DATA = { tbl, i }
        else
            OPEN_RIGHT_C_CTX_FX_CHAIN = true
        end
    end
    local btn_hover = r.ImGui_IsItemHovered(ctx) and (not vol_hover and not pan_hover)
    if (tbl[i].type ~= "Container" and tbl[i].type ~= "ROOT") then
        AutoContainer(tbl, i)
    end
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    local is_del_color = del_color and del_color or (ALT and btn_hover) and COLOR["del"] or
        (AUTO_COLORING and tbl[i].auto_color and tbl[i].auto_color or TypToColor(tbl[i]))
    DragAndDropMove(tbl, i)
    if DRAG_MOVE and DRAG_MOVE.move_guid == tbl[i].guid and not CTRL_DRAG then
        local xs, ys = r.ImGui_GetItemRectMin(ctx)
        local xe, ye = r.ImGui_GetItemRectMax(ctx)
        r.ImGui_DrawList_AddRect(draw_list, xs - mute, ys, xe, ye, 0x666666FF, 3, nil)
    else
        DrawListButton(name, is_del_color, --  (ALT and btn_hover) and COLOR["del"] or TypToColor(tbl[i])
            tbl[i].type ~= "ROOT" and "R" or nil, nil, btn_hover)
    end
    -- if CTRL_DOWN then
    --     if DRAG_ADD_FX then
    --         if tbl[i].type ~= "Container" and tbl[i].type ~= "ROOT" then
    --             local added_fx_idx = DragAddDDTarget(tbl, i, tbl[i].p == 1, "swapadd")
    --             -- SWAP WITH INSERTED PLUGIN
    --             if added_fx_idx then
    --                 local parrent_container = GetParentContainerByGuid(tbl[i])
    --                 local item_id = CalcFxID(parrent_container, i)
    --                 r.TrackFX_Delete(TRACK, item_id)
    --                 EndUndoBlock("HOTSWAP INSERT")
    --             end
    --         end
    --     end
    -- end


    --! DRAW VOLUME
    if tbl[i].wet_val then
        r.ImGui_SameLine(ctx, nil, 0)
        r.ImGui_PushID(ctx, tbl[i].guid .. "wet/dry")
        local is_vol
        if tbl[i + 1] and tbl[i + 1].p > 0 or tbl[i].p == 1 then
            is_vol = true
        end
        local rv, v = MyKnob("", is_vol and "arc" or "dry_wet", tbl[i].wet_val * 100, 0, 100, is_vol)
        if rv then
            local parrent_container = GetParentContainerByGuid(tbl[i])
            local item_id = CalcFxID(parrent_container, i)
            r.TrackFX_SetParam(TRACK, item_id, tbl[i].wetparam, v / 100)
        end
        if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
            local parrent_container = GetParentContainerByGuid(tbl[i])
            local item_id = CalcFxID(parrent_container, i)
            r.TrackFX_SetParam(TRACK, item_id, tbl[i].wetparam, 1)
        end
        r.ImGui_PopID(ctx)
    end
    if tbl[i].name == "FX CHAIN" then
        r.ImGui_SameLine(ctx, nil, 0)
        r.ImGui_PushID(ctx, tbl[i].guid .. "enclose")

        if r.ImGui_InvisibleButton(ctx, "e", para_btn_size, def_btn_h) then
            if r.TrackFX_GetCount(TRACK) ~= 0 then
                r.PreventUIRefresh(1)
                r.Undo_BeginBlock()
                r.TrackFX_AddByName(TRACK, "Container", false, -1000)
                for j = r.TrackFX_GetCount(TRACK), 1, -1 do
                    local id = 0x2000000 + 1 + (r.TrackFX_GetCount(TRACK) + 1)
                    r.TrackFX_CopyToTrack(TRACK, j, TRACK, id, true)
                end
                EndUndoBlock("ENCLOSE ALL INTO CONTAINER")
                r.PreventUIRefresh(-1)
            end
        end
        Tooltip("ENCLOSE ALL INTO CONTAINER")
        r.ImGui_PopID(ctx)

        DrawListButton("K", color, "R", true, r.ImGui_IsItemHovered(ctx))
    end
    r.ImGui_EndGroup(ctx)
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_DrawListSplitter_Merge(SPLITTER)
    return btn_hover
end

local function SetItemPos(tbl, i, x, item_w)
    if tbl[i].p > 0 then
        r.ImGui_SameLine(ctx)
    else
        if tbl[i].type == "ROOT" then
            -- START ONLY HAS MUTE
            item_w = item_w + mute + volume
        else
            -- NORMAL FX HAS BYPASS AND VOLUME
            if tbl[i].type ~= "Container" then
                item_w = item_w + mute + volume
            end
        end
        r.ImGui_SetCursorPosX(ctx, x - (item_w // 2))

        if tbl[i + 1] and tbl[i + 1].p > 0 then
            local total_w = ParallelRowWidth(tbl, i, item_w)

            local text_size = (total_w // 2) + (para_btn_size // 2)
            r.ImGui_SetCursorPosX(ctx, x - text_size)
        end
    end
end

local function GenerateCoordinates(tbl, i, last)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)

    local x = xs + ((xe - xs) // 2)
    if last then
        return { x = x, ys = ys + s_spacing_y + (add_btn_h), ye = ye }
    end
    tbl[i].x, tbl[i].xs, tbl[i].xe, tbl[i].ys, tbl[i].ye = x, xs, xe, ys, ye
end

local function CreateLines(top, cur, bot)
    if top then
        local x1 = cur.x
        local y1 = top.ye + s_spacing_y + (add_btn_h // 2) --+ (def_btn_h // 2) --- (add_btn_h // 2)
        local x2 = x1
        local y2 = cur.ys
        LINE_POINTS[#LINE_POINTS + 1] = { x1, y1, x2, y2 }
    end
    if bot then
        local x1 = cur.x
        local y1 = cur.ye
        local x2 = x1
        local y2 = bot.ys - s_spacing_y - (add_btn_h // 2) -- (def_btn_h // 2)
        LINE_POINTS[#LINE_POINTS + 1] = { x1, y1, x2, y2 }
    end
end

local function AddRowSeparatorLine(A, B, bot)
    if A.FX_ID == B.FX_ID then return end
    local x1 = A.x
    local y1 = bot.ys - s_spacing_y - (add_btn_h // 2) --- (def_btn_h // 2)
    local x2 = B.x
    local y2 = bot.ys - s_spacing_y - (add_btn_h // 2) --- (def_btn_h // 2)

    LINE_POINTS[#LINE_POINTS + 1] = { x1, y1, x2, y2 }

    x1 = A.x
    y1 = A.ys - s_spacing_y - (add_btn_h // 2) --- (def_btn_h // 2)
    x2 = B.x
    y2 = A.ys - s_spacing_y - (add_btn_h // 2) --- (def_btn_h // 2)

    LINE_POINTS[#LINE_POINTS + 1] = { x1, y1, x2, y2 }
end

function DrawPlugins(center, tbl, fade, color_del)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), fade)
    local last
    for i = 0, #tbl do
        --local name = tbl[i].name:gsub("(%S+: )", "")
        --local name = Stripname(tbl[i].name, true, true)
        local name = tbl[i].name --:gsub("(%S+: )", "")
        local width, height = CalculateItemWH(tbl[i])
        width = tbl[i].W and tbl[i].W or width + name_margin
        height = tbl[i].H and tbl[i].H or height
        SetItemPos(tbl, i, center, width)
        if tbl[i].type ~= "Container" then
            local button_hovered = DrawButton(tbl, i, name, width, fade, color_del)
            color_del = tbl[i].type == "ROOT" and button_hovered and ALT and COLOR["bypass"] or color_del
        end
        if tbl[i].type == "Container" then
            r.ImGui_BeginGroup(ctx)
            r.ImGui_PushID(ctx, tbl[i].guid .. "container")
            -- r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(),
            --    DRAG_MOVE and DRAG_MOVE.move_guid == tbl[i].guid and 0 or 1)
            if r.ImGui_BeginChild(ctx, "##", width, height, true, WND_FLAGS) then
                if DRAG_MOVE and DRAG_MOVE.move_guid == tbl[i].guid and not CTRL_DRAG then
                else
                    local button_hovered = DrawButton(tbl, i, name, -volume, fade, color_del)
                    GenerateCoordinates(tbl, i)

                    -- HIGLIGHT EVERYCHILD WITH DELETE COLOR IF PARRENT IS GOING TO BE DELETED
                    local del_color = color_del and color_del or button_hovered and ALT and COLOR["bypass"]

                    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_Alpha(), tbl[i].bypass and 0.5 or fade)
                    local fade_alpha = not tbl[i].bypass and 0.5 or fade
                    DrawPlugins(r.ImGui_GetCursorPosX(ctx) + (width // 2) - s_window_x, tbl[i].sub, fade_alpha, del_color)
                    r.ImGui_PopStyleVar(ctx)
                end
                r.ImGui_EndChild(ctx)
            end
            -- r.ImGui_PopStyleVar(ctx)

            r.ImGui_EndGroup(ctx)
            r.ImGui_PopID(ctx)
        end
        GenerateCoordinates(tbl, i)
        CheckFX_P(tbl, i)
        if AddInsertPoints(tbl, i, center) then
            last = GenerateCoordinates(tbl, i, "last")
        end
    end
    r.ImGui_PopStyleVar(ctx)

    local last_row, first_in_row
    for i = 0, #tbl do
        if last_row ~= tbl[i].ROW then
            first_in_row = tbl[i]
            last_row = tbl[i].ROW
        end
        local top = FindNextPrevRow(tbl, i, -1, "HIGHEST")
        local cur = tbl[i]
        local bot = FindNextPrevRow(tbl, i, 1) or last
        CreateLines(top, cur, bot)

        if tbl[i + 1] and tbl[i + 1].ROW ~= last_row or not tbl[i + 1] then
            local last_in_row = tbl[i]
            AddRowSeparatorLine(first_in_row, last_in_row, bot)
            first_in_row = nil
        end
    end
end

local function Paste(replace, para, insert, move)
    if not CLIPBOARD.tbl then return end
    if CLIPBOARD.guid == R_CLICK_DATA[1][R_CLICK_DATA[2]].guid then return end
    local parrent_container = GetParentContainerByGuid(R_CLICK_DATA[1][R_CLICK_DATA[2]])
    local item_id = CalcFxID(parrent_container, (para or insert) and R_CLICK_DATA[2] + 1 or R_CLICK_DATA[2])

    r.Undo_BeginBlock()
    r.TrackFX_CopyToTrack(CLIPBOARD.track, CLIPBOARD.id, TRACK, item_id, move and true or false)
    r.TrackFX_SetNamedConfigParm(TRACK, item_id, "parallel", (insert and "0" or R_CLICK_DATA[1][R_CLICK_DATA[2]].p))
    if replace then
        local del_id = CalcFxID(parrent_container, R_CLICK_DATA[2] + 1)
        r.TrackFX_Delete(TRACK, del_id)
    end
    if para then
        r.TrackFX_SetNamedConfigParm(TRACK, item_id, "parallel", 1)
    end
    EndUndoBlock("COPY FX")
    UpdateClipboardInfo()
    --AAA = true
end

local function Rename()
    local tbl, i = R_CLICK_DATA[1], R_CLICK_DATA[2]
    local RV
    if r.ImGui_IsWindowAppearing(ctx) then
        r.ImGui_SetKeyboardFocusHere(ctx)
        NEW_NAME = tbl[i].name:gsub("(%S+: )", "")
    end
    RV, NEW_NAME = r.ImGui_InputText(ctx, 'Name', NEW_NAME, r.ImGui_InputTextFlags_AutoSelectAll())
    COMMENT_ACTIVE = r.ImGui_IsItemActive(ctx)
    if r.ImGui_Button(ctx, 'OK') or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or
        r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
        NEW_NAME = NEW_NAME:gsub("^%s*(.-)%s*$", "%1") -- remove trailing and leading
        if #NEW_NAME ~= 0 then SAVED_NAME = NEW_NAME end
        if SAVED_NAME then
            local parrent_container = GetParentContainerByGuid(tbl[i])
            local item_id = CalcFxID(parrent_container, i)
            r.TrackFX_SetNamedConfigParm(TRACK, item_id, "renamed_name", SAVED_NAME)
        end
        R_CLICK_DATA = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'Cancel') then
        R_CLICK_DATA = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        R_CLICK_DATA = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
end
local function RCCTXMenuInsert()
    if CLIPBOARD.tbl then
        if r.ImGui_MenuItem(ctx, 'PASTE') then
            Paste(false, false, true)
        end
    else
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

local function RCCTXMenuParallel()
    if PARA_DATA[1][PARA_DATA[2]].p > 0 then
        if r.ImGui_MenuItem(ctx, 'RESET LANE VOLUME') then
            local parrent_container = GetParentContainerByGuid(PARA_DATA[1][PARA_DATA[2]])
            local _, first_idx_in_row = FindNextPrevRow(PARA_DATA[1], PARA_DATA[2], -1)

            for i = first_idx_in_row, PARA_DATA[2] do
                local item_id = CalcFxID(parrent_container, i)
                r.TrackFX_SetParam(TRACK, item_id, PARA_DATA[1][i].wetparam, 1)
            end
        end
        if r.ImGui_MenuItem(ctx, 'ADJUST LANE VOLUME TO UNITY') then
            local parrent_container = GetParentContainerByGuid(PARA_DATA[1][PARA_DATA[2]])
            local _, first_idx_in_row, p_cnt = FindNextPrevRow(PARA_DATA[1], PARA_DATA[2], -1)

            for i = first_idx_in_row, PARA_DATA[2] do
                local item_id = CalcFxID(parrent_container, i)
                r.TrackFX_SetParam(TRACK, item_id, PARA_DATA[1][i].wetparam, 1 / p_cnt)
            end
        end
        r.ImGui_Separator(ctx)
        if r.ImGui_MenuItem(ctx, 'UNBYPASS ALL') then
            local parrent_container = GetParentContainerByGuid(PARA_DATA[1][PARA_DATA[2]])
            local _, first_idx_in_row = FindNextPrevRow(PARA_DATA[1], PARA_DATA[2], -1)
            local _, last_idx_in_row = FindNextPrevRow(PARA_DATA[1], PARA_DATA[2], 1)

            for i = first_idx_in_row, last_idx_in_row do
                local item_id = CalcFxID(parrent_container, i)
                r.TrackFX_SetEnabled(TRACK, item_id, true)
            end
        end
        if CLIPBOARD.tbl then
            if r.ImGui_MenuItem(ctx, 'PASTE') then
                Paste(false, true)
            end
        end
    else
        if CLIPBOARD.tbl then
            if r.ImGui_MenuItem(ctx, 'PASTE') then
                Paste(false, true)
            end
        else
            r.ImGui_CloseCurrentPopup(ctx)
        end
    end
end

function RCCTXMenu()
    if r.ImGui_MenuItem(ctx, 'RENAME') then
        OPEN_RENAME = true
    end
    if r.ImGui_MenuItem(ctx, 'REPLACE') then
        local parrent_container = GetParentContainerByGuid(R_CLICK_DATA[1][R_CLICK_DATA[2]])
        local item_id = CalcFxID(parrent_container, R_CLICK_DATA[2])
        FX_ID = { item_id, R_CLICK_DATA[1][R_CLICK_DATA[2]].p == 1 }
        REPLACE = item_id
        OPEN_FX_LIST = true
    end
    r.ImGui_Separator(ctx)
    if r.ImGui_MenuItem(ctx, 'DELETE') then
        local parrent_container = GetParentContainerByGuid(R_CLICK_DATA[1][R_CLICK_DATA[2]])
        local item_id = CalcFxID(parrent_container, R_CLICK_DATA[2])
        if R_CLICK_DATA[1][R_CLICK_DATA[2]] == "ROOT" then
            RemoveAllFX()
            return
        end
        CheckNextItemParallel(R_CLICK_DATA[2], parrent_container)
        r.TrackFX_Delete(TRACK, item_id)
    end
    r.ImGui_Separator(ctx)
    if r.ImGui_MenuItem(ctx, 'COPY') then
        local parrent_container = GetParentContainerByGuid(R_CLICK_DATA[1][R_CLICK_DATA[2]])
        local item_id = CalcFxID(parrent_container, R_CLICK_DATA[2])
        local data = tableToString(
            {
                tbl = R_CLICK_DATA[1],
                tbl_i = R_CLICK_DATA[2],
                track_guid = r.GetTrackGUID(TRACK),
                fx_id = item_id,
                guid = R_CLICK_DATA[1][R_CLICK_DATA[2]].guid
            }
        )
        r.SetExtState("PARANORMALFX", "COPY_BUFFER", data, false)
        r.SetExtState("PARANORMALFX", "COPY_BUFFER_ID", r.genGuid(), false)
    end

    -- SHOW ONLY WHEN CLIPBOARD IS AVAILABLE
    if CLIPBOARD.tbl then
        if r.ImGui_MenuItem(ctx, 'PASTE-REPLACE') then
            Paste(true)
        end
        if r.ImGui_MenuItem(ctx, 'MOVE-CUT') then
            Paste(nil, nil, nil, true)
        end
    end

    if R_CLICK_DATA[1][R_CLICK_DATA[2]].type == "Container" then
        if r.ImGui_MenuItem(ctx, 'SAVE AS CHAIN') then
            OPEN_FM = true
            FM_TYPE = "SAVE"
            Init_FM_database()
        end
    end


    -- r.ImGui_Separator(ctx)
    -- if r.ImGui_MenuItem(ctx, 'SHOW LAST TOUCHED PARAMETER') then
    --     local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)
    --     if retval then

    --     end
    -- end
end

local function StoreSettings()
    local data = tableToString(
        {
            esc_close = ESC_CLOSE,
            custom_font = CUSTOM_FONT,
            auto_color = AUTO_COLORING,
            spacing = s_spacing_y,
            add_btn_h = add_btn_h,
            add_bnt_w = add_bnt_w,
            wirethickness = WireThickness,
            wire_color = COLOR["wire"],
            fx_color = COLOR["n"],
            container_color = COLOR["Container"],
            parallel_color = COLOR["parallel"],
            knobvol_color = COLOR["knob_vol"],
            drywet_color = COLOR["knob_drywet"],
            bypass_color = COLOR["bypass"],

        }
    )
    r.SetExtState("PARANORMALFX", "SETTINGS", data, true)
end

local function DrawUserSettings()
    local WX, WY = r.ImGui_GetWindowPos(ctx)

    r.ImGui_SetNextWindowPos(ctx, WX + 5, WY + 70)
    -- if not r.ImGui_BeginChild(ctx, 'hackUSERSETTIGS', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)
    if r.ImGui_BeginChild(ctx, "USERSETTIGS", 182, 384, 1) then
        if r.ImGui_BeginListBox(ctx, "FONT", nil, 38) then
            if r.ImGui_Selectable(ctx, "DEFAULT", CUSTOM_FONT == nil) then
                SELECTED_FONT = DEFAULT_FONT
                CUSTOM_FONT = nil
            end
            if r.ImGui_Selectable(ctx, "SYSTEM", CUSTOM_FONT ~= nil) then
                SELECTED_FONT = SYSTEM_FONT
                CUSTOM_FONT = true
            end
            r.ImGui_EndListBox(ctx)
        end
        r.ImGui_SetNextItemWidth(ctx, 100)
        retval, s_spacing_y = r.ImGui_SliderInt(ctx, "SPACING", s_spacing_y, 0, 20)
        r.ImGui_SetNextItemWidth(ctx, 100)

        retval, add_btn_h = r.ImGui_SliderInt(ctx, "+ HEIGHT", add_btn_h, 10, 22)
        r.ImGui_SetNextItemWidth(ctx, 100)

        retval, add_bnt_w = r.ImGui_SliderInt(ctx, "+ WIDTH", add_bnt_w, 20, 100)
        r.ImGui_SetNextItemWidth(ctx, 50)
        retval, WireThickness = r.ImGui_SliderInt(ctx, "WIRE THICKNESS", WireThickness, 1, 5)
        --retval, COLOR["wire"] = r.ImGui_ColorPicker4(ctx, "WIRE COLOR", COLOR["wire"], nil, COLOR["wire"])
        rv_ac, AUTO_COLORING = r.ImGui_Checkbox(ctx, "AUTO COLORING", AUTO_COLORING)
        r.ImGui_Separator(ctx)
        RV_COL, COLOR["wire"] = r.ImGui_ColorEdit4(ctx, "WIRE COLOR", COLOR["wire"], r.ImGui_ColorEditFlags_NoInputs())
        if AUTO_COLORING then r.ImGui_BeginDisabled(ctx, true) end
        RV_COL, COLOR["n"] = r.ImGui_ColorEdit4(ctx, "FX COLOR", COLOR["n"], r.ImGui_ColorEditFlags_NoInputs())
        RV_COL, COLOR["Container"] = r.ImGui_ColorEdit4(ctx, "CONTAINER COLOR", COLOR["Container"],
            r.ImGui_ColorEditFlags_NoInputs())
        RV_COL, COLOR["bypass"] = r.ImGui_ColorEdit4(ctx, "BYPASS COLOR", COLOR["bypass"],
            r.ImGui_ColorEditFlags_NoInputs())
        if AUTO_COLORING then r.ImGui_EndDisabled(ctx) end

        RV_COL, COLOR["parallel"] = r.ImGui_ColorEdit4(ctx, "+ || COLOR", COLOR["parallel"],
            r.ImGui_ColorEditFlags_NoInputs())
        RV_COL, COLOR["knob_vol"] = r.ImGui_ColorEdit4(ctx, "KNOB VOLUME", COLOR["knob_vol"],
            r.ImGui_ColorEditFlags_NoInputs())
        RV_COL, COLOR["knob_drywet"] = r.ImGui_ColorEdit4(ctx, "KNOB DRY/WET", COLOR["knob_drywet"],
            r.ImGui_ColorEditFlags_NoInputs())
        r.ImGui_Separator(ctx)
        retval, ESC_CLOSE = r.ImGui_Checkbox(ctx, "CLOSE ON ESC", ESC_CLOSE)

        -- CH_RV, PROFILE_DEBUG = r.ImGui_Checkbox(ctx, "PROFILE SCRIPT (DEBUG)", PROFILE_DEBUG)
        -- if CH_RV then
        --     OPEN_SETTINGS = nil
        -- end

        --if r.ImGui_Button(ctx, "SAVE") then
        --    StoreSettings()
        --OPEN_SETTINGS = nil
        --end
        --r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, "DEFAULT") then
            CUSTOM_FONT = nil
            SELECTED_FONT = DEFAULT_FONT
            s_spacing_y = 7
            custom_btn_h = 22
            Knob_Radius = custom_btn_h // 2
            ROUND_CORNER = 2
            WireThickness = 1
            add_bnt_w = 55
            add_btn_h = 14
            COLOR = {
                ["n"]           = 0x315e94ff,
                ["Container"]   = 0x49cc85FF,
                ["knob_bg"]     = 0x192432ff,
                ["knob_vol"]    = 0x49cc85FF,
                ["knob_drywet"] = 0x3a87ffff,
                ["midi"]        = 0x8833AAFF,
                ["del"]         = 0xFF2222FF,
                ["ROOT"]        = 0x49cc85FF,
                ["add"]         = 0x192432ff,
                ["parallel"]    = 0x192432ff,
                ["bypass"]      = 0xdc5454ff,
                ["enabled"]     = 0x49cc85FF,
                ["wire"]        = 0xB0B0B9FF,
            }
        end
        r.ImGui_SameLine(ctx)

        if r.ImGui_Button(ctx, "DELETE SAVED") then
            r.DeleteExtState("PARANORMALFX", "SETTINGS", true)
            --r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
    -- r.ImGui_EndChild(ctx)
end

-- FOR FILE MANAGER NOT TO CRASH SINCE IT EXPECTS THIS FUNCTION
function CustomLoad(string, path)
    --AddFX(path)
end

local function FXChainMenu()
    if r.ImGui_MenuItem(ctx, "SAVE CHAIN") then
        OPEN_FM = true
        FM_TYPE = "SAVE"
        Init_FM_database()
        local _, chunk = r.GetTrackStateChunk(TRACK, "")
        local retch, s1, cl = Chunk_GetFXChainSection(chunk)

        -- TRIM INNER CHAIN TO MAKE SAME STRUCTURE AS .RfxChain
        if retch then
            -- FIND FIRST BYPASS
            local bs, be = string.find(retch, 'BYPASS ')
            -- REMOVE LAST >
            local inner_chain = string.sub(retch, bs, -2)
            local fx_chain_chunk = GetFXChainChunk(inner_chain)
            SAVED_DATA = fx_chain_chunk
        end
    end
    -- if r.ImGui_MenuItem(ctx, "LOAD CHAIN") then
    --     OPEN_FM = true
    --     FM_TYPE = "LOAD"
    --     Init_FM_database()
    -- end
end

local function Popups()
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
    if OPEN_RIGHT_C_CTX then
        OPEN_RIGHT_C_CTX = nil
        if not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX") then
            r.ImGui_OpenPopup(ctx, "RIGHT_C_CTX")
        end
    end

    if r.ImGui_BeginPopup(ctx, "RIGHT_C_CTX") then
        RCCTXMenu()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_RIGHT_C_CTX_PARALLEL then
        OPEN_RIGHT_C_CTX_PARALLEL = nil
        if not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX_PARALLEL") then
            r.ImGui_OpenPopup(ctx, "RIGHT_C_CTX_PARALLEL")
        end
    end

    if r.ImGui_BeginPopup(ctx, "RIGHT_C_CTX_PARALLEL") then
        RCCTXMenuParallel()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_RIGHT_C_CTX_INSERT then
        OPEN_RIGHT_C_CTX_INSERT = nil
        if not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX_INSERT") then
            r.ImGui_OpenPopup(ctx, "RIGHT_C_CTX_INSERT")
        end
    end

    if r.ImGui_BeginPopup(ctx, "RIGHT_C_CTX_INSERT") then
        RCCTXMenuInsert()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_FX_LIST then
        OPEN_FX_LIST = nil
        if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
            r.ImGui_OpenPopup(ctx, "FX LIST")
        end
    end

    if r.ImGui_BeginPopup(ctx, "FX LIST") then
        DrawFXList()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_RENAME then
        OPEN_RENAME = nil
        if not r.ImGui_IsPopupOpen(ctx, "RENAME") then
            r.ImGui_OpenPopup(ctx, 'RENAME')
            local mx, my = r.ImGui_GetMousePos(ctx)
            r.ImGui_SetNextWindowPos(ctx, mx - 100, my)
        end
    end

    --r.ImGui_SetNextWindowPos(ctx, mx - 100, my, r.ImGui_Cond_Once())
    if r.ImGui_BeginPopupModal(ctx, 'RENAME', nil,
            r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_TopMost()) then
        Rename()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_FM then
        OPEN_FM = nil
        if not r.ImGui_IsPopupOpen(ctx, "File Dialog") then
            r.ImGui_OpenPopup(ctx, 'File Dialog')
        end
    end
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 400, 300, 400, 300)
    if r.ImGui_BeginPopupModal(ctx, 'File Dialog', true, r.ImGui_WindowFlags_TopMost() |  r.ImGui_WindowFlags_NoResize()) then
        File_dialog()
        FM_Modal_POPUP()
        r.ImGui_EndPopup(ctx)
    end

    if OPEN_RIGHT_C_CTX_FX_CHAIN then
        OPEN_RIGHT_C_CTX_FX_CHAIN = nil
        r.ImGui_OpenPopup(ctx, 'FX_CHAIN')
    end

    if r.ImGui_BeginPopup(ctx, "FX_CHAIN") then
        FXChainMenu()
        r.ImGui_EndPopup(ctx)
    end

    if not r.ImGui_IsPopupOpen(ctx, "FX LIST") and #FILTER ~= 0 then FILTER = '' end
    if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
        if FX_ID then FX_ID = nil end
        if CLICKED then CLICKED = nil end
        -- if REPLACE then REPLACE = nil end
    end
    if not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX_PARALLEL") then
        if PARA_DATA then PARA_DATA = nil end
    end
    if not r.ImGui_IsPopupOpen(ctx, "FX LIST") and not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX") and not r.ImGui_IsPopupOpen(ctx, "RENAME") and not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX_PARALLEL") and not r.ImGui_IsPopupOpen(ctx, "RIGHT_C_CTX_INSERT") then
        if R_CLICK_DATA then R_CLICK_DATA = nil end
        if REPLACE then REPLACE = nil end
    end
end

local function CheckKeys()
    ALT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Alt()
    CTRL = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut()
    SHIFT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shift()
    HOME = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Home())
    SPACE = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Space())
    Z = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Z())
    P = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_P())
    ESC = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape())

    if HOME then CANVAS.off_x, CANVAS.off_y = 0, 50 end

    if CTRL and Z then r.Main_OnCommand(40029, 0) end -- UNDO
    if r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut() | r.ImGui_Mod_Shift() and Z then
        r.Main_OnCommand(40030, 0)                    -- REDO
    end
    --r.show
    if SPACE and (not FX_OPENED and not RENAME_OPENED) then r.Main_OnCommand(40044, 0) end -- PLAY STOP

    -- ACTIVATE CTRL ONLY IF NOT PREVIOUSLY DRAGGING
    if not CTRL_DRAG then
        CTRL_DRAG = (not MOUSE_DRAG and CTRL) and r.ImGui_IsMouseDragging(ctx, 0)
    end
    MOUSE_DRAG = r.ImGui_IsMouseDragging(ctx, 0)
end

local function UI()
    r.ImGui_SetCursorPos(ctx, 5, 25)
    -- NIFTY HACK FOR COMMENT BOX NOT OVERLAP UI BUTTONS
    if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)

    --r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 2)
    if r.ImGui_BeginChild(ctx, "TopButtons", 280, def_btn_h + (s_window_y * 2), 1) then
        local retval, tr_ID = r.GetTrackName(TRACK)
        r.ImGui_PushFont(ctx, ICONS_FONT2)
        if r.ImGui_InvisibleButton(ctx, "D", CalculateItemWH({ name = "D" }), def_btn_h) then
            if OPEN_SETTINGS then
                StoreSettings()
            end
            OPEN_SETTINGS = not OPEN_SETTINGS
        end
        DrawListButton("D", 0xff, nil, nil, r.ImGui_IsItemHovered(ctx))
        r.ImGui_SameLine(ctx)
        if r.ImGui_InvisibleButton(ctx, "L", CalculateItemWH({ name = "D" }), def_btn_h) then
            CANVAS.off_x, CANVAS.off_y = 0, 50
        end
        DrawListButton("L", 0xff, nil, nil, r.ImGui_IsItemHovered(ctx))
        r.ImGui_PopFont(ctx)
        Tooltip("RESET VIEW")
        r.ImGui_SameLine(ctx)
        local pin_color = SYNC and 0x49cc85FF or 0xff --0x1b3d65ff
        if r.ImGui_InvisibleButton(ctx, "PIN", CalculateItemWH({ name = "PIN" }), def_btn_h) then
            --if r.ImGui_Checkbox(ctx, "PIN", SYNC) then
            SEL_LIST_TRACK = TRACK
            SYNC = not SYNC
        end
        DrawListButton("PIN", pin_color, nil, nil, r.ImGui_IsItemHovered(ctx))
        Tooltip(
            "LOCKS TO SELECTED TRACK\nMULTIPLE SCRIPTS CAN HAVE DIFFERENT SELECTIONS\nCAN BE CHANGED VIA TRACKLIST")

        r.ImGui_SameLine(ctx)
        if r.ImGui_InvisibleButton(ctx, "M", CalculateItemWH({ name = "PIN" }), def_btn_h) then
            if SYNC then
                r.SetTrackUIMute(SEL_LIST_TRACK, -1, 0)
            else
                r.SetTrackUIMute(TRACK, -1, 0)
            end
        end
        local mute_color = r.GetMediaTrackInfo_Value(SYNC and SEL_LIST_TRACK or TRACK, "B_MUTE")
        DrawListButton("M", mute_color == 0 and 0xff or 0xff2222ff, nil, nil, r.ImGui_IsItemHovered(ctx))

        r.ImGui_SameLine(ctx, 0, 0)

        if r.ImGui_InvisibleButton(ctx, "S", CalculateItemWH({ name = "PIN" }), def_btn_h) then
            if SYNC then
                r.SetTrackUISolo(SEL_LIST_TRACK, -1, 0)
            else
                r.SetTrackUISolo(TRACK, -1, 0)
            end
        end
        local solo_color = r.GetMediaTrackInfo_Value(SYNC and SEL_LIST_TRACK or TRACK, "I_SOLO")
        DrawListButton("S", solo_color == 0 and 0xff or 0xf1c524ff, nil, nil, r.ImGui_IsItemHovered(ctx))
        r.ImGui_SameLine(ctx)

        --Tooltip("RESET VIEW")
        r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + s_window_y // 2)
        if r.ImGui_BeginMenu(ctx, tr_ID .. "##main") then
            for i = 0, r.CountTracks(0) do
                local track = i == 0 and r.GetMasterTrack(0) or r.GetTrack(0, i - 1)
                local _, track_id = r.GetTrackName(track)
                if r.ImGui_Selectable(ctx, track_id) then
                    if SYNC then
                        SEL_LIST_TRACK = track
                    else
                        r.SetOnlyTrackSelected(track)
                    end
                end
            end
            r.ImGui_EndMenu(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_EndChild(ctx)
end

local function Frame()
    Popups()
    UpdateFxData()
    GetOrUpdateFX()
    local center
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), s_spacing_x, s_spacing_y)
    if r.ImGui_BeginChild(ctx, "##MAIN", nil, nil, nil, WND_FLAGS) then --(ctx, "##MAIN", nil, nil, nil,  r.ImGui_WindowFlags_AlwaysHorizontalScrollbar())
        center = (r.ImGui_GetContentRegionMax(ctx) + s_window_x) // 2
        r.ImGui_SetCursorPosY(ctx, CANVAS.off_y)
        center = center + CANVAS.off_x
        local bypass = PLUGINS[0].bypass and 1 or 0.5
        DrawPlugins(center, PLUGINS, bypass)

        if DRAW_PREVIEW then
            local mx, my = r.ImGui_GetMousePos(ctx)
            r.ImGui_SetNextWindowPos(ctx, mx + 10, my + 15)
            -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0xBB)
            if DRAG_MOVE.type == "Container" then
                if r.ImGui_BeginChild(ctx, "##PREVIEW_DRAW_CONTAINER", DRAG_MOVE.W, DRAG_MOVE.H, true) then
                    DrawButton(dummy_preview, 1, DRAG_MOVE.name, DRAG_MOVE.W - volume - mute, 1)

                    local area_w = r.ImGui_GetContentRegionMax(ctx)
                    DrawPlugins(area_w // 2, DRAG_MOVE.sub, 1)
                    r.ImGui_EndChild(ctx)
                end
            else
                local width = CalculateItemWH({ name = DRAG_MOVE.name })
                if r.ImGui_BeginChild(ctx, "##PREVIEW_DRAW_FX", width + mute + (s_window_x * 2), def_btn_h + (s_window_y * 2), true) then
                    DrawButton(dummy_preview, 1, Stripname(DRAG_MOVE.name, true), width, 1)
                    r.ImGui_EndChild(ctx)
                end
            end
            -- r.ImGui_PopStyleColor(ctx)
        end

        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    DrawLines()
end

function Iterate_container(depth, track, container_id, parent_fx_count, previous_diff, container_guid)
    local _, c_fx_count = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + container_id, "container_count")
    local diff = depth == 0 and parent_fx_count + 1 or (parent_fx_count + 1) * previous_diff
    local child_guids = {}

    FX_DATA["insertpoint_0" .. container_guid] = {
        IDX = 1,
        name = "DUMMY",
        type = "INSERT_POINT",
        guid = "insertpoint_0" .. container_guid,
        pid = container_guid,
        ROW = 0,
    }

    local row = 1
    for i = 1, c_fx_count do
        local fx_id = container_id + diff * i
        local fx_guid = TrackFX_GetFXGUID(TRACK, 0x2000000 + fx_id)
        local _, fx_type = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "fx_type")
        local _, para = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "parallel")

        if i > 1 then row = para == "0" and row + 1 or row end

        FX_DATA[fx_guid] = {
            type = fx_type,
            IDX = i,
            pid = container_guid,
            guid = fx_guid,
            ROW = row
        }
        child_guids[#child_guids + 1] = { guid = fx_guid }
        if fx_type == "Container" then
            FX_DATA[fx_guid].depth = depth + 1
            FX_DATA[fx_guid].DIFF = diff * (c_fx_count + 1)
            Iterate_container(depth + 1, track, fx_id, c_fx_count, diff, fx_guid)
            FX_DATA[fx_guid].ID = fx_id
        end
    end
    return child_guids
end

function UpdateFxData()
    if not TRACK then return end
    FX_DATA = {}
    FX_DATA = {
        ["ROOT"] = {
            type = "ROOT",
            pid = "ROOT",
            guid = "ROOT",
            ROW = 0,
        }
    }
    local row = 1
    local total_fx_count = r.TrackFX_GetCount(TRACK)
    for i = 1, total_fx_count do
        local _, fx_type = r.TrackFX_GetNamedConfigParm(TRACK, i - 1, "fx_type")
        local _, para = r.TrackFX_GetNamedConfigParm(TRACK, i - 1, "parallel")
        local fx_guid = TrackFX_GetFXGUID(TRACK, i - 1)

        if i > 1 then row = para == "0" and row + 1 or row end

        FX_DATA[fx_guid] = {
            type = fx_type,
            IDX = i,
            pid = "ROOT",
            guid = fx_guid,
            ROW = row,
        }
        if fx_type == "Container" then
            FX_DATA[fx_guid].depth = 0
            FX_DATA[fx_guid].DIFF = (total_fx_count + 1)
            FX_DATA[fx_guid].ID = i
            Iterate_container(0, TRACK, i, total_fx_count, 0, fx_guid)
        end
    end
end

function UpdateClipboardInfo()
    -- DONT RECALCULATE IF PASTING ON DIFFERENT TRACK
    if CLIPBOARD.track ~= TRACK then return end
    UpdateFxData()
    local updated = GetFx(CLIPBOARD.tbl[CLIPBOARD.i].guid)
    local parrent = GetFx(updated.pid)

    local item_id = CalcFxID(parrent, updated.IDX)
    CLIPBOARD.id = item_id
end

local old_copy_id
local function ClipBoard()
    local x, y = r.ImGui_GetContentRegionMax(ctx)
    r.ImGui_SetCursorPos(ctx, 5, y - 30)
    -- NIFTY HACK FOR COMMENT BOX NOT OVERLAP UI BUTTONS
    if not r.ImGui_BeginChild(ctx, 'hack44', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)

    --r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 2)
    if r.HasExtState("PARANORMALFX", "COPY_BUFFER") then
        local copy_id = r.GetExtState("PARANORMALFX", "COPY_BUFFER_ID")
        if old_copy_id ~= copy_id then
            local stored = r.GetExtState("PARANORMALFX", "COPY_BUFFER")
            if stored ~= nil then
                local storedTable = stringToTable(stored)
                if storedTable ~= nil then
                    CLIPBOARD = {
                        tbl = storedTable.tbl,
                        i = storedTable.tbl_i,
                        id = storedTable.fx_id,
                        guid = storedTable.guid
                    }
                    for i = 1, r.CountTracks(0) do
                        local track = r.GetTrack(0, i - 1)
                        if storedTable.track_guid == r.GetTrackGUID(track) then
                            CLIPBOARD.track = track
                            break
                        end
                    end
                end
                old_copy_id = copy_id
            end
        end
    end

    -- if size > 0 then
    if CLIPBOARD.tbl then
        local size = CalculateItemWH({ name = CLIPBOARD.tbl[CLIPBOARD.i].name }) + 190
        if r.ImGui_BeginChild(ctx, "CLIPBOARD", size, def_btn_h + s_window_y, 1) then
            if r.HasExtState("PARANORMALFX", "COPY_BUFFER") then
                if CLIPBOARD.tbl then
                    local rv, name = r.GetTrackName(CLIPBOARD.track)
                    r.ImGui_Text(ctx, "CLIPBOARD: " .. name .. " - FX: " .. CLIPBOARD.tbl[CLIPBOARD.i].name)
                end
            else
                r.ImGui_Text(ctx, "CLIPBOARD EMPTY ")
            end
            r.ImGui_EndChild(ctx)
        end
    end
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_EndChild(ctx)
end

local function Tutorial()
    local avail_w = r.ImGui_GetContentRegionAvail(ctx)
    r.ImGui_SameLine(ctx, avail_w - 120)

    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 5, 5)
    if r.ImGui_BeginChild(ctx, 'right_side_tutorial', -5, TUTORIAL_VISIBLE and 296 or 23, true, r.ImGui_WindowFlags_NoScrollbar()) then
        TUTORIAL_VISIBLE = r.ImGui_TreeNode(ctx, 'TUTORIALS', r.ImGui_TreeNodeFlags_NoTreePushOnOpen())
        if TUTORIAL_VISIBLE and r.ImGui_BeginChild(ctx, 'tutorial_view') then
            for i = 1, #TUTORIALS do
                r.ImGui_Selectable(ctx, TUTORIALS[i].name .. "##12345")
                if r.ImGui_IsItemHovered(ctx) then
                    if prev_tut ~= i then
                        IMG_OBJ = nil
                        prev_tut = i
                    end
                    Tooltip_Tutorial(TUTORIALS[i])
                end
            end
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleColor(ctx)
    --r.ImGui_PopStyleColor(ctx)
    --r.ImGui_EndChild(ctx)
end

--LAST_TRACK = r.GetSelectedTrack(0, 0)
local function Main()
    if WANT_REFRESH then
        WANT_REFRESH = nil
        FX_LIST, CAT = GetFXTbl()
    end
    -- if PROFILE_DEBUG then
    --     PROFILE_STARTED = true
    --     profiler2.start()
    -- end
    LINE_POINTS = {}
    PLUGINS = {}
    TRACK = r.GetSelectedTrack(0, 0)
    local master = r.GetMasterTrack(0)
    if r.GetMediaTrackInfo_Value(master, "I_SELECTED") == 1 then TRACK = master end

    TRACK = SYNC and SEL_LIST_TRACK or TRACK

    if LAST_TRACK ~= TRACK then
        Store_To_PEXT(LAST_TRACK)
        LAST_TRACK = TRACK
        if not Restore_From_PEXT() then
            CANVAS = InitCanvas()
        end
    end

    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), 0x111111FF)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 500, 500, FLT_MAX, FLT_MAX)
    r.ImGui_SetNextWindowSize(ctx, 500, 500, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, 'PARANORMAL FX ROUTER', true, WND_FLAGS)
    r.ImGui_PopStyleColor(ctx)

    if visible then
        r.ImGui_PushFont(ctx, SELECTED_FONT)
        CheckKeys()
        --UpdateFxData()
        if TRACK then
            Frame()
            UI()
            Tutorial()
            ClipBoard()
        end
        if OPEN_SETTINGS then
            DrawUserSettings()
        end
        if not IS_DRAGGING_RIGHT_CANVAS and r.ImGui_IsMouseReleased(ctx, 1) and not r.ImGui_IsAnyItemHovered(ctx) then
            r.ImGui_OpenPopup(ctx, 'FX LIST')
        end
        IS_DRAGGING_RIGHT_CANVAS = r.ImGui_IsMouseDragging(ctx, 1, 2)
        FX_OPENED = r.ImGui_IsPopupOpen(ctx, "FX LIST")
        RENAME_OPENED = r.ImGui_IsPopupOpen(ctx, "RENAME")
        --if CUSTOM_FONT and not FONT_UPDATE then
        r.ImGui_PopFont(ctx)
        --end
        r.ImGui_End(ctx)
    end
    UpdateScroll()
    if ESC and ESC_CLOSE then open = nil end
    if open then
        pdefer(Main)
    end

    if r.ImGui_IsMouseReleased(ctx, 0) then
        CTRL_DRAG = nil
        DRAG_MOVE = nil
        DRAG_ADD_FX = nil
        DRAW_PREVIEW = nil
    end
    -- if PROFILE_DEBUG and PROFILE_STARTED then
    --     profiler2.stop()
    --     profiler2.report(PATH .. "profiler.log")
    --     PROFILE_DEBUG, PROFILE_STARTED = false, nil
    --     OpenFile(PATH .. "profiler.log")
    -- end
    if FONT_UPDATE then FONT_UPDATE = nil end
end

function Exit()
    if CLIPBOARD.tbl and CLIPBOARD.track == TRACK then
        r.DeleteExtState("PARANORMALFX", "COPY_BUFFER", false)
        r.DeleteExtState("PARANORMALFX", "COPY_BUFFER_ID", false)
    end
    Store_To_PEXT(LAST_TRACK)
end

r.atexit(Exit)
pdefer(Main)
