-- @description Sexan FX Browser parser V7
-- @author Sexan
-- @license GPL v3
-- @version 1.41
-- @changelog
--  find fix

local r                                = reaper
local os                               = r.GetOS()
local os_separator                     = package.config:sub(1, 1)
local script_path                      = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]

local FX_FILE                          = script_path .. "/FX_LIST.txt"
local FX_CAT_FILE                      = script_path .. "/FX_CAT_FILE.txt"
local FX_DEV_LIST_FILE                 = script_path .. "/FX_DEV_LIST_FILE.txt"

local CAT                              = {}
local DEVELOPER_LIST                   = { " (Waves)" }
local PLUGIN_LIST                      = {}
local INSTRUMENTS                      = {}
local VST_INFO, VST, VSTi, VST3, VST3i = {}, {}, {}, {}, {}
local JS_INFO, JS                      = {}, {}
local AU_INFO, AU, AUi                 = {}, {}, {}
local CLAP_INFO, CLAP, CLAPi           = {}, {}, {}
local LV2_INFO, LV2, LV2i              = {}, {}, {}

local function ResetTables()
    CAT = {}
    DEVELOPER_LIST = { " (Waves)" }
    PLUGIN_LIST = {}
    INSTRUMENTS = {}
    VST_INFO, VST, VSTi, VST3, VST3i = {}, {}, {}, {}, {}
    JS_INFO, JS = {}, {}
    AU_INFO, AU, AUi = {}, {}, {}
    CLAP_INFO, CLAP, CLAPi = {}, {}, {}
    LV2_INFO, LV2, LV2i = {}, {}, {}
end

function MakeFXFiles()
    GetFXTbl()
    local serialized_fx = TableToString(PLUGIN_LIST)
    WriteToFile(FX_FILE, serialized_fx)

    local serialized_cat = TableToString(CAT)
    WriteToFile(FX_CAT_FILE, serialized_cat)

    local serialized_dev_list = TableToString(DEVELOPER_LIST)
    WriteToFile(FX_DEV_LIST_FILE, serialized_dev_list)

    return PLUGIN_LIST, CAT, DEVELOPER_LIST
end

function ReadFXFile()
    local fx_file = io.open(FX_FILE, "r")
    if fx_file then
        PLUGIN_LIST = {}
        local fx_string = fx_file:read("*all")
        fx_file:close()
        PLUGIN_LIST = StringToTable(fx_string)
    end

    local cat_file = io.open(FX_CAT_FILE, "r")
    if cat_file then
        CAT = {}
        local cat_string = cat_file:read("*all")
        cat_file:close()
        CAT = StringToTable(cat_string)
    end

    local dev_list_file = io.open(FX_DEV_LIST_FILE, "r")
    if dev_list_file then
        DEVELOPER_LIST = {}
        local dev_list_string = dev_list_file:read("*all")
        dev_list_file:close()
        DEVELOPER_LIST = StringToTable(dev_list_string)
    end

    return PLUGIN_LIST, CAT, DEVELOPER_LIST
end

function WriteToFile(path, data)
    local file_cat = io.open(path, "w")
    if file_cat then
        file_cat:write(data)
        file_cat:close()
    end
end

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

function Literalize(str)
    return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end)
end

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
        if file:find(filter, nil, true) then
            tbl[#tbl + 1] = file:gsub(filter, "")
        end
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
        if DEVELOPER_LIST[i] == " (" .. val .. ")" then return end
    end
    DEVELOPER_LIST[#DEVELOPER_LIST + 1] = " (" .. val .. ")"
end

local function ParseVST(name, ident)
    if not name:match("^VST") then return end

    if name:match("VST: ") then
        --name = name:gsub("%s", "", 1)
        VST[#VST + 1] = name
    elseif name:match("VSTi: ") then
        --name = name:gsub("%s", "", 1)
        VSTi[#VSTi + 1] = name
        INSTRUMENTS[#INSTRUMENTS + 1] = name
    elseif name:match("VST3: ") then
        --name = name:gsub("%s", "", 1)
        VST3[#VST3 + 1] = name
    elseif name:match("VST3i: ") then
        --name = name:gsub("%s", "", 1)
        VST3i[#VST3i + 1] = name
        INSTRUMENTS[#INSTRUMENTS + 1] = name
    end
    -- WE NEED TO EXTRACT ONLY DLL WITHOUT PATH SO REVERSE IT FOR EASIER MATCH TO FIRST "/"" AFTER DLL
    ident = os:match("Win") and ident:reverse():match("(.-)\\") or ident:reverse():match("(.-)/")
    -- NEED TO REPLACE WHITESPACES AND DASH WITH LOWER DASH ALSO (HOW ITS IN VST INI FILE)
    ident = ident:reverse():gsub(" ", "_"):gsub("-", "_")
    VST_INFO[#VST_INFO + 1] = { id = ident, name = name }
    PLUGIN_LIST[#PLUGIN_LIST + 1] = name
end

local function ParseJSFX(name, ident)
    if not name:match("^JS:") then return end
    --name                          = name:gsub("%s", "", 1)
    JS[#JS + 1]                   = name
    JS_INFO[#JS_INFO + 1]         = { id = ident, name = name }
    PLUGIN_LIST[#PLUGIN_LIST + 1] = name
end

local function ParseAU(name, ident)
    if not name:match("^AU") then return end

    if name:match("AU: ") then
        --name = name:gsub("%s", "", 1)
        AU[#AU + 1] = name
    elseif name:match("AUi: ") then
        --name = name:gsub("%s", "", 1)
        AUi[#AUi + 1] = name
        INSTRUMENTS[#INSTRUMENTS + 1] = name
    end
    AU_INFO[#AU_INFO + 1]         = { id = ident, name = name }
    PLUGIN_LIST[#PLUGIN_LIST + 1] = name
end

local function ParseCLAP(name, ident)
    if not name:match("^CLAP") then return end

    if name:match("CLAP: ") then
        --name = name:gsub("%s", "", 1)
        CLAP[#CLAP + 1] = name
    elseif name:match("CLAPi: ") then
        --name = name:gsub("%s", "", 1)
        CLAPi[#CLAPi + 1] = name
        INSTRUMENTS[#INSTRUMENTS + 1] = name
    end
    CLAP_INFO[#CLAP_INFO + 1] = { id = ident, name = name }
    PLUGIN_LIST[#PLUGIN_LIST + 1] = name
end

local function ParseLV2(name, ident)
    if not name:match("^LV2") then return end

    if name:match("LV2: ") then
        --name = name:gsub("%s", "", 1)
        LV2[#LV2 + 1] = name
    elseif name:match("LV2i: ") then
        --name = name:gsub("%s", "", 1)
        LV2i[#LV2i + 1] = name
        INSTRUMENTS[#INSTRUMENTS + 1] = name
    end
    LV2_INFO[#LV2_INFO + 1] = { id = ident, name = name }
    PLUGIN_LIST[#PLUGIN_LIST + 1] = name
end

local function ParseFXTags()
    -- PARSE CATEGORIES
    local tags_path = r.GetResourcePath() .. "/reaper-fxtags.ini"
    local tags_str  = GetFileContext(tags_path)
    local DEV       = true
    for line in tags_str:gmatch('[^\r\n]+') do
        local category = line:match("^%[(.+)%]")
        if line:match("^%[(category)%]") then
            DEV = false
        end
        -- CATEGORY FOUND
        if category then
            CAT[#CAT + 1] = { name = category:upper(), list = {} }
        end
        -- PLUGIN FOUND
        local FX, dev_category = line:match("(.+)=(.+)")
        if dev_category then
            dev_category = dev_category:gsub("[%[%]]", "")
            if DEV then AddDevList(dev_category) end
            local fx_name = FindFXIDName(VST_INFO, FX)
            fx_name = fx_name and fx_name or FindFXIDName(AU_INFO, FX)
            fx_name = fx_name and fx_name or FindFXIDName(CLAP_INFO, FX)
            fx_name = fx_name and fx_name or FindFXIDName(JS_INFO, FX, "JS")
            fx_name = fx_name and fx_name or FindFXIDName(LV2_INFO, FX)
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

local function ParseCustomCategories()
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
                fx_name = fx_name and fx_name or FindFXIDName(LV2_INFO, FX)
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

local function SortFoldersINI(fav_str)
    local folders = {}
    --local cur_folder
    local add
    for line in fav_str:gmatch('[^\r\n]+') do
        local category = line:match("%[(.-)%]")
        if category then
            if category:find("Folder", nil, true) then
                add = true
                --cur_folder = category
                folders[#folders + 1] = { name = category }
            else
                add = false
            end
        end
        if folders[#folders] and not category and add then
            folders[#folders][#folders[#folders] + 1] = line .. "\n"
        end
    end

    local main_folder
    for i = #folders, 1, -1 do
        table.sort(folders[i])
        table.insert(folders[i], 1, "[" .. folders[i].name .. "]" .. "\n")
        if folders[i].name == "Folders" then
            main_folder = table.remove(folders, i)
        end
    end
    folders[#folders + 1] = main_folder

    local sorted = ""
    for i = 1, #folders do
        folders[i].name = nil
        sorted = sorted .. table.concat(folders[i])
    end

    return sorted
end

local magic = {
    ["not"] = { ' and ', ' not %s:find("%s") ' },
    ["or"] = { ' or ', ' %s:find("%s") ' },
    ["and"] = { ' and ', '%s:find("%s") ' },
}

local function ParseSmartFolder(smart_string)
    local smart_terms = {}
    local SMART_FX = {}

    -- TAG QUOTED WORDS
    for exact in smart_string:gmatch '"(.-)"' do
        smart_string = smart_string:gsub(exact, '_schwa_magic_' .. exact:gsub(' ', '|||')) -- APPEND MAGIC WORD SO WE CAN FIND IT LATER FOR PATTERN MATCHING
    end

    smart_string = smart_string:gsub('"', '')

    -- SEPARATE FILTER BY WHITESPACE
    for term in smart_string:gmatch("([^%s]+)") do
        term = term:lower():gsub('[%(%)%.%+%-%*%?%[%]%^%$%%]', '%%%1')
        -- TAGGED QUOTED STRING FOUND
        if term:find('_schwa_magic_') then
            term = term:gsub('_schwa_magic_', '')
            if term:find('|||') then
                -- exact match multiple words as single pattern
                term = '(' .. term:gsub('|||', ' ') .. ')'
            else
                -- exact match single word
                term = '%A' .. term .. '%A'
            end
            -- EXCLUDE MAGIC TAGS AND APPED PATTERN FOR EXACT MATCH
            --term = '%A' .. term:gsub('_schwa_magic_',''):gsub('|||',' ') .. '%A'
        end
        smart_terms[#smart_terms + 1] = term
    end

    local code_gen = { "for i = 1, #PLUGIN_LIST do\nlocal target = PLUGIN_LIST[i]:lower()", "" }

    local add_magic
    for i = 1, #smart_terms do
        if magic[smart_terms[i]] then
            add_magic = i > 1 and (magic[smart_terms[i]][1] .. magic[smart_terms[i]][2]) or magic[smart_terms[i]][2]
        else
            if add_magic then
                code_gen[2] = code_gen[2] .. add_magic:format("target", smart_terms[i])
                add_magic = nil
            else
                code_gen[2] = i > 1 and code_gen[2] .. " and " .. (' %s:find("%s")'):format("target", smart_terms[i]) or
                    code_gen[2] .. (' %s:find("%s")'):format("target", smart_terms[i])
            end
        end
    end

    code_gen[2] = 'if ' .. code_gen[2] .. ' then'
    code_gen[#code_gen + 1] = 'SMART_FX[#SMART_FX+1] = PLUGIN_LIST[i]\nend\nend\n'

    local code_str = table.concat(code_gen, "\n")

    local func_env = {
        SMART_FX = SMART_FX,
        PLUGIN_LIST = PLUGIN_LIST,
        string = string,
    }

    local func, err = load(code_str, "ScriptRun", "t", func_env)

    if func then
        local status, err2 = pcall(func)
        if err2 then
            r.ShowConsoleMsg("ERROR RUNNING SMART FOLDER CODE GEN : \n" .. err2)
        end
    end
    return SMART_FX
end

local function ParseFavorites()
    -- PARSE FAVORITES FOLDER
    local fav_path = r.GetResourcePath() .. "/reaper-fxfolders.ini"
    local fav_str  = GetFileContext(fav_path)

    fav_str        = SortFoldersINI(fav_str)

    CAT[#CAT + 1]  = { name = "FOLDERS", list = {} }

    local current_folder
    for line in fav_str:gmatch('[^\r\n]+') do
        local folder = line:match("^%[(Folder%d+)%]")

        -- GET INITIAL FOLDER NAME "[Folder0]" AND SAVE IF
        if folder then current_folder = folder end

        -- GET FOLDER ITEMS "Item0=..."
        if line:match("Item%d+") then
            local item = "R_ITEM_" .. line:match("Item%d+=(.+)")
            local dev_tbl = InTbl(CAT[#CAT].list, current_folder)
            if not dev_tbl then
                table.insert(CAT[#CAT].list,
                    { name = current_folder, fx = { item }, order = current_folder:match("Folder(%d+)") })
            else
                table.insert(dev_tbl, item)
            end
        end

        -- RENAME ITEMS BY TYPE TO REAL NAMES "Type0=2"
        -- 3 = VST, 2 = JS, 7 = CLAP, 1 = LV2
        if line:match("Type%d+") then
            local line_id, fx_type = line:match("(%d+)=(%d+)")
            if fx_type == "3" then -- VST
                local folder_item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                if folder_item then
                    local item = folder_item:gsub("R_ITEM_", "", 1)
                    if item then
                        local id = os:match("Win") and item:reverse():match("(.-)\\") or item:reverse():match("(.-)/")
                        if id then
                            -- NEED TO REPLACE WHITESPACES AND DASH WITH LOWER DASH ALSO (HOW ITS IN VST INI FILE)
                            id = id:reverse():gsub(" ", "_"):gsub("-", "_")
                            local fx_found = FindFXIDName(VST_INFO, id)
                            if fx_found then
                                table.insert(CAT[#CAT].list[#CAT[#CAT].list].fx, fx_found)
                            end
                        end
                    end
                end
            elseif fx_type == "2" then --JSFX
                local folder_item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                if folder_item then
                    local item = folder_item:gsub("R_ITEM_", "", 1)
                    local fx_found = FindFXIDName(JS_INFO, item)
                    if fx_found then
                        table.insert(CAT[#CAT].list[#CAT[#CAT].list].fx, fx_found)
                    end
                end
            elseif fx_type == "7" then -- CLAP
                local folder_item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                if folder_item then
                    local item = folder_item:gsub("R_ITEM_", "", 1)
                    local fx_found = FindFXIDName(CLAP_INFO, item)
                    if fx_found then
                        table.insert(CAT[#CAT].list[#CAT[#CAT].list].fx, fx_found)
                    end
                end
            elseif fx_type == "1" then -- LV2
                local folder_item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                if folder_item then
                    local item = folder_item:gsub("R_ITEM_", "", 1)
                    local fx_found = FindFXIDName(LV2_INFO, item)
                    if fx_found then
                        table.insert(CAT[#CAT].list[#CAT[#CAT].list].fx, fx_found)
                    end
                end
            elseif fx_type == "5" then -- AU
                local folder_item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                if folder_item then
                    local item = folder_item:gsub("R_ITEM_", "", 1)
                    local fx_found = FindFXIDName(AU_INFO, item)
                    if fx_found then
                        table.insert(CAT[#CAT].list[#CAT[#CAT].list].fx, fx_found)
                    end
                end
            elseif fx_type == "1048576" then -- SMART FOLDER
                local folder_item = CAT[#CAT].list[#CAT[#CAT].list].fx[line_id + 1]
                CAT[#CAT].list[#CAT[#CAT].list].smart = true
                CAT[#CAT].list[#CAT[#CAT].list].fx = ParseSmartFolder(folder_item:gsub("R_ITEM_", "", 1))
                --CAT[#CAT].list[#CAT[#CAT].list].filter = folder_item:gsub("R_ITEM_", "", 1)
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

    table.sort(CAT[#CAT].list, function(a, b) return tonumber(a.order) < tonumber(b.order) end)

    -- REMOVE SMART FOLDERS FOR NOW
    for i = 1, #CAT do
        for j = #CAT[i].list, 1, -1 do
            --if CAT[i].list[j].smart then table.remove(CAT[i].list, j) end
            if CAT[i].list[j] then
                for f = #CAT[i].list[j].fx, 1, -1 do
                    if CAT[i].list[j].fx[f]:find("R_ITEM_") then
                        table.remove(CAT[i].list[j].fx, f)
                    end
                end
            end
        end
    end
end

local function ParseFXChains()
    local fxChainsFolder = r.GetResourcePath() .. "/FXChains"
    local FX_CHAINS = {}
    GetDirFilesRecursive(fxChainsFolder, FX_CHAINS, ".RfxChain")
    if #FX_CHAINS ~= 0 then
        --table.sort(FX_CHAINS, function(a, b) if a and b then return a:lower() < b:lower() end end)
        --CAT[#CAT + 1] = { name = "FX CHAINS", list = FX_CHAINS }
    end
    return FX_CHAINS
end

local function ParseTrackTemplates()
    local trackTemplatesFolder = r.GetResourcePath() .. "/TrackTemplates"
    local TRACK_TEMPLATES = {}
    GetDirFilesRecursive(trackTemplatesFolder, TRACK_TEMPLATES, ".RTrackTemplate")
    -- if #TRACK_TEMPLATES ~= 0 then
    --     --table.sort(FX_CHAINS, function(a, b) if a and b then return a:lower() < b:lower() end end)
    --     CAT[#CAT + 1] = { name = "TRACK TEMPLATES", list = TRACK_TEMPLATES }
    -- end
    return TRACK_TEMPLATES
end

local function AllPluginsCategory()
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
    if #LV2 ~= 0 then table.insert(CAT[#CAT].list, { name = "LV2", fx = LV2 }) end
    if #LV2i ~= 0 then table.insert(CAT[#CAT].list, { name = "LV2i", fx = LV2i }) end
    if #INSTRUMENTS ~= 0 then table.insert(CAT[#CAT].list, { name = "INSTRUMENTS", fx = INSTRUMENTS }) end

    -- SORT EVERYTHING ALPHABETICALLY
    for i = 1, #CAT do
        -- DONT SORT THERE CATEGORIES, LEAVE THEM AS IN FOLDER (CHAINS/TEMPLATES) OR AS CREATED BY USER (FAVORITES)
        if CAT[i].name ~= "FOLDERS" and CAT[i].name ~= "FX CHAINS" and CAT[i].name ~= "TRACK TEMPLATES" then
            table.sort(CAT[i].list,
                function(a, b) if a.name and b.name then return a.name:lower() < b.name:lower() end end)
        end
        for j = 1, #CAT[i].list do
            if CAT[i].list[j].fx then
                table.sort(CAT[i].list[j].fx, function(a, b) if a and b then return a:lower() < b:lower() end end)
            end
        end
    end

    table.sort(CAT, function(a, b) if a.name and b.name then return a.name:lower() < b.name:lower() end end)
end

function GenerateFxList()
    PLUGIN_LIST[#PLUGIN_LIST + 1] = "Container"
    PLUGIN_LIST[#PLUGIN_LIST + 1] = "Video processor"

    for i = 0, math.huge do
        local retval, name, ident = r.EnumInstalledFX(i)
        if not retval then break end
        ParseVST(name, ident)
        ParseJSFX(name, ident)
        ParseAU(name, ident)
        ParseCLAP(name, ident)
        ParseLV2(name, ident)
    end

    ParseFXTags() -- CATEGORIES
    ParseCustomCategories()
    ParseFavorites()
    local FX_CHAINS = ParseFXChains()
    if #FX_CHAINS ~= 0 then
        CAT[#CAT + 1] = { name = "FX CHAINS", list = FX_CHAINS }
    end
    local TRACK_TEMPLATES = ParseTrackTemplates()
    if #TRACK_TEMPLATES ~= 0 then
        CAT[#CAT + 1] = { name = "TRACK TEMPLATES", list = TRACK_TEMPLATES }
    end
    AllPluginsCategory()

    return PLUGIN_LIST
end

local sub = string.sub
function Stripname(name, prefix, suffix)
    if not DEVELOPER_LIST then return name end
    -- REMOVE DEVELOPER
    if suffix then
        for i = 1, #DEVELOPER_LIST do
            local ss, se = name:find(DEVELOPER_LIST[i], nil, true)
            if ss then
                name = sub(name, 0, ss)
                break
            end
        end
    end
    -- REMOVE VST: JS: AU: CLAP:
    if prefix then
        local ps, pe = name:find("(%S+: )")
        if ps then
            name = sub(name, pe)
        end
    end
    return name
end

function GetFXTbl()
    ResetTables()
    return GenerateFxList(), CAT, DEVELOPER_LIST
end

function UpdateChainsTrackTemplates(cat_tbl)
    if not cat_tbl then return end
    local FX_CHAINS = ParseFXChains()
    local TRACK_TEMPLATES = ParseTrackTemplates()
    local chain_found, template_found
    for i = 1, #cat_tbl do
        if cat_tbl[i].name == "FX CHAINS" then
            cat_tbl[i].list = FX_CHAINS
            chain_found = true
        end
        if cat_tbl[i].name == "TRACK TEMPLATES" then
            cat_tbl[i].list = TRACK_TEMPLATES
            template_found = true
        end
    end
    if not chain_found then
        cat_tbl[#cat_tbl + 1] = { name = "FX CHAINS", list = FX_CHAINS }
    end
    if not template_found then
        cat_tbl[#cat_tbl + 1] = { name = "TRACK TEMPLATES", list = TRACK_TEMPLATES }
    end
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

-- -- USE ONLY NON CHACHING OR CACHING! NOT BOTH AT THE SAME TIME

-- --NON CACHING -- USE IF YOU WANT RESCAN ON EVERY SCRIPT STARTUP
-- --local FX_LIST_TEST, CAT_TEST = GetFXTbl()

-- --CACHIN TO FILE - USE IF YOU WANT TO SCAN ONLY ONCE THEN USE THAT TXT FILE FOR FASTER LOADS
-- local FX_LIST_TEST, CAT_TEST = ReadFXFile()
-- if not FX_LIST_TEST or not CAT_TEST then
--     FX_LIST_TEST, CAT_TEST = MakeFXFiles()
-- end
-- --CACHIN TO FILE

-- local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

-- local tsort = table.sort
-- function SortTable(tab, val1, val2)
--     tsort(tab, function(a, b)
--         if (a[val1] < b[val1]) then
--             -- primary sort on position -> a before b
--             return true
--         elseif (a[val1] > b[val1]) then
--             -- primary sort on position -> b before a
--             return false
--         else
--             -- primary sort tied, resolve w secondary sort on rank
--             return a[val2] < b[val2]
--         end
--     end)
-- end

-- local old_t = {}
-- local old_filter = ""
-- local function Filter_actions(filter_text)
--     if old_filter == filter_text then return old_t end
--     filter_text = Lead_Trim_ws(filter_text)
--     local t = {}
--     if filter_text == "" or not filter_text then return t end
--     for i = 1, #FX_LIST_TEST do
--         local name = FX_LIST_TEST[i]:lower() --:gsub("(%S+:)", "")
--         local found = true
--         for word in filter_text:gmatch("%S+") do
--             if not name:find(word:lower(), 1, true) then
--                 found = false
--                 break
--             end
--         end
--         if found then t[#t + 1] = { score = FX_LIST_TEST[i]:len() - filter_text:len(), name = FX_LIST_TEST[i] } end
--     end
--     if #t >= 2 then
--         SortTable(t, "score", "name") -- Sort by key priority
--     end
--     old_t = t
--     old_filter = filter_text
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
--                 if r.ImGui_Selectable(ctx, filtered_fx[i].name, i == ADDFX_Sel_Entry) then
--                     r.TrackFX_AddByName(TRACK, filtered_fx[i].name, false, -1000 - r.TrackFX_GetCount(TRACK))
--                     r.ImGui_CloseCurrentPopup(ctx)
--                     LAST_USED_FX = filtered_fx[i].name
--                 end
--             end
--             r.ImGui_EndChild(ctx)
--         end
--         if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
--             r.TrackFX_AddByName(TRACK, filtered_fx[ADDFX_Sel_Entry].name, false, -1000 - r.TrackFX_GetCount(TRACK))
--             LAST_USED_FX = filtered_fx[filtered_fx[ADDFX_Sel_Entry].name]
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
--         r.SetTrackStateChunk(TRACK, chunk, true)
--     else
--         r.Main_openProject(track_template_path)
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
--                     LoadTemplate(template_str)       -- ADD NEW TRACK FROM TEMPLATE
--                     LoadTemplate(template_str, true) -- REPLACE CURRENT TRACK WITH TEMPLATE
--                 end
--             end
--         end
--     end
-- end

-- local function DrawItems(tbl, main_cat_name)
--     for i = 1, #tbl do
--         if r.ImGui_BeginMenu(ctx, tbl[i].name) then--
--             for j = 1, #tbl[i].fx do
--                 if tbl[i].fx[j] then
--                     local name = tbl[i].fx[j]
--                     if main_cat_name == "ALL PLUGINS" and tbl[i].name ~= "INSTRUMENTS" then
--                         -- STRIP PREFIX IN "ALL PLUGINS" CATEGORIES EXCEPT INSTRUMENT WHERE THERE CAN BE MIXED ONES
--                         name = name:gsub("^(%S+:)", "")
--                     elseif main_cat_name == "DEVELOPER" then
--                         -- STRIP SUFFIX (DEVELOPER) FROM THESE CATEGORIES
--                         name = name:gsub(' %(' .. Literalize(tbl[i].name) .. '%)', "")
--                     end
--                     if r.ImGui_Selectable(ctx, name) then
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
--     for i = 1, #CAT_TEST do
--         if r.ImGui_BeginMenu(ctx, CAT_TEST[i].name) then
--             if CAT_TEST[i].name == "FX CHAINS" then
--                 DrawFxChains(CAT_TEST[i].list)
--             elseif CAT_TEST[i].name == "TRACK TEMPLATES" then
--                 DrawTrackTemplates(CAT_TEST[i].list)
--             else
--                 DrawItems(CAT_TEST[i].list, CAT_TEST[i].name)
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
--             --UPDATE FX CHAINS (WE DONT NEED TO RESCAN EVERYTHING IF NEW CHAIN WAS CREATED BY SCRIPT)
--             if WANT_REFRESH then
--                 WANT_REFRESH = nil
--                 UpdateChainsTrackTemplates(CAT)
--             end
--             -- RESCAN FILE LIST
--             if r.ImGui_Button(ctx, "RESCAN PLUGIN LIST") then
--                 FX_LIST_TEST, CAT_TEST = MakeFXFiles()
--             end
--             Frame()
--         else
--             reaper.ImGui_Text(ctx, "SELECT TRACK")
--         end
--         r.ImGui_End(ctx)
--     end
--     if open then
--         r.defer(Main)
--     end
-- end

-- r.defer(Main)
