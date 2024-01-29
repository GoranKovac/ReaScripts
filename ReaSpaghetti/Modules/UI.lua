--@noindex
--NoIndex: true

local r = reaper

local help_tbl = {
    "CANVAS : ",
    "\tMOUSE:",
    "\t\tLeft Drag    - Marqee select",
    "\t\tLeft Click   - Selection",
    "\t\tShift/Ctrl   - Adds/Removes selection",
    "\t\tRight Click  - Opens Api Menu",
    "\t\tRight Drag   - Scroll",
    "\t\tMouse Scroll - Zoom",
    "\tKEYS :",
    "\t\tF2           - Rename Single node (ignores multiselection)",
    "\t\tDelete       - Deletes selected nodes",
    "\t\tCTRL + C/V   - Copy Paste (Start/Return Node excluded)",
    "\t\tCTRL + A     - Select all",
    "\t\tHome         - Resets view to center",
    "\n",
    "SIDEBAR :",
    "\tNodes TAB      - Double Click scoll node into view",
    "\tVariables TAB  - STRING, INTEGER, FLOAT nodes",
    "\tAPI TAB        - Left Drag - Drag and drop node",
    "\tAPI TAB        - Double Click - Open API Site for info",
    "Search Bar :",
    "\tLeft Drag      - Drag and drop node",
    "NODES :",
    "\tShift hover    - Trace all Input/Output lines",
    "\tALT CLICK PIN  - Deletes all connections to that pin",
    "\tALT CLICK WIRE - Deletes that specific wire",
}

function Top_Menu()
    if r.ImGui_BeginMenuBar(ctx) then
        if r.ImGui_BeginMenu(ctx, 'File') then
            if r.ImGui_MenuItem(ctx, 'New') then
                --local FUNCTIONS = GetFUNCTIONS()
                --if #FUNCTIONS > 2 or #FUNCTIONS[1].NODES > 1 or #FUNCTIONS[2].NODES > 1 then
                if AreFunctionsDirty() then
                    NEW_WARNIGN = true
                else
                    RESET_CANVAS = true
                    ClearProject()
                end
            end
            if r.ImGui_MenuItem(ctx, 'Open') then
                OPEN_FM = true
                FM_TYPE = "OPEN"
                Init_FM_database()
            end
            if r.ImGui_MenuItem(ctx, 'Save as') then
                OPEN_FM = true
                FM_TYPE = "SAVE"
                Init_FM_database()
            end
            if r.ImGui_MenuItem(ctx, 'Export to Action') then
                if not PROJECT_PATH then
                    EXPORT_ACTION_WARNING = true
                else
                    EXPORT_ACTION_POPUP = true
                end
            end
            if r.ImGui_MenuItem(ctx, 'Update API') then
                CurlToFile()
            end

            if ULTRA_API then
                if r.ImGui_MenuItem(ctx, 'Update ULTRASCHALL API') then
                    WriteUltraApi()
                end
            end
            r.ImGui_EndMenu(ctx)
        end
        if r.ImGui_BeginMenu(ctx, 'Options') then
            if r.ImGui_MenuItem(ctx, 'Preferences') then
                PREFERENCES = true
            end
            r.ImGui_EndMenu(ctx)
        end
        if r.ImGui_BeginMenu(ctx, 'Help') then
            if r.ImGui_MenuItem(ctx, 'Keys And Shortcuts') then
                HELP = true
            end
            if r.ImGui_MenuItem(ctx, 'Open Documentation') then
                OpenFile(PATH .. NATIVE_SEPARATOR .. "Docs" .. NATIVE_SEPARATOR .. "ReaSpaghetti.pdf")
            end
            r.ImGui_EndMenu(ctx)
        end
        r.ImGui_EndMenuBar(ctx)
    end
end

local function DBGNode()
    if not DEBUG then return end
    --local avail_w = r.ImGui_GetContentRegionAvail(ctx)
    --r.ImGui_SameLine(ctx, avail_w - 300)
    local cur_node = #CntSelNodes() == 1 and CntSelNodes()[1] or nil

    local dbg_str = cur_node and INSPECT(cur_node) or ""

    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 5, 5)
    r.ImGui_SetCursorPos(ctx, 250, 35)
    if r.ImGui_BeginChild(ctx, 'NodeDBG', -5, DEBUG_N_VISIBLE and 500 or 23, true, r.ImGui_WindowFlags_NoScrollbar()) then
        DEBUG_N_VISIBLE = r.ImGui_TreeNode(ctx, 'NODE TBL : ', r.ImGui_TreeNodeFlags_NoTreePushOnOpen())
        if DEBUG_N_VISIBLE and r.ImGui_BeginChild(ctx, 'debug_view') then
            r.ImGui_TextWrapped(ctx, dbg_str)
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleColor(ctx)
end

LEGO_MGS = {}
local function DBGMsg()
    local avail_w = r.ImGui_GetContentRegionAvail(ctx)
    r.ImGui_SameLine(ctx, avail_w - 300)

    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 5, 5)
    if r.ImGui_BeginChild(ctx, 'right_side', -5, DEBUG_VISIBLE and 27 + #LEGO_MGS * 13 or 23, true, r.ImGui_WindowFlags_NoScrollbar()) then
        DEBUG_VISIBLE = r.ImGui_TreeNode(ctx, 'Debug MSG - MESSAGES : ' .. #LEGO_MGS,
            r.ImGui_TreeNodeFlags_NoTreePushOnOpen())
        if DEBUG_VISIBLE and r.ImGui_BeginChild(ctx, 'debug_view') then
            r.ImGui_TextWrapped(ctx, table.concat(LEGO_MGS, "\n"))
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleColor(ctx)
end

local types = {
    "INTEGER",
    "NUMBER",
    "STRING",
    "BOOLEAN",
    "TABLE",
    "ANY"
}

local function TableSpecial(node)
    --if node.type ~= "tc" then return end
    if r.ImGui_Button(ctx, "+", 19, 19) then
        if node.type == "tc" then
            local ins = { { name = "VAL " .. #node.inputs + 1, type = "INTEGER" } }
            local inputs = CreateInputs("in", ins)
            node.inputs[#node.inputs + 1] = inputs[1]
        else
            if node.fname == "CUSTOM_MultiIfElse" then
                local ins = { { name = "INP " .. #node.inputs, type = "BOOLEAN" } }
                local inputs = CreateInputs("in", ins)
                node.inputs[#node.inputs + 1] = inputs[1]
            elseif node.fname == "CUSTOM_MultiIfElseifElse" then
                local ins = { { name = "INP " .. #node.inputs + 1, type = "BOOLEAN" } }
                local inputs = CreateInputs("in", ins)
                node.inputs[#node.inputs + 1] = inputs[1]
                local out = { { name = "OUT " .. #node.outputs, type = "RUN" } }
                local outputs = CreateInputs("out", out)
                node.outputs[#node.outputs + 1] = outputs[1]
            elseif node.fname == "CUSTOM_CodeNodeRun" then
                local ins = { { name = "INPUT " .. #node.inputs, type = "INTEGER" } }
                local inputs = CreateInputs("in", ins)
                --table.insert(node.inputs, 1, inputs[1])
                node.inputs[#node.inputs + 1] = inputs[1]
                --for i = 1, #node.inputs - 1 do
                --    node.inputs[i].label = node.inputs[i].label:gsub("%d+", i)
                --end

                local out = { { name = "OUTPUT " .. #node.outputs + 1, type = "INTEGER" } }
                local outputs = CreateInputs("out", out)
                node.outputs[#node.outputs + 1] = outputs[1]
            end
        end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "-", 19, 19) then
        if node.type == "tc" then
            if #node.inputs > 0 then
                -- DELETE ALL CONNECTIONS TO THIS PIN
                Delete_Wire(node.inputs[#node.inputs].connection)
                table.remove(node.in_values, #node.in_values)
                table.remove(node.inputs, #node.inputs)
            end
        else
            if node.fname == "CUSTOM_MultiIfElse" then
                if #node.inputs > 2 then
                    -- DELETE ALL CONNECTIONS TO THIS PIN
                    Delete_Wire(node.inputs[#node.inputs].connection)
                    table.remove(node.in_values, #node.in_values)
                    table.remove(node.inputs, #node.inputs)
                end
            elseif node.fname == "CUSTOM_MultiIfElseifElse" then
                if #node.inputs > 1 then
                    -- DELETE ALL CONNECTIONS TO THIS PIN
                    Delete_Wire(node.inputs[#node.inputs].connection)
                    Delete_Wire(node.outputs[#node.outputs].connection)
                    table.remove(node.in_values, #node.in_values)
                    table.remove(node.inputs, #node.inputs)
                    table.remove(node.outputs, #node.outputs)
                end
            elseif node.fname == "CUSTOM_CodeNodeRun" then
                if #node.inputs > 1 then
                    --Delete_Wire(node.inputs[1].connection)
                    --Delete_Wire(node.outputs[1].connection)
                    Delete_Wire(node.inputs[#node.inputs].connection)
                    Delete_Wire(node.outputs[#node.outputs].connection)
                    if #node.in_values ~= 0 then
                        table.remove(node.in_values, #node.in_values)
                    end
                    table.remove(node.inputs, #node.inputs)
                    table.remove(node.outputs, #node.outputs)
                end
            end
        end
    end
    if node.type == "tc" or node.type == "code" then
        local avail_w = r.ImGui_GetContentRegionAvail(ctx)
        if r.ImGui_BeginChild(ctx, "code_inputs") then
            for ins = 1, #node.inputs do
                if node.inputs[ins].type ~= "CODE" then
                    if ins > 0 then
                        local cur_type = node.inputs[ins].type
                        r.ImGui_PushID(ctx, "tc_inp" .. ins)
                        r.ImGui_SetNextItemWidth(ctx, avail_w / 3)
                        if r.ImGui_BeginCombo(ctx, ins, cur_type) then
                            for v in ipairs(types) do
                                if r.ImGui_Selectable(ctx, types[v]) then
                                    -- DO NOT ALLOW CHANGING IF PIN IS CONNECTED
                                    if not next(node.inputs[ins].connection) then
                                        -- UPDATE FUNCTION INPUT TYPE
                                        node.inputs[ins].type = types[v]
                                    end
                                end
                            end
                            r.ImGui_EndCombo(ctx)
                        end
                        r.ImGui_PopID(ctx)
                    end
                end
                if node.type == "tc" then
                    r.ImGui_SameLine(ctx)
                    r.ImGui_PushID(ctx, "##tc" .. node.guid .. ins)
                    r.ImGui_SetNextItemWidth(ctx, avail_w / 3)
                    RV_TC_I_NAME, node.inputs[ins].label = r.ImGui_InputText(ctx, "##labeli", node.inputs[ins].label)
                    r.ImGui_PopID(ctx)
                    r.ImGui_SameLine(ctx)
                    r.ImGui_PushID(ctx, "##tc_apply" .. node.guid .. ins)
                    _, node.inputs[ins].to_key = r.ImGui_Checkbox(ctx, "TO KEY", node.inputs[ins].to_key)
                    r.ImGui_PopID(ctx)
                end
            end
            r.ImGui_EndChild(ctx)
        end
        if node.type == "code" then
            local avail_w = r.ImGui_GetContentRegionAvail(ctx)
            r.ImGui_SameLine(ctx, 150)
            if r.ImGui_BeginChild(ctx, "code_outputs") then
                for outs = 1, #node.outputs do
                    --if node.outputs[outs].type ~= "CODE" then
                    local cur_type = node.outputs[outs].type
                    r.ImGui_PushID(ctx, "code_outp" .. outs)
                    r.ImGui_SetNextItemWidth(ctx, avail_w / 3)
                    if r.ImGui_BeginCombo(ctx, outs, cur_type) then
                        for v in ipairs(types) do
                            if r.ImGui_Selectable(ctx, types[v]) then
                                -- DO NOT ALLOW CHANGING IF PIN IS CONNECTED
                                if not next(node.outputs[outs].connection) then
                                    -- UPDATE FUNCTION INPUT TYPE
                                    node.outputs[outs].type = types[v]
                                end
                            end
                        end
                        r.ImGui_EndCombo(ctx)
                    end
                    r.ImGui_PopID(ctx)
                end
                r.ImGui_EndChild(ctx)
            end
        end
    end
end

local tbl_types = {
    ["m"] = true, ["i"] = true, ["f"] = true, ["s"] = true, ["b"] = true }

local function InspectorFrame(node)
    if not node then return end
    DEF_INC = nil
    local io_type = tbl_types[node.type] and "out" or "in"
    local current_io_tbl = tbl_types[node.type] and node.outputs or
        node.inputs --node.type == "m" and node.outputs or node.inputs
    if node.type == "tc" or node.fname == "CUSTOM_MultiIfElse" or node.fname == "CUSTOM_MultiIfElseifElse" or node.fname == "CUSTOM_CodeNodeRun" then
        TableSpecial(node)
        DEF_INC = true
        if node.type == "tc" or node.type == "code" then return end
    end
    local w = r.ImGui_GetContentRegionAvail(ctx)
    for i = 1, #current_io_tbl do
        if current_io_tbl[i] then
            local missing
            local pin = current_io_tbl[i]

            if node.missing_arg then
                for m = 1, #node.missing_arg do
                    if node.missing_arg[m] == pin.label then
                        missing = true
                    end
                end
            end

            local current_input = #pin.connection == 0 and pin.i_val or pin.o_val
            local disable_input = (#pin.connection ~= 0 and io_type == "in") and true or false
            if node.type == "m" or node.type == "retnode" then
                disable_input = true
            end

            if disable_input then r.ImGui_BeginDisabled(ctx) end
            if not pin.no_draw then
                r.ImGui_PushID(ctx, i)

                r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FrameRounding(), 5)
                --r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x17181fff)
                r.ImGui_SetCursorPosX(ctx, 5)
                r.ImGui_SetNextItemWidth(ctx, w - 10)
                if pin.type == "INTEGER" then
                    local separator = node.type == "i" and "" or " : "
                    if node.type == "i" then
                        I_RV2, pin.i_val = r.ImGui_DragInt(ctx, "##" .. pin.label, pin.i_val, 1, 0, nil,
                            pin.label .. separator .. '%d%',
                            r.ImGui_SliderFlags_AlwaysClamp())
                        if I_RV2 then pin.o_val = pin.i_val end
                    else
                        _, pin.i_val = r.ImGui_DragInt(ctx, "##" .. pin.label, current_input, 1, 0, nil,
                            pin.label .. separator .. '%d%',
                            r.ImGui_SliderFlags_AlwaysClamp())
                    end
                elseif pin.type == "NUMBER/INTEGER" or pin.type == "NUMBER" then
                    local separator = node.type == "f" and "" or " : "
                    if node.type == "f" then
                        F_RV2, pin.i_val = r.ImGui_DragDouble(ctx, "##" .. pin.label, pin.i_val, 0.01, 0.0, 0.0,
                            pin.label .. separator .. '%.03f')
                        if F_RV2 then pin.o_val = pin.i_val end
                    else
                        _, pin.i_val = r.ImGui_DragDouble(ctx, "##" .. pin.label, current_input, 0.01, 0.0, 0.0,
                            pin.label .. separator .. '%.03f')
                    end
                elseif pin.type == "STRING" then
                    if node.type == "s" then
                        S_RV2, pin.i_val = r.ImGui_InputTextWithHint(ctx, "##" .. pin.label, pin.label, pin.i_val)
                        if S_RV2 then pin.o_val = pin.i_val end
                    else
                        _, pin.i_val = r.ImGui_InputTextWithHint(ctx, "##" .. pin.label, pin.label, current_input)
                    end
                elseif pin.type == "BOOLEAN" then
                    if node.type == "b" then
                        B_RV2, pin.i_val = r.ImGui_Checkbox(ctx, pin.label, pin.i_val)
                        if B_RV2 then pin.o_val = pin.i_val end
                    else
                        _, pin.i_val = r.ImGui_Checkbox(ctx, pin.label, current_input)
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
                else
                    r.ImGui_InputText(ctx, '##', tostring(current_input))
                end

                -- r.ImGui_PopStyleColor(ctx)
                r.ImGui_PopID(ctx)
                r.ImGui_PopStyleVar(ctx) --
            end
            if disable_input then r.ImGui_EndDisabled(ctx) end
        end
    end
end

local function FunctionIO2(func)
    local avail_w, avail_h = r.ImGui_GetContentRegionAvail(ctx)
    if r.ImGui_BeginChild(ctx, "ARGUMENTS", avail_w / 2, avail_h, 1) then
        r.ImGui_Text(ctx, "   ARGUMENTS")
        r.ImGui_SameLine(ctx)
        r.ImGui_PushID(ctx, "b_arg+")
        if r.ImGui_Button(ctx, "+", 18, 18) then
            local ins = { { name = "ARG " .. #func.inputs + 1, type = "INTEGER" } }
            -- FUNCTION INPUT
            func.inputs[#func.inputs + 1] = CreateInputs("in", ins)[1]

            -- FUNCTION START OUTPUT
            func.NODES[1].outputs[#func.NODES[1].outputs + 1] =
                CreateInputs("out", ins)[1]

            -- UPDATE ALL INSERTED NODE FUNCTIONS
            UpdateChildFunctions(CURRENT_FUNCTION, "ARG", "add", CreateInputs("in", ins)[1])
        end
        r.ImGui_PopID(ctx)
        r.ImGui_SameLine(ctx)
        r.ImGui_PushID(ctx, "b_arg-")
        if r.ImGui_Button(ctx, "-", 18, 18) then
            if #func.inputs > 0 then
                -- ALWAYS REMOVE ALL CONNECTIONS FIRST
                -- FUNCTION INPUT
                Delete_Wire(func.inputs[#func.inputs].connection)

                Delete_Wire(func.NODES[1].outputs[#func.NODES[1].outputs].connection)

                table.remove(func.inputs, #func.inputs)
                -- FUNCTION START OUTPUT
                table.remove(func.NODES[1].outputs, #func.NODES[1].outputs)
                -- UPDATE ALL INSERTED NODE FUNCTIONS
                UpdateChildFunctions(CURRENT_FUNCTION, "ARG", "remove")
            end
        end
        r.ImGui_PopID(ctx)
        if #func.inputs > 0 then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x000000FF)
            if r.ImGui_BeginListBox(ctx, "##ARGUMENTS", avail_w / 2, -1) then
                for inp = 1, #func.inputs do
                    local cur_type = func.inputs[inp].type
                    r.ImGui_PushID(ctx, "args" .. inp)
                    r.ImGui_SetNextItemWidth(ctx, avail_w / 4)
                    if r.ImGui_BeginCombo(ctx, "##inp", cur_type) then
                        for v in ipairs(types) do
                            if r.ImGui_Selectable(ctx, types[v]) then
                                -- DO NOT ALLOW CHANGE IF PIN IS CONNECTED
                                if not next(func.inputs[inp].connection) then
                                    -- UPDATE FUNCTION INPUT TYPE
                                    func.inputs[inp].type = types[v]
                                    -- UPDATE FUNCTION START NODE TYPE
                                    func.NODES[1].outputs[inp].type = types[v]
                                    -- UPDATE CHILD FUNCTIONS ARGUMENT TYPE
                                    UpdateChildFunctions(CURRENT_FUNCTION, "ARG", "update", nil, inp, types[v])
                                end
                            end
                        end
                        r.ImGui_EndCombo(ctx)
                    end
                    r.ImGui_PopID(ctx)
                    r.ImGui_SameLine(ctx)
                    r.ImGui_PushID(ctx, "args name" .. inp)
                    RV_I_NAME, func.inputs[inp].label = r.ImGui_InputText(ctx, "##labeli" .. inp,
                        func.inputs[inp].label)
                    if RV_I_NAME then
                        func.NODES[1].outputs[inp].label = func.inputs[inp].label
                        UpdateChildFunctionsIO(CURRENT_FUNCTION, "ARG", inp, func.inputs[inp].label)
                    end
                    r.ImGui_PopID(ctx)
                end
                r.ImGui_EndListBox(ctx)
            end
            r.ImGui_PopStyleColor(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_BeginChild(ctx, "RETURNS", avail_w / 2, avail_h, 1) then
        r.ImGui_Text(ctx, "  RETURNS")
        r.ImGui_SameLine(ctx)
        r.ImGui_PushID(ctx, "b_ret+")
        if r.ImGui_Button(ctx, "+", 18, 18) then
            local out = { { name = "RET " .. #func.outputs + 1, type = "INTEGER" } }
            -- FUNCTION OUTPUT
            func.outputs[#func.outputs + 1] = CreateInputs("out", out)[1]
            -- FUNCTION RETURN NODE INPUT
            func.NODES[2].inputs[#func.NODES[2].inputs + 1] =
                CreateInputs("in", out)[1]
            -- UPDATE ALL INSERTED NODE FUNCTIONS
            UpdateChildFunctions(CURRENT_FUNCTION, "RET", "add", CreateInputs("out", out)[1])
        end
        r.ImGui_PopID(ctx)
        r.ImGui_SameLine(ctx)
        r.ImGui_PushID(ctx, "b_ret-")
        if r.ImGui_Button(ctx, "-", 18, 18) then
            if #func.outputs > 0 then
                Delete_Wire(func.outputs[#func.outputs].connection)

                Delete_Wire(func.NODES[2].inputs[#func.NODES[2].inputs]
                    .connection)
                -- FUNCTION OUTPUT
                table.remove(func.outputs, #func.outputs)
                -- FUNCTION RETURN NODE INPUT
                table.remove(func.NODES[2].inputs, #func.NODES[2].inputs)
                -- UPDATE ALL INSERTED NODE FUNCTIONS
                UpdateChildFunctions(CURRENT_FUNCTION, "RET", "remove")
            end
        end
        r.ImGui_PopID(ctx)

        if #func.outputs > 0 then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x000000FF)
            if r.ImGui_BeginListBox(ctx, "##RETURNS", avail_w / 2, -1) then
                for out = 1, #func.outputs do
                    local cur_type = func.outputs[out].type
                    r.ImGui_PushID(ctx, "rets" .. out)
                    r.ImGui_SetNextItemWidth(ctx, avail_w / 4)
                    if r.ImGui_BeginCombo(ctx, out, cur_type) then
                        for v in ipairs(types) do
                            if r.ImGui_Selectable(ctx, types[v]) then
                                -- DO NOT ALLOW CHANGE IF PIN IS CONNECNTED
                                if not next(func.outputs[out].connection) then
                                    -- UPDATE FUNCTION INPUT TYPE
                                    func.outputs[out].type = types[v]
                                    -- UPDATE FUNCTION RETURN NODE TYPE
                                    func.NODES[2].inputs[out].type = types[v]
                                    -- UPDATE CHILD FUNCTIONS RETURN TYPE
                                    UpdateChildFunctions(CURRENT_FUNCTION, "RET", "update", nil, out, types[v])
                                end
                            end
                        end
                        r.ImGui_EndCombo(ctx)
                    end
                    r.ImGui_PopID(ctx)
                    r.ImGui_SameLine(ctx)
                    r.ImGui_PushID(ctx, "ret name" .. out)
                    RV_O_NAME, func.outputs[out].label = r.ImGui_InputText(ctx, "##labelo" .. out,
                        func.outputs[out].label)
                    if RV_O_NAME then
                        func.NODES[2].inputs[out].label = func.outputs[out].label
                        UpdateChildFunctionsIO(CURRENT_FUNCTION, "RET", out, func.outputs[out].label)
                    end
                    r.ImGui_PopID(ctx)
                end
                r.ImGui_EndListBox(ctx)
            end
            r.ImGui_PopStyleColor(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
end

local function FunctionIspector()
    if CURRENT_FUNCTION < 3 then return end
    local FUNCTIONS = GetFUNCTIONS()
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 2, 5)
    local _, pad_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
    local def_h = 17 + (pad_y * 2)
    local def_w = 32
    local total_io = #FUNCTIONS[CURRENT_FUNCTION].inputs > #FUNCTIONS[CURRENT_FUNCTION].outputs and
        #FUNCTIONS[CURRENT_FUNCTION].inputs or #FUNCTIONS[CURRENT_FUNCTION].outputs
    local h_off = total_io == 0 and 36 or 43
    local h_exp = def_h + h_off + total_io * (17 + pad_y * 2)

    r.ImGui_SetCursorPosX(ctx, 5)
    if r.ImGui_BeginChild(ctx, 'InspectorF', INSPECT_VISIBLEF and 350 or (INSPECT_HOOVER_F and 120 or def_w), INSPECT_VISIBLEF and h_exp or def_h, true, r.ImGui_WindowFlags_NoScrollbar()) then
        INSPECT_VISIBLEF = r.ImGui_TreeNode(ctx, 'FUNCTION I/O', r.ImGui_TreeNodeFlags_NoTreePushOnOpen())
        INSPECT_HOOVER_F = r.ImGui_IsItemHovered(ctx)
        if INSPECT_VISIBLEF and r.ImGui_BeginChild(ctx, 'Inspect_view2') then
            -- r.ImGui_Separator(ctx)
            FunctionIO2(FUNCTIONS[CURRENT_FUNCTION])
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
end

local function NodeInspector()
    --local _, avail_h = r.ImGui_GetContentRegionAvail(ctx)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 2, 5)
    local _, pad_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
    local cur_node = #CntSelNodes() == 1 and CntSelNodes()[1] or nil
    local def_h = 17 + (pad_y * 2)
    local def_w = 32
    local h_exp = def_h
    if cur_node then
        local current_io_tbl = tbl_types[cur_node.type] and cur_node.outputs or cur_node.inputs
        h_exp = def_h + 4 + (#current_io_tbl * (17 + pad_y * 2))
        --if cur_node.type == "tc" then
        if DEF_INC then
            h_exp = h_exp + 25
        end
    end
    r.ImGui_SetCursorPos(ctx, 5, 35)
    if r.ImGui_BeginChild(ctx, 'Inspector', INSPECT_VISIBLE and 295 or (INSPECT_HOOVER and 130 or def_w), INSPECT_VISIBLE and h_exp or def_h, true, r.ImGui_WindowFlags_NoScrollbar()) then
        INSPECT_VISIBLE = r.ImGui_TreeNode(ctx, 'NODE INSPECTOR', r.ImGui_TreeNodeFlags_NoTreePushOnOpen())
        INSPECT_HOOVER = r.ImGui_IsItemHovered(ctx)
        if INSPECT_VISIBLE and r.ImGui_BeginChild(ctx, 'Inspect_view') then
            r.ImGui_Separator(ctx)
            InspectorFrame(cur_node)
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleVar(ctx)
end

function DeferTest()
    if r.ImGui_Button(ctx, "RUN") then
        BREAK_RUN = nil
        r.ImGui_SetKeyboardFocusHere(ctx)
        LEGO_MGS = {}
        ClearNodesWarning()
        InitRunFlow()
    end
    r.ImGui_SameLine(ctx)
    if DEFERED_NODE then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), 0x00FF00AA)
    end
    if r.ImGui_Button(ctx, "STOP") then
        if DEFERED_NODE then
            --if START_FLOW and DEFER then
            r.ImGui_PopStyleColor(ctx)
            DEFERED_NODE = nil
            --DEFER = false
            -- START_FLOW = false
        end
    end
    --if START_FLOW and DEFER then
    if DEFERED_NODE then
        r.ImGui_PopStyleColor(ctx)
    end
end

function UI_Buttons()
    r.ImGui_SetCursorPos(ctx, 5, 5)
    -- NIFTY HACK FOR COMMENT BOX NOT OVERLAP UI BUTTONS
    if not r.ImGui_BeginChild(ctx, 'toolbars', -FLT_MIN, -FLT_MIN, false, r.ImGui_WindowFlags_NoInputs()) then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000EE)

    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 0)
    if r.ImGui_BeginChild(ctx, "TopButtons", 420, 25, 1) then
        r.ImGui_SetCursorPos(ctx, 4, 3)
        if r.ImGui_Checkbox(ctx, "GRID", GRID) then GRID = not GRID end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Checkbox(ctx, "WIRE FLOW", SHOW_FLOW) then SHOW_FLOW = not SHOW_FLOW end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, "CENTER VIEW") then
            FLUX.to(CANVAS, 0.5, { off_x = CANVAS.rx / 2 - 100 * CANVAS.scale, off_y = CANVAS.ry / 2 }):ease("cubicout")
        end
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, "ZOOM : " .. string.format("%.3f", CANVAS.scale))

        r.ImGui_SameLine(ctx)
        ------------------
        DeferTest()
        r.ImGui_SameLine(ctx)
        ------------------
        r.ImGui_EndChild(ctx)
    end
    --FunctionIspector()
    --FunctionIO()

    DBGMsg()
    DBGNode()

    --Inspector()
    NodeInspector()
    FunctionIspector()
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_EndChild(ctx)
end

FUNCTION_NAME = "Main"
function FunctionTabs()
    local FUNCTIONS = GetFUNCTIONS()
    r.ImGui_SetCursorPosX(ctx, 5)
    if r.ImGui_BeginTabBar(ctx, "F_TABS") then
        if r.ImGui_BeginTabItem(ctx, "Init", false, CHANGE_FTAB == 1 and r.ImGui_TabItemFlags_SetSelected() or 0) then
            if CURRENT_FUNCTION ~= 1 then Deselect_all() end
            CURRENT_FUNCTION = 1
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "Main", false, CHANGE_FTAB == 2 and r.ImGui_TabItemFlags_SetSelected() or 0) then
            if CURRENT_FUNCTION ~= 2 then Deselect_all() end
            CURRENT_FUNCTION = 2
            r.ImGui_EndTabItem(ctx)
        end
        for i = 3, #FUNCTIONS do
            r.ImGui_PushID(ctx, FUNCTIONS[i].label .. i .. "blabla")
            if FUNCTIONS[i].tab_open then
                RTV, FUNCTIONS[i].tab_open = r.ImGui_BeginTabItem(ctx, FUNCTIONS[i].label, true,
                    CHANGE_FTAB == i and r.ImGui_TabItemFlags_SetSelected() or 0)
                if RTV then
                    if CURRENT_FUNCTION ~= i then Deselect_all() end
                    CURRENT_FUNCTION = i
                    -- CANVAS = FUNCTIONS[CURRENT_FUNCTION].CANVAS
                    r.ImGui_EndTabItem(ctx)
                end
            end
            r.ImGui_PopID(ctx)
        end
        r.ImGui_EndTabBar(ctx)
        CHANGE_FTAB = nil
    end
end

CUR_TAB = "NODES"

function Sidebar()
    local list_tbl --= GetNodeTBL()
    if r.ImGui_BeginTabBar(ctx, "TABS") then
        if r.ImGui_BeginTabItem(ctx, "FUNC", false, CHANGE_MTAB == "FUNC" and r.ImGui_TabItemFlags_SetSelected() or 0) then
            CUR_TAB = "FUNC"
            list_tbl = GetFUNCTIONS()
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "NODES") then
            CUR_TAB = "NODES"
            list_tbl = GetNodeTBL()
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "VARS") then
            CUR_TAB = "VARS"
            list_tbl = GetVariableGETSETTBL()
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "API") then
            CUR_TAB = "API"
            list_tbl = GetApiTBL()
            r.ImGui_EndTabItem(ctx)
        end
        if r.ImGui_BeginTabItem(ctx, "LIBRARY") then
            CUR_TAB = "LIBRARY"
            list_tbl = GetLibrary()
            r.ImGui_EndTabItem(ctx)
        end
        r.ImGui_EndTabBar(ctx)
        CHANGE_MTAB = nil
    end
    r.ImGui_Separator(ctx)
    local aw = r.ImGui_GetContentRegionAvail(ctx)
    r.ImGui_SetNextItemWidth(ctx, CUR_TAB == "FUNC" and -25 or -FLT_MIN)
    --r.ImGui_SetCursorPosX(ctx, 0)
    _, SIDE_FILTER = r.ImGui_InputText(ctx, '##SIDEinput', SIDE_FILTER)
    if CUR_TAB == "FUNC" then
        r.ImGui_SameLine(ctx, nil, 4)
        if r.ImGui_Button(ctx, "+", -FLT_MIN, 19) then
            local node = AddNode("func", "NEW FUNCTION")
            --SetMetaReturnFollower(node)
            local FUNCTIONS = GetFUNCTIONS()
            FUNCTIONS[#FUNCTIONS + 1] = node
            FUNCTIONS[#FUNCTIONS].CANVAS = InitCanvas()
            DIRTY = true
        end
    end
    r.ImGui_Separator(ctx)
    local filter_tbl = Filter_actions(SIDE_FILTER, list_tbl)
    local final_tbl = #SIDE_FILTER ~= 0 and filter_tbl or list_tbl
    r.ImGui_SetNextWindowBgAlpha(ctx, 0)
    if r.ImGui_BeginListBox(ctx, "SIDEBAR", -FLT_MIN, -FLT_MIN) then
        for i = 1, #final_tbl do
            --r.ImGui_PushID(ctx, i .. CUR_TAB)

            local col
            if final_tbl[i].type == "get" then
                col = 0x00FF00FF
            elseif final_tbl[i].type == "set" then
                col = 0x00FFFFFF
            else
                col = 0xFFFFFFFF
            end

            if CUR_TAB == "VARS" then
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), col)
            end

            local selected
            if CUR_TAB == "NODES" or CUR_TAB == "VARS" then
                selected = final_tbl[i].selected
            elseif CUR_TAB == "FUNC" then
                selected = (CUR_SIDEBAR_ID and CUR_SIDEBAR_ID == i or (CURRENT_FUNCTION and CURRENT_FUNCTION == i))
            end

            if RENAME_FUNC and RENAME_FUNC == i then
                r.ImGui_SetNextItemWidth(ctx, 220)
                r.ImGui_SetKeyboardFocusHere(ctx)
                _, final_tbl[i].label = r.ImGui_InputText(ctx, '##t', final_tbl[i].label)
                if ENTER or (not r.ImGui_IsItemActive(ctx) and r.ImGui_IsMouseClicked(ctx, 0)) then
                    UpdateChildFunctionsNames(RENAME_FUNC, final_tbl[i].label)
                    RENAME_FUNC, CUR_SIDEBAR_ID = nil, nil
                end
            else
                r.ImGui_PushID(ctx, '##' .. i .. final_tbl[i].label .. CUR_TAB)
                if r.ImGui_Selectable(ctx, final_tbl[i].label, DRAG_LIST_NODE_ID == i or selected, r.ImGui_SelectableFlags_AllowDoubleClick()) then
                    if CUR_TAB == "NODES" or CUR_TAB == "VARS" then
                        if not SHIFT_DOWN then Deselect_all() end
                        final_tbl[i].selected = true
                    end
                    if r.ImGui_IsMouseDoubleClicked(ctx, 0) then
                        if CUR_TAB == "API" then
                            OpenUrlHelp(final_tbl[i].label)
                        elseif CUR_TAB == "NODES" or CUR_TAB == "VARS" then
                            CenterNodeToScreen(final_tbl[i])
                        elseif CUR_TAB == "FUNC" then
                            if CHANGE_FTAB ~= i then Deselect_all() end

                            CHANGE_FTAB = i
                            CURRENT_FUNCTION = i
                            final_tbl[i].tab_open = true
                        end
                    end
                end
                r.ImGui_PopID(ctx)
            end
            if CUR_TAB == "VARS" then r.ImGui_PopStyleColor(ctx) end

            if CUR_TAB ~= "API" then
                if r.ImGui_IsItemClicked(ctx, 1) then
                    CUR_SIDEBAR_ID = i
                    r.ImGui_OpenPopup(ctx, "Func_CTX")
                end
            end

            -- if r.ImGui_IsItemHovered(ctx) then
            --     Tooltip_Tutorial()
            -- end

            if r.ImGui_IsItemActive(ctx) and r.ImGui_IsMouseDragging(ctx, 0) then
                if CUR_TAB == "API" then
                    if not DRAG_LIST_NODE then
                        DRAG_LIST_NODE_ID = i
                        DRAG_LIST_NODE = AddNode("api", final_tbl[i].label, final_tbl[i])
                    end
                end

                if CUR_TAB == "VARS" then
                    GET_SET_NODE = final_tbl[i]
                    -- if final_tbl[i].type == "set" then
                    --     if not DRAG_LIST_NODE then
                    --         DRAG_LIST_NODE_ID = i
                    --         --GETTER_INFO = final_tbl[i]
                    --         DRAG_LIST_NODE = AddNode("get", "GET " .. final_tbl[i].label)
                    --     end
                    if final_tbl[i].type == "i" or final_tbl[i].type == "f" or final_tbl[i].type == "s" or final_tbl[i].type == "b" or final_tbl[i].type == "t" or final_tbl[i].type == "tc" or final_tbl[i].type == "api_var" then
                        if not DRAG_LIST_NODE then
                            DRAG_LIST_NODE_ID = i
                            DRAG_LIST_NODE = AddNode(final_tbl[i].type, final_tbl[i].label)
                        end
                    end
                end

                if CUR_TAB == "FUNC" then
                    if final_tbl[i].type == "func" then
                        if final_tbl[i].label ~= "Main" and final_tbl[i].label ~= "Init" then
                            if not DRAG_LIST_NODE then
                                DRAG_LIST_NODE_ID = i
                                local FLOLLOWER = PropagateParentFunctionNodes(i)
                                FLOLLOWER.FID = i
                                DRAG_LIST_NODE = FLOLLOWER
                            end
                        end
                    end
                end

                if CUR_TAB == "LIBRARY" then
                    if not DRAG_LIST_NODE then
                        local FUNCTIONS = GetFUNCTIONS()
                        local new = Deepcopy(final_tbl[i])
                        ReplaceGUIDS(final_tbl[i].guid, { new })
                        FUNCTIONS[#FUNCTIONS + 1] = new
                        --FUNCTIONS[#FUNCTIONS].CANVAS = InitCanvas()
                        RelinkFunction(FUNCTIONS[#FUNCTIONS])
                        DRAG_LIST_NODE_ID = #FUNCTIONS

                        local FLOLLOWER = PropagateParentFunctionNodes(DRAG_LIST_NODE_ID)
                        FLOLLOWER.FID = DRAG_LIST_NODE_ID
                        DRAG_LIST_NODE = FLOLLOWER
                    end
                end
            end
        end

        if r.ImGui_BeginPopup(ctx, "Func_CTX") then
            if r.ImGui_MenuItem(ctx, 'Rename') then
                RENAME_FUNC = CUR_SIDEBAR_ID
            elseif r.ImGui_MenuItem(ctx, 'Delete') then
                if CUR_TAB == "FUNC" then
                    local FUNCTIONS = GetFUNCTIONS()
                    if FUNCTIONS[CUR_SIDEBAR_ID].label ~= "Main" and FUNCTIONS[CUR_SIDEBAR_ID].label ~= "Init" then
                        -- DELETE ALL SAME NODE FUNCTIONS
                        for i = 1, #FUNCTIONS do
                            for n = #FUNCTIONS[i].NODES, 1, -1 do
                                local node = FUNCTIONS[i].NODES[n]
                                if node.FID and node.FID == CUR_SIDEBAR_ID then
                                    local next_node = FUNCTIONS[i].NODES[n].outputs[0].connection[1] and
                                        GetNodeInfo(FUNCTIONS[i].NODES[n].outputs[0].connection[1].node)
                                    local next_pin = FUNCTIONS[i].NODES[n].outputs[0].connection[1] and
                                        FUNCTIONS[i].NODES[n].outputs[0].connection[1].pin
                                    local prev_node = FUNCTIONS[i].NODES[n].inputs[0].connection[1] and
                                        GetNodeInfo(FUNCTIONS[i].NODES[n].inputs[0].connection[1].node)
                                    local prev_pin = FUNCTIONS[i].NODES[n].inputs[0].connection[1] and
                                        FUNCTIONS[i].NODES[n].inputs[0].connection[1].pin
                                    DeleteNode(FUNCTIONS[i].NODES, n)
                                    -- AUTOCONNECT PREVIOUS/NEXT NODES IF THIS NODE WAS IN MIDDLE
                                    ConnectNextPreviousFunctionNodes(prev_node, prev_pin, next_node, next_pin)
                                end
                                -- UPDATE NODE FIDS IF GREATER THAN DELETED ONE
                                if node.FID and node.FID > CUR_SIDEBAR_ID then
                                    node.FID = node.FID - 1
                                end
                            end
                        end
                        -- DELETE FUNCTION
                        table.remove(FUNCTIONS, CUR_SIDEBAR_ID)
                        if CUR_SIDEBAR_ID == CURRENT_FUNCTION then
                            CHANGE_FTAB = CUR_SIDEBAR_ID - 1
                            --CURRENT_FUNCTION = CHANGE_FTAB
                            final_tbl[CHANGE_FTAB].tab_open = true
                        end
                        CURRENT_FUNCTION = CURRENT_FUNCTION - 1
                    end
                    --! REMOVE ALL FUNCTIONS
                elseif CUR_TAB == "NODES" then
                    local NODES = GetNodeTBL()
                    if NODES[CUR_SIDEBAR_ID].label ~= "START" then
                        table.remove(NODES, CUR_SIDEBAR_ID)
                    end
                end
            end
            if CUR_SIDEBAR_ID > 2 then
                if r.ImGui_MenuItem(ctx, 'EXPORT') then
                    ExportFunction(CUR_SIDEBAR_ID)
                    InitLibrary()
                end
            end
            r.ImGui_EndPopup(ctx)
        end

        if CUR_SIDEBAR_ID then
            if not r.ImGui_IsPopupOpen(ctx, "Func_CTX") then
                CUR_SIDEBAR_ID = nil
            end
        end
        r.ImGui_EndListBox(ctx)
    end
end

function Popups()
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }

    if OPEN_FILTER and not r.ImGui_IsAnyItemActive(ctx) then
        OPEN_FILTER = nil
        if not r.ImGui_IsPopupOpen(ctx, "FILTER LIST") then
            FILTER = ''
            r.ImGui_OpenPopup(ctx, "FILTER LIST")
        end
    end

    if OPEN_PROMOTE and not r.ImGui_IsAnyItemActive(ctx) then
        OPEN_PROMOTE = nil
        if not r.ImGui_IsPopupOpen(ctx, "PIN_PROMOTE_SET") then
            r.ImGui_OpenPopup(ctx, "PIN_PROMOTE_SET")
        end
    end

    if NEW_WARNIGN then
        if not r.ImGui_IsPopupOpen(ctx, 'Warning') then r.ImGui_OpenPopup(ctx, 'Warning') end
        Modal_POPUP("Save project before closing?", ClearProject)
    end

    if OPEN_FM then
        OPEN_FM = nil
        if not r.ImGui_IsPopupOpen(ctx, "File Dialog") then
            r.ImGui_OpenPopup(ctx, 'File Dialog')
        end
    end

    -- RENAME
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'Rename', nil, r.ImGui_WindowFlags_AlwaysAutoResize() | r.ImGui_WindowFlags_TopMost()) then
        Rename()
        r.ImGui_EndPopup(ctx)
    end

    -- FX LIST
    if r.ImGui_BeginPopup(ctx, "FILTER LIST") then
        FilterBox()
        r.ImGui_EndPopup(ctx)
    end

    -- RIGHT CLICK PIN CONTEXT
    if r.ImGui_BeginPopup(ctx, "PIN_PROMOTE_SET") then
        MOUSE_POPUP_X, MOUSE_POPUP_Y = r.ImGui_GetMousePosOnOpeningCurrentPopup(ctx)

        PinContextMenu()
        r.ImGui_EndPopup(ctx)
    end

    if r.ImGui_BeginPopup(ctx, "GET-SET") then
        MOUSE_POPUP_X, MOUSE_POPUP_Y = r.ImGui_GetMousePosOnOpeningCurrentPopup(ctx)
        GetSetMenu()
        r.ImGui_EndPopup(ctx)
    end

    -- API SUCCESS UPDATE POPUP
    if UPDATE then
        r.ImGui_OpenPopup(ctx, "UPDATE")
        UPDATE = nil
    end

    if ADDED_TO_ACTIONS then
        r.ImGui_OpenPopup(ctx, "ADDED TO ACTIONS")
        ADDED_TO_ACTIONS = nil
    end
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if EXPORT_ACTION_POPUP then
        EXPORT_ACTION_POPUP = nil
        r.ImGui_OpenPopup(ctx, "EXPORT_ACTION_POPUP")
    end

    if EXPORT_ACTION_WARNING then
        EXPORT_ACTION_WARNING = nil
        r.ImGui_OpenPopup(ctx, "EXPORT_ACTION_WARNING")
    end
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if r.ImGui_BeginPopup(ctx, "EXPORT_ACTION_WARNING") then
        r.ImGui_Text(ctx, "\n\t\tPROJECT NEEDS TO BE SAVED FIRST\t\t\n\n")
        r.ImGui_EndPopup(ctx)
    end

    if r.ImGui_BeginPopupModal(ctx, 'EXPORT_ACTION_POPUP', nil, r.ImGui_WindowFlags_AlwaysAutoResize()) then
        r.ImGui_Text(ctx, 'DEFERED SCRIPT?\n\n')
        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'YES', 120, 0) then
            ExportTest(PROJECT_NAME, PROJECT_PATH, true)
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'NO', 120, 0) then
            ExportTest(PROJECT_NAME, PROJECT_PATH)
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'CANCEL', 120, 0) then
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_EndPopup(ctx)
    end

    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if r.ImGui_BeginPopup(ctx, "UPDATE") then
        r.ImGui_Text(ctx, "\n\t\tAPI FILE UPDATED\t\t\n\n")
        r.ImGui_EndPopup(ctx)
    end

    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if r.ImGui_BeginPopup(ctx, "ADDED TO ACTIONS") then
        r.ImGui_Text(ctx, "\n\t\tADDED " .. "ReaSpaghetti_StandAlone_" .. PROJECT_NAME .. " TO ACTION LIST\t\t\n\n")
        r.ImGui_EndPopup(ctx)
    end

    if HELP then
        r.ImGui_OpenPopup(ctx, "Help")
        HELP = nil
    end

    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), 0x000000FF)
    if r.ImGui_BeginPopup(ctx, "Help") then
        r.ImGui_Text(ctx, table.concat(help_tbl, "\n"))
        r.ImGui_EndPopup(ctx)
    end
    r.ImGui_PopStyleColor(ctx)

    if PREFERENCES then
        r.ImGui_OpenPopup(ctx, "PREFERENCES")
        PREFERENCES = nil
    end
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), 0x000000FF)
    if r.ImGui_BeginPopup(ctx, "PREFERENCES") then
        _, TOOLTIP = r.ImGui_Checkbox(ctx, "Tooltips", TOOLTIP)
        _, DEBUG = r.ImGui_Checkbox(ctx, "DEBUG", DEBUG)
        CH_RV, PROFILE_DEBUG = r.ImGui_Checkbox(ctx, "PROFILE SCRIPT", PROFILE_DEBUG)
        if CH_RV then
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_EndPopup(ctx)
    end
    r.ImGui_PopStyleColor(ctx)

    -- FILE MANAGER
    --if OPEN_FM then
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 500, 500, 500, 500)
    if r.ImGui_BeginPopupModal(ctx, 'File Dialog', true, r.ImGui_WindowFlags_TopMost() |  r.ImGui_WindowFlags_NoResize()) then
        --if FM_RV then
        --    r.ShowConsoleMsg("here")
        File_dialog()
        FM_Modal_POPUP()
        r.ImGui_EndPopup(ctx)
        --r.ImGui_End(ctx)
        --end
    end

    if not r.ImGui_IsPopupOpen(ctx, 'FILTER LIST') and not r.ImGui_IsPopupOpen(ctx, 'PIN_PROMOTE_SET') and not r.ImGui_IsPopupOpen(ctx, 'GET-SET') then
        if INSERT_NODE_DATA then INSERT_NODE_DATA = nil end
        if MOUSE_POPUP_X then
            MOUSE_POPUP_X, MOUSE_POPUP_Y = nil, nil
        end
    end
end

function Modal_POPUP(text, func)
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'Warning', nil, r.ImGui_WindowFlags_AlwaysAutoResize()) then
        r.ImGui_Text(ctx, text)
        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'OK', 120, 0) then
            NEED_SAVE = true
            OPEN_FM = true
            FM_TYPE = "SAVE"
            Init_FM_database()
            NEW_WARNIGN = nil
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_SetItemDefaultFocus(ctx)
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'No', 120, 0) then
            func()
            NEW_WARNIGN = nil
            if WANT_CLOSE then CLOSE = true end
            r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_EndPopup(ctx)
    end
end

local types_pl = {
    ["INTEGER"] = "i",
    ["NUMBER"] = "f",
    ["STRING"] = "s",
    ["BOOLEAN"] = "b",
    ["TABLE"] = "t",
}

function CheckWindowPayload()
    if CANVAS.zone_L or CANVAS.zone_R or CANVAS.zone_T or CANVAS.zone_B then return end
    if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'D&DP', nil,
            r.ImGui_DragDropFlags_AcceptNoDrawDefaultRect())
        r.ImGui_EndDragDropTarget(ctx)
        if ret then
            local con_guid, node_guid, tbl_type, pin_type, pin_num, node_label, node_type, pin_label = payload:match(
                "(.+),(.+),(.+),(.+),(.+),(.+),(.+),(.+)")

            local src_node = GetNodeInfo(node_guid)

            local src_io_tbl = tbl_type == "in" and src_node.inputs or src_node.outputs

            -- IF PIN IS ALREADY CONNECTED DO NOTHING
            if next(src_io_tbl[tonumber(pin_num)].connection) then return end

            -- ONLY ALLOW ON RUN PIN SINCE THERE ARE MULTIPLE PINS WITH SAME TYPE (WE DONT KNOW THE TARGET EG. NODE WITH MULTIPLE INTEGERS)
            INSERT_NODE_DATA = {
                link = con_guid,
                node_guid = node_guid,
                node_type = node_type,
                tbl_type = tbl_type,
                pin_type = pin_type,
                pin_label = pin_label,
                pin_num = tonumber(pin_num)
            }

            if pin_type:find("RUN") then
                OPEN_FILTER = true
            else
                if tbl_type == "out" then
                    if node_type == "i" or node_type == "f" or node_type == "s" or node_type == "b" or node_type == "t" or node_type == "tc" or node_type == "api_var" then
                        INSERT_NODE_DATA = nil
                        return
                    end
                    INSERT_NODE_DATA.get_set = "api_var"
                    INSERT_NODE_DATA.in_out = "out"
                    INSERT_NODE_DATA.node_label = node_label
                    OPEN_PROMOTE = true
                elseif tbl_type == "in" then
                    if pin_type ~= "INTEGER" and pin_type ~= "NUMBER" and pin_type ~= "STRING" and pin_type ~= "BOOLEAN" and pin_type ~= "TABLE" then
                        INSERT_NODE_DATA = nil
                        return
                    end
                    INSERT_NODE_DATA.get_set = types_pl[pin_type]
                    INSERT_NODE_DATA.in_out = "in"
                    OPEN_PROMOTE = true
                end
            end
        end
    end
end

local dsc_img = PATH .. "Examples/SCHWA/" .. "TutorialRS.png"

function Tooltip_Tutorial(img)
    if r.ImGui_BeginTooltip(ctx) then
        if not r.ImGui_ValidatePtr(img_obj, 'ImGui_Image*') then
            -- img_obj = r.ImGui_CreateImage(dsc_img)
        end
        -- AnimateSpriteSheet(img_obj, 58, 5, 12, 10, 0, 0)
        r.ImGui_EndTooltip(ctx)
    end
end
