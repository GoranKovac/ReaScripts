function msg(m)
  return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end
-----------------
-- Mouse table --
-----------------

local mouse = {  
                -- Constants
                LB    = 1,
                RB    = 2,
                Ctrl  = function() return reaper.JS_Mouse_GetState(95)  &4 == 4  end,
                Shift = function() return reaper.JS_Mouse_GetState(95)  &8 == 8  end,
                Alt   = function() return reaper.JS_Mouse_GetState(95) &16 == 16 end,
                
                -- "cap" function
                cap = function (mask)
                        if mask == nil then 
                          return reaper.JS_Mouse_GetState(95) end
                        return reaper.JS_Mouse_GetState(95)&mask == mask
                      end, 
                
                lb_down = function() return reaper.JS_Mouse_GetState(95) &1 == 1 end,
                rb_down = function() return reaper.JS_Mouse_GetState(95) &2 == 2 end,
                
                uptime = 0,
                
                last_x = -1, last_y = -1,
                dx = 0, dy = 0,
                ox = 0, oy = 0, 
                p = 0,
                tr = nil,
                r_t = 0, r_b = 0,
                x = 0, y = 0,
                otr = nil, 
                ort = 0, orb = 0,
                op = 0,
                
                
                last_LMB_state = false,
                last_RMB_state = false,
                
                l_click = false,
                r_click = false,
                l_dclick = false,
                l_up = false,
                r_up = false,
                l_down = false,
                r_down = false
              }
        
function OnMouseDown(lmb_down, rmb_down)
  if not rmb_down and lmb_down and mouse.last_LMB_state == false then
    mouse.last_LMB_state = true
    mouse.l_click = true
  end
  if not lmb_down and rmb_down and mouse.last_RMB_state == false then
    mouse.last_RMB_state = true
    mouse.r_click = true
  end
  mouse.ox, mouse.oy = mouse.x, mouse.y -- mouse click coordinates
  mouse.ort, mouse.orb, mouse.otr = mouse.r_t, mouse.r_b, mouse.tr
  mouse.op = mouse.p
  mouse.cap_count = 0       -- reset mouse capture count
end


function OnMouseUp(lmb_down, rmb_down)
  mouse.uptime = os.clock()
  mouse.dx = 0
  mouse.dy = 0
  if not lmb_down and mouse.last_LMB_state then mouse.last_LMB_state = false mouse.l_up = true end
  if not rmb_down and mouse.last_RMB_state then mouse.last_RMB_state = false mouse.r_up = true end
end

function OnMouseDoubleClick()
  mouse.l_dclick = true
end

function OnMouseHold(lmb_down, rmb_down)
    mouse.l_down = lmb_down and true
    mouse.r_down = rmb_down and true
    mouse.dx = mouse.x - mouse.ox
    mouse.dy = mouse.y - mouse.oy
    
    mouse.last_x, mouse.last_y = mouse.x, mouse.y
end

--------------------------------------
--Functions related to this example --
--------------------------------------

-- Draw values from "mouse table"
function draw_sorted_table(orig_table, sorted_table)
  local st = sorted_table
  local t = orig_table
  
  for i,n in ipairs(st) do
    gfx.set(0.8,0.8,0.8,0.8)
    if type(t[st[i]]) ~= "function" then
      if i < 6 then
        gfx.x = 10 --end
        if mouse.cap(t[st[i]]) then -- get currently pressed btn/modifier
          gfx.set(0.8,0.1,0.1,1)    -- set red color
        end
      end
      gfx.printf("mouse."..tostring(n)..":\t  ") -- print key
      --end
      gfx.set(0.8,1,1,1)
      gfx.printf(tostring(t[st[i]])) -- print value
      gfx.x = 10
     
      -- add vertical spaces
      if i == 5 or i == 8 or i == 12 or i == 14 or i == 16 or i == 23 or i == 23 or i == 26 then
        gfx.y = gfx.y + gfx.texth
      end
      -- move to next line
      gfx.y = gfx.y + gfx.texth
    end
  end
  
end


-- Sort table alphabetically
function sorted_table(t)
  local st = {} -- sorted table
  for n in pairs(t) do 
    st[#st+1] = n
  end
  table.sort(st)
  return st
end


-- create a sorted array (= "mouse table keys" are sorted alphabetically and put to an array)
local sorted_mouse_t = sorted_table(mouse) -- call sorted_table function -> store to "sorted_mouse_t"


-- GUI drawing function
function draw_gui()
  gfx.x = 10
  gfx.y = 10
 
  -- Draw mouse table keys and values
  gfx.x = 10
  draw_sorted_table(mouse, sorted_mouse_t)
 
end

-- GUI table --------------------------------------------
--   contains GUI related settings (some basic user definable settings), initial values etc.
---------------------------------------------------------
local gui = {}

function init()
  
  -- Add stuff to "gui" table
  gui.settings = {}                 -- Add "settings" table to "gui" table 
  gui.settings.font_size = 20       -- font size
  gui.settings.docker_id = 0        -- try 0, 1, 257, 513, 1027 etc.
  
  ---------------------------
  -- Initialize gfx window --
  ---------------------------
  
  gfx.init("", 380, 700, gui.settings.docker_id)
  gfx.setfont(1,"Arial", gui.settings.font_size)
  gfx.clear = 3355443  -- matches with "FUSION: Pro&Clean Theme :: BETA 01" http://forum.cockos.com/showthread.php?t=155329
  -- (Double click in ReaScript IDE to open the link)

  GetMouseInfo()
end


--------------
-- Mainloop --
--------------

function GetMouseInfo(x, y, p)
  mouse.x, mouse.y, mouse.p = x or mouse.x, y or mouse.y, p or mouse.p
  mouse.l_click   = false
  mouse.r_click   = false
  mouse.l_dclick  = false
  mouse.l_up      = false
  mouse.r_up      = false
  mouse.l_down    = false
  mouse.r_down    = false
  
  local LB_DOWN = mouse.lb_down()           -- Get current left mouse button state
  local RB_DOWN = mouse.rb_down()           -- Get current right mouse button state
 -- mouse.x, mouse.y = reaper.GetMousePosition()
  
  -- (modded Schwa's GUI example)
  if (LB_DOWN and not RB_DOWN) or (RB_DOWN and not LB_DOWN) then   -- LMB or RMB pressed down?
    if (mouse.last_LMB_state == false and not RB_DOWN) or (mouse.last_RMB_state == false and not LB_DOWN) then
      OnMouseDown(LB_DOWN, RB_DOWN)
      if mouse.uptime and os.clock() - mouse.uptime < 0.20 then
        OnMouseDoubleClick()
      end
    else
      OnMouseHold(LB_DOWN,RB_DOWN)
    end
      
  elseif not LB_DOWN and mouse.last_RMB_state or not RB_DOWN and mouse.last_LMB_state then
    OnMouseUp(LB_DOWN, RB_DOWN)
  end
  
  draw_gui()
 
  --gfx.update()
  --reaper.defer(mainloop)
  return mouse
end

init()
