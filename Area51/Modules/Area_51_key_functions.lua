--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.05
	 * NoIndex: true
--]]
local reaper = reaper
local prev_area

function Remove()
  local tbl = Get_area_table("Areas")
  local CPY_TBL = Get_area_table("Copy")
  if copy then
     Copy_mode()
     return
  end -- DISABLE COPY MODE
  RemoveAsFromTable(tbl, "Delete", "~=")
  DeleteCopy(CPY_TBL)
  prev_area = nil
  BLOCK = nil
  Change_cursor()
  Set_active_as(nil)
  AREAS_UPDATE = 1
end

function Copy_mode()
  local tbl = Get_area_table("Areas")
  local CPY_TBL = Get_area_table("Copy")
  copy = next(tbl) ~= nil and not copy
  GHOST_UPDATE = copy and 1 or false
  if copy then
    Set_copy_tbl(copy3(tbl))
    Buffer_copy(Get_area_table("Copy"))
  end
  if not copy then
    Ghost_unlink_or_destroy(tbl, "Unlink")
    DeleteCopy(CPY_TBL)
    prev_area = nil
    Set_active_as(nil)
  end
  AREAS_UPDATE = 1
end

function Copy_Paste()
  if copy then
    local tbl = Get_area_table()
    Area_function(tbl, "Paste")
  end
end

function Duplicate_area()
  if copy then return end -- DO NOT ALLOW DUPLICATE IN COPY MODE
  local tbl = Get_area_table()
  Area_function(tbl, "Duplicate")
end

function Del()
  local tbl = Get_area_table()
  Area_function(tbl, "Delete")
end

function As_split()
  local tbl = Get_area_table()
  Area_function(tbl, "Split")
end


function Select_as(num)
  if not copy then return end
  local tbl = Get_area_table("Areas")
  local CPY_TBL = Get_area_table("Copy")
  local active_as = tbl[num] and tbl[num] or nil

  if prev_area ~= active_as then
    if prev_area ~= nil then
      reaper.JS_LICE_AlterBitmapHSV( prev_area, 0, 0, -0.5)  -- revert to original
      prev_area = nil
    end
  end

  if active_as and CPY_TBL[num].bm ~= prev_area then
    reaper.JS_LICE_AlterBitmapHSV( CPY_TBL[num].bm, 0, 0, 0.5) -- increase , high light
    prev_area = CPY_TBL[num].bm
  end
  Ghost_unlink_or_destroy(tbl, "Unlink", "area")
  Set_active_as(active_as)
  GHOST_UPDATE = 1
  AREAS_UPDATE = 1
end

