--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
	 * NoIndex: true
--]]
local reaper = reaper
local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local BUTTON_UPDATE
local mouse
local Element = {}

local menu_options = {
  [1] = { name="", fname="" },
  [2] = { name="Create New Variant", fname="CreateNew" },
  [3] = { name="Duplicate Variant", fname="Duplicate" },
  [4] = { name="Delete Variant", fname="Delete" },
  [5] = { name="Clear Variant", fname="Clear" },
  [6] = { name="Show All Variants", fname="ShowAll" }
}

function Get_class_tbl(tbl)
  return Element
end

local function ConcatMenuNames()
  local concat = ""
  for i = 1, #menu_options do
    concat = concat .. menu_options[i].name .. (i ~= #menu_options and "|" or "")
  end
  return concat
end

function Show_menu(tbl)
  reaper.PreventUIRefresh(1)
  gfx.init("", -100, -100)
  gfx.x = gfx.mouse_x
  gfx.y = gfx.mouse_y

  local versions = {}
  for i = 1, #tbl.info do
    versions[#versions+1] = i == tbl.idx and "!" .. i or i
  end

  menu_options[1].name = ">Virtual TR|" .. table.concat(versions, "|") .."|<|"

  local m_num = gfx.showmenu(ConcatMenuNames())

  if m_num > #tbl.info then
    m_num = (m_num - #tbl.info) + 1
    _G[menu_options[m_num].fname](mouse.otr, tbl)
  else
    if m_num ~= 0 then
      Set_Virtual_Track(mouse.otr, tbl, m_num)
    end
  end
  gfx.quit()

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

function Element:new(x, y, w, h, guid, info)
  local elm = {}
  elm.x, elm.y, elm.w, elm.h = x, y, w, h
  elm.guid = guid
  elm.info  = info
  elm.idx = 1;
  setmetatable(elm, self)
  self.__index = self
  return elm
end

function Element:update_xywh()
  self.y = Get_tr_TBH(self.guid)
  self:draw(1,1)
end

A_DRAWCOUNT = 0
function Element:draw(w,h)
  reaper.JS_Composite(track_window, 0, self.y, self.w, self.h, Get_BM_table()[self.guid], 0, 0, w, h, true)
  A_DRAWCOUNT = A_DRAWCOUNT + 1
end

function Element:pointIN(sx, sy)
  local x, y = To_client(sx, sy)
  return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Element:mouseIN()
  return mouse.l_down == false and self:pointIN(mouse.x, mouse.y)
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
  if self:mouseClick() then
    Show_menu(self)
  end
end

local function Track(tbl)
  for _, track in pairs(tbl) do track:track() end
end

local function Update_BTNS(tbl, update)
  if not update then return end
  for _, track in pairs(tbl) do track:update_xywh() end
end

function Draw(tbl)
  mouse = MouseInfo()
  mouse.tr, mouse.r_t, mouse.r_b = Get_track_under_mouse(mouse.x, mouse.y)
  Track(tbl)
  local is_view_changed = Arrange_view_info()
  BUTTON_UPDATE = is_view_changed and true
  Update_BTNS(tbl, BUTTON_UPDATE)
  BUTTON_UPDATE = false
end