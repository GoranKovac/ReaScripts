-- @description Sexan ImGui FileManager
-- @author Sexan
-- @license GPL v3
-- @version 1.02
-- @changelog
--  Allow prenaming

local r = reaper
local os_separator = package.config:sub(1, 1)

FM_MAIN_PATH = r.GetResourcePath() .. os_separator .. "FXChains" .. os_separator

local path, filelist, entry, CAN_SAVE, CAN_LOAD

-- FOR SAVING
exstensions = {
    ".RfxChain",
}

-- FOR DROP DOWN MENU
exstensions_preview = {
    ".RfxChain",
    ".*",
}

exstension = exstensions[1]

local FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

local function Ltrim(s)
    if s == nil then return end
    return (s:gsub("^%s*", ""))
end

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
            current_text_input = is_dir and entry or
                entry:reverse():match("%.(.+)"):reverse() -- REMOVE EXTENSTION FROM SELECTED ENTRY IF NOT FOLDER
            if r.ImGui_IsMouseDoubleClicked(ctx, 0) then
                if is_dir then
                    if path:sub(#path, 1) ~= os_separator then
                        path = path .. os_separator
                    end
                    path = path .. entry
                    filelist = GetFileList()
                else
                    if FM_TYPE == "LOAD" then
                        LoadFile()
                        r.ImGui_CloseCurrentPopup(ctx)
                    elseif FM_TYPE == "SAVE" then
                        CAN_SAVE = true
                        DoSave()
                    end
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
    local fx,fy = r.ImGui_GetStyleVar(ctx,r.ImGui_StyleVar_FramePadding())
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(),0,0)
    r.ImGui_PushStyleVar(ctx,  r.ImGui_StyleVar_FramePadding(),0,fy)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),0)
    for i = 1, #path_buttons do
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
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_PopStyleColor(ctx)


    return #path_buttons
end

function Init_FM_database(name)
    path = FM_MAIN_PATH
    filelist = {}
    current_text_input = name or ""
    RemoveLastPathComponent()
    filelist = GetFileList()
end

function DoSave()
    if not CAN_SAVE then return end
    --local save_extension = current_text_input:match(exstension) and current_text_input or        current_text_input .. exstensions_preview[1]
    local save_file = current_text_input .. exstensions[1] -- APPEND EXTENSION TO FILE NAME
    local save_path = path .. os_separator .. save_file
    local file = io.open(save_path, "r")
    if file ~= nil then
        io.close(file)
        --r.ImGui_OpenPopup(ctx, 'Overwrite')
        OPEN_OVERWRITE = true
    else
        SaveToFIle(save_path)
        FM_TYPE = nil
        SAVED_DATA = nil
        OPEN_FM = nil
        WANT_REFRESH = true
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

local function DoLoad()
    if not CAN_LOAD then return end
    if filelist.current_is_dir then
        if path:sub(#path, 1) ~= os_separator then
            path = path .. os_separator
        end
        path = path .. filelist.current
        filelist = GetFileList()
    else
        LoadFile()
        r.ImGui_CloseCurrentPopup(ctx)
    end
end

function File_dialog()
    local path_buttons = PathButtons()
    r.ImGui_Separator(ctx)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0)
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
    if OPEN_OVERWRITE then
        r.ImGui_OpenPopup(ctx, 'Overwrite')
        OPEN_OVERWRITE = nil
    end
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_Separator(ctx)
    if FM_TYPE == "LOAD" then r.ImGui_BeginDisabled(ctx, true) end
    r.ImGui_SetNextItemWidth(ctx, -203)
    if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end
    _, current_text_input = r.ImGui_InputText(ctx, "##text", current_text_input)
    CAN_LOAD = #current_text_input ~= 0
    r.ImGui_SameLine(ctx)
    if FM_TYPE == "LOAD" then r.ImGui_EndDisabled(ctx) end

    r.ImGui_SetNextItemWidth(ctx, 100)
    rc, current_item = r.ImGui_Combo(ctx, "##exstension", current_item, table.concat(exstensions_preview, "\0") .. "\0")
    if rc then
        exstension = exstensions[current_item + 1]
        filelist = GetFileList()
    end

    if FM_TYPE == "LOAD" then
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, "open") then
            DoLoad()
        end
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter(), false) then
            DoLoad()
        end
    end

    if FM_TYPE == "SAVE" then
        r.ImGui_SameLine(ctx)
        CAN_SAVE = true
        if not current_text_input or Ltrim(current_text_input) == "" then
            r.ImGui_BeginDisabled(ctx, true)
            CAN_SAVE = false
        end
        if r.ImGui_Button(ctx, "SAVE") then
            DoSave()
        end
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter(), false) and not OVERWRITE_OPEN then
            DoSave()
        end
        if not current_text_input or Ltrim(current_text_input) == "" then
            r.ImGui_EndDisabled(ctx)
        end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "CLOSE") then
        FM_TYPE = nil
        OPEN_FM = nil
        r.ImGui_CloseCurrentPopup(ctx)
    end

    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) and not OVERWRITE_OPEN then WANT_CLOSE_FM = true end

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
        local string = file:read("*all")
        CustomLoad(string, load_path)
        file:close()
        FM_TYPE = nil
        OPEN_FM = nil
    end
end

function SaveToFIle(save_path)
    local data = SAVED_DATA
    local file = io.open(save_path, "w")
    if file then
        file:write(data)
        file:close()
        return true
    end
end

local function DoOverwrite()
    --local save_extension = current_text_input:match(exstension) and current_text_input or
    --    current_text_input .. exstensions_preview[1]
    local save_file = current_text_input .. exstensions[1] -- APPEND EXTENSION TO FILE NAME
    local save_path = path .. os_separator .. save_file
    SaveToFIle(save_path)
    r.ImGui_CloseCurrentPopup(ctx)
    FM_TYPE = nil
    WANT_REFRESH = true
    WANT_CLOSE_FM = true
    OPEN_FM = nil
    SAVED_DATA = nil
    r.ImGui_CloseCurrentPopup(ctx)
end

function FM_Modal_POPUP()
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'Overwrite', nil, r.ImGui_WindowFlags_AlwaysAutoResize()) then
        OVERWRITE_OPEN = true
        r.ImGui_Text(ctx, current_text_input .. ' - already exists.\nOverwrite file ?\n\n')
        r.ImGui_Separator(ctx)
        if r.ImGui_Button(ctx, 'OK', 120, 0) then
            DoOverwrite()
        end
        -- if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter(), false) then
        --     DoOverwrite()
        -- end
        r.ImGui_SetItemDefaultFocus(ctx)
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, 'CANCEL', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
            r.ImGui_CloseCurrentPopup(ctx)
            OVERWRITE_OPEN = nil
        end
        r.ImGui_EndPopup(ctx)
    end
end

-----------------------------------------------------------
-- IMPLEMENTAION EXAMPLE
-- NOT THIS CANT BE TESTED IN STANDALONE FROM THIS SCRIPT
-- COPY CODE BELLOW TO NEW SCRIPT
-- !! DO NOT UNCOMMENT THIS BELLOW OR IT WILL DO NASTY THINGS!! COPY IN SEPARATE SCRIPT
-----------------------------------------------------------

-- local r = reaper
-- local os_separator = package.config:sub(1, 1)
-- package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
-- -- CTX MUST BE GLOBAL
-- ctx = r.ImGui_CreateContext('TINY FILE MANAGER')
-- require("FileManager")

-- PATH YOU WANT TO BE DEFAULT
-- FM_MAIN_PATH = r.GetResourcePath() .. os_separator .. "FXChains" .. os_separator

-- -- FOR SAVING
-- exstensions = {
--     ".txt",
-- }

-- -- FOR DROP DOWN MENU
-- exstensions_preview = {
--     ".txt",
--     ".*",
-- }

-- exstension = exstensions[1]

-- -- DEFINE HERE WHAT YOUR LOAD WILL ACTUALLY DO WHEN FILE IS READ
-- function CustomLoad(str, path)
--     r.ShowConsoleMsg(path.."\n")
--     r.ShowConsoleMsg(str)
-- end

-- function Main()
--     local visible, open = r.ImGui_Begin(ctx, 'TINY FILE MANAGER', true)
--     if visible then
--         if r.ImGui_Button(ctx, "SAVE") then
--             SAVED_DATA = "THIS\nWILL\nBE\nWRITTEN\nIN\nTHE\nFILE"
--             OPEN_FM = true
--             FM_TYPE = "SAVE"
--             Init_FM_database()
--         end
--         if r.ImGui_Button(ctx, "LOAD") then
--             OPEN_FM = true
--             FM_TYPE = "LOAD"
--             Init_FM_database()
--         end
--         if OPEN_FM then
--             OPEN_FM = nil
--             if not r.ImGui_IsPopupOpen(ctx, "File Dialog") then
--                 r.ImGui_OpenPopup(ctx, 'File Dialog')
--             end
--         end
--         local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
--         r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
--             r.ImGui_SetNextWindowSizeConstraints(ctx, 400, 300, 400, 300)
--             if r.ImGui_BeginPopupModal(ctx, 'File Dialog', true, r.ImGui_WindowFlags_TopMost() |  r.ImGui_WindowFlags_NoResize()) then
--                 File_dialog()
--                 FM_Modal_POPUP()
--                 r.ImGui_EndPopup(ctx)
--             end
--         r.ImGui_End(ctx)
--     end
--     if open then
--         r.defer(Main)
--     end
-- end

-- r.defer(Main)
