-- Credits nihilboy for idea

local r = reaper
local deps = {}

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
local folder = r.GetResourcePath() ..  "\\Scripts\\FX_PNG\\"

if not r.file_exists( folder ) then
  os.execute("mkdir " .. folder)
end

local tr_idx = r.InsertTrackAtIndex( r.CountTracks(0), false )
local track = r.GetTrack(tr_idx, 0)
local i = 0
local proc_delay = 0.5

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

local function takeScreenshot()
    local window = r.TrackFX_GetFloatingWindow(track, fxIndex )
    local retval, w, h = r.JS_Window_GetClientSize( window )
    if retval then
        local srcDC = r.JS_GDI_GetWindowDC(window)
        local destBmp = r.JS_LICE_CreateBitmap(true, w, h)
        local destDC = r.JS_LICE_GetDC(destBmp)
        r.JS_GDI_Blit(destDC, 0, 0, srcDC, 8, 31, w, h)
        r.JS_LICE_WritePNG(path, destBmp, false)
        r.JS_GDI_ReleaseDC(window, srcDC)
        r.JS_LICE_DestroyBitmap(destBmp)
        r.TrackFX_Delete(track, fxIndex) 
    end
end

function main()
    --r.ShowConsoleMsg(i.."\n")
    retval, pluginName, ident = r.EnumInstalledFX(i)
    if not retval then
        START = false
        DONE = true
    end
    if pluginName then
      -- REPLACE SYMBOLS WITH _ FOR FILE WRITING
      local pluginName_strip = pluginName:gsub("[-:_/%s><]", "_")
      path = folder .. pluginName_strip  .. '.png'
      -- IF FILE EXIST SKIP IT
      if not r.file_exists( path ) then
        if not PROCESS then
        fxIndex = r.TrackFX_AddByName(track, pluginName, false, 1)
        r.TrackFX_Show(track, fxIndex, 3)
          Wait(
            r.time_precise(), 
            function()
              takeScreenshot()
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

local function gui()
    local visible, open = r.ImGui_Begin(ctx, 'FX SCREENSHOTER', true)
    if visible then
        if r.ImGui_Button( ctx, START and "STOP" or "START" ) then
          if START then
            START = false
          else
            START = true
          end
        end
        r.ImGui_SameLine(ctx)
       
        if START then main() end
        r.ImGui_Text(ctx, DONE and "FINISHED" or ("PROCESSING : ID " .. i .. " - " .. (pluginName or "")))
        r.ImGui_End(ctx)
    end

    if open then
        r.defer(gui)
    end
end

function Exit()
  if track then r.DeleteTrack( track )  end
end

r.atexit(Exit)
gui()