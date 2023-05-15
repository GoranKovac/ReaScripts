--@noindex
--NoIndex: true
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
    ["random"]     = 'math.random()\n',
    ["randomS"]    = 'math.random(abs(%s))\n',
    ["randomM"]    = 'math.random(abs(%s), abs(%s))\n',
    ["huge"]       = 'math.huge()\n',
    ["pi"]         = 'math.pi()\n',
    ["abs"]        = 'math.abs(%s)\n',
    ["cos"]        = 'math.cos(%s)\n',
    ["acos"]       = 'math.acos(%s)\n',
    ["sin"]        = 'math.sin(%s)\n',
    ["asin"]       = 'math.asin(%s)\n',
    ["atan"]       = 'math.atan(%s)\n',
    ["tan"]        = 'math.tan(%s)\n',
    ["ceil"]       = 'math.ceil(%s)\n',
    ["floor"]      = 'math.floor(%s)\n',
    ["deg"]        = 'math.deg(%s)\n',
    ["exp"]        = 'math.exp(%s)\n',
    ["log"]        = 'math.log(%s)\n',
    ["modf"]       = 'math.modf(%s)\n',
    ["rad"]        = 'math.rad(%s)\n',
    ["sqrt"]       = 'math.sqrt(%s)\n',
    ["randomseed"] = 'math.randomseed(%s)\n',
    ["fmod"]       = 'math.fmod(%s, %s)\n',
    ["max"]        = 'math.max(%s, %s)\n',
    ["min"]        = 'math.min(%s, %s)\n',
    ["pow"]        = '%s ^ %s\n',
    ["IntToFloat"] = '%s + .0\n',
    ["FloatToInt"] = 'math.floor(%s)\n',
}

local lua_type = {
    -- LOOPS
    ["CUSTOM_ForLoop"]     = function(a, b, c, d) return ('for IDX%s = %s, %s, %s do\n'):format(a, b, c, d) end,
    ["CUSTOM_Pairs"]       = function(a, b, c) return ('for KEY%s, VALUE%s in pairs(s%)\n'):format(a, b, c) end,
    ["CUSTOM_Ipairs"]      = function(a, b, c) return ('for IDX%s, VALUE%s in ipairs(s%)\n'):format(a, b, c) end,
    -- TABLE
    ["TableInsert"]        = function(a, b) return ('table.insert(%s, %s)\n'):format(a, b) end,
    ["TableInsertFast"]    = function(a, b, c) return ('%s[#%s + 1] = %s\n'):format(a, b, c) end,
    ["TableRemove"]        = function(a, b) return ('table.remove(%s, %s)\n'):format(a, b) end,
    ["CUSTOM_TableConcat"] = function(a, b, c) return ('%s = table.concat(%s, %s)\n'):format(a, b, c) end,
    ["CUSTOM_TableLenght"] = function(a, b) return ('%s = #%s)\n'):format(a, b) end,
    ["CUSTOM_TableGetVal"] = function(a, b, c) return ('%s = %s[%s]\n'):format(a, b, c) end,
    ["CUSTOM_TableSetVal"] = function(a, b, c) return ('%s[%s] = %s\n'):format(a, b, c) end,
}

local CODE_STR = {}

local function IdenLVL(n)
    return n and string.rep('\x20', n * 4) or ""
end

local function AddCode(c_str)
    CODE_STR[#CODE_STR + 1] = c_str
end

local function Comment(ident, node_tbl)
    if node_tbl.text and #node_tbl.text ~= 0 then
        CODE_STR[#CODE_STR + 1] = IdenLVL(ident) .. "-- " .. node_tbl.text .. '\n'
    end
end

local function NodeIDX(node_guid)
    local node, f_idx, n_idx = GetNodeInfo(node_guid)
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)
    return node, node_idx
end

function ValueReferences2(inputs)
    local vars = {}
    for i = 1, #inputs do
        local arg_val
        -- NOT CONNECTED TO ANY NODE, GET RAW VALUE
        if #inputs[i].connection == 0 then
            arg_val = type(inputs[i].i_val) == "string" and '"' .. inputs[i].i_val .. '"' or inputs[i].i_val
        else
            -- CONNECTED TO OTHER NODE, GET REFERENCE NODE
            local src_node, idx, out_v = TraceSrcNode(inputs[i].connection[1])
            arg_val = (out_v:gsub("[()]", ""))
        end
        vars[#vars + 1] = arg_val
    end
    return vars
end

function AddVars2(nodes, func_idx, ident)
    for n = 1, #nodes do
        local node = nodes[n]
        local node_idx = ("_F%dN%d"):format(func_idx, n)
        AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") .. node_idx .. '_out1' .. ' = ')
        if node.type == "s" then
            AddCode('"' .. node.outputs[1].i_val .. '"' .. "\n")
        elseif node.type == "i" then
            AddCode(node.outputs[1].i_val .. "\n")
        elseif node.type == "f" then
            AddCode(node.outputs[1].i_val .. "\n")
        elseif node.type == "b" then
            AddCode(tostring(node.outputs[1].i_val) .. "\n")
        elseif node.type == "t" then
            AddCode(tostring('{}') .. "\n")
        end
    end
end

function NT_TABLE2(node_tbl, func_idx, ident)
    Comment(ident, node_tbl)
    local node, node_idx = NodeIDX(node_tbl.guid)

    local vals = ValueReferences2(node_tbl.inputs)
    AddCode(IdenLVL(ident) .. lua_type[node_tbl.fname](table.unpack(vals)))
end

function NT_FORLOOP2(node_tbl, func_idx, ident)
    Comment(ident, node_tbl)

    local node, node_idx = NodeIDX(node_tbl.guid)

    local start_or_key, inc_or_value, end_or_table, sub1 =
        ValueReferences2({ node_tbl.inputs[1] })[1],
        ValueReferences2({ node_tbl.inputs[2] })[1],
        ValueReferences2({ node_tbl.inputs[3] })[1],
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

local function IsLoop(node, pin)
    if node.fname == "CUSTOM_ForLoop" or node.fname == "CUSTOM_Ipairs" or node.fname == "CUSTOM_Pairs" or node.fname == "CUSTOM_Fastpairs" then
        return true
    end
end

function TraceSrcNode(data)
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

    if IsLoop(src_node, src_pin) then
        return src_node, src_node_idx[1], out_label .. src_node_idx[1]
    elseif src_node.type == "m" then
        return src_node, src_node_idx[1], out_label
    elseif src_node.type == "func" then
        return src_node, src_node_idx[1], out_label .. src_node_idx[1] .. ('_out%d'):format(src_pin)
    else
        return src_node, src_node_idx[1], node_label .. src_node_idx[1] .. ('_out%d'):format(src_pin)
    end
end

-- TRACE SOURCE NODE FROM PIN CONNECTION
local function GetSourceNode(node, inputs)
    local prev_node, p_f_id, p_n_id = GetNodeInfo(inputs.connection[1].node)

    local connection_pin = inputs.connection[1].pin
    local prev_node_idx = ("_F%dN%d"):format(p_f_id, p_n_id)

    if prev_node.type == "get" then
        -- GET NODE RETURNS SETTERS OR VARIABLE SO WE NEED TO TRACE SOURCE OF SETTER
        --local api_var_node = GetNodeInfo(prev_node.get)

        -- NORMAL GETTER
        local src_node, f_id, n_id = GetNodeInfo(prev_node.get)

        if src_node.set then
            -- SOURCE IS SETTER
            connection_pin = src_node.set.pin
            src_node, f_id, n_id = GetNodeInfo(src_node.set.guid)
        end

        local src_node_idx = ("_F%dN%d"):format(f_id, n_id)

        if IsLoop(src_node, connection_pin) then
            -- IF CONNECTED TO LOOP OUTPUT RETURN LOOP PIN LABEL NAME
            return src_node, src_node_idx, src_node.outputs[connection_pin].label:gsub("%s+", "") .. src_node_idx, true
        else
            -- RETURN REFERENCED NODE NAME
            return src_node, src_node_idx,
                src_node.label:gsub("%s+", "") .. src_node_idx .. ('_out%d'):format(connection_pin)
        end
    elseif prev_node.type == "set" then
        local src_node, f_id, n_id = GetNodeInfo(prev_node.set.guid)
        local src_node_idx = ("_F%dN%d"):format(f_id, n_id)
        if IsLoop(src_node, prev_node.set.pin) then
            -- IF CONNECTED TO LOOP OUTPUT RETURN LOOP PIN LABEL NAME
            return src_node, src_node_idx, src_node.outputs[prev_node.set.pin].label:gsub("%s+", "") .. src_node_idx,
                true
        else
            -- RETURN REFERENCED NODE NAME
            return src_node, src_node_idx,
                src_node.label:gsub("%s+", "") .. src_node_idx .. ('_out%d'):format(prev_node.set.pin)
        end
    elseif prev_node.type == "api_var" then
        local src_node, f_id, n_id = GetNodeInfo(prev_node.set.guid)
        local src_node_idx = ("_F%dN%d"):format(f_id, n_id)
        if IsLoop(src_node, prev_node.set.pin) then
            -- IF CONNECTED TO LOOP OUTPUT RETURN LOOP PIN LABEL NAME
            return src_node, src_node_idx, src_node.outputs[prev_node.set.pin].label:gsub("%s+", "") .. src_node_idx,
                true
        else
            -- RETURN REFERENCED NODE NAME
            return src_node, src_node_idx,
                src_node.label:gsub("%s+", "") .. src_node_idx .. ('_out%d'):format(prev_node.set.pin)
        end
    else
        if IsLoop(prev_node, connection_pin) then
            -- IF CONNECTED TO LOOP OUTPUT RETURN LOOP PIN LABEL NAME
            return prev_node, prev_node_idx, prev_node.outputs[connection_pin].label:gsub("%s+", "") .. prev_node_idx,
                true
        else
            if prev_node.type == "m" then
                -- CONNECTED TO FUNCTION START NODE, RETURN START PIN NAME (FUNCTION ARGUMENT)
                return prev_node, nil, prev_node.outputs[connection_pin].label:gsub("%s+", "")
            elseif prev_node.type == "func" then
                -- CONNECTED TO FUNCTION OUTPUT, RETURN OUTPUT PIN NAME (FUNCTION RETURN)
                return prev_node, prev_node_idx,
                    prev_node.outputs[connection_pin].label:gsub("%s+", "") ..
                    prev_node_idx .. ('_out%d'):format(connection_pin)
            else
                -- RETURN REFERENCED NODE NAME
                return prev_node, prev_node_idx,
                    prev_node.label:gsub("%s+", "") .. prev_node_idx .. ('_out%d'):format(connection_pin)
            end
        end
    end
end

function ValueReferences(node, inputs, idx_sub_1, delim)
    for i = 1, #inputs do
        if i > 1 then AddCode(delim and delim or ', ') end

        local arg_val
        -- NOT CONNECTED TO ANY NODE, GET RAW VALUE
        if #inputs[i].connection == 0 then
            arg_val = type(inputs[i].i_val) == "string" and '"' .. inputs[i].i_val .. '"' or inputs[i].i_val
            if idx_sub_1 then
                -- SUBTRACT START, END AND SKIP INCREMENT
                if i < 3 then arg_val = arg_val - 1 end
            end
        else
            -- CONNECTED TO OTHER NODE, GET REFERENCE NODE
            local src_node, idx, out_v, loop = TraceSrcNode(inputs[i].connection[1])

            --local src_node, idx, out_v, loop = GetSourceNode(node, inputs[i])
            arg_val = (out_v:gsub("[()]", "")) -- .. (loop and "" or '_out%d')):format(inputs[i].connection[1].pin)
            if idx_sub_1 then
                -- SUBTRACT START, END AND SKIP INCREMENT
                if i < 3 then arg_val = arg_val .. " - 1" end
            end
        end
        AddCode(tostring(arg_val))
    end
end

local function AddVars(nodes, func_idx, ident)
    for n = 1, #nodes do
        local node = nodes[n]
        local node_idx = ("_F%dN%d"):format(func_idx, n)
        if node.type == "s" then
            AddCode(IdenLVL(ident) ..
                'local ' .. node.label:gsub("%s+", "") ..
                node_idx .. '_out1' .. ' = ' .. '"' .. node.outputs[1].i_val .. '"' .. "\n")
        elseif node.type == "i" then
            AddCode(IdenLVL(ident) ..
                'local ' .. node.label:gsub("%s+", "") .. node_idx .. '_out1' .. ' = ' .. node.outputs[1].i_val .. "\n")
        elseif node.type == "f" then
            AddCode(IdenLVL(ident) ..
                'local ' ..
                node.label:gsub("%s+", ""):gsub("[()]", "") ..
                node_idx .. '_out1' .. ' = ' .. node.outputs[1].i_val .. "\n")
        elseif node.type == "b" then
            AddCode(IdenLVL(ident) ..
                'local ' ..
                node.label:gsub("%s+", "") .. node_idx .. '_out1' .. ' = ' .. tostring(node.outputs[1].i_val) .. "\n")
        elseif node.type == "t" then
            AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") ..
                node_idx .. '_out1' .. ' = ' .. tostring('{}') .. "\n")
        end
    end
end

function AddFunc(node, index)
    -- SKIP INIT FUNCTION
    if index < 2 then return end
    AddCode('\nfunction ' .. node.label:gsub("%s+", "") .. '(')
    for i = 1, #node.inputs do
        if i > 1 then AddCode(', ') end
        AddCode(node.inputs[i].label:gsub("%s+", ""))
    end
    AddCode(')\n')
end

function CloseFunc(index)
    if index < 2 then return end
    -- if RUNNING then
    --     AddCode('\rr.defer(Main)\n')
    -- end
    AddCode('end\n')
end

function NT_TABLE_C(node, func_idx, ident)
    MakeMathFlow(node, ident)

    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)
    AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") ..
        node_idx .. '_out1' .. ' = ' .. tostring('{'))

    for i = 1, #node.inputs do
        if i > 1 then AddCode(', ') end
        if node.inputs[i].to_key then
            AddCode(node.inputs[i].label:gsub("%s+", "") .. ' = ')
        end
        ValueReferences(node, { node.inputs[i] })
    end

    AddCode('}' .. "\n")
end

function NT_PATH(node, func_idx, ident)
    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)
    if node.fname == "CUSTOM_GetScriptPath" then
        AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") ..
            node_idx .. '_out1' .. ' = ' .. ('%q'):format(PATH) .. '\n')
    elseif node.fname == "CUSTOM_GetOsNativeSeparator" then
        AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") ..
            node_idx .. '_out1' .. ' = ' .. ('%q'):format(NATIVE_SEPARATOR) .. '\n')
    end
end

function NT_TABLE(node, func_idx, ident)
    MakeMathFlow(node, ident)

    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)
    if node.fname == "TableInsert" then
        AddCode(IdenLVL(ident) .. 'table.insert(')
        ValueReferences(node, node.inputs)
        AddCode(')\n')
    elseif node.fname == "TableInsertFast" then
        AddCode(IdenLVL(ident))
        ValueReferences(node, { node.inputs[1] })
        AddCode('[#')
        ValueReferences(node, { node.inputs[1] })
        AddCode(' + 1] = ')
        ValueReferences(node, { node.inputs[2] })
        AddCode(')\n')
    elseif node.fname == "TableRemove" then
        AddCode(IdenLVL(ident) .. 'table.remove(')
        ValueReferences(node, node.inputs)
        AddCode(')\n')
    elseif node.fname == "CUSTOM_TableConcat" then
        AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") ..
            node_idx .. '_out1' .. ' = table.concat(')
        ValueReferences(node, node.inputs)
        AddCode(')\n')
    elseif node.fname == "CUSTOM_TableLenght" then
        AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") ..
            node_idx .. '_out1' .. ' = #')
        ValueReferences(node, node.inputs)
        AddCode('\n')
    elseif node.fname == "CUSTOM_TableGetVal" then
        AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") ..
            node_idx .. '_out1' .. ' = ')
        ValueReferences(node, node.inputs, nil, '[')
        AddCode(']\n')
    elseif node.fname == "CUSTOM_TableSetVal" then
        AddCode(IdenLVL(ident))
        ValueReferences(node, { node.inputs[1] })
        AddCode('[')
        ValueReferences(node, { node.inputs[2] })
        AddCode('] = ')
        ValueReferences(node, { node.inputs[3] })
        AddCode('\n')
    end
end

function NT_STD(node, func_idx, ident)
    MakeMathFlow(node, ident)

    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)
    if node.fname == "CUSTOM_Concat" then
        AddCode(IdenLVL(ident) ..
            node.label:gsub("%s+", ""):gsub("[()]", "") .. node_idx .. '_out1' .. ' = ')
        ValueReferences(node, node.inputs, nil, "..")
    elseif node.fname == "CUSTOM_ToString" then
        AddCode(IdenLVL(ident) ..
            node.label:gsub("%s+", ""):gsub("[()]", "") .. node_idx .. '_out1' .. ' = tostring(')
        ValueReferences(node, node.inputs, nil)
        AddCode(')')
    end
    AddCode('\n')
end

function NT_DEFER(node, func_idx, ident)
    --if RUNNING then
    AddCode(IdenLVL(ident) .. 'r.defer(Main)\n')
    --end
    RUNNING = node
end

-- Node Types
function NT_SET(node, func_idx, ident)
    MakeMathFlow(node, ident)
    if #node.inputs[1].connection == 0 then return end
    local src_node, p_f_id, p_n_id = GetNodeInfo(node.set.guid)
    local src_node_idx = ("_F%dN%d"):format(p_f_id, p_n_id)

    --local connection_pin = node.inputs[1].connection[1].pin
    AddCode(IdenLVL(ident) .. src_node.label:gsub("%s+", ""):gsub("[()]", "") .. src_node_idx .. '_out1' .. ' = ')
    ValueReferences(node, node.inputs)
    AddCode('\n')
end

function NT_CALL(node, func_idx, ident)
    MakeMathFlow(node, ident)
    AddCode(IdenLVL(ident))
    -- IF API DOES NOT RETURN ANY VALUE DO NOT ADD LOCAL
    if #node.outputs > 0 then AddCode('local ') end

    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    --local node_idx = '_f_' .. f_idx .. 'n_' .. n_idx
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)

    for out_i = 1, #node.outputs do
        if out_i > 1 then AddCode(', ') end
        AddCode((node.label:gsub("%s+", "") .. node_idx .. '_out%d'):format(out_i))
    end

    if #node.outputs > 0 then AddCode(' = ') end

    if node.sp_api then
        AddCode(node.sp_api .. '.' .. node.fname .. '(')
    else
        AddCode('r.' .. node.fname .. '(')
    end
    ValueReferences(node, node.inputs)
    AddCode(')\n')
end

function NT_FORLOOP(node, func_idx, ident)
    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)

    local inputs = node.inputs
    local idx_sub_1
    if node.fname == "CUSTOM_ForLoop" then
        AddCode('\n' .. IdenLVL(ident) .. 'for IDX' .. node_idx .. ' = ')
        inputs = { node.inputs[1], node.inputs[3], node.inputs[2] }
        idx_sub_1 = node.inputs[4].i_val == true
    elseif node.fname == "CUSTOM_Ipairs" then
        AddCode(IdenLVL(ident) .. 'for KEY' .. node_idx .. ', VALUE' .. node_idx .. ' in ipairs(')
    elseif node.fname == "CUSTOM_Pairs" then
        AddCode(IdenLVL(ident) .. 'for KEY' .. node_idx .. ', VALUE' .. node_idx .. ' in pairs(')
    end

    ValueReferences(node, inputs, idx_sub_1)

    if node.fname == "CUSTOM_Ipairs" or node.fname == "CUSTOM_Pairs" then AddCode(')') end
    AddCode(' do\n')

    local child_flow = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    CodeGen(child_flow, func_idx, ident + 1)
    AddCode(IdenLVL(ident) .. 'end\n\n')
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
                --local inp1, inp1_idx, out_name = GetSourceNode(node, node.inputs[1])
                trace_1 = { inp1, inp1_idx, out_name } --inp1.label:gsub("%s+", "") .. inp1_idx .. '_out1' }

                --local inp1, f1_idx, n1_idx = GetNodeInfo(node.inputs[1].connection[1].node)
                --local inp1_idx = ("_F%dN%d"):format(f1_idx, n1_idx)
                --trace_1 = { inp1, inp1_idx, inp1.label:gsub("%s+", "") .. inp1_idx .. '_out1' }
            end
        end
        if node.inputs[3] then
            if #node.inputs[3].connection == 0 then
                val_2 = node.inputs[3].i_val
            else
                local inp2, inp2_idx, out_name = TraceSrcNode(node.inputs[3].connection[1])
                --local inp2, inp2_idx, out_name = GetSourceNode(node, node.inputs[3])
                trace_2 = { inp2, inp2_idx, out_name } --inp2.label:gsub("%s+", "") .. inp2_idx .. '_out1' }

                --local inp2, f2_idx, n2_idx = GetNodeInfo(node.inputs[3].connection[1].node)
                --local inp2_idx = ("_F%dN%d"):format(f2_idx, n2_idx)
                --trace_2 = { inp2, inp2_idx, inp2.label:gsub("%s+", "") .. inp2_idx .. '_out1' }
            end
        end

        tmp_str[1] =
            math_code_str[node.inputs[2].i_val]:format(
                val_1 and tostring(val_1) or (trace_1 and trace_1[3]:gsub("[()]", "") or ""),
                val_2 and tostring(val_2) or (trace_2 and trace_2[3]:gsub("[()]", "") or "")
            )

        table.insert(tbl, 1, IdenLVL(ident) .. node.label:gsub("%s+", "") .. node_idx .. '_out1' .. " = " .. tmp_str[1])
        if trace_1 then
            TraceMath(trace_1[1], trace_1[2], tbl, ident)
        end
        if trace_2 then
            TraceMath(trace_2[1], trace_2[2], tbl, ident)
        end
    end
end

local function RemoveDuplicates(tbl)
    local seen = {}
    local rem = {}
    for index, item in ipairs(tbl) do
        if seen[item] then
            rem[#rem + 1] = index
        else
            seen[item] = true
        end
    end
    for i = #rem, 1, -1 do
        table.remove(tbl, rem[i])
    end
end


function MakeMathFlow(node, ident)
    for i = 1, #node.inputs do
        if #node.inputs[i].connection ~= 0 then
            local math_code = {}

            local prev_node, f_idx, n_idx = GetNodeInfo(node.inputs[i].connection[1].node)
            local prev_node_idx = ("_F%dN%d"):format(f_idx, n_idx)

            TraceMath(prev_node, prev_node_idx, math_code, ident)

            RemoveDuplicates(math_code)

            AddCode(table.concat(math_code))
        end
    end
end

function NT_IFELSE_M(node, func_idx, ident)
    MakeMathFlow(node, ident)
end

function NT_IFELSE(node, func_idx, ident)
    MakeMathFlow(node, ident)

    -- IF
    AddCode('\n' .. IdenLVL(ident) .. 'if ')
    ValueReferences(node, { node.inputs[1] })
    AddCode(' == ' .. tostring(node.inputs[2].i_val) .. ' then\n')
    -- TURN ON LOOP OUT 1 FOR CHILD FLOW
    node.outputs[1].run = true
    local child_flow_t = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    CodeGen(child_flow_t, func_idx, ident + 1)

    ---ELSE
    AddCode(IdenLVL(ident) .. 'else\n')
    -- TURN ON LOOP OUT 2 FOR CHILD FLOW
    node.outputs[1].run = false
    node.outputs[2].run = true
    local child_flow_f = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    if #child_flow_f ~= 0 then
        CodeGen(child_flow_f, func_idx, ident + 1)
    else
        table.remove(CODE_STR, #CODE_STR)
    end
    AddCode(IdenLVL(ident) .. 'end\n\n')
    -- TURN OFF BOTH LOOP RUNS
    node.outputs[2].run = false
    node.outputs[1].run = false
end

function NT_FUNC(node, func_idx, ident)
    MakeMathFlow(node, ident)
    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    local node_idx = ("_F%dN%d"):format(f_idx, n_idx)
    AddCode(IdenLVL(ident))
    -- IF FUNCTION DOES NOT RETURN ANY VALUE DO NOT ADD LOCAL
    if #node.outputs > 0 then AddCode('local ') end
    for out_i = 1, #node.outputs do
        if out_i > 1 then AddCode(', ') end
        AddCode((node.outputs[out_i].label:gsub("%s+", "") .. node_idx .. "_out%d"):format(out_i))
    end
    if #node.outputs > 0 then AddCode(' = ') end
    AddCode(node.label:gsub("%s+", "") .. '(')
    ValueReferences(node, node.inputs)
    AddCode(')\n')
end

function NT_FUNC_RET(node, func_idx, ident)
    MakeMathFlow(node, ident)

    AddCode(IdenLVL(ident) .. 'return ')
    ValueReferences(node, node.inputs)
    AddCode('\n')
end

MEMORY_FUNC = nil

local fake_reaper = {}
for k, v in pairs(r) do
    fake_reaper[k] = v
end

fake_reaper.defer = function(callback)
    if RUNNING then
        r.defer(callback)
    end
end

local code_vars = {
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
    local func, err = load(str, "ScriptRun", "t", code_vars)
    --local func, err = load('reaper.defer(function() end)', "ScriptRun", 't', code_vars)
    if func then
        local start_time = r.time_precise()

        local pass, err_msg = pcall(func)
        if not pass then
            RUNNING = nil
            r.ShowConsoleMsg("\nLOAD SCRIPT ERROR\n" .. err_msg)
            return
        end
        local end_time = r.time_precise()
        r.ShowConsoleMsg("\nNATIVE RUN :" .. ('%.4f ms\n'):format((end_time - start_time) * 1000))
    else
        RUNNING = nil

        r.ShowConsoleMsg("\nLOAD FUNCTION COULD NOT BE CREATED:\n" .. err)
        return
    end
end

function NativeExport()
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

local blocks = {}

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

function GenerateCode(export)
    CODE_STR = {}

    local FUNCTIONS = GetFUNCTIONS()

    AddCode('local r = reaper\n')
    AddCode('local math = math\n')

    -- if ULTRA_API then
    --     AddCode(
    --         'if not ultraschall then ultraschall = dofile(r.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua") end\n')
    -- end

    -- CREATE GLOBAL SCOPE FIRST (INIT FUNCTION (1))
    AddVars(FUNCTIONS[1].NODES, 1, 0)
    CodeGen(TraceFlow(FUNCTIONS[1].NODES), 1, 0)
    -- SKIP INIT AND CREATE IN REVERSE ORDER TO HAVE LOCAL FUNCTIONS IN ORDER

    for i = #FUNCTIONS, 2, -1 do
        AddFunc(FUNCTIONS[i], i)
        local NODES = FUNCTIONS[i].NODES
        AddVars(NODES, i, 1)
        local FLOW = TraceFlow(NODES)
        CodeGen(FLOW, i, 1)
        CloseFunc(i)
    end

    AddCode('\nMain()\n\n')

    --if export then r.ShowConsoleMsg(table.concat(CODE_STR)) end
    r.ShowConsoleMsg(table.concat(CODE_STR))
    if not export then MakeMemoryFunc(table.concat(CODE_STR)) end
end
