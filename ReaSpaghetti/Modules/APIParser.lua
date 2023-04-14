--@noindex
--NoIndex: true


local r = reaper
local API_PATH = PATH .. "api_file.txt"

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

function ReadApiFile(load_path)
    local file = io.open(load_path, "r")
    if file then
        local string = file:read("*all")
        file:close()
        return string
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
    -- PROPERLY HANDLE THIS TYPE ONLY FOR IMGUI FUNCTIONS (EXCLUDE integer,float,table,string ...)
    ["IMGUI_RESOURCE"] = "IMGUI_OBJ",
}

--local Math_INT = { "+", "-", "*" }

local Math_FLOAT = { "+", "-", "*", "/", "%", "^" }

local Compare = { '==', '~=', '>', '>=', '<', '<=' }

--local Bitwise = { '&', '|', '~', '<<', '>>', '~n' }

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
                local name = filter_line:match('reaper.(.+%))'):gsub("%((.-)%)", "")
                if r.APIExists(name) then
                    --if r[name] then
                    found = true
                    api[#api + 1] = { fname = name, label = name, out = {}, ins = {}, desc = "", run = "in/out" }

                    -- MATCH BEFORE REAPER.
                    local return_vals = filter_line:match('(.+)reaper')

                    if return_vals then
                        -- STRIP , AND WHITESPACES
                        return_vals = return_vals:gsub(",", ""):gsub("optional", ""):gsub("%s+", "")

                        for a_type, a_name in return_vals:gmatch('<em>([^<]-)</em>(%a* ?)') do
                            -- IMGUI SPECIFIC TYPE OBJECT
                            if name:match("ImGui_Create") then
                                if not name:match("_CreateContext") then
                                    a_type = a_type .. "/IMGUI_OBJ"
                                end
                            end

                            api[#api].out[#api[#api].out + 1] = {
                                type = a_type:upper(),
                                name = a_name ~= "" and a_name:upper() or a_type:upper(),
                            }
                        end
                    end

                    -- MATCH AFTER REAPER FUNCTION NAME "("
                    local argument_vals = filter_line:match("%((.+)%)")

                    if argument_vals then
                        -- STRIP STUFF , OPTIONAL AND WHITESPACES
                        argument_vals = argument_vals:gsub(",", ""):gsub("optional", ""):gsub("%s+", "")
                        for a_type, a_name in argument_vals:gmatch('<em>([^<]-)</em>(%a+)') do
                            a_type = a_type:upper()
                            if convert[a_type] then a_type = convert[a_type] end
                            --if name:lower():find("showconsolemsg") then
                            --     a_type = "ANY"
                            --end
                            api[#api].ins[#api[#api].ins + 1] = {
                                type = a_type,
                                name = a_name:upper(),
                            }
                        end
                    end
                end
            end
        end
    end

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
        desc = "",
        ins = {
            { name = "", type = "ANY" },
        },
        out = {},
        run = "in/out"
    }

    -- TEST DEFER (HACK)
    api[#api + 1] = {
        fname = "CUSTOM_TestDefer",
        label = "LEGO Defer",
        desc = "",
        ins = {},
        out = {},
        run = "in/out"
    }

    -- TEST DEFER END (HACK)
    api[#api + 1] = {
        fname = "CUSTOM_TestDeferEND",
        label = "LEGO Defer End",
        desc = "",
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
        desc = "Returns VALUE T[KEY]",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "KEY",   type = "INTEGER", def_val = 1 },
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
        desc = "SETS VALUE T[KEY]",
        ins = {
            { name = "TABLE", type = "TABLE" },
            { name = "KEY",   type = "INTEGER", def_val = 1 },
            { name = "VAL",   type = "ANY" },
        },
        out = {},
        run = "in/out"
    }

    --RETURN NODE
    api[#api + 1] = {
        fname = "CUSTOM_ReturnNode",
        label = "Return Node",
        desc = "Returns values from function",
        ins = {
            { name = "VAL", type = "ANY" },
        },
        out = {},
        run = "in"
    }

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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
        ins = {
            { name = "X", type = "NUMBER/INTEGER", def_val = 0 },
            { name = "",  type = "STRING",         def_val = "atan", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "ATAN", type = "NUMBER" }
        },
    }

    -- MATH CEIL
    api[#api + 1] = {
        fname = "MathCeil",
        label = "MathCeil",
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
        ins = {
            { name = "", type = "DUMMY",  def_val = 1,        pin_disable = true, no_draw = true },
            { name = "", type = "STRING", def_val = "random", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "RND", type = "INTEGER" }
        },
    }

    -- MATH HUGE
    api[#api + 1] = {
        fname = "MathHuge",
        label = "MathHuge",
        desc = "",
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
        desc = "",
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
        desc = "",
        ins = {
            { name = "X", type = "INTEGER", def_val = 0 },
            { name = "",  type = "STRING",  def_val = "randomS", pin_disable = true, no_draw = true },
        },
        out = {
            { name = "RND", type = "INTEGER" }
        },
    }

    -- MATH RANDOM MULTI RANGE
    api[#api + 1] = {
        fname = "MathRandomMultiRange",
        label = "MathRandomMultiRange",
        desc = "",
        ins = {
            { name = "X", type = "INTEGER", def_val = 1 },
            { name = "",  type = "STRING",  def_val = "randomM", pin_disable = true, no_draw = true },
            { name = "Y", type = "INTEGER", def_val = 1 },
        },
        out = {
            { name = "RND", type = "INTEGER" }
        },
    }

    -- MATH FMOD
    api[#api + 1] = {
        fname = "MathFmod",
        label = "MathFmod",
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
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
        desc = "",
        ins = {},
        out = {
            { name = "PATH", type = "STRING" }
        },
        run = "in/out"
    }

    api[#api + 1] = {
        fname = "CUSTOM_GetOsNativeSeparator",
        label = "Get Native OS Separator",
        desc = "",
        ins = {},
        out = {
            { name = "PATH", type = "STRING" }
        },
        run = "in/out"
    }

    api[#api + 1] = {
        fname = "CUSTOM_MultiIfElse",
        label = "Multi IF-ELSE",
        desc = "",
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
        desc = "",
        ins = {
            { name = "INP 1", type = "BOOLEAN" },
        },
        out = {
            { name = "ELSE OUT", type = "RUN", run = false },
            { name = "OUT 1",    type = "RUN", run = false },
        },
        run = "in/out"
    }

    return api
end
