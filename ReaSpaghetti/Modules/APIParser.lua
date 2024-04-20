--@noindex
--NoIndex: true

local r = reaper
local API_PATH = PATH .. "api_file.txt"
local ULTRA_API_PATH = PATH .. "ultra_api.txt"
local IMGUI_DOCS_STR

function ReadApiFile(load_path)
    local file = io.open(load_path, "r")
    if file then
        local string = file:read("*all")
        file:close()
        return string
    end
end

local IMGUI_DEF_VALS = {}
local function GetImguiDefaults2(str)
    for line in str:gmatch('[^\r\n]+') do
        local f_name = line:match('ImGui%.(%S+)%(')
        if f_name and line:match('Optional =') then
            f_name = "ImGui_" .. f_name
            IMGUI_DEF_VALS[f_name] = {}
            for val_name, def_val in line:gmatch('</span> (%S+) = <span class="sn">(.-)</span>') do
                if val_name and def_val then
                    IMGUI_DEF_VALS[f_name][val_name] = def_val
                end
            end
        end
    end
end

if r.APIExists("ImGui_GetVersion") then
    IMGUI_DOCS_STR = ReadApiFile(r.GetResourcePath() .. "/Data/reaper_imgui_doc.html")
    GetImguiDefaults2(IMGUI_DOCS_STR)
end

function CurlToFile()
    local curl_cmd
    if r.GetOS():sub(1, 3) == 'Win' then
        curl_cmd = 'curl'
    else
        curl_cmd = '/usr/bin/curl'
    end

    r.ExecProcess(
        ([[%s -so "%s" https://www.extremraym.com/cloud/reascript-doc/ --ssl-no-revoke]]):format(curl_cmd, API_PATH), 0)
    UPDATE = true
end

function CreateApiFile()
    local file = io.open(API_PATH, "r")
    if file ~= nil then
        io.close(file)
    else
        CurlToFile()
    end
end

function FindApi(name)
    local Api_TBL = GetApiTBL()
    for i = 1, #Api_TBL do
        if name == Api_TBL[i].label then
            return Api_TBL[i]
        end
    end
end

local convert = {
    ["REAPROJECT"] = "INTEGER",
    -- PROPERLY HANDLE THIS TYPE ONLY FOR IMGUI FUNCTIONS
    ["IMGUI_RESOURCE"] = "IMGUI_OBJ",
}

local exclude_api = {
    ["defer"] = true
}

local Math_FLOAT = { "+", "-", "*", "/", "%", "^" }

local Compare = { '==', '~=', '>', '>=', '<', '<=' }

local function Parse_Ultraschall()
    if not ULTRA_API then return end

    local ul_tmp_tbl = {}
    local prefix = "US_"

    local functionnames_table = ultraschall.Docs_GetAllUltraschallApiFunctionnames()
    for i = 1, #functionnames_table do
        ul_tmp_tbl[#ul_tmp_tbl + 1] = {
            fname = functionnames_table[i],
            label = table.concat({ prefix, functionnames_table[i] }),
            out = {},
            ins = {},
            desc = ultraschall.Docs_GetUltraschallApiFunction_Description(functionnames_table[i], i),
            run = "in/out",
            sp_api = "ultraschall"
        }

        local _, params_table = ultraschall.Docs_GetUltraschallApiFunction_Params(functionnames_table[i], i)
        for j = 1, #params_table do
            local opt = params_table[j].datatype:find("optional") and { use = false } or nil
            ul_tmp_tbl[#ul_tmp_tbl].ins[#ul_tmp_tbl[#ul_tmp_tbl].ins + 1] = {
                type = params_table[j].datatype:gsub("optional ", ""):upper(),
                opt = opt,
                name = params_table[j].name:upper(),
                desc = params_table[j].description
            }
        end

        local _, retvals_table = ultraschall.Docs_GetUltraschallApiFunction_Retvals(functionnames_table[i], i)
        for j = 1, #retvals_table do
            --local opt = retvals_table[j].datatype:find("optional") and { use = false } or nil
            ul_tmp_tbl[#ul_tmp_tbl].out[#ul_tmp_tbl[#ul_tmp_tbl].out + 1] = {
                type = retvals_table[j].datatype:gsub("optional ", ""):upper(),
                -- opt = opt,
                name = retvals_table[j].name:upper(),
                desc = retvals_table[j].description
            }
        end
    end
    return ul_tmp_tbl
end

function WriteUltraApi(ret)
    local ultra_api_tbl = Parse_Ultraschall()
    local serialized = TableToString(ultra_api_tbl)
    local file_w = io.open(ULTRA_API_PATH, "w")
    if file_w then
        file_w:write(serialized) --- HERES
        file_w:close()
    end
    if ret then
        return ultra_api_tbl
    end
end

local function CheckUltraApiFile(ret)
    local file = io.open(ULTRA_API_PATH, "r")
    if file ~= nil then
        local string = file:read("*all")
        local ultra_api_tbl = StringToTable(string)
        io.close(file)
        if ultra_api_tbl ~= nil then
            if ret then
                return ultra_api_tbl
            end
        end
    else
        return WriteUltraApi(ret)
        -- local ultra_api_tbl = Parse_Ultraschall()
        -- local serialized = TableToString(ultra_api_tbl)
        -- local file_w = io.open(ULTRA_API_PATH, "w")
        -- if file_w then
        --     file_w:write(serialized) --- HERES
        --     file_w:close()
        -- end
        -- return ultra_api_tbl
    end
end

local function GetImguiDefaults(name, parm)
    --if parm:find("In") then
    --    parm = parm:sub(1, -3)
    --elseif parm:find("Out") then
    --    parm = parm:sub(1, -4)
    --end
    --uv_min_x = <span class="sn">0.0</span>
    --local imgui_str = ReadApiFile(IMGUI_DOC_PATH)
    IMGUI_DEF_VALS = {}
    for line in IMGUI_DOCS_STR:gmatch('[^\r\n]+') do
        if line:match(name .. '%(') then
            -- if name == "ImGui_DrawList_AddImage" then
            --     reaper.ShowConsoleMsg(line .. "\n")
            -- end
            if line:match(parm) then
                local def_val = line:match(parm .. "Optional" .. ' = <span class="sn">(.-)</span>')
                if def_val then
                    return def_val
                end
            end
        end
    end
end

function Fill_Api_list()
    local start, found
    local api = {}
    local api_str = ReadApiFile(API_PATH)
    for line in api_str:gmatch('[^\r\n]+') do
        -- GET DESCRIPTION
        if found then
            if line:match('<p>') then
                start = true
                if line:match('</p>') then
                    api[#api].desc = line:match('<p>(.-)</p>')
                    found = nil
                    start = nil
                else
                    api[#api].desc = api[#api].desc .. line:gsub('<p>', ""):gsub('<br>', "\n")
                end
            elseif line:match('<br>') and start then
                api[#api].desc = api[#api].desc .. line:gsub('<br>', "\n")
            elseif line:match('</p>') and start then
                api[#api].desc = api[#api].desc .. line:gsub('</p>', "")
                found = nil
                start = nil
            end
        end

        if line:match('<div class="l_func">') then
            local filter_line = line:match("<code>(.+)</code>")
            if filter_line:match('reaper.') and not filter_line:match('{reaper.') then
                --! FIX {reaper.array} functions
                --local name = filter_line:match('reaper.(.+%))'):gsub("%((.-)%)", "")
                local name = filter_line:match('reaper.(%S+)%(')
                if r.APIExists(name) and not exclude_api[name] then
                    found = true
                    api[#api + 1] = { fname = name, label = name, out = {}, ins = {}, desc = "", run = "in/out" }

                    -- MATCH BEFORE REAPER.
                    local return_vals = filter_line:match('(.+)reaper')

                    if return_vals then
                        if return_vals:find(",") then
                            for ret in return_vals:gmatch('[^,]+') do
                                --local opt = ret:find("optional") and { use = false } or nil
                                for r_type, r_name in ret:gsub("optional", ""):gsub("%s+", ""):gmatch('<em>(%S+)</em>(%S+ ?)') do
                                    api[#api].out[#api[#api].out + 1] = {
                                        type = r_type:upper(),
                                        name = r_name:upper(),
                                        -- opt = opt
                                    }
                                end
                            end
                        else
                            for r_type in return_vals:gmatch('<em>([^<]-)</em>') do
                                if name:match("ImGui_Create") then
                                    if not name:match("_CreateContext") then
                                        r_type = r_type .. "/IMGUI_OBJ"
                                    end
                                end

                                api[#api].out[#api[#api].out + 1] = {
                                    type = r_type:upper(),
                                    name = r_type:upper(),
                                }
                            end
                        end
                        -- STRIP , AND WHITESPACES
                        -- for ret in return_vals:gmatch('[^,]+') do
                        --     --reaper.ShowConsoleMsg(arg .. "\n\n")
                        --     for a_type, a_name in ret:gsub("optional", ""):gsub("%s+", ""):gmatch('<em>(%S+)</em>(%S+ ?)') do
                        --         -- IMGUI SPECIFIC TYPE OBJECT
                        --         if name:match("ImGui_Create") then
                        --             if not name:match("_CreateContext") then
                        --                 a_type = a_type .. "/IMGUI_OBJ"
                        --             end
                        --         end

                        --         api[#api].out[#api[#api].out + 1] = {
                        --             type = a_type:upper(),
                        --             name = a_name ~= "" and a_name:upper() or a_type:upper(),
                        --         }
                        --     end
                        -- end
                        -- return_vals = return_vals:gsub(",", ""):gsub("optional", ""):gsub("%s+", "")
                        -- for r_type, r_name in return_vals:gmatch('<em>([^<]-)</em>(%a* ?)') do
                        --     -- IMGUI SPECIFIC TYPE OBJECT
                        --     if name:match("ImGui_Create") then
                        --         if not name:match("_CreateContext") then
                        --             r_type = r_type .. "/IMGUI_OBJ"
                        --         end
                        --     end

                        --     api[#api].out[#api[#api].out + 1] = {
                        --         type = r_type:upper(),
                        --         name = r_name ~= "" and r_name:upper() or r_type:upper(),
                        --     }
                        -- end
                    end

                    -- MATCH AFTER REAPER FUNCTION NAME "("
                    local argument_vals = filter_line:match("%((.+)%)")

                    if argument_vals then
                        for arg in argument_vals:gmatch('[^,]+') do
                            local opt = arg:find("optional") and { use = false } or nil
                            for a_type, a_name in arg:gsub("optional", ""):gsub("%s+", ""):gmatch('<em>(%S+)</em>(%S+ ?)') do
                                local def_val
                                if opt then
                                    if name:find("ImGui_") then
                                        --def_val = GetImguiDefaults(name, a_name)
                                        def_val = IMGUI_DEF_VALS[name][a_name .. 'Optional']
                                    end
                                end
                                --end
                                a_type = a_type:upper()
                                if convert[a_type] then a_type = convert[a_type] end
                                api[#api].ins[#api[#api].ins + 1] = {
                                    type = a_type,
                                    name = a_name:upper(),
                                    opt = opt,
                                    def_val = def_val
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if ULTRA_API then
        local ultra_tbl = CheckUltraApiFile(true)
        if ultra_tbl then
            for i = 1, #ultra_tbl do
                api[#api + 1] = ultra_tbl[i]
            end
        end
    end

    --table.sort(api, function(a, b) return a.label:lower() < b.label:lower() end)

    -- NUMERIC FOR LOOP
    api[#api + 1] = {
        fname = "CUSTOM_ForLoop",
        label = "NUMERIC FOR LOOP",
        desc = "Start index \n Increment \n End index \n Loop Run, Loop finish -> RUN",
        ins = {
            { name = "START",      type = "INTEGER", def_val = 1 },
            { name = "INCREMENT",  type = "INTEGER", def_val = 1 },
            { name = "END",        type = "INTEGER", def_val = 1 },
            { name = "OUT IDX -1", type = "BOOLEAN", def_val = true, pin_disable = true }
        },
        out = {
            { name = "LOOP", type = "RUN",     run = true },
            { name = "IDX",  type = "INTEGER", def_val = 0 },
        },
        run = "in/out"
    }

    -- IPAIRS FOR LOOP
    api[#api + 1] = {
        fname = "CUSTOM_Ipairs",
        label = "IPAIRS FOR LOOP",
        desc = "Iterates indexed table - KEY - VALUE",
        ins = {
            { name = "TABLE", type = "TABLE" },
        },
        out = {
            { name = "LOOP",  type = "RUN",    run = true },
            { name = "KEY",   type = "INTEGER" },
            { name = "VALUE", type = "ANY" },
        },
        run = "in/out"
    }

    -- PAIRS FOR LOOP
    api[#api + 1] = {
        fname = "CUSTOM_Pairs",
        label = "PAIRS FOR LOOP",
        desc = "Iterates non indexed table (NO ORDER) - KEY - VALUE",
        ins = {
            { name = "TABLE", type = "TABLE" },
        },
        out = {
            { name = "LOOP",  type = "RUN", run = true },
            { name = "KEY",   type = "ANY" },
            { name = "VALUE", type = "ANY" },
        },
        run = "in/out"
    }

    --IF ELSE
    api[#api + 1] = {
        fname = "CUSTOM_IF_Else",
        label = "IF ELSE",
        desc = "Condition A == B -> TRUE RUN | Else -> FALSE RUN",
        ins = {
            { name = "INP",       type = "BOOLEAN" },
            { name = "CONDITION", type = "BOOLEAN", def_val = true }
        },
        out = {
            { name = "TRUE",  type = "RUN", run = false },
            { name = "FALSE", type = "RUN", run = false },
        },
        run = "in/out"
    }

    -- INTERNAL DBG VIEW MSG
    api[#api + 1] = {
        fname = "CUSTOM_DBG_View",
        label = "DEBUG MSG",
        desc = "Outpus to DEBUG VIEW",
        ins = {
            { name = "", type = "ANY" },
        },
        out = {},
        run = "in/out"
    }

    -- TEST DEFER (HACK)
    api[#api + 1] = {
        fname = "CUSTOM_TestDefer",
        label = "Spaghetti Defer",
        desc = "Defer script (Keep running in background)",
        ins = {},
        out = {},
        run = "in/out"
    }

    -- TEST DEFER END (HACK)
    api[#api + 1] = {
        fname = "CUSTOM_TestDeferEND",
        label = "Spaghetti Defer End",
        desc = "Kill Defer (stop running in background)",
        ins = {},
        out = {},
        run = "in/out"
    }


    --Table INSERT
    api[#api + 1] = {
        fname = "TableInsert",
        label = "Table Insert",
        desc = "Insert Value into table",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "VALUE", type = "ANY" }
        },
        out = {},
        run = "in/out"
    }

    --Table INSERT FAST
    api[#api + 1] = {
        fname = "TableInsertFast",
        label = "Table Insert TBL[#TBL +1]",
        desc = "Table insert TBL[#TBL +1]",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "VALUE", type = "ANY" }
        },
        out = {},
        run = "in/out"
    }

    --Table REMOVE
    api[#api + 1] = {
        fname = "TableRemove",
        label = "Table Remove",
        desc = "Remove key from table",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "IDX",   type = "INTEGER", def_val = 1 }
        },
        out = {},
        run = "in/out"
    }

    --Table CONCAT
    api[#api + 1] = {
        fname = "CUSTOM_TableConcat",
        label = "Table Concat",
        desc = "Concatate table values into string with specified delimiter",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "DELIM", type = "STRING" }
        },
        out = {
            { name = "RESULT", type = "STRING" }
        },
        run = "in/out"
    }

    --Table LENGHT
    api[#api + 1] = {
        fname = "CUSTOM_TableLenght",
        label = "Table Lenght",
        desc = "Returns Table Lenght",
        ins = {
            { name = "TABLE", type = "TABLE" },
        },
        out = {
            { name = "#", type = "INTEGER" }
        },
        run = "in/out"
    }

    --Table GetValue
    api[#api + 1] = {
        fname = "CUSTOM_TableGetVal",
        label = "Table GET VALUE",
        desc = "Returns VALUE T[IDX]",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "KEY",   type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "VAL", type = "ANY" }
        },
        run = "in/out"
    }

    --Table GetNamedValue
    api[#api + 1] = {
        fname = "CUSTOM_TableGetVal",
        label = "Table GET NAMED VALUE",
        desc = "Returns VALUE T.NAME",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "KEY",   type = "STRING", def_val = "" },
        },
        out = {
            { name = "VAL", type = "ANY" }
        },
        run = "in/out"
    }

    --Table SetValue
    api[#api + 1] = {
        fname = "CUSTOM_TableSetVal",
        label = "Table SET VALUE",
        desc = "SETS T[IDX] = VALUE",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "KEY",   type = "INTEGER", def_val = 1 },
            { name = "VAL",   type = "ANY" },
        },
        out = {},
        run = "in/out"
    }

    --Table SetNamedValue
    api[#api + 1] = {
        fname = "CUSTOM_TableSetVal",
        label = "Table SET NAMED VALUE",
        desc = "SETS T.NAME = VALUE",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "KEY",   type = "STRING", def_val = "" },
            { name = "VAL",   type = "ANY" },
        },
        out = {},
        run = "in/out"
    }

    --RETURN NODE
    -- api[#api + 1] = {
    --     fname = "CUSTOM_ReturnNode",
    --     label = "Return Node",
    --     desc = "Returns values from function",
    --     ins = {
    --         { name = "VAL", type = "ANY" },
    --     },
    --     out = {},
    --     run = "in"
    -- }

    -- MATH FLOAT
    api[#api + 1] = {
        fname = "MATH_FLOAT",
        label = "Math Operations",
        desc = "Math FLOAT/NUMBER + - / * ^ %",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "LIST",           def_val = Math_FLOAT[1], list = Math_FLOAT, pin_disable = true },
            { name = "Y", type = "NUMBER/INTEGER", def_val = 0 }
        },
        out = {
            { name = "RESULT", type = "NUMBER" },
        },
    }
    -- MATH COMPARE FLOAT
    api[#api + 1] = {
        fname = "MATH_FLOAT_Compare",
        label = "Math Compare",
        desc = "Compare == > >= < <=",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "LIST",           def_val = Compare[1], list = Compare, pin_disable = true },
            { name = "Y", type = "NUMBER/INTEGER", def_val = 0 }
        },
        out = {
            { name = "RESULT", type = "BOOLEAN" }
        }
    }

    -- MATH ABS
    api[#api + 1] = {
        fname = "MathAbs",
        label = "MathAbs",
        desc = "Returns Absolute value -> -10 = 10, 10 = 10",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "abs", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "ABS", type = "NUMBER" }
        },
    }

    -- MATH COS
    api[#api + 1] = {
        fname = "MathCos",
        label = "MathCos",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "cos", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "COS", type = "NUMBER" }
        },
    }

    -- MATH ACOS
    api[#api + 1] = {
        fname = "MathACos",
        label = "MathACos",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "acos", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "ACOS", type = "NUMBER" }
        },
    }

    -- MATH SIN
    api[#api + 1] = {
        fname = "MathSin",
        label = "MathSin",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "sin", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "SIN", type = "NUMBER" }
        },
    }

    -- MATH ASIN
    api[#api + 1] = {
        fname = "MathASin",
        label = "MathASin",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "asin", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "ASIN", type = "NUMBER" }
        },
    }

    -- MATH ATAN
    api[#api + 1] = {
        fname = "MathAtan",
        label = "MathAtan",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "atan", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "ATAN", type = "NUMBER" }
        },
    }

    -- MATH ATAN
    api[#api + 1] = {
        fname = "MathTan",
        label = "MathTan",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "tan", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "TAN", type = "NUMBER" }
        },
    }

    -- MATH CEIL
    api[#api + 1] = {
        fname = "MathCeil",
        label = "MathCeil",
        desc = "Returns Ceil Value - 0.6 = 1",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "ceil", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "CEIL", type = "NUMBER" }
        },
    }

    -- MATH FLOOR
    api[#api + 1] = {
        fname = "MathFloor",
        label = "MathFloor",
        desc = "Returns Floor value - 0.6 = 0",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "floor", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "FLOOR", type = "NUMBER" }
        },
    }

    -- MATH DEG
    api[#api + 1] = {
        fname = "MathDeg",
        label = "MathDeg",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "deg", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "DEG", type = "NUMBER" }
        },
    }

    -- MATH EXP
    api[#api + 1] = {
        fname = "MathExp",
        label = "MathExp",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "exp", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "EXP", type = "NUMBER" }
        },
    }

    -- MATH LOG
    api[#api + 1] = {
        fname = "MathLog",
        label = "MathLog",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "log", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "LOG", type = "NUMBER" }
        },
    }

    -- MATH MODF
    api[#api + 1] = {
        fnam = "MathModf",
        label = "MathModF",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "modf", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "MODF", type = "NUMBER" }
        },
    }

    -- MATH RAD
    api[#api + 1] = {
        fname = "MathRad",
        label = "MathRad",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "rad", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "RAD", type = "NUMBER" }
        },
    }

    -- MATH SQRT
    api[#api + 1] = {
        fname = "MathSqrt",
        label = "MathSqrt",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "sqrt", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "SQRT", type = "NUMBER" }
        },
    }

    -- MATH RANDOMSEED
    api[#api + 1] = {
        fname = "MathRandomSeed",
        label = "MathRandomSeed",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "randomseed", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "RND", type = "NUMBER" }
        },
    }

    -- MATH RANDOM
    api[#api + 1] = {
        fname = "MathRandom",
        label = "MathRandom",
        desc = "Returns Random value between 0-1",
        ins = {
            { name = "", type = "DUMMY",  def_val = 1,        pin_disable = true, no_draw = true },
            { name = "", type = "STRING", def_val = "random", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "RND", type = "NUMBER" }
        },
    }

    -- MATH HUGE
    api[#api + 1] = {
        fname = "MathHuge",
        label = "MathHuge",
        desc = "Returns High number",
        ins = {
            { name = "", type = "DUMMY",  def_val = 1,      pin_disable = true, no_draw = true },
            { name = "", type = "STRING", def_val = "huge", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "HUGE", type = "NUMBER" }
        },
    }

    -- MATH PI
    api[#api + 1] = {
        fname = "MathPi",
        label = "MathPi",
        --desc = "",
        ins = {
            { name = "", type = "DUMMY",  def_val = 1,    pin_disable = true, no_draw = true },
            { name = "", type = "STRING", def_val = "pi", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "PI", type = "NUMBER" }
        },
    }

    -- MATH RANDOMS SINGLE
    api[#api + 1] = {
        fname = "MathRandomSingleRange",
        label = "MathRandomSingleRange",
        desc = "Returns Random value from 0-Number",
        ins = {
            { name = "X", type = "INTEGER", def_val = 0 },
            { name = "",  type = "STRING",  def_val = "randomS", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "RND", type = "NUMBER" }
        },
    }

    -- MATH RANDOM MULTI RANGE
    api[#api + 1] = {
        fname = "MathRandomMultiRange",
        label = "MathRandomMultiRange",
        desc = "Returns Random value between to Numbers",
        ins = {
            { name = "X", type = "INTEGER", def_val = 1 },
            { name = "",  type = "STRING",  def_val = "randomM", pin_disable = true, no_draw = true },
            { name = "Y", type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "RND", type = "NUMBER" }
        },
    }

    -- MATH FMOD
    api[#api + 1] = {
        fname = "MathFmod",
        label = "MathFmod",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 1 },
            { name = "",  type = "STRING",         def_val = "fmod", pin_disable = true, no_draw = true },
            { name = "Y", type = "NUMBER/INTEGER", def_val = 1 },
        },
        out = {
            { name = "FMOD", type = "NUMBER" }
        },
    }

    -- MATH MAX
    api[#api + 1] = {
        fname = "MathMax",
        label = "MathMax",
        desc = "Returns Maximal Value",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 1 },
            { name = "",  type = "STRING",         def_val = "max", pin_disable = true, no_draw = true },
            { name = "Y", type = "NUMBER/INTEGER", def_val = 1 },
        },
        out = {
            { name = "MAX", type = "NUMBER" }
        },
    }

    -- MATH MIN
    api[#api + 1] = {
        fname = "MathMin",
        label = "MathMin",
        desc = "Returns Minimal Value",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 1 },
            { name = "",  type = "STRING",         def_val = "min", pin_disable = true, no_draw = true },
            { name = "Y", type = "NUMBER/INTEGER", def_val = 1 },
        },
        out = {
            { name = "MIN", type = "NUMBER" }
        },
    }

    -- MATH MIN
    api[#api + 1] = {
        fname = "MathPow",
        label = "MathPow",
        --desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 1 },
            { name = "",  type = "STRING",         def_val = "pow", pin_disable = true, no_draw = true },
            { name = "Y", type = "NUMBER/INTEGER", def_val = 1 },
        },
        out = {
            { name = "POW", type = "NUMBER" }
        },
    }

    -- MATH TYPE
    api[#api + 1] = {
        fname = "MathType",
        label = "MathType",
        desc = "Returns Type of the number : Integer - Float",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "DUMMY",          def_val = "mathtype", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "RND", type = "STRING" }
        },
    }

    api[#api + 1] = {
        fname = "MathIntToFloat",
        label = "INT TO FLOAT",
        desc = "Converte Integer to Float/Number",
        ins = {
            { name = "INT", type = "INTEGER", def_val = 1 },
            { name = "",    type = "STRING",  def_val = "IntToFloat", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "FLOAT", type = "NUMBER" }
        },
    }

    api[#api + 1] = {
        fname = "MathFloatToInt",
        label = "FLOAT TO INT",
        desc = "Converts Float/Number to Integer",
        ins = {
            { name = "FLOAT", type = "NUMBER", def_val = 1 },
            { name = "",      type = "STRING", def_val = "FloatToInt", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "INT", type = "INTEGER" }
        },
    }

    -- BITWISE--------------------

    -- BITSWISE AND &
    api[#api + 1] = {
        fname = "STD_Bitwise AND &",
        label = "Bitwise AND &",
        --desc = "",
        ins = {
            { name = "A", type = "INTEGER", def_val = 1 },
            { name = "",  type = "STRING",  def_val = "&", pin_disable = true, no_draw = true },
            { name = "B", type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "AND &", type = "INTEGER" }
        },
    }

    -- BITSWISE OR |
    api[#api + 1] = {
        fname = "STD_Bitwise OR |",
        label = "Bitwise OR |",
        --desc = "",
        ins = {
            { name = "A", type = "INTEGER", def_val = 1 },
            { name = "",  type = "STRING",  def_val = "|", pin_disable = true, no_draw = true },
            { name = "B", type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "OR |", type = "INTEGER" }
        },
    }

    -- BITSWISE XOR ~
    api[#api + 1] = {
        fname = "STD_Bitwise XOR ~",
        label = "Bitwise XOR ~",
        --desc = "",
        ins = {
            { name = "A", type = "INTEGER", def_val = 1 },
            { name = "",  type = "STRING",  def_val = "~", pin_disable = true, no_draw = true },
            { name = "B", type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "XOR ~", type = "INTEGER" }
        },
    }

    -- BITSWISE NOT
    api[#api + 1] = {
        fname = "STD_Bitwise NOT",
        label = "Bitwise NOT",
        -- desc = "",
        ins = {
            { name = "A", type = "INTEGER", def_val = 1 },
            { name = "",  type = "STRING",  def_val = "~x", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "NOT", type = "INTEGER" }
        },
    }

    -- BITSWISE LEFT SHIFT
    api[#api + 1] = {
        fname = "STD_Bitwise LEFT SHIFT",
        label = "Bitwise LEFT SHIFT",
        --desc = "",
        ins = {
            { name = "A", type = "INTEGER", def_val = 1 },
            { name = "",  type = "STRING",  def_val = "<<", pin_disable = true, no_draw = true },
            { name = "B", type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "LS", type = "INTEGER" }
        },
    }

    -- BITSWISE RIGHT SHIFT
    api[#api + 1] = {
        fname = "STD_Bitwise RIGHT SHIFT",
        label = "Bitwise RIGHT SHIFT",
        --desc = "",
        ins = {
            { name = "A", type = "INTEGER", def_val = 1 },
            { name = "",  type = "STRING",  def_val = ">>", pin_disable = true, no_draw = true },
            { name = "B", type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "RS", type = "INTEGER" }
        },
    }

    api[#api + 1] = {
        fname = "CUSTOM_Concat",
        label = "Concat",
        desc = "Standard Concatation\nHELLO + WORLD = HELO WORLD",
        ins = {
            { name = "A", type = "ANY" },
            -- { name = "",  type = "STRING", def_val = "concat", pin_disable = true, no_draw = true },
            { name = "B", type = "ANY" },
        },
        out = {
            { name = "", type = "STRING" }
        },
        run = "in/out"
    }

    api[#api + 1] = {
        fname = "CUSTOM_ToString",
        label = "ToString",
        desc = "CONVERTS TO STRING",
        ins = {
            { name = "VAL", type = "ANY" },
            --     { name = "",  type = "STRING", def_val = "tostring", pin_disable = true, no_draw = true },
            --{ name = "Y", type = "ANY",    def_val = 1 },
        },
        out = {
            { name = "", type = "STRING" }
        },
        run = "in/out"
    }

    api[#api + 1] = {
        fname = "CUSTOM_Type",
        label = "Type",
        desc = "RETURNS TYPE OF PIN",
        ins = {
            { name = "VAL", type = "ANY" },
            --     { name = "",  type = "STRING", def_val = "tostring", pin_disable = true, no_draw = true },
            --{ name = "Y", type = "ANY",    def_val = 1 },
        },
        out = {
            { name = "", type = "STRING" }
        },
        run = "in/out"
    }

    -- LOGICAL OP
    api[#api + 1] = {
        fname = "STD_And",
        label = "LUA AND",
        desc = "",
        ins = {
            { name = "A", type = "ANY" },
            { name = "",  type = "STRING", def_val = "lua_and", pin_disable = true, no_draw = true },
            { name = "B", type = "ANY" },
        },
        out = {
            { name = "VAL", type = "ANY" }
        },
    }

    -- LOGICAL OP
    api[#api + 1] = {
        fname = "STD_And",
        label = "LOGICAL AND",
        desc = "A AND B == TRUE -> TRUE AND TRUE = TRUE\n TRUE AND FALSE = FALSE",
        ins = {
            { name = "A", type = "ANY" },
            { name = "",  type = "STRING", def_val = "and", pin_disable = true, no_draw = true },
            { name = "B", type = "ANY" },
        },
        out = {
            { name = "BOOLEAN", type = "BOOLEAN" }
        },
    }

    api[#api + 1] = {
        fname = "STD_Not",
        label = "LOGICAL NOT",
        desc = "",
        ins = {
            { name = "A", type = "ANY" },
            { name = "",  type = "STRING", def_val = "not", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "BOOLEAN", type = "BOOLEAN" }
        },
    }

    api[#api + 1] = {
        fname = "STD_Or",
        label = "LUA OR",
        desc = "",
        ins = {
            { name = "A", type = "ANY" },
            { name = "",  type = "STRING", def_val = "lua_or", pin_disable = true, no_draw = true },
            { name = "B", type = "ANY" },
        },
        out = {
            { name = "VAL", type = "ANY" }
        },
    }

    api[#api + 1] = {
        fname = "STD_Or",
        label = "LOGICAL OR",
        desc = "A OR B == TRUE -> TRUE AND FALSE = TRUE",
        ins = {
            { name = "A", type = "ANY" },
            { name = "",  type = "STRING", def_val = "or", pin_disable = true, no_draw = true },
            { name = "B", type = "ANY" },
        },
        out = {
            { name = "BOOLEAN", type = "BOOLEAN" }
        },
    }

    api[#api + 1] = {
        fname = "CUSTOM_GetScriptPath",
        label = "Get Script Path",
        desc = "Returns Scripts PATH",
        ins = {},
        out = {
            { name = "PATH", type = "STRING" }
        },
        run = "in/out"
    }

    api[#api + 1] = {
        fname = "CUSTOM_GetOsNativeSeparator",
        label = "Get Native OS Separator",
        desc = "Get native OS SLASH separator",
        ins = {},
        out = {
            { name = "PATH", type = "STRING" }
        },
        run = "in/out"
    }

    api[#api + 1] = {
        fname = "CUSTOM_MultiIfElse",
        label = "Multi IF-ELSE",
        desc = "Open Node Inspector to add/remove inputs",
        ins = {
            { name = "CONDITION", type = "BOOLEAN", def_val = true },
            { name = "INP 1",     type = "BOOLEAN" },
        },
        out = {
            { name = "TRUE",  type = "RUN", run = false },
            { name = "FALSE", type = "RUN", run = false },
        },
        run = "in/out"
    }

    api[#api + 1] = {
        fname = "CUSTOM_MultiIfElseifElse",
        label = "SWITCH",
        desc = "SWITCH STATEMENT\nOpen Node inspector to add/remove inputs",
        ins = {
            { name = "INP 1", type = "BOOLEAN" },
        },
        out = {
            { name = "ELSE OUT", type = "RUN", run = false },
            { name = "OUT 1",    type = "RUN", run = false },
        },
        run = "in/out"
    }

    -- dB to Val
    api[#api + 1] = {
        fname = "CUSTOM_dBToVAL",
        label = "dB to VAL",
        desc = "CONVERTS dB TO VALUE FOR CONNECTING TO API (API DOES NOT EXPECT dB BUT VALUE)",
        ins = {
            { name = "dB", type = "NUMBER", def_val = 0 },
        },
        out = {
            { name = "VALUE", type = "NUMBER", def_val = 0 },
        },
        run = "in/out"
    }

    -- Val to Db
    api[#api + 1] = {
        fname = "CUSTOM_VALtodB",
        label = "VAL TO dB",
        desc = "CONVERTS CURRENT VALUE TO dB",
        ins = {
            { name = "VALUE", type = "NUMBER", def_val = 0 },
        },
        out = {
            { name = "dB", type = "NUMBER", def_val = 0 },
        },
        run = "in/out"
    }

    -- Nil Check
    api[#api + 1] = {
        fname = "CUSTOM_NilCheck",
        label = "IS NIL",
        desc = "CHECKS IF INCOMING VARIABLE IS NIL",
        ins = {
            { name = "VALUE", type = "ANY" },
        },
        out = {
            { name = "NIL", type = "BOOLEAN", def_val = true },
        },
        run = "in/out"
    }

    -- VAL TO BOOL
    api[#api + 1] = {
        fname = "CUSTOM_ValToBool",
        label = "CONVERTS 0 to FALSE and > 0 to TRUE",
        desc = "CHECKS IF INCOMING VARIABLE IS NIL",
        ins = {
            { name = "VALUE", type = "NUMBER" },
        },
        out = {
            { name = "BOOL", type = "BOOLEAN", def_val = true },
        },
        run = "in/out"
    }

    -- VAL TO BOOL
    api[#api + 1] = {
        fname = "CUSTOM_SwitchValue",
        label = "TOGGLE VALUE 0-1",
        desc = "TOGGLES VALUE TO 0 IS VALUE IS 1 OR 1 IF VALUE IS 0",
        ins = {
            { name = "VALUE", type = "NUMBER" },
        },
        out = {
            { name = "NEW VAL", type = "NUMBER", def_val = 0 },
        },
        run = "in/out"
    }

    -- VAL TO BOOL
    api[#api + 1] = {
        fname = "CUSTOM_DoWhile",
        label = "DO WHILE",
        desc = "DO UNTIL CONDITION IS MET",
        ins = {
            { name = "VALUE", type = "BOOLEAN" },
        },
        out = {
            { name = "LOOP", type = "RUN", run = true },
        },
        run = "in/out"
    }

    -- VAL TO BOOL
    api[#api + 1] = {
        fname = "CUSTOM_ClearTable",
        label = "Clear/Renew Table",
        desc = "Clears Table with new table",
        ins = {
            { name = "TABLE", type = "TABLE" },
        },
        out = {},
        run = "in/out"
    }

    -- VAL TO BOOL
    api[#api + 1] = {
        fname = "CUSTOM_CheckTableKV",
        label = "Table HAS K",
        desc = "Checs if K exists",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "K",     type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "HAS K", type = "BOOLEAN" },
        },
        run = "in/out"
    }

    -- VAL TO BOOL
    api[#api + 1] = {
        fname = "CUSTOM_StringCompare",
        label = "Compare ==",
        desc = "Checks if two strings are equal",
        ins = {
            { name = "VAL 1", type = "ANY" },
            { name = "VAL 2", type = "ANY" },
        },
        out = {
            { name = "SAME", type = "BOOLEAN" },
        },
        run = "in/out"
    }

    return api
end
