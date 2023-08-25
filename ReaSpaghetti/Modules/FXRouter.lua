local r = reaper

local function GetFileContext(fp)
    local str = "\n"
    local f = io.open(fp, 'r')
    if f then
        str = f:read('a')
        f:close()
    end
    return str
end

local function FX_NAME(str)
    local vst_name
    for name_segment in str:gmatch('[^%,]+') do
        if name_segment:match("(%S+) ") then
            if name_segment:match('"(JS: .-)"') then
                vst_name = name_segment:match('"JS: (.-)"') and "JS:" .. name_segment:match('"JS: (.-)"') or nil
            else
                vst_name = name_segment:match("(%S+ .-%))") and "VST:" .. name_segment:match("(%S+ .-%))") or nil
            end
        end
    end
    if vst_name then return vst_name end
end

function GetPlugins()
    local fx_list    = {}
    local tbl        = {}

    local vst_path   = r.GetResourcePath() .. "/reaper-vstplugins64.ini"
    local vst_str    = GetFileContext(vst_path)

    local vst_path32 = r.GetResourcePath() .. "/reaper-vstplugins.ini"
    local vst_str32  = GetFileContext(vst_path32)

    local jsfx_path  = r.GetResourcePath() .. "/reaper-jsfx.ini"
    local jsfx_str   = GetFileContext(jsfx_path)

    local au_path    = r.GetResourcePath() .. "/reaper-auplugins64-bc.ini"
    local au_str     = GetFileContext(au_path)

    local plugins    = vst_str .. vst_str32 .. jsfx_str .. au_str

    for line in plugins:gmatch('[^\r\n]+') do tbl[#tbl + 1] = line end

    for i = 1, #tbl do
        local fx_name = FX_NAME(tbl[i])
        if fx_name then
            fx_list[#fx_list + 1] = {
                fname = "FX_" .. fx_name,
                label = fx_name,
                ins = {},
                out = {},
            }
        end
    end
    return fx_list
end

function AddFXToTrack(name)
    local TRACK_FX_CNT = r.TrackFX_GetCount(TRACK)
    r.TrackFX_AddByName(TRACK, name, false, -1000 - TRACK_FX_CNT)
    local fx_guid = r.TrackFX_GetFXGUID(TRACK, TRACK_FX_CNT + 1)
    return fx_guid
end

function GetTrackFxIndexFromFxGUID(fx_guid)
    for i = 1, TRACK_FX_CNT do
        if r.TrackFX_GetFXGUID(TRACK, i - 1) == fx_guid then return i end
    end
end

function Set_Pin_Mapping(node_id, pin_type, pin_n, low32, high32)
    r.TrackFX_SetPinMappings(TRACK, node_id - 1, pin_type, pin_n - 1, low32, high32)
end

local function Validate_FX_Nodes(nodes)
    for i = #nodes, 2, -1 do
        if not GetTrackFxIndexFromFxGUID(nodes[i].guid) then
            if nodes[i].type == "fx" then
                table.remove(nodes, i)
            end
        end
    end
end

local function UpdateTRCH(node)
    for i = #node.outputs, 1, -1 do
        if i > TR_CH // 2 then
            table.remove(node.outputs, i)
            table.remove(node.inputs, i)
        elseif i < TR_CH // 2 and not node.outputs[i + 1] then
            local ins = {
                { name = tostring(i * 2 + 1) .. "/" .. tostring(i * 2 + 2), type = "INTEGER" } }
            local out = {
                { name = tostring(i * 2 + 1) .. "/" .. tostring(i * 2 + 2), type = "INTEGER" } }
            local inputs = CreateInputs("in", ins)
            local outputs = CreateInputs("out", out)
            node.inputs[#node.inputs + 1] = inputs[1]
            node.outputs[#node.outputs + 1] = outputs[1]
        end
    end
end

function GetTrackFX_Nodes()
    TRACK = r.GetSelectedTrack(0, 0)
    if not TRACK then return end

    local FX_NODES = GetCurFunctionNodes()
    TRACK_FX_CNT = r.TrackFX_GetCount(TRACK)
    TR_CH = r.GetMediaTrackInfo_Value(TRACK, "I_NCHAN")
    Validate_FX_Nodes(FX_NODES)
    --if not TRACK_FX_CNT then return end
    local prev_node = FX_NODES[#FX_NODES]
    for i = 1, TRACK_FX_CNT do
        local fx_guid = r.TrackFX_GetFXGUID(TRACK, i - 1)
        if not In_TBL(FX_NODES, fx_guid) then
            local prev_node_x = prev_node and prev_node.x + prev_node.w + 250 or 0
            local offset_y = prev_node and prev_node.y or 100

            local _, fx_name = r.TrackFX_GetFXName(TRACK, i - 1)
            fx_name = fx_name:match('[%:%/%s]+(.*)'):gsub('%(.-%)', '')

            local offset_x = prev_node_x and prev_node_x or 0

            local tbl = Create_constant_tbl("fx")
            tbl.fname = "FX_" .. fx_name

            FX_NODES[#FX_NODES + 1] = Get_Node("fx", fx_name, offset_x, offset_y, 0, 0, fx_guid, tbl)
        else
            UpdateTRCH(FX_NODES[i + 1]) -- FIRST NODE IS START NODE WE SKIP IT
            --PinToWire(FX_NODES[i + 1])  -- FIRST NODE IS START NODE WE SKIP IT
        end
        prev_node = FX_NODES[#FX_NODES]
    end
end
