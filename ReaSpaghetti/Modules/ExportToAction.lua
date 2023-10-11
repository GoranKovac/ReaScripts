--@noindex
--NoIndex: true

local r = reaper
function ExportTest(name, proj_path, is_defer)
    name = name:match(".%reanodes") and name or name .. ".reanodes"
    local lua_string = {}

    table.insert(lua_string, 'package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\\/])[^\\/]-$]] .. "../?.lua;"')
    table.insert(lua_string, 'STANDALONE_RUN = true')
    if is_defer then
        table.insert(lua_string, 'DEFER = true')
    end
    table.insert(lua_string, 'require("Sexan_ReaSpaghetti")')
    table.insert(lua_string, 'local func_file = "' .. proj_path:gsub("\\", "/") .. name:gsub("\\", "/") .. '"')
    table.insert(lua_string, 'local file = io.open(func_file, "r")')
    table.insert(lua_string, 'if file then')
    table.insert(lua_string, '   local string = file:read("*all")')
    table.insert(lua_string, '    RestoreNodes(string)')
    table.insert(lua_string, '    file:close()')
    table.insert(lua_string, 'end')

    table.insert(lua_string, 'local function Main()')

    table.insert(lua_string, 'InitRunFlow()')
    if is_defer then
        table.insert(lua_string, 'if DEFERED_NODE and DEFER then reaper.defer(Main) end')
    end
    table.insert(lua_string, 'end')
    table.insert(lua_string, 'local function Exit()')
    if is_defer then
        table.insert(lua_string, 'DEFER = nil')
    end
    table.insert(lua_string, 'end')
    table.insert(lua_string, 'reaper.atexit(Exit)')
    if is_defer then
        table.insert(lua_string, 'reaper.defer(Main)')
    else
        table.insert(lua_string, 'Main()')
    end

    local path = PATH .. "ExportedActions/ReaSpaghetti_StandAlone_" .. name:gsub(".reanodes", "") .. ".lua"
    local file = io.open(path, "w")
    if file then
        file:write(table.concat(lua_string, "\n"))
        file:close()
        local ret = r.AddRemoveReaScript(true, 0, path, 1)
        if ret then
            ADDED_TO_ACTIONS = true
        end
    end
end
