--[[
 * ReaScript Name: Project Time Counter with AFK mode
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.37
--]]
 
--[[
 * Changelog:
 * v1.37 (2017-08-14)
  + code improvement
--]]

---------------------------------------
local afk = 60 -- set afk treshold HERE
---------------------------------------
local threshold = afk

local last_action_time = 0
local last_proj_change_count = reaper.GetProjectStateChangeCount(0)
local last_proj, last_proj_name =  reaper.EnumProjects( -1 , 0) 
local dock_pos = reaper.GetExtState("timer", "dock")

function store_time() -- store time values to project
  reaper.SetProjExtState(0, "timer", "timer", timer) -- store seconds
end

function restore_time() -- restore time values from project
  local ret, load_timer = reaper.GetProjExtState(0, "timer", "timer") -- restore seconds
    if load_timer ~= "" then
      timer =  tonumber(load_timer)
    else
      timer = 0
    end
end

function count_time()
  if afk < threshold then
    if os.time() - last_action_time > 0 then -- interval of 1 second      
      afk = afk + 1
      timer = timer + 1      
      last_action_time = os.time() 
    end
  end  
  store_time()
end

function time()
  local days = math.floor(timer/(60*60*24))
  local hours = math.floor(timer/(60*60)%24)
  local minutes = math.floor(timer/60%60)
  local seconds = math.floor(timer%60)
      
  local format = string.format("%02d:%02d:%02d:%02d",days,hours,minutes,seconds)
  return format
end
 
function main() 
  local proj, proj_name =  reaper.EnumProjects( -1 , 0) 
  local proj_change_count = reaper.GetProjectStateChangeCount(0)
  
  if last_proj ~= proj then
    restore_time()
    last_proj = proj
  end
  
  if proj_change_count > last_proj_change_count or reaper.GetPlayState() ~= 0 then
    afk = 0
    last_proj_change_count = proj_change_count
  end
  
  count_time()
  
  gfx.x, gfx.y = 2, 15
  gfx.printf(time())
  gfx.update()

  if gfx.getchar() > -1 then  -- defer while gfx window is open
     reaper.defer(main)
  else
    
  end
end

function store_settings()
  reaper.SetExtState("timer", "dock", gfx.dock(-1), true)
  store_time()
end

function init()
  dock_pos = dock_pos or 513
  
  gfx.init("", 120, 50, dock_pos)
  gfx.setfont(1,"Arial", 24)
  gfx.clear = 3355443 
  main()   
end
restore_time() -- call function restore_time() to restore time values from project
init()
reaper.atexit(store_settings)
