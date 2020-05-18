--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.06
	 * NoIndex: true
--]]
local reaper = reaper
local main_wnd        = reaper.GetMainHwnd()                            -- GET MAIN WINDOW
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8) -- GET TRACK VIEW

local mouse = {
	LB    = 1,
	RB    = 2,
	Ctrl  = function() return reaper.JS_Mouse_GetState(95)  &4 == 4  end,
	Shift = function() return reaper.JS_Mouse_GetState(95)  &8 == 8  end,
	Alt   = function() return reaper.JS_Mouse_GetState(95) &16 == 16 end,
	Alt_Shift = function() return reaper.JS_Mouse_GetState(95) &24 == 24 end,
	Ctrl_Shift = function() return reaper.JS_Mouse_GetState(95) &12 == 12 end,
	Ctrl_Alt = function() return reaper.JS_Mouse_GetState(95) &20 == 20 end,
	Ctrl_Shift_Alt = function() return reaper.JS_Mouse_GetState(95) &28 == 28 end,
	cap = function (mask)
			if mask == nil then 
				return reaper.JS_Mouse_GetState(95) end
			return reaper.JS_Mouse_GetState(95)&mask == mask
			end,

	lb_down = function() return reaper.JS_Mouse_GetState(95) &1 == 1 end,
	rb_down = function() return reaper.JS_Mouse_GetState(95) &2 == 2 end,
	uptime = 0,

	last_x = -1,
	last_y = -1,
	last_p = -1,

	last_tr = nil,
	last_r_t = nil,
	last_r_b = nil,

	dx = 0,
	dy = 0,
	dp = 0,

	ox = 0,
	oy = 0,
	op = 0,
	otr = nil,
	ort = 0,
	orb = 0,

	tr = nil,
	x = 0,
	y = 0,
	p = 0,
	r_t = 0,
	r_b = 0,

	detail = false,

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
	mouse.detail    = false
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
	mouse.dp = mouse.p - mouse.op

	mouse.last_x, mouse.last_y, mouse.last_p = mouse.x, mouse.y, mouse.p
	if mouse.tr then
		mouse.last_r_t, mouse.last_r_b = mouse.r_t, mouse.r_b
		mouse.last_tr = mouse.tr
	end
end

function X_to_pos(x)
	local zoom_lvl = reaper.GetHZoomLevel() -- HORIZONTAL ZOOM LEVEL
	local Arr_start_time = reaper.GetSet_ArrangeView2(0, false, 0, 0) -- GET ARRANGE VIEW
	local cx, _ = reaper.JS_Window_ScreenToClient( track_window, x, 0)

	cx = cx >= 0 and cx or 0

	local p = (cx / zoom_lvl) + Arr_start_time
	p = reaper.GetToggleCommandState(1157) == 1 and reaper.SnapToGrid(0, p) or p
	return p
end

function MouseInfo(x,y,p)
	mouse.x, mouse.y = reaper.GetMousePosition()
	mouse.p = X_to_pos(mouse.x)
	if mouse.tr then mouse.last_tr = mouse.tr end

	local m_cx, m_cy = reaper.JS_Window_ScreenToClient( track_window, mouse.x, mouse.y )

	--ARRANGE = ((mouse.l_down) and (mouse.ox >= sx and Check_val_for_os(mouse.oy, sy)) and mouse.otr) and true or false
	ARRANGE = ((mouse.l_down) and mouse.otr) and true or false--((mouse.l_down) and (m_cx >= 0 and m_cy >= 0) and mouse.otr) and true or false
	--ARRANGE = ((mouse.l_down) and (mouse.ox >= sx and mouse.oy >= sy) and mouse.otr) and true or false 		------ FOR OSX OY NEEDS TO BE LESS THAN SCREEN Y (mouse.oy <= sy) ----------------------------------
	mouse.DRAW_AREA = mouse.Ctrl_Shift() or mouse.Ctrl_Shift_Alt()  and true or false
	mouse.l_click   = false
	mouse.r_click   = false
	mouse.l_dclick  = false
	mouse.l_up      = false
	mouse.r_up      = false
	mouse.l_down    = false
	mouse.r_down    = false
	local LB_DOWN = mouse.lb_down()           -- Get current left mouse button state
	local RB_DOWN = mouse.rb_down()           -- Get current right mouse button state

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

	return mouse
end

local prevTime = 0 -- or script start time
function Pass_thru()
   if mouse.l_down then
      if not BLOCK then
		 if not mouse.Ctrl_Shift_Alt() and not mouse.Ctrl_Shift() then
			if WINDOW_IN_FRONT or check_window_in_front() then return end
			local pOK, pass, time, wLow, wHigh, lLow, lHigh = reaper.JS_WindowMessage_Peek(track_window, "WM_LBUTTONDOWN")
			local pOK1, pass1, time1, wLow1, wHigh1, lLow1, lHigh1 = reaper.JS_WindowMessage_Peek(track_window, "WM_LBUTTONDBLCLK")
            if pOK and time > prevTime then
               prevTime = time
			   reaper.JS_WindowMessage_Post(track_window, "WM_LBUTTONDOWN", wLow, wHigh, lLow, lHigh)
			   reaper.JS_WindowMessage_Post(track_window, "WM_LBUTTONDBLCLK", wLow1, wHigh1, lLow1, lHigh1)
            end
         end
      end
   end
end