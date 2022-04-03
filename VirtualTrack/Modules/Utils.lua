--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.03
	 * NoIndex: true
--]]

local reaper = reaper
function Break( msg )
    local line = "Breakpoint at line " .. debug.getinfo(2).currentline
    local ln = "\n" .. string.rep("=", #line) .. "\n"
    local trace = debug.traceback(ln .. line)
    trace = trace:gsub("(stack traceback:\n).*\n", "%1")
    reaper.ShowConsoleMsg(trace .. ln .. "\n" )
    reaper.MB(tostring(msg) .. "\n\nContinue?", line, 0 )
end

function Open_url(url)
    local OS = reaper.GetOS()
    if (OS == "OSX32" or OS == "OSX64") or OS == 'macOS-arm64' then
        os.execute('open "' .. url .. '"')
    elseif OS == "Win64" or OS == "Win32" then
        os.execute('start "" "' .. url .. '"')
    else
        os.execute('xdg-open "' .. url .. '"') -- LINUX
    end
end

function Check_Requirements()
    local reaper_version = reaper.GetAppVersion()
    local big, small = reaper_version:match("(6).(%d%d)")
    -- TEMPORARY NEEDS DEV RELEASE UNTIL FIXED LANES ARA IN STABLE
    if not reaper_version:match("+dev") then
        reaper.MB( "Reaper DEV Prerelease version v6.50+dev is required for this script. Please download latest DEV prerelease from www.landoleet.org", "SCRIPT REQUIREMENTS", 0 )
        Open_url("www.landoleet.org")
        return reaper.defer(function() end)
    else
        if tonumber(small) < 53 then
            reaper.MB( "Reaper DEV Prerelease version v6.50+dev is required for this script. Please download latest DEV prerelease from www.landoleet.org", "SCRIPT REQUIREMENTS", 0 )
            Open_url("https://www.landoleet.org")
            return reaper.defer(function() end)
        end
    end
    if not reaper.APIExists("JS_ReaScriptAPI_Version") then
        reaper.MB( "JS_ReaScriptAPI is required for this script. Please download it from ReaPack", "SCRIPT REQUIREMENTS", 0 )
        reaper.ReaPack_BrowsePackages('JS_ReaScriptAPI:')
        return reaper.defer(function() end)
    else
        local version = reaper.JS_ReaScriptAPI_Version()
        if version < 1.301 then
            reaper.MB( "Your JS_ReaScriptAPI version is " .. version .. "\nPlease update to latest version.", "Older version is installed", 0 )
            reaper.ReaPack_BrowsePackages('JS_ReaScriptAPI:')
            return reaper.defer(function() end)
        end
    end
    if not reaper.ImGui_GetVersion then
        reaper.MB( "ReaImGui is required for this script. Please download it from ReaPack", "SCRIPT REQUIREMENTS", 0 )
        reaper.ReaPack_BrowsePackages( 'ReaImGui:')
        return reaper.defer(function() end)
    end
end

local crash = function(errObject)
    reaper.JS_VKeys_Intercept(-1, -1)
    local byLine = "([^\r\n]*)\r?\n?"
    local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
    local err = errObject and string.match(errObject, trimPath) or "Couldn't get error message."
    local trace = debug.traceback()
    local stack = {}
    for line in string.gmatch(trace, byLine) do
        local str = string.match(line, trimPath) or line
        stack[#stack + 1] = str
    end
    local name = ({reaper.get_action_context()})[2]:match("([^/\\_]+)$")
    local ret =
        reaper.ShowMessageBox(
        name .. " has crashed!\n\n" .. "Would you like to have a crash report printed " .. "to the Reaper console?",
        "Oops",
        4
    )
    if ret == 6 then
        reaper.ShowConsoleMsg(
            "Error: " .. err .. "\n\n" ..
            "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 2) .. "\n\n" ..
            "Reaper:       \t" .. reaper.GetAppVersion() .. "\n" ..
            "Platform:     \t" .. reaper.GetOS()
        )
    end
end

function GetCrash() return crash end

function MSG(m) reaper.ShowConsoleMsg(tostring(m) .. "\n") end

function string.starts(String,Start) return string.sub(String,1,string.len(Start))==Start end

function trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

function round(num) return math.floor(num + 0.5) end

function tableToString(table)
    return serializeTable(table)
end

function stringToTable(str)
    local f, err = load("return "..str)
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
            name = "['".. name .. "']"
        end
        tmp = tmp .. name .. " = "
    end
    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
        for k, v in pairs(val) do
            tmp =  tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
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

function Literalize(str)
    return str:gsub(
        "[%(%)%.%%%+%-%*%?%[%]%^%$]",
        function(c)
            return "%" .. c
        end
    )
end

function Split_by_line(str)
    local t = {}
    for line in string.gmatch(str, "[^\r\n]+") do
        t[#t + 1] = line
    end
    return t
end

function ChunkTableGetSection(chunk, key) -- ADDOPTED FROM BirdBird and daniellumertz! 🦜
    local chunk_lines = Split_by_line(chunk)
    local section_chunks = {}
    local last_section_chunk = -1
    local current_scope = 0
    local i = 1
    while i <= #chunk_lines do
        local line = chunk_lines[i]

        local scope_end = false
        if line == '<'..key then
            last_section_chunk = i
            current_scope = current_scope + 1
        elseif string.starts(line, '<') then
            current_scope = current_scope + 1
        elseif string.starts(line, '>') then
            current_scope = current_scope - 1
            scope_end = true
        end

        if current_scope == 1 and last_section_chunk ~= -1 and scope_end then
            local s = ''
            for j = last_section_chunk, i do
                s = s .. chunk_lines[j] .. '\n'
            end
            last_section_chunk = -1
            table.insert(section_chunks, s)
        end
        i = i + 1
    end

    return next(section_chunks) and table.concat(section_chunks, "\n")
end

function GetChunkSection(chunk, key) -- ADDOPTED FROM LBX
    local chs, che
    chs, _ = string.find(chunk,'<' .. key)
    local level = 0
    local cpos = chs
    repeat
        local s, e = string.find(chunk,'[%<%>]', cpos)
        if s then
            local char = string.sub(chunk,s - 1, s)
            if char == '\n<' then level = level + 1
            elseif char == '\n>' then level = level - 1
            end
        end
        cpos = s + 1
        if level == 0 then che = s break end
    until level == 0

    if chs == nil or che == nil then return end
    local fchunk = string.sub(chunk,chs,che)
    return fchunk
end

function DBG_TBL(A)
    for index, value in pairs(A) do
        reaper.ShowConsoleMsg("K: "..tostring(index).." - V: "..tostring(type(value) == "table" and #value or value).."\n")
    end
end

function GenPalette(val)
    local a = {r = 0.5, g = 0.5,  b = 0.5}
    local b = {r = 0.5, g = 0.5,  b = 0.5}
    local c = {r = 1,   g = 1,    b = 1}
    local d = {r = 0,   g = 0.33, b = 0.67}

    local brightness = 0.0

    local col = {}
    col.r = math.floor(math.min(a.r + brightness + math.cos((c.r * val + d.r) * 6.28318) * b.r, 1) * 255 + 0.5)
    col.g = math.floor(math.min(a.g + brightness + math.cos((c.g * val + d.g) * 6.28318) * b.g, 1) * 255 + 0.5)
    col.b = math.floor(math.min(a.b + brightness + math.cos((c.b * val + d.b) * 6.28318) * b.b, 1) * 255 + 0.5)
    return col.r, col.g, col.b
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
