--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.07
	 * NoIndex: true
--]]
local reaper = reaper
local gfx = gfx

local script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
local image_path = script_folder:gsub("\\Modules", "") .. "Images/VT_icon_empty.png"

local main_wnd = reaper.GetMainHwnd() -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8)
local BUTTON_UPDATE, mouse
local Element = {}

local function GetMenuTBL()
    local menu = {
        [1] = { name = "",                      fname = "" },
        [2] = { name = "Create New Variant",    fname = "CreateNew" },
        [3] = { name = "Duplicate Variant",     fname = "Duplicate" },
        [4] = { name = "Delete Variant",        fname = "Delete" },
        [5] = { name = "Clear Variant",         fname = "Clear" },
        [6] = { name = "Rename Variants",       fname = "Rename" },
        [7] = { name = "Show All Variants",     fname = "ShowAll" }
    }
    return menu
end

function Get_class_tbl(tbl) return Element end

local function MakeMenu(tbl)
    local menu_options = GetMenuTBL()
    local concat, main_name, lane_mode = "", "", nil
    if reaper.ValidatePtr(tbl.rprobj, "MediaTrack*") then
        main_name = "MAIN Virtual TR : "
        if reaper.GetMediaTrackInfo_Value(tbl.rprobj, "I_FREEMODE") == 2 then
            lane_mode = true
            menu_options[7].name = "!" .. menu_options[7].name
        end
    elseif reaper.ValidatePtr(tbl.rprobj, "TrackEnvelope*") then
        main_name = "MAIN Virtual ENV : "
        table.remove(menu_options, 7) -- REMOVE "ShowAll" KEY IF ENVELOPE
    end
    local version_id = lane_mode and Unmuted_lane(tbl) or tbl.idx
    local versions = {}
    for i = 1, #tbl.info do
        versions[#versions+1] = i == version_id and "!" .. i .. " - ".. tbl.info[i].name or i .. " - " .. tbl.info[i].name
    end

    menu_options[1].name = ">" .. main_name .. tbl.info[tbl.idx].name .. "|" .. table.concat(versions, "|") .."|<|"

    for i = 1, #menu_options do
        concat = concat .. menu_options[i].name .. (i ~= #menu_options and "|" or "")
    end
    return concat, menu_options, lane_mode
end

local function Update_tempo_map()
    if reaper.CountTempoTimeSigMarkers(0) then
        local retval, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, 0)
        reaper.SetTempoTimeSigMarker(0, 0, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo)
    end
    reaper.UpdateTimeline()
end

local function CreateGFXWindow()
    local title = "supper_awesome_mega_menu"
    gfx.init( title, 0, 0, 0, 0, 0 )
    local hwnd = reaper.JS_Window_Find( title, true )
    if hwnd then
        reaper.JS_Window_Show( hwnd, "HIDE" )
    end
    gfx.x = gfx.mouse_x
    gfx.y = gfx.mouse_y
end

function Show_menu(tbl)
    UpdateInternalState(tbl)
    reaper.PreventUIRefresh(1)
    CreateGFXWindow()

    local update_tempo = tbl.rprobj == reaper.GetMasterTrack(0) and true or false
    tbl = tbl.rprobj == reaper.GetMasterTrack(0) and Get_VT_TB()[reaper.GetTrackEnvelopeByName( tbl.rprobj, "Tempo map" )] or tbl

    local concat_menu, menu_options, lane_mode = MakeMenu(tbl)
    local m_num = gfx.showmenu(concat_menu)

    if m_num > #tbl.info then
        m_num = (m_num - #tbl.info) + 1
        -- for the moment, all of these functions can change the state
        reaper.Undo_BeginBlock2(0)
        _G[menu_options[m_num].fname](tbl.rprobj, tbl, tbl.idx)
        StoreStateToDocument(tbl)
        reaper.Undo_EndBlock2(0, "VT: " .. menu_options[m_num].name, -1)
    else
        if m_num ~= 0 then
            reaper.Undo_BeginBlock2(0)
            if not lane_mode then
                SwapVirtualTrack(tbl.rprobj, tbl, m_num)
                StoreStateToDocument(tbl)
            else
                Mute_view(tbl, m_num) -- MUTE VIEW IS ONLY FOR PREVIEWING VERSIONS WE DO NOT SAVE ANYTHING HERE (STORE IS HAPPENING WHEN WE TOGGLE SHOW ALL VARIANTS OPTION)
            end
            reaper.Undo_EndBlock2(0, "VT: Recall Version " .. tbl.info[m_num].name, -1)
        end
    end

    UPDATE_DRAW = true
    reaper.JS_LICE_Clear(tbl.font_bm, 0x00000000)
    gfx.quit()

    reaper.PreventUIRefresh(-1)
    if update_tempo then Update_tempo_map() end
    reaper.UpdateArrange()
    UpdateChangeCount()
end

function Element:new(rprobj, info, direct)
    local elm = {}
    elm.rprobj = rprobj
    elm.bm = reaper.JS_LICE_LoadPNG(image_path)
    elm.x, elm.y, elm.w, elm.h = 0, 0, reaper.JS_LICE_GetWidth(elm.bm), reaper.JS_LICE_GetHeight(elm.bm)
    elm.font_bm = reaper.JS_LICE_CreateBitmap(true, elm.w, elm.h)
    elm.font = reaper.JS_LICE_CreateFont()
    reaper.JS_LICE_SetFontColor(elm.font, 0xFFFFFFFF)
    reaper.JS_LICE_Clear(self.font_bm, 0x00000000)
    elm.info = info
    elm.idx = 1
    setmetatable(elm, self)
    self.__index = self
    if direct == 1 then -- unused
        self:cleanup()
    end
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
    if self:mouseClick() then Show_menu(self) end
end

local function Track(tbl)
    if Window_in_front() then return end
    for _, track in pairs(tbl) do track:track() end
end

local function Update_BTNS(tbl, update)
    if not update then return end
    for _, track in pairs(tbl) do track:update_xywh() end
end

local prev_Arr_end_time, prev_proj_state, last_scroll, last_scroll_b, last_pr_t, last_pr_h
local function Arrange_view_info()
    local TBH = Get_TBH()
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
    Track(tbl)
    local reaper_arrange_updated = Arrange_view_info() or UPDATE_DRAW
    BUTTON_UPDATE = reaper_arrange_updated and true
    Update_BTNS(tbl, BUTTON_UPDATE)
    BUTTON_UPDATE = false
    UPDATE_DRAW = false
end