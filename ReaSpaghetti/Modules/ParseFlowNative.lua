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

local function IsLoop(node, pin)
    if node.fname == "CUSTOM_ForLoop" or node.fname == "CUSTOM_Ipairs" or node.fname == "CUSTOM_Pairs" or node.fname == "CUSTOM_Fastpairs" then
        return true
    end
end

-- TRACE SOURCE NODE FROM PIN CONNECTION
local function GetSourceNode(node, inputs)
    local prev_node, p_f_id, p_n_id = GetNodeInfo(inputs.connection[1].node)

    local connection_pin = inputs.connection[1].pin
    local prev_node_idx = ("_F%dN%d"):format(p_f_id, p_n_id)

    if prev_node.type == "get" then
        -- GET NODE RETURNS SETTERS OUTPUT SO WE NEED TO TRACE SOURCE OF SETTER
        local api_var_node = GetNodeInfo(prev_node.get)
        local src_node, f_id, n_id = GetNodeInfo(api_var_node.set.guid)
        local src_node_idx = ("_F%dN%d"):format(f_id, n_id)
        if IsLoop(src_node, api_var_node.set.pin) then
            -- IF CONNECTED TO LOOP OUTPUT RETURN LOOP PIN LABEL NAME
            return src_node.outputs[api_var_node.set.pin].label:gsub("%s+", "") .. src_node_idx, true
        else
            -- RETURN REFERENCED NODE NAME
            return src_node.label:gsub("%s+", "") .. src_node_idx
        end
    elseif prev_node.type == "set" then
        local src_node, f_id, n_id = GetNodeInfo(prev_node.set.guid)
        local src_node_idx = ("_F%dN%d"):format(f_id, n_id)
        if IsLoop(src_node, prev_node.set.pin) then
            -- IF CONNECTED TO LOOP OUTPUT RETURN LOOP PIN LABEL NAME
            return src_node.outputs[prev_node.set.pin].label:gsub("%s+", "") .. src_node_idx, true
        else
            -- RETURN REFERENCED NODE NAME
            return src_node.label:gsub("%s+", "") .. src_node_idx
        end
    elseif prev_node.type == "api_var" then
        local src_node, f_id, n_id = GetNodeInfo(prev_node.set.guid)
        local src_node_idx = ("_F%dN%d"):format(f_id, n_id)
        if IsLoop(src_node, prev_node.set.pin) then
            -- IF CONNECTED TO LOOP OUTPUT RETURN LOOP PIN LABEL NAME
            return src_node.outputs[prev_node.set.pin].label:gsub("%s+", "") .. src_node_idx, true
        else
            -- RETURN REFERENCED NODE NAME
            return src_node.label:gsub("%s+", "") .. src_node_idx
        end
    else
        if IsLoop(prev_node, connection_pin) then
            -- IF CONNECTED TO LOOP OUTPUT RETURN LOOP PIN LABEL NAME
            return prev_node.outputs[connection_pin].label:gsub("%s+", "") .. prev_node_idx, true
        else
            if prev_node.type == "m" then
                -- CONNECTED TO FUNCTION START NODE, RETURN START PIN NAME (FUNCTION ARGUMENT)
                return prev_node.outputs[connection_pin].label:gsub("%s+", "")
            elseif prev_node.type == "func" then
                -- CONNECTED TO FUNCTION OUTPUT, RETURN OUTPUT PIN NAME (FUNCTION RETURN)
                return prev_node.outputs[connection_pin].label:gsub("%s+", "") .. prev_node_idx
            else
                -- RETURN REFERENCED NODE NAME
                return prev_node.label:gsub("%s+", "") .. prev_node_idx
            end
        end
    end
end

local function ValueReferences(node, inputs, idx_sub_1)
    for i = 1, #inputs do
        if i > 1 then AddCode(', ') end

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
            local out_v, loop = GetSourceNode(node, inputs[i])
            arg_val = (out_v .. (loop and "" or '_out%d')):format(inputs[i].connection[1].pin)
            if idx_sub_1 then
                -- SUBTRACT START, END AND SKIP INCREMENT
                if i < 3 then arg_val = arg_val .. " - 1" end
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
    AddCode(IdenLVL(ident) .. 'local ' .. node.label:gsub("%s+", "") .. ' = ' .. node.outputs[1].i_val)
end

function NT_CALL(node, func_idx, ident)
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
        AddCode(IdenLVL(ident) .. 'for IDX' .. node_idx .. ' = ')
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
    if node.fname:find("MATH_") then
        if node.inputs[1].connection[1] and node.inputs[3].connection[1] then
            -- TRACE NODE REFERENCES

            local inp1, f1_idx, n1_idx = GetNodeInfo(node.inputs[1].connection[1].node)
            local inp2, f2_idx, n2_idx = GetNodeInfo(node.inputs[3].connection[1].node)
            local inp1_idx = ("_F%dN%d"):format(f1_idx, n1_idx)
            local inp2_idx = ("_F%dN%d"):format(f2_idx, n2_idx)

            table.insert(tbl, 1,
                IdenLVL(ident) .. node.label:gsub("%s+", "") .. node_idx .. '_out1' ..
                " = " ..
                inp1.label:gsub("%s+", "") .. inp1_idx .. '_out1' ..
                ' ' ..
                node.inputs[2].i_val ..
                ' ' ..
                inp2.label:gsub("%s+", "") .. inp2_idx .. '_out1' .. "\n")

            -- TRACE FIRST INPUT
            TraceMath(inp1, inp1_idx, tbl, ident)

            -- TRACE SECOND INPUT
            TraceMath(inp2, inp2_idx, tbl, ident)
        else
            -- WRITE VALUES
            table.insert(tbl, 1,
                IdenLVL(ident) .. node.label:gsub("%s+", "") .. node_idx .. '_out1' ..
                " = " ..
                node.inputs[1].i_val ..
                ' ' .. node.inputs[2].i_val ..
                ' ' .. node.inputs[3].i_val .. "\n")
        end
    end
end

local function MakeMathFlow(node, ident)
    local math_code = {}

    local prev_node, f_idx, n_idx = GetNodeInfo(node.inputs[1].connection[1].node)
    local prev_node_idx = ("_F%dN%d"):format(f_idx, n_idx)

    TraceMath(prev_node, prev_node_idx, math_code, ident)
    AddCode(table.concat(math_code))
end

function NT_IFELSE(node, func_idx, ident)
    MakeMathFlow(node, ident)

    -- IF
    AddCode(IdenLVL(ident) .. 'if ')
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
    CodeGen(child_flow_f, func_idx, ident + 1)
    AddCode(IdenLVL(ident) .. 'end\n')

    -- TURN OFF BOTH LOOP RUNS
    node.outputs[2].run = false
    node.outputs[1].run = false
end

function NT_FUNC(node, func_idx, ident)
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
    load = load,
    dofile = dofile,
    r = reaper,
    reaper = reaper,
    ultraschall = ULTRA_API and ultraschall

}

function MakeMemoryFunc(str)
    local func, err = load(str, "ScriptRun", "t", code_vars)
    if func then
        local start_time = reaper.time_precise()

        local pass, err_msg = pcall(func)
        if not pass then
            reaper.ShowConsoleMsg("\nLOAD SCRIPT ERROR\n" .. err_msg)
            return
        end
        local end_time = reaper.time_precise()
        reaper.ShowConsoleMsg("\nNATIVE RUN :" .. ('%.4f ms\n'):format((end_time - start_time) * 1000))
    else
        reaper.ShowConsoleMsg("\nLOAD FUNCTION COULD NOT BE CREATED:\n" .. err)
        return
    end
end

function NativeExport(tbl, name)
    local path = PATH .. "ExportedActions/ReaSpaghetti_StandAlone_" .. name:gsub(".reanodes", "") .. ".lua"
    local gen_code = "-- CODE GENERATED BY ReaSpaghetti\n\n"
    local gen_desc =
    "-- SUFIX : FxNx \n -- F = FUNCTION ID (FUNCTION WHERE NODE LIVES) \n -- N = NODE ID (NUMBER OF THE NODE IN FUNCTION) \n\n"

    table.insert(tbl, 1, gen_code)
    table.insert(tbl, 1, gen_desc)

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

    AddCode('local r = reaper\n')
    if ULTRA_API then
        AddCode(
            'if not ultraschall then ultraschall = dofile(r.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua") end\n')
    end
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

    AddCode(DEFERED_NODE and '\nr.defer(Main)\n\n' or '\nMain()\n\n')


    --print(table.concat(CODE_STR))
    MakeMemoryFunc(table.concat(CODE_STR))
    NativeExport(CODE_STR, "NATIVE_EXPORT")
end
