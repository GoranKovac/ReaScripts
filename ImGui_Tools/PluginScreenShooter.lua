-- Credits nihilboy for idea

local r = reaper
package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
local im = require 'imgui' '0.9.2'

local platform = r.GetOS()

local deps = {}
local proc_delay = 0.5
local SIZE_DATA = {}
local osx, linux, win
local linux_app
if platform:match("OSX") or platform:match("macOS") then
    osx = true
elseif platform:match("Other") then
    linux = true
    --AAA = reaper.ExecProcess('/bin/bash -c "which gnome-screenshot"',0)
else
    win = true
end

if not im.GetVersion then
    deps[#deps + 1] = '"Dear Imgui"'
end
if not r.JS_ReaScriptAPI_Version then
    deps[#deps + 1] = '"js_ReaScriptAPI"'
end

if #deps ~= 0 then
    r.ShowMessageBox("Need Additional Packages.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
    r.ReaPack_BrowsePackages(table.concat(deps, " OR "))
    return true
end

local function PrintTraceback(err)
    local byLine = "([^\r\n]*)\r?\n?"
    local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
    local stack = {}
    for line in string.gmatch(err, byLine) do
        local str = string.match(line, trimPath) or line
        stack[#stack + 1] = str
    end
    r.ShowConsoleMsg(
        "Error: " .. stack[1] .. "\n\n" ..
        "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 3) .. "\n\n" ..
        "Reaper:       \t" .. r.GetAppVersion() .. "\n" ..
        "Platform:     \t" .. r.GetOS()
    )
end

function PDefer(func)
    r.defer(function()
        local status, err = xpcall(func, debug.traceback)
        if not status then
            PrintTraceback(err)
            Exit()
        end
    end)
end

local ctx = im.CreateContext('FX SCREENSHOTER')

local png_folder = "/Scripts/FX_PNG/"
local folder = r.GetResourcePath() .. png_folder

if not r.file_exists(folder) then
    reaper.RecursiveCreateDirectory(folder,0)
end

r.InsertTrackAtIndex(r.CountTracks(0), false)

local track = r.GetTrack(r.CountTracks(0), 0)
local fx_idx = 0

local total_fx = 0
for j = 1, math.huge do
    local retval = r.EnumInstalledFX(j)
    if not retval then break end
    total_fx = total_fx + 1
end

local function SerializeTable(val, name, skipnewlines, depth)
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

function TableToString(table) return SerializeTable(table) end

function WriteToFile(path, data)
    local file_cat = io.open(path, "w")
    if file_cat then
        file_cat:write(data)
        file_cat:close()
    end
end

local function WriteFxData()
    local serialized = TableToString(SIZE_DATA)
    WriteToFile(folder .. "FX_SIZES.txt", serialized)
end

function Wait(startTime, callback)
    PROCESS = true
    if r.time_precise() - startTime > proc_delay then
        callback()
        fx_idx = fx_idx + 1
        PROCESS = nil
    else
        r.defer(function() Wait(startTime, callback) end)
    end
end

local function FxOffset()
    return pluginName:match("^JS") and 0 or 27
end

local function ScreenshotOSX(path, x, y, w, h)
    x, y = im.PointConvertNative(ctx, x, y, false)
    local command = 'screencapture -x -R %d,%d,%d,%d -t png "%s"'
    os.execute(command:format(x, y, w, h, path .. ".png"))
end

local function ScreenshotLinux(path, x, y, w, h)
    x, y = im.PointConvertNative(ctx, x, y, false)
    local command = 'shutter -s %d,%d,%d,%d -e -o "%s"'
    os.execute(command:format(x, y, w, h, path .. ".png"))
end

local function takeScreenshot(fxIndex, path)
    local window = r.TrackFX_GetFloatingWindow(track, fxIndex)
    local retval, left, top, right, bottom = r.JS_Window_GetClientRect( window )
    if retval then
        local destBmp
        local w, h = right - left, bottom - top
        local off_y = FxOffset()
        if win or linux then
            local srcDC = r.JS_GDI_GetClientDC(window)
            destBmp = r.JS_LICE_CreateBitmap(true, w, h - off_y)
            local destDC = r.JS_LICE_GetDC(destBmp)
            r.JS_GDI_Blit(destDC, 0, -off_y, srcDC, 0, 0, w, h)
            r.JS_LICE_WritePNG(path .. ".png", destBmp, false)
            r.JS_GDI_ReleaseDC(window, srcDC)
            r.JS_LICE_DestroyBitmap(destBmp)
        elseif osx then
            h = top - bottom
            ScreenshotOSX(path, left, top - off_y, w, h - off_y)
        else
           -- ScreenshotLinux(path, left, top - off_y, w, h - off_y)
        end
        if r.ValidatePtr(track, "MediaTrack*") then
            r.TrackFX_Delete(track, fxIndex)
        end
        SIZE_DATA[pluginName] = { path = path .. ".png", w = w, h = h }
    end
end

local function BuildDatabase()
    SIZE_DATA = {}
    for j = 1, math.huge do
        local retval, pluginName = r.EnumInstalledFX(j)
        if not retval then break end
        local png_name = pluginName:gsub("[-:_/%s><]", "_")
        local path = folder .. png_name .. ".png"
        if r.file_exists(path) then
            local img = im.CreateImage(path)
            local w, h = im.Image_GetSize(img)
            SIZE_DATA[pluginName] = { path = png_folder .. png_name .. ".png", w = w, h = h }
        end
    end
    WriteFxData()
end

local function Process()
    if DONE then return end
    retval, pluginName = r.EnumInstalledFX(fx_idx)
    if not retval then
        START = false
        DONE = true
        BuildDatabase()
        return
    end
    if pluginName then
        local png_name = pluginName:gsub("[-:_/%s><]", "_")
        local path = folder .. png_name
        if not r.file_exists(path .. ".png") then
            if not PROCESS then
                local fxIndex = r.TrackFX_AddByName(track, pluginName, false, 1)
                r.TrackFX_Show(track, fxIndex, 3)
                Wait(
                    r.time_precise(),
                    function()
                        takeScreenshot(fxIndex, path)
                    end
                )
            end
        else
            fx_idx = fx_idx + 1
        end
    else
        fx_idx = fx_idx + 1
    end 
end

local function Main()
    local visible, open = im.Begin(ctx, 'FX SCREENSHOTER', true)
    if visible then
        if START then Process() end
        if im.Button(ctx, START and "STOP" or "START") then
            if not START then
              BuildDatabase()
            end
            START = not START
            if DONE then DONE = nil end
        end
        if fx_idx > 0 then
          im.SameLine(ctx)
          im.Text(ctx, fx_idx .. " of " .. total_fx)
          im.ProgressBar(ctx,fx_idx/total_fx)
          if START then
            im.Text(ctx, DONE and "FINISHED" or (START and "PROCESSING : " .. (pluginName or "") or ""))
          end
        end
        im.End(ctx)
    end

    if open then
        PDefer(Main)
    end
end

function Exit()
    if track and r.ValidatePtr(track, "MediaTrack*") then
        r.DeleteTrack(track)
    end
end

r.atexit(Exit)
PDefer(Main)
