local r = reaper

------------------- OLD PARSER
------------------- OLD PARSER
------------------- OLD PARSER
------------------- OLD PARSER

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
    ["//"]         = function(x, y)
        if x == 0 or y == 0 then return 0 end
        return x // y
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

------------------- OLD PARSER
------------------- OLD PARSER


function GetChildFlowNATIVE(called_node, NODES)
    local LOOP_FLOW = {}
    for i = 1, #called_node.outputs do
        if called_node.outputs[i] then
            local loop_run = called_node.outputs[i].run == true and called_node.outputs[i].connection
            if loop_run then
                if next(loop_run) then
                    local next_node_guid = loop_run[1].node
                    while next_node_guid do
                        LOOP_FLOW[#LOOP_FLOW + 1] = In_TBL(NODES, next_node_guid)
                        local next_node = LOOP_FLOW[#LOOP_FLOW]
                        local next_output = next_node.outputs[0]
                        -- FLOW IS CHECKED ONLY IF OUT PIN 0 (RUN) IS CONNECTED
                        if next_output and next_output.connection and next(next_output.connection) then
                            next_node_guid = next_output.connection[1].node
                        elseif next_node.type == "ws" then
                            next_node_guid = next_node.sender
                        else
                            next_node_guid = nil
                        end
                    end
                end
            end
        end
    end
    return LOOP_FLOW
end

function TraceFlow(NODES)
    local FLOW = {}

    local start_node = NODES[1] --DEFERED_NODE and DEFERED_NODE or NODES[1]
    local master = start_node.outputs[0].connection
    ---------------- DEFER TEST ----------
    if not master then return end

    local master_active = next(master) and true or false

    if master_active then
        -- ADD START NODE ALSO
        if not In_TBL(FLOW, start_node.guid) then
            FLOW[#FLOW + 1] = start_node
        end
        LAST_NODE = master[1].node
        if not In_TBL(FLOW, LAST_NODE) then
            FLOW[#FLOW + 1] = In_TBL(NODES, LAST_NODE)
        end

        while LAST_NODE do
            local next_node = FLOW[#FLOW]
            if next_node.outputs[0] and next(next_node.outputs[0].connection) then
                LAST_NODE = next_node.outputs[0].connection[1].node
                FLOW[#FLOW + 1] = In_TBL(NODES, LAST_NODE)
                -- WIRELESS NODE, NEXT NODE IS SENDER
            elseif next_node.type == "ws" then
                LAST_NODE = next_node.sender
                FLOW[#FLOW + 1] = In_TBL(NODES, LAST_NODE)
            else
                LAST_NODE = nil
            end
        end
    end
    return FLOW
end

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
    --["CUSTOM_GetScriptPath"]        = function() return [[debug.getinfo(1).source:match("@?(.*[\\|/])")]] .. "\n" end,
    ["CUSTOM_GetOsNativeSeparator"] = function() return ('%q'):format(NATIVE_SEPARATOR) .. '\n' end
}

local Imgui_BeginEnd = {
    -- BEGIN -> END
    ["ImGui_Begin"]                   = "ImGui_End",
    ["ImGui_BeginChild"]              = "ImGui_EndChild",
    ["ImGui_BeginChildFrame"]         = "ImGui_EndChildFrame",
    ["ImGui_BeginCombo"]              = "ImGui_EndCombo",
    ["ImGui_BeginDisabled"]           = "ImGui_EndDisabled",
    ["ImGui_BeginDragDropSource"]     = "ImGui_EndDragDropSource",
    ["ImGui_BeginDragDropTarget"]     = "ImGui_EndDragDropTarget",
    ["ImGui_BeginGroup"]              = "ImGui_EndGroup",
    ["ImGui_BeginListBox"]            = "ImGui_EndListBox",
    ["ImGui_BeginMenu"]               = "ImGui_EndMenu",
    ["ImGui_BeginMenuBar"]            = "ImGui_EndMenuBar",
    ["ImGui_BeginPopup"]              = "ImGui_EndPopup",
    ["ImGui_BeginPopupContextltem"]   = "ImGui_EndPopupContextltem",
    ["ImGui_BeginPopupContextWindow"] = "ImGui_EndPopupContextWindow",
    ["ImGui_BeginPopupModal"]         = "ImGui_EndPopupModal",
    ["ImGui_BeginTabBar"]             = "ImGui_EndTabBar",
    ["ImGui_BeginTabltem"]            = "ImGui_EndTabltem",
    ["ImGui_BeginTable"]              = "ImGui_EndTable",
    ["ImGui_BeginTooltip"]            = "ImGui_EndTooltip",
    ---- PUSH -> POP
    ["ImGui_PushButtonRepeat"]        = "ImGui_PopButtonRepeat",
    ["ImGui_PushClipRect"]            = "ImGui_PopClipRect",
    ["ImGui_PushFont"]                = "ImGui_PopFont",
    ["ImGui_PushID"]                  = "ImGui_PopID",
    ["ImGui_PushItemWidth"]           = "ImGui_PopItemWidth",
    ["ImGui_PushStyleColor"]          = "ImGui_PopStyleColor",
    ["ImGui_PushStyleVar"]            = "ImGui_PopStyleVar",
    ["ImGui_PushTabStop"]             = "ImGui_PopTabStop",
    ["ImGui_PushTextWrapPos"]         = "ImGui_PopTextWrapPos",
}

local CODE_STR = {}

local function LiveCode(f, n, i, io)
    return ('FUNCTIONS[%s].NODES[%s].' .. (io == 'in' and 'inputs' or 'outputs') .. '[%s].i_val'):format(f, n, i)
end

local function IsLocal(n)
    if EXPORT then
        return (n == 0 or n == 1) and 'local ' or ''
    else
        return ''
    end
end

local function IdenLVL(n)
    return n and string.rep('\x20', n * 4) or ""
end

local function AddCode(c_str)
    CODE_STR[#CODE_STR + 1] = c_str
end

local function AddCodeLine(tbl, str)
    tbl[#tbl + 1] = str
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
    if not data then return end
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
        if tbl[i] == val then return true end
    end
end

local function RemoveDuplicates(tbl)
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
        local src_node, f_id, n_id = GetNodeInfo(node.guid)
        local tmp_str = {}
        local val_1, val_2
        local trace_1, trace_2
        if node.inputs[1] then
            if #node.inputs[1].connection == 0 then
                val_1 = EXPORT and tostring(node.inputs[1].i_val) or
                    LiveCode(f_id, n_id, 1, "in") --node.inputs[1].i_val
            else
                local inp1, inp1_idx, out_name = TraceSrcNode(node.inputs[1].connection[1])
                trace_1 = { inp1, inp1_idx, out_name }
            end
        end
        if node.inputs[3] then
            if #node.inputs[3].connection == 0 then
                val_2 = EXPORT and tostring(node.inputs[3].i_val) or
                    LiveCode(f_id, n_id, 3, "in") --node.inputs[3].i_val
            else
                local inp2, inp2_idx, out_name = TraceSrcNode(node.inputs[3].connection[1])
                trace_2 = { inp2, inp2_idx, out_name }
            end
        end

        tmp_str[1] =
            math_code_str[node.inputs[2].i_val]:format(
                val_1 and val_1 or (trace_1 and trace_1[3]:gsub("[()]", "") or ""),
                val_2 and val_2 or (trace_2 and trace_2[3]:gsub("[()]", "") or "")
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
        end
    end

    if #math_code ~= 0 then
        local math_filter = RemoveDuplicates(math_code)
        AddCode(table.concat(math_filter))
    end
end

function ValueReferences(guid, exclude)
    local idx_start = exclude and 1 + exclude or 1
    local node, f_idx, n_idx = GetNodeInfo(guid)
    local vars = {}
    local arg_val = {}
    local code_lines = {}
    for i = idx_start, #node.inputs do
        if i > idx_start then AddCodeLine(code_lines, ', ') end
        -- NOT CONNECTED TO ANY NODE, GET RAW VALUE
        if not node.inputs[i].opt or (node.inputs[i].opt and node.inputs[i].opt.use) then
            if #node.inputs[i].connection == 0 then
                if EXPORT then
                    arg_val[1] = type(node.inputs[i].i_val) == "string"
                        and ('%q'):format(node.inputs[i].i_val)
                        or node.inputs[i].i_val
                else
                    arg_val[1] = LiveCode(f_idx, n_idx, i, "in")
                end
            else
                -- CONNECTED TO OTHER NODE, GET REFERENCE NODE
                local src_node, idx, out_v = TraceSrcNode(node.inputs[i].connection[1])
                arg_val[1]                 = out_v
            end
        else
            if EXPORT then
                arg_val[1] = "nil"
            else
                arg_val[1] = ('%q'):format(node.inputs[i].i_val)
            end
        end

        vars[#vars + 1] = arg_val[1]
        AddCodeLine(code_lines, tostring(arg_val[1]))
    end
    return code_lines, vars
end

local VARS = {
    ["s"] = true,
    ["i"] = true,
    ["f"] = true,
    ["b"] = true,
    ["t"] = true,
}

function AddVars(nodes, func_idx, ident)
    local code_lines = {}
    for n = 1, #nodes do
        local node = nodes[n]
        if VARS[node.type] then
            --if node.type == "code" then reaper.ShowConsoleMsg(node.label) end
            local node_idx = ("_F%dN%d"):format(func_idx, n)
            local label = {
                IdenLVL(ident) .. IsLocal(ident) .. node.label:gsub("%s+", "") .. node_idx .. '_out1' .. ' = ' }

            --local value = EXPORT and node.outputs[1].i_val or LiveCode(func_idx, n, 1, "out")

            local value
            if EXPORT then
                value = node.outputs[1].i_val
            else
                value = LiveCode(func_idx, n, 1, "out")
            end
            --local label = { IdenLVL(ident) .. node.label:gsub("%s+", "") .. node_idx .. '_out1' .. ' = ' }

            --Comment(ident, node)
            if node.type == "s" then
                if #node.outputs[1].connection ~= 0 then
                    local next_node = GetNodeInfo(node.outputs[1].connection[1].node)
                    if next_node.type ~= "code" then
                        AddCodeLine(code_lines,
                            label[1] .. (EXPORT and ('%q'):format(node.outputs[1].i_val) or value) .. "\n")
                        --AddCode(label[1] .. ('%q'):format(node.outputs[1].i_val) .. "\n")
                    end
                else
                    AddCodeLine(code_lines,
                        label[1] .. (EXPORT and ('%q'):format(node.outputs[1].i_val) or value) .. "\n")
                    --AddCode(label[1] .. ('%q'):format(node.outputs[1].i_val) .. "\n")
                end
            elseif node.type == "i" then
                AddCodeLine(code_lines, label[1] .. value .. "\n")
                --AddCode(label[1] .. node.outputs[1].i_val .. "\n")
            elseif node.type == "f" then
                AddCodeLine(code_lines, label[1] .. value .. "\n")
                --AddCode(label[1] .. node.outputs[1].i_val .. "\n")
            elseif node.type == "b" then
                AddCodeLine(code_lines, label[1] .. tostring(value) .. "\n")
                --AddCode(label[1] .. tostring(node.outputs[1].i_val) .. "\n")
            elseif node.type == "t" then
                AddCodeLine(code_lines, label[1] .. tostring('{}') .. "\n")
                --AddCode(label[1] .. tostring('{}') .. "\n")
            end
        end
    end
    AddCode(table.concat(code_lines))
end

local function AddFunc(node, index)
    -- SKIP INIT FUNCTION
    if index < 2 then return end
    local code_line = {}
    AddCodeLine(code_line, '\nfunction ' .. node.label:gsub("%s+", "") .. '(')
    for i = 1, #node.inputs do
        if i > 1 then AddCodeLine(code_line, ', ') end
        AddCodeLine(code_line, node.inputs[i].label:gsub("%s+", ""))
    end
    AddCodeLine(code_line, ')\n')
    AddCode(table.concat(code_line))
end

local function CloseFunc(index)
    if index < 2 then return end
    AddCode('end\n')
end

function NT_IMGUI(node_tbl, func_idx, ident)
    local code_line = {}
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx, var_name = NodeIDX(node_tbl.guid)

    AddCodeLine(code_line, IdenLVL(ident))

    local is_local = IsLocal(ident)
    -- IF API DOES NOT RETURN ANY VALUE DO NOT ADD LOCAL
    if #node_tbl.outputs > 0 then
        AddCodeLine(code_line, is_local)
    end

    for out_i = 1, #node.outputs do
        if out_i > 1 then AddCodeLine(code_line, ', ') end
        AddCodeLine(code_line, var_name:format(out_i))
    end

    if #node.outputs > 0 then AddCodeLine(code_line, ' = ') end

    if node.sp_api then
        AddCodeLine(code_line, node.sp_api .. '.' .. node.fname .. '(')
    else
        AddCodeLine(code_line, 'r.' .. node.fname .. '(')
    end
    local vals_code, vals = ValueReferences(node_tbl.guid)
    AddCodeLine(code_line, table.concat(vals_code))
    AddCodeLine(code_line, ')\n')

    AddCode(table.concat(code_line))
end

function NT_CALL(node_tbl, func_idx, ident)
    local code_line = {}
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx, var_name = NodeIDX(node_tbl.guid)

    AddCodeLine(code_line, IdenLVL(ident))

    local is_local = IsLocal(ident)
    -- IF API DOES NOT RETURN ANY VALUE DO NOT ADD LOCAL
    if #node_tbl.outputs > 0 then
        AddCodeLine(code_line, is_local)
    end

    for out_i = 1, #node.outputs do
        if out_i > 1 then AddCodeLine(code_line, ', ') end
        AddCodeLine(code_line, var_name:format(out_i))
    end

    if #node.outputs > 0 then AddCodeLine(code_line, ' = ') end

    if node.sp_api then
        AddCodeLine(code_line, node.sp_api .. '.' .. node.fname .. '(')
    else
        AddCodeLine(code_line, 'r.' .. node.fname .. '(')
    end
    local vals_code, vals = ValueReferences(node_tbl.guid)
    AddCodeLine(code_line, table.concat(vals_code))
    AddCodeLine(code_line, ')\n')

    AddCode(table.concat(code_line))
end

function NT_TABLE(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)
    local node, node_idx, var_name = NodeIDX(node_tbl.guid)

    var_name = var_name:format(1)

    --local is_local = IsLocal(ident)

    local code, vals = ValueReferences(node_tbl.guid)
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
        local code, vals = ValueReferences(node_tbl.guid)
        AddCode(vals[i])
    end

    AddCode('}\n')
end

function NT_FORLOOP(node_tbl, func_idx, ident)
    Comment(ident, node_tbl)

    local node, node_idx = NodeIDX(node_tbl.guid)

    local code, vals = ValueReferences(node_tbl.guid)

    local start_or_key, inc_or_value, end_or_table, sub1 =
        vals[1],                                                               --ValueReferences({ node_tbl.inputs[1] }, true)[1],
        vals[2],                                                               --ValueReferences({ node_tbl.inputs[2] }, true)[1],
        vals[3],                                                               --ValueReferences({ node_tbl.inputs[3] }, true)[1],
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

    local code, vals = ValueReferences(node_tbl.guid)

    local cond_1 = vals[1] --ValueReferences({ node.inputs[1] }, true)[1]
    local cond_2 = vals[2] --ValueReferences({ node.inputs[2] }, true)[1]

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

    local code, vals = ValueReferences(node_tbl.guid)

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

    local code, vals = ValueReferences(node_tbl.guid)

    AddCode(IdenLVL(ident) .. is_local .. lua_type[node.fname](var_name, table.unpack(vals)))
end

function NT_SET(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)
    if #node_tbl.inputs[1].connection == 0 then return end

    local node, node_idx, var_name = NodeIDX(node_tbl.set.guid)
    var_name = var_name:format(1)

    AddCode(IdenLVL(ident) .. var_name .. ' = ')
    local code, vals = ValueReferences(node_tbl.guid)
    AddCode(table.concat(code))
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
    local code, vals = ValueReferences(node_tbl.guid)

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
    local code, vals = ValueReferences(node_tbl.guid)
    AddCode(table.concat(code))
    AddCode('\n')
end

function NT_CODE(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx, var_name = NodeIDX(node_tbl.guid)
    local func_name = node.label .. node_idx

    local str_src = TraceSrcNode(node_tbl.inputs[1].connection[1])

    --if not str_src then return end

    local c_string = str_src and str_src.outputs[1].i_val or ""
    local load_code = {}

    load_code[#load_code + 1] = '\nfunction ' .. func_name .. '('

    for i = 2, #node_tbl.inputs do
        if i > 2 then load_code[#load_code + 1] = ', ' end
        load_code[#load_code + 1] = 'input' .. i - 1
    end

    load_code[#load_code + 1] = ')\n'

    if #node_tbl.outputs > 0 then
        load_code[#load_code + 1] = IdenLVL(ident - 1) .. 'local '

        for i = 1, #node_tbl.outputs do
            if i > 1 then load_code[#load_code + 1] = ', ' end
            load_code[#load_code + 1] = 'output' .. i
            if i == #node_tbl.outputs then load_code[#load_code + 1] = '\n' end
        end
    end


    load_code[#load_code + 1] = IdenLVL(ident - 1) .. c_string:gsub('\n', '\n' .. IdenLVL(ident - 1)) --..
    -- '\n' .. IdenLVL(ident - 1) .. 'return '
    if #node_tbl.outputs > 0 then
        load_code[#load_code + 1] = '\n' .. IdenLVL(ident - 1) .. 'return '
        for i = 1, #node_tbl.outputs do
            if i > 1 then load_code[#load_code + 1] = ', ' end
            load_code[#load_code + 1] = 'output' .. i
            --if i == #node_tbl.outputs then load_code[#load_code + 1] = '\nend\n' end
        end
    end

    load_code[#load_code + 1] = '\nend\n'

    --table.insert(CODE_STR, 3, table.concat(load_code))

    table.insert(CODE_STR, 1, table.concat(load_code))

    AddCode(IdenLVL(ident))

    if #node.outputs > 0 then AddCode('local ') end

    for out_i = 1, #node.outputs do
        local label = (func_name:gsub("%s+", "") .. "_out%d"):format(out_i)
        if out_i > 1 then AddCode(', ') end
        AddCode(label)
    end

    if #node.outputs > 0 then AddCode(' = ') end

    AddCode(func_name:gsub("%s+", "") .. '(')
    --local inputs = Deepcopy(node_tbl.inputs)
    --table.remove(inputs, 1)
    local code, vals = ValueReferences(node_tbl.guid, 1)
    AddCode(table.concat(code))
    AddCode(')\n')
end

-- -- function NT_CODE2(node_tbl, func_idx, ident)
-- --     MakeMathFlow(node_tbl, ident)
-- --     Comment(ident, node_tbl)

-- --     local node, node_idx, var_name = NodeIDX(node_tbl.guid)
-- --     local func_name = node.label .. node_idx
-- --     local code_string = ValueReferences({ node_tbl.inputs[1] }, true)[1]
-- --     local load_code = {}

-- --     -- VARS
-- --     load_code[#load_code + 1] = '\n' .. 'local ' .. func_name .. '_vars = {\n' .. code_vars .. '}\n'

-- --     -- AddCode('\n' .. IdenLVL(ident) .. func_name .. '_vars = {\n')
-- --     -- AddCode(code_vars)
-- --     -- AddCode('}\n')

-- --     -- PREPARE INPUTS
-- --     local vals = ValueReferences(node_tbl.inputs, true)
-- --     table.remove(vals, 1) -- REMOVE CODE INPUT

-- --     for i = 1, #vals do
-- --         AddCode(IdenLVL(ident) .. func_name .. '_vars.input[' .. i .. '] = ' .. vals[i] .. '\n')
-- --     end

-- --     local str_src = TraceSrcNode(node_tbl.inputs[1].connection[1])
-- --     local c_string = str_src.outputs[1].i_val

-- --     load_code[#load_code + 1] = 'local ' .. code_string .. ' = ' .. ('%q'):format(c_string)

-- --     load_code[#load_code + 1] =
-- --         '\n' .. 'local ' ..
-- --         func_name .. '_func = ' ..
-- --         'load(' ..
-- --         code_string .. ', ' .. ('%q'):format('node' .. node_idx) ..
-- --         ', ' .. '"t"' .. ', ' .. func_name .. '_vars' .. ')\n'
-- --     -- LOAD

-- --     -- AddCode('\n' .. IdenLVL(ident) ..
-- --     --     func_name .. '_func = ' ..
-- --     --     'load(' ..
-- --     --     code_string .. ', ' .. ('%q'):format('node' .. node_idx) ..
-- --     --     ', ' .. '"t"' .. ', ' .. func_name .. '_vars' .. ')\n')

-- --     table.insert(CODE_STR, 2, table.concat(load_code))

-- --     AddCode('\n' .. IdenLVL(ident) .. func_name .. '_func()\n')

-- --     for i = 1, #node_tbl.outputs do
-- --         AddCode(IdenLVL(ident) .. var_name:format(i) .. ' = ' .. func_name .. '_vars.output[' .. i .. ']\n')
-- --     end
-- -- end
function NT_SWITCH(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx = NodeIDX(node_tbl.guid)

    --AddCode(IdenLVL(ident) .. 'if ')

    --local vals = ValueReferences(node_tbl.inputs, true)

    for i = 1, #node_tbl.outputs do
        node_tbl.outputs[i].run = false
    end

    local code, vals = ValueReferences(node_tbl.guid)

    for i = 1, #node_tbl.inputs do
        AddCode(IdenLVL(ident))
        --if i > 1 then AddCode('else') end

        local inp_condition = vals[i] or tostring(true)
        AddCode('if ' .. inp_condition .. ' then\n')

        node_tbl.outputs[i + 1].run = true
        local child_flow_t = GetChildFlowNATIVE(node_tbl, GetFunctionNodes(node_tbl.guid))
        node_tbl.outputs[i + 1].run = false
        CodeGen(child_flow_t, func_idx, ident + 1)
        AddCode(IdenLVL(ident) .. 'end\n')
    end
    -- AddCode(IdenLVL(ident) .. 'else\n')
    -- node_tbl.outputs[1].run = true
    -- local child_flow_t = GetChildFlowNATIVE(node_tbl, GetFunctionNodes(node_tbl.guid))
    -- node_tbl.outputs[1].run = false
    -- CodeGen(child_flow_t, func_idx, ident + 1)
    -- AddCode(IdenLVL(ident) .. 'end\n')
end

function NT_SWITCH_ELSEIF(node_tbl, func_idx, ident)
    MakeMathFlow(node_tbl, ident)
    Comment(ident, node_tbl)

    local node, node_idx = NodeIDX(node_tbl.guid)

    --AddCode(IdenLVL(ident) .. 'if ')

    --local vals = ValueReferences(node_tbl.inputs, true)

    for i = 1, #node_tbl.outputs do
        node_tbl.outputs[i].run = false
    end

    local code, vals = ValueReferences(node_tbl.guid)

    for i = 1, #node_tbl.inputs do
        AddCode(IdenLVL(ident))
        if i > 1 then AddCode('else') end
        local inp_condition = vals[i] or tostring(true)
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
    DEFERING = true
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
            if _G[node.compiler] then
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
end

function NativeExport2()
    local path = PATH .. "ExportedActions/ReaSpaghetti_StandAlone_" .. PROJECT_NAME:gsub(".reanodes", "") .. ".lua"

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

local fake_reaper = {}
for k, v in pairs(r) do
    fake_reaper[k] = v
end

local defer_queue = {}
fake_reaper.defer = function(callback)
    DEFERING = true
    if RUNNING then
        defer_queue[#defer_queue + 1] = callback
    end
end

local script_vars = {
    FUNCTIONS = {},
    INIT = false,
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
    ultraschall = ULTRA_API and ultraschall,
    package = package
}

-- local function ParseError(er)
--     --local f_idx, n_idx = er:gmatch("_F(%d+)N(%d+)_")
-- end

function MakeFunc()
    local str = table.concat(CODE_STR)
    local func, err = load(str, "ScriptRun", "t", script_vars)
    if func then
        func()
    else
        r.ShowConsoleMsg("\nERROR LOADING SCRIPT : " .. err)
    end
end

function GenerateCode2(export)
    defer_queue = {}
    EXPORT = export or nil
    CODE_STR, blocks, InitFuncCalls = {}, {}, {}
    script_vars.INIT = INIT_SCRIPT_CODE

    local FUNCTIONS = GetFUNCTIONS()
    script_vars.FUNCTIONS = FUNCTIONS

    if not export then AddCode('\nif not INIT then goto run end\n') end
    AddVars(FUNCTIONS[1].NODES, 1, 0)
    CodeGen(TraceFlow(FUNCTIONS[1].NODES), 1, 0)
    if not export then AddCode('\n::run::') end
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
        AddCode('\nr.defer(Main)')
    else
        AddCode('\nMain()')
    end

    if ULTRA_API then
        table.insert(CODE_STR, 1,
            'if not ultraschall then ultraschall = dofile(r.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua") end\n')
    end
    table.insert(CODE_STR, 1, math_string .. '\n')
    table.insert(CODE_STR, 1, 'local r = reaper\n')

    ---------------------------DESCRIPTION-------------------------
    local gen_code = "-- GENERATED BY SPAGHETTI AI\n\n"
    local gen_desc =
    "-- SUFIX : FxNx \n-- F = FUNCTION ID \n-- N = NODE ID  \n\n"

    table.insert(CODE_STR, 1, 'NATIVE_SEPARATOR = package.config:sub(1, 1)')
    table.insert(CODE_STR, 1, gen_code)
    table.insert(CODE_STR, 1, gen_desc)


    --if export then r.ShowConsoleMsg(table.concat(CODE_STR)) end
    --r.ShowConsoleMsg(table.concat(CODE_STR))
    if not export then MakeFunc() end
end

function LoopNativeCode()
    local prev_defer_queue = defer_queue
    defer_queue = {}
    local FUNCTIONS = GetFUNCTIONS()
    script_vars.FUNCTIONS = FUNCTIONS
    for i = 1, #prev_defer_queue do
        local callback = prev_defer_queue[i]
        local status, err2 = pcall(callback)
        if err2 then
            r.ShowConsoleMsg("SCRIPT STOPED RUNNING BECAUSE OF ERROR : \n" .. err2)
        end
    end
    if INIT_SCRIPT_CODE then
        INIT_SCRIPT_CODE = false
        script_vars.INIT = INIT_SCRIPT_CODE
    end
    -- if CODE_MODIFIED and CODE_UPDATE then
    --     defer_queue = {}
    --     GenerateCode2()
    --     CODE_MODIFIED, CODE_UPDATE = nil, nil
    -- end
end
