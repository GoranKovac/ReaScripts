--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.03
	 * NoIndex: true
--]]
local reaper = reaper
local gfx = gfx
local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
-- local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW
local track_window = reaper.JS_Window_FindEx( main_wnd, main_wnd, "REAPERTCPDisplay", "" )
local BUTTON_UPDATE
local mouse
local Element = {}

local menu_options = {
    [1] = { name = "",                      fname = "" },
    [2] = { name = "Create New Variant",    fname = "CreateNew" },
    [3] = { name = "Duplicate Variant",     fname = "Duplicate" },
    [4] = { name = "Delete Variant",        fname = "Delete" },
    [5] = { name = "Clear Variant",         fname = "Clear" },
    [6] = { name = "Rename Variants",       fname = "Rename" },
    [7] = { name = "Show All Variants",     fname = "ShowAll" }
}

function Get_class_tbl(tbl)
    return Element
end

local function ConcatMenuNames(track)
    local concat = ""
    local options = reaper.ValidatePtr(track, "MediaTrack*") and #menu_options or #menu_options-1
    local fimp = reaper.GetMediaTrackInfo_Value(track, "I_FREEMODE") == 2 and "!" or ""
    for i = 1, options do
        concat = concat .. (i ~= 7 and menu_options[i].name or fimp .. menu_options[i].name) .. (i ~= options and "|" or "")
    end
    return concat
end

function Show_menu(tbl)
    reaper.PreventUIRefresh(1)
    local title = "supper_awesome_mega_menu"
    gfx.init( title, 0, 0, 0, 0, 0 )
    local hwnd = reaper.JS_Window_Find( title, true )
    if hwnd then
        reaper.JS_Window_Show( hwnd, "HIDE" )
    end
    gfx.x = gfx.mouse_x
    gfx.y = gfx.mouse_y

    local gray_out = ""
    if reaper.ValidatePtr(mouse.otr, "MediaTrack*") then
        if reaper.GetMediaTrackInfo_Value(mouse.otr, "I_FREEMODE") == 2 then
            gray_out = "#"
        end
    end

    local versions = {}
    for i = 1, #tbl.info do
        versions[#versions+1] = i == tbl.idx and gray_out .. "!" .. i .. " - ".. tbl.info[i].name or gray_out .. i .. " - " .. tbl.info[i].name
    end

    menu_options[1].name = ">" .. math.floor(tbl.idx) .. " Virtual TR : " .. tbl.info[tbl.idx].name .. "|" .. table.concat(versions, "|") .."|<|"

    local m_num = gfx.showmenu(ConcatMenuNames(mouse.otr))

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

function Element:new(x, y, w, h, rprobj, info)
    local elm = {}
    elm.x, elm.y, elm.w, elm.h = x, y, w, h
    elm.rprobj, elm.bm = rprobj, reaper.JS_LICE_CreateBitmap(true, elm.w, elm.h)
    reaper.JS_LICE_Clear(elm.bm, 0x66002244)
    elm.info = info
    elm.idx = 1;
    setmetatable(elm, self)
    self.__index = self
    return elm
end

function Element:update_xywh()
    self.y = Get_TBH_Info(self.rprobj)
    local retval, left, top, right, bottom = reaper.JS_Window_GetClientRect( track_window )
    self.x = (right - left) - 10 - self.w
    self:draw(1,1)
end

function Element:draw(w,h)
    if Get_TBH_Info()[self.rprobj].vis then
        reaper.JS_Composite(track_window, self.x, self.y, self.w, self.h, self.bm, 0, 0, w, h, true)
    else
        reaper.JS_Composite_Unlink(track_window, self.bm, true)
    end
end

function Element:pointIN(sx, sy)
    local x, y = To_client(sx, sy)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Element:mouseIN()
    return mouse.l_down == false and self:pointIN(mouse.x, mouse.y)
end

function Element:mouseDown()
    return mouse.l_down and self:pointIN(mouse.ox, mouse.oy)
end

function Element:mouseUp()
    return mouse.l_up --and self:pointIN(mouse.ox, mouse.oy)
end

function Element:mouseClick()
    return mouse.l_click and self:pointIN(mouse.ox, mouse.oy)
end

function Element:mouseR_Down()
    return mouse.r_down and self:pointIN(mouse.ox, mouse.oy)
end

function Element:mouseM_Down()
  --return m_state&64==64 and self:pointIN(mouse_ox, mouse_oy)
end

function Element:track()
    if not Get_TBH_Info()[self.rprobj].vis then return end
    if Window_in_front() then return end
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

local prev_Arr_end_time, prev_proj_state, last_scroll, last_scroll_b, last_pr_t, last_pr_h
local function Arrange_view_info()
    local TBH = Get_TBH_Info()
    if not TBH then return end
    local last_pr_tr = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
    local proj_state = reaper.GetProjectStateChangeCount(0) -- PROJECT STATE
    local _, scroll, _, _, scroll_b = reaper.JS_Window_GetScrollInfo(track_window, "SB_VERT") -- GET VERTICAL SCROLL
    local _, Arr_end_time = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW
    if prev_Arr_end_time ~= Arr_end_time then -- THIS ONE ALWAYS CHANGES WHEN ZOOMING IN OUT
        prev_Arr_end_time = Arr_end_time
        return true
    elseif prev_proj_state ~= proj_state then
        prev_proj_state = proj_state
        return true
    elseif last_scroll ~= scroll then
        last_scroll = scroll
        return true
    elseif last_scroll_b ~= scroll_b then
        last_scroll_b = scroll_b
        return true
    elseif last_pr_tr then -- LAST TRACK ALWAYS CHANGES HEIGHT WHEN OTHER TRACK RESIZE
        if TBH[last_pr_tr].h ~= last_pr_h or TBH[last_pr_tr].t ~= last_pr_t then
            last_pr_h = TBH[last_pr_tr].h
            last_pr_t = TBH[last_pr_tr].t
            return true
        end
    end
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