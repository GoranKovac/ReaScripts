local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 1000) -- GET TRACK VIEW

local Element = {}

function color()
end

function Element:new(x, y, w, h, guid, time_start, time_end, info, norm_val, norm_val2)
  local elm = {}
  elm.x, elm.y, elm.w, elm.h = x, y, w, h
  elm.guid, elm.bm = guid, reaper.JS_LICE_CreateBitmap(true, 1, 1)
  reaper.JS_LICE_Clear(elm.bm, 0x66002244)
  elm.info, elm.time_start, elm.time_end = info, time_start, time_end
  elm.norm_val = norm_val
  elm.norm_val2 = norm_val2
  ----------------------
  setmetatable(elm, self)
  self.__index = self
  return elm
end

function extended(Child, Parent)
  setmetatable(Child, {__index = Parent})
end

function Element:update_xywh()
  local _, x_view_start, y_view_start = reaper.JS_Window_GetRect(track_window)
  local zoom_lvl = reaper.GetHZoomLevel()
  local Arr_start = reaper.GetSet_ArrangeView2(0, false, 0, 0)
  local Arr_pixel = Round(Arr_start * zoom_lvl)
  local x_s = Round(self.time_start * zoom_lvl) -- convert time to pixel
  local x_e = Round(self.time_end * zoom_lvl) -- convert time to pixel
  self.x = (x_s - Arr_pixel) + x_view_start -- NEED TO ADD X VIEW START AND THEN REMOVE IT WHEN DRAWING OR MOUSE CORDINATES ARE WRONG
  self.y, self.h = GetTrackTBH(self.sel_info) -- FIND NEW TRACKS HEIGHT AND Y IF CHANGED
  self.w = x_e - x_s
  self:draw()
end

function Element:draw()
  local _, x_view_start, y_view_start = reaper.JS_Window_GetRect(track_window)
  reaper.JS_Composite(track_window, self.x - x_view_start, self.y - y_view_start, self.w, self.h, self.bm, 0, 0, 1, 1)
  refresh_reaper()
end

function Element:pointIN(x, y)
  return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h --then -- IF MOUSE IS IN ELEMENT
end

function Element:zoneIN(x, y)
  local range2 = 14

  if x >= self.x and x <= self.x + range2 then
    if y >= self.y and y <= self.y + range2 then
      return "TL"
    elseif y <= self.y + self.h and y >= (self.y + self.h) - range2 then
      return "BL"
    end
    return {"L", self.x, self.w}
  end

  if x >= (self.x + self.w - range2) and x <= self.x + self.w then
    if y >= self.y and y <= self.y + range2 then
      return "TR"
    elseif y <= self.y + self.h and y >= (self.y + self.h) - range2 then
      return "BR"
    end
    return {"R", self.x + self.w, self.w}
  end

  if y >= self.y and y <= self.y + range2 then
    return {"T", self.y, self.h}
  end
  if y <= self.y + self.h and y >= (self.y + self.h) - range2 then
    return {"B", self.y, self.h}
  end

  if x > (self.x + range2) and x < (self.x + self.w - range2) then
    if y > self.y + range2 and y < (self.y + self.h) - range2 then
      return {"C", self.x, self.w, self.y}
    end
  end
end

function Element:mouseZONE()
  return mouse.l_down and self:zoneIN(mouse.ox, mouse.oy)
end

function Element:mouseIN()
  return mouse.l_down == false and self:pointIN(mouse.x, mouse.y)
end
------------------------
function Element:mouseDown()
  return mouse.l_down and self:pointIN(mouse.ox, mouse.oy)
end
--------
function Element:mouseUp() -- its actual for sliders and knobs only!
  return mouse.l_up and self:pointIN(mouse.ox, mouse.oy)
end
--------
function Element:mouseClick()
  return mouse.l_click and self:pointIN(mouse.ox, mouse.oy)
end
------------------------
function Element:mouseR_Down()
  return mouse.r_down and self:pointIN(mouse.ox, mouse.oy)
end
--------
function Element:mouseM_Down()
  --return m_state&64==64 and self:pointIN(mouse_ox, mouse_oy)
end
--------
local transform
function Element:track()
  if CREATING then
    return
  end
  --[[
  if mouse.l_down and self:mouseDown() and self:mouseZONE() then
    ZONE = true
    zone(self:mouseZONE(),self)
    --msg(self:mouseZONE())
  elseif mouse.l_up then ZONE = nil --end
  end
  ]]
  --[[
    if self:mouseDown() and not ZONE then ZONE = self:zoneIN(mouse.ox, mouse.oy) end
    if ZONE and mouse.l_down then transform = zone(ZONE,self)
    elseif ZONE and mouse.l_up then self.info = GetAreaInfo(transform) ZONE = nil transform = nil
    end
    ]]
end
----------------------------------------------------------------------------------------------------
---   Create Element Child Classes(Button,Slider,Knob)   -------------------------------------------
----------------------------------------------------------------------------------------------------
AreaSelection = {}
extended(AreaSelection, Element)
Rng_Slider = {}
extended(Rng_Slider, Element)
Menu = {}
extended(Menu, Element)

local Menu_TB = {Menu:new(0, 0, 0, 0, "H", nil, nil, nil, 8)}

function Rng_Slider:draw_body()
  local _, x_view_start, y_view_start = reaper.JS_Window_GetRect(track_window)
  local x, y, w, h = self.x, self.y, self.w, self.h
  local val = h * self.norm_val
  local val2 = h * self.norm_val2
  reaper.JS_Composite(track_window, self.x - x_view_start, self.y - y_view_start, self.w, self.h, self.bm, 0, 0, 1, 1)
  refresh_reaper()
end

local m_bm = reaper.JS_LICE_CreateBitmap(true, 1, 1)
reaper.JS_LICE_Clear(m_bm, 0x33005511)
local last_num = 0
function Menu:draw_body(tbl)
  if not tbl then
    return
  end
  local _, x_view_start, y_view_start = reaper.JS_Window_GetRect(track_window)

  self.x, self.y, self.w, self.h = tbl.x, tbl.y, tbl.w, tbl.h
  self.x, self.y, self.w, self.h = self.x + Round(self.w / 2), self.y, Round(self.w / 2), 15
   --math.ceil(h/4)
  reaper.JS_Composite(track_window, (self.x) - x_view_start, self.y - y_view_start, self.w, self.h, self.bm, 0, 0, 1, 1) -- DRAW BACKGROUND

  local step = Round(self.w / (self.norm_val))
  if self:pointIN(m_x, m_y) then
    for i = 0, self.norm_val - 1 do
      local w_offest = 0
      w_offest = Round(w_offest + (step * i))
      if m_x > self.x + w_offest and m_x < (self.x + w_offest + step) then
        A1 = i + 1
        reaper.JS_Composite(
          track_window,
          (self.x + w_offest) - x_view_start,
          self.y - y_view_start,
          step,
          self.h,
          m_bm,
          0,
          0,
          1,
          1
        )
      end
    end
    if last_num ~= A1 then
      refresh_reaper()
      last_num = A1
    end
    last_menu_in = true
  else
    if last_menu_in then
      reaper.JS_Composite_Unlink(track_window, m_bm)
      refresh_reaper()
      last_menu_in = nil
    end
  end
end

function Track(tbl)
  for _, area in pairs(tbl) do
    area:track()
  end
end

function Draw(tbl)
  Track(tbl)
  local is_view_changed = Arrange_view_info()
  if is_view_changed and not DRAWING then
    for i = 1, #tbl do
      tbl[i]:update_xywh()
    end -- UPDATE ALL AS ONLY ON CHANGE
  elseif DRAWING then
    tbl[#tbl]:draw() -- UPDATE ONLY AS THAT IS DRAWING (LAST CREATED) STILL NEEDS MINOR FIXING TO DRAW ONLY LAST AS IN LAST TABLE,RIGHT NOT IT UPDATES ONLY LAST AS TABLE (EVERY AS IN LAST TABLE)
  end
end

function refresh_reaper()
  reaper.JS_Window_InvalidateRect(track_window, 0, 0, 5000, 5000, false)
end
