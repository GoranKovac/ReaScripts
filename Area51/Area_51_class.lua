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

      if not mouse.Ctrl() then -- DRAG COPY
        if not SPLIT then
          AreaDo({self}, "split") -- split selection
          self.sel_info = GetSelectionInfo(self) -- get new info on seleciton
          GetGhosts(self.sel_info, self.time_start, self.time_start + self.time_dur, "update", z[2])
          SPLIT = true --set split flag
        end
        --end
        self.time_start = new_L
        self.time_start = self.time_start >= 0 and self.time_start or 0
        self.x = convert_time_to_pixel(self.time_start, 0)
      end

      local temp_area_ghost = convert_time_to_pixel(new_L, 0) -- TEMPORARY AREA GRAPHICS SO WE DO NOT MOVE THE ORIGINAL ONE SINCE IT CHANGE THE DATA OF THE TABLE 

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
          DrawItemGhosts(self.sel_info[i].items, self.sel_info[i].track, z[2], self.time_dur, 0, mouse.tr, new_L - z[2])
        elseif self.sel_info[i].env_name then
          DrawEnvGhosts(self.sel_info[i].track, self.sel_info[i].env_name, z[2], self.time_dur, 0, mouse.tr, new_L - z[2])
        end
      end
      self:draw(temp_area_ghost) -- TEMPORARY AREA GRAPHICS SO WE DO NOT MOVE THE ORIGINAL ONE SINCE IT CHANGE THE DATA OF THE TABLE 
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
    SPLIT = nil
    move = nil
    ZONE = nil
    test = nil
    ARRANGE = nil
    if z[1] == "L" or z[1] == "R" or z[1] == "T" or z[1] == "B" then
      self.sel_info = GetSelectionInfo(self) -- UPDATE AREAS INFORMATION
      GetGhosts(self.sel_info, self.time_start, self.time_start + self.time_dur, "update", z[2])
    elseif z[1] == "C" then
      if mouse.Ctrl() then
        local new_L = z[2] + mouse.dp >= 0 and z[2] + mouse.dp or 0
        AreaDo({self}, "PASTE",new_L)
        self.time_start = new_L
        self.time_start = self.time_start >= 0 and self.time_start or 0
        self.x = convert_time_to_pixel(self.time_start, 0)
      else
        move_items_envs(self, self.time_start - z[2]) -- MOVE ITEMS BEFORE WE UPDATE THE AREA SO OFFSET CAN REFRESH
      end
      UnlinkGhosts()
      self.sel_info = GetSelectionInfo(self)
      GetGhosts(self.sel_info, self.time_start, self.time_start + self.time_dur, "update", z[2])
    end
    --GetGhosts(self.sel_info, self.time_start, self.time_start + self.time_dur, "update", z[2])
  end
  if z[1] ~= "C" then self:draw() end
end

function Element:update_xywh()
  self.x, self.w = convert_time_to_pixel(self.time_start, self.time_start + self.time_dur)
  self.y, self.h = GetTrackTBH(self.sel_info) -- FIND NEW TRACKS HEIGHT AND Y IF CHANGED
  self:draw()
end

function Element:draw(x,y,h)
  self.x = x or self.x
  self.y = y or self.y
  self.h = h or self.h
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
  return mouse.l_down == false and self:pointIN(mouse.x, mouse.y) --self:pointIN(mouse.x, mouse.y)
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

  A_M_Block = self:mouseIN() or self:mouseDown() or ZONE and true or nil

  if self:mouseIN() then
  end
end
----------------------------------------------------------------------------------------------------
---   Create Element Child Classes(Button,Slider,Knob)   -------------------------------------------
----------------------------------------------------------------------------------------------------
AreaSelection = {}
extended(AreaSelection, Element)

function Track(tbl)
  for _, area in pairs(tbl) do
    area:track()
    if area:mouseIN() or area:mouseDown() then return end
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

