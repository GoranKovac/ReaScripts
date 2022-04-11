local reaper = reaper

local crash = function(errObject)
    local byLine = "([^\r\n]*)\r?\n?"
    local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
    local err = errObject and string.match(errObject, trimPath) or "Couldn't get error message."
    local trace = debug.traceback()
    local stack = {}
    for line in string.gmatch(trace, byLine) do
        local str = string.match(line, trimPath) or line
        stack[#stack + 1] = str
    end
    local name = ({ reaper.get_action_context() })[2]:match("([^/\\_]+)$")
    local ret =
    reaper.ShowMessageBox(
        name .. " has crashed!\n\n" .. "Would you like to have a crash report printed " .. "to the Reaper console?",
        "Oops",
        4
    )
    if ret == 6 then
        reaper.ShowConsoleMsg(
            "Error: " .. err .. "\n\n" ..
            "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 2) .. "\n\n" ..
            "Reaper:       \t" .. reaper.GetAppVersion() .. "\n" ..
            "Platform:     \t" .. reaper.GetOS()
        )
    end
end

function GetCrash() return crash end

local main_wnd = reaper.GetMainHwnd()
local track_window = reaper.JS_Window_FindChildByID(main_wnd, 0x3E8)
local mouse = {
    Ctrl = function() return reaper.JS_Mouse_GetState(95) & 4 == 4 end,
    Shift = function() return reaper.JS_Mouse_GetState(95) & 8 == 8 end,
    Alt = function() return reaper.JS_Mouse_GetState(95) & 16 == 16 end,
    Alt_Shift = function() return reaper.JS_Mouse_GetState(95) & 24 == 24 end,
    Ctrl_Shift = function() return reaper.JS_Mouse_GetState(95) & 12 == 12 end,
    Ctrl_Alt = function() return reaper.JS_Mouse_GetState(95) & 20 == 20 end,
    Ctrl_Shift_Alt = function() return reaper.JS_Mouse_GetState(95) & 28 == 28 end,
    cap = function(mask)
        if mask == nil then
            return reaper.JS_Mouse_GetState(95)
        end
        return reaper.JS_Mouse_GetState(95) & mask == mask
    end,
    lb_down = function() return reaper.JS_Mouse_GetState(95) & 1 == 1 end,
    rb_down = function() return reaper.JS_Mouse_GetState(95) & 2 == 2 end,
    p = nil, op = nil, dp = nil,
    tr = nil, tr_num = nil, tr_info = nil, otr = nil, otr_num = nil, otr_info = nil, dtr = {},
    env = nil, env_name = nil, oenv = nil, oenv_name = nil,
    track_range = {},
    item = nil, oitem = nil, otake = nil,
    detail = nil, odetail = nil,
    x = 0, y = 0,
    ox = 0, oy = 0,
    dx = 0, dy = 0,
    last_LMB_state = false,
    last_RMB_state = false,
    l_click = false, r_click = false,
    l_dclick = false,
    l_up = false, r_up = false,
    l_down = false, r_down = false,
}

local function OnMouseDown(lmb_down, rmb_down)
    if not rmb_down and lmb_down and mouse.last_LMB_state == false then
        mouse.last_LMB_state = true
        mouse.l_click = true
    end
    if not lmb_down and rmb_down and mouse.last_RMB_state == false then
        mouse.last_RMB_state = true
        mouse.r_click = true
    end
    mouse.track_range = {}
    mouse.ox, mouse.oy = mouse.x, mouse.y -- mouse click coordinates
    mouse.odetail, mouse.otr, mouse.otr_num, mouse.oitem, mouse.otake = mouse.detail, mouse.tr, mouse.tr_num, mouse.item, mouse.take
    mouse.op = mouse.p
    mouse.oenv = mouse.env
    mouse.oenv_name = mouse.env_name
end

local function OnMouseUp(lmb_down, rmb_down)
    mouse.uptime = os.clock()
    mouse.dx, mouse.dy = 0, 0
    if not lmb_down and mouse.last_LMB_state then mouse.last_LMB_state = false
        mouse.l_up = true
    end
    if not rmb_down and mouse.last_RMB_state then mouse.last_RMB_state = false
        mouse.r_up = true
    end
end

local function OnMouseDoubleClick()
    mouse.l_dclick = true
end

local function OnMouseHold(lmb_down, rmb_down)
    mouse.l_down = lmb_down and true
    mouse.r_down = rmb_down and true

    mouse.dx = mouse.x - mouse.ox
    mouse.dy = mouse.y - mouse.oy
    mouse.dp = mouse.p - mouse.op

    if mouse.tr_num then -- ALWAYS CAPTURE TRACK (IF WE WENT OFFSCREEN REMEMBER LAST TRACK)
        mouse.dtr = { mouse.otr_num, mouse.tr_num }
        mouse.last_tr_num = mouse.tr_num
    end
    mouse.last_x, mouse.last_y = mouse.x, mouse.y
    mouse.last_p = mouse.p
end

function Mouse_X_to_pos(x)
    local zoom_lvl = reaper.GetHZoomLevel()
    local Arr_start_time = reaper.GetSet_ArrangeView2(0, false, 0, 0)
    local cx, _ = reaper.JS_Window_ScreenToClient(track_window, x, 0)
    cx = cx >= 0 and cx or 0
    local p = (cx / zoom_lvl) + Arr_start_time
    p = reaper.GetToggleCommandState(1157) == 1 and reaper.SnapToGrid(0, p) or p
    return p
end

function Mouse()
    mouse.x, mouse.y = reaper.GetMousePosition()
    mouse.tr, mouse.detail = reaper.GetThingFromPoint(mouse.x, mouse.y)
    if mouse.detail:match("envelope") then
        mouse.env = reaper.GetTrackEnvelope(mouse.tr, tonumber(mouse.detail:match("%d+")))
        mouse.env_name = ({ reaper.GetEnvelopeName(mouse.env) })[2]
    else
        mouse.env, mouse.env_name = nil, nil
    end
    mouse.p = Mouse_X_to_pos(mouse.x)
    mouse.tr_num = mouse.tr and reaper.GetMediaTrackInfo_Value(mouse.tr, "IP_TRACKNUMBER") or nil
    mouse.item, mouse.take = reaper.GetItemFromPoint(mouse.x, mouse.y, true)
    mouse.l_click, mouse.r_click, mouse.l_dclick, mouse.l_up, mouse.r_up, mouse.l_down, mouse.r_down = false, false, false, false, false, false, false
    local LB_DOWN, RB_DOWN = mouse.lb_down(), mouse.rb_down()

    if (LB_DOWN and not RB_DOWN) or (RB_DOWN and not LB_DOWN) then
        if (mouse.last_LMB_state == false and not RB_DOWN) or (mouse.last_RMB_state == false and not LB_DOWN) then
            OnMouseDown(LB_DOWN, RB_DOWN)
            if mouse.uptime and os.clock() - mouse.uptime < 0.20 then
                OnMouseDoubleClick()
            end
        else
            OnMouseHold(LB_DOWN, RB_DOWN)
        end
    elseif not LB_DOWN and mouse.last_RMB_state or not RB_DOWN and mouse.last_LMB_state then
        OnMouseUp(LB_DOWN, RB_DOWN)
    end

    if #mouse.dtr > 1 then
        if mouse.dtr[1] and mouse.dtr[2] then
            mouse.track_range, mouse.razors = {}, {}
            local first = mouse.dtr[1] > mouse.dtr[2] and mouse.dtr[2] or mouse.dtr[1]
            local last = mouse.dtr[1] > mouse.dtr[2] and mouse.dtr[1] or mouse.dtr[2]
            for i = first, last do mouse.track_range[#mouse.track_range + 1] = reaper.CSurf_TrackFromID(i, false) end
        end
    end
    return mouse
end
