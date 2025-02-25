--@noindex
--NoIndex: true

local r = reaper

function Literalize(str)
    return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
end

function serializeTable(val, name, skipnewlines, depth)
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
        tmp = tmp .. "{"
        for k, v in pairs(val) do
            tmp = tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. ","
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end
    return tmp
end

function tableToString(table)
    return serializeTable(table)
end

function stringToTable(str)
    local f, err = load("return " .. str)
    return f ~= nil and f() or nil
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

local pearson_table = {
    9, 159, 180, 252, 71, 6, 13, 164, 232, 35, 226, 155, 98, 120, 154, 69,
    157, 24, 137, 29, 147, 78, 121, 85, 112, 8, 248, 130, 55, 117, 190, 160,
    176, 131, 228, 64, 211, 106, 38, 27, 140, 30, 88, 210, 227, 104, 84, 77,
    75, 107, 169, 138, 195, 184, 70, 90, 61, 166, 7, 244, 165, 108, 219, 51,
    9, 139, 209, 40, 31, 202, 58, 179, 116, 33, 207, 146, 76, 60, 242, 124,
    254, 197, 80, 167, 153, 145, 129, 233, 132, 48, 246, 86, 156, 177, 36, 187,
    45, 1, 96, 18, 19, 62, 185, 234, 99, 16, 218, 95, 128, 224, 123, 253,
    42, 109, 4, 247, 72, 5, 151, 136, 0, 152, 148, 127, 204, 133, 17, 14,
    182, 217, 54, 199, 119, 174, 82, 57, 215, 41, 114, 208, 206, 110, 239, 23,
    189, 15, 3, 22, 188, 79, 113, 172, 28, 2, 222, 21, 251, 225, 237, 105,
    102, 32, 56, 181, 126, 83, 230, 53, 158, 52, 59, 213, 118, 100, 67, 142,
    220, 170, 144, 115, 205, 26, 125, 168, 249, 66, 175, 97, 255, 92, 229, 91,
    214, 236, 178, 243, 46, 44, 201, 250, 135, 186, 150, 221, 163, 216, 162, 43,
    11, 101, 34, 37, 194, 25, 50, 12, 87, 198, 173, 240, 193, 171, 143, 231,
    111, 141, 191, 103, 74, 245, 223, 20, 161, 235, 122, 63, 89, 149, 73, 238,
    134, 68, 93, 183, 241, 81, 196, 49, 192, 65, 212, 94, 203, 10, 200, 47,
}
assert(#pearson_table == 0x100)

function pearson8(str)
    local hash = 0
    for c in str:gmatch('.') do
        hash = pearson_table[(hash ~ c:byte()) + 1]
    end
    return hash
end

local tsort = table.sort
function SortTable(tab, val1, val2)
    tsort(tab, function(a, b)
        if (a[val1] < b[val1]) then
            -- primary sort on position -> a before b
            return true
        elseif (a[val1] > b[val1]) then
            -- primary sort on position -> b before a
            return false
        else
            -- primary sort tied, resolve w secondary sort on rank
            return a[val2] < b[val2]
        end
    end)
end

function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

local old_t = {}
local old_filter = ""
function Filter_actions(filter_text, tbl)
    if old_filter == filter_text then return old_t end
    filter_text = Lead_Trim_ws(filter_text)
    local t = {}
    if filter_text == "" or not filter_text then return t end
    for i = 1, #tbl do
        local name = tbl[i]:lower()
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then t[#t + 1] = { score = tbl[i]:len() - filter_text:len(), name = tbl[i] } end
    end
    if #t >= 2 then
        SortTable(t, "score", "name") -- Sort by key priority
    end
    old_t = t
    old_filter = filter_text
    return t
end

function SetMinMax(Input, Min, Max)
    if Input >= Max then
        Input = Max
    elseif Input <= Min then
        Input = Min
    else
        Input = Input
    end
    return Input
end

function ClearExtState()
    r.DeleteExtState("PARANORMALFX2", "COPY_BUFFER", false)
    r.DeleteExtState("PARANORMALFX2", "COPY_BUFFER_ID", false)
    CLIPBOARD = {}
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

function HasMultiple(tbl)
    local cnt = 0
    for _ in pairs(tbl) do
        cnt = cnt + 1
        if cnt == 2 then return true end
    end
    --return count
  end
  

function M_CLICK() return r.JS_Mouse_GetState(95) &1 == 1 end

function M_TEST()
    if not LAST_CLICK and M_CLICK() then
        LAST_CLICK = true
    end

    MOUSE_UP = not LAST_CLICK and true or false

    if LAST_CLICK and not M_CLICK() then
        LAST_CLICK = nil
    end
end

--profiler.attachToWorld() -- after all functions have been defined