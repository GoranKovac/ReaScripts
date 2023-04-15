--@noindex
--NoIndex: true

local random, huge, pi, abs, cos, acos, sin, asin, atan, ceil, floor, deg, exp, log, modf, rad, sqrt, randomseed, fmod, min, max, mtype =
    math.random, math.huge, math.pi, math.abs, math.cos, math.acos, math.sin, math.asin, math.atan, math.ceil,
    math.floor, math.deg, math.exp, math.log, math.modf, math.rad, math.sqrt, math.randomseed, math.fmod, math.min,
    math.max, math.type

-- local Math2 = {
--     ['==']         = function(self) return self[1].i_val == self[3].i_val end,
--     ['~=']         = function(self) return self[1].i_val ~= self[3].i_val end,
--     ['>']          = function(self) return self[1].i_val > self[3].i_val end,
--     ['>=']         = function(self) return self[1].i_val >= self[3].i_val end,
--     ['<']          = function(self) return self[1].i_val < self[3].i_val end,
--     ['<=']         = function(self) return self[1].i_val <= self[3].i_val end,
--     ["+"]          = function(self) return self[1].i_val + self[3].i_val end,
--     ["-"]          = function(self) return self[1].i_val - self[3].i_val end,
--     ["*"]          = function(self) return self[1].i_val * self[3].i_val end,
--     ["/"]          = function(self)
--         if self[1].i_val == 0 or self[3].i_val == 0 then return 0 end
--         return self[1].i_val / self[3].i_val
--     end,
--     ["%"]          = function(self) return self[1].i_val % self[3].i_val end,
--     ["^"]          = function(self) return self[1].i_val ^ self[3].i_val end,
--     ["random"]     = function() return random() end,
--     ["huge"]       = function() return huge end,
--     ["pi"]         = function() return pi end,
--     ["abs"]        = function(self) return abs(self[1].i_val) end,
--     ["cos"]        = function(self) return cos(self[1].i_val) end,
--     ["acos"]       = function(self) return acos(self[1].i_val) end,
--     ["sin"]        = function(self) return sin(self[1].i_val) end,
--     ["asin"]       = function(self) return asin(self[1].i_val) end,
--     ["atan"]       = function(self) return atan(self[1].i_val) end,
--     ["ceil"]       = function(self) return ceil(self[1].i_val) end,
--     ["floor"]      = function(self) return floor(self[1].i_val) end,
--     ["deg"]        = function(self) return deg(self[1].i_val) end,
--     ["exp"]        = function(self) return exp(self[1].i_val) end,
--     ["log"]        = function(self) return log(self[1].i_val) end,
--     ["modf"]       = function(self) return modf(self[1].i_val) end,
--     ["rad"]        = function(self) return rad(self[1].i_val) end,
--     ["sqrt"]       = function(self) return sqrt(self[1].i_val) end,
--     ["randomseed"] = function(self) return randomseed(self[1].i_val) end,
--     ["randomS"]    = function(self) return random(self[1].i_val) end,
--     ["randomM"]    = function(self) return random(self[1].i_val, self[3].i_val) end,
--     ["fmod"]       = function(self) return fmod(self[1].i_val, self[3].i_val) end,
--     ["max"]        = function(self) return max(self[1].i_val, self[3].i_val) end,
--     ["min"]        = function(self) return min(self[1].i_val, self[3].i_val) end,
--     ["pow"]        = function(self) return self[1].i_val ^ self[3].i_val end,
--     ["mathtype"]   = function(self) return mtype(self[1].i_val) end,
--     ["IntToFloat"] = function(self) return self[1].i_val + .0 end,
--     ["FloatToInt"] = function(self) return floor(self[1].i_val) end,
-- }

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
    -- THESE TYPES ARE EXPENSIVE TO DO ON EVERY CALL SO THEY ARE INDEPENDAT FUNCTIONS WITH RUN PINS TO ONLY RUN WHEN CALLED
    --['type']     = function(x) return type(x) end,
    --['tonumber'] = function(x) return tonumber(x) end,
    --['tostring'] = function(x) return tostring(x) end,
    -- ["concat"]   = function(x, y)
    --     x = x or ""
    --     y = y or ""
    --     return tostring(x) .. tostring(y)
    -- end,

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
function CheckCurrentInput2(node_inp)
    local a, b = 0, 0
    if node_inp[1] then
        if #node_inp[1].connection == 0 then
            a = node_inp[1].i_val
        else
            -- IN CASE VALUE IS NIL (CONNECTED TO API NODE) RETURN 0 SO LIVE CALCULATING WONT CRASH (API IS CALCULATED AFTER RUNNING)
            a = node_inp[1].o_val or 0
        end
    end
    if node_inp[3] then
        if #node_inp[3].connection == 0 then
            b = node_inp[3].i_val
        else
            -- IN CASE VALUE IS NIL (CONNECTED TO API NODE) RETURN 0 SO LIVE CALCULATING WONT CRASH (API IS CALCULATED AFTER RUNNING)
            b = node_inp[3].o_val or 0
        end
        return a, b
    end
    return a
end

-- function CheckCurrentInput(node_inp)
--     local a = node_inp[1] and node_inp[1].o_val or node_inp[1].i_val
--     if node_inp[3] then
--         local b = node_inp[3].o_val and node_inp[3].o_val or node_inp[3].i_val
--         return a, b
--     end
--     return a
-- end

-- function DoMath(op, node)
--     --local a, b = CheckCurrentInput(node.inputs)
--     return Math2[op](node.inputs)
-- end

function DoMath(op, node)
    local a, b = CheckCurrentInput2(node.inputs)
    return Math[op](a, b)
end

function DoStd(op, node)
    local a, b = CheckCurrentInput2(node.inputs)
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
    for k, v in ipairs(tbl) do
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

    --local a = called_node.inputs[1].o_val ~= nil and called_node.inputs[1].o_val or called_node.inputs[1].i_val
    --local b = called_node.inputs[2].o_val ~= nil and called_node.inputs[2].o_val or called_node.inputs[2].i_val

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
    if DEFER then
        DEFERED_NODE = called_node
    end
end

function CUSTOM_TestDeferEND(called_node, func_node)
    if DEFER then
        DEFER = false
        START_FLOW = false
        DEFERED_NODE = nil
    end
end

function CUSTOM_Set(called_node)
    called_node.outputs[1].o_val = called_node.inputs[1].o_val -- PASSTHRU VALUE TO OUTPUT
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
        called_node.outputs[1].o_val[#called_node.outputs[1].o_val + 1] = called_node.inputs[i].o_val
    end
end

function CUSTOM_TableGetVal(called_node, func_node, tbl, key)
    if not tbl then return "ERROR" end
    if not tbl[key] then return "ERROR" end
    called_node.outputs[1].o_val = tbl[key]
end

function CUSTOM_TableSetVal(called_node, func_node, tbl, key, val)
    if not tbl then return "ERROR" end
    if not tbl[key] then return "ERROR" end
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
    called_node.outputs[1].o_val = PATH --debug.getinfo(1).source:match("@?(.*[\\|/])")
end

function CUSTOM_GetOsNativeSeparator(called_node, func_node)
    called_node.outputs[1].o_val = NATIVE_SEPARATOR --debug.getinfo(1).source:match("@?(.*[\\|/])")
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
