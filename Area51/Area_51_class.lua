local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 1000) -- GET TRACK VIEW

local Element = {}

function color()
end

function Element:new(x, y, w, h, guid, time_start, time_dur, info, norm_val, norm_val2)
  local elm = {}
  elm.x, elm.y, elm.w, elm.h = x, y, w, h
  elm.guid, elm.bm = guid, reaper.JS_LICE_CreateBitmap(true, 1, 1)
  reaper.JS_LICE_Clear(elm.bm, 0x66002244)
  elm.info, elm.time_start, elm.time_dur = info, time_start, time_dur
  elm.norm_val = norm_val
  elm.norm_val2 = norm_val2
  setmetatable(elm, self)
  self.__index = self
  return elm
end

function extended(Child, Parent)
  setmetatable(Child, {__index = Parent})
end

function Element:zone(z)
  if mouse.l_down then
    if z[1] == "L" then
      local new_L = z[2] + mouse.dp
      self.time_start = new_L
      self.time_start = self.time_start >= 0 and self.time_start or 0
      self.time_start = self.time_start <= z[3] and self.time_start or z[3]
      self.x, self.w = convert_time_to_pixel(self.time_start, z[3])
    elseif z[1] == "R" then
      local new_R = z[2] + mouse.dp
      self.time_dur = new_R
      self.time_dur = self.time_dur >= 0 and self.time_dur or 0
      _, self.w = convert_time_to_pixel(0, self.time_dur)
      --AreaDo({self},"stretch")
    elseif z[1] == "C" then
      move = true
      local tracks = z[5]
      local new_L = z[2] + mouse.dp >= 0 and z[2] + mouse.dp or 0
      --offset = (new_L - self.time_start) -- GET MOVE OFFSET FOR ITEMS
      self.time_start = new_L
      self.time_start = self.time_start >= 0 and self.time_start or 0
      self.x = convert_time_to_pixel(self.time_start, 0)

      local last_project_tr = get_last_visible_track()
      local last_project_tr_id = reaper.CSurf_TrackToID(last_project_tr, false)
      local mouse_delta = reaper.CSurf_TrackToID(env_to_track(mouse.tr), false) - reaper.CSurf_TrackToID(env_to_track(mouse.last_tr), false)

      -- OFFSET TRACKS BASED ON AREA POSITION (TRACKS FOLLOW AREA)
      if mouse_delta ~= 0 then
        
        local skip
        for i = 1, #tracks do
          if reaper.ValidatePtr(tracks[i].track, "TrackEnvelope*") then -- IF THERE IS ENVELOPE TRACK IN TABLE DO NOT MOVE UP/DOWN
            skip = true
            break
          end
        end
        
        if not skip then -- IF THERE IS NO ENVELOPE TRACK SELECTED
          -- PREVENT TRACKS TO GO BELLOW OR ABOVE FIRST/LAST PROJECT TRACK 
          if reaper.CSurf_TrackToID(env_to_track(tracks[1].track), false) + mouse_delta >= 1 and
            reaper.CSurf_TrackToID(env_to_track(tracks[#tracks].track), false) + mouse_delta <= (last_project_tr_id) then
            for i = 1, #tracks do --for i = #tracks, 1, -1 do
              self.sel_info[i].track = generic_track_offset(tracks[i].track, mouse.last_tr)
            end
          end
        end
        
      end
      self.y, self.h = GetTrackTBH(self.sel_info)
      for i = 1, #self.sel_info do
        if self.sel_info[i].items then
          DrawItemGhosts(self.sel_info[i].items, self.sel_info[i].track, z[2], self.time_dur, 0, mouse.tr, self.time_start - z[2])
        elseif self.sel_info[i].env_name then
          DrawEnvGhosts(self.sel_info[i].track, self.sel_info[i].env_name, z[2], self.time_dur, 0, mouse.tr, self.time_start - z[2])
        end
      end
    elseif z[1] == "T" then
      local rd = (mouse.r_t - mouse.ort)
      local new_y, new_h = z[2] + rd, z[3] - rd
      self.y, self.h = new_y, new_h
    elseif z[1] == "B" then
      local rd = (mouse.r_b - mouse.orb)
      local new_h = z[3] + rd
      self.h = new_h
    end
  else
    move = nil
    ZONE = nil
    test = nil
    ARRANGE = nil
    if z[1] == "L" or z[1] == "R" or z[1] == "T" or z[1] == "B" then
      self.sel_info = GetSelectionInfo(self) -- UPDATE AREAS INFORMATION
      GetGhosts(self.sel_info, self.time_start, self.time_start + self.time_dur, "update", z[2])
    elseif z[1] == "C" then
      move_items_envs(self, self.time_start - z[2]) -- MOVE ITEMS BEFORE WE UPDATE THE AREA SO OFFSET CAN REFRESH
      UnlinkGhosts()
      self.sel_info = GetSelectionInfo(self)
      GetGhosts(self.sel_info, self.time_start, self.time_start + self.time_dur, "update", z[2])
    end
    --GetGhosts(self.sel_info, self.time_start, self.time_start + self.time_dur, "update", z[2])
  end
  self:draw()
end

function Element:update_xywh()
  self.x, self.w = convert_time_to_pixel(self.time_start, self.time_start + self.time_dur)
  self.y, self.h = GetTrackTBH(self.sel_info) -- FIND NEW TRACKS HEIGHT AND Y IF CHANGED
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
    return {"L", self.time_start, self.time_start + self.time_dur}
  end

  if x >= (self.x + self.w - range2) and x <= self.x + self.w then
    if y >= self.y and y <= self.y + range2 then
      return "TR"
    elseif y <= self.y + self.h and y >= (self.y + self.h) - range2 then
      return "BR"
    end
    return {"R", self.time_dur, self.time_start}
  end

  if y >= self.y and y <= self.y + range2 then
    return {"T", self.y, self.h}
  end
  if y <= self.y + self.h and y >= (self.y + self.h) - range2 then
    return {"B", self.y, self.h}
  end

  if x > (self.x + range2) and x < (self.x + self.w - range2) then
    if y > self.y + range2 and y < (self.y + self.h) - range2 then
      return {"C", self.time_start, self.time_dur, self.y, self.sel_info}
    end
  end
end

function Element:mouseZONE()
  return self:zoneIN(mouse.ox, mouse.oy)
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
function Element:track()
  if CREATING then
    return
  end
  if self:mouseDown() then
    if not ZONE then
      ZONE = self:mouseZONE()
      test = self
    end
  end
  if ZONE and self.guid == test.guid then
    test:zone(ZONE)
  end -- PREVENT OTHER AREAS TRIGGERING THIS LOOP AGAIN
  if self:mouseIN() then
  end
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

Menu_TB = {Menu:new(0, 0, 0, 0, "H", nil, nil, nil, 8)}
SLD_TB = {Rng_Slider:new(0, 0, 0, 0, "H", nil, nil, nil, 8)}

function Rng_Slider:draw_body()
  local _, x_view_start, y_view_start = reaper.JS_Window_GetRect(track_window)
  local x, y, w, h = self.x, self.y, self.w, self.h
  local val = h * self.norm_val
  local val2 = h * self.norm_val2
  reaper.JS_Composite(track_window, self.x - x_view_start, self.y - y_view_start, self.w, self.h, m_bm, 0, 0, 1, 1)
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
  refresh_reaper()
  local step = Round(self.w / (self.norm_val))

  if self:pointIN(mouse.x, mouse.y) then
    for i = 0, self.norm_val - 1 do
      local w_offest = 0
      w_offest = Round(w_offest + (step * i))
      if mouse.x > self.x + w_offest and mouse.x < (self.x + w_offest + step) then
       -- A1 = i + 1
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
    --[[if last_num ~= A1 then
      refresh_reaper()
      last_num = A1
    end
    last_menu_in = true]]
    
  else
    --if last_menu_in then
      reaper.JS_Composite_Unlink(track_window, m_bm)
      refresh_reaper()
      --last_menu_in = nil
    --end
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

