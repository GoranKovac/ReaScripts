--[[
 * ReaScript Name: Multi project time counter
 * Discription: Script shows 3 timers: Windows time, how long project has been opened and third timer has AFK mode that that counts time only while you work in the project
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.1
--]]
 
--[[
 * Changelog:
 * v1.1 (2017-08-13)
  + Initial release
--]]

---------------------------------------
local afk = 60 -- set afk treshold HERE
---------------------------------------
local threshold = afk
local last_time = 0
local last_action_time = 0
local last_proj_change_count = reaper.GetProjectStateChangeCount(0)

function store_time() -- store time values to project
  reaper.SetProjExtState(0, "timer", "timer", timer) -- store seconds
  reaper.SetProjExtState(0, "timer", "timer2", timer2) -- store seconds
end

function restore_time() -- restore time values from project
  local ret, load_timer = reaper.GetProjExtState(0, "timer", "timer") -- restore seconds
  local ret, load_timer2 = reaper.GetProjExtState(0, "timer", "timer2") -- restore seconds
    if load_timer ~= "" then
      timer = load_timer
    else
      timer = 0
    end
    
    if load_timer2 ~= "" then
      timer2 = load_timer2
    else
      timer2 = 0
    end
    
end
function proj_time()
  if os.time() - last_time > 0 then
    timer2 = timer2 + 1
    last_time = os.time()
    store_time()
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
  proj_time()
  local w_timer = os.time()
  
  local proj_change_count = reaper.GetProjectStateChangeCount(0)
  if proj_change_count > last_proj_change_count or reaper.GetPlayState() ~= 0 then
    afk = 0
    last_proj_change_count = proj_change_count
  end
 
  if afk < threshold then
    count_time()
  end
  
  local days,p_days = math.floor(timer/(60*60*24)),math.floor(timer2/(60*60*24))
  local hours, w_hours, p_hours = math.floor(timer/(60*60)%24), math.floor(w_timer/(60*60)%24), math.floor(timer2/(60*60)%24)
  local minutes, w_minutes, p_minutes = math.floor(timer/60%60), math.floor(w_timer/60%60), math.floor(timer2/60%60)
  local seconds, w_seconds, p_seconds = math.floor(timer%60), math.floor(w_timer%60), math.floor(timer2%60)
      
  local format = string.format("%02d:%02d:%02d:%02d",days,hours,minutes,seconds)
  local p_format = string.format("%02d:%02d:%02d:%02d",p_days,p_hours,p_minutes,p_seconds)
  local w_format = string.format("%02d:%02d:%02d",w_hours,w_minutes,w_seconds)
 
  gfx.x, gfx.y = 2, 8
  gfx.printf(w_format)
  gfx.x, gfx.y = 2, 38
  gfx.printf(p_format)
  gfx.x, gfx.y = 2, 68
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
  
  gfx.init("", 120, 100, dock_pos)
  gfx.setfont(1,"Arial", 24)
  gfx.clear = 3355443 
  main()   
end
restore_time() -- call function restore_time() to restore time values from project
init()
reaper.atexit(store_settings)
