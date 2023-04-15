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
    --["NIL"] = true,
    ["NUMBER"] = function(i_type) if i_type ~= "NUMBER" and i_type ~= "INTEGER" and i_type ~= "NUMBER/INTEGER" then return true end end,
    ["STRING"] = function(i_type) if i_type ~= "STRING" then return true end end,
    ["BOOLEAN"] = function(i_type) if i_type ~= "BOOLEAN" then return true end end,
    ["TABLE"] = function(i_type) if i_type ~= "TABLE" then return true end end,
    ["USERDATA"] = function(i_type) if i_type ~= "USERDATA" then return true end end,
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
    "REAPROJECT",
    "MEDIATRACK",
    "MEDIAITEM",
    "MEDIAITEM_TAKE",
    "TRACKENVELOPE",
    "PCM_SOURCE"
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
local function CheckInputType(node, NODES)
    if not node.fname:match("CUSTOM_TableGetVal") then return end
    if #node.outputs[1].connection == 0 then return end

    local missing = {}

    local target_node = In_TBL(NODES, node.outputs[1].connection[1].node)
    local target_pin = node.outputs[1].connection[1].pin
    local target_type = target_node.inputs[target_pin].type

    if target_type ~= "ANY" then
        local out_type = type(node.outputs[1].o_val):upper()
        if out_type == "USERDATA" then
            if target_type:find("IMGUI") then
                if not ValidateImgui(node.outputs[1].o_val) then
                    missing[#missing + 1] = target_type ..
                        " TYPE NOT COMPATIBLE WITH : " .. out_type
                end
            elseif RPR_TYPES[target_type] then
                if not ValidateRpr(node.outputs[1].o_val) then
                    missing[#missing + 1] = target_type ..
                        " TYPE NOT COMPATIBLE WITH : " .. out_type
                end
            else
                if ValidateImgui(node.outputs[1].o_val) then
                    missing[#missing + 1] = target_type ..
                        " TYPE NOT COMPATIBLE WITH : " .. ValidateImgui(node.outputs[1].o_val)
                elseif ValidateRpr(node.outputs[1].o_val) then
                    missing[#missing + 1] = target_type ..
                        " TYPE NOT COMPATIBLE WITH : " .. ValidateRpr(node.outputs[1].o_val)
                else
                    inp_types[out_type](target_type)
                    missing[#missing + 1] = target_type .. " TYPE NOT COMPATIBLE WITH : " .. out_type
                end
            end
        else
            if inp_types[out_type](target_type) then
                missing[#missing + 1] = target_type .. " TYPE NOT COMPATIBLE WITH : " .. out_type
            end
        end
    end
    if #missing ~= 0 then
        target_node.missing_arg = missing
        return true
    end
end

-- local function CheckInputType(node, NODES)
--     if not node.fname:match("CUSTOM_TableGetVal") then return end
--     local missing = {}
--     for i = 1, #node.inputs do
--         if node.in_values[i] then
--             if #node.inputs[i].connection ~= 0 and node.inputs[i].type ~= "ANY" then
--                 local prev_node = In_TBL(NODES, node.inputs[i].connection[1].node)
--                 local prev_pin = node.inputs[i].connection[1].pin
--                 local prev_type = prev_node.outputs[prev_pin].type
--                 if prev_type == "ANY" then
--                     local out_type = type(prev_node.outputs[prev_pin].o_val):upper()
--                     if out_type == "USERDATA" then
--                         if node.inputs[i].type:find("IMGUI") then
--                             if not ValidateImgui(prev_node.outputs[prev_pin].o_val) then
--                                 missing[#missing + 1] = node.inputs[i].type .. " TYPE NOT COMPATIBLE WITH : " .. out_type
--                             end
--                         elseif RPR_TYPES[node.inputs[i].type] then
--                             if not ValidateRpr(prev_node.outputs[prev_pin].o_val) then
--                                 missing[#missing + 1] = node.inputs[i].type .. " TYPE NOT COMPATIBLE WITH : " .. out_type
--                             end
--                         end
--                     else
--                         if inp_types[out_type](node.inputs[i].type) then
--                             missing[#missing + 1] = node.inputs[i].type .. " TYPE NOT COMPATIBLE WITH : " .. out_type
--                         end
--                     end
--                 end
--             end
--         end
--     end
--     if #missing ~= 0 then
--         node.missing_arg = missing
--         return true
--     end
-- end

-- local function CheckInputType(node)
--     local missing = {}
--     for i = 1, #node.inputs do
--         if node.in_values[i] then
--             local input_type = type(node.in_values[i]):upper()
--             if node.inputs[i].type ~= "ANY" then
--                 if inp_types[input_type](node.inputs[i].type) then
--                     -- if input_type ~= node.inputs[i].type then
--                     missing[#missing + 1] = node.inputs[i].type .. " TYPE NOT COMPATIBLE WITH : " .. input_type
--                 end
--             end
--         end
--     end
--     if #missing ~= 0 then
--         node.missing_arg = missing
--         return true
--     end
-- end

local function ArgumentsMissing(node)
    local missing = {}

    -- CHECK IF NUMBER OF INPUT_VALS MATCH NUMBER OF INPUTS (function arguments)
    for i = 1, #node.inputs do
        if node.in_values[i] == nil then
            missing[#missing + 1] = node.inputs[i].label
        end
        -- DONT ALLOW EMPTY STRINGS (IMGUI CRASHES ON EMPTY STRINGS) - BUT ALLOW IN CONCAT DELIMITER
        if type(node.in_values[i]) == "string" and node.fname ~= "CUSTOM_TableConcat" then
            if #node.in_values[i] == 0 then
                missing[#missing + 1] = node.inputs[i].label
            end
        end

        -- AVOID CONCATING NESTED TABLES
        if node.fname == "CUSTOM_TableConcat" then
            if node.in_values[i] then
                if type(node.in_values[i][1]) == "table" then
                    missing[#missing + 1] = "NESTED TABLE - CANOT CONCAT"
                end
            end
        end

        -- AVOID CRASH ON OUT OF BOUNDS
        if node.fname == "TableRemove" then
            if node.in_values[1] then
                if not node.in_values[1][node.in_values[2]] then
                    missing[#missing + 1] = "INDEX OUT OF BOUNDS"
                end
            end
        end

        if node.fname == "CUSTOM_TableGetVal" then
            if node.in_values[1] then
                if not node.in_values[1][node.in_values[2]] then
                    missing[#missing + 1] = "INDEX OUT OF BOUNDS"
                end
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

local function CollectArguments(node)
    for i = 1, #node.inputs do
        node.in_values[i] = #node.inputs[i].connection ~= 0 and node.inputs[i].o_val or node.inputs[i].i_val
    end
end

function Run_Flow(tbl, func_node)
    FOLLOW_WARNING = true
    for i = 1, #tbl do
        local node = tbl[i]
        local out_values

        if node.type == "func" then
            --ResetTableVars(node.NODES)
            ResetVars(node.NODES)
            local FLOW = TraceFlow(node.NODES)
            Run_Flow(FLOW, node)
        else
            ClearReturnValues(node)
            CollectArguments(node)
            if node.fname then
                if node.fname:find("CUSTOM_") then
                    out_values = { _G[node.fname](node, func_node, table.unpack(node.in_values)) }

                    if out_values[1] == "ERROR" then
                        if ArgumentsMissing(node) then
                            --if DEFERED_NODE then
                            -- DEFERED_NODE, DEFER, START_FLOW = nil, false, false
                            BREAK_RUN = true
                            --end
                            Deselect_all()
                            CHANGE_TAB = func_node.FID
                            break
                        end
                    end
                else
                    -- if CheckInputType(node, func_node.NODES) then
                    --     if DEFERED_NODE then
                    --         DEFERED_NODE, DEFER, START_FLOW = nil, false, false
                    --     end
                    --     Deselect_all()
                    --     CHANGE_TAB = func_node.FID
                    --     break
                    -- end
                    -- BREAK ONLY ON API CALL
                    if ArgumentsMissing(node) then
                        --if DEFERED_NODE then
                        -- DEFERED_NODE, DEFER, START_FLOW = nil, false, false
                        BREAK_RUN = true
                        --end
                        Deselect_all()
                        CHANGE_TAB = func_node.FID
                        break
                    end
                    out_values = { _G[node.fname](table.unpack(node.in_values)) }
                end
                UpdateReturnValues(node, out_values)
                if CheckInputType(node, func_node.NODES) then
                    --if DEFERED_NODE then
                    --    DEFERED_NODE, DEFER, START_FLOW = nil, false, false
                    BREAK_RUN = true
                    --end
                    Deselect_all()
                    CHANGE_TAB = func_node.FID
                    break
                end
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
        local NODES = FUNCTIONS[i].NODES
        --ResetTableVars(NODES)
        ResetVars(NODES)
        local FLOW = TraceFlow(NODES)
        Run_Flow(FLOW, FUNCTIONS[i])
        if BREAK_RUN then
            DEFERED_NODE = nil
            break
        end
    end
end
