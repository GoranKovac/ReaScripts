local info = debug.getinfo(1, 'S');
local script_path = info.source:match [[^@?(.*[\/])[^\/]-$]];
package.cpath = package.cpath .. ";" .. script_path .. "/Modules/?.dll" -- Add current folder/socket module for looking at .dll (need for loading basic luasocket)
package.cpath = package.cpath .. ";" .. script_path .. "/Modules/?.so" -- Add current folder/socket module for looking at .so (need for loading basic luasocket)
package.path = package.path .. ";" .. script_path .. "/Modules/?.lua"  -- Add current folder/socket module for looking at sockets.

-- INSTALL VSCODE EXSTENSION
-- https://marketplace.visualstudio.com/items?itemName=AlexeyMelnichuk.lua-mobdebug

-- .vscode/launch.json
-- {
--     // Use IntelliSense to learn about possible attributes.
--     // Hover to view descriptions of existing attributes.
--     // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
--     "version": "0.2.0",
--     "configurations": [
--         {
--             "name": "Lua MobDebug: Listen",
--             "type": "luaMobDebug",
--             "request": "attach",
--             "workingDirectory": "${workspaceFolder}",
--             "sourceBasePath": "${workspaceFolder}",
--             "listenPublicly": false,
--             "listenPort": 8172,
--             "stopOnEntry": false,
--             "sourceEncoding": "UTF-8"
--         }
--     ]
-- }


-- .vscode/tasks.json
-- {   
--     "version": "2.0.0",
--     "tasks": [
--         {
--             "label": "Run Reaper Script",
--             "type": "shell",
--             "command": "C:/REAPER/reaper.exe",
--             "args": [
--                 "-nonewinst",
--                 "${file}"
--             ],
--             "problemMatcher": [],
--             "presentation": {
--                 "reveal": "never"
--             }
--         {
--             "label": "Debug Script",
--             "command": "${command:workbench.action.debug.start}"
--         },
--         {
--             "label": "Debug and Run",
--             "dependsOrder": "parallel",
--             "dependsOn": [
--                 "Debug Script",
--                 "Run Reaper Script"
--             ],
--             "problemMatcher": []
--         }
--     ]
-- }

DEBUG = require("mobdebug")

DEBUG.defer = function(func)
    reaper.defer(function() xpcall(func, DEBUG.crash) end)
end

DEBUG.start()
