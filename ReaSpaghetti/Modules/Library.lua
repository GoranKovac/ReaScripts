--@noindex
--NoIndex: true
local r = reaper

local lib_path = PATH .. "Library"

local LIBRARY = {}

function InitLibrary()
    LIBRARY = {}
    for index = 0, math.huge do
        local lib_file = r.EnumerateFiles(lib_path, index)
        if not lib_file then break end
        local file = io.open(lib_path .. NATIVE_SEPARATOR .. lib_file, "r")
        if file then
            local string = file:read("*all")
            local store_function = StringToTable(string)
            if store_function ~= nil then
                LIBRARY[#LIBRARY + 1] = store_function
            end
            file:close()
        end
    end
end

function GetLibrary()
    return LIBRARY
end

function ExportFunction(id)
    local FUNCTIONS = GetFUNCTIONS()
    local function_to_export = FUNCTIONS[id]
    local serialized = TableToString(function_to_export)
    local save_path = PATH .. "Library" .. NATIVE_SEPARATOR .. function_to_export.label .. ".reanlib"

    local file = io.open(save_path, "w")
    if file then
        file:write(serialized)
        file:close()
    end
end
