-- @description Reaper VSCode Definitions Generator
-- @author Sexan, Cfillion, Docs source X-Raym - https://www.extremraym.com/cloud/reascript-doc/
-- @license GPL v3
-- @version 1.11
-- @changelog
--  Replace <br> html tag with markdown two trailing whitespace for better compability with other IDES

--local r = reaper
--local script_path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
--print(debug.getinfo(1, "S").source)
local API_PATH = "api_file.txt"

local lua_func_str = [[
---is_new_value,filename,sectionID,cmdID,mode,resolution,val,contextstr = reaper.get_action_context()
---Returns contextual information about the script, typically MIDI/OSC input values.
---val will be set to a relative or absolute value depending on mode (=0: absolute mode, >0: relative modes).
---resolution=127 for 7-bit resolution, =16383 for 14-bit resolution.
---sectionID, and cmdID will be set to -1 if the script is not part of the action list.
---mode, resolution and val will be set to -1 if the script was not triggered via MIDI/OSC.
---contextstr may be empty or one of:
---
---* midi:XX[:YY] (one or two bytes hex)
---* [wheel|hwheel|mtvert|mthorz|mtzoom|mtrot|mediakbd]:flags
---* key:flags:keycode
---* osc:/msg[:f=FloatValue|:s=StringValue]
---* KBD_OnMainActionEx
---
---(flags may include V=virtkey, S=shift, A=alt/option, C=control/command, W=win/control)
---@return boolean is_new_value
---@return string filename
---@return integer sectionID
---@return integer cmdID
---@return integer mode
---@return integer resolution
---@return number val
---@return string contextstr
function reaper.get_action_context() end

---Adds code to be called back by REAPER. Used to create persistent ReaScripts that continue to run and respond to input, while the user does other tasks. Identical to runloop().
---Note that no undo point will be automatically created when the script finishes, unless you create it explicitly.
---@param function function
---@return boolean retval
function reaper.defer(function) end

---Adds code to be called back by REAPER. Used to create persistent ReaScripts that continue to run and respond to input, while the user does other tasks. Identical to defer().
---Note that no undo point will be automatically created when the script finishes, unless you create it explicitly.
---@param function function
---@return boolean retval
function reaper.runloop(function) end

---Adds code to be executed when the script finishes or is ended by the user. Typically used to clean up after the user terminates defer() or runloop() code.
---@param function function
---@return boolean retval
function reaper.atexit(function) end

---Sets action options for the script.
---* flag&1: script will auto-terminate if re-launched while already running
---* flag&2: if (flag&1) is set, script will re-launch after auto-terminating
---* flag&4: set script toggle state on
---* flag&8: set script toggle state off
---@param flag integer
function reaper.set_action_options(flag) end

---Causes gmem_read()/gmem_write() to read EEL2/JSFX/Video shared memory segment named by parameter. Set to empty string to detach. 6.20+: returns previous shared memory segment name.Must be called, before you can use a specific gmem-variable-index with gmem_write!
---@param sharedMemoryName string
---@return string former_attached_gmemname
function reaper.gmem_attach(sharedMemoryName) end

---Read (number) value from shared memory attached-to by gmem_attach(). index can be [0..1<<25).returns nil if not available
---@param index integer
---@return number retval
function reaper.gmem_read(index) end

---Write (number) value to shared memory attached-to by gmem_attach(). index can be [0..1<<25).Before you can write into a currently unused variable with index "index", you must call gmem_attach first!
---@param index integer
---@param value number
function reaper.gmem_write(index, value) end

---Returns the path to the directory containing imgui.lua, imgui.py and gfx2imgui.lua.
---@return string path
function reaper.ImGui_GetBuiltinPath() end

---[BR] Get mouse cursor context. Each parameter returns information in a form of string as specified in the table below.
---
---+------------+----------------+------------------------------------------------+  
---| Window     | Segment        | Details                                        |  
---+------------+----------------+------------------------------------------------+  
---| unknown    | ""             | ""                                             |  
---+------------+----------------+------------------------------------------------+  
---| ruler      | region_lane    | ""                                             |  
---|            | marker_lane    | ""                                             |  
---|            | tempo_lane     | ""                                             |  
---|            | timeline       | ""                                             |  
---+------------+----------------+------------------------------------------------+  
---| transport  | ""             | ""                                             |  
---+------------+----------------+------------------------------------------------+  
---| tcp        | track          | ""                                             |  
---|            | envelope       | ""                                             |  
---|            | empty          | ""                                             |  
---+------------+----------------+------------------------------------------------+  
---| mcp        | track          | ""                                             |  
---|            | empty          | ""                                             |  
---+------------+----------------+------------------------------------------------+  
---| arrange    | track          | empty, item, item_stretch_marker,              |  
---|            |                | env_point, env_segment                         |  
---|            | envelope       | empty, env_point, env_segment                  |  
---|            | empty          | ""                                             |  
---+------------+----------------+------------------------------------------------+  
---| midi_editor| unknown        | ""                                             |  
---|            | ruler          | ""                                             |  
---|            | piano          | ""                                             |  
---|            | notes          | ""                                             |  
---|            | cc_lane        | cc_selector, cc_lane                           |  
---+------------+----------------+------------------------------------------------+  
---To get more info on stuff that was found under mouse cursor see BR_GetMouseCursorContext_Envelope, BR_GetMouseCursorContext_Item, BR_GetMouseCursorContext_MIDI, BR_GetMouseCursorContext_Position, BR_GetMouseCursorContext_Take, BR_GetMouseCursorContext_Track
---@return string window
---@return string segment
---@return string details
function reaper.BR_GetMouseCursorContext() end
]]

local gfx_start_str = [[
---@class gfx
---@field r number current red component (0..1) used by drawing operations.
---@field g number current green component (0..1) used by drawing operations.
---@field b number current blue component (0..1) used by drawing operations.
---@field a2 number  current alpha component (0..1) used by drawing operations when writing solid colors (normally ignored but useful when creating transparent images).
---@field a number alpha for drawing (1=normal).
---@field mode number blend mode for drawing. Set mode to 0 for default options. Add 1.0 for additive blend mode (if you wish to do subtractive, set gfx.a to negative and use gfx.mode as additive). Add 2.0 to disable source alpha for gfx.blit(). Add 4.0 to disable filtering for gfx.blit().
---@field w number width of the UI framebuffer.
---@field h number height of the UI framebuffer.
---@field x number current graphics position X. Some drawing functions use as start position and update.
---@field y number current graphics position Y. Some drawing functions use as start position and update.
---@field clear number if greater than -1.0, framebuffer will be cleared to that color. the color for this one is packed RGB (0..255), i.e. red+green*256+blue*65536. The default is 0 (black).
---@field dest number destination for drawing operations, -1 is main framebuffer, set to 0..1024-1 to have drawing operations go to an offscreen buffer (or loaded image).
---@field texth number the (READ-ONLY) height of a line of text in the current font. Do not modify this variable.
---@field ext_retina number to support hidpi/retina, callers should set to 1.0 on initialization, this value will be updated to value greater than 1.0 (such as 2.0) if retina/hidpi. On macOS gfx.w/gfx.h/etc will be doubled, but on other systems gfx.w/gfx.h will remain the same and gfx.ext_retina is a scaling hint for drawing.
---@field mouse_x number current X coordinate of the mouse relative to the graphics window.
---@field mouse_y number current Y coordinate of the mouse relative to the graphics window.
---@field mouse_wheel number wheel position, will change typically by 120 or a multiple thereof, the caller should clear the state to 0 after reading it.
---@field mouse_hwheel number horizontal wheel positions, will change typically by 120 or a multiple thereof, the caller should clear the state to 0 after reading it.
---@field mouse_cap number a bitfield of mouse and keyboard modifier state:
gfx = {}
]]

local gfx_ret = {
    arc            = { { type = "number", name = "retval" } },
    blit           = { { type = "number", name = "source" } },
    blitext        = { { type = "number", name = "retval" } },
    blurto         = { { type = "number", name = "retval" } },
    circle         = { { type = "number", name = "retval" } },
    clienttoscreen = {
        { type = "number", name = "convx" },
        { type = "number", name = "convy" },
    },
    deltablit      = { { type = "number", name = "retval" } },
    dock           = {
        { type = "number",     name = "querystate" },
        { type = "number|nil", name = "window_x_position" },
        { type = "number|nil", name = "window_y_position" },
        { type = "number|nil", name = "window_width" },
        { type = "number|nil", name = "window_height" },
    },
    drawchar       = { { type = "number", name = "char" } },
    drawnumber     = { { type = "number", name = "retval" } },
    drawstr        = { { type = "number", name = "retval" } },
    getchar        = {
        { type = "number", name = "char" },
        { type = "number", name = "unichar" }
    },
    getdropfile    = {
        { type = "number",     name = "retval" },
        { type = "string|nil", name = "filename" },
    },
    getfont        = {
        { type = "number", name = "fontindex" },
        { type = "string", name = "fontface" },
    },
    getimgdim      = {
        { type = "number", name = "w" },
        { type = "number", name = "h" },
    },
    getpixel       = {
        { type = "number", name = "r" },
        { type = "number", name = "g" },
        { type = "number", name = "b" },
    },
    gradrect       = { { type = "number", name = "retval" }, },
    init           = { { type = "number", name = "retval" }, },
    line           = { { type = "number", name = "retval" }, },
    lineto         = { { type = "number", name = "retval" }, },
    loadimg        = { { type = "number", name = "retval" }, },
    measurechar    = {
        { type = "number", name = "width" },
        { type = "number", name = "height" },
    },
    measurestr     = {
        { type = "number", name = "width" },
        { type = "number", name = "height" },
    },
    muladdrect     = { { type = "number", name = "retval" }, },
    printf         = { { type = "number", name = "retval" }, },
    quit           = { { type = "number", name = "retval" }, },
    rect           = { { type = "number", name = "retval" }, },
    rectto         = { { type = "number", name = "x_coordinate" }, },
    roundrect      = { { type = "number", name = "retval" }, },
    screentoclient = {
        { type = "number", name = "convx" },
        { type = "number", name = "convy" },
    },
    set            = { { type = "number", name = "retval" }, },
    setcursor      = { { type = "number", name = "retval" }, },
    setfont        = { { type = "number", name = "retval" }, },
    setimgdim      = { { type = "number", name = "retval" }, },
    setpixel       = { { type = "number", name = "retval" }, },
    showmenu       = { { type = "number", name = "selection" }, },
    transformblit  = { { type = "number", name = "retval" }, },
    triangle       = { { type = "number", name = "retval" }, },
    update         = { { type = "number", name = "retval" }, },
}

local array_start_str = [[
--- @class reaper.array : { [integer]: number }
local reaper_array = {}

---Creates a new reaper.array object of maximum and initial size size, if specified, or from the size/values of a table/array. Both size and table/array can be specified, the size parameter will override the table/array size.
--- @overload fun(table: reaper.array): reaper.array
--- @overload fun(table: reaper.array, size: integer): reaper.array
--- @overload fun(size: integer, table: reaper.array): reaper.array
--- @param size integer
--- @return reaper.array
function reaper.new_array(size) end

---Sets the value of zero or more items in the array. If value not specified, 0.0 is used. offset is 1-based, if size omitted then the maximum amount available will be set.
---@param value? number
---@param offset? integer
---@param size? integer
---@return boolean retval
function reaper_array.clear(value, offset, size) end

---Convolves complex value pairs from reaper.array, starting at 1-based srcoffs, reading/writing to 1-based destoffs. size is in normal items (so it must be even)
---@param src? reaper.array
---@param srcoffs? integer
---@param size? integer
---@param destoffs? integer
---@return integer retval
function reaper_array.convolve(src, srcoffs, size, destoffs) end

---Copies values from reaper.array or table, starting at 1-based srcoffs, writing to 1-based destoffs.
---@param src? reaper.array
---@param srcoffs? integer
---@param size? integer
---@param destoffs? integer
---@return integer retval
function reaper_array.copy(src, srcoffs, size, destoffs) end

---Performs a forward FFT of size. size must be a power of two between 4 and 32768 inclusive. If permute is specified and true, the values will be shuffled following the FFT to be in normal order.
---@param size integer
---@param permute? boolean
---@param offset? integer
---@return boolean retval
function reaper_array.fft(size, permute, offset) end

---Performs a forward real->complex FFT of size. size must be a power of two between 4 and 32768 inclusive. If permute is specified and true, the values will be shuffled following the FFT to be in normal order.
---@param size integer
---@param permute? boolean
---@param offset? integer
---@return boolean retval
function reaper_array.fft_real(size, permute, offset) end

---Returns the maximum (allocated) size of the array.
---@return integer size
function reaper_array.get_alloc() end

---Performs a backwards FFT of size. size must be a power of two between 4 and 32768 inclusive. If permute is specified and true, the values will be shuffled before the IFFT to be in fft-order.
---@param size integer
---@param permute? boolean
---@param offset? integer
---@return boolean retval
function reaper_array.ifft(size, permute, offset) end

---Performs a backwards complex->real FFT of size. size must be a power of two between 4 and 32768 inclusive. If permute is specified and true, the values will be shuffled before the IFFT to be in fft-order.
---@param size integer
---@param permute? boolean
---@param offset? integer
---@return boolean retval
function reaper_array.ifft_real(size, permute, offset) end

---Multiplies values from reaper.array, starting at 1-based srcoffs, reading/writing to 1-based destoffs.
---@param src? reaper.array
---@param srcoffs? integer
---@param size? integer
---@param destoffs? integer
---@return integer retvals
function reaper_array.multiply(src, srcoffs, size, destoffs) end

---Resizes an array object to size. size must be [0..max_size].
---@param size integer
---@return boolean retval
function reaper_array.resize(size) end

---Returns a new table with values from items in the array. Offset is 1-based and if size is omitted all available values are used.
---@param offset? integer
---@param size? integer
---@return table new_table
function reaper_array.table(offset, size) end
]]

local ignore_class = {
    ["boolean"] = true,
    ["integer"] = true,
    ["number"] = true,
    ["table"] = true,
    ["string"] = true,
    ["userdata"] = true,
    ["reaper.array"] = true,
    ["identifier"] = true,
    ["flag"] = true,
    ["function"] = true,
    ["optional "] = true,
    ["integer|number"] = true,
    ["string|nil"] = true,
    ["number|nil"] = true,
    ["any"] = true,
}

local api_blacklist = {
    ["reaper.get_action_context"] = true,
    ["reaper.defer"] = true,
    ["reaper.runloop"] = true,
    ["reaper.atexit"] = true,
    ["reaper.set_action_options"] = true,
    ["reaper.gmem_attach"] = true,
    ["reaper.gmem_read"] = true,
    ["reaper.gmem_write"] = true,
    ["reaper.BR_GetMouseCursorContext"] = true
}

local function SaveToFile(data, fn)
    local file
    file = io.open(fn, "w")
    if file then
        file:write(data)
        file:close()
    end
end

local function ReadApiFile(load_path)
    local file = io.open(load_path, "r")
    if file then
        local string = file:read("*all")
        file:close()
        return string
    end
end

-- DOWNLOAD RAW HTML FROM XRAYMS SITE
local function CurlToFile()
    local curl_cmd
    if package.config:sub(1, 1) == '\\' then
        -- if r.GetOS():sub(1, 3) == 'Win' then
        curl_cmd = 'curl'
    else
        curl_cmd = '/usr/bin/curl'
    end
    os.execute(([[%s -so "%s" https://www.extremraym.com/cloud/reascript-doc/ --ssl-no-revoke]]):format(curl_cmd,
        API_PATH))
    -- r.ExecProcess(
    --     ([[%s -so "%s" https://www.extremraym.com/cloud/reascript-doc/ --ssl-no-revoke]]):format(curl_cmd, API_PATH), 0)
end

local function trim(s)
    if not s then return end
    return s:match '^%s*(.*%S)' or ''
end

CurlToFile()

local function ParseReturns(tbl, ret_str, name)
    if name == "reaper.my_getViewport" then
        tbl[#tbl + 1] = { type = "integer", name = "left" }
        tbl[#tbl + 1] = { type = "integer", name = "top" }
        tbl[#tbl + 1] = { type = "integer", name = "right" }
        tbl[#tbl + 1] = { type = "integer", name = "bottom" }
    end
    if not ret_str then return end
    if ret_str then
        -- MULTIPLE RETURNS
        if ret_str:find(",") then
            for ret in ret_str:gmatch('[^,]+') do
                -- WORKAROUND FOR GetItemFromPoint DOC RETURN ERROR
                if name == "reaper.GetItemFromPoint" then
                    if ret == "<em>MediaItem</em>" then
                        ret = ret .. " retval"
                    end
                end
                for ret_type, ret_name in ret:gmatch('<em>(.+)</em>(.+ ?)') do
                    local opt
                    ret_type = ret_type:match("identifier") and "userdata" or trim(ret_type)
                    ret_name = trim(ret_name:gsub("=", ""))

                    -- REMOVE OPTIONAL AND PREPARE FOR APPEND ?
                    if ret_type:find("optional") then
                        ret_type = ret_type:gsub("optional ", "")
                        opt = "?"
                    end

                    tbl[#tbl + 1] = {
                        -- SOME ERROR IN DOCS SO THIS COMES IN ON FEW FUNCTIONS
                        type = ret_type:gsub("</em><em>", ""),
                        name = ret_name,
                        opt = opt,
                    }
                end
            end
        else
            -- SINGLE RETURNS
            for ret_type, ret_name in ret_str:gmatch('<em>([^<]-)</em>(.* ?)') do
                local opt = nil
                ret_name = ret_name:gsub('%s+', '')
                ret_name = ret_name:gsub('=', '')
                ret_name = #ret_name > 0 and ret_name or nil
                if name == "reaper.SplitMediaItem" then
                    opt = "?"
                end
                if name == "reaper.CF_GetFocusedFXChain" then
                    ret_name = nil
                end
                tbl[#tbl + 1] = {
                    type = ret_type:match("identifier") and "userdata" or trim(ret_type),
                    name = ret_name and ret_name or "retval",
                    opt = opt
                }
            end
        end
    end
end

local function ParseArguments(tbl, arg_str, c_str, name)
    if not arg_str then return end
    -- genGuid DOES NOT TAKE ANY PARAMETERS
    if name == "reaper.genGuid" then return end
    for arg in arg_str:gmatch('[^,]+') do
        for arg_type, arg_name in arg:gmatch('<em>(.+)</em>(.+ ?)') do
            local opt
            arg_name = trim(arg_name)
            arg_type = arg_type:match("identifier") and "userdata" or trim(arg_type)
            -- CONVERT TO ANOTATIONS OPTIONAL `type?`
            if arg_type:find("optional") then
                arg_type = arg_type:gsub("optional ", "")
                opt = "?"
            elseif arg_name and c_str:find(arg_name .. "Optional") then
                --r.ShowConsoleMsg("C OPT FOUND - " .. name .. "  :  " .. arg_name.."\n")
                opt = "?"
            end

            -- WORKAROUND FOR GetSet_ArrangeView2 MISSING OPTIONALS TAGS
            if name == "reaper.GetSet_ArrangeView2" then
                if arg_name == "start_time" or arg_name == "end_time" then
                    opt = "?"
                end
                --  WORKAROUND FOR DOCS NOT REPORTING BOTH PARAMETERS OPTIONAL
            elseif name == "reaper.ShowActionList" then
                opt = "?"
            elseif name == "reaper.ShowPopupMenu" then
                if arg_name == "y" then
                    opt = "?"
                end
            end
            tbl[#tbl + 1] = {
                type = arg_type:gsub("</em><em>", ""),
                name = arg_name:gsub("%.", "_"):gsub("%)", ""),
                opt = opt,
            }
        end
    end
end

local function ParseGfxArguments(arg_tbl, ret_tbl, arg_str, name)
    if arg_str then
        -- GET OPTIONAL PART "[...]"
        local opt_str = arg_str:match('%[(.-)]')
        -- GET REQUIRED PART "...["
        local req_str = trim(arg_str:match('[^%[]*'))
        req_str = (req_str and #req_str ~= 0) and req_str or nil
        if req_str then
            req_str = req_str:gsub(",", " ")
            for arg_name in req_str:gmatch('%S+') do
                local arg_type = arg_name:find('"') and "string" or "number"
                arg_tbl[#arg_tbl + 1] = {
                    type = arg_type,
                    name = trim(arg_name:gsub('"', "")),
                    opt = (name == "setcursor" and arg_name == "custom_cursor_name") and "?" or nil
                }
            end
        end
        if opt_str then
            opt_str = opt_str:gsub("=1", ""):gsub(",", " "):gsub("%.%.%.", " ...")
            for arg_name in opt_str:gmatch('%S+') do
                local arg_type
                if name == "printf" and arg_name == "..." then
                    arg_type = "any"
                else
                    arg_type = arg_name:find('"') and "string" or "number"
                end
                arg_tbl[#arg_tbl + 1] = {
                    type = arg_type,
                    name = trim(arg_name:gsub('"', "")),
                    opt = "?"
                }
            end
        end
    end
    ret_tbl.rets = gfx_ret[name]
end

local function GenerateApiTbl(api_str)
    local API, GFX_API = {}, {}
    local CUR_API = API

    local dsc_tbl = {}
    local htmlstring = api_str --ReadApiFile(API_PATH)
    local c_str = ""
    for line in htmlstring:gmatch('[^\r\n]+') do
        -- GET DESCRIPTION
        -- DESCRIPTION IS LOCATED BELLOW THE FUNCTION
        if GET_DESC then
            -- STOP WHEN NEW FUNCTION IS HIT
            if line:match('<div class="function_definition') then
                GET_DESC = nil
                if #dsc_tbl ~= 0 then
                    CUR_API[#CUR_API].desc = table.concat(dsc_tbl, "\n")
                end
                dsc_tbl = {}
                -- ADD LINES
            elseif line:match("<br>") or line:match("</?p>") or line:match("<li>") or line:match("<ul>") then
                local str = trim(line):gsub("<p>", ""):gsub("</p>", ""):gsub("<li>", "* "):gsub("</li>", ""):gsub(
                    "<ul>", "*"):gsub("</ul>", ""):gsub("<br>\n?", "\x20\x20")
                if #str ~= 0 then
                    dsc_tbl[#dsc_tbl + 1] = "---" .. str
                end
            end
        end

        -- EXAMPLE STRING
        -- <div class="l_func"><code><em>integer</em> reaper.RecursiveCreateDirectory(<em>string</em> path, <em>integer</em> ignored)</code></div>

        -- HTML_STR = <em>integer</em> reaper.RecursiveCreateDirectory(<em>string</em> path, <em>integer</em> ignored)
        -- RET_STR =  <em>integer</em>
        -- NAME =                      reaper.RecursiveCreateDirectory
        -- ARG_STR =                                                   <em>string</em> path, <em>integer</em> ignored
        local html_str = line:match('<div class="l_func"><code>(.+)</code>')
        if line:match('<div class="c_func"><code>(.+)</code>') then
            c_str = line:match('<div class="c_func"><code>(.+)</code>')
        end
        if html_str and not html_str:match("ImGui") then
            -- JS_API JS_Composite Docs workaround
            html_str = html_str:gsub("strong", "em"):gsub("unsupported", "optional boolean")
            local name = html_str:match('({?reaper.%S+)%(') or html_str:match('(gfx.%S+)%(')
            if name then
                if not name:match("reaper.array") and not name:match("new_array") and not name:match("gfx%.") and not api_blacklist[name] then
                    CUR_API = API
                    GET_DESC = true
                    CUR_API[#CUR_API + 1] = { api_name = name, rets = {}, args = {} }
                    local return_str = html_str:match('(.-) reaper%.')
                    ParseReturns(CUR_API[#CUR_API].rets, return_str, name)
                    local argument_str = html_str:match("%((.+)%)")
                    c_str = c_str:match("%((.+)%)") or ""
                    --r.ShowConsoleMsg(c_str.."\n")
                    ParseArguments(CUR_API[#CUR_API].args, argument_str, c_str, name)
                    c_str = ""
                elseif name:match("gfx%.") then
                    CUR_API = GFX_API
                    GET_DESC = true
                    CUR_API[#CUR_API + 1] = { api_name = name, args = {} }
                    local argument_str = html_str:match("%((.+)%)")
                    ParseGfxArguments(CUR_API[#CUR_API].args, CUR_API[#CUR_API], argument_str,
                        name:gsub("gfx.", ""))
                end
            end
        end
    end
    return API, GFX_API
end

local added_types = {}
local function CheckType(v_type, str)
    if not ignore_class[v_type] then
        if not added_types[v_type] then
            table.insert(str, 1, "---@class (exact) " .. v_type .. " : userdata")
            added_types[v_type] = true
        end
    end
end

local html_entities = { amp = '&', gt = '>', lt = '<', nbsp = '\u{A0}' }

local html_string = ReadApiFile(API_PATH)
local reaper_api, gfx_api = GenerateApiTbl(html_string)
local reaper_str_tbl, gfx_str_tbl, array_str_tbl = { "\n" }, {}, {}

local union_types = {
    ["ReaProject"] = "|nil|0",
    ["KbdSectionInfo"] = "|integer"
}

local function CreateApiString(api, str)
    for i = 1, #api do
        local references = {}
        local name = api[i].api_name
        -- LEAVE & FROM &AMP; ETC IN DESCRIPTIONS
        if api[i].desc then
            api[i].desc = api[i].desc:gsub([[<a href=["']?#(.-)["']?>(.-)</a>]], function(anchor, text)
                references[#references + 1] = anchor
                return text
            end)

            api[i].desc = api[i].desc:gsub('&(.-);', html_entities):gsub('<br>\n%-%-%-<br>', '\n---'):gsub('\n%-%-%-$',
                ''):gsub('<br>$', '')
        end

        str[#str + 1] = api[i].desc

        -- if #references ~= 0 then
        --     str[#str + 1] = "---    "
        -- end

        local args = {}
        for j = 1, #api[i].args do
            CheckType(api[i].args[j].type, reaper_str_tbl)
            local opt_str = api[i].args[j].opt or ""
            str[#str + 1] = "---@param " ..
                api[i].args[j].name ..
                opt_str .. " " .. api[i].args[j].type .. (union_types[api[i].args[j].type] or "")
            args[#args + 1] = api[i].args[j].name
        end

        for j = 1, #api[i].rets do
            CheckType(api[i].rets[j].type, reaper_str_tbl)
            local opt_str = api[i].rets[j].opt or ""
            str[#str + 1] = "---@return " .. api[i].rets[j].type .. opt_str .. " " .. api[i].rets[j].name
        end

        -- if #references ~= 0 then
        --     for _, reference in ipairs(references) do
        --         str[#str + 1] = ('---@see reaper.' .. reference)
        --     end
        -- end

        str[#str + 1] = "function " .. name .. "(" .. table.concat(args, ", ") .. ") end\n"
    end
end

-- ADD REAPER API
CreateApiString(reaper_api, reaper_str_tbl)
-- ADD META
table.insert(reaper_str_tbl, 1, "---@diagnostic disable: keyword\n---@meta\n\n---@class reaper\nreaper = {}\n")
-- ADD LUA_ FUNCTIONS
table.insert(reaper_str_tbl, lua_func_str)
-- ADD GFX API
CreateApiString(gfx_api, gfx_str_tbl)
table.insert(gfx_str_tbl, 1, gfx_start_str)
-- ADD REAPER.ARRAY API
table.insert(array_str_tbl, 1, array_start_str)

local final_str = table.concat(reaper_str_tbl, "\n") ..
    "\n" .. table.concat(gfx_str_tbl, "\n") .. "\n" .. table.concat(array_str_tbl, "\n")

-- EXPORT IN REAPER FOLDER
SaveToFile(final_str, "DefinitionsOutput/reaper_defs.lua")
