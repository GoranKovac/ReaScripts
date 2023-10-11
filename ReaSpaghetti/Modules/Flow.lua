--@noindex
--NoIndex: true
local r = reaper
for key in pairs(r) do _G[key] = r[key] end

local _G = _G

function GetChildFlow(called_node, func_node)
    local NODES = func_node.NODES
    called_node.LOOP_FLOW = {}
    for i = 1, #called_node.outputs do
        if called_node.outputs[i] then
            local loop_run = called_node.outputs[i].run == true and called_node.outputs[i].connection
            if loop_run then
                if next(loop_run) then
                    local next_node_guid = loop_run[1].node
                    while next_node_guid do
                        called_node.LOOP_FLOW[#called_node.LOOP_FLOW + 1] = In_TBL(NODES, next_node_guid)
                        local next_node = called_node.LOOP_FLOW[#called_node.LOOP_FLOW]
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
end

local function UpdateReturnValues(node, out_values)
    if not out_values then return end
    -- ASSIGN OUT TABLE TO CORESPONDING OUT PINS
    for i = 1, #out_values do
        if node.outputs[i] then node.outputs[i].o_val = out_values[i] end
    end
end
local inp_types = {
    ["NUMBER"] = function(i_type, org_val)
        local sub_type = math.type(org_val):upper()
        sub_type = sub_type == "FLOAT" and "NUMBER" or sub_type
        if not i_type:match(sub_type) then return sub_type end
        --if i_type ~= "NUMBER" and i_type ~= "INTEGER" and i_type ~= "NUMBER/INTEGER" then return true end
    end,
    ["STRING"] = function(i_type) if i_type ~= "STRING" then return "STRING" end end,
    ["BOOLEAN"] = function(i_type) if i_type ~= "BOOLEAN" then return "BOOLEAN" end end,
    ["TABLE"] = function(i_type) if i_type ~= "TABLE" then return "TABLE" end end,
    ["USERDATA"] = function(i_type) if i_type ~= "USERDATA" then return "USERDATA" end end,
}

local IMGUI_PTRS = {
    "ImGui_Context*",
    "ImGui_DrawList*",
    "ImGui_DrawListSplitter*",
    "ImGui_Font*",
    "ImGui_Image*",
    "ImGui_ImageSet*",
    "ImGui_ListClipper*",
    "ImGui_TextFilter*",
    "ImGui_Viewport*",
}

local RPR_PTRS = {
    "ReaProject*",
    "MediaTrack*",
    "MediaItem*",
    "MediaItem_Take*",
    "TrackEnvelope*",
    "PCM_source*"
}

local RPR_TYPES = {
    ["REAPROJECT"] = true,
    ["MEDIATRACK"] = true,
    ["MEDIAITEM"] = true,
    ["MEDIAITEM_TAKE"] = true,
    ["TRACKENVELOPE"] = true,
    ["PCM_SOURCE"] = true,
}

local function ValidateRpr(pointer)
    for i = 1, #RPR_PTRS do
        if r.ValidatePtr(pointer, RPR_PTRS[i]) then
            return RPR_PTRS[i]
        end
    end
    return false
end

local function ValidateImgui(pointer)
    for i = 1, #IMGUI_PTRS do
        if r.ImGui_ValidatePtr(pointer, IMGUI_PTRS[i]) then
            return IMGUI_PTRS[i]
        end
    end
    return false
end

-- CHECK TABLE GET SET COMPATIBLE WITH TARGET PINS (TABLE GET / SET TYPE IS ANY SO WE NEED TO CHECK VALUE TYPES)
function CheckInputType(node, val, NODES, get_set)
    if get_set == "GET" and #node.outputs[1].connection == 0 then return end
    if get_set == "SET" and #node.inputs[1].connection == 0 then return end
    local missing = {}

    local target_node = get_set == "GET" and
        In_TBL(NODES, node.outputs[1].connection[1].node) or
        In_TBL(NODES, node.inputs[1].connection[1].node)

    local target_pin = get_set == "GET" and node.outputs[1].connection[1].pin or nil
    local target_type = get_set == "GET" and target_node.inputs[target_pin].type or nil

    -- FIND KEY LABEL IF TABLE SET IS CALLED
    if get_set == "SET" then
        for k, v in ipairs(target_node.inputs) do
            if val[2] == v.label then
                -- TARGET PIN FOUND
                target_type = v.type
                target_pin = k
            end
        end
    end

    if target_type ~= "ANY" then
        local out_type = type(val[1]):upper()
        if out_type == "USERDATA" then
            if target_type:find("IMGUI") then
                if not ValidateImgui(val[1]) then
                    missing[#missing + 1] = target_type ..
                        " TYPE NOT COMPATIBLE WITH : " .. out_type
                end
            elseif RPR_TYPES[target_type] then
                if not ValidateRpr(val[1]) then
                    missing[#missing + 1] = target_type ..
                        " TYPE NOT COMPATIBLE WITH : " .. out_type
                end
            else
                if ValidateImgui(val[1]) then
                    missing[#missing + 1] = target_type ..
                        " TYPE NOT COMPATIBLE WITH : " .. ValidateImgui(val[1])
                elseif ValidateRpr(val[1]) then
                    missing[#missing + 1] = target_type ..
                        " TYPE NOT COMPATIBLE WITH : " .. ValidateRpr(val[1])
                else
                    inp_types[out_type](target_type)
                    missing[#missing + 1] = target_type .. " TYPE NOT COMPATIBLE WITH : " .. out_type
                end
            end
        else
            if val[1] ~= nil and target_type ~= nil then
                local other_type = inp_types[out_type](target_type, val[1])
                if other_type then
                    missing[#missing + 1] = target_type .. " TYPE NOT COMPATIBLE WITH : " .. other_type
                end
            end
        end
    end
    if #missing ~= 0 then
        if get_set == "GET" then
            target_node.missing_arg = missing
        else
            node.missing_arg = missing
        end
        return true
    end
end

local function ArgumentsMissing(node)
    local missing = {}

    -- CHECK IF NUMBER OF INPUT_VALS MATCH NUMBER OF INPUTS (function arguments)
    for i = 1, #node.inputs do
        --  SKIP OPTIONAL IF NON OR NOT USED
        if not node.inputs[i].opt or (node.inputs[i].opt and node.inputs[i].opt.use) then
            if node.in_values[i] == nil then
                missing[#missing + 1] = node.inputs[i].label
                -- break
            end

            -- DONT ALLOW EMPTY STRINGS (IMGUI CRASHES ON EMPTY STRINGS) - BUT ALLOW IN CONCAT DELIMITER
            if type(node.in_values[i]) == "string" and node.fname ~= "CUSTOM_TableConcat" then
                if #node.in_values[i] == 0 then
                    missing[#missing + 1] = "EMPTY STRING " .. node.inputs[i].label
                    --break
                end
            end

            -- AVOID CONCATING NESTED TABLES
            if node.fname == "CUSTOM_TableConcat" then
                if node.in_values[i] then
                    if type(node.in_values[i][1]) == "table" then
                        missing[#missing + 1] = "NESTED TABLE - CANOT CONCAT"
                        --   break
                    end
                end
            end

            -- AVOID CRASH ON OUT OF BOUNDS
            if node.fname == "TableRemove" then
                if node.in_values[1] then
                    if not node.in_values[1][node.in_values[2]] then
                        missing[#missing + 1] = "INDEX OUT OF BOUNDS"
                        --break
                    end
                end
            end

            if node.fname == "CUSTOM_TableGetVal" then
                if node.in_values[1] then
                    if not node.in_values[1][node.in_values[2]] then
                        missing[#missing + 1] = "INDEX OUT OF BOUNDS"
                        -- break
                    end
                else

                end
            end
            if node.fname == "CUSTOM_TableSetVal" then
                if node.in_values[1] then
                    if not node.in_values[1][node.in_values[2]] then
                        if type(node.in_values[2]) == "string" and #node.in_values[2] ~= 0 then
                            missing[#missing + 1] = "NON EXISTING KEY"
                        elseif type(node.in_values[2]) == "number" then
                            missing[#missing + 1] = "NON EXISTING KEY"
                        end
                        -- break
                    end
                end
            end

            if node.fname == "CUSTOM_CodeRun" then
                missing[#missing + 1] = "CODE ERROR"
            end
        end
    end

    -- INPUTS MISSMATCH SO ARGUMENTS ARE MISSING
    if #missing ~= 0 then
        node.missing_arg = missing
        return true
    end
end

local function ClearReturnValues(node)
    -- WE LINK OUTPUTS TO INPUTS SO WE CLEAR THEM FIRST ON EVERY NEW RUN
    for i = 1, #node.outputs do
        node.outputs[i].o_val = nil
    end
end

local function ClearTable(t)
    if not t then return end
    for i = #t, 1, -1 do t[i] = nil end
end

--! WE NEED TO CLEAR TABLE VARS ON EVERY RUN
--! PREVENTING NODE TABLE TO KEEP ADDING VALUES TO IT
--! EQUIVALENT TO
--! function main()
--!     T = {}
--!     table.insert(T,1)
--! end
local function ResetTableVars(tbl)
    for n = 1, #tbl do
        local node = tbl[n]
        if node.type == "t" then
            ClearTable(node.outputs[1].i_val)
            ClearTable(node.outputs[1].o_val)
        end
    end
end

--! WE NEED TO CLEAR TABLE VARS ON EVERY RUN
--! PREVENTING NODE TABLE TO KEEP ADDING VALUES TO IT OR VARIABLES NODES STORE THEIR UPDATED VALUE
--! EQUIVALENT TO
--! function main()
--!     local a = 15   -- i_val = 15   -> o_val == 15
--!     T = {}
--!     table.insert(T,1)
--!     a = 35         -- o_val = 35
--! end
local function ResetVars(tbl)
    for n = 1, #tbl do
        local node = tbl[n]
        if node.type == "s" or
            node.type == "i" or
            node.type == "f" or
            node.type == "b" then
            -- INPUT IS ALWAYS UNCHANGED SO RESET OUTPUT VALUE TO INPUT
            node.outputs[1].o_val = node.outputs[1].i_val
        elseif node.type == "t" then
            ClearTable(node.outputs[1].i_val)
            ClearTable(node.outputs[1].o_val)
        end
    end
end

local function CollectArguments(NODES, node)
    for i = 1, #node.inputs do
        if not node.inputs[i].opt or (node.inputs[i].opt and node.inputs[i].opt.use) then
            node.in_values[i] = #node.inputs[i].connection ~= 0 and node.inputs[i].o_val or node.inputs[i].i_val
        else
            node.in_values[i] = nil
        end
    end
end

function Run_Flow(tbl, func_node)
    FOLLOW_WARNING = true
    for i = 1, #tbl do
        local node = tbl[i]
        local out_values

        if node.type == "func" then
            ResetVars(node.NODES)
            local FLOW = TraceFlow(node.NODES)
            Run_Flow(FLOW, node)
        else
            ClearReturnValues(node)
            CollectArguments(func_node.NODES, node)
            if node.fname then
                if node.fname:find("CUSTOM_") then
                    out_values = { _G[node.fname](node, func_node, table.unpack(node.in_values)) }
                    if out_values[1] and out_values[1]:find("ERROR") then
                        if out_values[1] == "ERROR" then
                            ArgumentsMissing(node)
                        end

                        BREAK_RUN = true
                        Deselect_all()
                        CHANGE_FTAB = func_node.FID
                        break
                    end
                else
                    -- BREAK ONLY ON API CALL
                    if ArgumentsMissing(node) then
                        BREAK_RUN = true
                        Deselect_all()
                        CHANGE_FTAB = func_node.FID
                        break
                    end
                    if node.sp_api then
                        out_values = { ultraschall[node.fname](table.unpack(node.in_values)) }
                    else
                        out_values = { _G[node.fname](table.unpack(node.in_values)) }
                    end
                end
                UpdateReturnValues(node, out_values)
            end
        end
    end
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

function InitRunFlow()
    local start_func = DEFERED_NODE and 2 or 1
    local FUNCTIONS = GetFUNCTIONS()
    for i = start_func, 2 do
        if i == 1 then ResetTmpFunctionsTBL() end

        local NODES = FUNCTIONS[i].NODES
        ResetTableVars(NODES)
        ResetVars(NODES)
        local FLOW = TraceFlow(NODES)
        Run_Flow(FLOW, FUNCTIONS[i])
        if BREAK_RUN then
            DEFERED_NODE = nil
            break
        end
    end
end
