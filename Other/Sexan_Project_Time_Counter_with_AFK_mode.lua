--[[
 * ReaScript Name: Project Time Counter with AFK mode
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.3
--]]
 
--[[
 * Changelog:
 * v1.3 (2017-02-25)
  + Simplified the code
--]]

---------------------------------------
local afk = 60 -- set afk treshold HERE
---------------------------------------
local threshold = afk

local last_action_time = 0
local last_proj_change_count = reaper.GetProjectStateChangeCount(0)

function store_time() -- store time values to project
  reaper.SetProjExtState(0, "timer", "timer", timer) -- store seconds
end

function restore_time() -- restore time values from project
  local ret, load_timer = reaper.GetProjExtState(0, "timer", "timer") -- restore seconds
    if load_timer ~= "" then
      timer = load_timer
    else
      timer = 0
    end
end

function count_time()
  if os.time() - last_action_time > 0 then -- interval of 1 second      
    afk = afk + 1
    timer = timer + 1      
    last_action_time = os.time() 
  end  
  store_time()
end
 
function main()
  restore_time()
  
  local proj_change_count = reaper.GetProjectStateChangeCount(0)
  if proj_change_count > last_proj_change_count or reaper.GetPlayState() ~= 0 then
    afk = 0
    last_proj_change_count = proj_change_count
  end
 
  if afk < threshold then
    count_time()
  end
  
  local days = math.floor(timer/(60*60*24))
  local hours = math.floor(timer/(60*60)%24)
  local minutes = math.floor(timer/60%60)
  local seconds = math.floor(timer%60)
      
  local format = string.format("%02d:%02d:%02d:%02d",days,hours,minutes,seconds)
 
  gfx.x, gfx.y = 2, 15
  gfx.printf(format)
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
  local dock_pos = reaper.GetExtState("time", "dock")
  dock_pos = dock_pos or 513
  
  gfx.init("", 120, 50, dock_pos)
  gfx.setfont(1,"Arial", 24)
  gfx.clear = 3355443 
  main()   
end
restore_time() -- call function restore_time() to restore time values from project
init()
reaper.atexit(store_settings)
