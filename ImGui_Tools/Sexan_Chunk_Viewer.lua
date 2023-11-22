-- @description Sexan ChunkViewer Imgui
-- @author Sexan
-- @license GPL v3
-- @version 1.01
-- @changelog
--  cleanup
local r = reaper
local ctx = r.ImGui_CreateContext('ChunkyBoy')
local contents = ''

local function AddIdent(str)
  local t = {}
  local number_of_spaces = 2
  local indent = 0
  local add = false
  for line in str:gmatch("[^\n]+") do
    if add then
      indent = indent + 1
      add = false
    end
    if line:find("^<") then
      add = true
    elseif line == ">" then
      indent = indent - 1
    end
    t[#t + 1] = (string.rep(string.rep(" ", number_of_spaces), indent) or "") .. line
  end
  return table.concat(t, "\n")
end

local function Main()
  local visible, open = reaper.ImGui_Begin(ctx, 'CHUNKY BOY', true, flags)
  if visible then
    if r.ImGui_Button(ctx, 'GET TRACK') then
      local track = r.GetSelectedTrack2(0, 0, true)
      if track then
        LAST = "TRACK"
        LAST_PTR = track
        local retval, chunk = r.GetTrackStateChunk(track, "", false)
        contents = AddIdent(chunk)
      end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'GET ENVELOPE') then
      local env = r.GetSelectedEnvelope(0)
      if env then
        LAST = "ENV"
        LAST_PTR = env
        local retval, chunk = r.GetEnvelopeStateChunk(env, "", false)
        contents = AddIdent(chunk)
      end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'GET ITEM') then
      local item = r.GetSelectedMediaItem(0, 0)
      if item then
        LAST = "ITEM"
        LAST_PTR = item
        local retval, chunk = r.GetItemStateChunk(item, "", false)
        contents = AddIdent(chunk)
      end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'SET') then
      if LAST then
        if LAST == "TRACK" then
          r.SetTrackStateChunk(LAST_PTR, contents, false)
        elseif LAST == "ENV" then
          r.SetEnvelopeStateChunk(LAST_PTR, contents, false)
        elseif LAST == "ITEM" then
          r.SetItemStateChunk(LAST_PTR, contents, false)
        end
      end
    end
    RV, contents = r.ImGui_InputTextMultiline(ctx, '##source', contents, -1, -1)
    r.ImGui_End(ctx)
  end
  if open then r.defer(Main) end
end
reaper.defer(Main)
