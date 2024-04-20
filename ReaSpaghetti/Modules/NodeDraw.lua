--@noindex
--NoIndex: true

local r = reaper

local pad_x, pad_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())

local min, max, abs, floor, log, sin, cos, huge = math.min, math.max, math.abs, math.floor, math.log, math.sin, math.cos,
    math.huge

local API_LIST = {}

DL = r.ImGui_GetWindowDrawList(ctx)

local FUNCTIONS = {}

local NODE_Buttons_LEFT = {
    [1] = { name = "i", func = function(self) self.toggle_comment = not self.toggle_comment end },
    -- [2] = { name = "", func = function(self)
    --     RV_COL, self.rgba = r.ImGui_ColorEdit4(ctx, 'MyColor##3' .. self.guid,
    --         self.rgba, r.ImGui_ColorEditFlags_NoInputs() | r.ImGui_ColorEditFlags_NoLabel())
    -- end },
}

local NODE_CFG = {
    MIN_W = 200,
    MIN_H = 100,
    SEGMENT = 30,
    ROUND_CORNER = 12,
    PIN_SIZE = 6,
    PIN_MOVE_OUT = 10,
    EDGE_THICKNESS = 2,
    PIN_BTN_W_EXTEND = 1.5, -- CANNOT BE 0 (EXTEND PIN HITBOX)
    LABEL_COL = 0x000000FF,
    PIN_LABEL_COL = 0xFFFFFFFF,
    INPUT_OFFSET = 70
}

WIRE_COL = 0x11BBFFFF
DELETE_COL = 0xFF1111FF

function CntSelNodes()
    local cnt_tbl = {}
    local NODES = GetCurFunctionNodes()
    for i = 1, #NODES do
        if NODES[i].selected then
            cnt_tbl[#cnt_tbl + 1] = NODES[i]
        end
    end
    return cnt_tbl
end

function GetFUNCTIONS()
    return FUNCTIONS
end

function GetNodeTBL()
    return GetCurFunctionNodes()
end

function GetCurFunctionNodes()
    return FUNCTIONS[CURRENT_FUNCTION].NODES
end

function GetFunctionNodes(guid)
    for i = 1, # FUNCTIONS do
        if In_TBL(FUNCTIONS[i].NODES, guid) then
            return FUNCTIONS[i].NODES
        end
    end
end

function GetFunctionNodeByFid(fid)
    local tbl = {}
    for i = 1, # FUNCTIONS do
        for n = 1, #FUNCTIONS[i].NODES do
            if FUNCTIONS[i].NODES[n].FID == fid then
                tbl[#tbl + 1] = FUNCTIONS[i].NODES[n]
            end
        end
    end
    return tbl
end

function GetNodeInfo(guid)
    for i = 1, # FUNCTIONS do
        local node, n = In_TBL(FUNCTIONS[i].NODES, guid)
        if node then return node, i, n end
    end
end

function GetApiTBL()
    return API_LIST
end

function GetVariableGETSETTBL()
    local NODES = GetCurFunctionNodes()
    local var_tbl = {}
    -- GET INIT FUNCTIONS
    if CURRENT_FUNCTION > 1 then
        for i = 1, #FUNCTIONS[1].NODES do
            if FUNCTIONS[1].NODES[i].type == "s" or
                FUNCTIONS[1].NODES[i].type == "i" or
                FUNCTIONS[1].NODES[i].type == "b" or
                FUNCTIONS[1].NODES[i].type == "t" or
                FUNCTIONS[1].NODES[i].type == "tc" or
                FUNCTIONS[1].NODES[i].type == "f" or
                --FUNCTIONS[1].NODES[i].type == "get" or
                FUNCTIONS[1].NODES[i].type == "api_var" then
                --FUNCTIONS[1].NODES[i].type == "set" then
                var_tbl[#var_tbl + 1] = FUNCTIONS[1].NODES[i]
            end
        end
    end
    --var_tbl[#var_tbl + 1] = "SEPARATOR"
    for i = 1, #NODES do
        if NODES[i].type == "s" or
            NODES[i].type == "i" or
            NODES[i].type == "f" or
            NODES[i].type == "b" or
            NODES[i].type == "t" or
            NODES[i].type == "tc" or
            --NODES[i].type == "get" or
            NODES[i].type == "api_var" then
            --NODES[i].type == "set" then
            var_tbl[#var_tbl + 1] = NODES[i]
        end
    end
    return var_tbl
end

function GetVariableTBL(NODES)
    local var_tbl = {}
    for i = 1, #NODES do
        if NODES[i].type == "s" or
            NODES[i].type == "i" or
            NODES[i].type == "f" or
            NODES[i].type == "t" or
            NODES[i].type == "b" then
            var_tbl[#var_tbl + 1] = NODES[i]
        end
    end
    return var_tbl
end

local NodeCOLOR = {
    ["func"]    = 0xFFceffff,
    ["retnode"] = 0xFFceffff,
    ["n"]       = 0x88ceffff,
    ["m"]       = 0x88ceffff,
    ["s"]       = 0x00ddffff,
    ["i"]       = 0xbeff85ff,
    ["f"]       = 0x88ceffff,
    ["b"]       = 0xd365ffff,
    ["t"]       = 0x618cffff,
    ["tc"]      = 0x618cffff, -- TABLE CONSTRUCTOR
    ["set"]     = 0xac5cd9ff,
    ["get"]     = 0x39da8aff,
    ["api"]     = 0x88ceffff, --88ceffff
    ["bg"]      = 0x28293dFF, --0x111111FF
    ["sel"]     = 0x00FF22FF,
    ["warning"] = 0xF44336FF,
    ["route"]   = 0x88ceffff,
    ["ws"]      = 0x88ceffff,
    ["wr"]      = 0x88ceffff,
    ["api_var"] = 0xac5cd9ff,
    ["group"]   = 0x00fffbff,
    ["groupbg"] = 0x00fffb11,
    ["code"]    = 0x88ceffff,
}

local PinCOLOR = {
    ["ANY"]            = 0x00FFFFFF,
    ["NUMBER/INTEGER"] = 0xfdad5aFF,
    ["INTEGER"]        = 0xF44336FF,
    ["NUMBER"]         = 0xfdad5aFF,
    ["STRING"]         = 0x00ddffff,
    ["BOOLEAN"]        = 0xd365ffff,
    ["TABLE"]          = 0x618cffff,
    ["RUN"]            = 0x11FF11FF,
    ["UNKNOWN"]        = 0xFFFFFFFF
}

local PinType = {
    -- ["ANY"]     = 1,
    ["INTEGER"] = 1,
    ["NUMBER"]  = 1,
    ["STRING"]  = 1,
    ["BOOLEAN"] = 1,
    --["TABLE"]   = 1,
    ["RUN"]     = 1,
}

-- DRAWING CHANNELS
local NodeDLChannel = {
    -- WIRE -- 2
    ["func"]    = 7,
    ["api"]     = 7,
    ["retnode"] = 7,
    ["s"]       = 7,
    ["i"]       = 7,
    ["f"]       = 7,
    ["b"]       = 7,
    ["n"]       = 7, --8 ACTIVE
    ["m"]       = 7, --8 ACTIVE
    ["t"]       = 7,
    ["tc"]      = 7,
    ["set"]     = 7,
    ["get"]     = 7,
    ["route"]   = 7,
    ["ws"]      = 7,
    ["wr"]      = 7,
    ["api_var"] = 7,
    ["group"]   = 5,
    ["code"]    = 7,
}

function Create_constant_tbl(type)
    local tbl = {}
    if type == "s" then
        tbl = { ins = {}, out = { { name = "", type = "STRING" } }, resizeable = true }
    elseif type == "i" then
        tbl = { ins = {}, out = { { name = "", type = "INTEGER" } } }
    elseif type == "f" then
        tbl = { ins = {}, out = { { name = "", type = "NUMBER" } } }
    elseif type == "b" then
        tbl = { ins = {}, out = { { name = "", type = "BOOLEAN" } } }
    elseif type == "t" then
        tbl = { ins = {}, out = { { name = "", type = "TABLE", def_val = {} } } }
    elseif type == "route" then
        tbl = { ins = {}, out = {}, run = "in/out" }
    elseif type == "ws" then
        tbl = { ins = {}, out = {}, run = "in", sender = r.genGuid(), wireless_id = r.genGuid() }
    elseif type == "wr" then
        tbl = {
            ins = {},
            out = {},
            run = "out",
        }
    elseif type == "tc" then
        tbl = {
            ins = {}, --ins = { { name = "TABLE", type = "TABLE" } },
            out = { { name = "TABLE", type = "TABLE" } },
            run = "in/out",
            fname = "CUSTOM_TableConstructor"
        }
    elseif type == "m" then
        tbl = { ins = {}, out = {}, run = "out", fname = "CUSTOM_FunctionStartArgs" }
    elseif type == "set" or type == "api_var" then
        tbl = {
            ins = { { name = "", type = "" } },
            out = { { name = "", type = "" } },
            run = "in/out",
            fname = "CUSTOM_Set"
        }
    elseif type == "get" then
        tbl = {
            ins = {},
            out = { { name = "", type = "" } },
        }
    elseif type == "func" then
        tbl = {
            ins = {},
            out = {},
            tab_open = false,
            FID = #FUNCTIONS + 1,
            NODES = InitStartNodes(),
            run = "in/out"
        }
    elseif type == "retnode" then
        tbl = {
            -- ins = { { name = "VAL", type = "ANY" } },
            ins = {},
            out = {},
            run = "in",
            fname = "CUSTOM_ReturnNode"
        }
    elseif type == "group" then
        tbl = {
            ins = {},
            out = {},
            --fname = "CUSTOM_ReturnNode"
            resizeable = true
        }
    elseif type == "code" then
        tbl = {
            ins = {
                { name = "CODE", type = "STRING" },
            },
            out = {
                --{ name = "", type = "NUMBER", def_val = 0.0 },
            },
            --resizeable = true,
            fname = "CUSTOM_CodeNodeRun",
            run = "in/out"
        }
    end
    return tbl
end

local function Socket(tbl, num, io_type)
    return {
        connection = {},
        type = tbl.type,
        label = tbl.name,
        pin = num,
        run = tbl.run,
        x = 0,
        y = 0,
        ---------------------------
        pin_disable = tbl.pin_disable,
        no_draw = tbl.no_draw,
        opt = tbl.opt,
        --def_val = tbl.def_val and (type(tbl.def_val) == "table" and {} or tbl.def_val) or nil,
        o_val = io_type == "out" and tbl.def_val or nil,
        i_val = io_type == "in" and tbl.def_val or nil,
        list = tbl.list,
    }
end

function CreateInputs(type, io_tbl, run_pin)
    local tbl = {}

    if run_pin and run_pin:find(type) then
        tbl[0] = Socket({ name = "RUN", type = "RUN" })
    end

    for i = 1, #io_tbl do
        tbl[#tbl + 1] = Socket(io_tbl[i], i, type)
    end
    return tbl
end

local function Get_Node(type, label, x, y, w, h, guid, tbl)
    return {
        type        = type,
        guid        = guid and guid or r.genGuid(),
        label       = label,
        fname       = tbl.fname,
        x           = x,
        y           = y,
        w           = w and w or (ORG_FONT_SIZE / 2) * utf8.len(label),
        h           = h and h or 0,
        inputs      = CreateInputs("in", tbl.ins, tbl.run),
        outputs     = CreateInputs("out", tbl.out, tbl.run),
        desc        = tbl.desc,
        selected    = false,
        NODES       = tbl.NODES,
        in_values   = {},
        get         = tbl.get,
        sender      = tbl.sender,
        receiver    = tbl.receiver,
        wireless_id = tbl.wireless_id,
        can_resize  = tbl.resizeable,
        sp_api      = tbl.sp_api
    }
end

function In_TBL(tbl, o_val)
    for i = 1, #tbl do if o_val == tbl[i].guid then return tbl[i], i end end
end

local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

function Filter_actions(filter_text, tbl)
    filter_text = Lead_Trim_ws(filter_text)
    local t = {}
    if filter_text == "" then return t end
    for i = 1, #tbl do
        local list = tbl[i]
        local name = list.label:lower()
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then t[#t + 1] = list end
    end
    return t
end

local function CreateNodeInsertLink(node)
    if node.fname and (node.fname:lower():find("math") or node.fname:lower():find("std_")) then return end
    if not INSERT_NODE_DATA then return end

    local data = INSERT_NODE_DATA

    -- MAKE LINK ONLY FOR RUN PIN (TOO COMPLEX TO MAKE OTHER PINS SINCE NODE CAN HAVE MULTIPLE OF SAME)
    local link_guid = data.link .. "-" .. node.guid .. ":" .. data.pin_type

    local dst_io_tbl = data.tbl_type == "in" and node.outputs or node.inputs

    local pin = INSERT_NODE_DATA.pin_type == "RUN" and dst_io_tbl[0] or dst_io_tbl[1]

    pin.connection[#pin.connection + 1] = { link = link_guid, node = data.node_guid, pin = data.pin_num }

    local NODES = GetNodeTBL()
    local source = In_TBL(NODES, data.node_guid)
    local src_pin_tbl = data.tbl_type == "in" and source.inputs or source.outputs

    -- LISTEN VALUES FROM SOURCE NODE (exclude run pin)
    if data.tbl_type == "in" and data.pin_type ~= "RUN" then
        setmetatable(src_pin_tbl[data.pin_num], {
            __index = node.outputs[1],
        })

        --LISTEN VALUES FROM CURRENT NODE
    elseif data.tbl_type == "out" and data.pin_type ~= "RUN" then
        setmetatable(node.inputs[1], {
            __index = src_pin_tbl[data.pin_num]
        })
    end

    src_pin_tbl[data.pin_num].connection[#src_pin_tbl[data.pin_num].connection + 1] = {
        link = link_guid,
        node = node.guid,
        pin = INSERT_NODE_DATA.pin_type == "RUN" and 0 or 1
    }
end

local function ApiSetterMetaFollower(node)
    local source_node = GetNodeInfo(INSERT_NODE_DATA.node_guid)

    node.outputs[1].type = INSERT_NODE_DATA.pin_type
    node.inputs[1].type = INSERT_NODE_DATA.pin_type

    node.outputs[1].label = INSERT_NODE_DATA.pin_type
    node.inputs[1].label = INSERT_NODE_DATA.pin_type

    setmetatable(node.inputs[1], {
        __index = source_node.outputs[INSERT_NODE_DATA.pin_num],
    })

    node.set = { api = true, guid = source_node.guid, pin = INSERT_NODE_DATA.pin_num }
end

local function SetterMetaFollower(node)
    if not GET_SET_NODE then return end
    local source_node = GET_SET_NODE

    node.outputs[1].type = source_node.outputs[1].type
    node.inputs[1].type = source_node.outputs[1].type

    setmetatable(node.outputs[1], {
        __index = function(t, k)
            if k == "get" then rawset(node.outputs[1], "o_val", source_node.outputs[1].o_val) end
        end,
        __newindex = function(t, k, v) if k == "set" then source_node.outputs[1].o_val = v end end
    })

    -- setmetatable(node.inputs[1], {
    --     __index = function(t, k) if k == "i_val" then return source_node.outputs[1].o_val end end,
    --     --__index = function(t, k) if k == "o_val" then return rawget(source_node.outputs[1], "o_val") end end,
    --     --__newindex = source_node.outputs[1]
    -- })

    node.set = { guid = source_node.guid, pin = 1 }
end

local function GetterMetaFollower(node)
    if not GET_SET_NODE then return end
    local source_node = GET_SET_NODE

    node.outputs[1].type = GET_SET_NODE.outputs[1].type

    -- GETTER ALWAYS HAS/READS 1 VALUE
    setmetatable(node.outputs[1], {
        __index = source_node.outputs[1],
        __newindex = source_node.outputs[1],
    })

    node.get = source_node.guid
end

local function OldMetatable()
    local results = {}
    setmetatable(results, { __mode = "kv" }) -- make values weak
    return results
end

function InsertNode(type, name, api_tbl)
    local node = AddNode(type, name, api_tbl)
    if type == "api_var" then
        ApiSetterMetaFollower(node)
    elseif type == "set" then
        SetterMetaFollower(node)
    elseif type == "get" then
        GetterMetaFollower(node)
    end

    node.x, node.y =
        (MOUSE_POPUP_X - (CANVAS.view_x + CANVAS.off_x)) / CANVAS.scale - node.w / 2,
        (MOUSE_POPUP_Y - (CANVAS.view_y + CANVAS.off_y)) / CANVAS.scale - (type == "wr" and node.h or 0)

    if type ~= "func" then
        -- SET MATH METATABLE (AUTOMATIC IN NODE CALCULATION)
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

        local NODES = GetNodeTBL()
        NODES[#NODES + 1] = node
        CreateNodeInsertLink(NODES[#NODES])
    else
        FUNCTIONS[#FUNCTIONS + 1] = node
    end
    INSERT_NODE_DATA = nil
end

function AddNode(type, name, api_tbl)
    if not api_tbl then
        api_tbl = Create_constant_tbl(type)
    end
    local NODES = GetNodeTBL()
    local receiver_guid = type == "wr" and NODES[#NODES].sender or nil
    local wireless_id = type == "wr" and NODES[#NODES].wireless_id or nil
    local w = (type == "group" or type == "s") and NODE_CFG.MIN_W or 100
    local h = (type == "group" or type == "s") and NODE_CFG.MIN_H or 50
    local node = Get_Node(type, name, 0, 0, w, h, receiver_guid or r.genGuid(), api_tbl)
    if type == "wr" then node.wireless_id = wireless_id end
    return node
end

local MAX_FX_SIZE = 300
FILTER = ''
function FilterBox()
    MOUSE_POPUP_X, MOUSE_POPUP_Y = r.ImGui_GetMousePosOnOpeningCurrentPopup(ctx)
    r.ImGui_PushItemWidth(ctx, MAX_FX_SIZE)
    if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end
    _, FILTER = r.ImGui_InputText(ctx, '##input', FILTER)
    local filtered_fx = Filter_actions(FILTER, API_LIST)
    r.ImGui_SetNextWindowPos(ctx, r.ImGui_GetItemRectMin(ctx), ({ r.ImGui_GetItemRectMax(ctx) })[2])
    local filter_h = #filtered_fx == 0 and 2 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx))
    if not SETTER_INFO and not INSERT_NODE_DATA then
        if #FILTER == 0 then
            if r.ImGui_Selectable(ctx, "ADD INTEGER", false) then
                InsertNode("i", "INTEGER")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD NUMBER(FLOAT)", false) then
                InsertNode("f", "NUMBER(FLOAT)")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD STRING", false) then
                InsertNode("s", "STRING")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD BOOLEAN", false) then
                InsertNode("b", "BOOLEAN")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD TABLE", false) then
                InsertNode("t", "TABLE")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD TABLE CONSTRUCTOR", false) then
                InsertNode("tc", "TABLE CONSTRUCTOR")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD RE-ROUTE NODE", false) then
                InsertNode("route", "R")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD WIRELESS ROUTE NODES", false) then
                InsertNode("ws", "SENDER")
                InsertNode("wr", "RECEIVER")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD GROUP NODE", false) then
                InsertNode("group", "GROUP")
                DIRTY = true
            end
            if r.ImGui_Selectable(ctx, "ADD CODE NODE", false) then
                InsertNode("code", "CODE")
                DIRTY = true
            end
        end
    end
    if r.ImGui_BeginChild(ctx, "##popupp", MAX_FX_SIZE, filter_h) then
        for i = 1, #filtered_fx do
            r.ImGui_PushID(ctx, i)
            if r.ImGui_Selectable(ctx, filtered_fx[i].label) then
                InsertNode("api", filtered_fx[i].label, filtered_fx[i])
                DIRTY = true
                r.ImGui_CloseCurrentPopup(ctx)
            end
            r.ImGui_PopID(ctx)
            -- DISABLE DRAG AND DROP FOR NOW
            -- if r.ImGui_IsItemActive(ctx) and r.ImGui_IsMouseDragging(ctx, 0) then
            --     if not DRAG_LIST_NODE then
            --         DRAG_LIST_NODE_ID = i
            --         DRAG_LIST_NODE = AddNode("api", filtered_fx[i].label, filtered_fx[i])
            --     end
            -- end
        end
        r.ImGui_EndChild(ctx)
    end
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

local function Get_Node_Screen_position(n)
    local x, y = CANVAS.view_x + CANVAS.off_x, CANVAS.view_y + CANVAS.off_y
    local n_x, n_y = x + (n.x * CANVAS.scale), y + (n.y * CANVAS.scale)
    local n_w, n_h = n.w * CANVAS.scale, n.h * CANVAS.scale
    return n_x, n_y, n_x + n_w, n_y + n_h, n_w, n_h
end

local function CalculateIOSize(node)
    local ins, outs = 0, 0
    for i = 1, #node.inputs do
        if not node.inputs[i].no_draw or not node.inputs[i].pin_disable then
            ins = ins + 1
        end
    end
    for i = 1, #node.outputs do
        if not node.outputs[i].no_draw or not node.outputs[i].pin_disable then
            outs = outs + 1
        end
    end
    return ins, outs
end

local function CalcMinCodeSize(node)
    if node.type ~= "code" then return end
    local ins, outs = CalculateIOSize(node)
    local total_ins = ins + outs
    local min_h = (total_ins * NODE_CFG.SEGMENT) + NODE_CFG.SEGMENT
    return min_h
    -- node.h = node.h < min_h and min_h or node.h
end

--! EXCLUDE NO DRAW PINS
local function AutoAdjust_Node_WH(node)
    if node.can_resize then
        --local min_h = CalcMinCodeSize(node)
        --node.h = node.h < min_h and min_h or node.h
        return
    end
    local ins, outs = CalculateIOSize(node)
    local total_ins = ins + outs
    node.h = (total_ins * NODE_CFG.SEGMENT) + NODE_CFG.SEGMENT
    --if node.type == "code" then
    --    node.h = CalcMinCodeSize(node)
    --end
    -- AUTO CALCULATE NODE W BY TEXT LENGHT
    local text_size = (ORG_FONT_SIZE / 2) * utf8.len(node.label)
    local w = node.type ~= "route" and text_size + (NODE_CFG.SEGMENT * 4) or NODE_CFG.SEGMENT
    node.w = w
    --if node.type == "code" then
    --     node.h = CalcMinCodeSize(node)
    --end
end

local function Check_Overlap(A, B, full_in)
    if not A or not B then return end
    local AX1, AY1, AX2, AY2 = Get_Node_Screen_position(A)
    local BX1, BY1, BX2, BY2 = Get_Node_Screen_position(B)
    if full_in then
        -- NODE IS FULLY ENCLOSED (EXCLUDE TITLEBAR)
        return AX1 <= BX1 and AY1 <= BY1 - (NODE_CFG.SEGMENT * CANVAS.scale) and AX2 >= BX2 and AY2 >= BY2
    else
        -- ANY OVERLAP
        return AX1 < BX2 and AX2 > BX1 and AY1 < BY2 and AY2 > BY1
    end
end

local function HasConnection(io_tbl, link)
    for i = 1, #io_tbl do
        if io_tbl[i].link == link then return i, io_tbl end
    end
end

function Delete_Wire(del_tbl, func_nodes)
    DIRTY = true
    local NODES = func_nodes or GetCurFunctionNodes()
    for i = #del_tbl, 1, -1 do
        local delete_link = del_tbl[i].link
        for n = 1, #NODES do
            local node = NODES[n]
            for k = #node.inputs, 0, -1 do
                if node.inputs[k] then
                    local link_idx = HasConnection(node.inputs[k].connection, delete_link)
                    if link_idx then
                        table.remove(node.inputs[k].connection, link_idx)
                        -- REMOVE LINK METATABLE
                        setmetatable(node.inputs[k], nil)
                        if #node.inputs[k].connection == 0 then node.inputs[k].o_val = nil end
                    end
                    --if #node.inputs[k].connection == 0 then node.inputs[k].o_val = nil end
                end
            end
            for k = #node.outputs, 0, -1 do
                if node.outputs[k] then
                    local link_idx = HasConnection(node.outputs[k].connection, delete_link)
                    if link_idx then
                        table.remove(node.outputs[k].connection, link_idx)
                        if #node.outputs[k].connection == 0 then
                            if node.outputs[k].type ~= "TABLE" then
                                node.outputs[k].o_val = nil
                            end
                        end
                    end
                    -- if #node.outputs[k].connection == 0 then
                    --     if node.outputs[k].type ~= "TABLE" then
                    --         node.outputs[k].o_val = nil
                    --     end
                    -- end
                end
            end
        end
    end
end

local function lerp(a, b, t) return a + (b - a) * t end

local function CubicBezier(p1, p2, p3, p4, time)
    local p5 = lerp(p1, p2, time) -- OFFSET TIME A BIT TO START LATE
    local p6 = lerp(p2, p3, time)
    local p7 = lerp(p3, p4, time)
    local p8 = lerp(p5, p6, time)
    local p9 = lerp(p6, p7, time)
    local p10 = lerp(p8, p9, time) -- OFFSET TIME A BIT TO END SOONER
    return p10
end

local function Calculate_Bezier_p2_p3_simple(xs, xe)
    local controlDistance = abs(xs - xe) / 2
    local p2_x = xs + controlDistance
    local p3_x = xe - controlDistance
    return p2_x, p3_x
end

-- local bb_offset = 10
-- local min_dist  = (10 * 10)
-- local function IsMouseOnBaz(x1, y1, x2, y2, p2_x, p3_x)
--     -- POPUP IS OPENED
--     if not r.ImGui_IsWindowFocused(ctx) then return end
--     if r.ImGui_IsAnyItemActive(ctx) then return end

--     local xs, xe = min(x1, x2), max(x1, x2)
--     local ys, ye = min(y1, y2), max(y1, y2)

--     if abs(ys - ye) < 5 then ys, ye = ys - bb_offset, ye + bb_offset end

--     -- IF MOUSE IS IN BEZIER BOUNDING BOX
--     if MX > xs and MX < xe and MY > ys and MY < ye then
--         local num_segments = 50
--         for i = 1, num_segments do
--             local point_x = CubicBezier(x1, p2_x, p3_x, x2, i / num_segments)
--             local point_y = CubicBezier(y1, y1, y2, y2, i / num_segments)
--             local dst_x, dst_y = MX - point_x, MY - point_y
--             local dst_sqrd = (dst_x * dst_x + dst_y * dst_y) / CANVAS.scale
--             -- IF MOUSE IS IN CLOSE DISTANCE OF THE CURVE RETURN TRUE
--             if dst_sqrd < min_dist then return true end
--         end
--     end
-- end

local START_TIME = r.time_precise()
local function Animate_On_Cordinates(begin_val, end_val, b2, b3, duration_in_sec, START_time, delay)
    local time = max(r.time_precise() - START_TIME, 0.01)
    if time >= duration_in_sec then START_TIME = r.time_precise() end
    local final_time = math.min((time / duration_in_sec - floor(time / duration_in_sec)) * 1, 1)
    local new_val = CubicBezier(begin_val, end_val, b2, b3, final_time)
    return new_val
end

local anim_duration = 2
local function Animated_Circles(xs, ys, xe, ye, col)
    local p2_x, p3_x = Calculate_Bezier_p2_p3_simple(xs, xe)
    local new_x      = Animate_On_Cordinates(xs, p2_x, p3_x, xe, anim_duration, START_TIME, 0)
    local new_y      = Animate_On_Cordinates(ys, ys, ye, ye, anim_duration, START_TIME, 0)
    r.ImGui_DrawList_AddCircleFilled(DL, new_x, new_y, 5 * CANVAS.scale, col) --0x00FF11FF
end

local BB_OFFSET = 15
local MIN_DST = 200
local function MouseCloseToBez(xs, ys, p2_x, ys, p3_x, ye, xe, ye)
    if MOVE_NODE then return end
    if r.ImGui_IsAnyItemHovered(ctx) then return end

    local X, Y, W, H = BEZIER.bounding_box(xs, ys, p2_x, ys, p3_x, ye, xe, ye)
    X = X - BB_OFFSET * CANVAS.scale
    Y = Y - BB_OFFSET * CANVAS.scale
    W = W + (BB_OFFSET * 2) * CANVAS.scale
    H = H + (BB_OFFSET * 2) * CANVAS.scale

    --DEBUG DRAW BOUNDING BOX
    --r.ImGui_DrawList_AddRect(DL, X, Y, X + W, Y + H, 0xFFFFFFFF)

    -- MOUSE IS IN BOUNDARY BOX
    if MX > X and MX < X + W and MY > Y and MY < Y + H then
        local d2, x, y, t = BEZIER.hit(MX, MY, xs, ys, p2_x, ys, p3_x, ye, xe, ye)
        if d2 < MIN_DST * CANVAS.scale then
            return true
        end
    end
end

-- local function MouseInNode(x, y, w, h)
--     if MX > x and MX < x + w and MY > y and MY < y + h then
--         return true
--     end
-- end

local function Draw_Beziar(xs, ys, xe, ye, color, th, link, node_o, node_i, pin_label, pins_i, pins_o)
    xs = xs + (NODE_CFG.PIN_MOVE_OUT * CANVAS.scale)
    xe = xe - (NODE_CFG.PIN_MOVE_OUT * CANVAS.scale)
    local p2_x, p3_x = Calculate_Bezier_p2_p3_simple(xs, xe)

    local mouse_on_baz = MouseCloseToBez(xs, ys, p2_x, ys, p3_x, ye, xe, ye)
    --local mouse_on_baz = IsMouseOnBaz(xs, ys, xe, ye, p2_x, p3_x)
    th = mouse_on_baz and 10 * CANVAS.scale or th

    --- TRACE INPUT OUTPUT OF NODE
    if node_o or node_i then
        if (node_o.trace or node_i.trace) then th = 10 * CANVAS.scale end
    end
    if pins_o or pins_i then
        if (pins_o.trace or pins_i.trace) then
            if ALT_DOWN then color = DELETE_COL end
            th = 10 * CANVAS.scale
        end
    end

    if ALT_DOWN and mouse_on_baz then
        color = DELETE_COL
        -- DELETE ONLY THIS WIRE
        if r.ImGui_IsMouseClicked(ctx, 0) then
            AddUndo(node_i, { op = "DELETE_WIRE", link = link })
            Delete_Wire({ { link = link } })
        end
    end

    r.ImGui_DrawList_AddBezierCubic(DL, xs, ys, p2_x, ys, p3_x, ye, xe, ye, color, th)
    if SHOW_FLOW then Animated_Circles(xs, ys, xe, ye, color) end
end

local function Draw_Wire(node, src_outputs)
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)
    local NODES = GetNodeTBL()
    local thick = 3.5 * CANVAS.scale
    for i = 0, #src_outputs do
        local output = src_outputs[i]
        if output then
            for j = 1, #src_outputs[i].connection do
                if src_outputs[i].connection[j] then
                    local link_guid = src_outputs[i].connection[j].link
                    local dst_data = src_outputs[i].connection[j]
                    local input_node = In_TBL(NODES, dst_data.node)
                    local input = input_node.inputs[dst_data.pin]
                    if HasConnection(input_node.inputs[dst_data.pin].connection, link_guid) then
                        Draw_Beziar(output.x, output.y, input.x, input.y,
                            PinCOLOR[output.type] or PinCOLOR["UNKNOWN"],
                            thick, --WIRE_COL
                            link_guid, node, input_node, output.label, input, output)
                    end
                end
            end
        end
    end
end

local function DrawPinLabel(node, pin_type, pin_tbl, name, s, x, y)
    if pin_tbl.no_draw then return end
    if name:find("RUN") then return end
    local FONT_SIZE = r.ImGui_GetFontSize(ctx)
    local txt_size_w

    if pin_type == "in" then
        -- ONLY DRAW REAPER SPECIFIC TYPES (EXCLUDE INT,FLOAT,STRING, BOOL)
        if PinType[pin_tbl.type] then
            if node.type == "tc" or node.type == "retnode" or node.type == "func" then
                txt_size_w = s
            else
                return
            end
        else
            txt_size_w = s
        end
    else
        txt_size_w = r.ImGui_CalcTextSize(ctx, name) + s
    end

    local txt_side_off = pin_type == "in" and x + txt_size_w + NODE_CFG.EDGE_THICKNESS * 2 * CANVAS.scale or
        x - txt_size_w - NODE_CFG.EDGE_THICKNESS * 2 * CANVAS.scale

    r.ImGui_DrawList_AddTextEx(DL, nil, FONT_SIZE,
        txt_side_off,
        y - FONT_SIZE / 2,
        NODE_CFG.PIN_LABEL_COL,
        name)
end

local function Draw_Pin_Button(dl, pin_tbl, name, node_id, pin_id, pin_type, x, y, s, btn_w, btn_h)
    local move_out = NODE_CFG.PIN_MOVE_OUT * CANVAS.scale
    local side_offset = pin_type == "in" and s + move_out or btn_w - s - move_out
    r.ImGui_SetCursorScreenPos(ctx, x - side_offset, y - btn_h)
    -- PIN BUTTON FOR DEBUGGING
    r.ImGui_InvisibleButton(ctx, "##" .. node_id .. pin_type .. pin_id, btn_w, btn_h * 2)

    local color = PinCOLOR[pin_tbl.type] or PinCOLOR["UNKNOWN"]

    local is_active = r.ImGui_IsItemActive(ctx) or
        r.ImGui_IsItemHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem())

    local is_connected = #pin_tbl.connection > 0

    color = (is_active and ALT_DOWN) and DELETE_COL or color

    color = (pin_tbl.opt and pin_tbl.opt.use == false) and (color & ~0x000000DD) or color

    if is_connected then
        r.ImGui_DrawList_AddCircleFilled(DL,
            x + (pin_type == "in" and -move_out or move_out), y,
            is_active and s * 1.5 or s,
            color)
    else
        r.ImGui_DrawList_AddCircle(DL, x + (pin_type == "in" and -move_out or move_out), y,
            is_active and ((math.sin(r.time_precise() * 8) + 5)) * CANVAS.scale or s / 1.2,
            color, 0, 2.5 * CANVAS.scale)
    end

    if pin_tbl.type == "NUMBER/INTEGER" then
        r.ImGui_DrawList_AddRectFilledMultiColor(dl, x + (pin_type == "in" and -move_out or move_out) - s, y - s,
            x + (pin_type == "in" and -move_out or move_out) + s, y + s,
            0xF44336FF, 0xfdad5aFF, 0xfdad5aFF, 0xF44336FF)
    end
end

local function Pin_Drag_Drop(pin, node, p_num, table_type)
    -- DO NOT ALLOW BRANCHING RUN OR RUN PINS IF ALREADY CONNECTED
    if pin.type == "RUN" and next(pin.connection) then return end
    -- DO NOT ALLOW BRANCHIN INPUTS
    if table_type == "in" and next(pin.connection) then return end

    if r.ImGui_BeginDragDropSource(ctx) then
        local connection_guid = node.guid .. ":" .. pin.label
        local pin_label = #pin.label ~= 0 and pin.label or "DUMMY"
        local dnd_data = { connection_guid, node.guid, table_type, pin.type, p_num, node.label, node.type, pin_label }
        r.ImGui_SetDragDropPayload(ctx, 'D&DP', table.concat(dnd_data, ","))
        r.ImGui_Text(ctx, pin.label)
        r.ImGui_EndDragDropSource(ctx)
    end

    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'D&DP')
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            -- NUMBER OF (.+) NEEDS TO MATCH ABOVE dnd_data NO MATTER ARE THEY USED OR NOT (OTHERWISE CONNECTING PINS DOES NOT WORK)
            local con_guid, node_guid, tbl_type, pin_type, pin_num, node_label = payload:match(
                "(.+),(.+),(.+),(.+),(.+),(.+),(.+),(.+)")
            -- DONT ALLOW CONNECTING PINS ON SAME NODE
            if node.guid == node_guid then return end

            -- DONT ALLOW CONNECTING PINS WITH DIFFERENT TYPE
            -- ALLOW SPECIAL ANY TYPE FOR CONSOLE MSGS (TO STRING FOR EXAMPLE CAN ACCEPT ANYTHING)
            if pin.type ~= pin_type then
                if pin.type == "ANY" or pin_type == "ANY" then
                    -- ALLOW CONNECTING TO ANY TYPE EXCEPT RUN
                    if pin.type == "RUN" or pin_type == "RUN" then
                        return
                    end
                    --elseif node.fname:match("Math") or
                    -- CHECK MATCH IN BOTH DIRECTIONS
                elseif node.label:match("Math") or node_label:match("Math") then
                    if not pin.type:match(pin_type) and not pin_type:match(pin.type) then
                        return
                    end
                elseif not node.label:match("Math") or not node_label:match("Math") then
                    if not pin.type:match(pin_type) and not pin_type:match(pin.type) then
                        -- PIN TYPES MISSMATCH
                        return
                    end
                end
            end

            -- DONT ALLOW BRANCHING RUN PIN (NO PARALLEL)
            if pin.type == "RUN" and next(pin.connection) then return end
            -- DONT ALLOW CONNECTING INPUT TO INPUT
            if table_type == tbl_type then return end
            -- DO NOT ALLOW BRANCHIN INPUTS
            if table_type == "in" and next(pin.connection) then return end

            local reverse_link_guid = node.guid .. ":" .. pin.label .. "-" .. con_guid
            local link_guid = con_guid .. "-" .. node.guid .. ":" .. pin.label

            -- CHECK IF CONNECTION EXIST IN BOTH DIRECTIONS (DO NOT ADD IF ALREADY HAS CONNECTION FROM ONE SIDE)
            if HasConnection(pin.connection, reverse_link_guid) then return end
            if HasConnection(pin.connection, link_guid) then return end

            local NODES = GetNodeTBL()
            local source = In_TBL(NODES, node_guid)

            pin.connection[#pin.connection + 1] = {
                link = link_guid,
                node = node_guid,
                pin = tonumber(pin_num),
            }

            -- LISTEN VALUES FROM SOURCE NODE (exclude run pin)
            if table_type == "in" and pin.type ~= "RUN" then
                setmetatable(node.inputs[p_num], {
                    __index = source.outputs[tonumber(pin_num)],
                    __newindex = source.outputs[tonumber(pin_num)],
                })
                -- LISTEN VALUES FROM CURRENT NODE
            elseif table_type == "out" and pin.type ~= "RUN" then
                setmetatable(source.inputs[tonumber(pin_num)], {
                    __index = node.outputs[p_num],
                })
            end

            local src_pin_tbl = tbl_type == "in" and source.inputs or source.outputs

            src_pin_tbl[tonumber(pin_num)].connection[#src_pin_tbl[tonumber(pin_num)].connection + 1] = {
                link = link_guid,
                node = node.guid,
                pin = p_num
            }
        end
    end
end

local function TraceNode()
    return (SHIFT_DOWN and r.ImGui_IsItemHovered(ctx))
end

local function CenterTextPush(o_val, pin_type)
    local tw = r.ImGui_CalcTextSize(ctx, o_val)
    local iw = r.ImGui_CalcItemWidth(ctx)

    --local pad_x, pad_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())

    --local need_text_center = true --(pin.type ~= "NUMBER") and true or false

    --local list_off = pin_type ~= "LIST" and 0 or 25 * CANVAS.scale
    --local pad_x, pad_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), pad_x, pad_y * CANVAS.scale)
end

local function DrawOptionalCheckbox(pin, node)
    if pin.opt then
        _, pin.opt.use = r.ImGui_Checkbox(ctx, "##OPT" .. pin.label .. node.guid, pin.opt.use)
        if r.ImGui_IsItemHovered(ctx) then
            if r.ImGui_BeginTooltip(ctx) then
                r.ImGui_PushFont(ctx, FONT_STATIC)
                r.ImGui_Text(ctx, "USE OPTIONAL")
                r.ImGui_PopFont(ctx)
                r.ImGui_EndTooltip(ctx)
            end
        end
        r.ImGui_SameLine(ctx)
    end
end

local function CheckOptional(pin)
    if pin.opt and pin.opt.use == false then
        return true
    end
end

local function Draw_input(node, io_type, pin, x, y, pin_n, h)
    if node.type == "tc" or node.type == "t" then return end
    if node.type == "api" and io_type == "out" then return end
    if node.type == "code" and io_type == "out" then return end
    --if node.type == "get" or node.type == "set" or node.type == "api_var" then return end

    -- OFFSET OUT X INSIDE THE NODE
    x = io_type == "out"
        and (x + NODE_CFG.EDGE_THICKNESS * CANVAS.scale) - node.w * CANVAS.scale
        or x + NODE_CFG.EDGE_THICKNESS * 3 * CANVAS.scale

    -- USE FULL NODE WIDTH FOR INTEGER,FLOAT,STRING NODES ("i", "f", "s")
    local w = io_type == "out"
        and node.w * CANVAS.scale - (NODE_CFG.EDGE_THICKNESS * 2 * CANVAS.scale)
        or node.w * CANVAS.scale - (NODE_CFG.EDGE_THICKNESS * 6 * CANVAS.scale)

    if not pin.no_draw then
        r.ImGui_SetCursorScreenPos(ctx, x, y - h - (1 * CANVAS.scale))
        --r.ImGui_SetNextItemWidth(ctx, pin.opt and w - 30 * CANVAS.scale or w)

        -- SHOW VALUES ON GETTERS SETTERS
        if (node.type == "get" or node.type == "set" or node.type == "api_var" or node.type == "func" or node.type == "m" or node.type == "retnode") and pin.type ~= "RUN" then
            r.ImGui_BeginDisabled(ctx)
            -- --! FIX PREFORMANCE CALLING MATH NODE HERE
            -- --! PERFORMANCE HOG
            -- local txt = tostring(pin.o_val)
            -- --local txt = "aaa"
            -- local tw = r.ImGui_CalcTextSize(ctx, txt)
            -- local iw = r.ImGui_CalcItemWidth(ctx)
            -- r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), math.max(0, (iw - tw) / 2),
            --     pad_y * CANVAS.scale)
            -- r.ImGui_InputText(ctx, '##', txt)
            -- r.ImGui_PopStyleVar(ctx)
            r.ImGui_EndDisabled(ctx)
            return
        end

        local current_input = #pin.connection == 0 and pin.i_val or pin.o_val

        local disable_input = (#pin.connection ~= 0 and io_type == "in") and true or false

        if disable_input then r.ImGui_BeginDisabled(ctx) end
        local id = node.guid .. pin_n
        r.ImGui_PushID(ctx, id)

        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), pad_x, pad_y * CANVAS.scale)

        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FrameRounding(), 5)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x17181fff)

        DrawOptionalCheckbox(pin, node)
        if CheckOptional(pin) then
            r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_DisabledAlpha(), 0.3)
            r.ImGui_BeginDisabled(ctx)
        end

        r.ImGui_SetNextItemWidth(ctx, pin.opt and w - 30 * CANVAS.scale or w)

        if pin.type == "INTEGER" then
            local separator = node.type == "i" and "" or " : "
            if node.type == "i" then
                I_RV, pin.i_val = r.ImGui_DragInt(ctx, "##" .. pin.label, pin.i_val, 1, 0, nil,
                    pin.label .. separator .. '%d%', r.ImGui_SliderFlags_AlwaysClamp())
                if I_RV then pin.o_val = pin.i_val end
            else
                -- if CheckOptional(pin) then
                --     r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_DisabledAlpha(), 0.3)
                --     r.ImGui_BeginDisabled(ctx)
                -- end
                current_input = type(current_input) == "string" and 0 or current_input
                _, pin.i_val = r.ImGui_DragInt(ctx, "##" .. pin.label, current_input, 1, 0, nil,
                    pin.label .. separator .. '%d%', r.ImGui_SliderFlags_AlwaysClamp())
                -- if CheckOptional(pin) then
                --     r.ImGui_PopStyleVar(ctx)
                --     r.ImGui_EndDisabled(ctx)
                -- end

                -- DrawOptionalCheckbox(pin)
            end
        elseif pin.type == "NUMBER/INTEGER" or pin.type == "NUMBER" then
            local separator = node.type == "f" and "" or " : "
            if node.type == "f" then
                current_input = type(current_input) == "string" and 0 or current_input

                F_RV, pin.i_val = r.ImGui_DragDouble(ctx, "##" .. pin.label, pin.i_val, 0.01, 0.0, 0.0,
                    pin.label .. separator .. '%.03f')
                if F_RV then pin.o_val = pin.i_val end
            else
                -- if CheckOptional(pin) then
                --     r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_DisabledAlpha(), 0.3)
                --     r.ImGui_BeginDisabled(ctx)
                -- end
                current_input = type(current_input) == "string" and 0 or current_input
                _, pin.i_val = r.ImGui_DragDouble(ctx, "##" .. pin.label, current_input, 0.01, 0.0, 0.0,
                    pin.label .. separator .. '%.03f')
                -- if CheckOptional(pin) then
                --     r.ImGui_PopStyleVar(ctx)
                --     r.ImGui_EndDisabled(ctx)
                -- end
                --DrawOptionalCheckbox(pin)
            end
        elseif pin.type == "STRING" then
            --local ins = CalculateIOSize(node)
            if node.type == "s" then
                if DEFERED_NODE then r.ImGui_BeginDisabled(ctx) end
                r.ImGui_PushFont(ctx, FONT_CODE)
                --S_RV, pin.i_val = r.ImGui_InputTextWithHint(ctx, "##" .. pin.label, pin.label, pin.i_val)
                S_RV, pin.i_val = r.ImGui_InputTextMultiline(ctx, "##" .. pin.label, pin.i_val, nil,
                    (node.h - NODE_CFG.SEGMENT - 8) * CANVAS.scale)
                r.ImGui_PopFont(ctx)
                if S_RV then pin.o_val = pin.i_val end
                if DEFERED_NODE then r.ImGui_EndDisabled(ctx) end
            else
                -- if CheckOptional(pin) then
                --     r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_DisabledAlpha(), 0.3)
                --     r.ImGui_BeginDisabled(ctx)
                -- end
                _, pin.i_val = r.ImGui_InputTextWithHint(ctx, "##" .. pin.label, pin.label, current_input)
                -- if CheckOptional(pin) then
                --     r.ImGui_PopStyleVar(ctx)
                --     r.ImGui_EndDisabled(ctx)
                -- end

                --DrawOptionalCheckbox(pin)
            end
        elseif pin.type == "BOOLEAN" then
            if node.type == "b" then
                B_RV, pin.i_val = r.ImGui_Checkbox(ctx, pin.label, pin.i_val)
                if B_RV then pin.o_val = pin.i_val end
            else
                -- if CheckOptional(pin) then
                --     r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_DisabledAlpha(), 0.3)
                --     r.ImGui_BeginDisabled(ctx)
                -- end

                _, pin.i_val = r.ImGui_Checkbox(ctx, pin.label, current_input)
                -- if CheckOptional(pin) then
                --     r.ImGui_PopStyleVar(ctx)
                --     r.ImGui_EndDisabled(ctx)
                -- end
            end
        elseif pin.type == "LIST" then
            if r.ImGui_BeginCombo(ctx, '##', pin.i_val) then
                for v in ipairs(pin.list) do
                    if r.ImGui_Selectable(ctx, pin.list[v], pin.i_val == pin.list[v]) then
                        pin.i_val = pin.list[v]
                    end
                end
                r.ImGui_EndCombo(ctx)
            end
            -- elseif pin.type == "CODE" then
            --     local ins = CalculateIOSize(node)
            --     r.ImGui_PushFont(ctx, FONT_CODE)
            --     --local total_io = ins + outs
            --     _, pin.i_val = r.ImGui_InputTextMultiline(ctx, '##text' .. node.guid, pin.i_val,
            --         (node.w - NODE_CFG.EDGE_THICKNESS * 6) * CANVAS.scale,
            --         (node.h - ins * NODE_CFG.SEGMENT - 10) * CANVAS.scale)
            --     r.ImGui_PopFont(ctx)
        end

        r.ImGui_PopStyleColor(ctx)
        r.ImGui_PopID(ctx)
        r.ImGui_PopStyleVar(ctx) -- Y PADDING FOR INPUT WIDGETS ZOOM
        r.ImGui_PopStyleVar(ctx) -- ROUNDING

        --
        if CheckOptional(pin) then
            r.ImGui_PopStyleVar(ctx)
            r.ImGui_EndDisabled(ctx)
        end
        if disable_input then r.ImGui_EndDisabled(ctx) end
        --DrawOptionalCheckbox(pin)
        --r.ImGui_PopStyleVar(ctx) -- FRAME BOARDER
        --r.ImGui_PopStyleVar(ctx) -- FRAME BOARDER
    end
end

local function Draw_IO(active_ch, node, pins, x, y, pin_type)
    --! check bellow maybe not needed anymore
    if not next(pins) then return end
    local pin_size = NODE_CFG.PIN_SIZE * CANVAS.scale
    local pin_button_w = (pin_size * 2) * NODE_CFG.PIN_BTN_W_EXTEND
    local pin_button_h = NODE_CFG.SEGMENT / 2 * CANVAS.scale
    local ins, outs = CalculateIOSize(node)

    --local pin_io_offset = pin_type == "in" and outs * CANVAS.scale or 0
    local pin_io_offset = pin_type == "out" and ins * CANVAS.scale or 0
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, active_ch)

    y = y - pin_button_h + (pin_io_offset * NODE_CFG.SEGMENT)
    for i = 0, #pins do
        if pins[i] then
            local pin = pins[i]

            local py = i == 0 and y - (pin_io_offset * NODE_CFG.SEGMENT) or y
            local label = pin.label
            pin.x, pin.y = x, py

            DrawPinLabel(node, pin_type, pin, pin.label, pin_size, x, py)

            Draw_input(node, pin_type, pin, x, py, i, (pin_button_h / 2) + (pin_size / 2))

            --! SKIP DRAWING IF PIN IS DISABLED
            if not pin.pin_disable then
                Draw_Pin_Button(DL, pin, label, node.guid, i, pin_type, x, py, pin_size, pin_button_w, pin_button_h)

                pin.trace = r.ImGui_IsItemHovered(ctx)

                local pin_drag = r.ImGui_IsItemActive(ctx)

                if INSERT_NODE_DATA then
                    pin_drag =
                        (INSERT_NODE_DATA.node_guid == node.guid and
                            INSERT_NODE_DATA.tbl_type == pin_type and
                            INSERT_NODE_DATA.pin_num == i) and
                        true
                end

                if pin_drag then
                    local new_MX = MOUSE_POPUP_X and MOUSE_POPUP_X or MX
                    local new_MY = MOUSE_POPUP_Y and MOUSE_POPUP_Y or MY
                    Draw_Beziar(
                        pin_type == "out" and x or new_MX - (NODE_CFG.PIN_MOVE_OUT * CANVAS.scale),
                        pin_type == "out" and py or new_MY,
                        pin_type == "out" and new_MX + (NODE_CFG.PIN_MOVE_OUT * CANVAS.scale) or x,
                        pin_type == "out" and new_MY or py,
                        PinCOLOR[pin.type] or PinCOLOR["UNKNOWN"], 5)
                end

                if r.ImGui_IsItemClicked(ctx, 0) and ALT_DOWN then
                    -- DELETE EVERY CONNECTION ON THIS PIN
                    Delete_Wire(pins[i].connection)
                end

                Pin_Drag_Drop(pin, node, i, pin_type)
            end
        end
        --! DONT INCREMENT Y IF PIN IS SET NOT TO DRAW
        if pins[i] and pins[i].no_draw then
        else
            y = y + NODE_CFG.SEGMENT * CANVAS.scale
        end
    end
end

local function Node_Label(dl, node, x, y, w, h)
    local label_size = r.ImGui_CalcTextSize(ctx, node.label)
    local FONT_SIZE = r.ImGui_GetFontSize(ctx)
    local col = NODE_CFG.LABEL_COL
    r.ImGui_DrawList_AddTextEx(dl, nil, FONT_SIZE, x + (w / 2) - label_size / 2, y + (h / 2) - FONT_SIZE / 2, col,
        node.label)
end

function Deselect_all()
    local NODES = GetCurFunctionNodes()
    for i = 1, #NODES do NODES[i].selected = false end
end

local function MarqeeSelectNode(n)
    if not MARQUEE then return end
    if not MOVE_NODE then
        if not Check_Overlap(n, MARQUEE, true) then
            if not MARQUEE_SHIFT then
                n.selected = Check_Overlap(MARQUEE, n)
            else
                if not n.selected then
                    n.selected = Check_Overlap(MARQUEE, n)
                end
            end
        else
            n.selected = false
        end
    end
end

local FIRST_SELECT
local function ClickSelectNode(node)
    if r.ImGui_IsMouseDown(ctx, 0) then
        if r.ImGui_IsItemClicked(ctx, 0) then
            -- STORE FIRST CLICKED NODE
            if not FIRST_SELECT then FIRST_SELECT = node end
            if not node.selected then
                if not SHIFT_DOWN and not CTRL_DOWN then Deselect_all() end
                if not CTRL_DOWN then
                    FIRST_SELECT.selected = true
                end
            end
        end
        -- IF MOUSE DID NOT MOVE THEN JUST SELECT FIRST NODE
    elseif FIRST_SELECT and (DRAGX == 0 and DRAGY == 0) then
        if r.ImGui_IsMouseReleased(ctx, 0) then
            if not SHIFT_DOWN and not CTRL_DOWN then Deselect_all() end
            if CTRL_DOWN then
                FIRST_SELECT.selected = not FIRST_SELECT.selected
            else
                FIRST_SELECT.selected = true
            end
        end
        FIRST_SELECT = nil
    end
end

local function MoveNode(node)
    --if DRAG_COPY then return end
    if not MOVE_NODE then return end
    if r.ImGui_IsMouseDown(ctx, 0) then
        --r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeAll())
        --if r.ImGui_IsMouseDragging(ctx, 0) then
        local off_x, off_y = 0, 0
        if EDGE_SCROLLING then
            off_x = EDGE_SCROLLING.x / CANVAS.scale
            off_y = EDGE_SCROLLING.y / CANVAS.scale
        end
        if node.selected then
            node.x = node.x + DX / CANVAS.scale - off_x
            node.y = node.y + DY / CANVAS.scale - off_y
        end
    elseif r.ImGui_IsMouseReleased(ctx, 0) then
        MOVE_NODE = nil
    end
end

local function DrawOffSceenHelper(x, y, xe, ye)
    local posx, posy = "", ""

    if xe < CANVAS.view_x then
        posx = "LEFT"
    elseif x > CANVAS.view_x + CANVAS.rx then
        posx = "RIGHT"
    end
    if y < CANVAS.view_y then
        posy = "TOP"
    elseif y > CANVAS.view_y + CANVAS.ry then
        posy = "BOT"
    end

    local pos = posx .. posy

    local test = {
        ["LEFT"] = { x = CANVAS.view_x, y = y },
        ["LEFTTOP"] = { x = CANVAS.view_x, y = CANVAS.view_y },
        ["LEFTBOT"] = { x = CANVAS.view_x, y = CANVAS.view_y + CANVAS.ry - 50 },
        ["RIGHT"] = { x = CANVAS.view_x + CANVAS.rx - 50, y = y },
        ["RIGHTTOP"] = { x = CANVAS.view_x + CANVAS.rx - 50, y = CANVAS.view_y },
        ["RIGHTBOT"] = { x = CANVAS.view_x + CANVAS.rx - 50, y = CANVAS.view_y + CANVAS.ry - 50 },
        ["TOP"] = { x = x, y = CANVAS.view_y },
        ["BOT"] = { x = x, y = CANVAS.view_y + CANVAS.ry - 50 },
    }

    r.ImGui_SetCursorScreenPos(ctx, test[pos].x, test[pos].y)
    r.ImGui_Button(ctx, "HELPER", 50, 50)
end

local function Warning_box(node, x, y)
    if FOLLOW_WARNING then
        node.selected = true
        CenterNodeToScreen(node)
        FOLLOW_WARNING = nil
    end
    r.ImGui_PushFont(ctx, FONT_STATIC)
    local txt = "WARNING MISSING INPUTS! \n\n" .. table.concat(node.missing_arg, "\n")

    local w, h = r.ImGui_CalcTextSize(ctx, txt)
    r.ImGui_SetNextWindowPos(ctx, x + 5, y - 10 - h)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x110000FF)

    if r.ImGui_BeginChild(ctx, "##warning_ch" .. node.guid, (w + 15), (h + 10), 10, r.ImGui_WindowFlags_NoInputs()
            | r.ImGui_WindowFlags_NoDecoration()
            | r.ImGui_WindowFlags_NoMove()
            | r.ImGui_WindowFlags_NoSavedSettings()
            | r.ImGui_WindowFlags_AlwaysAutoResize()
            | r.ImGui_WindowFlags_NoDocking()
            | r.ImGui_WindowFlags_NoFocusOnAppearing()
            | r.ImGui_WindowFlags_TopMost()
        ) then
        r.ImGui_Text(ctx, txt)
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopFont(ctx)
    r.ImGui_PopStyleColor(ctx)
end

local function RenameInPlace(node, x, y, w, title_h)
    r.ImGui_SetCursorScreenPos(ctx, x, y + title_h / 8)
    r.ImGui_SetNextItemWidth(ctx, w)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x000000FF)
    r.ImGui_PushFont(ctx, FONT)
    CenterTextPush(node.label, "RUN")
    r.ImGui_SetKeyboardFocusHere(ctx)
    _, node.label = r.ImGui_InputText(ctx, "##RN", node.label)
    if ENTER or ESC or (not r.ImGui_IsItemActive(ctx) and r.ImGui_IsMouseClicked(ctx, 0)) then
        RENAME_NODE = nil
    end
    r.ImGui_PopFont(ctx)
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_PopStyleVar(ctx)
end

function UpdateChildFunctionsNames(fid, name)
    for f = 1, #FUNCTIONS do
        for n = 1, #FUNCTIONS[f].NODES do
            local node = FUNCTIONS[f].NODES[n]
            if node.FID == fid then node.label = name end
        end
    end
end

function UpdateChildFunctionsIO(fid, io, i, name)
    for f = 1, #FUNCTIONS do
        for n = 1, #FUNCTIONS[f].NODES do
            local node = FUNCTIONS[f].NODES[n]
            if node.FID == fid then
                local io_tbl = io == "ARG" and node.inputs or node.outputs
                io_tbl[i].label = name
            end
        end
    end
end

function UpdateChildFunctions(fid, io, add_remove_update, tbl, pin_num, pin_type)
    for f = 1, #FUNCTIONS do
        for n = 1, #FUNCTIONS[f].NODES do
            local node = FUNCTIONS[f].NODES[n]
            if node.FID == fid then
                local node_io_tbl = io == "ARG" and node.inputs or node.outputs
                if add_remove_update == "add" then
                    local ins = { { name = "ARG " .. #FUNCTIONS[CURRENT_FUNCTION].inputs, type = "INTEGER" } }
                    local out = { { name = "RET " .. #FUNCTIONS[CURRENT_FUNCTION].outputs, type = "INTEGER" } }
                    -- r.ShowConsoleMsg("ADD\n")
                    node_io_tbl[#node_io_tbl + 1] = io == "ARG" and CreateInputs("in", ins)[1] or
                        CreateInputs("out", out)[1]
                    --tbl
                elseif add_remove_update == "remove" then
                    -- REMOVE ANY CONNECTION TO THIS PIN
                    Delete_Wire(node_io_tbl[#node_io_tbl].connection, FUNCTIONS[f].NODES)
                    table.remove(node_io_tbl, #node_io_tbl)
                elseif add_remove_update == "update" then
                    node_io_tbl[pin_num].type = pin_type
                end
            end
        end
    end
end

local function DrawTooltip(dsc)
    if not TOOLTIP then return end
    if MOVE_NODE then return end
    if not dsc or #dsc == 0 then return end
    if r.ImGui_IsItemHovered(ctx) then
        if r.ImGui_BeginTooltip(ctx) then
            r.ImGui_PushFont(ctx, FONT_STATIC)
            r.ImGui_Text(ctx, dsc)
            r.ImGui_PopFont(ctx)
            r.ImGui_EndTooltip(ctx)
        end
    end
end

local function GetGroupChildNodes(node, NODES)
    if node.type ~= "group" then return end
    if not MOVE_NODE then
        local tmp_childs = {}
        for i = 1, #NODES do
            -- GROUP NODE OVERLAPS WITH CHILD NODE
            if Check_Overlap(node, NODES[i], true) then
                tmp_childs[#tmp_childs + 1] = NODES[i].guid
                NODES[i].has_parent = node.guid
            else
                -- IF CHILD NODE HAS PARENT CHECK IS IT STILL WITHIN IT
                if NODES[i].has_parent then
                    if not Check_Overlap(In_TBL(NODES, NODES[i].has_parent), NODES[i], true) then
                        NODES[i].has_parent = false
                    end
                end
            end
        end
        node.childs = tmp_childs
    elseif MOVE_NODE and MOVE_NODE == node.guid then
        if node.childs and #node.childs ~= 0 then
            local off_x, off_y = 0, 0
            if EDGE_SCROLLING then
                off_x = EDGE_SCROLLING.x / CANVAS.scale
                off_y = EDGE_SCROLLING.y / CANVAS.scale
            end
            for i = 1, #node.childs do
                -- for k in pairs(node.childs) do
                local child_node = In_TBL(NODES, node.childs[i])
                -- EXCLUDE SELECTED CHILDS SINCE THEY ARE MOVED ANYWAY
                if child_node and not child_node.selected then
                    child_node.x = child_node.x - off_x + DX / CANVAS.scale
                    child_node.y = child_node.y - off_y + DY / CANVAS.scale
                end
            end
        end
    end
end

local function CalculateNewSize(node)
    local off_x, off_y = 0, 0
    if EDGE_SCROLLING then
        off_x = EDGE_SCROLLING.x / CANVAS.scale
        off_y = EDGE_SCROLLING.y / CANVAS.scale
    end

    --local min_h = NODE_CFG.MIN_H --node.type == "group" and NODE_CFG.MIN_H or CalcMinCodeSize(node)

    local new_w = node.w + DX > NODE_CFG.MIN_W and node.w - off_x + DX / CANVAS.scale or NODE_CFG.MIN_W
    local new_h = node.h + DY > NODE_CFG.MIN_H and node.h - off_y + DY / CANVAS.scale or NODE_CFG.MIN_H
    node.w = new_w
    node.h = new_h
end

local function Draw_Toolbar_Button(btn, node, btn_n, x, y, s, c)
    r.ImGui_SetCursorScreenPos(ctx, x, y)
    if r.ImGui_InvisibleButton(ctx, btn.name .. "##" .. node.guid .. btn_n, s, s) then
        btn.func(node)
    end
    r.ImGui_DrawList_AddCircleFilled(DL, x + s / 2, y + s / 2, s / 3,
        r.ImGui_IsItemHovered(ctx) and c | 0x66666600 or c)
    local FONT_SIZE = r.ImGui_GetFontSize(ctx)
    r.ImGui_DrawList_AddTextEx(DL, nil, FONT_SIZE, x + s / 1.8 - FONT_SIZE / 4, y + s / 2 - FONT_SIZE / 2,
        0xFFFFFFFF, btn.name)
end

local function NodeDoubleClick(node)
    if node.type == "func" then
        CHANGE_FTAB = node.FID
        GetFUNCTIONS()[CHANGE_FTAB].tab_open = true
        CHANGE_MTAB = "FUNC"
    end
end

local function Draw_Node(node)
    AutoAdjust_Node_WH(node)
    local x, y, xe, ye, w, h = Get_Node_Screen_position(node)
    --if not MOUSE_IN_NODE then
    --MOUSE_IN_NODE = MouseInNode(x, y, w, h)
    --end
    local title_h = NODE_CFG.SEGMENT * CANVAS.scale
    local edge_thickness = NODE_CFG.EDGE_THICKNESS * CANVAS.scale
    local edge_offset = edge_thickness / 2

    local has_body = #node.inputs ~= 0 or #node.outputs ~= 0 or node.can_resize
    local sel = node.selected

    if node.missing_arg then
        Warning_box(node, x, y)
    end

    --node.vis = r.ImGui_IsRectVisibleEx(ctx, x, y, xe, ye)

    if sel and not node.vis then
        --    DrawOffSceenHelper(x, y, xe, ye)
    end

    local active_ch = sel and NodeDLChannel[node.type] + 1 or NodeDLChannel[node.type]
    ---- DRAW NODE
    r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, active_ch)
    -- BG
    r.ImGui_DrawList_AddRectFilled(DL, x, y, xe, ye,
        node.missing_arg and NodeCOLOR["warning"] or (node.type == "group" and NodeCOLOR["groupbg"] or NodeCOLOR["bg"]),
        NODE_CFG.ROUND_CORNER * CANVAS.scale)

    -- TITLE BG
    r.ImGui_DrawList_AddRectFilled(DL, x, y, xe, y + title_h - 2 * CANVAS.scale,
        node.rgba ~= 0x00000000 and node.rgba or NodeCOLOR[node.type],
        NODE_CFG.ROUND_CORNER * CANVAS.scale, has_body and r.ImGui_DrawFlags_RoundCornersTop() or 0)

    if sel then
        --local expand = 1 * CANVAS.scale
        r.ImGui_DrawList_AddRect(DL, x, y, xe, ye, NodeCOLOR["sel"],
            NODE_CFG.ROUND_CORNER * CANVAS.scale, nil,
            edge_thickness * 1.5)
    end
    -- LABEL
    if RENAME_NODE and RENAME_NODE.guid == node.guid then
        RenameInPlace(node, x, y, w, title_h)
    else
        Node_Label(DL, node, x, y, w, title_h)
    end

    for i = 1, 2 do                              --#NODE_Buttons_LEFT do
        local button = NODE_Buttons_LEFT[i]
        local distance = x + (title_h * (i - 1)) -- OFFSET FROM LEFT
        --local distance = xe - (title_h * i) -- OFFSET FROM RIGHT
        if i == 1 then
            if (RENAME_NODE and RENAME_NODE.guid ~= node.guid) or not RENAME_NODE then
                if node.type ~= "route" then
                    Draw_Toolbar_Button(button, node, i, distance, y, title_h, NodeCOLOR["bg"])
                    if r.ImGui_IsItemHovered(ctx) then DrawTooltip(node.desc) end
                end
            end
        elseif i == 2 then
            -- r.ImGui_SetCursorScreenPos(ctx, distance + 10, y + title_h / 2 - 12)
            -- RV_COL, node.rgba = r.ImGui_ColorEdit4(ctx, 'MyColor##3' .. node.guid,
            --     node.rgba ~= 0x00000000 and node.rgba or NodeCOLOR[node.type],
            --     r.ImGui_ColorEditFlags_NoInputs() | r.ImGui_ColorEditFlags_NoLabel())
        end
    end
    -- CENTER NEXT BUTTON IN THE FRAME
    x, y = x + edge_offset, y + edge_offset
    w, h = w - edge_offset, h - edge_offset

    -- NODE BUTTON
    r.ImGui_SetCursorScreenPos(ctx, x, y)
    r.ImGui_InvisibleButton(ctx, "##" .. node.guid, w - edge_offset, title_h - edge_offset)
    if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
        NodeDoubleClick(node)
    end

    ---- DRAW NODE
    node.trace = TraceNode()
    MarqeeSelectNode(node)
    ClickSelectNode(node)

    if not MOVE_NODE then
        MOVE_NODE = r.ImGui_IsItemActive(ctx) and node.guid or nil
    end

    --DrawTooltip(node.desc)
    --MoveNode(node)

    -- if node.can_resize then
    --     r.ImGui_SetCursorScreenPos(ctx, x + w - (10 * CANVAS.scale), h + y - (10 * CANVAS.scale))
    --     r.ImGui_Button(ctx, '##RS' .. node.guid, (10 * CANVAS.scale), (10 * CANVAS.scale))
    --     if r.ImGui_IsItemHovered(ctx) or r.ImGui_IsItemActive(ctx) then
    --         r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeNWSE())
    --     end
    --     if r.ImGui_IsItemActive(ctx) then
    --         CalculateNewSize(node)
    --         --CalcMinCodeSize(node)
    --     end
    -- end


    if node.toggle_comment then
        --local pad_y = select(2, r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding()))
        local _, th = r.ImGui_CalcTextSize(ctx, tostring(node.text) .. '\x20')
        th = th + (pad_y * 2)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x00000088)
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FrameBorderSize(), 1)
        r.ImGui_SetCursorScreenPos(ctx, x, y - th - (10 * CANVAS.scale))
        _, node.text = r.ImGui_InputTextMultiline(ctx, '##text' .. node.guid, node.text, w, th)
        r.ImGui_PopStyleColor(ctx)
        r.ImGui_PopStyleVar(ctx)
    end

    x, y = x - edge_offset, y - edge_offset

    local io_y = y + title_h
    Draw_IO(active_ch, node, node.inputs, x, io_y, "in")    -- INPUTS
    Draw_IO(active_ch, node, node.outputs, xe, io_y, "out") -- OUTPUTS

    MoveNode(node)

    if node.can_resize then
        r.ImGui_SetCursorScreenPos(ctx, x + w - (10 * CANVAS.scale), h + y - (10 * CANVAS.scale))
        r.ImGui_Button(ctx, '##RS' .. node.guid, (10 * CANVAS.scale), (10 * CANVAS.scale))
        if r.ImGui_IsItemHovered(ctx) or r.ImGui_IsItemActive(ctx) then
            r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeNWSE())
        end
        if r.ImGui_IsItemActive(ctx) then
            CalculateNewSize(node)
        end
    end

    -- DUMMY BODY BUTTON (FOR DETECTING HOOVER OVER NODE)
    -- r.ImGui_SetCursorScreenPos(ctx, x, y)
    --r.ImGui_InvisibleButton(ctx, "##BODY" .. node.guid, w - edge_offset, h)
end

function SelectAll()
    local NODES = GetCurFunctionNodes()
    for i = 1, #NODES do NODES[i].selected = true end
end

local function ReplaceLinkAndNodeGuids(node, old_guid, new_guid)
    local L_old_guid = Literalize(old_guid)
    if node.guid == old_guid then
        node.guid = new_guid
    end
    for i = 0, #node.inputs do
        if node.inputs[i] then
            for j = 1, #node.inputs[i].connection do
                local node_link = node.inputs[i].connection[j].link
                if node_link:find(L_old_guid) then
                    node.inputs[i].connection[j].link = node_link:gsub(L_old_guid, new_guid)
                end
                local node_guid = node.inputs[i].connection[j].node
                if node_guid == old_guid then
                    node.inputs[i].connection[j].node = new_guid
                end
            end
        end
    end
    for i = 0, #node.outputs do
        if node.outputs[i] then
            for j = 1, #node.outputs[i].connection do
                local node_link = node.outputs[i].connection[j].link
                if node_link:find(L_old_guid) then
                    node.outputs[i].connection[j].link = node_link:gsub(L_old_guid, new_guid)
                end
                local node_guid = node.outputs[i].connection[j].node
                if node_guid == old_guid then
                    node.outputs[i].connection[j].node = new_guid
                end
            end
        end
    end
end

local function GetMinXYInTBL(tbl)
    local min_x, min_y = huge, huge
    for i = 1, #tbl do
        min_x = min_x < tbl[i].x and min_x or tbl[i].x
        min_y = min_y < tbl[i].y and min_y or tbl[i].y
    end
    return min_x, min_y
end

function ReplaceGUIDS(old_guid, tbl, new_g)
    local new_guid = new_g and new_g or r.genGuid()
    for i = 1, #tbl do
        ReplaceLinkAndNodeGuids(tbl[i], old_guid, new_guid)
    end
end

local TMP_COPY, TMP_GUIDS
function Copy()
    TMP_COPY, TMP_GUIDS = {}, {}
    local NODES = GetCurFunctionNodes()
    for i = 1, #NODES do
        local node = NODES[i]
        if node.selected and node.type ~= "m" and node.type ~= "retnode" then
            TMP_COPY[#TMP_COPY + 1] = Deepcopy(node)

            --! TRACK ORIGINAL NODES IN FUNCTION (THEY MUST FOLLOW ORIGINAL FUNCTION)
            if node.type == "func" then
                TMP_COPY[#TMP_COPY].NODES = {}
                setmetatable(TMP_COPY[#TMP_COPY].NODES,
                    {
                        __index = node.NODES,
                        __len = function() return #node.NODES end
                    })
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

            if node.get then
                local source_node = GetNodeInfo(node.get)
                setmetatable(node.outputs[1], {
                    __index = source_node.outputs[1],
                })
            end

            if node.set then
                if node.set.api then
                    local source_node = GetNodeInfo(node.set.guid)
                    setmetatable(node.inputs[1], {
                        __index = source_node.outputs[node.set.pin],
                    })
                else
                    local source_node = GetNodeInfo(node.set.guid)
                    setmetatable(node.outputs[1], {
                        __index = function(t, k)
                            if k == "get" then rawset(node.outputs[1], "o_val", source_node.outputs[1].o_val) end
                        end,
                        __newindex = function(t, k, v) if k == "set" then source_node.outputs[1].o_val = v end end
                    })
                    -- local source_node = GetNodeInfo(node.set.guid)
                    -- setmetatable(node.outputs[node.set.pin], {
                    --     __index = source_node.outputs[node.set.pin],
                    --     __newindex = source_node.outputs[node.set.pin]
                    -- })
                end
            end

            --! CLEAR IN VALUES SINCE THEY ARE LINKED ON RUN
            TMP_COPY[#TMP_COPY].in_values = {}
            TMP_GUIDS[#TMP_GUIDS + 1] = node.guid
        end
    end

    if #TMP_COPY ~= 0 then
        for i = 1, #TMP_GUIDS do ReplaceGUIDS(TMP_GUIDS[i], TMP_COPY) end
        TMP_COPY.x, TMP_COPY.y = GetMinXYInTBL(TMP_COPY)
    end
end

function ValidateLink(tbl, node_idx, link)
    for i = 1, #tbl do
        if node_idx ~= i then
            local node = tbl[i]
            for k = #node.inputs, 0, -1 do
                if node.inputs[k] then
                    if HasConnection(node.inputs[k].connection, link) then return true end
                end
            end
            for k = #node.outputs, 0, -1 do
                if node.outputs[k] then
                    if HasConnection(node.outputs[k].connection, link) then return true end
                end
            end
        end
    end
end

function Paste()
    if not TMP_COPY or #TMP_COPY == 0 then return end
    Deselect_all()

    for i = 1, #TMP_COPY do
        for j = 0, #TMP_COPY[i].inputs do
            if TMP_COPY[i].inputs[j] then
                for c = #TMP_COPY[i].inputs[j].connection, 1, -1 do
                    if not ValidateLink(TMP_COPY, i, TMP_COPY[i].inputs[j].connection[c].link) then
                        table.remove(TMP_COPY[i].inputs[j].connection, c)
                    end
                    if #TMP_COPY[i].inputs[j].connection == 0 then TMP_COPY[i].inputs[j].o_val = nil end
                end
            end
        end
        for j = 0, #TMP_COPY[i].outputs do
            if TMP_COPY[i].outputs[j] then
                for c = #TMP_COPY[i].outputs[j].connection, 1, -1 do
                    if not ValidateLink(TMP_COPY, i, TMP_COPY[i].outputs[j].connection[c].link) then
                        table.remove(TMP_COPY[i].outputs[j].connection, c)
                    end
                    if #TMP_COPY[i].outputs[j].connection == 0 then TMP_COPY[i].outputs[j].o_val = nil end
                end
            end
        end
    end

    local NODES = GetCurFunctionNodes()
    for i = 1, #TMP_COPY do
        local node = TMP_COPY[i]
        node.selected = true
        node.x, node.y = node.x + (CANVAS.MX - TMP_COPY.x), node.y + (CANVAS.MY - TMP_COPY.y)
        NODES[#NODES + 1] = node
    end
    Copy() -- REFRESH COPY TABLE
end

local function DrawDragNode(node)
    if CANVAS.MouseIN then
        if r.ImGui_IsMouseDragging(ctx, 0) then
            AutoAdjust_Node_WH(node)
            node.x, node.y = CANVAS.MX - node.w / 2, CANVAS.MY - NODE_CFG.SEGMENT / 2
            Draw_Node(node)
        elseif r.ImGui_IsMouseReleased(ctx, 0) then
            local NODES = GetCurFunctionNodes()
            if r.ImGui_IsWindowHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByPopup()) then
                if CUR_TAB == "VARS" then
                    r.ImGui_OpenPopup(ctx, "GET-SET")
                else
                    NODES[#NODES + 1] = DRAG_LIST_NODE
                    DIRTY = true

                    --DRAG_LIST_NODE, DRAG_LIST_NODE_ID, GETTER_INFO = nil, nil, nil
                end
            end
        end
    end
    if r.ImGui_IsMouseReleased(ctx, 0) then
        DRAG_LIST_NODE, DRAG_LIST_NODE_ID = nil, nil --GETTER_INFO = nil
    end
end

--! ONLY CURRENT NODES
local function Node_Drawing()
    if not SPLITTER then
        SPLITTER = r.ImGui_CreateDrawListSplitter(DL)
        r.ImGui_Attach(ctx, SPLITTER)
    end
    r.ImGui_DrawListSplitter_Split(SPLITTER, 10)
    FUNCTIONS[CURRENT_FUNCTION].CANVAS = CANVAS
    local NODES = GetCurFunctionNodes()
    -- for i = 1, #NODES do
    --     Draw_Wire(NODES[i], NODES[i].outputs)
    -- end
    for i = 1, #NODES do
        local node = NODES[i]
        Draw_Node(node)
        GetGroupChildNodes(node, NODES)
    end
    for i = 1, #NODES do
        Draw_Wire(NODES[i], NODES[i].outputs)
    end

    if DRAG_LIST_NODE then
        DrawDragNode(DRAG_LIST_NODE)
    end
    --if DRAG_COPY then DragCopyNodes() end
    r.ImGui_DrawListSplitter_Merge(SPLITTER)
end

function Remove_Connections(tbl, i, func_nodes)
    for j = 0, #tbl[i].inputs do
        if tbl[i].inputs[j] then
            Delete_Wire(tbl[i].inputs[j].connection, func_nodes)
        end
    end
    for j = 0, #tbl[i].outputs do
        if tbl[i].outputs[j] then
            Delete_Wire(tbl[i].outputs[j].connection, func_nodes)
        end
    end
end

-- local function FindWirelessPair(tbl, src_guid, wid)
--     for i = 1, #tbl do
--         if tbl[i].guid ~= src_guid then
--             if tbl[i].wireless_id == wid then
--                 return true
--             end
--         end
--     end
-- end

local function FindWirelessPair(tbl, wid)
    for i = 1, #tbl do
        if tbl[i].wireless_id == wid then
            return i
        end
    end
end

-- local function RemoveSourceGettersSetters(guid, delete_api_var_getter)
--     for i = 1, #FUNCTIONS do
--         for n = #FUNCTIONS[i].NODES, 1, -1 do
--             local node = FUNCTIONS[i].NODES[n]
--             if node then
--                 if node.type == "get" then
--                     if node.get == guid then
--                         Remove_Connections(FUNCTIONS[i].NODES, n)
--                         table.remove(FUNCTIONS[i].NODES, n)
--                     end
--                 end
--                 -- FLAG TO NOT CHECK IN RECURSION
--                 if not delete_api_var_getter then
--                     if node.type == "set" or node.type == "api_var" then
--                         -- REMOVE API VAR GETTER FIRST
--                         if node.type == "api_var" then
--                             RemoveSourceGettersSetters(node.guid, true)
--                         end
--                         -- REMOVE SETTER
--                         if node.set.guid == guid then
--                             Remove_Connections(FUNCTIONS[i].NODES, n)
--                             table.remove(FUNCTIONS[i].NODES, n)
--                         end
--                     end
--                 end
--             end
--         end
--     end
-- end

local function CleanLeftoverGetters(guid)
    for i = 1, #FUNCTIONS do
        for n = #FUNCTIONS[i].NODES, 1, -1 do
            local node = FUNCTIONS[i].NODES[n]
            if node.type == "get" then
                if node.get == guid then
                    Remove_Connections(FUNCTIONS[i].NODES, n, FUNCTIONS[i].NODES)
                    table.remove(FUNCTIONS[i].NODES, n)
                end
            end
        end
    end
end

local function CleanLeftoverSetters(guid)
    for i = 1, #FUNCTIONS do
        for n = #FUNCTIONS[i].NODES, 1, -1 do
            local node = FUNCTIONS[i].NODES[n]
            if node.type == "set" then
                if node.set.guid == guid then
                    Remove_Connections(FUNCTIONS[i].NODES, n, FUNCTIONS[i].NODES)
                    table.remove(FUNCTIONS[i].NODES, n)
                end
            end
        end
    end
end

local function CleanLeftoverAPIVAR(guid)
    local del_api = {}
    for i = 1, #FUNCTIONS do
        for n = #FUNCTIONS[i].NODES, 1, -1 do
            local node = FUNCTIONS[i].NODES[n]
            if node.type == "api_var" then
                if node.set.guid == guid then
                    Remove_Connections(FUNCTIONS[i].NODES, n, FUNCTIONS[i].NODES)
                    del_api[#del_api + 1] = table.remove(FUNCTIONS[i].NODES, n)
                end
            end
        end
    end
    if #del_api ~= 0 then return del_api end
end

local function CleanupLeftovers(del_tbl, NODES)
    for i = 1, #del_tbl do
        local del_node = del_tbl[i]
        -- IS WIRELESS NODE
        if del_node.wireless_id then
            local node_idx = FindWirelessPair(NODES, del_node.wireless_id)
            if node_idx then
                Remove_Connections(NODES, node_idx)
                table.remove(NODES, node_idx)
            end
        end

        -- VARIABLE SETTERS
        CleanLeftoverSetters(del_node.guid)
        -- API SETTERS
        local del_api_var_tbl = CleanLeftoverAPIVAR(del_node.guid)
        -- API VAR HAS ITS OWN GETTERS SO DELETE THEM FIRST
        if del_api_var_tbl then
            for j = 1, #del_api_var_tbl do
                -- DELETE API GETTERS
                CleanLeftoverGetters(del_api_var_tbl[j].guid)
            end
        end
        -- STANDARD VARIABLE GETTERS
        CleanLeftoverGetters(del_node.guid)
    end
end

local function DeleteNodeTable(tbl)
    if not tbl then return end

    local deleted_tbl = {}
    for i = #tbl, 1, -1 do
        if tbl[i] then
            if tbl[i].selected and tbl[i].type ~= "m" and tbl[i].type ~= "retnode" then
                DIRTY = true
                Remove_Connections(tbl, i)
                deleted_tbl[#deleted_tbl + 1] = table.remove(tbl, i)
            end
        end
    end

    CleanupLeftovers(deleted_tbl, tbl)
    -- DELETE REMAINING WIRELESS PAIR
    -- for i = #tbl, 1, -1 do
    --     if tbl[i].wireless_id then
    --         if not FindWirelessPair(tbl, tbl[i].guid, tbl[i].wireless_id) then
    --             Remove_Connections(tbl, i)
    --             table.remove(tbl, i)
    --         end
    --     end
    -- end

    --ConnectNextPreviousFunctionNodes(prev_node, prev_pin, next_node, next_pin)
end

function DeleteNode(tbl, n)
    DIRTY = true
    Remove_Connections(tbl, n)
    table.remove(tbl, n)
end

function Delete()
    local NODES = GetNodeTBL()
    DeleteNodeTable(NODES)
end

function DrawLoop()
    r.ImGui_PushFont(ctx, FONT)
    Node_Drawing()
    r.ImGui_PopFont(ctx)
    --if START_FLOW and DEFER then
    if DEFERED_NODE then
        InitRunFlow()
    end
end

function CenterNodeToScreen(node)
    local x, y = CANVAS.view_x + CANVAS.off_x, CANVAS.view_y + CANVAS.off_y
    local nx, ny = Get_Node_Screen_position(node)

    local node_center_x = (((x - nx) + CANVAS.rx / 2) - node.w / 2)
    local node_center_y = (y - ny + (CANVAS.ry / 2) - node.h / 2)

    -- ANIMATE MOVEMENT
    FLUX.to(CANVAS, 0.5, { off_x = node_center_x, off_y = node_center_y }):ease("cubicout")
end

function PropagateParentFunctionNodes(id)
    local FOLLOWER = Deepcopy(FUNCTIONS[id])
    ReplaceGUIDS(FUNCTIONS[id].guid, { FOLLOWER })

    FOLLOWER.NODES = {}

    setmetatable(FOLLOWER.NODES,
        {
            __index = FUNCTIONS[id].NODES,
            __len = function() return #FUNCTIONS[id].NODES end
        }
    )
    return FOLLOWER
end

function RelinkFunction(func_tbl)
    for n = 1, #func_tbl.NODES do
        local node = func_tbl.NODES[n]
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
                    __index = connected_node.outputs[node.inputs[o].connection[1].pin],
                    __newindex = connected_node.outputs[node.inputs[o].connection[1].pin]
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
                __newindex = source_node.outputs[1],
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
                -- local source_node = GetNodeInfo(node.set.guid)
                -- setmetatable(node.outputs[node.set.pin], {
                --     __index = source_node.outputs[node.set.pin],
                --     __newindex = source_node.outputs[node.set.pin]
                -- })
            end
        end
    end
end

local function RelinkParrentFunctionNodes()
    for i = 1, #FUNCTIONS do
        for n = 1, #FUNCTIONS[i].NODES do
            local node = FUNCTIONS[i].NODES[n]
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
                        __index = connected_node.outputs[node.inputs[o].connection[1].pin],
                        __newindex = connected_node.outputs[node.inputs[o].connection[1].pin]
                    })
                end
            end

            -- RELINK MATH METATABLE
            if node.fname and node.fname:lower():find("math") then
                setmetatable(node.outputs[1], {
                    __index = function(t, k)
                        if k == "o_val" then
                            return DoMath(node.inputs[2].i_val, node)
                        end
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
                    __newindex = source_node.outputs[1],
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
                    -- local source_node = GetNodeInfo(node.set.guid)
                    -- setmetatable(node.outputs[node.set.pin], {
                    --     __index = source_node.outputs[node.set.pin],
                    --     __newindex = source_node.outputs[node.set.pin]
                    -- })
                end
            end
        end
    end
end

function StoreNodes()
    --CleanTABLENodes()
    --r.ShowConsoleMsg("STORED\n")
    local storedTable = {}
    --storedTable.CANVAS = CANVAS
    storedTable.CURRENT_FUNCTION = CURRENT_FUNCTION
    storedTable.FUNCTIONS = FUNCTIONS
    local serialized = TableToString(storedTable)
    return serialized
end

function RestoreNodes(string)
    local storedTable = StringToTable(string)
    --r.ShowConsoleMsg(string)
    if storedTable ~= nil then
        --r.ShowConsoleMsg(string)
        --CANVAS = storedTable.CANVAS
        CURRENT_FUNCTION = storedTable.CURRENT_FUNCTION or 2
        FUNCTIONS = storedTable.FUNCTIONS

        --! UPDATE OLD PROJECTS WITH CANVAS FOR NOW
        if not FUNCTIONS[CURRENT_FUNCTION].CANVAS then
            for i = 1, #FUNCTIONS do
                FUNCTIONS[i].CANVAS = InitCanvas()
            end
        end
        --START_DIRT = #FUNCTIONS + #FUNCTIONS[1].NODES + #FUNCTIONS[2].NODES
        DIRTY = nil

        CANVAS = FUNCTIONS[CURRENT_FUNCTION].CANVAS
        RelinkParrentFunctionNodes()
        return true
    end
end

function InitApi()
    CreateApiFile()
    API_LIST = Fill_Api_list()
end

function Rename()
    local node = CntSelNodes()[1]
    RENAME_NODE = node
    local RV
    if r.ImGui_IsWindowAppearing(ctx) then
        r.ImGui_SetKeyboardFocusHere(ctx)
        NEW_NAME = node.label
    end
    RV, NEW_NAME = r.ImGui_InputText(ctx, 'Name', NEW_NAME, r.ImGui_InputTextFlags_AutoSelectAll())
    if r.ImGui_Button(ctx, 'OK') or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or
        r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
        NEW_NAME = NEW_NAME:gsub("^%s*(.-)%s*$", "%1") -- remove trailing and leading
        if #NEW_NAME ~= 0 then SAVED_NAME = NEW_NAME end
        if SAVED_NAME then
            node.label = SAVED_NAME
        end
        r.ImGui_CloseCurrentPopup(ctx)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'Cancel') or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        RENAME_NODE = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

function GetSetMenu()
    if r.ImGui_MenuItem(ctx, 'GET') then
        InsertNode("get", "GET " .. GET_SET_NODE.label)
        GET_SET_NODE = nil
    end

    -- API VARIABLES CAN ONLY GET
    if GET_SET_NODE and GET_SET_NODE.type ~= "api_var" then
        if r.ImGui_MenuItem(ctx, 'SET') then
            InsertNode("set", "SET " .. GET_SET_NODE.label)
            GET_SET_NODE = nil
        end
    end
end

function PinContextMenu()
    if r.ImGui_MenuItem(ctx, 'PROMOTE TO VARIABLE') then
        if INSERT_NODE_DATA.get_set == "api_var" then
            InsertNode("api_var", "VAR " .. INSERT_NODE_DATA.node_label)
        else
            InsertNode(INSERT_NODE_DATA.get_set, INSERT_NODE_DATA.pin_label)
        end
    end
end

function ClearProject()
    NEED_SAVE = nil
    -- DELETE COPY PASTE BUFFER
    TMP_COPY = {}
    FUNCTIONS = {}
    InitStartFunction()
end

function InitStartNodes(is_init)
    local tmp = {}
    tmp[#tmp + 1] = Get_Node("m", "START", 0, 0, 0, 0, nil, Create_constant_tbl("m"))
    if not is_init then
        tmp[#tmp + 1] = Get_Node("retnode", "RETURN", 500, 0, 0, 0, nil, Create_constant_tbl("retnode"))
    end
    return tmp
end

function InitStartFunction()
    FUNCTIONS[#FUNCTIONS + 1] = Get_Node("func", "Init", 0, 0, 0, 0, nil, Create_constant_tbl("func"))
    FUNCTIONS[#FUNCTIONS].NODES = InitStartNodes(true)
    FUNCTIONS[#FUNCTIONS].CANVAS = InitCanvas()
    FUNCTIONS[#FUNCTIONS + 1] = Get_Node("func", "Main", 0, 0, 0, 0, nil, Create_constant_tbl("func"))
    FUNCTIONS[#FUNCTIONS].NODES = InitStartNodes(true)
    FUNCTIONS[#FUNCTIONS].CANVAS = InitCanvas()
    CURRENT_FUNCTION = 2
    CHANGE_FTAB = 2
end

function ClearNodesWarning()
    for i = 1, #FUNCTIONS do
        for n = 1, #FUNCTIONS[i].NODES do
            local node = FUNCTIONS[i].NODES[n]
            if node.missing_arg then node.missing_arg = nil end
        end
    end
end

function AreFunctionsDirty()
    -- local cur_dirt = #FUNCTIONS + #FUNCTIONS[1].NODES + #FUNCTIONS[2].NODES
    -- if cur_dirt ~= START_DIRT then
    --     return true
    -- end

    if DIRTY then return true end
end

function ConnectNextPreviousFunctionNodes(prev_node, prev_pin, next_node, next_pin)
    if prev_node and next_node then
        local link_guid = next_node.guid .. ":" .. "RUN" .. "-" .. prev_node.guid .. ":" .. "RUN"

        local p_con = prev_node.outputs[prev_pin].connection
        local n_con = next_node.inputs[next_pin].connection

        p_con[#p_con + 1] = {
            link = link_guid,
            node = next_node.guid,
            pin = next_pin,
        }
        n_con[#n_con + 1] = {
            link = link_guid,
            node = prev_node.guid,
            pin = prev_pin
        }
    end
end

function AnimateSpriteSheet(img_obj, frames, cols, rows, speed, x, y, time)
    --local now_time = time - r.time_precise()
    local w, h = r.ImGui_Image_GetSize(img_obj)

    --local xs, ys = WIN_X + x, WIN_Y + y
    local xe, ye = w / cols, h / rows

    local uv_step_x, uv_step_y = 1 / cols, 1 / rows

    local frame = math.floor((r.time_precise() * speed) % frames)

    local col_frame = frame % cols
    local row_frame = math.floor(frame / cols)

    local uv_xs = col_frame * uv_step_x
    local uv_ys = row_frame * uv_step_y
    local uv_xe = uv_xs + uv_step_x
    local uv_ye = uv_ys + uv_step_y

    --r.ImGui_DrawList_AddImage(DL, img_obj, xs, ys, xe, ye, uv_xs, uv_ys, uv_xe, uv_ye)
    r.ImGui_Image(ctx, img_obj, xe, ye, uv_xs, uv_ys, uv_xe, uv_ye)
end
