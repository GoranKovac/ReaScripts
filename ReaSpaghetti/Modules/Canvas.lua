--@noindex
--NoIndex: true

local r = reaper

local min, max, abs = math.min, math.max, math.abs

function InitCanvas()
    local CANVAS = {
        view_x = 0,
        view_y = 0,
        w = 0,
        h = 0,
        off_x = 100,
        off_y = 200,
        scale = 1,
        rx = 0,
        ry = 0
    }
    return CANVAS
end

function CanvasEdgeScrolling()
    if r.ImGui_IsMouseDragging(ctx, 0) and r.ImGui_IsWindowFocused(ctx) and not MARQUEE then
        EDGE_SCROLLING = { x = 0, y = 0 }
        if CANVAS.zone_L then
            CANVAS.off_x = CANVAS.off_x + EDGE_SCROLLING_SPEED
            EDGE_SCROLLING.x = 5
        end
        if CANVAS.zone_R then
            CANVAS.off_x = CANVAS.off_x - EDGE_SCROLLING_SPEED
            EDGE_SCROLLING.x = -5
        end
        if CANVAS.zone_T then
            CANVAS.off_y = CANVAS.off_y + EDGE_SCROLLING_SPEED
            EDGE_SCROLLING.y = 5
        end
        if CANVAS.zone_B then
            CANVAS.off_y = CANVAS.off_y - EDGE_SCROLLING_SPEED
            EDGE_SCROLLING.y = -5
        end
    elseif EDGE_SCROLLING and r.ImGui_IsMouseReleased(ctx, 0) then
        EDGE_SCROLLING = { x = 0, y = 0 }
    end
end

local function CanvasMouseDetection()
    CANVAS.MouseIN = (MX - CANVAS.view_x > 0 and MX - CANVAS.view_x < CANVAS.rx and MY - CANVAS.view_y > 0 and MY - CANVAS.view_y < CANVAS.ry) and
        true or false
    CANVAS.zone_L = (MX - CANVAS.view_x > 0 and MX - CANVAS.view_x < EDGE_SCROLLING_ZONE)
    CANVAS.zone_R = (MX - CANVAS.view_x < CANVAS.rx and MX - CANVAS.view_x > CANVAS.rx - EDGE_SCROLLING_ZONE)
    CANVAS.zone_T = (MY - CANVAS.view_y > 0 and MY - CANVAS.view_y < EDGE_SCROLLING_ZONE)
    CANVAS.zone_B = (MY - CANVAS.view_y < CANVAS.ry and MY - CANVAS.view_y > CANVAS.ry - EDGE_SCROLLING_ZONE)
end

local function Update()
    local FUNCTIONS              = GetFUNCTIONS()
    WIN_X, WIN_Y                 = r.ImGui_GetWindowPos(ctx)
    CANVAS                       = FUNCTIONS[CURRENT_FUNCTION].CANVAS
    MX, MY                       = r.ImGui_GetMousePos(ctx)
    CANVAS.view_x, CANVAS.view_y = r.ImGui_GetCursorScreenPos(ctx)
    DRAGX, DRAGY                 = r.ImGui_GetMouseDragDelta(ctx, nil, nil, 0)
    DX, DY                       = r.ImGui_GetMouseDelta(ctx)
    CANVAS.rx, CANVAS.ry         = r.ImGui_GetContentRegionAvail(ctx)
    CANVAS.MX, CANVAS.MY         =
        (MX - (CANVAS.view_x + CANVAS.off_x)) / CANVAS.scale,
        (MY - (CANVAS.view_y + CANVAS.off_y)) / CANVAS.scale
    CanvasMouseDetection()
end

local function UpdateScroll()
    if not IS_DRAGGING_RIGHT_CANVAS then return end
    local btn = r.ImGui_MouseButton_Right()
    if r.ImGui_IsMouseDragging(ctx, btn) then
        r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeAll())
        local drag_x, drag_y = r.ImGui_GetMouseDragDelta(ctx, nil, nil, btn)
        CANVAS.off_x, CANVAS.off_y = CANVAS.off_x + drag_x, CANVAS.off_y + drag_y
        r.ImGui_ResetMouseDragDelta(ctx, btn)
    end
end

local ZOOM_MIN, ZOOM_MAX, ZOOM_SPEED = 0.15, 1, 1 / 8
function UpdateZoom()
    if not r.ImGui_IsWindowHovered(ctx) then return end
    local new_scale = CANVAS.scale + (r.ImGui_GetMouseWheel(ctx) * ZOOM_SPEED)
    new_scale = max(ZOOM_MIN, min(ZOOM_MAX, new_scale))
    if new_scale == CANVAS.scale then return end

    local scale_diff = (new_scale / CANVAS.scale)
    local mouse_x, mouse_y = MX, MY
    mouse_x, mouse_y = mouse_x - CANVAS.view_x - CANVAS.off_x, mouse_y - CANVAS.view_y - CANVAS.off_y

    local diff_x, diff_y = mouse_x - (mouse_x * scale_diff), mouse_y - (mouse_y * scale_diff)
    CANVAS.off_x, CANVAS.off_y = CANVAS.off_x + diff_x, CANVAS.off_y + diff_y
    CANVAS.scale = new_scale
end

local function DrawGrid()
    if not GRID then return end

    local CANVAS_p0 = { r.ImGui_GetCursorScreenPos(ctx) }
    local CANVAS_sz = { r.ImGui_GetContentRegionAvail(ctx) } -- Resize CANVAS to what's available
    local CANVAS_p1 = { CANVAS_p0[1] + CANVAS_sz[1], CANVAS_p0[2] + CANVAS_sz[2] }
    local GRID_STEP = 64.0 * CANVAS.scale
    local x = math.fmod(CANVAS.off_x, GRID_STEP)
    while x < CANVAS_sz[1] do
        r.ImGui_DrawList_AddLine(DL, CANVAS_p0[1] + x, CANVAS_p0[2], CANVAS_p0[1] + x, CANVAS_p1[2], 0xc8c8c812)
        x = x + GRID_STEP
    end
    local y = math.fmod(CANVAS.off_y, GRID_STEP)
    while y < CANVAS_sz[2] do
        r.ImGui_DrawList_AddLine(DL, CANVAS_p0[1], CANVAS_p0[2] + y, CANVAS_p1[1], CANVAS_p0[2] + y, 0xc8c8c812)
        y = y + GRID_STEP
    end
end

local function Draw_MARQUEE()
    if TOOLBAR_DRAG then return end
    if MOVE_NODE then return end
    if not MARQUEE then
        if not r.ImGui_IsWindowHovered(ctx) then return end
        -- CHECK IF SHIFT IS ACTIVE BEFORE MARQUEE STARTED
        MARQUEE_SHIFT = SHIFT_DOWN
    end
    if (r.ImGui_IsItemHovered(ctx) and r.ImGui_IsItemActive(ctx)) then return end

    if r.ImGui_IsMouseDragging(ctx, 0) then
        local mpx, mpy = r.ImGui_GetMouseClickedPos(ctx, 0)
        local MQ_dx, MQ_dy = r.ImGui_GetMouseDragDelta(ctx, mpx, mpy, 0)
        MARQUEE = {
            x = (math.min(mpx, mpx + MQ_dx) - (CANVAS.view_x + CANVAS.off_x)) / CANVAS.scale,
            y = (math.min(mpy, mpy + MQ_dy) - (CANVAS.view_y + CANVAS.off_y)) / CANVAS.scale,
            w = abs(MQ_dx) / CANVAS.scale,
            h = abs(MQ_dy) / CANVAS.scale,
        }
        r.ImGui_DrawList_AddRectFilled(DL, mpx, mpy, mpx + MQ_dx, mpy + MQ_dy, 0xFFFFFF11)
        r.ImGui_DrawList_AddRect(DL, mpx, mpy, mpx + MQ_dx, mpy + MQ_dy, 0x607EAAAA)
    else
        if r.ImGui_IsMouseReleased(ctx, 0) and MARQUEE then
            MARQUEE = nil
            MARQUEE_SHIFT = nil
        end
    end
end

function UpdateZoomFont()
    if not CANVAS then return end
    local new_font_size = math.floor(ORG_FONT_SIZE * CANVAS.scale)
    if FONT_SIZE ~= new_font_size then
        if NEXT_FRAME then
            if FONT then
                r.ImGui_Detach(ctx, FONT)
                r.ImGui_Detach(ctx, FONT_CODE)
            end
            FONT = r.ImGui_CreateFont('sans-serif', new_font_size, r.ImGui_FontFlags_Bold())
            FONT_CODE = r.ImGui_CreateFont('monospace', new_font_size, r.ImGui_FontFlags_Bold())
            r.ImGui_Attach(ctx, FONT)
            r.ImGui_Attach(ctx, FONT_CODE)
            FONT_SIZE = new_font_size
            NEXT_FRAME = nil
        end
    end
end

local function CanvasMouseOperations()
    if r.ImGui_IsWindowHovered(ctx, r.ImGui_HoveredFlags_AllowWhenBlockedByPopup()) then
        if not OPEN_FM then
            if r.ImGui_IsMouseReleased(ctx, 0) and (DRAGX == 0 and DRAGY == 0) and not r.ImGui_IsAnyItemHovered(ctx) then
                if not SHIFT_DOWN and not CTRL_DOWN then
                    Deselect_all()
                end
            end
            if not IS_DRAGGING_RIGHT_CANVAS and r.ImGui_IsMouseReleased(ctx, 1) and not r.ImGui_IsAnyItemHovered(ctx) then
                -- UNFOCUS SEARCH BAR SO WE CAN RESET FILTER
                r.ImGui_SetKeyboardFocusHere(ctx)
                INSERT_NODE_DATA, SETTER_INFO = nil, nil
                MOUSE_POPUP_X, MOUSE_POPUP_Y = nil, nil
                FILTER = ''
                r.ImGui_OpenPopup(ctx, "FILTER LIST")
            end
            if IS_DRAGGING_RIGHT_CANVAS then
                if r.ImGui_IsPopupOpen(ctx, 'FILTER LIST') then
                    -- CLOSE POPUP
                    r.ImGui_SetWindowFocus(ctx)
                end
            end

            IS_DRAGGING_RIGHT_CANVAS = r.ImGui_IsMouseDragging(ctx, 1)
        end
    end
end

local function MiniMap()
    local w, h = r.ImGui_GetWindowSize(ctx)
    r.ImGui_SetNextWindowPos(ctx, w + 198, h + 200)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), 0x000000DD)
    if r.ImGui_BeginChild(ctx, "Minimap", 200, 200, 1) then
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
end

local function CheckShortcuts()
    local COPY = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl()) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_C())
    local PASTE = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl()) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_V())
    local DELETE = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Delete())
    local SEL_ALL = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl()) and r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_A())
    local F2 = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_F2())
    local HOME = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Home())
    local KEY_R = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_R())
    local KEY_Z = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Z())

    ALT_DOWN = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftAlt())
    SHIFT_DOWN = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftShift())
    CTRL_DOWN = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl())
    ESC = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape())
    ENTER = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter())
    KEYPAD_ENTER = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter())

    -- CLEAR WARNING
    if ESC then ClearNodesWarning() end

    if CTRL_DOWN and KEY_R then
        r.ImGui_SetKeyboardFocusHere(ctx)
        LEGO_MGS = {}
        BREAK_RUN = nil
        ClearNodesWarning()
        InitRunFlow()
    end

    if CTRL_DOWN and KEY_Z then
        DoUndo()
    end

    if COPY then
        if r.ImGui_IsWindowFocused(ctx) and not r.ImGui_IsAnyItemActive(ctx) then Copy() end
    end
    if PASTE then
        if r.ImGui_IsWindowFocused(ctx) and not r.ImGui_IsAnyItemActive(ctx) then Paste() end
    end
    if DELETE then
        if r.ImGui_IsWindowFocused(ctx) and not r.ImGui_IsAnyItemActive(ctx) then Delete() end
    end
    if SEL_ALL then if r.ImGui_IsWindowFocused(ctx) and not r.ImGui_IsAnyItemActive(ctx) then SelectAll() end end
    if HOME then
        if r.ImGui_IsWindowFocused(ctx) and not r.ImGui_IsAnyItemActive(ctx) then
            FLUX.to(CANVAS, 0.5, { off_x = CANVAS.rx / 2 - 100 * CANVAS.scale, off_y = CANVAS.ry / 2 }):ease(
                "cubicout")
        end
    end
    if F2 then
        local sel_nodes = CntSelNodes()
        if #sel_nodes == 1 and sel_nodes[1].type ~= "func" then
            RENAME_NODE = sel_nodes[1]
            --if not r.ImGui_IsPopupOpen(ctx, "Rename") then
            --    r.ImGui_OpenPopup(ctx, "Rename")
            --end
        end
    end
end

function CanvasLoop()
    CheckShortcuts()
    Update()
    DrawGrid()
    Draw_MARQUEE()
    CanvasEdgeScrolling()
    DrawLoop()
    --MiniMap()
    CanvasMouseOperations()
    UpdateZoom()
    UpdateScroll()
end
