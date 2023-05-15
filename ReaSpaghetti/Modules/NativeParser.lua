local r = reaper

local math_string = [[
local random, huge, pi, abs, cos, acos, sin, asin, atan, tan, ceil, floor, deg, exp, log, modf, rad, sqrt, randomseed, fmod, min, max, mtype =
math.random, math.huge, math.pi, math.abs, math.cos, math.acos, math.sin, math.asin, math.atan, math.tan, math.ceil,
math.floor, math.deg, math.exp, math.log, math.modf, math.rad, math.sqrt, math.randomseed, math.fmod, math.min,
math.max, math.type
]]

local math_code_str = {
    ['==']         = '%s == %s\n',
    ['~=']         = '%s ~= %s\n',
    ['>']          = '%s > %s\n',
    ['>=']         = '%s >= %s\n',
    ['<']          = '%s < %s\n',
    ['<=']         = '%s <= %s\n',
    ["+"]          = '%s + %s\n',
    ["-"]          = '%s - %s\n',
    ["*"]          = '%s * %s\n',
    ["%"]          = '%s %% %s\n',
    ["/"]          = '%s / %s\n',
    ["//"]         = '%s // %s\n',
    ["random"]     = 'random()\n',
    ["randomS"]    = 'random(abs(%s))\n',
    ["randomM"]    = 'random(abs(%s), abs(%s))\n',
    ["huge"]       = 'huge()\n',
    ["pi"]         = 'pi()\n',
    ["abs"]        = 'abs(%s)\n',
    ["cos"]        = 'cos(%s)\n',
    ["acos"]       = 'acos(%s)\n',
    ["sin"]        = 'sin(%s)\n',
    ["asin"]       = 'asin(%s)\n',
    ["atan"]       = 'atan(%s)\n',
    ["tan"]        = 'tan(%s)\n',
    ["ceil"]       = 'ceil(%s)\n',
    --["floor"]      = 'math.floor(%s)\n',
    ["floor"]      = '(%s // 1)\n',
    ["deg"]        = 'deg(%s)\n',
    ["exp"]        = 'exp(%s)\n',
    ["log"]        = 'log(%s)\n',
    ["modf"]       = 'modf(%s)\n',
    ["rad"]        = 'rad(%s)\n',
    ["sqrt"]       = 'sqrt(%s)\n',
    ["randomseed"] = 'randomseed(%s)\n',
    ["fmod"]       = 'fmod(%s, %s)\n',
    ["max"]        = 'max(%s, %s)\n',
    ["min"]        = 'min(%s, %s)\n',
    ["pow"]        = '%s ^ %s\n',
    ["IntToFloat"] = '%s + .0\n',
    --["FloatToInt"] = 'math.floor(%s)\n',
    ["FloatToInt"] = '(%s // 1)\n',
}

local lua_type = {
    -- LOOPS
    ["CUSTOM_ForLoop"]              = function(a, b, c, d) return ('for IDX%s = %s, %s, %s do\n'):format(a, b, d, c) end,
    ["CUSTOM_Pairs"]                = function(a, b, c) return ('for KEY%s, VALUE%s in pairs(%s) do\n'):format(a, a, b) end,
    ["CUSTOM_Ipairs"]               = function(a, b, c) return ('for KEY%s, VALUE%s in ipairs(%s) do\n'):format(a, a, b) end,
    -- IFELSE
    ["CUSTOM_IF_Else"]              = function(a, b) return ('if %s == %s then\n'):format(a, b) end,
    -- TABLE
    ["TableInsert"]                 = function(name, a, b) return ('table.insert(%s, %s)\n'):format(a, b) end,
    ["TableInsertFast"]             = function(name, a, b) return ('%s[#%s + 1] = %s\n'):format(a, a, b) end,
    ["TableRemove"]                 = function(name, a, b) return ('table.remove(%s, %s)\n'):format(a, b) end,
    ["CUSTOM_TableConcat"]          = function(name, a, b) return ('%s = table.concat(%s, %s)\n'):format(name, a, b) end,
    ["CUSTOM_TableLenght"]          = function(name, a) return ('%s = #%s\n'):format(name, a) end,
    ["CUSTOM_TableGetVal"]          = function(name, a, b, c) return ('%s = %s[%s]\n'):format(name, a, b, c) end,
    ["CUSTOM_TableSetVal"]          = function(name, a, b, c) return ('%s[%s] = %s\n'):format(a, b, c, name) end,
    -- STD
    ["CUSTOM_Concat"]               = function(name, a, b) return ('%s = %s .. %s\n'):format(name, a, b) end,
    ["CUSTOM_ToString"]             = function(name, a) return ('%s = tostring(%s)\n'):format(name, a) end,
    ["CUSTOM_GetScriptPath"]        = function() return ('%q'):format(PATH) .. '\n' end,
    ["CUSTOM_GetOsNativeSeparator"] = function() return ('%q'):format(NATIVE_SEPARATOR) .. '\n' end
}

local CODE_STR = {}

local function IsLocal(n)
    if EXPORT then
        return (n == 0 or n == 1) and 'local ' or ''
    else
        return ''
    end
    -- return (n == 0 or n == 1) and 'local ' or ''
end

local function IdenLVL(n)
    return n and string.rep('\x20', n * 4) or ""
end

local function AddCode(c_str)
    CODE_STR[#CODE_STR + 1] = c_str
end

local function Comment(ident, node_tbl)
    if node_tbl.text and #node_tbl.text ~= 0 then
        CODE_STR[#CODE_STR + 1] = IdenLVL(ident) .. "-- " .. node_tbl.text:upper() .. '\n'
    end
end

local function NodeIDX(node_guid)
    local node, f_idx, n_idx = GetNodeInfo(node_guid)
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)
    local node_label = node.label:gsub("%s+", "") .. node_idx .. '_out%d'
    return node, node_idx, node_label
end

local function IsLoop(node)
    if node.fname == "CUSTOM_ForLoop" or node.fname == "CUSTOM_Ipairs" or node.fname == "CUSTOM_Pairs" or node.fname == "CUSTOM_Fastpairs" then
        return true
    end
end

local function TraceSrcNode(data)
    local src_node, f_id, n_id = GetNodeInfo(data.node)
    local src_node_idx = { ("_F%dN%d"):format(f_id, n_id) }
    local src_pin = data.pin

    local not_src = (src_node.get or src_node.set) and true
    while not_src == true do
        local src_guid = src_node.get and src_node.get or src_node.set.guid
        src_pin = src_node.set and src_node.set.pin or src_pin

        src_node, f_id, n_id = GetNodeInfo(src_guid)
        src_node_idx[1] = ("_F%dN%d"):format(f_id, n_id)

        not_src = (src_node.get or src_node.set) and true
    end

    local node_label = src_node.label:gsub("%s+", "")
    local out_label = src_node.outputs[src_pin].label:gsub("%s+", "")

    if IsLoop(src_node) then
        return src_node, src_node_idx[1], out_label .. src_node_idx[1]
    elseif src_node.type == "m" then
        return src_node, src_node_idx[1], out_label
    elseif src_node.type == "func" then
        return src_node, src_node_idx[1], out_label .. src_node_idx[1] .. ('_out%d'):format(src_pin)
    else
        return src_node, src_node_idx[1], node_label .. src_node_idx[1] .. ('_out%d'):format(src_pin)
    end
end

local function HasVal(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then
            --reaper.ShowConsoleMsg("found\n")
            return true
        end
    end
end

local function RemoveDuplicates(tbl)
    -- local seen = {}
    -- local rem = {}
    -- for index, item in ipairs(tbl) do
    --     if seen[item] then
    --         rem[#rem + 1] = index
    --     else
    --         seen[item] = true
    --     end
    -- end
    -- for i = #rem, 1, -1 do
    --     table.remove(tbl, rem[i])
    -- end
    local math_filter = {}

    for i = 1, #tbl do
        if not HasVal(math_filter, tbl[i]) then
            math_filter[#math_filter + 1] = tbl[i]
        end
    end
    return math_filter
end

local function TraceMath(node, node_idx, tbl, ident)
    if node.fname and node.fname:lower():find("math") then
        local tmp_str = {}
        local val_1, val_2
        local trace_1, trace_2
        if node.inputs[1] then
            if #node.inputs[1].connection == 0 then
                val_1 = node.inputs[1].i_val
            else
                local inp1, inp1_idx, out_name = TraceSrcNode(node.inputs[1].connection[1])
                trace_1 = { inp1, inp1_idx, out_name }
            end
        end
        if node.inputs[3] then
            if #node.inputs[3].connection == 0 then
                val_2 = node.inputs[3].i_val
            else
                local inp2, inp2_idx, out_name = TraceSrcNode(node.inputs[3].connection[1])
                trace_2 = { inp2, inp2_idx, out_name }
            end
        end

        tmp_str[1] =
            math_code_str[node.inputs[2].i_val]:format(
                val_1 and tostring(val_1) or (trace_1 and trace_1[3]:gsub("[()]", "") or ""),
                val_2 and tostring(val_2) or (trace_2 and trace_2[3]:gsub("[()]", "") or "")
            )

        table.insert(tbl, 1,
            IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") .. node_idx .. '_out1' .. " = " .. tmp_str[1])
        if trace_1 then
            TraceMath(trace_1[1], trace_1[2], tbl, ident)
        end
        if trace_2 then
            TraceMath(trace_2[1], trace_2[2], tbl, ident)
        end
    end
end

local function MakeMathFlow(node, ident)
    local math_code = {}
    for i = 1, #node.inputs do
        if #node.inputs[i].connection ~= 0 then
            local prev_node, f_idx, n_idx = GetNodeInfo(node.inputs[i].connection[1].node)
            local prev_node_idx = ("_F%dN%d"):format(f_idx, n_idx)

            TraceMath(prev_node, prev_node_idx, math_code, ident)

            --RemoveDuplicates(math_code)
            --AddCode(table.concat(math_code))
        end
    end

    if #math_code ~= 0 then
        local math_filter = RemoveDuplicates(math_code)
        --reaper.ShowConsoleMsg(table.concat(math_filter))
        --reaper.ShowConsoleMsg('\n CLEAR \n')
        AddCode(table.concat(math_filter))
    end
end

function ValueReferences(inputs, return_val)
    local vars = {}
    local arg_val = {}
    for i = 1, #inputs do
        if not return_val then
            if i > 1 then AddCode(', ') end
        end

        -- NOT CONNECTED TO ANY NODE, GET RAW VALUE
        if #inputs[i].connection == 0 then
            arg_val[1] = type(inputs[i].i_val) == "string" and ('%q'):format(inputs[i].i_val) or inputs[i].i_val
        else
            -- CONNECTED TO OTHER NODE, GET REFERENCE NODE
            local src_node, idx, out_v = TraceSrcNode(inputs[i].connection[1])
            arg_val[1]                 = out_v
        end

        vars[#vars + 1] = arg_val[1]
        if not return_val then AddCode(tostring(arg_val[1])) end
    end
    return return_val and vars
end

function AddVars(nodes, func_idx, ident)
    for n = 1, #nodes do
        local node = nodes[n]
        local node_idx = ("_F%dN%d"):format(func_idx, n)
        local label = { IdenLVL(ident) .. IsLocal(ident) .. node.label:gsub("%s+", "") .. node_idx .. '_out1' .. ' = ' }
        --local label = { IdenLVL(ident) .. node.label:gsub("%s+", "") .. node_idx .. '_out1' .. ' = ' }

        if node.type == "s" then
            if node.outputs[1].connection ~= 0 then
                local next_node = GetNodeInfo(node.outputs[1].connection[1].node)
                if next_node.type ~= "code" then
                    Comment(ident, node)
                    AddCode(label[1] .. ('%q'):format(node.outputs[1].i_val) .. "\n")
                end
            else
                Comment(ident, node)
                AddCode(label[1] .. ('%q'):format(node.outputs[1].i_val) .. "\n")
            end
        elseif node.type == "i" then
            Comment(ident, node)
            AddCode(label[1] .. node.outputs[1].i_val .. "\n")
        elseif node.type == "f" then
            Comment(ident, node)
            AddCode(label[1] .. node.outputs[1].i_val .. "\n")
        elseif node.type == "b" then
            Comment(ident, node)
            AddCode(label[1] .. tostring(node.outputs[1].i_val) .. "\n")
        elseif node.type == "t" then
            Comment(ident, node)
            AddCode(label[1] .. tostring('{}') .. "\n")
        end
    end
end

local function AddFunc(node, index)
    -- SKIP INIT FUNCTION
    if index < 2 then return end
    local func_code = {}
    AddCode('\nfunction ' .. node.label:gsub("%s+", "") .. '(')
    for i = 1, #node.inputs do
        if i > 1 then AddCode(', ') end
        AddCode(node.inputs[i].label:gsub("%s+", ""))
    end
    AddCode(')\n')
end

local function CloseFunc(index)
    if index < 2 then return end
    AddCode('end\n')
end

function NT_CALL(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx, var_name = NodeIDX(node_tbl.guid)
    AddCode(IdenLVL(ident))

    local is_local = IsLocal(ident)
    -- IF API DOES NOT RETURN ANY VALUE DO NOT ADD LOCAL
    if #node_tbl.outputs > 0 then AddCode(is_local) end

    for out_i = 1, #node.outputs do
        if out_i > 1 then AddCode(', ') end
        AddCode(var_name:format(out_i))
    end

    if #node.outputs > 0 then AddCode(' = ') end

    if node.sp_api then
        AddCode(node.sp_api .. '.' .. node.fname .. '(')
    else
        AddCode('r.' .. node.fname .. '(')
    end
    ValueReferences(node_tbl.inputs)
    AddCode(')\n')
end

function NT_TABLE(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)
    local node, node_idx, var_name = NodeIDX(node_tbl.guid)

    var_name = var_name:format(1)

    --local is_local = IsLocal(ident)

    local vals = ValueReferences(node_tbl.inputs, true)
    AddCode(IdenLVL(ident) .. lua_type[node_tbl.fname](var_name, table.unpack(vals)))
end

function NT_TABLE_C(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx, var_name = NodeIDX(node_tbl.guid)
    var_name = var_name:format(1)

    local is_local = IsLocal(ident)

    AddCode(IdenLVL(ident) .. is_local .. var_name .. ' = ' .. tostring('{'))

    for i = 1, #node.inputs do
        if i > 1 then AddCode(', ') end
        if node.inputs[i].to_key then
            local label = node.inputs[i].label:gsub("%s+", "") .. ' = '
            AddCode(label)
        end
        ValueReferences({ node.inputs[i] })
    end

    AddCode('}\n')
end

function NT_FORLOOP(node_tbl, func_idx, ident)
    Comment(ident, node_tbl)

    local node, node_idx = NodeIDX(node_tbl.guid)

    local start_or_key, inc_or_value, end_or_table, sub1 =
        ValueReferences({ node_tbl.inputs[1] }, true)[1],
        ValueReferences({ node_tbl.inputs[2] }, true)[1],
        ValueReferences({ node_tbl.inputs[3] }, true)[1],
        node_tbl.inputs[4] and (node_tbl.inputs[4].i_val == true and 1 or nil) -- ONLY PRESENT IN NORMAL FOR LOOP

    if sub1 then
        start_or_key = type(start_or_key) == "string" and start_or_key .. tostring(" - 1") or start_or_key - sub1
        end_or_table = type(end_or_table) == "string" and end_or_table .. tostring(" - 1") or end_or_table - sub1
    end

    AddCode(IdenLVL(ident) .. lua_type[node.fname](node_idx, start_or_key, inc_or_value, end_or_table))

    local child_flow = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))

    CodeGen(child_flow, func_idx, ident + 1)

    AddCode(IdenLVL(ident) .. 'end\n')
end

function NT_IFELSE(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx = NodeIDX(node_tbl.guid)

    -- RESET DISABLE BOTH OUTPUTS ON START
    node.outputs[1].run = false
    node.outputs[2].run = false

    local cond_1 = ValueReferences({ node.inputs[1] }, true)[1]
    local cond_2 = ValueReferences({ node.inputs[2] }, true)[1]

    AddCode(IdenLVL(ident) .. lua_type[node.fname](cond_1, cond_2))
    -- TURN ON LOOP OUT 1 FOR CHILD FLOW
    node.outputs[1].run = true
    local child_flow_t = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    node.outputs[1].run = false
    CodeGen(child_flow_t, func_idx, ident + 1)

    ---ELSE
    node.outputs[2].run = true
    local child_flow_f = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    node.outputs[2].run = false

    if #child_flow_f ~= 0 then
        -- ADD ELSE ONLY IF FALSE CHILD FLOW EXIST
        AddCode(IdenLVL(ident) .. 'else\n')
        CodeGen(child_flow_f, func_idx, ident + 1)
    end
    AddCode(IdenLVL(ident) .. 'end\n\n')
end

function NT_IFELSE_M(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx = NodeIDX(node_tbl.guid)

    AddCode(IdenLVL(ident) .. 'if ')

    local vals = ValueReferences(node_tbl.inputs, true)

    -- i == 1 IS CONDITION FLAG
    for i = 2, #vals do
        if i > 2 then AddCode(' and ') end
        AddCode(tostring(vals[i]) .. ' == ' .. tostring(vals[1]))
    end

    AddCode(' then\n')

    -- RESET DISABLE BOTH OUTPUTS ON START
    node.outputs[1].run = false
    node.outputs[2].run = false


    node.outputs[1].run = true
    local child_flow_t = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    node.outputs[1].run = false
    CodeGen(child_flow_t, func_idx, ident + 1)

    ---ELSE
    node.outputs[2].run = true
    local child_flow_f = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    node.outputs[2].run = false

    if #child_flow_f ~= 0 then
        -- ADD ELSE ONLY IF FALSE CHILD FLOW EXIST
        AddCode(IdenLVL(ident) .. 'else\n')
        CodeGen(child_flow_f, func_idx, ident + 1)
    end
    AddCode(IdenLVL(ident) .. 'end\n\n')
end

function NT_STD(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx, var_name = NodeIDX(node_tbl.guid)

    local is_local = IsLocal(ident)

    var_name = var_name:format(1)

    local vals = ValueReferences(node_tbl.inputs, true)

    AddCode(IdenLVL(ident) .. is_local .. lua_type[node.fname](var_name, table.unpack(vals)))
end

function NT_SET(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)
    if #node_tbl.inputs[1].connection == 0 then return end

    local node, node_idx, var_name = NodeIDX(node_tbl.set.guid)
    var_name = var_name:format(1)

    AddCode(IdenLVL(ident) .. var_name .. ' = ')
    ValueReferences(node_tbl.inputs)
    AddCode('\n')
end

local InitFuncCalls = {}
function NT_FUNC(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local func_code = {}

    local node, node_idx = NodeIDX(node_tbl.guid)

    func_code[#func_code + 1] = IdenLVL(ident)
    --AddCode(IdenLVL(ident))

    for out_i = 1, #node.outputs do
        local label = (node.outputs[out_i].label:gsub("%s+", "") .. node_idx .. "_out%d"):format(out_i)
        if out_i > 1 then
            func_code[#func_code + 1] = ', '
            --AddCode(', ')
        end
        func_code[#func_code + 1] = label
        --AddCode(label)
    end
    if #node.outputs > 0 then
        func_code[#func_code + 1] = ' = '
        --AddCode(' = ')
    end
    func_code[#func_code + 1] = node.label:gsub("%s+", "") .. '('
    --AddCode(node.label:gsub("%s+", "") .. '(')
    --ValueReferences(node_tbl.inputs)
    local vals = ValueReferences(node_tbl.inputs, true)

    for i = 1, #vals do
        if i > 1 then func_code[#func_code + 1] = ', ' end
        func_code[#func_code + 1] = vals[i]
    end
    --func_code[#func_code + 1] = --ValueReferences(node_tbl.inputs, true)

    func_code[#func_code + 1] = ')\n'
    --AddCode(')\n')

    if ident ~= 0 then
        AddCode(table.concat(func_code))
    else
        InitFuncCalls[#InitFuncCalls + 1] = func_code
    end
end

function NT_FUNC_RET(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    AddCode(IdenLVL(ident) .. 'return ')
    ValueReferences(node_tbl.inputs)
    AddCode('\n')
end

-- local code_vars = [[
--     input = {},
--     output = {},
--     math = math,
--     utf8 = utf8,
--     string = string,
--     table = table,
--     os = os,
--     pairs = pairs,
--     ipairs = ipairs,
--     tostring = tostring,
--     tonumber = tonumber,
--     type = type,
--     next = next,
--     select = select,
--     print = r.ShowConsoleMsg,
--     io = io,
--     debug = debug,
--     rawget = rawget,
--     rawset = rawset,
--     getmetatable = getmetatable,
--     setmetatable = setmetatable,
--     ]]

function NT_CODE(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx, var_name = NodeIDX(node_tbl.guid)
    local func_name = node.label .. node_idx

    local str_src = TraceSrcNode(node_tbl.inputs[1].connection[1])
    local c_string = str_src.outputs[1].i_val
    local load_code = {}

    load_code[#load_code + 1] = '\nlocal function ' .. func_name .. '('
    for i = 2, #node_tbl.inputs do
        if i > 2 then load_code[#load_code + 1] = ', ' end
        load_code[#load_code + 1] = 'input' .. i - 1
    end
    load_code[#load_code + 1] = ')\n'
    load_code[#load_code + 1] = IdenLVL(ident - 1) .. 'local '
    for i = 1, #node_tbl.outputs do
        if i > 1 then load_code[#load_code + 1] = ', ' end
        load_code[#load_code + 1] = 'output' .. i
        if i == #node_tbl.outputs then load_code[#load_code + 1] = '\n' end
    end

    load_code[#load_code + 1] = IdenLVL(ident - 1) .. c_string:gsub('\n', '\n' .. IdenLVL(ident - 1)) ..
        '\n' .. IdenLVL(ident - 1) .. 'return '

    for i = 1, #node_tbl.outputs do
        if i > 1 then load_code[#load_code + 1] = ', ' end
        load_code[#load_code + 1] = 'output' .. i
        if i == #node_tbl.outputs then load_code[#load_code + 1] = '\nend\n' end
    end

    table.insert(CODE_STR, 3, table.concat(load_code))
    AddCode(IdenLVL(ident) .. 'local ')
    for out_i = 1, #node.outputs do
        local label = (func_name:gsub("%s+", "") .. "_out%d"):format(out_i)
        if out_i > 1 then AddCode(', ') end
        AddCode(label)
    end
    if #node.outputs > 0 then AddCode(' = ') end

    AddCode(func_name:gsub("%s+", "") .. '(')
    local inputs = Deepcopy(node_tbl.inputs)
    table.remove(inputs, 1)
    ValueReferences(inputs)
    AddCode(')\n')
end

-- function NT_CODE2(node_tbl, func_idx, ident)
--     MakeMathFlow(node_tbl, ident)
--     Comment(ident, node_tbl)

--     local node, node_idx, var_name = NodeIDX(node_tbl.guid)
--     local func_name = node.label .. node_idx
--     local code_string = ValueReferences({ node_tbl.inputs[1] }, true)[1]
--     local load_code = {}

--     -- VARS
--     load_code[#load_code + 1] = '\n' .. 'local ' .. func_name .. '_vars = {\n' .. code_vars .. '}\n'

--     -- AddCode('\n' .. IdenLVL(ident) .. func_name .. '_vars = {\n')
--     -- AddCode(code_vars)
--     -- AddCode('}\n')

--     -- PREPARE INPUTS
--     local vals = ValueReferences(node_tbl.inputs, true)
--     table.remove(vals, 1) -- REMOVE CODE INPUT

--     for i = 1, #vals do
--         AddCode(IdenLVL(ident) .. func_name .. '_vars.input[' .. i .. '] = ' .. vals[i] .. '\n')
--     end

--     local str_src = TraceSrcNode(node_tbl.inputs[1].connection[1])
--     local c_string = str_src.outputs[1].i_val

--     load_code[#load_code + 1] = 'local ' .. code_string .. ' = ' .. ('%q'):format(c_string)

--     load_code[#load_code + 1] =
--         '\n' .. 'local ' ..
--         func_name .. '_func = ' ..
--         'load(' ..
--         code_string .. ', ' .. ('%q'):format('node' .. node_idx) ..
--         ', ' .. '"t"' .. ', ' .. func_name .. '_vars' .. ')\n'
--     -- LOAD

--     -- AddCode('\n' .. IdenLVL(ident) ..
--     --     func_name .. '_func = ' ..
--     --     'load(' ..
--     --     code_string .. ', ' .. ('%q'):format('node' .. node_idx) ..
--     --     ', ' .. '"t"' .. ', ' .. func_name .. '_vars' .. ')\n')

--     table.insert(CODE_STR, 2, table.concat(load_code))

--     AddCode('\n' .. IdenLVL(ident) .. func_name .. '_func()\n')

--     for i = 1, #node_tbl.outputs do
--         AddCode(IdenLVL(ident) .. var_name:format(i) .. ' = ' .. func_name .. '_vars.output[' .. i .. ']\n')
--     end
-- end

function NT_SWITCH(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx = NodeIDX(node_tbl.guid)

    --AddCode(IdenLVL(ident) .. 'if ')

    --local vals = ValueReferences(node_tbl.inputs, true)

    for i = 1, #node_tbl.outputs do
        node_tbl.outputs[i].run = false
    end

    for i = 1, #node_tbl.inputs do
        AddCode(IdenLVL(ident))
        if i > 1 then AddCode('else') end
        local inp_condition = ValueReferences({ node_tbl.inputs[i] }, true)[1] or tostring(true)
        AddCode('if ' .. inp_condition .. ' then\n')

        node_tbl.outputs[i + 1].run = true
        local child_flow_t = GetChildFlowNATIVE(node_tbl, GetFunctionNodes(node_tbl.guid))
        node_tbl.outputs[i + 1].run = false
        CodeGen(child_flow_t, func_idx, ident + 1)
    end
    AddCode(IdenLVL(ident) .. 'else\n')
    node_tbl.outputs[1].run = true
    local child_flow_t = GetChildFlowNATIVE(node_tbl, GetFunctionNodes(node_tbl.guid))
    node_tbl.outputs[1].run = false
    CodeGen(child_flow_t, func_idx, ident + 1)
    AddCode(IdenLVL(ident) .. 'end\n')
end

function NT_DEFER(node, func_idx, ident)
    AddCode(IdenLVL(ident) .. 'r.defer(Main)\n')
    RUNNING = node
end

function NT_PATH(node_tbl, func_idx, ident)
    --MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx, var_name = NodeIDX(node_tbl.guid)
    var_name = var_name:format(1)

    AddCode(IdenLVL(ident) .. var_name .. ' = ' .. lua_type[node.fname]())
end

local blocks
function CodeGen(nodes, func_idx, ident_lvl)
    for i = 1, #nodes do
        local node = nodes[i]
        if node.compiler then
            _G[node.compiler](node, func_idx, ident_lvl)
            if node.last_node then
                blocks[#blocks + 1] = node.last_node
            end
            if i == blocks[#blocks] then
                AddCode('end')
                table[#blocks] = nil
            end
        end
    end
end

function NativeExport2()
    local path = PATH .. "ExportedActions/ReaSpaghetti_StandAlone_" .. PROJECT_NAME:gsub(".reanodes", "") .. ".lua"
    local gen_code = "-- CODE GENERATED BY ReaSpaghetti\n\n"
    local gen_desc =
    "-- SUFIX : FxNx \n-- F = FUNCTION ID (FUNCTION WHERE NODE LIVES) \n-- N = NODE ID (NUMBER OF THE NODE IN FUNCTION) \n\n"

    table.insert(CODE_STR, 1, gen_desc)
    table.insert(CODE_STR, 1, gen_code)
    table.insert(CODE_STR, 1, 'NATIVE_SEPARATOR = package.config:sub(1, 1)')

    local file = io.open(path, "w")
    if file then
        file:write(table.concat(CODE_STR))
        file:close()
        local ret = r.AddRemoveReaScript(true, 0, path, 1)
        if ret then
            ADDED_TO_ACTIONS = true
        end
    end
end

MEMORY_FUNC = nil

local fake_reaper = {}
for k, v in pairs(r) do
    fake_reaper[k] = v
end

fake_reaper.defer = function(callback)
    DEFERING = true
    if RUNNING and not CAN_UPDATE then
        r.defer(callback)
    end
end

local script_vars = {
    RELOAD = false,
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
    io = io,
    debug = debug,
    rawget = rawget,
    rawset = rawset,
    getmetatable = getmetatable,
    setmetatable = setmetatable,
    load = load,
    dofile = dofile,
    r = fake_reaper,
    reaper = fake_reaper,
    ultraschall = ULTRA_API and ultraschall

}

function MakeMemoryFunc(str)
    local func, err = load(str, "ScriptRun", "t", script_vars)
    if func then
        --local start_time = r.time_precise()

        local pass, err_msg = pcall(func)
        if not pass then
            RUNNING = nil
            r.ShowConsoleMsg("\nLOAD SCRIPT ERROR\n" .. err_msg)
            return
        end
        --local end_time = r.time_precise()
        -- r.ShowConsoleMsg("\nNATIVE RUN :" .. ('%.4f ms\n'):format((end_time - start_time) * 1000))
    else
        RUNNING = nil
        r.ShowConsoleMsg("\nLOAD FUNCTION COULD NOT BE CREATED:\n" .. err)
        return
    end
end

function GenerateCode2(export)
    EXPORT = export or nil
    CODE_STR, blocks, InitFuncCalls = {}, {}, {}

    local FUNCTIONS = GetFUNCTIONS()

    AddCode('local r = reaper\n')
    AddCode(math_string .. '\n')

    -- if ULTRA_API then
    --     AddCode(
    --         'if not ultraschall then ultraschall = dofile(r.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua") end\n')
    -- end

    if not export then AddCode('\nif not ' .. 'RELOAD' .. ' then\n') end
    AddVars(FUNCTIONS[1].NODES, 1, 0)
    CodeGen(TraceFlow(FUNCTIONS[1].NODES), 1, 0)
    if not export then AddCode('\nend\n') end
    -- SKIP INIT AND CREATE IN REVERSE ORDER TO HAVE LOCAL FUNCTIONS IN ORDER

    for i = #FUNCTIONS, 2, -1 do
        AddFunc(FUNCTIONS[i], i)
        local NODES = FUNCTIONS[i].NODES
        AddVars(NODES, i, 1)
        local FLOW = TraceFlow(NODES)
        CodeGen(FLOW, i, 1)
        CloseFunc(i)
    end

    if #InitFuncCalls ~= 0 then
        for i = 1, #InitFuncCalls do
            AddCode(table.concat(InitFuncCalls[i]))
        end
    end

    if RUNNING then
        AddCode('\nreaper.defer(Main)\n\n')
    else
        AddCode('\nMain()\n\n')
    end

    --if export then r.ShowConsoleMsg(table.concat(CODE_STR)) end
    --r.ShowConsoleMsg(table.concat(CODE_STR))
    if not export then MakeMemoryFunc(table.concat(CODE_STR)) end
end

function LoopNativeCode()
    if CAN_UPDATE then
        script_vars.RELOAD = true
        GenerateCode2()
        script_vars.RELOAD = false
    end
end
