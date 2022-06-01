-- @description V6_Button_organizer
-- @author Sexan
-- @license GPL v3
-- @version 1.2
-- @changelog
--   + Limit section finding

local reaper = reaper

local rtconfig_content = ''
local theme = reaper.GetResourcePath() .. "\\ColorThemes\\Default_6.0.ReaperThemeZip"
local ENTRY_NAME = "Default_6.0_unpacked\\rtconfig.txt"
--theme = reaper.GetLastColorThemeFile() .. "Zip"
local function str_split(s, delimiter)
    local result = {};
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do table.insert(result, match) end
    return result;
end

function Literalize(str)
    return str:gsub(
        "[%(%)%.%%%+%-%*%?%[%]%^%$]",
        function(c) return "%" .. c end
    )
end

-- READ RTCONFIG CONTENT
local function Get_RTCONFIG_Content()
    local zipHandle, ok = reaper.JS_Zip_Open(theme, 'r', 6)
    --local retval, list = reaper.JS_Zip_ListAllEntries(zipHandle)
    --ENTRY_NAME = list:gsub("%.ReaperTheme", "\\rtconfig.txt")
    local entry_id_r = reaper.JS_Zip_Entry_OpenByName(zipHandle, ENTRY_NAME)
    buf_size, rtconfig_content = reaper.JS_Zip_Entry_ExtractToMemory(zipHandle)
    reaper.JS_Zip_Entry_Close(zipHandle)
    reaper.JS_Zip_Close(theme)
end

local layouts, moded_layouts
local function Get_Layouts()
    layouts = {
        [1] = { name = "TCP" },
        --[2] = {name = "MCP"},
        [2] = { name = "ENV" },
        [3] = { name = "MASTER" },
    }
    -- TCP
    local tcp = rtconfig_content:match("TRACK CONTROL PANELS(.*)MASTER TRACK CONTROL PANEL")
    for layout in tcp:gmatch('(Layout ".-".-)drawTcp') do -- MATCH EVERYTHING BETWEEN "LAYOUT "X" AND drawTcp
        layouts[1][#layouts[1] + 1] = layout
    end

    -- MCP
    -- local mcp = rtconfig_content:match("THE MIXER(.*)")
    -- for layout in mcp:gmatch('(Layout ".-".-)drawMcp') do -- MATCH EVERYTHING BETWEEN "LAYOUT "X" AND drawMasterTcp
    --     layouts["MCP"][#layouts["MCP"] + 1] = layout
    -- end

    -- MASTER
    local master = rtconfig_content:match("MASTER TRACK CONTROL PANEL(.*)ENVELOPE CONTROL PANELS")
    for layout in master:gmatch('(Layout ".-".-)drawMasterTcp') do -- MATCH EVERYTHING BETWEEN "LAYOUT "X" AND drawMasterTcp
        layouts[3][#layouts[3] + 1] = layout
    end

    -- ENV
    local env_tcp = rtconfig_content:match("ENVELOPE CONTROL PANELS(.*)THE MIXER")
    for layout in env_tcp:gmatch('(Layout ".-".-)drawEnvcp') do -- MATCH EVERYTHING BETWEEN "LAYOUT "X" AND drawEnvcp
        layouts[2][#layouts[2] + 1] = layout
    end

    moded_layouts = {
        [1] = { name = "TCP" },
        --[2] = {name = "MCP"},
        [2] = { name = "ENV" },
        [3] = { name = "MASTER" },
    }
    for k in pairs(layouts) do
        for l, v in ipairs(layouts[k]) do
            moded_layouts[k][l] = str_split(v, '\n')
        end
    end
end

-- REFRESH REAPER THEME
local function RefreshTheme()
    local thisTheme = reaper.GetLastColorThemeFile()
    reaper.OpenColorThemeFile(thisTheme)
end

-- WRITE TO REATHEMEFILE
local function Write_to_theme_zip()
    local zipHandle, ok = reaper.JS_Zip_Open(theme, 'w', 6)
    local num_deleted = reaper.JS_Zip_DeleteEntries(zipHandle, ENTRY_NAME .. "\00", #ENTRY_NAME)
    local entry_id_w = reaper.JS_Zip_Entry_OpenByName(zipHandle, ENTRY_NAME)
    reaper.JS_Zip_Entry_CompressMemory(zipHandle, rtconfig_content, #rtconfig_content)
    reaper.JS_Zip_Entry_Close(zipHandle)
    reaper.JS_Zip_Close(theme)
    RefreshTheme() -- UPDATE REAPER THEME
end

-- MAKE CHANGES TO RTCONFIG AND REATHEME FILE
local function Store_and_Update_new_button(section, layout_idx)
    local current_reordered_layout = table.concat(moded_layouts[section][layout_idx], "\n"):gsub("%%", "%%%%") -- CONCAT NEW MODIFIED LAYOUT TO STRING
    local current_original_layout = Literalize(layouts[section][layout_idx])
    rtconfig_content = rtconfig_content:gsub(current_original_layout, current_reordered_layout) -- CHANGE THE ORIGINAL LAYOUT IN RTCONFIG WITH MODIFIED ONE
    Write_to_theme_zip() -- WRITE CHANGES TO REATHEME FILE
    Init() -- GET RTCONFIG DATA AGAIN
end

local patterns = { "tcp", "envcp", "master_", "master" }
local function Pattern_remove(str)
    str = str:gsub("%.", "") -- GET WORD AFTER "THEN" and remove dot
    for _, v in ipairs(patterns) do str = str:gsub(v, "") end
    return str
end

local ctx = reaper.ImGui_CreateContext('My script')
local function GUI()
    local visible, open = reaper.ImGui_Begin(ctx, 'V6 THEME BUTTON ORGANIZER', true, flags)
    if visible then
        -- ITERATE THU ALL LAYOUTS
        for j = 1, #moded_layouts do
            for i = 1, #moded_layouts[j] do
                local tbl = moded_layouts[j][i]
                -- ITERATE THRU LAYOUT LINES
                local layout_name = tbl[1]:match('(Layout ".-")') -- GET ONLY 'Layout "xxx"'
                if layouts[j][i]:lower():find('then') then -- IF ORIGINAL LAYOUT STRING HAS 'THEN' (WE ONLY NEED LAYOUTS THAT HAVE REORDERING)
                    reaper.ImGui_Text(ctx, moded_layouts[j].name .. " - " .. layout_name) -- SET TEXT AS NAME LAYOUT
                    reaper.ImGui_BeginGroup(ctx)
                    for k, v in ipairs(tbl) do
                        -- FIND "THEN" LINES (WHICH ARE USED FOR REORDER)
                        if string.find(v:lower(), 'then') then
                            local button_name = v:match("%S+ (%S+)") -- GET WORD AFTER "THEN"
                            button_name = Pattern_remove(button_name)
                            reaper.ImGui_Button(ctx, button_name .. "##" .. i)
                            reaper.ImGui_SameLine(ctx)
                            -- IF BUTTON IS DRAGGED START DRAG AND DROP
                            if reaper.ImGui_BeginDragDropSource(ctx) then
                                reaper.ImGui_SetDragDropPayload(ctx, 'DND_BUTTON', tostring(k))
                                reaper.ImGui_Text(ctx, button_name)
                                reaper.ImGui_EndDragDropSource(ctx)
                            end
                            -- GET DRAG AND DROP TARGET
                            if reaper.ImGui_BeginDragDropTarget(ctx) then
                                RV_P, PAYLOAD = reaper.ImGui_AcceptDragDropPayload(ctx, 'DND_BUTTON')
                                if RV_P then
                                    local payload_n = tonumber(PAYLOAD)
                                    tbl[k] = tbl[payload_n]
                                    tbl[payload_n] = v
                                    Store_and_Update_new_button(j, i)
                                end
                                reaper.ImGui_EndDragDropTarget(ctx)
                            end
                        end
                    end
                    reaper.ImGui_EndGroup(ctx)
                end
                --RV, contents = reaper.ImGui_InputTextMultiline(ctx, '##source', contents, -1, -1) -- TEXT EDITOR IN SCRIPT
            end
        end
        reaper.ImGui_End(ctx)
    end
    if open then reaper.defer(GUI)
    else reaper.ImGui_DestroyContext(ctx)
    end
end

function Init()
    Get_RTCONFIG_Content()
    Get_Layouts()
end

function Exit() end

Init()
reaper.atexit(Exit)
reaper.defer(GUI)
