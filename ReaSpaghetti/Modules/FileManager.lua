--@noindex
--NoIndex: true

local r = reaper

local path, filelist
local os_separator = package.config:sub(1, 1)
local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

local exstensions = {
    "%.reanodes",
    -- "%.txt",
    --  ""
}

local exstensions_preview = {
    ".reanodes",
    -- ".txt",
    --  ".*"
}

local exstension = exstensions[1]

local function GetDirEntries(path, enumerator, filter)
    local entries = {}
    enumerator(path, -1)
    for index = 0, math.huge do
        local path = enumerator(path, index)
        if not path then break end
        if path:sub(1, 1) ~= '.' then
            if filter then
                if path:match(filter) then
                    entries[#entries + 1] = path
                end
            else
                entries[#entries + 1] = path
            end
        end
    end
    table.sort(entries, function(a, b) return a:lower() < b:lower() end)
    return entries
end

local function GetFileList()
    return {
        dirs    = GetDirEntries(path, r.EnumerateSubdirectories),
        files   = GetDirEntries(path, r.EnumerateFiles, exstension),
        current = nil
    }
end

local function RemoveLastPathComponent()
    local last = #path - path:reverse():find(os_separator)
    path = last > 0 and path:sub(1, last) or os_separator
end

local function DrawEntries(entries, is_dir)
    for i, entry in ipairs(entries) do
        if r.ImGui_Selectable(ctx, entry, filelist.current == entry, r.ImGui_SelectableFlags_AllowDoubleClick()) then
            filelist.current = entry
            filelist.current_is_dir = is_dir
            --filelist.current_text_input = not is_dir and entry or filelist.current_text_input
            filelist.current_text_input = entry
            if r.ImGui_IsMouseDoubleClicked(ctx, 0) then
                if is_dir then
                    if path:sub(#path, 1) ~= os_separator then
                        path = path .. os_separator
                    end
                    path = path .. entry
                    filelist = GetFileList()
                else
                    if FM_TYPE == "OPEN" then
                        LoadFile()
                        r.ImGui_CloseCurrentPopup(ctx)

                    elseif FM_TYPE == "SAVE" then
                        --local load_path = path .. os_separator .. filelist.current
                        --SaveToFIle(load_path)
                        WANT_OVERRIDE = true
                        --r.ImGui_OpenPopup(ctx, 'Overwrite')
                    end
                    --r.ImGui_CloseCurrentPopup(ctx)
                end
            end
        end
    end
end

local function Split_by_line(str)
    local t, i = {}, 1
    while true do
        local ni = str:find(os_separator, i)
        t[#t + 1] = str:sub(i, ni and ni - 1 or nil)
        if not ni or ni == str:len() then break end
        i = ni + 1
    end
    return t
end

local function autoWrap(n, sz, func)
    local item_spacing_x =
        r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
    local window_visible_x2 =
        r.ImGui_GetWindowPos(ctx) + r.ImGui_GetWindowContentRegionMax(ctx)
    for i = 0, n do
        func(i)
        local x2 = r.ImGui_GetItemRectMax(ctx)
        if i < n and x2 + item_spacing_x + sz < window_visible_x2 then
            r.ImGui_SameLine(ctx)
        end
    end
end
local pad_x = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())
local inner_pad = (pad_x * 2)
local function PathButtons()
    local path_buttons = Split_by_line(path)
    local item_spacing_x = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())
    local window_x2 = r.ImGui_GetWindowPos(ctx) + r.ImGui_GetWindowContentRegionMax(ctx)
    for i = 1, #path_buttons do
        -- local w, h = r.ImGui_CalcTextSize(ctx, path_buttons[i] .. os_separator)
        if r.ImGui_Button(ctx, path_buttons[i] .. os_separator) and i ~= #path_buttons then
            path = ''
            for j = 1, i do
                if j > 1 then path = path .. os_separator end
                path = path .. path_buttons[j]
            end
            if path:len() == 0 then path = os_separator end -- Unix root
            filelist = GetFileList()
        end
        local button_x2 = r.ImGui_GetItemRectMax(ctx)
        if i < #path_buttons then
            local next_w = r.ImGui_CalcTextSize(ctx, path_buttons[i + 1])
            local next_x2 = button_x2 + item_spacing_x + next_w + inner_pad
            if next_x2 < window_x2 then
                r.ImGui_SameLine(ctx)
            end
        end
    end
    return #path_buttons
end

local function PathButtons2()
    local path_buttons = Split_by_line(path)
    for i = 1, #path_buttons do
        if i > 1 then r.ImGui_SameLine(ctx) end
        if r.ImGui_Button(ctx, path_buttons[i] .. os_separator) and i ~= #path_buttons then
            path = ''
            for j = 1, i do
                if j > 1 then path = path .. os_separator end
                path = path .. path_buttons[j]
            end
            if path:len() == 0 then path = os_separator end -- Unix root
            filelist = GetFileList()
        end
    end
    return #path_buttons
end

function Init_FM_database()
    path = debug.getinfo(1, "S").source:sub(2)
    filelist = {}
    filelist.current_text_input = ""

    RemoveLastPathComponent()
    filelist = GetFileList()
end

function File_dialog()
    local path_buttons = PathButtons()
    if r.ImGui_BeginListBox(ctx, "##frame", -FLT_MIN, -23) then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0x55D8FFFF)
        local dirs, files = filelist.dirs, filelist.files
        if path_buttons > 1 then
            if r.ImGui_Selectable(ctx, '..', filelist.current == entry, r.ImGui_SelectableFlags_AllowDoubleClick()) then
                if r.ImGui_IsMouseDoubleClicked(ctx, 0) then
                    RemoveLastPathComponent()
                    filelist = GetFileList()
                end
            end
        end
        DrawEntries(dirs, true)
        r.ImGui_PopStyleColor(ctx)

        DrawEntries(files, false)

        r.ImGui_EndListBox(ctx)
    end

    if FM_TYPE == "OPEN" then r.ImGui_BeginDisabled(ctx, true) end
    r.ImGui_SetNextItemWidth(ctx, -173)
    _, filelist.current_text_input = r.ImGui_InputText(ctx, "##text", filelist.current_text_input)
    r.ImGui_SameLine(ctx)
    if FM_TYPE == "OPEN" then r.ImGui_EndDisabled(ctx) end

    r.ImGui_SetNextItemWidth(ctx, 70)
    rc, current_item = r.ImGui_Combo(ctx, "##exstension", current_item, table.concat(exstensions_preview, "\0") .. "\0")
    if rc then
        exstension = exstensions[current_item + 1]
        --    filelist = GetFileList()
    end

    if FM_TYPE == "OPEN" then
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, "open") then
            if filelist.current_is_dir then
                if path:sub(#path, 1) ~= os_separator then
                    path = path .. os_separator
                end
                path = path .. filelist.current
                filelist = GetFileList()
            else
                LoadFile()
            end
            r.ImGui_CloseCurrentPopup(ctx)
        end
    end

    if FM_TYPE == "SAVE" then
        r.ImGui_SameLine(ctx)
        if not filelist.current_text_input or Ltrim(filelist.current_text_input) == "" then
            r.ImGui_BeginDisabled(ctx, true) --or not filelist.current_text_input:match(exstension) then
            -- r.ImGui_BeginDisabled(ctx, true)
        end
        if r.ImGui_Button(ctx, "save") then
            local save_extension = filelist.current_text_input:match(exstension) and filelist.current_text_input or
                filelist.current_text_input .. exstensions_preview[1]
            local save_path = path .. os_separator .. save_extension
            local file = io.open(save_path, "r")
            if file ~= nil then
                io.close(file)
                r.ImGui_OpenPopup(ctx, 'Overwrite')
            else
                --r.ShowConsoleMsg("Saving to :" .. save_path)
                SaveToFIle(save_path)
                FM_TYPE = nil
                --OPEN_FM = nil
                if NEED_SAVE then ClearProject() end
                if WANT_CLOSE then CLOSE = true end
                r.ImGui_CloseCurrentPopup(ctx)
            end
        end
        if not filelist.current_text_input or Ltrim(filelist.current_text_input) == "" then --or not filelist.current_text_input:match(exstension) then
            r.ImGui_EndDisabled(ctx)
        end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "close") then
        FM_TYPE = nil
        --OPEN_FM = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
    if WANT_CLOSE_FM then
        WANT_CLOSE_FM = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

function LoadFile()
    if filelist.current == nil then return end
    local load_path = path .. os_separator .. filelist.current
    local file = io.open(load_path, "r")
    if file then
        PROJECT_NAME = filelist.current
        PROJECT_PATH = path .. os_separator
        local string = file:read("*all")
        RestoreNodes(string)
        --r.ShowConsoleMsg(string)
        file:close()
        FM_TYPE = nil
        OPEN_FM = nil
    end
end

--! CHECK IF EXTENSION IS ALREADY PROVIDED, IF NOT THEN USE EXTENSTION
function SaveToFIle(save_path)
    --local save_path = path .. os_separator .. filelist.current_text_input
    local data = StoreNodes()
    local file = io.open(save_path, "w")
    if file then
        file:write(data)
        file:close()
        PROJECT_NAME = filelist.current_text_input
        PROJECT_PATH = path .. os_separator
        DIRTY = nil
    end
end

function FM_Modal_POPUP()
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)

    if WANT_OVERRIDE then
        WANT_OVERRIDE = nil
        r.ImGui_OpenPopup(ctx, 'Overwrite')
    end

    if r.ImGui_BeginPopupModal(ctx, 'Overwrite', nil, r.ImGui_WindowFlags_AlwaysAutoResize()) then
        r.ImGui_Text(ctx, filelist.current_text_input .. ' - already exists.\nOverwrite file ?\n\n')
        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'OK', 120, 0) then
            local save_extension = filelist.current_text_input:match(exstension) and filelist.current_text_input or
                filelist.current_text_input .. exstensions_preview[1]
            local save_path = path .. os_separator .. save_extension
            SaveToFIle(save_path)
            r.ImGui_CloseCurrentPopup(ctx)
            FM_TYPE = nil
            WANT_CLOSE_FM = true
            if WANT_CLOSE then CLOSE = true end
            --OPEN_FM = nil
        end
        r.ImGui_SetItemDefaultFocus(ctx)
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'Cancel', 120, 0) then 
            if WANT_CLOSE then WANT_CLOSE = nil end
            r.ImGui_CloseCurrentPopup(ctx) end
        r.ImGui_EndPopup(ctx)
    end
end
