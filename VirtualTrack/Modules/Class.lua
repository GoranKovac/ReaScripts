--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.08
	 * NoIndex: true
--]]
local reaper = reaper

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
local image_path = script_folder:gsub("[\\|/]Modules", "") .. "Images/VT_icon_empty.png"

local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8)
local BUTTON_UPDATE, mouse
local Element = {}

function Get_class_tbl(tbl) return Element end

function Element:new(rprobj, info, direct)
    local elm = {}
    elm.rprobj = rprobj
    elm.bm = reaper.JS_LICE_LoadPNG(image_path)
    elm.x, elm.y, elm.w, elm.h = 0, 0, reaper.JS_LICE_GetWidth(elm.bm), reaper.JS_LICE_GetHeight(elm.bm)
    elm.font_bm = direct == 0 and reaper.JS_LICE_CreateBitmap(true, elm.w, elm.h) or nil-- CREATE ONLY WHEN NECESSARY
    elm.font = direct == 0 and reaper.JS_LICE_CreateFont() or nil-- CREATE ONLY WHEN NECESSARY
    if elm.font then reaper.JS_LICE_SetFontColor(elm.font, 0xFFFFFFFF) end -- CREATE ONLY WHEN NECESSARY
    if elm.font_bm then reaper.JS_LICE_Clear(self.font_bm, 0x00000000) end -- CREATE ONLY WHEN NECESSARY
    elm.info = info
    elm.idx = 1
    elm.comp_idx = 0
    elm.lane_mode = 0
    elm.def_icon = nil
    elm.group = 0
    setmetatable(elm, self)
    self.__index = self
    return elm
end

function Element:cleanup()
    if self.bm then reaper.JS_LICE_DestroyBitmap(self.bm) end
    self.bm = nil
    if self.font_bm then reaper.JS_LICE_DestroyBitmap(self.font_bm) end
    self.font_bm = nil
    if self.font then reaper.JS_LICE_DestroyFont(self.font) end
    self.font = nil
end

function Element:update_xywh()
    local y, h = Get_TBH_Info(self.rprobj)
    self.y = math.floor(y + h/4) + 15
    self:draw()
end

function Element:draw_text()
    reaper.JS_LICE_Clear(self.font_bm, 0x00000000)
    reaper.JS_LICE_Blit(self.font_bm, 0, 0, self.bm, 0, 0, self.w, self.h, 1, "ADD")
    reaper.JS_LICE_DrawText(self.font_bm, self.font, math.floor(self.idx) .."/".. #self.info, 3, 0, 1, 80, 80)
end

function Element:draw()
    if Get_TBH()[self.rprobj].vis then
        self:draw_text()
        reaper.JS_Composite(track_window, self.x, self.y, self.w, self.h, self.font_bm, 0, 0, self.w, self.h, true)
    else
        reaper.JS_Composite_Unlink(track_window, self.font_bm, true)
    end
end

function Element:ButtonIn(sx, sy)
    local x, y = To_client(sx, sy)
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Element:LaneButtonIn(sx, sy)
    if not mouse.lane then return end
    local x, y = To_client(sx, sy)
    local t, h = Get_TBH_Info(self.rprobj)
    local lane_button_w, lane_button_h = 28, 13
    local lane_button_t = (h - 14) / #self.info
    local lane_box_h = lane_button_t * (mouse.lane-1)
    return x > 0 and x <= lane_button_w and y >= t + lane_box_h and y <= t + lane_box_h + lane_button_h
end

function Element:mouseIN()
    return mouse.l_down == false and self:ButtonIn(mouse.x, mouse.y)
end

function Element:mouseDown()
    return mouse.l_down and self:ButtonIn(mouse.ox, mouse.oy)
end

function Element:mouseUp()
    return mouse.l_up --and self:ButtonIn(mouse.ox, mouse.oy)
end

function Element:mouseClick()
    return mouse.l_click and self:ButtonIn(mouse.ox, mouse.oy)
end

function Element:LanemouseDClick()
    return mouse.l_dclick and self:LaneButtonIn(mouse.ox, mouse.oy)
end

function Element:mouseR_Down()
    return mouse.r_down and self:ButtonIn(mouse.ox, mouse.oy)
end

function Element:mouseM_Down()
  --return m_state&64==64 and self:ButtonIn(mouse_ox, mouse_oy)
end

function Element:track()
    if not Get_TBH()[self.rprobj].vis then return end
    --if self:LanemouseDClick() then Mute_view(self, self.idx)end
    --if self:LanemouseClick() then PT_COMP_TEST()end
    if self:mouseClick() then Show_menu(self.rprobj) end
end

local function Track(tbl)
    if Window_in_front() then return end
    for _, track in pairs(tbl) do track:track() end
end

local function Update_BTNS(tbl, update)
    if not update then return end
    for _, track in pairs(tbl) do track:update_xywh() end
end

function Draw(tbl)
    mouse = MouseInfo()
    Track(tbl)
    local reaper_arrange_updated = Arrange_view_info() or UPDATE_DRAW
    BUTTON_UPDATE = reaper_arrange_updated and true
    Update_BTNS(tbl, BUTTON_UPDATE)
    BUTTON_UPDATE = false
    UPDATE_DRAW = false
end

function SetUpdateDraw()
    UPDATE_DRAW = true
end