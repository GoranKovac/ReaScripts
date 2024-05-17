local r = reaper
local script_path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
local API_PATH = script_path .. "api_imgui_pre09.txt"

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
    ["reaper_array"] = true
}

local imgui_class_types =  {
 ["ImGui_Resource"] = "userdata",
 ["ImGui_DrawList"] = "userdata",
 ["ImGui_Viewport"] = "userdata",
 ["ImGui_Context"] = "ImGui_Resource",
 ["ImGui_DrawListSplitter"] = "ImGui_Resource",
 ["ImGui_Font"] = "ImGui_Resource",
 ["ImGui_Function"] = "ImGui_Resource",
 ["ImGui_Image"] = "ImGui_Resource",
 ["ImGui_ImageSet"] = "ImGui_Image",
 ["ImGui_ListClipper"] = "ImGui_Resource",
 ["ImGui_TextFilter"] = "ImGui_Resource",
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

local function trim(s)
    if not s then return end
    return s:match '^%s*(.*%S)' or ''
end

local function ParseReturns(tbl, ret_str, name)
    if name == "reaper.my_getViewport" then
        tbl[#tbl + 1] = {type = "integer", name = "left"}
        tbl[#tbl + 1] = {type = "integer", name = "top"}
        tbl[#tbl + 1] = {type = "integer", name = "right"}
        tbl[#tbl + 1] = {type = "integer", name = "bottom"} 
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
                for ret_type, ret_name in ret:gmatch('<i>(.+)</i>(.+ ?)') do
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
                        type = ret_type:gsub("</i><i>", ""),
                        name = ret_name,
                        opt = opt,
                    }
                end
            end
        else
            -- SINGLE RETURNS
            for ret_type in ret_str:gmatch('<i>([^<]-)</i>') do
                local opt
                if ret_type:find("optional") then
                    ret_type = ret_type:gsub("optional ", "")
                    opt = "?"
                end
                tbl[#tbl + 1] = {
                    type = ret_type:match("identifier") and "userdata" or trim(ret_type),
                    name = "retval",
                    opt = opt
                }
            end
        end
    end
end

local function ParseArguments(tbl, arg_str, c_str, name)
    if not arg_str then return end
    -- genGuid DOES NOT TAKE ANY PARAMETERS
    for arg in arg_str:gmatch('[^,]+') do
        for arg_type, arg_name in arg:gmatch('<i>(.+)</i>(.+ ?)') do
            local opt
            arg_name = trim(arg_name)
            arg_type = arg_type:match("identifier") and "userdata" or trim(arg_type)
            arg_type = arg_type:match("reaper_array") and "reaper.array" or arg_type
            -- CONVERT TO ANOTATIONS OPTIONAL `type?`
            if arg_type:find("optional") then
                arg_type = arg_type:gsub("optional ", "")
                opt = "?"
            elseif arg_name and c_str:find(arg_name.."Optional") then
                --r.ShowConsoleMsg("C OPT FOUND - " .. name .. "  :  " .. arg_name.."\n")             
                opt = "?"
            end
            
            tbl[#tbl + 1] = {
                type = arg_type:gsub("</i><i>", ""),
                name = arg_name:gsub("%.", "_"):gsub("%)", ""),
                opt = opt,
            }
        end
    end
end

local function GenerateApiTbl(api_str)
    local API, GFX_API = {}, {}
    local CUR_API = API

    local dsc_tbl = {}
    local htmlstring = api_str
    local c_str = ""
    for line in htmlstring:gmatch('[^\r\n]+') do
        -- GET DESCRIPTION
        -- DESCRIPTION IS LOCATED BELLOW THE FUNCTION
        if GET_DESC then
            -- STOP WHEN NEW FUNCTION IS HIT
            if line:match('<a name=') then
                GET_DESC = nil
                if #dsc_tbl ~= 0 then
                    CUR_API[#CUR_API].desc = table.concat(dsc_tbl, "\n")
                end
                dsc_tbl = {}
                -- ADD LINES
            elseif line:match("<br>$") or line:match("</?p>") or line:match("<li>") or line:match("<ul>") then
                local str = trim(line):gsub("<p>", ""):gsub("</p>", "<br>"):gsub("<li>", "* "):gsub("</li>", ""):gsub(
                        "<ul>", "*")
                    :gsub("</ul>", "")
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
        local html_str
        if line:match('<div class="l_func') then
            html_str = line:match('<code>(.+)</code>')
        end
        if line:match('<div class="c_func') then
            c_str = line:match('<code>(.+)</code>')
        end
        if html_str then
            local name = html_str:match('({?reaper.%S+)%(')
            if name and name:match("reaper.ImGui_") and not name:match("reaper.ImGui__") and not name:match("reaper.ImGui_GetBuiltinPath") then
                CUR_API = API
                GET_DESC = true
                CUR_API[#CUR_API + 1] = { api_name = name, rets = {}, args = {} }
                local return_str = html_str:match('(.-) reaper%.')
                ParseReturns(CUR_API[#CUR_API].rets, return_str, name)
                local argument_str = html_str:match("%((.+)%)")
                c_str = c_str:match("%((.+)%)") or ""
                ParseArguments(CUR_API[#CUR_API].args, argument_str, c_str, name)
                c_str = ""      
            end
        end
    end
    return API, GFX_API
end

local added_types = {}
local function CheckType(v_type, str)
    if not ignore_class[v_type] then
        if not added_types[v_type] then
            table.insert(str, 1, "---@class (exact) " .. v_type .. " : " .. imgui_class_types[v_type])
            added_types[v_type] = true
        end
    end
end

local html_entities = { amp = '&', gt = '>', lt = '>', nbsp = '\u{A0}' }

local html_string = ReadApiFile(API_PATH)
local reaper_api = GenerateApiTbl(html_string)
local reaper_str_tbl = { "\n" }

local union_types = {
    ["ImGui_Font"] = "|nil",
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

        str[#str + 1] = "function " .. name .. "(" .. table.concat(args, ", ") .. ") end\n"
    end
end

-- ADD REAPER API
CreateApiString(reaper_api, reaper_str_tbl)
-- ADD META
table.insert(reaper_str_tbl, 1, "---@diagnostic disable: keyword\n---@meta\n\n") -- ---@class reaper\nreaper = {}\n

local final_str = table.concat(reaper_str_tbl, "\n")
-- EXPORT IN REAPER FOLDER
SaveToFile(final_str, script_path .. "DefinitionsOutput/imgui_pre09_defs.lua")
