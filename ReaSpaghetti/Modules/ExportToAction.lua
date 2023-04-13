local r = reaper
function ExportTest(name, proj_path)
    local lua_string = {}
    lua_string[1] =
    'package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\\/])[^\\/]-$]] .. "?.lua;"'
    lua_string[2] = 'STANDALONE_RUN = true'
    lua_string[3] = 'require("Sexan_ReaSpaghetti")'
    lua_string[4] = 'local func_file = "' .. proj_path:gsub("\\", "/") .. name:gsub("\\", "/") .. '"'
    lua_string[5] = 'local file = io.open(func_file, "r")'
    lua_string[6] = 'if file then'
    lua_string[7] = '   local string = file:read("*all")'
    lua_string[8] = '    RestoreNodes(string)'
    lua_string[9] = '    file:close()'
    lua_string[10] = 'end'
    lua_string[11] = 'InitRunFlow()'

    local path = PATH .. "ReaSpaghetti_StandAlone_" .. name:gsub(".reanodes", "") .. ".lua"
    local file = io.open(path, "w")
    if file then
        file:write(table.concat(lua_string, "\n"))
        file:close()
        --reaper.AddRemoveReaScript(true, integer sectionID, lua_string, true)
        local ret = r.AddRemoveReaScript(true, 0, path, 1)
        if ret then
            ADDED_TO_ACTIONS = true
        end
    end
end
