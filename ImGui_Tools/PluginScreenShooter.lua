-- Credits nihilboy for idea

local r = reaper
local running_os = r.GetOS()
local deps = {}
local proc_delay = 0.5
local SIZE_DATA = {}
if not r.ImGui_GetVersion then
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

local ctx = r.ImGui_CreateContext('FX SCREENSHOTER')
local png_folder = "/Scripts/FX_PNG/"
local folder = r.GetResourcePath() .. png_folder
if not r.file_exists(folder) then
    os.execute("mkdir " .. folder)
end

r.InsertTrackAtIndex(r.CountTracks(0), false)
local track = r.GetTrack(r.CountTracks(0), 0)
local i = 0

function SerializeToFile(val, name, skipnewlines, depth)
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
            tmp = tmp .. SerializeToFile(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end
        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        --! THIS IS MODIFICATION FOR THIS SCRIPT
        --! POINTERS GET RECALCULATED ON RUN SO WE NIL HERE (MEDIATRACKS, MEDIAITEMS... )
        tmp = tmp .. "nil"
        --tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end
    return tmp
end

function StringToTable(str)
    local f, err = load("return " .. str)
    if err then
        reaper.ShowConsoleMsg("\nerror" .. err)
    end
    return f ~= nil and f() or nil
end

function TableToString(table) return SerializeToFile(table) end

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
        i = i + 1
        PROCESS = nil
    else
        r.defer(function() Wait(startTime, callback) end)
    end
end

local function FxOffset()
    return pluginName:match("^JS") and 0 or 27
end

local function IsOSX()
    if running_os:match("OSX") or running_os:match("macOS") then
        return true
    end
end

local function ScreenshotOSX(path, x, y, w, h)
    x, y = r.ImGui_PointConvertNative(ctx, x, y, false)
    local filename = os.tmpname() -- a shell-safe value
    local command = 'screencapture -x -R %d,%d,%d,%d -t png "%s"'
    os.execute(command:format(x, y, w, h, path .. ".png"))
    --local png = r.JS_LICE_LoadPNG(filename)
    --os.remove(filename)
    --return png
end

local function takeScreenshot(fxIndex, path)
    local window = r.TrackFX_GetFloatingWindow(track, fxIndex)
    --local retval, w, h = r.JS_Window_GetClientSize(window)
    --local retval, left, top, right, bottom = r.JS_Window_GetRect(window)
    local retval, left, top, right, bottom = r.JS_Window_GetClientRect( window )
    if retval then
        local destBmp
        local w, h = right - left, bottom - top
        local off_y = FxOffset()
        if not IsOSX() then
            local srcDC = r.JS_GDI_GetClientDC(window)
            destBmp = r.JS_LICE_CreateBitmap(true, w, h - off_y)
            local destDC = r.JS_LICE_GetDC(destBmp)
            r.JS_GDI_Blit(destDC, 0, -off_y, srcDC, 0, 0, w, h)
            r.JS_LICE_WritePNG(path .. ".png", destBmp, false)
            r.JS_GDI_ReleaseDC(window, srcDC)
            r.JS_LICE_DestroyBitmap(destBmp)
        else
            h = top - bottom
            destBmp = ScreenshotOSX(path, right, top, left, h - off_y)
        end
        if r.ValidatePtr(track, "MediaTrack*") then
            r.TrackFX_Delete(track, fxIndex)
        end
        SIZE_DATA[pluginName] = { path = path .. ".png", w = w, h = h }
    end
end

function Main()
    if DONE then return end
    retval, pluginName = r.EnumInstalledFX(i)
    if not retval then
        START = false
        DONE = true
        --WriteFxData()
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
            i = i + 1
        end
    else
        i = i + 1
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
            local img = r.ImGui_CreateImage(path)
            local w, h = r.ImGui_Image_GetSize(img)
            SIZE_DATA[pluginName] = { path = png_folder .. png_name .. ".png", w = w, h = h }
        end
    end
    WriteFxData()
end

local function gui()
    local visible, open = r.ImGui_Begin(ctx, 'FX SCREENSHOTER', true)
    if visible then
        if r.ImGui_Button(ctx, START and "STOP" or "START") then
            START = not START
            if DONE then DONE = nil end
        end
        r.ImGui_SameLine(ctx)

        if START then Main() end
        r.ImGui_Text(ctx, DONE and "FINISHED" or (START and "PROCESSING : ID " .. i .. " - " .. (pluginName or "") or ""))
        if not START then
            if r.ImGui_Button(ctx, "BUILD PNG DATABASE") then
                BuildDatabase()
            end
        end
        r.ImGui_End(ctx)
    end

    if open then
        r.defer(gui)
    end
end

function Exit()
    if track and r.ValidatePtr(track, "MediaTrack*") then
        r.DeleteTrack(track)
    end
end

r.atexit(Exit)
gui()
