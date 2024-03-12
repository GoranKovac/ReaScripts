--@noindex
--NoIndex: true

local getinfo = debug.getinfo(1, 'S');
local script_path = getinfo.source:match [[^@?(.*[\/])[^\/]-$]];
package.path = script_path .. "?.lua;" -- GET DIRECTORY FOR REQUIRE

local pie_file = script_path .. "pie_file.txt"
local menu_file = script_path .. "menu_file.txt"

rv = reaper.ShowMessageBox( "Delete Pie script data?", "WARNING", 1 )

if rv == 1 then
    os.remove(pie_file)
    os.remove(menu_file)
end