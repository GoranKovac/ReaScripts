--@noindex
--NoIndex: true

local UNDO = {}
local UNDO_LIMIT = 10

local function RelinkMetatables(node)
    local FUNCTIONS = GetFUNCTIONS()
    --local node = func_tbl.NODES[n]
    if node.type == "func" then
        -- NODE HAS PARRENT FUNCTION
        if node.FID then
            -- RELINK FUNCTION NODES METATABLE
            node.NODES = {}
            setmetatable(node.NODES,
                {
                    __index = FUNCTIONS[node.FID].NODES,
                    __len = function() return #FUNCTIONS[node.FID].NODES end
                }
            )
        end
    end

    -- RELINK INPUT METATABLE
    for o = 1, #node.inputs do
        if next(node.inputs[o].connection) then
            local connected_node = GetNodeInfo(node.inputs[o].connection[1].node)
            setmetatable(node.inputs[o], {
                __index = connected_node.outputs[node.inputs[o].connection[1].pin]
            })
        end
    end

    -- RELINK MATH METATABLE
    if node.fname and node.fname:lower():find("math") then
        setmetatable(node.outputs[1], {
            __index = function(t, k)
                if k == "o_val" then return DoMath(node.inputs[2].i_val, node) end
            end,
        })
    elseif node.fname and node.fname:lower():find("std_") then
        setmetatable(node.outputs[1], {
            __index = function(t, k)
                if k == "o_val" then return DoStd(node.inputs[2].i_val, node) end
            end,
        })
    end

    -- RELINK GETTERS METATABLE
    if node.get then
        local source_node = GetNodeInfo(node.get)
        setmetatable(node.outputs[1], {
            __index = source_node.outputs[1],
        })
    end


    if node.set then
        -- RELINK API SETTER
        if node.set.api then
            local source_node = GetNodeInfo(node.set.guid)
            setmetatable(node.inputs[1], {
                __index = source_node.outputs[node.set.pin],
            })
        else
            -- RELINK VARIABLE SETTER
            local source_node = GetNodeInfo(node.set.guid)
            setmetatable(node.outputs[1], {
                __index = function(t, k)
                    if k == "get" then rawset(node.outputs[1], "o_val", source_node.outputs[1].o_val) end
                end,
                __newindex = function(t, k, v) if k == "set" then source_node.outputs[1].o_val = v end end
            })
        end
    end
end

function AddUndo(node, operation)
    if #UNDO == UNDO_LIMIT then
        table.remove(UNDO, 1)
    else
        UNDO[#UNDO + 1] = { node = Deepcopy(node), op_tbl = operation }
    end
end

local function RevertWires(node, wire_link)
    for i = 0, #node.inputs do
        if #node.inputs[i].connection ~= 0 then
            if node.inputs[i].connection[1].link == wire_link then
                local target_node = GetNodeInfo(node.inputs[i].connection[1].node)
                local target_pin = node.inputs[i].connection[1].pin

                target_node.outputs[target_pin].connection[#target_node.outputs[target_pin].connection + 1] = {
                    link = wire_link,
                    node = node.guid,
                    pin = i,
                }
            end
        end
    end
end

function DoUndo()
    if #UNDO == 0 then return end
    local last_node = UNDO[#UNDO].node
    local last_operation = UNDO[#UNDO].op_tbl
    if last_node then
        local FUNCTIONS = GetFUNCTIONS()
        if last_operation.op == "DELETE_WIRE" then
            RevertWires(last_node, last_operation.link)
        end

        local source_node, f, n = GetNodeInfo(last_node.guid)
        if source_node then
            FUNCTIONS[f].NODES[n] = last_node
            RelinkMetatables(FUNCTIONS[f].NODES[n])
        end
        table.remove(UNDO, #UNDO)
    end
end
