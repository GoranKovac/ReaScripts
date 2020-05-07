--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.06
	 * NoIndex: true
--]]
local reaper = reaper
local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW

local AREA_UPDATES

local Element = {}
function Get_class_tbl(tbl)
  return Element
end

local ZONE_BUFFER
local split, move, drag_copy
local CUR_AREA_ZONE

function get_buffer_bm()
  if ZONE_BUFFER and ZONE_BUFFER[5] then
    return ZONE_BUFFER[5].bm
  end
end

function copy3(obj, seen)
  -- Handle non-tables and previously-seen tables.
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  -- New table; mark it as seen an copy recursively.
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in next, obj do
    if k == "bm" and obj["guid"] ~= "ghost" then -- CREATE BITMAPS ONLY FOR AREAS, AVOID GHOSTS
      v = reaper.JS_LICE_CreateBitmap(true, obj["w"], obj["h"])
      reaper.JS_LICE_Clear(v, 0x66002244)
      reaper.JS_LICE_AlterBitmapHSV( v, 0, 0, 0.5)
    end
    res[copy3(k, s)] = copy3(v, s)
  end
  return res
end

function Element:new(x, y, w, h, guid, time_start, time_dur, info)
  local elm = {}
  elm.x, elm.y, elm.w, elm.h = x, y, w, h
  elm.guid, elm.bm = guid, reaper.JS_LICE_CreateBitmap(true, elm.w, elm.h)
  reaper.JS_LICE_Clear(elm.bm, 0x66002244)
  elm.info, elm.time_start, elm.time_dur = info, time_start, time_dur
  setmetatable(elm, self)
  self.__index = self
  return elm
end

function Element:update_zone(z)
  if copy then return end
  if mouse.l_down then
    if z[1] == "L" then
      local new_L = (Snap_val(z[2]) + mouse.dp) <= (z[3]+z[2]) and (Snap_val(z[2]) + mouse.dp) or Snap_val(z[3]+z[2])
      new_L = new_L >= 0 and new_L or 0
      local new_R = (z[3]+z[2]) - new_L >= 0 and (z[3]+z[2]) - new_L or 0
      self.time_start = new_L
      self.time_dur = new_R
    elseif z[1] == "R" then
      local new_R = Snap_val(z[3]+z[2]) + mouse.dp
      self.time_dur = new_R - self.time_start
      self.time_dur = self.time_dur >= 0 and self.time_dur or 0
    elseif z[1] == "C" then
        if (mouse.dp ~= 0 or mouse.tr ~= mouse.last_tr) and not drag_copy then
          if not split then Split_for_move(z[5]) split = true end
        end
        local offset = Mouse_track_offset(z[5].sel_info[1].track)
        local new_L = z[2] + mouse.dp >= 0 and z[2] + mouse.dp or 0
        self.time_start = new_L
        for i = 1, #z[5].sel_info do
          local new_tr = Track_from_offset(z[5].sel_info[i].track, offset)
          new_tr = env_offset_new(z[5].sel_info, z[5].sel_info[i].track, new_tr, z[5].sel_info[i].env_name) or new_tr
          self.sel_info[i].track = new_tr
          self.y, self.h = GetTrackTBH(self.sel_info)
        end
        z[5]:ghosts(self.time_start - z[2])
    elseif z[1] == "T" then
      local rd = (mouse.last_r_t - mouse.ort)
      if (z[3] - rd) > 0 then
        local new_y, new_h = z[2] + rd, z[3] - rd
        self.y, self.h = new_y, new_h
      end
    elseif z[1] == "B" then
      local rd = (mouse.last_r_b - mouse.orb)
      if (z[3] + rd) > 0 then
        local new_h = z[3] + rd
        self.h = new_h
      end
    end
    self.x, self.w = Convert_time_to_pixel(self.time_start, self.time_dur)
    if z[1] == "L" or z[1] == "R" or z[1] == "TL" or z[1] == "TR" then -- FOR STRETCHING AND OTHER ADVANCED VOODOO
      --Area_Drag(z[5].sel_info, self.sel_info, {z[2], z[3]}, {self.time_start,self.time_dur}, self.time_start - z[2], z[1], action)
    end
  elseif mouse.l_up then
    local action
    if move then
      action = "move"
    elseif drag_copy then
      action = "drag_copy"
    end
    if z[1] == "C" then
      if mouse.dp ~= 0 then
        Area_Drag(z[5], self, {z[2], z[3]}, {self.time_start,self.time_dur}, self.time_start - z[2], z[1], action) -- MOVE AND DRAG COPY
      end
      Ghost_unlink_or_destroy({self}, "Delete")
    end

    reaper.JS_LICE_DestroyBitmap( ZONE_BUFFER[5].bm )
    ZONE_BUFFER = nil
    split, drag_copy, move = nil, nil, nil

    if self.time_dur == 0 then
      RemoveAsFromTable(Get_area_table("Areas"), self.guid, "==")
    else
      self.sel_info = GetSelectionInfo(self)
    end
  end
end

function Element:update_xywh()
  self.x, self.w = Convert_time_to_pixel(self.time_start, self.time_dur)
  self.y, self.h = GetTrackTBH(self.sel_info)
  self:draw(1,1)
end

A_DRAWCOUNT = 0
function Element:draw(w,h,test,test2,test3,test4)
  local test_x = test and test or self.x
  local test_w = test2 and test2 or self.w
  local test_y = test3 and test3 or self.y
  local test_h = test4 and test4 or self.h
  reaper.JS_Composite(track_window, test_x, test_y, test_w, test_h, self.bm, 0, 0, w, h, true)
  --reaper.JS_Composite(track_window, self.x, self.y, self.w, self.h, self.bm, 0, 0, w, h, true)
  A_DRAWCOUNT = A_DRAWCOUNT + 1
end

function Element:ghosts(off_time)
  local temp_info = {}
  if not GHOST_UPDATE and not MOVE_AREA_UPDATE then return end
  local offset = Mouse_track_offset(self.sel_info[1].track)
  local area_offset = self.time_start - lowest_start() --  OFFSET AREA SELECTIONS TO MOUSE POSITION
  local mouse_offset = off_time and off_time or (mouse.p - self.time_start) + area_offset
  for i = 1, #self.sel_info do
    local new_tr = Track_from_offset(self.sel_info[i].track, offset)
    new_tr = env_offset_new(self.sel_info, self.sel_info[i].track, new_tr, self.sel_info[i].env_name) or new_tr
    temp_info[i] = { track = new_tr }
    if self.sel_info[i].ghosts then
      for j = 1, #self.sel_info[i].ghosts do
        local ghost = self.sel_info[i].ghosts[j]
        local ghost_start = mouse_offset and (mouse_offset + ghost.time_start) or ghost.time_start
        ghost.x, ghost.w = Convert_time_to_pixel(ghost_start, ghost.time_dur)
        ghost.y, ghost.h = Get_tr_TBH(new_tr)
        ghost:draw(ghost.info[1], ghost.info[2]) -- STORED GHOST W AND H
        --if mode == "OVERRIDE" and not Get_tr_TBH(new_env_tr) then reaper.JS_Composite_Unlink(track_window, ghost.bm) end -- IF IN OVERRIDE MODE REMOVE GHOSTS THAT HAVE NO TRACKS
      end
    end
  end
  -- HELPERS
  if not GHOST_UPDATE then return end
    local new_area_start = self.time_start + mouse_offset
    local new_area_x,new_area_w = Convert_time_to_pixel(new_area_start, self.time_dur)
    local new_area_y,new_area_h = GetTrackTBH(temp_info)
    self:draw(1,1, new_area_x, new_area_w, new_area_y, new_area_h)
  if MOVE_AREA_UPDATE then
   -- target.y, target.h = GetTrackTBH(temp_info)
  end
end

function Element:pointIN(sx, sy)
  local x, y = To_client(sx, sy)
  return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Element:zoneIN(sx, sy)
  local x, y = To_client(sx, sy)
  local range2 = 10

  if x >= self.x and x <= self.x + range2 then
    if y >= self.y and y <= self.y + range2 then
      return {"TL"}
    elseif y <= self.y + self.h and y >= (self.y + self.h) - range2 then
      return {"BL"}
    end
    return {"L", self.time_start, self.time_dur}
  end

  if x >= (self.x + self.w - range2) and x <= self.x + self.w then
    if y >= self.y and y <= self.y + range2 then
      return {"TR"}
    elseif y <= self.y + self.h and y >= (self.y + self.h) - range2 then
      return {"BR"}
    end
    return {"R", self.time_start, self.time_dur}
  end

  if y >= self.y and y <= self.y + range2 then
    return {"T", self.y, self.h, self.time_start + self.time_dur}
  end
  if y <= self.y + self.h and y >= (self.y + self.h) - range2 then
    return {"B", self.y, self.h, self.time_start + self.time_dur}
  end

  if x > (self.x + range2) and x < (self.x + self.w - range2) then
    if y > self.y + range2 and y < (self.y + self.h) - range2 then
      return {"C", self.time_start, self.time_dur, self.y}
    end
  end
end

function Element:mouseZONE()
  return self:zoneIN(mouse.ox, mouse.oy)-- mouse.ox, mouse.oy
end

function Element:mouseIN()
  return mouse.l_down == false and self:pointIN(mouse.x, mouse.y) --self:pointIN(mouse.x, mouse.y)
end
------------------------
function Element:mouseDown()
  return mouse.l_down and self:pointIN(mouse.ox, mouse.oy)
end
--------
function Element:mouseUp()
  return mouse.l_up --and self:pointIN(mouse.ox, mouse.oy)
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

function Element:track()
  local active_as = Get_area_table("Active")
  if CREATING or WINDOW_IN_FRONT then
    return
  end
  -- GET CLICKED AREA INFO GET ZONE
  if self:mouseClick() then
    if copy or mouse.DRAW_AREA then return end
    ZONE_BUFFER = self:mouseZONE()
    ZONE_BUFFER.guid = self.guid
    ZONE_BUFFER[5] = copy3(self)
    Buffer_copy({ZONE_BUFFER[5]})
    if ZONE_BUFFER[1] == "C" then
      if mouse.Ctrl() then
        drag_copy = self.guid
      end
      ZONE_BUFFER[5]:draw(1,1) -- DRAW STATIC COPiE
    end
    move = not drag_copy and self.guid or nil
  end

  if copy then
    if active_as then
      if active_as.guid == self.guid then
        self:ghosts() -- draw only selected as ghost
      end
    else
      self:ghosts()
    end
  end
  -- UPDATE AREA ZONE
  if ZONE_BUFFER and ZONE_BUFFER.guid == self.guid then
    self:update_zone(ZONE_BUFFER)
  end
  BLOCK = (not mouse.DRAW_AREA and CUR_AREA_ZONE) or ZONE_BUFFER and true or nil  -- GLOBAL BLOCKING FLAG IF MOUSE IS OVER AREA (ALSO USED TO INTERCEPT LMB CLICK)
  A51_cursor = ZONE_BUFFER and ZONE_BUFFER[1] or CUR_AREA_ZONE
  Change_cursor(A51_cursor)
end

function Track(tbl)
  for i = 1, #tbl do
    if tbl[i]:mouseIN() then
      CUR_AREA_ZONE = (not copy and not check_window_in_front()) and tbl[i]:zoneIN(mouse.x,mouse.y)[1]
      break
    else
      CUR_AREA_ZONE = nil
    end
  end

  if WINDOW_IN_FRONT then return end

  for i = #tbl, 1, -1  do
    tbl[i]:track()
    if AREAS_UPDATE then
      if copy then Get_area_table("Copy")[i]:update_xywh() end
      if not copy and not CREATING then tbl[i]:update_xywh() end
    end
    if MOVE_AREA_UPDATE and (move and tbl[i].guid == move or drag_copy and tbl[i].guid == drag_copy) then
      tbl[i]:draw(1,1)
    end
  end

  if DRAWING and #tbl ~= 0 then
    tbl[#tbl]:draw(1,1) -- UPDATE ONLY AS THAT IS DRAWING (LAST CREATED)
  end
end

function Draw(tbl)
  local is_view_changed = Arrange_view_info()
  local is_mouse_change = check_mouse_change()
  --WINDOW_IN_FRONT = Get_window_under_mouse()

  if is_mouse_change then
    GHOST_UPDATE = copy and 1
    MOVE_AREA_UPDATE = (move or drag_copy) and 1
 end

  if is_view_changed and not DRAWING then
    AREAS_UPDATE = 1
    GHOST_UPDATE = copy and 1
  end

  Track(tbl)

  AREAS_UPDATE = false
  if MOVE_AREA_UPDATE and MOVE_AREA_UPDATE < 3 then
    MOVE_AREA_UPDATE = MOVE_AREA_UPDATE + 1
  else
    MOVE_AREA_UPDATE = false
  end
  if GHOST_UPDATE and GHOST_UPDATE < 2 then
    GHOST_UPDATE = GHOST_UPDATE + 1
  else
    GHOST_UPDATE = false
  end
end