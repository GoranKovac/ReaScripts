--@noindex
--NoIndex: true

function print(x) reaper.ShowConsoleMsg(x) end

local CODE_STR = {}

local function AddCode(c_str)
    CODE_STR[#CODE_STR + 1] = c_str
end

local function IdenLVL(n)
    return n and string.rep('\x20', n * 4) or ""
end

local function GetNodeType(node)
    if node.type == "get" then
        return GetNodeInfo(node.get)
    elseif node.type == "set" or node.type == "api_var" then
        return GetNodeInfo(node.set.guid)
    else
        return node
    end
end

local function GetSourceNode(node, inputs)
    local prev_node = GetNodeInfo(node.guid)
    local connection_pin = inputs.connection[1].pin

    if prev_node.type == "get" then
        local api_var_node = GetNodeInfo(prev_node.get)
        local src_node, f_id, n_id = GetNodeInfo(api_var_node.set.guid)
        return { src_node, src_node.outputs[api_var_node.set.pin] }
        --return { connected_node, connected_node.outputs[node.inputs[o].connection[1].pin] }
    elseif prev_node.type == "set" then
        local src_node, f_id, n_id = GetNodeInfo(prev_node.set.guid)
        return { src_node, src_node.outputs[prev_node.set.pin] }
    elseif prev_node.type == "api_var" then
        local src_node, f_id, n_id = GetNodeInfo(prev_node.set.guid)
        return { src_node, src_node.outputs[prev_node.set.pin] }
    else
        return { prev_node, prev_node.outputs[connection_pin] }
    end
end

local function ValueReferences(node, inputs)
    for i = 1, #inputs do
        if i > 1 then AddCode(', ') end

        local arg_val

        if #inputs[i].connection == 0 then
            arg_val = type(inputs[i].i_val) == "string" and '"' .. inputs[i].i_val .. '"' or inputs[i].i_val
        else
            local src_node_pin = inputs[i].src
            local src_n, f_idx, n_idx = GetSourceNode(node, inputs[i])
            --local _, f_idx, n_idx = GetNodeInfo(src_node_pin[1].guid)
            local src_node_idx = '_f_' .. f_idx .. 'n_' .. n_idx

            -- FOR LOOP NEEDS OUT LABELS
            --arg_val = src_node_pin[1].label:gsub("%s+", "") .. src_node_idx

            arg_val = (src_node_pin[1].label:gsub("%s+", "") .. src_node_idx .. '_out%d%s'):format(
                inputs[i].connection[1].pin, "")
        end

        AddCode(tostring(arg_val))
    end
end

local function ValueReferences2(node, inputs)
    local cur_node, cf_idx, cn_idx = GetNodeInfo(node.guid)
    local c_node_idx = cf_idx .. cn_idx

    local end_offset = 0

    -- BOOL IDX-1 = inputs[4] -- WE NEED TO EXCLUDE IT FROM LOOP ARGUMENTS
    if cur_node.fname == "CUSTOM_ForLoop" then
        end_offset = 1
    end

    for i = 1, #inputs - end_offset do
        if i > 1 then AddCode(', ') end

        local arg_val

        if #inputs[i].connection == 0 then
            arg_val = type(inputs[i].i_val) == "string" and '"' .. inputs[i].i_val .. '"' or inputs[i].i_val
        else
            local prev_node, f_idx, n_idx = GetNodeInfo(inputs[i].connection[1].node)
            local prev_node_idx = 'f_' .. f_idx .. 'n_' .. n_idx

            local is_global = f_idx == 1 and "_G" or ""
            local src_node = GetNodeType(prev_node)

            local src_pin = inputs[i].connection[1].pin
            -- IF WE ARE IN FUNCTION THIS IS START NODE WE NEED NAME OF ARGUMENTS
            if src_node.type == "m" then
                arg_val = src_node.outputs[src_pin].label:gsub("%s+", "")
            elseif src_node.fname == "CUSTOM_ForLoop" then
                local idx_minus_one = ""
                if src_pin == 2 then
                    if src_node.inputs[4].i_val == true then
                        idx_minus_one = " -1"
                    end
                end
                arg_val = src_node.outputs[src_pin].label:gsub("%s+", ""):lower() .. prev_node_idx .. idx_minus_one
            elseif src_node.fname == "CUSTOM_Ipairs" or src_node.fname == "CUSTOM_Pairs" then
                arg_val = src_node.outputs[src_pin].label:gsub("%s+", ""):lower() .. prev_node_idx

                -- REFERENCE NODE
            else
                arg_val = (src_node.label:gsub("%s+", "") .. prev_node_idx .. '_out%d%s'):format(
                    inputs[i].connection[1].pin, is_global)
            end
        end

        AddCode(tostring(arg_val))
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
    AddCode('end\n')
end

-- Node Types
function NT_VAR(node, func_idx, ident)
    local is_global = func_idx == 1 and "_G" or ""

    AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") .. is_global .. ' = ' .. node.outputs[1].i_val)
end

function NT_CALL(node, func_idx, ident)
    local is_global = func_idx == 1 and "_G" or ""
    AddCode(IdenLVL(ident) .. 'local ')

    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    local node_idx = '_f_' .. f_idx .. 'n_' .. n_idx

    for out_i = 1, #node.outputs do
        if out_i > 1 then AddCode(', ') end
        AddCode((node.label:gsub("%s+", "") .. node_idx .. '_out%d%s'):format(out_i, is_global))
    end

    if #node.outputs > 0 then AddCode(' = ') end

    AddCode('r.' .. node.fname .. '(')
    ValueReferences(node, node.inputs)
    AddCode(')\n')
end

function NT_FORLOOP(node, func_idx, ident)
    local _, f_idx, n_idx = GetNodeInfo(node.guid)
    local node_idx = '_f_' .. f_idx .. 'n_' .. n_idx

    if node.fname == "CUSTOM_ForLoop" then
        AddCode(IdenLVL(ident) .. 'for idx' .. node_idx .. ' = ')
        --local start_idx, inc, end_idx, idx_sub_one = node.inputs[1], node.inputs[2], node.inputs[3],
        --   node.inputs[4] == true and " -1" or ""
    elseif node.fname == "CUSTOM_Ipairs" then
        AddCode(IdenLVL(ident) .. 'for key' .. node_idx .. ', value' .. node_idx .. ' in ipairs(')
    elseif node.fname == "CUSTOM_Pairs" then
        AddCode(IdenLVL(ident) .. 'for key' .. node_idx .. ', value' .. node_idx .. ' in pairs(')
    end


    ValueReferences(node, node.inputs)

    if node.fname == "CUSTOM_Ipairs" or node.fname == "CUSTOM_Pairs" then AddCode(')') end
    AddCode(' do\n')

    local child_flow = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    CodeGen(child_flow, func_idx, ident + 1)
    AddCode(IdenLVL(ident) .. 'end\n\n')
end

function NT_IFELSE(node, func_idx, ident)
    -- IF
    AddCode('if TMP_VAL ')
    ValueReferences(node, node.inputs)
    AddCode('then ')
    -- TURN ON LOOP OUT 1 FOR CHILD FLOW
    node.output[1].run = true
    local child_flow = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    --GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    CodeGen(node.LOOP_FLOW, func_idx)
    ---ELSE
    AddCode('else ')
    -- TURN ON LOOP OUT 2 FOR CHILD FLOW
    node.output[1].run = false
    node.output[2].run = true
    local child_flow = GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    --GetChildFlowNATIVE(node, GetFunctionNodes(node.guid))
    CodeGen(node.LOOP_FLOW, func_idx)
    AddCode('end\n')

    -- TURN OFF BOTH LOOP RUNS
    node.output[2].run = false
    node.output[1].run = false
    node.LOOP_FLOW = nil
end

function NT_FUNC(node, func_idx, ident)
    AddCode(IdenLVL(ident) .. 'local ')
    for out_i = 1, #node.outputs do
        if out_i > 1 then AddCode(', ') end
        AddCode((node.outputs[out_i].label:gsub("%s+", "")):format(out_i))
    end
    if #node.outputs > 0 then AddCode(' = ') end
    AddCode(node.label:gsub("%s+", "") .. '(')
    ValueReferences(node, node.inputs)
    AddCode(')\n')
end

function NT_FUNC_RET(node, func_idx, ident)
    AddCode(IdenLVL(ident) .. 'return ')
    ValueReferences(node, node.inputs)
    AddCode('\n')
end

MEMORY_FUNC = nil

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
    r = reaper,
    reaper = reaper,

}

function MakeMemoryFunc(str)
    local func, err = load(str, "ScriptRun", "t", code_vars)
    if func then
        local pass, err_msg = pcall(func)
        if not pass then
            reaper.ShowConsoleMsg("LOAD SCRIPT ERROR\n" .. err_msg)
            return
        end
    else
        reaper.ShowConsoleMsg("LOAD FUNCTION COULD NOT BE CREATED:\n" .. err)
        return
    end
end

function NativeExport(tbl, name)
    local path = PATH .. "ExportedActions/ReaSpaghetti_StandAlone_" .. name:gsub(".reanodes", "") .. ".lua"
    local gen_code = "-- CODE GENERATED BY ReaSpaghetti\n\n"

    table.insert(tbl, 1, gen_code)

    local file = io.open(path, "w")
    if file then
        file:write(table.concat(CODE_STR))
        file:close()
        local ret = reaper.AddRemoveReaScript(true, 0, path, 1)
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

function GenerateCode()
    CODE_STR = {}

    local FUNCTIONS = GetFUNCTIONS()

    AddCode('local r = reaper\n\n')
    -- CREATE GLOBAL SCOPE FIRST (INIT FUNCTION (1))
    CodeGen(TraceFlow(FUNCTIONS[1].NODES), 1)
    -- SKIP INIT AND CREATE IN REVERSE ORDER TO HAVE LOCAL FUNCTIONS IN ORDER
    for i = #FUNCTIONS, 2, -1 do
        AddFunc(FUNCTIONS[i], i)
        local NODES = FUNCTIONS[i].NODES
        local FLOW = TraceFlow(NODES)
        CodeGen(FLOW, i, 1)
        CloseFunc(i)
    end

    AddCode(DEFERED_NODE and '\nr.defer(Main)' or '\nMain()')

    --reaper.ClearConsole()
    print(table.concat(CODE_STR))
    --MakeMemoryFunc(table.concat(CODE_STR))
    --NativeExport(CODE_STR, "NATIVE_EXPORT")
end
