--@noindex
--NoIndex: true
local r = reaper

local random, huge, pi, abs, cos, acos, sin, asin, atan, tan, ceil, floor, deg, exp, log, modf, rad, sqrt, randomseed, fmod, min, max, mtype =
    math.random, math.huge, math.pi, math.abs, math.cos, math.acos, math.sin, math.asin, math.atan, math.tan, math.ceil,
    math.floor, math.deg, math.exp, math.log, math.modf, math.rad, math.sqrt, math.randomseed, math.fmod, math.min,
    math.max, math.type

local Math = {
    ['==']         = function(x, y) return x == y end,
    ['~=']         = function(x, y) return x ~= y end,
    ['>']          = function(x, y) return x > y end,
    ['>=']         = function(x, y) return x >= y end,
    ['<']          = function(x, y) return x < y end,
    ['<=']         = function(x, y) return x <= y end,
    ["+"]          = function(x, y) return x + y end,
    ["-"]          = function(x, y) return x - y end,
    ["*"]          = function(x, y) return x * y end,
    ["/"]          = function(x, y)
        if x == 0 or y == 0 then return 0 end
        return x / y
    end,
    ["%"]          = function(x, y)
        if x == 0 or y == 0 then return 0 end
        return x % y
    end,
    ["^"]          = function(x, y) return x ^ y end,
    ["random"]     = function() return random() end,
    ["huge"]       = function() return huge end,
    ["pi"]         = function() return pi end,
    ["abs"]        = function(x) return abs(x) end,
    ["cos"]        = function(x) return cos(x) end,
    ["acos"]       = function(x) return acos(x) end,
    ["sin"]        = function(x) return sin(x) end,
    ["asin"]       = function(x) return asin(x) end,
    ["atan"]       = function(x) return atan(x) end,
    ["tan"]        = function(x) return tan(x) end,
    ["ceil"]       = function(x) return ceil(x) end,
    ["floor"]      = function(x) return floor(x) end,
    ["deg"]        = function(x) return deg(x) end,
    ["exp"]        = function(x) return exp(x) end,
    ["log"]        = function(x) return log(x) end,
    ["modf"]       = function(x) return modf(x) end,
    ["rad"]        = function(x) return rad(x) end,
    ["sqrt"]       = function(x) return sqrt(x) end,
    ["randomseed"] = function(x) return randomseed(x) end,
    ["randomS"]    = function(x) if x == 0 then return 0 else return random(abs(x)) end end,
    ["randomM"]    = function(x, y) if x == 0 or y == 0 then return 0 else return random(abs(x), abs(y)) end end,
    ["fmod"]       = function(x, y) return fmod(x, y) end,
    ["max"]        = function(x, y) return max(x, y) end,
    ["min"]        = function(x, y) return min(x, y) end,
    ["pow"]        = function(x, y) return x ^ y end,
    ["mathtype"]   = function(x) return mtype(x) end,
    ["IntToFloat"] = function(x) return x + .0 end,
    ["FloatToInt"] = function(x) return floor(x) end,
}

local LuaStd = {
    -- LOGICAL OP
    ["and"]     = function(x, y)
        if x and y then
            return true
        else
            return false
        end
    end,
    ["or"]      = function(x, y)
        if x or y then
            return true
        else
            return false
        end
    end,
    -- LOGICAL LUA OP
    ["lua_and"] = function(x, y) return (x and y) end,
    ["lua_or"]  = function(x, y) return (x or y) end,
    ["not"]     = function(x) return (not x) end,
    --- BITWISE
    ["&"]       = function(x, y) return x & y end,
    ["|"]       = function(x, y) return x | y end,
    ["~"]       = function(x, y) return x ~ y end,
    ["<<"]      = function(x, y) return x << y end,
    [">>"]      = function(x, y) return x >> y end,
    ["~x"]      = function(x) return ~x end,
}

-- LITTLE BIGGER TAN ORIGINAL NOT TO TRIGGER __index WHEN CALLING .o_val
function CheckCurrentInput(node_inp)
    local a, b = 0, 0
    if node_inp[1] then
        if #node_inp[1].connection == 0 then
            a = node_inp[1].i_val
        else
            local v = node_inp[1].o_val
            a = v == nil and a or v
        end
    end
    if node_inp[3] then
        if #node_inp[3].connection == 0 then
            b = node_inp[3].i_val
        else
            local v = node_inp[3].o_val
            b = v == nil and b or v
        end
        return a, b
    end
    return a
end

function DoMath(op, node)
    local a, b = CheckCurrentInput(node.inputs)
    return Math[op](a, b)
end

function DoStd(op, node)
    local a, b = CheckCurrentInput(node.inputs)
    return LuaStd[op](a, b)
end

function CUSTOM_ForLoop(called_node, func_node, idx_start, idx_skip, idx_end, bool_minus_1)
    GetChildFlow(called_node, func_node)
    for i = idx_start, idx_end, idx_skip do
        called_node.outputs[2].o_val = bool_minus_1 and i - 1 or i
        Run_Flow(called_node.LOOP_FLOW, func_node)
    end
    called_node.LOOP_FLOW = nil
end

function CUSTOM_Fastpairs(called_node, func_node, tbl)
    if not tbl then return "ERROR" end
    GetChildFlow(called_node, func_node)
    for i = 1, #tbl do
        called_node.outputs[2].o_val = i
        called_node.outputs[3].o_val = tbl[i]
        Run_Flow(called_node.LOOP_FLOW, func_node)
    end
    called_node.LOOP_FLOW = nil
end

function CUSTOM_Ipairs(called_node, func_node, tbl)
    if not tbl then return "ERROR" end
    if type(tbl) ~= "table" then return "ERROR" end
    GetChildFlow(called_node, func_node)
    for k, v in ipairs(tbl) do
        called_node.outputs[2].o_val = k
        called_node.outputs[3].o_val = v
        Run_Flow(called_node.LOOP_FLOW, func_node)
    end
    called_node.LOOP_FLOW = nil
end

function CUSTOM_Pairs(called_node, func_node, tbl)
    if not tbl then return "ERROR" end
    if type(tbl) ~= "table" then return "ERROR" end

    GetChildFlow(called_node, func_node)
    for k, v in pairs(tbl) do
        called_node.outputs[2].o_val = k
        called_node.outputs[3].o_val = v
        Run_Flow(called_node.LOOP_FLOW, func_node)
    end
    called_node.LOOP_FLOW = nil
end

function CUSTOM_IF_Else(called_node, func_node, cond_a, cond_b)
    called_node.outputs[1].run = false
    called_node.outputs[2].run = false

    local a, b

    if called_node.inputs[1].o_val == nil then
        a = called_node.inputs[1].i_val
    else
        a = called_node.inputs[1].o_val
    end

    if called_node.inputs[2].o_val == nil then
        b = called_node.inputs[2].i_val
    else
        b = called_node.inputs[2].o_val
    end

    if a == b then
        called_node.outputs[1].run = true
        GetChildFlow(called_node, func_node)
        Run_Flow(called_node.LOOP_FLOW, func_node)
    else
        called_node.outputs[2].run = true
        GetChildFlow(called_node, func_node)
        Run_Flow(called_node.LOOP_FLOW, func_node)
    end
    called_node.LOOP_FLOW = nil
end

function CUSTOM_Concat(called_node, func_node)
    local a = called_node.inputs[1].o_val and called_node.inputs[1].o_val or ""
    local b = called_node.inputs[2].o_val and called_node.inputs[2].o_val or ""
    called_node.outputs[1].o_val = tostring(a) .. tostring(b)
end

function CUSTOM_ToString(called_node, func_node)
    called_node.outputs[1].o_val = tostring(called_node.inputs[1].o_val)
end

function CUSTOM_Type(called_node, func_node)
    if not called_node.inputs[1].o_val then return "ERROR" end
    called_node.outputs[1].o_val = type(called_node.inputs[1].o_val)
end

function CUSTOM_DBG_View(called_node, func_node)
    LEGO_MGS[#LEGO_MGS + 1] = Unbackslashed(called_node.inputs[1].o_val)
end

function CUSTOM_TestDefer(called_node)
    DEFERED_NODE = called_node
end

function CUSTOM_TestDeferEND(called_node, func_node)
    DEFERED_NODE = nil
end

function CUSTOM_Set(called_node)
    if called_node.set.api then
        called_node.outputs[1].o_val = called_node.inputs[1].o_val
    else
        called_node.outputs[1].set = called_node.inputs[1].o_val
        local dummy_index_call = called_node.outputs[1].get
    end
end

function StdDo(a, op, b)
    return LuaStd[op](a, b)
end

function TableInsert(tbl, value)
    table.insert(tbl, value)
end

function TableInsertFast(tbl, value)
    tbl[#tbl + 1] = value
end

function TableRemove(tbl, key)
    -- SILENT STOP (DONT CRASH)
    if not tbl[key] then return end
    table.remove(tbl, key)
end

function CUSTOM_TableConcat(called_node, func_node, tbl, delim)
    if not tbl then return "ERROR" end
    if type(tbl[1]) == "table" then return "ERROR" end
    called_node.outputs[1].o_val = table.concat(tbl, delim)
end

function CUSTOM_TableLenght(called_node, func_node, tbl)
    if not tbl then return "ERROR" end
    called_node.outputs[1].o_val = #tbl
end

function CUSTOM_TableConstructor(called_node, func_node)
    called_node.outputs[1].o_val = {}
    for i = 1, #called_node.inputs do
        if called_node.inputs[i].to_key then
            called_node.outputs[1].o_val[called_node.inputs[i].label] = called_node.inputs[i].o_val
        else
            called_node.outputs[1].o_val[#called_node.outputs[1].o_val + 1] = called_node.inputs[i].o_val
        end
    end
end

function CUSTOM_TableGetVal(called_node, func_node, tbl, key)
    if not tbl then return "ERROR" end
    if not tbl[key] then return "ERROR" end

    if CheckInputType(called_node, { tbl[key] }, func_node.NODES, "GET") then
        BREAK_RUN = true
        Deselect_all()
        CHANGE_FTAB = func_node.FID
        return "ERROR"
    end
    called_node.outputs[1].o_val = tbl[key]
end

function CUSTOM_TableSetVal(called_node, func_node, tbl, key, val)
    if not tbl then return "ERROR" end
    if not tbl[key] then return "ERROR" end
    if val == nil then return "ERROR" end

    if CheckInputType(called_node, { val, key }, func_node.NODES, "SET") then
        BREAK_RUN = true
        Deselect_all()
        CHANGE_FTAB = func_node.FID
        return "ERROR"
    end
    tbl[key] = val
end

function CUSTOM_ReturnNode(called_node, func_node)
    if not func_node then return end
    for i = 1, #called_node.inputs do
        func_node.outputs[i].o_val = called_node.inputs[i].o_val
        func_node.outputs[i].i_val = called_node.inputs[i].i_val
    end
end

function CUSTOM_FunctionStartArgs(called_node, func_node)
    if not func_node then return end
    for i = 1, #called_node.outputs do
        called_node.outputs[i].o_val = func_node.inputs[i].o_val
        called_node.outputs[i].i_val = func_node.inputs[i].i_val
    end
end

function CUSTOM_GetScriptPath(called_node, func_node)
    called_node.outputs[1].o_val = PATH
end

function CUSTOM_GetOsNativeSeparator(called_node, func_node)
    called_node.outputs[1].o_val = NATIVE_SEPARATOR
end

function CUSTOM_MultiIfElse(called_node, func_node)
    called_node.outputs[1].run = false
    called_node.outputs[2].run = false

    local true_false = true

    local condition
    if called_node.inputs[1].o_val == nil then
        condition = called_node.inputs[1].i_val
    else
        condition = called_node.inputs[1].o_val
    end

    for i = 2, #called_node.inputs do
        local inp_condition
        if called_node.inputs[i].o_val == nil then
            inp_condition = called_node.inputs[i].i_val
        else
            inp_condition = called_node.inputs[i].o_val
        end
        if inp_condition ~= condition then
            true_false = false
            break
        end
    end
    if true_false then
        called_node.outputs[1].run = true
        GetChildFlow(called_node, func_node)
        Run_Flow(called_node.LOOP_FLOW, func_node)
    else
        called_node.outputs[2].run = true
        GetChildFlow(called_node, func_node)
        Run_Flow(called_node.LOOP_FLOW, func_node)
    end
    called_node.LOOP_FLOW = nil
end

function CUSTOM_MultiIfElseifElse(called_node, func_node)
    for i = 1, #called_node.outputs do
        called_node.outputs[i].run = false
    end
    local else_out = true
    for i = 1, #called_node.inputs do
        local inp_condition
        if called_node.inputs[i].o_val == nil then
            inp_condition = called_node.inputs[i].i_val
        else
            inp_condition = called_node.inputs[i].o_val
        end
        if inp_condition then
            called_node.outputs[i + 1].run = true
            GetChildFlow(called_node, func_node)
            Run_Flow(called_node.LOOP_FLOW, func_node)
            else_out = false
            break
        end
    end
    if else_out then
        called_node.outputs[1].run = true
        GetChildFlow(called_node, func_node)
        Run_Flow(called_node.LOOP_FLOW, func_node)
    end
    called_node.LOOP_FLOW = nil
end

function CUSTOM_dBToVAL(called_node, func_node)
    local LN10_OVER_TWENTY = 0.11512925464970228420089957273422
    local x = #called_node.inputs[1].connection ~= 0 and called_node.inputs[1].o_val or called_node.inputs[1].i_val
    called_node.outputs[1].o_val = exp(x * LN10_OVER_TWENTY)
end

function CUSTOM_VALtodB(called_node, func_node)
    local x = #called_node.inputs[1].connection ~= 0 and called_node.inputs[1].o_val or called_node.inputs[1].i_val
    if x < 0.0000000298023223876953125 then
        called_node.outputs[1].o_val = -150
    else
        called_node.outputs[1].o_val = max(-150, log(x) * 8.6858896380650365530225783783321)
    end
end

function CUSTOM_NilCheck(called_node, func_node)
    if called_node.inputs[1].o_val == nil then
        called_node.outputs[1].o_val = true
    else
        called_node.outputs[1].o_val = false
    end
end

function CUSTOM_ValToBool(called_node, func_node)
    local x = #called_node.inputs[1].connection ~= 0 and called_node.inputs[1].o_val or called_node.inputs[1].i_val
    called_node.outputs[1].o_val = x <= 0 and true or false
end

function CUSTOM_SwitchValue(called_node, func_node)
    local x = #called_node.inputs[1].connection ~= 0 and called_node.inputs[1].o_val or called_node.inputs[1].i_val
    called_node.outputs[1].o_val = x == 0 and 1 or 0
end

function CUSTOM_DoWhile(called_node, func_node)
    GetChildFlow(called_node, func_node)

    while called_node.inputs[1].o_val do
        GetChildFlow(called_node, func_node)
        Run_Flow(called_node.LOOP_FLOW, func_node)
    end
    called_node.LOOP_FLOW = nil
end

function CUSTOM_ClearTable(called_node, func_node, tbl)
    if not called_node.inputs[1].o_val then return "ERROR" end

    -- tbl = {}
    local target_guid = called_node.inputs[1].connection[1].node
    local target = GetNodeInfo(target_guid)

    ----if target.type == "get" then
    --     target = GetNodeInfo(target.get)
    --end

    --reaper.ShowConsoleMsg(tostring(target.outputs[1].o_val) .. "\n")
    --reaper.ShowConsoleMsg(target.guid)
    target.outputs[1].o_val = {}

    --reaper.ShowConsoleMsg(tostring(target.outputs[1].o_val) .. "\n")
    --target.outputs[1].i_val = {}
    --called_node.inputs[1].o_val = {}
end

function CUSTOM_CheckTableKV(called_node, func_node, tbl, key)
    if not tbl then return "ERROR" end
    if tbl[key] then
        called_node.outputs[1].o_val = true
    else
        called_node.outputs[1].o_val = false
    end
end

-- CODE NODE
-- PREPARE METATABLE FOR READING INPUTS (CODE NODE)
local inputAccessor = {}
setmetatable(inputAccessor, {
    __index    = function(t, k)
        if k == 0 then return "ERROR" end

        --if k == #t.node.inputs then return "ERROR" end
        if type(k) ~= "number" then return "ERROR" end

        --if k == "code" then return t.node.inputs[1].o_val end
        -- CODE INPUT IS 1
        local key = k + 1
        local value = #t.node.inputs[key].connection ~= 0 and t.node.inputs[key].o_val or t.node.inputs[key].i_val
        -- DONT ALLOW NON INDEXED KEYS
        --if type(key) ~= "number" then return "ERROR" end
        -- DONT ALLOW USING INPUTS 0 (RUN) AND LAST INPUT (STRING CODE)
        --if k == 0 or k == #t.node.inputs then return "ERROR" end
        return value
    end,
    __newindex = function(t, k, v)
        -- DONT ALLOW WRITING INPUTS
        return "ERROR"
    end,
})

-- PREPARE METATABLE FOR READING/WRITING OUTPUTS (CODE NODE)
local outputAccessor = {}
setmetatable(outputAccessor, {
    __index = function(t, k)
        -- DONT ALLOW NON INDEXED KEYS
        if type(k) ~= "number" then return "ERROR" end
        -- DONT ALLOW READING PIN 0 (RUN)
        if k == 0 then return "ERROR" end
        return t.node.outputs[k].o_val
    end,
    __newindex = function(t, k, v)
        -- DONT ALLOW WRITING PIN 0 (RUN)
        if k == 0 then return "ERROR" end
        t.node.outputs[k].o_val = v
    end,
})

local code_vars = {
    input = inputAccessor,
    output = outputAccessor,
    math = math,
    utf8 = utf8,
    string = string,
    table = table,
    os = os,
    pairs = pairs,
    ipairs = ipairs,
    tostring = tostring,
    tonumber = tonumber,
    type = type,
    next = next,
    select = select,
    print = r.ShowConsoleMsg,
    io = io,
    debug = debug,
    rawget = rawget,
    rawset = rawset,
    getmetatable = getmetatable,
    setmetatable = setmetatable,
    reaper = reaper,
    r = r,
}

local TMP_FUNC = {}

function ResetTmpFunctionsTBL()
    TMP_FUNC = {}
end

function CUSTOM_CodeNodeRun(called_node, func_node)
    local func, err = TMP_FUNC[called_node.guid], nil
    local code_string
    if not func then
        code_string = #called_node.inputs[1].connection ~= 0 and called_node.inputs[1].o_val or
            called_node.inputs[1].i_val
    end

    rawset(inputAccessor, 'node', called_node)
    rawset(outputAccessor, 'node', called_node)

    if not func then
        func, err = load(code_string, called_node.guid, "t", code_vars)
        if func then
            local pass, err_msg = pcall(func)
            if not pass then
                called_node.missing_arg = { err_msg:gsub("%[(.-)%]", "LINE") }
                return "ERROR2"
            end
            TMP_FUNC[called_node.guid] = func
        else
            called_node.missing_arg = { err }
            return "ERROR2"
        end
    else
        local pass, err_msg = pcall(func)
        if not pass then
            called_node.missing_arg = { err_msg:gsub("%[(.-)%]", "LINE") }
            return "ERROR2"
        end
    end
    -- local func, err = load(code_string, called_node.guid, "t", code_vars)
    -- if func then
    --     local pass, err_msg = pcall(func)
    --     if not pass then
    --         called_node.missing_arg = { err_msg:gsub("%[(.-)%]", "LINE") }
    --         return "ERROR2"
    --     end
    -- else
    --     called_node.missing_arg = { err }

    --     return "ERROR2"
    -- end
end

function CUSTOM_StringCompare(called_node, func_node, str1, str2)
    if not str1 then return "ERROR" end
    if not str2 then return "ERROR" end
    if str1 == str2 then
        called_node.outputs[1].o_val = true
    else
        called_node.outputs[1].o_val = false
    end
end
