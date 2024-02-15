local r = reaper
local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local fx_browser_script_path = r.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"

local png_data_file = r.GetResourcePath() .. "/Scripts/FX_PNG/FX_SIZES.txt"
local reaper_path = r.GetResourcePath()

local function CheckDeps()
    local deps = {}

    if not r.ImGui_GetVersion then
        deps[#deps + 1] = '"Dear Imgui"'
    end
    if not r.file_exists(fx_browser_script_path) then
        deps[#deps + 1] = '"FX Browser Parser V7"'
    end

    if #deps ~= 0 then
        r.ShowMessageBox("Need Additional Packages.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
        r.ReaPack_BrowsePackages(table.concat(deps, " OR "))
        return true
    end
end

if CheckDeps() then return end

local ctx = r.ImGui_CreateContext('FX BROWSER STANDALONE')

if r.file_exists(fx_browser_script_path) then
    dofile(fx_browser_script_path)
end

--CACHIN TO FILE
local FX_LIST_TEST, CAT = ReadFXFile()
if not FX_LIST_TEST or not CAT or #CAT == 0 then
    FX_LIST_TEST, CAT = MakeFXFiles()
end
local last_select = {}

local SIZE_DATA = {}

function ReadSizeFile()
    local fx_file = io.open(png_data_file, "r")
    if fx_file then
        local fx_string = fx_file:read("*all")
        fx_file:close()
        SIZE_DATA = StringToTable(fx_string)
    end
end

ReadSizeFile()

local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

local tsort = table.sort
function SortTable(tab, val1, val2)
    tsort(tab, function(a, b)
        if (a[val1] < b[val1]) then
            -- primary sort on position -> a before b
            return true
        elseif (a[val1] > b[val1]) then
            -- primary sort on position -> b before a
            return false
        else
            -- primary sort tied, resolve w secondary sort on rank
            return a[val2] < b[val2]
        end
    end)
end

local old_t = {}
local old_filter = ""
local EXCLUDE = {}
local function Filter_actions(filter_text, tbl)
    local fx_tbl = tbl --or FX_LIST_TEST
    if old_filter == filter_text then
        if last_name == filter_name then
            return old_t
        else
            filter_name = last_name
        end
    else
        old_filter = filter_text
    end
    RefreshImgObj()
    filter_text = Lead_Trim_ws(filter_text)
    local t = {}
    EXCLUDE = {}
    if filter_text == "" or not filter_text then return t end
    for i = 1, #fx_tbl do
        local name = fx_tbl[i]:lower() --:gsub("(%S+:)", "")
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then
            t[#t + 1] = { score = fx_tbl[i]:len() - filter_text:len(), name = fx_tbl[i] }
        else
            EXCLUDE[i] = true
        end
    end
    if #t >= 2 then
        SortTable(t, "score", "name") -- Sort by key priority
    end
    old_t = t
    old_filter = filter_text
    return t
end

local function SetMinMax(Input, Min, Max)
    if Input >= Max then
        Input = Max
    elseif Input <= Min then
        Input = Min
    else
        Input = Input
    end
    return Input
end

local FILTER = ''
local function FilterBox(width, tbl)
    local MAX_FX_SIZE = width or 300
    r.ImGui_PushItemWidth(ctx, MAX_FX_SIZE)
    if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end
    _, FILTER = r.ImGui_InputTextWithHint(ctx, '##input', "SEARCH FX", FILTER)
    local filtered_fx = Filter_actions(FILTER, tbl)
    local filter_h = #filtered_fx == 0 and 0 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx))
    ADDFX_Sel_Entry = SetMinMax(ADDFX_Sel_Entry or 1, 1, #filtered_fx)
    if #filtered_fx ~= 0 and not tbl then
        if r.ImGui_BeginChild(ctx, "##popupp", MAX_FX_SIZE, filter_h) then
            for i = 1, #filtered_fx do
                if r.ImGui_Selectable(ctx, filtered_fx[i].name, i == ADDFX_Sel_Entry) then
                    r.TrackFX_AddByName(TRACK, filtered_fx[i].name, false, -1000 - r.TrackFX_GetCount(TRACK))
                    r.ImGui_CloseCurrentPopup(ctx)
                    LAST_USED_FX = filtered_fx[i].name
                end
            end
            r.ImGui_EndChild(ctx)
        end
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            r.TrackFX_AddByName(TRACK, filtered_fx[ADDFX_Sel_Entry].name, false, -1000 - r.TrackFX_GetCount(TRACK))
            LAST_USED_FX = filtered_fx[filtered_fx[ADDFX_Sel_Entry].name]
            ADDFX_Sel_Entry = nil
            FILTER = ''
            r.ImGui_CloseCurrentPopup(ctx)
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry - 1
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
            ADDFX_Sel_Entry = ADDFX_Sel_Entry + 1
        end
    end
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        FILTER, old_filter = '', ''
        r.ImGui_CloseCurrentPopup(ctx)
    end
    return #filtered_fx ~= 0
end

local function DrawFxChains(tbl, path)
    local extension = ".RfxChain"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                DrawFxChains(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                if TRACK then
                    r.TrackFX_AddByName(TRACK, table.concat({ path, os_separator, tbl[i], extension }), false,
                        -1000 - r.TrackFX_GetCount(TRACK))
                end
            end
        end
    end
end

local function LoadTemplate(template, replace)
    local track_template_path = r.GetResourcePath() .. "/TrackTemplates" .. template
    if replace then
        local chunk = GetFileContext(track_template_path)
        r.SetTrackStateChunk(TRACK, chunk, true)
    else
        r.Main_openProject(track_template_path)
    end
end

local function DrawTrackTemplates(tbl, path)
    local extension = ".RTrackTemplate"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
                local cur_path = table.concat({ path, os_separator, tbl[i].dir })
                DrawTrackTemplates(tbl[i], cur_path)
                r.ImGui_EndMenu(ctx)
            end
        end
        if type(tbl[i]) ~= "table" then
            if r.ImGui_Selectable(ctx, tbl[i]) then
                if TRACK then
                    local template_str = table.concat({ path, os_separator, tbl[i], extension })
                    LoadTemplate(template_str)       -- ADD NEW TRACK FROM TEMPLATE
                    LoadTemplate(template_str, true) -- REPLACE CURRENT TRACK WITH TEMPLATE
                end
            end
        end
    end
end

local function DrawItems(tbl, main_cat_name)
    for i = 1, #tbl do
        if r.ImGui_BeginMenu(ctx, tbl[i].name) then
            for j = 1, #tbl[i].fx do
                if tbl[i].fx[j] then
                    local name = tbl[i].fx[j]
                    if main_cat_name == "ALL PLUGINS" and tbl[i].name ~= "INSTRUMENTS" then
                        -- STRIP PREFIX IN "ALL PLUGINS" CATEGORIES EXCEPT INSTRUMENT WHERE THERE CAN BE MIXED ONES
                        name = name:gsub("^(%S+:)", "")
                    elseif main_cat_name == "DEVELOPER" then
                        -- STRIP SUFFIX (DEVELOPER) FROM THESE CATEGORIES
                        name = name:gsub(' %(' .. Literalize(tbl[i].name) .. '%)', "")
                    end
                    if r.ImGui_Selectable(ctx, name) then
                        if TRACK then
                            r.TrackFX_AddByName(TRACK, tbl[i].fx[j], false,
                                -1000 - r.TrackFX_GetCount(TRACK))
                            LAST_USED_FX = tbl[i].fx[j]
                        end
                    end
                end
            end
            r.ImGui_EndMenu(ctx)
        end
    end
end

function RefreshImgObj()
    for k in pairs(SIZE_DATA) do
        SIZE_DATA[k].image_obj = nil
    end
end

function ListFromTbl(tbl, name)
    if name == last_name then return end
    if not tbl.list then return end
    RefreshImgObj()
    last_name = name
    last_select = {}
    for j = 1, #tbl.list do
        if tbl.list[j].fx then
            for k = 1, #tbl.list[j].fx do
                last_select[#last_select + 1] = tbl.list[j].fx[k]
            end
        else
            last_select[#last_select + 1] = tbl.list[j]
        end
    end
end

local function DrawItemsTree(tbl, xx)
    for i = 1, #tbl do
        r.ImGui_SetCursorPosX(ctx, xx)
        if r.ImGui_Selectable(ctx, tbl[i].name, last_name == tbl[i].name) then
            ListFromTbl({ list = { tbl[i] } }, tbl[i].name)
        end
    end
end

local function DrawFxChainsTree(tbl, path)
    local extension = ".RfxChain"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_Selectable(ctx, tbl[i].dir) then
                --ListFromTbl({ list = { tbl[i] } }, tbl[i].name)
                --DrawFxChainsTree(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
            end
        end
        if type(tbl[i]) ~= "table" then
            ListFromTbl(tbl[i], tbl[i].name)
            -- if r.ImGui_Selectable(ctx, tbl[i]) then
            -- --    ListFromTbl({ list = { tbl[i] } }, tbl[i].name)
            -- end
        end
    end
end

local function DrawTrackTemplatesTree(tbl, path)
    local extension = ".RTrackTemplate"
    path = path or ""
    for i = 1, #tbl do
        if tbl[i].dir then
            if r.ImGui_Selectable(ctx, tbl[i].dir) then
                local cur_path = table.concat({ path, os_separator, tbl[i].dir })
                --DrawTrackTemplates(tbl[i], cur_path)
            end
        end
    end
end

function Frame()
    local search = FilterBox()
    if search then return end
    for i = 1, #CAT do
        if r.ImGui_BeginMenu(ctx, CAT[i].name) then
            if CAT[i].name == "FX CHAINS" then
                DrawFxChains(CAT[i].list)
            elseif CAT[i].name == "TRACK TEMPLATES" then
                DrawTrackTemplates(CAT[i].list)
            else
                DrawItems(CAT[i].list, CAT[i].name)
            end
            r.ImGui_EndMenu(ctx)
        end
    end
    if r.ImGui_Selectable(ctx, "CONTAINER") then
        r.TrackFX_AddByName(TRACK, "Container", false,
            -1000 - r.TrackFX_GetCount(TRACK))
        LAST_USED_FX = "Container"
    end
    if r.ImGui_Selectable(ctx, "VIDEO PROCESSOR") then
        r.TrackFX_AddByName(TRACK, "Video processor", false,
            -1000 - r.TrackFX_GetCount(TRACK))
        LAST_USED_FX = "Video processor"
    end
    if LAST_USED_FX then
        if r.ImGui_Selectable(ctx, "RECENT: " .. LAST_USED_FX) then
            r.TrackFX_AddByName(TRACK, LAST_USED_FX, false,
                -1000 - r.TrackFX_GetCount(TRACK))
        end
    end
end

local last_thumb_size
local thumb_size = 2
ListFromTbl(CAT[1], "ALL PLUGINS")
function TreeView()
    local search = FilterBox(-200, last_select)
    r.ImGui_SameLine(ctx)
    r.ImGui_SetNextItemWidth(ctx, 50)
    _, thumb_size = r.ImGui_SliderInt(ctx, "##SIZE", thumb_size, 1, 5)
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "RESCAN PLUGIN LIST") then
        FX_LIST_TEST, CAT = MakeFXFiles()
        ListFromTbl(CAT[1], "ALL PLUGINS")
    end
    if r.ImGui_BeginChild(ctx, "LIST", 200, nil, true) then
        for i = 1, #CAT - 1 do
            if last_name == CAT[i].name then
                r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Header(), 0x00AA55FF)
            end
            local rv = r.ImGui_CollapsingHeader(ctx, CAT[i].name, false, r.ImGui_TreeNodeFlags_OpenOnDoubleClick()) --then
            if last_name == CAT[i].name then
                r.ImGui_PopStyleColor(ctx)
            end

            if r.ImGui_IsItemClicked(ctx, 0) then
                ListFromTbl(CAT[i], CAT[i].name)
            end
            if rv then
                if CAT[i].name == "FX CHAINS" then
                    DrawFxChainsTree(CAT[i].list)
                elseif CAT[i].name == "TRACK TEMPLATES" then
                    DrawTrackTemplatesTree(CAT[i].list)
                else
                    DrawItemsTree(CAT[i].list, r.ImGui_GetCursorPosX(ctx) + 20)
                end
            end
        end
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_BeginChild(ctx, "VIEW", nil, nil, true) then
        if last_select then
            for j = 1, #last_select do
                if not EXCLUDE[j] then
                    if last_select[j] then
                        local name = last_select[j]
                        if SIZE_DATA[name] then
                            local xx, yy = r.ImGui_GetCursorPos(ctx)
                            local w, h = SIZE_DATA[name].w // thumb_size, SIZE_DATA[name].h // thumb_size

                            r.ImGui_Dummy(ctx, w, h) -- PLACE HOLDER
                            local minx, miny = r.ImGui_GetItemRectMin(ctx)
                            local maxx, maxy = r.ImGui_GetItemRectMax(ctx)

                            if r.ImGui_IsRectVisibleEx(ctx, minx, miny, maxx, maxy) then
                                if not r.ImGui_ValidatePtr(SIZE_DATA[name].image_obj, 'ImGui_Image*') then
                                    SIZE_DATA[name].image_obj = r.ImGui_CreateImage(reaper_path .. SIZE_DATA[name].path)
                                end
                                r.ImGui_SetCursorPos(ctx, xx, yy)

                                r.ImGui_BeginGroup(ctx)
                                r.ImGui_Text(ctx, name)
                                if r.ImGui_ImageButton(ctx, name, SIZE_DATA[name].image_obj, w, h) then
                                    local track = r.GetSelectedTrack2(0, 0, true)
                                    if track then
                                        r.TrackFX_AddByName(r.GetSelectedTrack2(0, 0, true), name, false, 1)
                                    end
                                end
                                r.ImGui_EndGroup(ctx)
                                if r.ImGui_IsItemActive(ctx) and r.ImGui_IsMouseDragging(ctx, 0) and r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_SourceExtern()) then
                                    last_fx = name
                                    r.ImGui_Image(ctx, SIZE_DATA[name].image_obj, w, h)
                                    r.ImGui_EndDragDropSource(ctx)
                                end
                            end
                        else
                            if r.ImGui_Button(ctx, name) then

                            end
                        end
                    end
                end
            end
        end
        r.ImGui_EndChild(ctx)
    end
    if r.ImGui_IsMouseReleased(ctx, 0) and last_fx then
        local retval = r.GetTrackFromPoint(r.GetMousePosition())
        if retval then
            r.TrackFX_AddByName(retval, last_fx, false, 1)
            last_fx = nil
        end
    end
end

function Main()
    local visible, open = r.ImGui_Begin(ctx, 'FX BROWSER', true)
    if visible then
        --UPDATE FX CHAINS (WE DONT NEED TO RESCAN EVERYTHING IF NEW CHAIN WAS CREATED BY SCRIPT)
        if WANT_REFRESH then
            WANT_REFRESH = nil
            UpdateChainsTrackTemplates(CAT)
        end
        -- RESCAN FILE LIST
        -- if r.ImGui_Button(ctx, "RESCAN PLUGIN LIST") then
        --     FX_LIST_TEST, CAT = MakeFXFiles()
        -- end
        --Frame()
        TreeView()
        r.ImGui_End(ctx)
    end
    if last_thumb_size ~= thumb_size then
        last_thumb_size = thumb_size
        RefreshImgObj()
    end
    if open then
        r.defer(Main)
    end
end

r.defer(Main)
