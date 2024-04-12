--@noindex
--NoIndex: true
local r = reaper

local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" .. package.path -- GET DIRECTORY FOR REQUIRE

function CheckDeps()
    local deps = {}
    if not r.ImGui_GetVersion then
        deps[#deps + 1] = '"Dear Imgui"'
    end
    if not r.JS_VKeys_Intercept then
        deps[#deps + 1] = '"js_ReaScriptAPI"'
    end
    if not r.SNM_SetIntConfigVar then
        deps[#deps + 1] = '"SWS/S&M"'
    end

    if #deps ~= 0 then
        r.ShowMessageBox("Need Additional Packages.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
        r.ReaPack_BrowsePackages(table.concat(deps, " OR "))
        return true
    end
end

function SaveToFile(data, fn)
    local file
    file = io.open(fn, "w")
    if file then
        file:write(data)
        file:close()
    end
end

function InTbl(tbl, val)
    for i = 1, #tbl do
        if tbl[i].guid == val then
            return tbl[i], i
        end
    end
end

function PngToRelative(fn)
    local file = io.open(fn, "r")
    if not file then return end
    local content = file:read("a")
    if content == "" then return end
    content = content:gsub('png = "(.-)/Data', 'png = "/Data')
    file = io.open(fn, "w")
    if file then
        file:write(content)
        file:close()
    end
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

function pow(x, p) return x ^ p end

function ReadFromFile(fn)
    local file = io.open(fn, "r")
    if not file then return end
    local content = file:read("a")
    if content == "" then return end
    return StringToTable(content)
end

function StringToTable(str)
    local f, err = load("return " .. str)
    return f ~= nil and f() or nil
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
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            if k ~= "selected" and k ~= "guid_list" and k ~= "img_obj" then
                tmp = tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
            end
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

function TableToString(table, new_line)
    local str = serializeTable(table, nil, new_line)
    return str
end

if not r.HasExtState("PIE3000", "RELATIVE_PNG") then
    --! REMOVE THIS AFTER A WHILE (THIS IS CURRENT SILENT PNG RELATIVE PATH FIX)
    local menu_file = script_path .. "menu_file.txt"
    local pie_file = script_path .. "pie_file.txt"
    PngToRelative(pie_file)
    PngToRelative(menu_file)
    r.SetExtState("PIE3000", "RELATIVE_PNG", "fix", true)
end
