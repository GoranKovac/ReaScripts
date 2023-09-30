-- @description Sexan FX Browser parser
-- @author Sexan
-- @license GPL v3
-- @version 1.1
-- @changelog
--  Added Developer names table to use with name stripping

local r = reaper
local os = r.GetOS()
local os_separator = package.config:sub(1, 1)
local CAT = {}
local DEVELOPER_LIST = { "Waves" }

function GetFileContext(fp)
    local str = "\n"
    -- DONT CRASH SCRIPT IF PATH IS NOT PROVIDED
    if not fp then return str end
    local f = io.open(fp, 'r')
    if f then
        str = f:read('a')
        f:close()
    end
    return str
end

local function GetDirFilesRecursive(dir, tbl, filter)
    for index = 0, math.huge do
        local path = r.EnumerateSubdirectories(dir, index)
        if not path then break end
        tbl[#tbl + 1] = { dir = path, {} }
        GetDirFilesRecursive(dir .. os_separator .. path, tbl[#tbl], filter)
    end

    for index = 0, math.huge do
        local file = r.EnumerateFiles(dir, index)
        if not file then break end
        tbl[#tbl + 1] = file:gsub(filter, "")
    end
end

local function FindCategory(cat)
    for i = 1, #CAT do
        if CAT[i].name == cat then return CAT[i].list end
    end
end

local function FindFXIDName(tbl, id, js)
    for i = 1, #tbl do
        if js then
            -- JS PLUGINS CAN HAVE ONLY PART OF IDENTIFIER IN THE STRING
            if tbl[i].id:find(id) then return tbl[i].name end
        else
            if tbl[i].id == id then return tbl[i].name end
        end
    end
end

function InTbl(tbl, val)
    for i = 1, #tbl do
        if tbl[i].name == val then return tbl[i].fx end
    end
end

function AddDevList(val)
    for i = 1, #DEVELOPER_LIST do
        if DEVELOPER_LIST[i] == val then return end
    end
    DEVELOPER_LIST[#DEVELOPER_LIST + 1] = val
end

local function ParseVST(plugin_list, INSTRUMENTS)
    local VST_INFO = {}
    local VST = {}
    local VSTi = {}
    local VST3 = {}
    local VST3i = {}
    local rename_tbl = {}

    local vst_path
    local vst_str

    if os == "Win32" or os == "OSX32" then
        vst_path = r.GetResourcePath() .. "/reaper-vstplugins.ini"
    elseif os == "Win64" or os == "OSX64" or os == "Other" then
        vst_path = r.GetResourcePath() .. "/reaper-vstplugins64.ini"
    elseif os == "macOS-arm64" then
        vst_path = r.GetResourcePath() .. "/reaper-vstplugins_arm64.ini"
    end

    local vst_rename_path

    if os == "Win32" or os == "OSX32" then
        vst_rename_path = r.GetResourcePath() .. "/reaper-vstrenames.ini"
    elseif os == "Win64" or os == "OSX64" or os == "Other" then
        vst_rename_path = r.GetResourcePath() .. "reaper-vstrenames64.ini"
    elseif os == "macOS-arm64" then
        vst_rename_path = r.GetResourcePath() .. "/reaper-vstpluginsrenames_arm64.ini"
    end

    if vst_rename_path then
        local vst_rename_str = GetFileContext(vst_rename_path)
        for line in vst_rename_str:gmatch('[^\r\n]+') do
            rename_tbl[#rename_tbl + 1] = line
        end
    end

    vst_str = GetFileContext(vst_path)

    for line in vst_str:gmatch('[^\r\n]+') do
        -- reacast.dll=00EE7DC39FE1D901,1919246691,ReaCast (Cockos)
        -- MATCH EVERY FIELD SEPARATED BY '=' AND ','
        local dll, id1, id2, name = line:match('(.-)=(.-),(.-),(.+)')
        if name and name ~= "<SHELL>" then
            local instrument = name:match("!!!VSTi")
            name = name:gsub("!!!VSTi", "")
            for i = 1, #rename_tbl do
                local new_id, new_name = rename_tbl[i]:match("(.+)=(.+)")
                if new_id == dll then
                    name = new_name
                end
            end
            -- VST3
            if dll:match("vst3") then
                local vst3_name = "VST3:" .. name
                VST_INFO[#VST_INFO + 1] = { id = dll, name = vst3_name }
                plugin_list[#plugin_list + 1] = vst3_name
                VST3[#VST3 + 1] = vst3_name
                -- VST3i
                if instrument then
                    VST3i[#VST3i + 1] = vst3_name
                    INSTRUMENTS[#INSTRUMENTS + 1] = vst3_name
                end
            else
                local vst_name = "VST:" .. name
                -- VST
                VST_INFO[#VST_INFO + 1] = { id = dll, name = vst_name }
                plugin_list[#plugin_list + 1] = vst_name
                VST[#VST + 1] = vst_name
                -- VSTi
                if instrument then
                    VSTi[#VSTi + 1] = vst_name
                    INSTRUMENTS[#INSTRUMENTS + 1] = vst_name
                end
            end
        end
    end
    return VST_INFO, VST, VSTi, VST3, VST3i
end

local function ParseJSFX(plugin_list)
    local JS_INFO   = {}
    local JS        = {}

    local jsfx_path = r.GetResourcePath() .. "/reaper-jsfx.ini"
    local jsfx_str  = GetFileContext(jsfx_path)

    for line in jsfx_str:gmatch('[^\r\n]+') do
        local js_name
        if line:match("NAME") then
            -- NAME utility/volume "JS: Volume Adjustment"
            -- NAME "ReaTeam Scripts/FX/BryanChi_FX Devices/cookdsp/fft-mono-template" "JS: FFT Mono Template"
            local id, name = line:match('%w+ ["]?(.+)["]? "JS: (.+)"')
            if name then
                js_name = "JS:" .. name
                JS_INFO[#JS_INFO + 1] = { id = id:gsub('"', ''), name = js_name }
            end
        end
        if js_name then
            plugin_list[#plugin_list + 1] = js_name
            JS[#JS + 1] = js_name
        end
    end
    return JS_INFO, JS
end

local function ParseAU(plugin_list, INSTRUMENTS)
    local AU_INFO = {}
    local AU      = {}
    local AUi     = {}

    local au_path
    local au_str

    if os == "OSX32" then
        au_path = r.GetResourcePath() .. "/reaper-auplugins.ini"
    elseif os == "OSX64" then
        au_path = r.GetResourcePath() .. "/reaper-auplugins64.ini"
    elseif os == "macOS-arm64" then
        au_path = r.GetResourcePath() .. "/reaper-auplugins_arm64.ini"
    end

    au_str = GetFileContext(au_path)

    for line in au_str:gmatch('[^\r\n]+') do
        local identifier = line:match("(.+)=<")
        if identifier then
            local renamed = line:match("=<.+>(.+)")
            local is_instrument = line:match("<inst>")
            local au_name = "AU:" .. (renamed and renamed or identifier)
            AU[#AU + 1] = au_name
            AU_INFO[#AU_INFO + 1] = { id = identifier, name = au_name }
            if is_instrument then
                AUi[#AUi + 1] = au_name
                INSTRUMENTS[#INSTRUMENTS + 1] = au_name
            end
            plugin_list[#plugin_list + 1] = au_name
        end
    end

    return AU_INFO, AU, AUi
end

local function ParseCLAP(plugin_list, INSTRUMENTS)
    local CLAP_INFO  = {}
    local CLAP       = {}
    local CLAPi      = {}

    local rename_tbl = {}

    local clap_path
    local clap_str

    if os == "Win64" then
        clap_path = r.GetResourcePath() .. "/reaper-clap-win64.ini"
    elseif os == 'OSX64' then
        clap_path = r.GetResourcePath() .. "/reaper-clap-macos-x86_64.ini"
    elseif os == "macOS-arm64" then
        clap_path = r.GetResourcePath() .. "/reaper-clap-macos-arm64.ini"
    elseif os == "Other" then
        -- LINUX
        clap_path = r.GetResourcePath() .. "/reaper-clap-linux-x86_64.ini"
    end

    clap_str = GetFileContext(clap_path)

    local clap_rename_path
    if os == "Win64" then
        clap_rename_path = r.GetResourcePath() .. "/reaper-clap-rename-win64.ini"
    elseif os == 'OSX64' then
        clap_rename_path = r.GetResourcePath() .. "/reaper-clap-rename-macos-x86_64.ini"
    elseif os == "macOS-arm64" then
        clap_rename_path = r.GetResourcePath() .. "/reaper-clap-rename-macos-arm64.ini"
    elseif os == "Other" then
        -- LINUX
        clap_rename_path = r.GetResourcePath() .. "reaper-clap-rename-linux-x86_64.ini"
    end


    if clap_rename_path then
        local clap_rename_str = GetFileContext(clap_rename_path)
        for line in clap_rename_str:gmatch('[^\r\n]+') do
            rename_tbl[#rename_tbl + 1] = line
        end
    end

    for line in clap_str:gmatch('[^\r\n]+') do
        --org.surge-synth-team.surge-xt-fx=0|Surge XT Effects (Surge Synth Team)
        -- SKIP SOME ID/GUID LINE "_=00E3FA30507FD901FD9E7AF993E4D901"
        if not line:match("_=") then
            -- GET STRINGS BETWEEN "=0|"
            local id, name = line:match("(.+)=%d+|(.+)")
            if name then
                -- MATCH "fx=0|"
                local is_instrument = line:match("=1|")
                local clap_name = "CLAP:" .. name
                -- CHECK IF PLUGIN IS RENAMED
                for i = 1, #rename_tbl do
                    local new_id, new_name = rename_tbl[i]:match("(.+)=%d+|(.+)")
                    if new_id == id then
                        clap_name = "CLAP:" .. new_name
                    end
                end
                CLAP_INFO[#CLAP_INFO + 1] = { id = id, name = clap_name }
                CLAP[#CLAP + 1] = clap_name
                if is_instrument then
                    CLAPi[#CLAPi + 1] = clap_name
                    INSTRUMENTS[#INSTRUMENTS + 1] = clap_name
                end
                plugin_list[#plugin_list + 1] = clap_name
            end
        end
    end
    return CLAP_INFO, CLAP, CLAPi
end

local function ParseLV2(plugin_list)
    local LV2_INFO = {}
    local LV2 = {}
    local LV2i = {}

    local lv2_str = "\n"

    if r.APIExists("LV2") then lv2_str = "reaper.lvl2api" end

    for line in lv2_str:gmatch('[^\r\n]+') do
        local lv2_plugin, uri = line:match('(.+)=(.+)')
        if lv2_plugin then
            local is_instrument
            local lv2_name = "LV2:" .. lv2_plugin

            LV2_INFO[#LV2_INFO + 1] = { id = uri, name = lv2_name }
            LV2[#LV2 + 1] = lv2_name
            plugin_list[#plugin_list + 1] = lv2_name
            if is_instrument then LV2i[#LV2i + 1] = lv2_name end
        end
    end

    return LV2_INFO, LV2, LV2i
end

local function ParseFXTags(VST_INFO, JS_INFO, AU_INFO, CLAP_INFO)
    -- PARSE CATEGORIES
    local tags_path = r.GetResourcePath() .. "/reaper-fxtags.ini"
    local tags_str  = GetFileContext(tags_path)
    local DEV       = true
    for line in tags_str:gmatch('[^\r\n]+') do
        local category = line:match("%[(.+)%]")
        if line:match("%[(category)%]") then
            DEV = false
        end
        -- CATEGORY FOUND
        if category then
            CAT[#CAT + 1] = { name = category:upper(), list = {} }
        end
        -- PLUGIN FOUND
        local FX, dev_category = line:match("(.+)=(.+)")
        if dev_category then
            if DEV then AddDevList(dev_category) end
            local fx_name = FindFXIDName(VST_INFO, FX)
            fx_name = fx_name and fx_name or FindFXIDName(AU_INFO, FX)
            fx_name = fx_name and fx_name or FindFXIDName(CLAP_INFO, FX)
            fx_name = fx_name and fx_name or FindFXIDName(JS_INFO, FX, "JS")
            --fx_name = fx_name and fx_name or FindFXIDName(LV2_INFO, FX, "JS")
            -- SPLIT MULTIPLE CATEGORIES AT |
            if dev_category:match("|") then
                for category_type in dev_category:gmatch('[^%|]+') do
                    -- TRIM LEADING AND TRAILING WHITESPACES
                    local dev_tbl = InTbl(CAT[#CAT].list, category_type)
                    if fx_name then
                        -- ADD CATEGORY ONLY IF PLUGIN EXISTS
                        if not dev_tbl then
                            table.insert(CAT[#CAT].list, { name = category_type, fx = { fx_name } })
                        else
                            table.insert(dev_tbl, fx_name)
                        end
                    end
                end
            else
                -- ADD SINGLE CATEGORY
                local dev_tbl = InTbl(CAT[#CAT].list, dev_category)
                if fx_name then
                    -- ADD CATEGORY ONLY IF PLUGIN EXISTS
                    if not dev_tbl then
                        table.insert(CAT[#CAT].list, { name = dev_category, fx = { fx_name } })
                    else
                        table.insert(dev_tbl, fx_name)
                    end
                end
            end
        end
    end
end

local function ParseCustomCategories(VST_INFO, JS_INFO, AU_INFO, CLAP_INFO)
    local fav_path = r.GetResourcePath() .. "/reaper-fxfolders.ini"
    local fav_str  = GetFileContext(fav_path)
    local cur_cat_tbl
    for line in fav_str:gmatch('[^\r\n]+') do
        local category = line:match("%[(.-)%]")
        if category then
            if category == "category" then
                cur_cat_tbl = FindCategory(category:upper())
            elseif category == "developer" then
                cur_cat_tbl = FindCategory(category:upper())
            else
                cur_cat_tbl = nil
            end
        end

        if cur_cat_tbl then
            local FX, categories = line:match("(.+)=(.+)")
            if categories then
                local fx_name = FindFXIDName(VST_INFO, FX)
                fx_name = fx_name and fx_name or FindFXIDName(AU_INFO, FX)
                fx_name = fx_name and fx_name or FindFXIDName(CLAP_INFO, FX)
                fx_name = fx_name and fx_name or FindFXIDName(JS_INFO, FX, "JS")
                --fx_name = fx_name and fx_name or FindFXIDName(LV2_INFO, FX, "JS")
                for category_type in categories:gmatch('([^+-%|]+)') do
                    local dev_tbl = InTbl(cur_cat_tbl, category_type)
                    if fx_name then
                        -- ADD CATEGORY ONLY IF PLUGIN EXISTS
                        if not dev_tbl then
                            table.insert(cur_cat_tbl, { name = category_type, fx = { fx_name } })
                        else
                            table.insert(dev_tbl, fx_name)
                        end
                    end
                end
            end
        end
    end
end

local function ParseFavorites(VST_INFO, JS_INFO, AU_INFO, CLAP_INFO)
    -- PARSE FAVORITES FOLDER
    local fav_path = r.GetResourcePath() .. "/reaper-fxfolders.ini"
    local fav_str  = GetFileContext(fav_path)

    CAT[#CAT + 1]  = { name = "FOLDERS", list = {} }
    local current_folder
    for line in fav_str:gmatch('[^\r\n]+') do
        local folder = line:match("%[(Folder%d+)%]")

        -- GET INITIAL FOLDER NAME "[Folder0]" AND SAVE IF
        if folder then current_folder = folder end

        -- GET FOLDER ITEMS "Item0=..."
        if line:match("Item%d+") then
            local item = line:match("Item%d+=(.+)")
            local dev_tbl = InTbl(CAT[#CAT].list, current_folder)
            if not dev_tbl then
                table.insert(CAT[#CAT].list, { name = current_folder, fx = { item } })
            else
                table.insert(dev_tbl, item)
            end
        end

        -- RENAME ITEMS BY TYPE TO REAL NAMES "Type0=2"
        -- 3 = VST, 2 = JS, 7 = CLAP, 1 = LV2
        if line:match("Type%d+") then
            local line_id, fx_type = line:match("(%d+)=(%d+)")
            if fx_type == "3" then -- VST
                local item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                if item then
                    local id = os:match("Win") and item:reverse():match("(.-)\\") or item:reverse():match("(.-)/")
                    if id then
                        -- NEED TO REPLACE WHITESPACES AND DASH WITH LOWER DASH ALSO (HOW ITS IN VST INI FILE)
                        id = id:reverse():gsub(" ", "_"):gsub("-", "_")
                        CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1] = FindFXIDName(VST_INFO, id)
                    end
                end
            elseif fx_type == "2" then --JSFX
                local item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1] = FindFXIDName(JS_INFO, item)
            elseif fx_type == "7" then -- CLAP
                local item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1] = FindFXIDName(CLAP_INFO, item)
            elseif fx_type == "1" then -- LV2
                --local item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                --CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1] = FindFXIDName(LV2_INFO, item)
            elseif fx_type == "5" then -- AU
                local item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1] = FindFXIDName(AU_INFO, item)
            elseif fx_type == "1048576" then -- SMART FOLDER
                CAT[#CAT].list[#CAT[#CAT].list].smart = true
            end
        end
        -- RENAME ORIGINAL FOLDER NAME "[Folder0]" TO PROPER ID NAME (Name0=Favorites)
        if line:match("Name%d+=(.+)") then
            -- EXTRACT NAME
            local folder_name = line:match("Name%d+=(.+)")
            local folder_ID = line:match("(%d+)=")

            -- FIND THE SAME ID AS NAME - Name0 -> Folder0 AND REPLACE ITS NAME
            for i = 1, #CAT[#CAT].list do
                if CAT[#CAT].list[i].name == "Folder" .. folder_ID then
                    CAT[#CAT].list[i].name = folder_name
                end
            end
        end
    end
    -- REMOVE SMART FOLDERS FOR NOW
    for i = 1, #CAT do
        for j = #CAT[i].list, 1, -1 do
            if CAT[i].list[j].smart then table.remove(CAT[i].list, j) end
        end
    end
end

local function ParseFXChains()
    local fxChainsFolder = r.GetResourcePath() .. "/FXChains"
    local FX_CHAINS = {}
    GetDirFilesRecursive(fxChainsFolder, FX_CHAINS, ".RfxChain")
    if #FX_CHAINS ~= 0 then
        --table.sort(FX_CHAINS, function(a, b) if a and b then return a:lower() < b:lower() end end)
        CAT[#CAT + 1] = { name = "FX CHAINS", list = FX_CHAINS }
    end
end

local function ParseTrackTemplates()
    local trackTemplatesFolder = r.GetResourcePath() .. "/TrackTemplates"
    local TRACK_TEMPLATES = {}
    GetDirFilesRecursive(trackTemplatesFolder, TRACK_TEMPLATES, ".RTrackTemplate")
    if #TRACK_TEMPLATES ~= 0 then
        --table.sort(FX_CHAINS, function(a, b) if a and b then return a:lower() < b:lower() end end)
        CAT[#CAT + 1] = { name = "TRACK TEMPLATES", list = TRACK_TEMPLATES }
    end
end

local function AllPluginsCategory(JS, AU, AUi, CLAP, CLAPi, VST, VSTi, VST3, VST3i, INSTRUMENTS)
    CAT[#CAT + 1] = { name = "ALL PLUGINS", list = {} }
    if #JS ~= 0 then table.insert(CAT[#CAT].list, { name = "JS", fx = JS }) end
    if #AU ~= 0 then table.insert(CAT[#CAT].list, { name = "AU", fx = AU }) end
    if #AUi ~= 0 then table.insert(CAT[#CAT].list, { name = "AUi", fx = AUi }) end
    if #CLAP ~= 0 then table.insert(CAT[#CAT].list, { name = "CLAP", fx = CLAP }) end
    if #CLAPi ~= 0 then table.insert(CAT[#CAT].list, { name = "CLAPi", fx = CLAPi }) end
    if #VST ~= 0 then table.insert(CAT[#CAT].list, { name = "VST", fx = VST }) end
    if #VSTi ~= 0 then table.insert(CAT[#CAT].list, { name = "VSTi", fx = VSTi }) end
    if #VST3 ~= 0 then table.insert(CAT[#CAT].list, { name = "VST3", fx = VST3 }) end
    if #VST3i ~= 0 then table.insert(CAT[#CAT].list, { name = "VST3i", fx = VST3i }) end
    if #INSTRUMENTS ~= 0 then table.insert(CAT[#CAT].list, { name = "INSTRUMENTS", fx = INSTRUMENTS }) end
    --if #LV2 ~= 0 then table.insert(CAT[#CAT].list, { name = "LV2", fx = LV2 }) end
    --if #LV2i ~= 0 then table.insert(CAT[#CAT].list, { name = "LV2i", fx = LV2i }) end


    -- SORT EVERYTHING ALPHABETICALLY
    for i = 1, #CAT do
        table.sort(CAT[i].list, function(a, b) if a.name and b.name then return a.name:lower() < b.name:lower() end end)
        for j = 1, #CAT[i].list do
            if CAT[i].list[j].fx then
                table.sort(CAT[i].list[j].fx, function(a, b) if a and b then return a:lower() < b:lower() end end)
            end
        end
    end

    table.sort(CAT, function(a, b) if a.name and b.name then return a.name:lower() < b.name:lower() end end)
end

function GenerateFxList()
    local plugin_list = {}
    local INSTRUMENTS = {}

    plugin_list[#plugin_list + 1] = "Container"
    plugin_list[#plugin_list + 1] = "Video processor"

    local VST_INFO, VST, VSTi, VST3, VST3i = ParseVST(plugin_list, INSTRUMENTS)
    local JS_INFO, JS = ParseJSFX(plugin_list)
    local AU_INFO, AU, AUi = ParseAU(plugin_list, INSTRUMENTS)
    local CLAP_INFO, CLAP, CLAPi = ParseCLAP(plugin_list, INSTRUMENTS)
    --local LV2_INFO, LV2, LV2i = ParseLV2(plugin_list)
    ParseFXTags(VST_INFO, JS_INFO, AU_INFO, CLAP_INFO) -- CATEGORIES
    ParseCustomCategories(VST_INFO, JS_INFO, AU_INFO, CLAP_INFO)
    ParseFavorites(VST_INFO, JS_INFO, AU_INFO, CLAP_INFO)
    ParseFXChains()
    ParseTrackTemplates()
    AllPluginsCategory(JS, AU, AUi, CLAP, CLAPi, VST, VSTi, VST3, VST3i, INSTRUMENTS)

    return plugin_list
end

function Stripname(name, prefix, suffix)
    -- REMOVE DEVELOPER
    if suffix then
        for i = 1, #DEVELOPER_LIST do
            if name:match(DEVELOPER_LIST[i]) then
                name = name:gsub('%(' .. DEVELOPER_LIST[i] .. '%)', "")
            end
        end
    end
    -- REMOVE VST: JS: AU: CLAP:
    name = prefix and name:gsub("(%S+: )", "") or name
    return name
end

function GetFXTbl()
    return GenerateFxList(), CAT
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
-- EXAMPLE FOR IMPLEMENTING IN YOUR SCRIPTS
-- COPY PASTE CODE BELLOW INTO NEW SCRIPT
-- MAKE SURE THIS SCRIPT "Sexan_FX_Browser" IS IN SAME FOLDER AS YOUR MAIN SCRIPT
-- DO NOT UNCOMMENT CODE BELLOW (ONLY FOR STANDALONE TESTING PURPOSES)
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------


-- local os_separator = package.config:sub(1, 1)
-- package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
-- require("Sexan_FX_Browser")

-- local r = reaper
-- local ctx = r.ImGui_CreateContext('FX INI PARSER')

-- local FX_LIST, CAT = GetFXTbl()
-- local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

-- local function Filter_actions(filter_text)
--     filter_text = Lead_Trim_ws(filter_text)
--     local t = {}
--     if filter_text == "" or not filter_text then return t end
--     for i = 1, #FX_LIST do
--         local action = FX_LIST[i]
--         local name = action:lower()
--         local found = true
--         for word in filter_text:gmatch("%S+") do
--             if not name:find(word:lower(), 1, true) then
--                 found = false
--                 break
--             end
--         end

--         if found then t[#t + 1] = action end
--     end
--     return t
-- end

-- local function SetMinMax(Input, Min, Max)
--     if Input >= Max then
--         Input = Max
--     elseif Input <= Min then
--         Input = Min
--     else
--         Input = Input
--     end
--     return Input
-- end

-- local FILTER = ''
-- local function FilterBox()
--     local MAX_FX_SIZE = 300
--     r.ImGui_PushItemWidth(ctx, MAX_FX_SIZE)
--     if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end
--     _, FILTER = r.ImGui_InputTextWithHint(ctx, '##input', "SEARCH FX", FILTER)
--     local filtered_fx = Filter_actions(FILTER)
--     local filter_h = #filtered_fx == 0 and 0 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx))
--     ADDFX_Sel_Entry = SetMinMax(ADDFX_Sel_Entry or 1, 1, #filtered_fx)
--     if #filtered_fx ~= 0 then
--         if r.ImGui_BeginChild(ctx, "##popupp", MAX_FX_SIZE, filter_h) then
--             for i = 1, #filtered_fx do
--                 if r.ImGui_Selectable(ctx, filtered_fx[i], i == ADDFX_Sel_Entry) then
--                     r.TrackFX_AddByName(TRACK, filtered_fx[i], false, -1000 - r.TrackFX_GetCount(TRACK))
--                     r.ImGui_CloseCurrentPopup(ctx)
--                     LAST_USED_FX = filtered_fx[i]
--                 end
--             end
--             r.ImGui_EndChild(ctx)
--         end
--         if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
--             r.TrackFX_AddByName(TRACK, filtered_fx[ADDFX_Sel_Entry], false, -1000 - r.TrackFX_GetCount(TRACK))
--             LAST_USED_FX = filtered_fx[filtered_fx[ADDFX_Sel_Entry]]
--             ADDFX_Sel_Entry = nil
--             FILTER = ''
--             r.ImGui_CloseCurrentPopup(ctx)
--         elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then
--             ADDFX_Sel_Entry = ADDFX_Sel_Entry - 1
--         elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
--             ADDFX_Sel_Entry = ADDFX_Sel_Entry + 1
--         end
--     end
--     if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
--         FILTER = ''
--         r.ImGui_CloseCurrentPopup(ctx)
--     end
--     return #filtered_fx ~= 0
-- end

-- local function DrawFxChains(tbl, path)
--     local extension = ".RfxChain"
--     path = path or ""
--     for i = 1, #tbl do
--         if tbl[i].dir then
--             if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
--                 DrawFxChains(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
--                 r.ImGui_EndMenu(ctx)
--             end
--         end
--         if type(tbl[i]) ~= "table" then
--             if r.ImGui_Selectable(ctx, tbl[i]) then
--                 if TRACK then
--                     r.TrackFX_AddByName(TRACK, table.concat({ path, os_separator, tbl[i], extension }), false,
--                         -1000 - r.TrackFX_GetCount(TRACK))
--                 end
--             end
--         end
--     end
-- end

-- local function LoadTemplate(template, replace)
--     local track_template_path = r.GetResourcePath() .. "/TrackTemplates" .. template
--     if replace then
--         local chunk = GetFileContext(track_template_path)
--         r.SetTrackStateChunk( TRACK, chunk, true )
--     else
--         r.Main_openProject( track_template_path )
--     end
-- end

-- local function DrawTrackTemplates(tbl, path)
--     local extension = ".RTrackTemplate"
--     path = path or ""
--     for i = 1, #tbl do
--         if tbl[i].dir then
--             if r.ImGui_BeginMenu(ctx, tbl[i].dir) then
--                 local cur_path = table.concat({ path, os_separator, tbl[i].dir })
--                 DrawTrackTemplates(tbl[i], cur_path)
--                 r.ImGui_EndMenu(ctx)
--             end
--         end
--         if type(tbl[i]) ~= "table" then
--             if r.ImGui_Selectable(ctx, tbl[i]) then
--                 if TRACK then
--                     local template_str = table.concat({ path, os_separator, tbl[i], extension })
--                     LoadTemplate(template_str) -- ADD NEW TRACK FROM TEMPLATE
--                     LoadTemplate(template_str, true) -- REPLACE CURRENT TRACK WITH TEMPLATE
--                 end
--             end
--         end
--     end
-- end

-- local function DrawItems(tbl)
--     for i = 1, #tbl do
--         if r.ImGui_BeginMenu(ctx, tbl[i].name) then
--             for j = 1, #tbl[i].fx do
--                 if tbl[i].fx[j] then
--                     if r.ImGui_Selectable(ctx, tbl[i].fx[j]) then
--                         if TRACK then
--                             r.TrackFX_AddByName(TRACK, tbl[i].fx[j], false,
--                                 -1000 - r.TrackFX_GetCount(TRACK))
--                             LAST_USED_FX = tbl[i].fx[j]
--                         end
--                     end
--                 end
--             end
--             r.ImGui_EndMenu(ctx)
--         end
--     end
-- end

-- function Frame()
--     local search = FilterBox()
--     if search then return end
--     for i = 1, #CAT do
--         if r.ImGui_BeginMenu(ctx, CAT[i].name) then
--             if CAT[i].name == "FX CHAINS" then
--                 DrawFxChains(CAT[i].list)
--             elseif CAT[i].name == "TRACK TEMPLATES" then
--                 DrawTrackTemplates(CAT[i].list)
--             else
--                 DrawItems(CAT[i].list)
--             end
--             r.ImGui_EndMenu(ctx)
--         end
--     end
--     if r.ImGui_Selectable(ctx, "CONTAINER") then
--         r.TrackFX_AddByName(TRACK, "Container", false,
--             -1000 - r.TrackFX_GetCount(TRACK))
--         LAST_USED_FX = "Container"
--     end
--     if r.ImGui_Selectable(ctx, "VIDEO PROCESSOR") then
--         r.TrackFX_AddByName(TRACK, "Video processor", false,
--             -1000 - r.TrackFX_GetCount(TRACK))
--         LAST_USED_FX = "Video processor"
--     end
--     if LAST_USED_FX then
--         if r.ImGui_Selectable(ctx, "RECENT: " .. LAST_USED_FX) then
--             r.TrackFX_AddByName(TRACK, LAST_USED_FX, false,
--                 -1000 - r.TrackFX_GetCount(TRACK))
--         end
--     end
-- end

-- function Main()
--     TRACK = r.GetSelectedTrack(0, 0)
--     local visible, open = r.ImGui_Begin(ctx, 'FX INI PARSER', true)
--     if visible then
--         if TRACK then
--             Frame()
--         else
--             reaper.ImGui_Text( ctx, "SELECT TRACK" )
--         end
--         r.ImGui_End(ctx)
--     end
--     if open then
--         r.defer(Main)
--     end
-- end

-- r.defer(Main)
