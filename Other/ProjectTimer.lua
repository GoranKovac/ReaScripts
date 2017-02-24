--[[
 * ReaScript Name: Project Time Counter with AFK mode
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.1 (2017-02-24)
  + improve code and save dock position
--]]

---------------------------------------
local afk = 59 -- set afk treshold HERE
---------------------------------------

local last_proj_change_count = reaper.GetProjectStateChangeCount(0)
local last_action_time = 0 -- initial action time
local sec,min,hour,day,cnt

function store_time() -- store time values to project
  local save_time = sec .. ",".. min .. ",".. hour .. ",".. day
  reaper.SetProjExtState(0, "time", "global", save_time) -- store seconds
end

function restore_time() -- restore time values from project
  local ret, load_time = reaper.GetProjExtState(0, "time", "global") -- restore seconds
 
  if load_time ~= "" then
    sec, min, hour, day = string.match(load_time, "([^,]+),([^,]+),([^,]+),([^,]+)")
  else
    sec, min, hour, day = 0, 0, 0, 0 
  end 
  
end

function count_time()
  if cnt <= afk then

    if os.time() - last_action_time > 0 then -- interval of 1 second
      cnt = cnt + 1
      
      sec = sec + 1
      if sec == 60 then
        min = min + 1 
        sec = 0                      
        
      if min == 60 then
        hour = hour + 1
        min = 0
          
      if hour == 24 then
        day = day + 1
        hour = 0          
      end
          
      end
        
      end
      
    last_action_time = os.time() 
    end
  
  else
  cnt = nil 
  end
    
store_time() -- call function to store time values
end
 
function main()
restore_time()
  
local play_state = reaper.GetPlayState() -- get transport state
local recording = play_state == 5 -- is record button on
local playing = play_state == 1 -- is play button on
 
  local proj_change_count = reaper.GetProjectStateChangeCount(0)
  if proj_change_count > last_proj_change_count or recording or playing then -- if project state changed or transport is in play or record mode
    cnt = 0
    last_proj_change_count = proj_change_count -- store "Project State Change Count" for the next pass 
  end
 
  if cnt then
    count_time()
  end
 
-- DRAW GUI --  
     gfx.x = 2
     gfx.y = 15      
     gfx.printf("")     
     gfx.printf("%02d",math.floor(day))
     gfx.printf(":")
     gfx.printf("%02d",math.floor(hour))
     gfx.printf(":")
     gfx.printf("%02d",math.floor(min)) 
     gfx.printf(":")
     gfx.printf("%02d",math.floor(sec))     
       
     gfx.update()

  if gfx.getchar() > -1 then  -- defer while gfx window is open
     reaper.defer(main)
  else
    
  end
end

function store_settings()
  -- save dock position
  reaper.SetExtState("time", "dock", gfx.dock(-1), true)
  -- save current time
  store_time()
end

function init()
  local dock_pos = reaper.GetExtState("time", "dock")
  dock_pos = dock_pos or 0
  
  gfx.init("", 0, 30, dock_pos)
  gfx.setfont(1,"Arial", 24)
  gfx.clear = 3355443 
  main()   
end
restore_time() -- call function restore_time() to restore time values from project
init()
reaper.atexit(store_settings)
