--@noindex
--NoIndex: true

local r = reaper

function Literalize(str)
    return str:gsub(
        "[%(%)%.%%%+%-%*%?%[%]%^%$]",
        function(c)
            return "%" .. c
        end
    )
end

function Ltrim(s)
    if s == nil then return end
    return (s:gsub("^%s*", ""))
end

function OpenFile(file)
    local cmd
    if r.GetOS():sub(1, 3) == 'Win' then
        cmd = 'cmd.exe /C start ""'
    else
        cmd = '/bin/sh -c open ""'
    end
    r.ExecProcess(([[%s "%s"]]):format(cmd, file), 0)
end

function OpenUrlHelp(api)
    local cmd
    if r.GetOS():sub(1, 3) == 'Win' then
        cmd = 'cmd.exe /C start ""'
    else
        cmd = '/bin/sh -c open ""'
    end
    r.ExecProcess(([[%s "https://www.extremraym.com/cloud/reascript-doc/#%s"]]):format(cmd, api), 0)
end

function OpenUrl(api)
    local cmd
    if r.GetOS():sub(1, 3) == 'Win' then
        cmd = 'cmd.exe /C start ""'
    else
        cmd = '/bin/sh -c open ""'
    end
    r.ExecProcess(([[%s %s"]]):format(cmd, api), 0)
end

function ShallowCopy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end

function Deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Deepcopy(orig_key)] = Deepcopy(orig_value)
        end
        setmetatable(copy, Deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function Palette(t)
    local a = { r = 0.5, g = 0.5, b = 0.5 }
    local b = { r = 0.5, g = 0.5, b = 0.5 }
    local c = { r = 1, g = 1, b = 1 }
    local d = { r = 0, g = 0.33, b = 0.67 }

    local brightness = 0.2

    local col = {}
    col.r = math.min(a.r + brightness + math.cos((c.r * t + d.r) * 6.28318) * b.r, 1)
    col.g = math.min(a.g + brightness + math.cos((c.g * t + d.g) * 6.28318) * b.g, 1)
    col.b = math.min(a.b + brightness + math.cos((c.b * t + d.b) * 6.28318) * b.b, 1)
    return col
end

function SerializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0
    local tmp = string.rep(" ", depth)
    if name then
        if type(name) == "number" and math.floor(name) == name then
            name = "[" .. name .. "]"
        elseif not string.match(name, '^[a-zA-z_][a-zA-Z0-9_]*$') then
            name = string.gsub(name, "'", "\\'")
            name = "['" .. name .. "']"
        end
        tmp = tmp .. name .. " = "
    end
    if type(val) == "table" then
        tmp = tmp .. "{"                                               .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            tmp = tmp .. SerializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    else
        val = type(val) ~= 'userdata' and val or nil
        tmp = tmp .. ('%q'):format(val)    
    end
    return tmp
end

function SerializeTableEXTSTATE(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0
    local tmp = string.rep(" ", depth)
    if name then
        if type(name) == "number" and math.floor(name) == name then
            name = "[" .. name .. "]"
        elseif not string.match(name, '^[a-zA-z_][a-zA-Z0-9_]*$') then
            name = string.gsub(name, "'", "\\'")
            name = "['" .. name .. "']"
        end
        tmp = tmp .. name .. " = "
    end
    if type(val) == "table" then
        tmp = tmp .. "{"                                              -- .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            tmp = tmp .. SerializeTable(v, k, skipnewlines, depth + 1) --.. "," .. (not skipnewlines and "\n" or "")
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    else
        -- HOPE TO FIX INF, -INF, NAN 
        val = type(val) ~= 'userdata' and val or nil
        tmp = tmp .. ('%q'):format(val)
    -- elseif type(val) == "number" then
    --     tmp = tmp .. tostring(val)
    -- elseif type(val) == "string" then
    --     tmp = tmp .. string.format("%q", val)
    -- elseif type(val) == "boolean" then
    --     tmp = tmp .. (val and "true" or "false")
    -- else
    --     --! THIS IS MODIFICATION FOR THIS SCRIPT
    --     --! POINTERS GET RECALCULATED ON RUN SO WE NIL HERE (MEDIATRACKS, MEDIAITEMS... )
    --     tmp = tmp .. "nil"
    --     --tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end
    return tmp
end

function TableToString(table) return SerializeTable(table) end

function StringToTable(str)
    local f, err = load("return " .. str)
    if err then
        reaper.ShowConsoleMsg("\nerror" .. err)
    end
    return f ~= nil and f() or nil
end

function Unbackslashed(s)
    local str = tostring(s)
    local ch = {
        ["\\a"] = '\\007',  --'\a' alarm             Ctrl+G BEL
        ["\\b"] = '\\008',  --'\b' backspace         Ctrl+H BS
        ["\\f"] = '\\012',  --'\f' formfeed          Ctrl+L FF
        ["\\n"] = '\\010',  --'\n' newline           Ctrl+J LF
        ["\\r"] = '\\013',  --'\r' carriage return   Ctrl+M CR
        ["\\t"] = '\\009',  --'\t' horizontal tab    Ctrl+I HT
        ["\\v"] = '\\011',  --'\v' vertical tab      Ctrl+K VT
        ["\\\n"] = '\\010', --     newline
        ["\\\\"] = '\\092', --     backslash
        ["\\'"] = '\\039',  --     apostrophe
        ['\\"'] = '\\034',  --     quote
    }
    return str:gsub("(\\.)", ch)
        :gsub("\\(%d%d?%d?)", function(n)
            return string.char(tonumber(n))
        end)
end

function Dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. Dump(v) .. ',' .. "\n"
        end
        return s .. '} '
    else
        return tostring(o)
    end
end
