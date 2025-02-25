--@noindex
--NoIndex: true

local r = reaper
local find = string.find

local INV_TAU = 1 / (2 * math.pi)
local sin, floor, abs, pi, fmod, randomseed, random = math.sin, math.floor, math.abs, math.pi, math.fmod, math
    .randomseed, math.random

function Wrap(number)
    return number <= 1 and number or number - 1
end

function ReaperPhase(speed)
    return fmod(TIME_SINCE_START * speed, 1.0)
end

function Sine(t, a, f)
    f = f * (pi * 2)
    local s = -sin(t * f) * a
    return s, s
end

function Square(t, a, f)
    f = f * (pi * 2)
    local s = sin(t * f)
    s = abs(s) / s * a
    return s, s
end

function SawtL(t, a, f)
    f = f * (pi * 2)
    return ((f * t) * 2 - a)
    --local s = (t) * INV_TAU
    --s = 2 * (s - floor(0.5 + s)) * a
    --return s, s
end

function SawtR(t, a, f)
    f = f * (pi * 2)
    -- local s = (t * f) * -INV_TAU
    -- s = 2 * (s - (0.5 + s) // 1) * a
    -- return s, s
    return ((f * t) * -2 + a)
end

function Triangle(t, a, f)
    f = f * (pi * 2)
    local s = (t * f) * INV_TAU
    s = (2 * abs(2 * (s - (0.5 + s) // 1)) - 1) * a
    return s, s
end

function GetWaveType(shape, t, x, y, w, h, inv)
    local shape_points = {}
    if shape == 0 then
        local points = {}
        for i = 1, w, 2 do
            local t2 = 1 / w
            local yval = Sine(t2 * i, h / 2 - 2, 1)
            points[#points + 1] = x + (i*CANVAS.scale)
            points[#points + 1] = y + (yval + (h / 2))*CANVAS.scale
        end
        return r.new_array(points, #points), Sine(t, h / 2, 1)
    elseif shape == 1 then
        shape_points = inv and { { 0, h - 2, w / 2, h - 2 }, { w / 2, 2, w / 2, h - 2 }, { w / 2, 2, w, 2 } } or
            { { 0, 2, w / 2, 2 }, { w / 2, 2, w / 2, h - 2 }, { w / 2, h - 2, w, h - 2 } }
        return shape_points, -Square(t, (h / 2) - 2, 1)
    elseif shape == 2 then
        shape_points = { { 0, 2, w, h - 2 } }
        return shape_points, SawtL(t, h / 2, 1)
    elseif shape == 3 then
        shape_points = { { 0, h - 2, w, 2 } }
        return shape_points, SawtR(t, h / 2, 1)
    elseif shape == 4 then
        shape_points = { { 0, h - 2, w / 2, 2 }, { w / 2, 2, w, h - 2 } }
        return shape_points, -Triangle(t, h / 2, 1)
    elseif shape == 5 then
        math.randomseed(r.time_precise())
        local rnd_shape = math.random(0, 4)
        local _, rnd_y = GetWaveType(rnd_shape, t, x, y, w, h)
        return shape_points, rnd_y
    end
end

function MapToParents(track, fx_id, p_id)
    local has_parent = true
    local cont_idx, new_idx
    local cur_fx = fx_id
    while has_parent do -- to get root parent container id
        has_parent, new_idx = API.GetNamedConfigParm(track, cur_fx, "parent_container")
        cur_fx = new_idx
        if #new_idx ~= 0 then cont_idx = new_idx end
    end
    if cont_idx then
        local _, buf = API.GetNamedConfigParm(track, cont_idx, "container_map.add." .. fx_id .. "." .. p_id)
        return cont_idx, buf
    end
end

function LinkLastTouched(track, src_fx_id, src_p_id)
    local cur_fx_id, buf = MapToParents(track, LASTTOUCH_FX_ID, LASTTOUCH_P_ID)
    -- TARGET IN CONTAINER
    if buf then
        -- TARGET IN CONTAINER
        API.SetNamedConfigParm(track, cur_fx_id, "param." .. buf .. ".plink.active", 1)
        API.SetNamedConfigParm(track, cur_fx_id, "param." .. buf .. ".plink.effect", src_fx_id)
        API.SetNamedConfigParm(track, cur_fx_id, "param." .. buf .. ".plink.param", src_p_id)
    else
        API.SetNamedConfigParm(track, LASTTOUCH_FX_ID, "param." .. LASTTOUCH_P_ID .. ".plink.active", 1)
        API.SetNamedConfigParm(track, LASTTOUCH_FX_ID, "param." .. LASTTOUCH_P_ID .. ".plink.effect", src_fx_id)
        API.SetNamedConfigParm(track, LASTTOUCH_FX_ID, "param." .. LASTTOUCH_P_ID .. ".plink.param", src_p_id)
    end
end

function OpenFX(id)
    r.Undo_BeginBlock()
    local open = API.GetFloatingWindow(TARGET, id)
    API.Show(TARGET, id, open and 2 or 3)
    EndUndoBlock("OPEN FX UI")
end

-- lb0 FUNCTION
local function Chunk_GetFXChainSection(chunk, chunk_start)
    -- MAKE SURE WE FOUND FXCHAIN (CAN BE WITHOUT THIS ALSO)
    local s1 = find(chunk, chunk_start)
    -- CHAIN STARTS WITH BYPASS
    s1 = find(chunk, 'BYPASS ', s1)
    if s1 then
        if not s1 then return end
        local s = s1
        local indent, op, cl = 1, nil, nil
        while indent > 0 do
            op = find(chunk, '\n<', s + 1, true)
            cl = find(chunk, '\n>\n', s + 1, true) + 1
            if op == nil and cl == nil then break end
            if op ~= nil then
                op = op + 1
                if op <= cl then
                    indent = indent + 1
                    s = op
                else
                    indent = indent - 1
                    s = cl
                end
            else
                indent = indent - 1
                s = cl
            end
        end

        local chain_chunk = string.sub(chunk, s1, cl)
        return chain_chunk
    end
end

-- EXTRACT
-- REVERSE EVERYTHING WE ARE LOOKIG FROM END TO START (WE FIND GUID THEN WE FIND ITS PARENT)
function ExtractContainer(chunk, guid)
    local r_chunk = chunk:reverse()
    local r_guid = ("FXID ".. guid):reverse() -- DONT MATCH EXTSTATE
    local s1 = find(r_chunk, r_guid, 1, true)
    if s1 then
        local s = s1
        local indent, op, cl = nil, nil, nil
        while (not indent or indent > 0) do
            if not indent then indent = 0 end
            cl = find(r_chunk, ('<\n'), s + 1, true) + 1 
            op = find(r_chunk, ('>\n'), s + 1, true)
            if op ~= nil then
                op = op + 1
                if op <= cl then
                    indent = indent + 1
                    s = op
                else
                    indent = indent - 1
                    s = cl
                end
            else
                indent = indent - 1
                s = cl
            end 
        end
        local chain_chunk = string.sub(r_chunk, s1, cl):reverse()
        local cont_fx_chunk = "BYPASS 0 0 0" .. chain_chunk .. "\nWAK 0 0"
        return cont_fx_chunk
    end
end

function ExtractContainer_BUGGY(chunk, guid)
    local r_chunk = chunk:reverse()
    local r_guid = guid:reverse()
    local s1 = find(r_chunk, r_guid, 1, true)
    --r.ShowConsoleMsg(guid.."\n\n\n\n")
    --r.ShowConsoleMsg(guid.."\n")
    --r.ShowConsoleMsg(r_chunk.."\n")

    if s1 then
        local s = s1
        local indent, op, cl = nil, nil, nil
        while (not indent or indent > 0) do
            -- INITIATE START HERE SINCE WE ARE IN CONTAINER ALREADY
            if not indent then indent = 0 end
            cl = find(r_chunk, ('\n<'):reverse(), s + 1, true)
            op = find(r_chunk, ('\n>\n'):reverse(), s + 1, true) + 1
            if op == nil or cl == nil then break end
            if op ~= nil then
                op = op + 2
                if op <= cl then
                    indent = indent + 1
                    s = op
                else
                    indent = indent - 1
                    s = cl
                end
            else
                indent = indent + 1
                s = cl
            end
        end
        local chain_chunk = string.sub(r_chunk, s1, cl):reverse()
        local cont_fx_chunk = "BYPASS 0 0 0\n" .. chain_chunk .. "\nWAK 0 0"
        return cont_fx_chunk
    end
end

function GetFXChainChunk(chunk)
    local number_of_spaces = 2
    local t = {}
    local indent = 0
    local add = false
    for line in chunk:gmatch("[^\n]+") do
        if add then
            indent = indent + 1
            add = false
        end
        if line:find("^<") then
            add = true
        elseif line == ">" then
            indent = indent - 1
        end

        -- ENVELOPE PARAMETER SECTION ENDED > IS FOUND IN SAME INDENTETION
        if PARAM_START and PARAM_START == indent then
            PARAM_START = nil
            PARAM_END = true
        end

        local fx_chunk_name = line:match('<(%S+) ')
        if fx_chunk_name == 'PARMENV' then
            PARAM_START = indent
        end

        -- SKIP ADDING IF ENVELOPE PARAMETER SECTION
        if not PARAM_START and not PARAM_END then
            if not line:match('FXID') and not line:match('FLOATPOS') then
                t[#t + 1] = (string.rep(string.rep(" ", number_of_spaces), indent) or "") .. line
            end
        end
        -- SET IT NIL HERE SO IT DOES NOT ADD ITS LAST > INTO TABLE
        if PARAM_END then PARAM_END = nil end
    end
    return table.concat(t, "\n")
end

function CreateFxChain(guid)
    --r.ShowConsoleMsg(tostring(TARGET))
    local _, chunk, chunk_start
    if MODE == "TRACK" then 
        _, chunk = r.GetTrackStateChunk(TARGET, "")
        chunk_start = '<FXCHAIN.-\n'
    elseif MODE == "ITEM" then
        chunk_start = '<TAKEFX.-\n'
        _, chunk  = r.GetItemStateChunk( ITEM, "" )
    end
    
    local chain_chunk, s1, cl
    if not guid then
        chain_chunk, s1, cl = Chunk_GetFXChainSection(chunk, chunk_start)
    else
        chain_chunk, s1, cl = ExtractContainer(chunk, guid)
    end
    -- TRIM INNER CHAIN TO MAKE SAME STRUCTURE AS .RfxChain
    if chain_chunk then
        -- FIND FIRST BYPASS
        local fx_chain_chunk = GetFXChainChunk(chain_chunk)
        SAVED_DATA = fx_chain_chunk
    end
end

SLOTS = {}

function StoreSlot(x)
    local _, chunk = r.GetTrackStateChunk(TARGET, "")
    local chain_chunk = Chunk_GetFXChainSection(chunk)
    SLOTS[x] = chain_chunk
end

function LoadSlot(x)
    if #SLOTS[x] == 0 then return end
    local _, track_chunk = r.GetTrackStateChunk(TARGET, "")
    local chain_chunk = Chunk_GetFXChainSection(track_chunk)
    local slot_chunk = Literalize(SLOTS[x])
    local new_chunk = string.gsub(track_chunk, chain_chunk, slot_chunk)
    r.SetTrackStateChunk(TARGET, new_chunk, false)
end

local min = math.min
function RingInsert(buffer, value)
    buffer[buffer.ptr] = value
    buffer.ptr = (buffer.ptr + 1) % buffer.max_size
    buffer.size = min(buffer.size + 1, buffer.max_size)
end

function RingEnum(buffer)
    if buffer.size < 1 then return function() end end

    local i = 0
    return function()
        local j = (buffer.ptr + i) % buffer.size
        if i < buffer.size then
            local value = buffer[j]
            i = i + 1
            return value
        end
    end
end

peak_width = 35
function DrawPeak(dl, tbl, x, y, w, h)
    -- TODO: use w to skip some samples

    if tbl.size < 1 then return end

    local half_h = h / 2
    local zero_y = y + half_h

    local points = r.new_array(tbl.size * 2)

    local n = 0
    for spl_stereo in RingEnum(tbl) do
        local val = (spl_stereo[1] + spl_stereo[2]) / 2
        --val = val * 0.2
        local i = 1 + (n * 2)
        points[i] = x + (i * 0.3) --* 0.2)
        points[i + 1] = zero_y + (half_h * val)

        n = n + 1
    end

    r.ImGui_DrawList_AddPolyline(dl, points, 0xFFFFFFFF, 0, 2)
end

function GetPeakInfo(tbl, lfo_type, freq, h)
    local t = r.ImGui_GetTime(ctx)
    local wf
    if lfo_type == "0" then
        wf = Sine(t, 1, 1, freq)
    elseif lfo_type == "1" then
        wf = Square(t, 1, 1, freq)
    elseif lfo_type == "2" then
        wf = SawtL(t, 1, 1, freq)
    elseif lfo_type == "3" then
        wf = SawtR(t, 1, 1, freq)
    elseif lfo_type == "4" then
        wf = Triangle(t, 1, 1, freq)
    elseif lfo_type == "5" then
        -- random
        --wf = Triangle(t, 1, 1, freq * 2)
    end

    RingInsert(tbl, { wf, wf })
end

function CheckPMActive(fx_id)
    local found = false
    for p_id = 0, API.GetNumParams(TARGET, fx_id) do
        local rv, mod = API.GetNamedConfigParm(TARGET, fx_id, "param." .. p_id .. ".mod.active")
        local rv, acs = API.GetNamedConfigParm(TARGET, fx_id, "param." .. p_id .. ".acs.active")
        local rv, lfo = API.GetNamedConfigParm(TARGET, fx_id, "param." .. p_id .. ".lfo.active")
        local fx_env = API.GetFXEnvelope(TARGET, fx_id, p_id, false)
        local has_points = (fx_env and r.CountEnvelopePoints(fx_env) > 2)
        if mod == "1" or lfo == "1" or acs == "1" or has_points then found = true end
    end
    return found
end

function MonitorLastTouchedFX()
    LASTTOUCH_RV, LASTTOUCH_TR_NUM, _, _, LASTTOUCH_FX_ID, LASTTOUCH_P_ID = r.GetTouchedOrFocusedFX(0)
end

function AddFX(name, id, parallel)
    if not TARGET then return end

    r.Undo_BeginBlock()
    if INSERT_FX_ENCLOSE_POS then
        CreateContainerAndInsertFX(INSERT_FX_ENCLOSE_POS.tbl, INSERT_FX_ENCLOSE_POS.i, name)
        INSERT_FX_ENCLOSE_POS = nil
    else
        id = INSERT_FX_SERIAL_POS or id
        id = INSERT_FX_PARALLEL_POS or id
        id = REPLACE_FX_POS and REPLACE_FX_POS.id or id

        if not id then return end

        local idx = id > 0x2000000 and id or -1000 - id
        API.AddByName(TARGET, name, MODE == "ITEM" and idx or false, idx)

        local is_parallel = parallel
        is_parallel = INSERT_FX_PARALLEL_POS or is_parallel
        is_parallel = (REPLACE_FX_POS and REPLACE_FX_POS.tbl[REPLACE_FX_POS.i].p > 0) or is_parallel
        --! PREPARE THIS FOR MIDIMERGE
        if is_parallel then API.SetNamedConfigParm(TARGET, id, "parallel", DEF_PARALLEL) end

        INSERT_FX_SERIAL_POS, INSERT_FX_PARALLEL_POS = nil, nil
    end
    local replaced
    if REPLACE_FX_POS then
        local parrent_container = GetParentContainerByGuid(REPLACE_FX_POS.tbl[REPLACE_FX_POS.i])
        parrent_container = GetFx(parrent_container.guid)
        local del_id = CalcFxID(parrent_container, REPLACE_FX_POS.i + 1)
        API.Delete(TARGET, del_id)
        REPLACE_FX_POS = nil
        replaced = true
    end
    LAST_USED_FX = name
    UpdateFxData()
    EndUndoBlock((replaced and "REPLACED FX: " or "ADD FX: ") ..
        name .. (parallel and " PARALLEL LANE" or " SERIAL LANE"))
end

function RemoveAllFX()
    r.PreventUIRefresh(1)
    r.Undo_BeginBlock()
    for i = API.GetCount(TARGET), 1, -1 do
        API.Delete(TARGET, i - 1)
    end
    EndUndoBlock("DELETE ALL FX IN CHAIN")
    r.PreventUIRefresh(-1)
    SEL_TBL = {}
end

function SetFXSlot(tbl, num)
    local chunk = tbl.fx[num].chunk
    local _, track_chunk = r.GetTrackStateChunk(TARGET, "", false)
    local fx_slot_chunk = get_fx_chunk(tbl.guid)
    local fx_chunk = Literalize(fx_slot_chunk)
    local new_chunk = string.gsub(track_chunk, fx_chunk, chunk)
    r.SetTrackStateChunk(TARGET, new_chunk, false)
end

function SetOnlyItemSelected(target_take)
    r.PreventUIRefresh(-1)
    for i = 1,  r.CountTrackMediaItems( TRACK ) do
        local item =  r.GetTrackMediaItem( TRACK, i-1 )
        r.SetMediaItemSelected( item, false )
    end
    local target_item = r.GetMediaItemTake_Item( target_take )
    r.SetMediaItemSelected( target_item, true )
    r.PreventUIRefresh(1)
    r.UpdateArrange()
end

--profiler.attachToWorld() -- after all functions have been defined