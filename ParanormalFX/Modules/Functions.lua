--@noindex
--NoIndex: true

local r = reaper
local find = string.find

function OpenFX(id)
    r.Undo_BeginBlock()
    local open = r.TrackFX_GetFloatingWindow(TRACK, id)
    r.TrackFX_Show(TRACK, id, open and 2 or 3)
    EndUndoBlock("OPEN FX UI")
end

-- lb0 FUNCTION
local function Chunk_GetFXChainSection(chunk)
    -- MAKE SURE WE FOUND FXCHAIN (CAN BE WITHOUT THIS ALSO)
    local s1 = find(chunk, '<FXCHAIN.-\n')
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
    local r_guid = guid:reverse()
    local s1 = find(r_chunk, r_guid, 1, true)
    if s1 then
        local s = s1
        local indent, op, cl = nil, nil, nil
        while (not indent or indent > 0) do
            -- INITIATE START HERE SINCE WE ARE IN CONTAINER ALREADY
            if not indent then indent = 0 end
            cl = find(r_chunk, ('\n<'):reverse(), s + 1, true)
            op = find(r_chunk, ('\n>\n'):reverse(), s + 1, true) + 1
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
    local _, chunk = r.GetTrackStateChunk(TRACK, "")

    local chain_chunk, s1, cl
    if not guid then
        chain_chunk, s1, cl = Chunk_GetFXChainSection(chunk)
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


local min = math.min
function ringInsert(buffer, value)
    buffer[buffer.ptr] = value
    buffer.ptr = (buffer.ptr + 1) % buffer.max_size
    buffer.size = min(buffer.size + 1, buffer.max_size)
end

function ringEnum(buffer)
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

function AddFX(name, id, parallel)
    if not TRACK then return end
    
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
        r.TrackFX_AddByName(TRACK, name, false, idx)
        
        local is_parallel = parallel
        is_parallel = INSERT_FX_PARALLEL_POS or is_parallel
        is_parallel = (REPLACE_FX_POS and REPLACE_FX_POS.tbl[REPLACE_FX_POS.i].p > 0) or is_parallel
        --! PREPARE THIS FOR MIDIMERGE
        if is_parallel then r.TrackFX_SetNamedConfigParm(TRACK, id, "parallel", DEF_PARALLEL) end

        INSERT_FX_SERIAL_POS, INSERT_FX_PARALLEL_POS = nil, nil
    end
    local replaced
    if REPLACE_FX_POS then
        local parrent_container = GetParentContainerByGuid(REPLACE_FX_POS.tbl[REPLACE_FX_POS.i])
        parrent_container = GetFx(parrent_container.guid)
        local del_id = CalcFxID(parrent_container, REPLACE_FX_POS.i + 1)
        r.TrackFX_Delete(TRACK, del_id)
        REPLACE_FX_POS = nil
        replaced = true
    end
    LAST_USED_FX = name
    UpdateFxData()
    EndUndoBlock((replaced and "REPLACED FX: " or "ADD FX: ") .. name .. (parallel and " PARALLEL LANE" or " SERIAL LANE"))
end

function RemoveAllFX()
    r.PreventUIRefresh(1)
    r.Undo_BeginBlock()
    for i = r.TrackFX_GetCount(TRACK), 1, -1 do
        r.TrackFX_Delete(TRACK, i - 1)
    end
    EndUndoBlock("DELETE ALL FX IN CHAIN")
    r.PreventUIRefresh(-1)
end