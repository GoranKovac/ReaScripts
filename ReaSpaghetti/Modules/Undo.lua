--@noindex
--NoIndex: true

local r = reaper

UNDO_STACK = {}
REDO_STACK = {}

local UNDO_LIMIT = 10

local function ProcessCmd(cmd)
    if cmd.type then
        if cmd.type == "connection" then
            cmd.apply(cmd.node_a, cmd.data)
        elseif cmd.type == "insert node" then
            cmd.apply(cmd.node_a)
        end
    end
end

local function ProcessUndo(top)
    if top.type then
        if top.type == "connection" then
            top.undo({ { link = top.data.link_guid } })
        elseif top.type == "insert node" then
            top.undo(top.data.NODES, top.data.n)
        end
    end
end

function ApplyCommand(cmd)
    if #UNDO_STACK == UNDO_LIMIT then
        table.remove(UNDO_STACK, 1)
    end
    UNDO_STACK[#UNDO_STACK + 1] = cmd
    ProcessCmd(cmd)
end

function UndoCommand()
    local top = table.remove(UNDO_STACK)
    if not top then return end
    REDO_STACK[#REDO_STACK + 1] = top
    ProcessUndo(top)
end

function RedoCommand()
    local top = table.remove(REDO_STACK)
    if not top then return end
    ApplyCommand(top)
end
