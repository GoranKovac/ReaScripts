--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.03
	 * NoIndex: true
--]]

local reaper = reaper
local script_path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]:gsub("[\\|/]Modules", "") -- GET DIRECTORY FOR REQUIRE
function Break( msg )
    local line = "Breakpoint at line " .. debug.getinfo(2).currentline
    local ln = "\n" .. string.rep("=", #line) .. "\n"
    local trace = debug.traceback(ln .. line)
    trace = trace:gsub("(stack traceback:\n).*\n", "%1")
    reaper.ShowConsoleMsg(trace .. ln .. "\n" )
    reaper.MB(tostring(msg) .. "\n\nContinue?", line, 0 )
end

local function open_url(url)
    local OS = reaper.GetOS()
    if (OS == "OSX32" or OS == "OSX64") or OS == 'macOS-arm64' then
        os.execute('open "" "' .. url .. '"')
    else
        os.execute('start "" "' .. url .. '"')
    end
end

local options_script_id = reaper.AddRemoveReaScript(true, 0, script_path .. "Virtual_track_Options.lua", true)
local options_script = reaper.NamedCommandLookup(options_script_id)

function Check_Requirements()
    local reaper_version = reaper.GetAppVersion()
    local big, small = reaper_version:match("(6).(%d%d)")
    if not reaper_version:match("+dev") then
        reaper.MB( "Reaper DEV Prerelease version v6.50+dev is required for this script. Please download latest DEV prerelease from www.landoleet.org", "SCRIPT REQUIREMENTS", 0 )
        open_url("www.landoleet.org")
        return reaper.defer(function() end)
    else
        if tonumber(small) < 50 then
            reaper.MB( "Reaper DEV Prerelease version v6.50+dev is required for this script. Please download latest DEV prerelease from www.landoleet.org", "SCRIPT REQUIREMENTS", 0 )
            open_url("www.landoleet.org")
            return reaper.defer(function() end)
        end
    end
    if not reaper.APIExists("JS_ReaScriptAPI_Version") then
        reaper.MB( "JS_ReaScriptAPI is required for this script. Please download it from ReaPack", "SCRIPT REQUIREMENTS", 0 )
        return reaper.defer(function() end)
    else
        local version = reaper.JS_ReaScriptAPI_Version()
        if version < 1.3 then
            reaper.MB( "Your JS_ReaScriptAPI version is " .. version .. "\nPlease update to latest version.", "Older version is installed", 0 )
            return reaper.defer(function() end)
        end
    end
    if not reaper.ImGui_GetVersion then
        reaper.MB( "ReaImGui is required for this script. Please download it from ReaPack", "SCRIPT REQUIREMENTS", 0 )
        return reaper.defer(function() end)
    end
    if not reaper.HasExtState( "VirtualTrack", "options" ) then
        reaper.MB( "No global options stored please set them now. You can change settings later by opening Virual_track_Options script", "VIRTUAL TRACK OPTIONS", 0 )
        reaper.Main_OnCommand(options_script,0)
        return reaper.defer(function() end)
    end
end

local crash = function(errObject)
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

function round(num)
    return math.floor(num + 0.5)
end

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

function MSG(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function literalize(str)
    return str:gsub(
        "[%(%)%.%%%+%-%*%?%[%]%^%$]",
        function(c)
            return "%" .. c
        end
    )
end

function split_by_line(str)
    local t = {}
    for line in string.gmatch(str, "[^\r\n]+") do
        t[#t + 1] = line
    end
    return t
end

function DBG_TBL(A)
    for index, value in pairs(A) do
        reaper.ShowConsoleMsg("K: "..tostring(index).." - V: "..tostring(type(value) == "table" and #value or value).."\n")
    end
end

function SaveFile(tbl, fn)
    local config_path = fn .. "config.txt"
    local file
    file = io.open(config_path, "w")
    for i = 1, #tbl do
        file:write(tostring(tbl[i]) , "\n")
    end
    file:close()
end

function ReadFile(fn)
    local file = fn .. "config.txt"
    local f = io.open(script_path .. "config.txt", "r")
    if not f then
        return
    else
        f:close()
    end
    local options = {}
    for line in io.lines(file) do
        line = line:match("%S+ (%S+)") == "true" and true or false
        table.insert(options, line)
    end
    return options
end

function GetSelItemChunk()
    local retval, chunk = reaper.GetItemStateChunk( reaper.GetSelectedMediaItem( 0, 0 ), "", false )
    reaper.ClearConsole()
    reaper.ShowConsoleMsg(chunk)
end

function GetSelTrackChunk()
    local retval, chunk = reaper.GetTrackStateChunk( reaper.GetSelectedTrack(0, 0), "", false )
    reaper.ClearConsole()
    reaper.ShowConsoleMsg(chunk)
end

function GetSeltEnvelopeChunk()
    local retval, chunk = reaper.GetEnvelopeStateChunk(reaper.GetSelectedEnvelope(0,0),"", false)
    reaper.ClearConsole()
    reaper.ShowConsoleMsg(chunk)
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
