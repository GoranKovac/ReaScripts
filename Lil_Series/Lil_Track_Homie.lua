-- @description Lil Track Homie
-- @author Sexan
-- @license GPL v3
-- @version 1.15
-- @changelog
--   Add backward compatibility for latest imgui

local reaper = reaper
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.9.3')
local floor = math.floor
local max = math.max
local abs = math.abs
local exp = math.exp
local log = math.log

function Round(num) return floor(num + 0.5) end

local start_time = reaper.time_precise()
local key_state, KEY = reaper.JS_VKeys_GetState(start_time - 2), nil
for i = 1, 255 do
    if key_state:byte(i) ~= 0 then
        KEY = i; reaper.JS_VKeys_Intercept(KEY, 1)
    end
end
if not KEY then return end
local cur_pref = reaper.SNM_GetIntConfigVar("alwaysallowkb", 1)
reaper.SNM_SetIntConfigVar("alwaysallowkb", 1)

function Key_held()
    key_state = reaper.JS_VKeys_GetState(start_time - 2)
    return key_state:byte(KEY) == 1
end

function Release()
    reaper.JS_VKeys_Intercept(KEY, -1)
    reaper.SNM_SetIntConfigVar("alwaysallowkb", cur_pref)
end

function Handle_errors(err)
    reaper.ShowConsoleMsg(err .. '\n' .. debug.traceback())
    Release()
end

local ctx = reaper.ImGui_CreateContext('My script', reaper.ImGui_ConfigFlags_NoSavedSettings())
local size = reaper.GetAppVersion():match('OSX') and 12 or 14
local font = reaper.ImGui_CreateFont('sans-serif', size)
reaper.ImGui_Attach(ctx, font)

local dB_step = 0.2

local dbg = true

function MSG(m) if dbg then reaper.ShowConsoleMsg(tostring(m) .. "\n") end end

-- Justin's functions ----------------------------------------
function VAL2DB(x)
    if x < 0.0000000298023223876953125 then
        x = -150
    else
        x = max(-150, log(x) * 8.6858896380650365530225783783321)
    end
    return x
end

function DB2VAL(x)
    return exp(x * 0.11512925464970228420089957273422)
end

local mx, my = reaper.GetMousePosition()
local mouse_track = reaper.GetTrackFromPoint(mx, my)

local tracks = {}
for i = 1, reaper.CountSelectedTracks(0) do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(0, i - 1)
end

if mouse_track then
    if #tracks == 1 then tracks[1] = mouse_track end
end


--local bgr_or_rgb = reaper.GetTrackColor(tracks[1]) -- byte order is platform-dependent
--local rgb = reaper.ImGui_ColorConvertNative(bgr_or_rgb)
--local rgba = (rgb << 8) | 0x33 -- 100% opacity

function Fader(val, vertical)
    for i = 1, #tracks do
        local vol, rv = reaper.GetMediaTrackInfo_Value(tracks[i], 'D_VOL')
        local dB_val = VAL2DB(abs(vol))
        --local vertical, horizontal = reaper.ImGui_GetMouseWheel(ctx)

        if dB_val < -90 then
            dB_step = 5   -- < -90 dB
        elseif dB_val < -60 then
            dB_step = 3   -- from -90 to -60 dB
        elseif dB_val < -45 then
            dB_step = 2   -- from -60 to -45 dB
        elseif dB_val < -30 then
            dB_step = 1.5 -- from -45 to -30 dB
        elseif dB_val < -18 then
            dB_step = 1   -- from -30 to -18 dB
        elseif dB_val < 24 then
            dB_step = 0.5 -- from -18 to 24 dB
        end

        if vertical and vertical ~= 0 then
            local add_vol = (vertical * dB_step)
            local new_vol = dB_val + add_vol > -150 and dB_val + add_vol or -151
            new_vol = new_vol > 12 and 12 or new_vol
            local value = DB2VAL(new_vol)
            --local final_val = knob_val and knob_val or value
            reaper.SetMediaTrackInfo_Value(tracks[i], "D_VOL", value)
        end
        if val then reaper.SetMediaTrackInfo_Value(tracks[i], "D_VOL", 1) end
    end
end

local pan_step = 0.05
function Pan(knob_val, vertical, type)
    for i = 1, #tracks do
        local cur_val = reaper.GetMediaTrackInfo_Value(tracks[i], type)
        if vertical and vertical ~= 0 then
            local add_vol = (vertical * pan_step)
            local new_val = cur_val + add_vol
            new_val = new_val > 1 and 1 or new_val
            new_val = new_val < -1 and -1 or new_val
            reaper.SetMediaTrackInfo_Value(tracks[i], type, new_val)
        elseif knob_val then
            local new_val = cur_val + knob_val
            new_val = new_val > 1 and 1 or new_val
            new_val = new_val < -1 and -1 or new_val
            reaper.SetMediaTrackInfo_Value(tracks[i], type, new_val)
        end
    end
end

local function MyKnob(label, p_value, v_min, v_max)
    local radius_outer = 20.0
    local pos = { reaper.ImGui_GetCursorScreenPos(ctx) }
    local center = { pos[1] + radius_outer, pos[2] + radius_outer }
    local line_height = reaper.ImGui_GetTextLineHeight(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local item_inner_spacing = { reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing()) }
    local mouse_delta = { reaper.ImGui_GetMouseDelta(ctx) }

    local ANGLE_MIN = 3.141592 * 0.75
    local ANGLE_MAX = 3.141592 * 2.25

    reaper.ImGui_InvisibleButton(ctx, label, radius_outer * 2, radius_outer * 2 + line_height + item_inner_spacing[2])
    local value_changed = false
    local is_active = reaper.ImGui_IsItemActive(ctx)
    local is_hovered = reaper.ImGui_IsItemHovered(ctx)
    if is_active and (mouse_delta[2] ~= 0.0 or mouse_delta[1] ~= 0.0) then
        --local val_step = p_value >= 0 and 1800 or 400
        local step = (v_max - v_min) / 300
        p_value = p_value - (mouse_delta[2] * step - mouse_delta[1] * step)
        if p_value < v_min then p_value = v_min end
        if p_value > v_max then p_value = v_max end
        value_changed = true
    end

    local t = (p_value - v_min) / (v_max - v_min)
    --local t = p_value < 0 and ((p_value - v_min) / -v_min / 2) or ((p_value / v_max * 0.5) + 0.5)
    local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
    local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
    local radius_inner = radius_outer * 0.40
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
        reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_FrameBg()), 16)
    reaper.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos * radius_inner, center[2] + angle_sin * radius_inner,
        center[1] + angle_cos * (radius_outer - 2), center[2] + angle_sin * (radius_outer - 2),
        reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_SliderGrabActive()), 2.0)
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner,
        reaper.ImGui_GetColor(ctx,
            is_active and reaper.ImGui_Col_FrameBgActive() or is_hovered and reaper.ImGui_Col_FrameBgHovered() or
            reaper.ImGui_Col_FrameBg()), 16)
    reaper.ImGui_DrawList_AddText(draw_list, pos[1], pos[2] + radius_outer * 2 + item_inner_spacing[2],
        reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_Text()), label)

    if is_active or is_hovered then
        local window_padding = { reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding()) }
        reaper.ImGui_SetNextWindowPos(ctx, pos[1] - window_padding[1] + 3,
            pos[2] - line_height - item_inner_spacing[2] - window_padding[2] + 82)
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_Text(ctx, ('%.2f' .. "dB"):format(p_value))
        reaper.ImGui_EndTooltip(ctx)
    end

    return value_changed, p_value
end

function TextCentered(string)
    local windowWidth = reaper.ImGui_GetWindowSize(ctx)
    local textWidth = reaper.ImGui_CalcTextSize(ctx, string)
    reaper.ImGui_SetCursorPosX(ctx, (windowWidth - textWidth) * 0.5);
    reaper.ImGui_Text(ctx, string);
end

function Draw_Color_Rect(color)
    local button_col = color == "yellow" and 0xFFFF0077 or (color == "red" and 0xFF000077 or 0x00FF0077)
    local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
    local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    reaper.ImGui_DrawList_AddRectFilled(draw_list, min_x, min_y, max_x, max_y, button_col)
end

local img_x, img_y = reaper.ImGui_PointConvertNative(ctx, reaper.GetMousePosition())
reaper.ImGui_SetNextWindowPos(ctx, img_x - 25, img_y - 65)
function GUI()
    if not Key_held() then
        return
    end
    if next(tracks) == nil then
        terminateScript = true
        return
    end
    local vol = reaper.GetMediaTrackInfo_Value(tracks[1], 'D_VOL')
    local rv, buf = reaper.GetTrackName(tracks[1])
    local pan_mode = reaper.GetMediaTrackInfo_Value(tracks[1], "I_PANMODE")
    local vertical, horizontal = reaper.ImGui_GetMouseWheel(ctx)

    local tr_name = #tracks == 1 and buf or "MULTI-TR"
    --reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), rgba)
    reaper.ImGui_PushFont(ctx, font)
    if reaper.ImGui_Begin(ctx, 'FADER', false, reaper.ImGui_WindowFlags_NoDecoration() | reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        TextCentered(tr_name)
        if pan_mode == 5 or pan_mode == 6 then
            local p1, p2
            local L_PAN = pan_mode == 6 and "D_DUALPANL" or "D_PAN"
            local D_PAN = pan_mode == 6 and "D_DUALPANR" or "D_WIDTH"
            if pan_mode == 6 then
                p1_old = reaper.GetMediaTrackInfo_Value(tracks[1], "D_DUALPANL")
                p2_old = reaper.GetMediaTrackInfo_Value(tracks[1], "D_DUALPANR")
            elseif pan_mode == 5 then
                p1_old = reaper.GetMediaTrackInfo_Value(tracks[1], "D_PAN")
                p2_old = reaper.GetMediaTrackInfo_Value(tracks[1], "D_WIDTH")
            end
            reaper.ImGui_SetNextItemWidth(ctx, 44)
            RVD1, p1 = reaper.ImGui_SliderDouble(ctx, '##pan1', p1_old, -1, 1, '%.2f')
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, reaper.ImGui_MouseButton_Left()) then
                RESET = true
            elseif reaper.ImGui_IsItemDeactivated(ctx) and RESET then
                for i = 1, #tracks do
                    reaper.SetMediaTrackInfo_Value(tracks[i], L_PAN, 0)
                end
                RESET = nil
            end
            if reaper.ImGui_IsItemHovered(ctx) then Pan(nil, vertical, L_PAN) end
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, 44)
            RVD2, p2 = reaper.ImGui_SliderDouble(ctx, '##pan2', p2_old, -1, 1, '%.2f')
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, reaper.ImGui_MouseButton_Left()) then
                RESET = true
            elseif reaper.ImGui_IsItemDeactivated(ctx) and RESET then
                for i = 1, #tracks do
                    reaper.SetMediaTrackInfo_Value(tracks[i], D_PAN, 0)
                end
                RESET = nil
            end
            if reaper.ImGui_IsItemHovered(ctx) then Pan(nil, vertical, D_PAN) end
            if RVD2 and not RESET then
                local pan_delta = p2 - p2_old
                Pan(pan_delta, nil, D_PAN)
                --local mouse_delta = { reaper.ImGui_GetMouseDelta(ctx) }
                --if mouse_delta[2] ~= 0 or mouse_delta[1] ~= 0 then
                --    local delta = mouse_delta[1] - mouse_delta[2]
                --    Pan(nil, delta, D_PAN)
                --end
            elseif RVD1 and not RESET then
                local pan_delta = p1 - p1_old
                Pan(pan_delta, nil, L_PAN)
                --local mouse_delta = { reaper.ImGui_GetMouseDelta(ctx) }
                --if mouse_delta[2] ~= 0 or mouse_delta[1] ~= 0 then
                --    local delta = mouse_delta[1] - mouse_delta[2]
                --    Pan(nil, delta, L_PAN)
                --end
            end
        else
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            local old_pan = reaper.GetMediaTrackInfo_Value(tracks[1], "D_PAN")
            RVS, pan = reaper.ImGui_SliderDouble(ctx, '##pan', old_pan, -1, 1, '%.2f')
            if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, reaper.ImGui_MouseButton_Left()) then
                RESET = true
            elseif reaper.ImGui_IsItemDeactivated(ctx) and RESET then
                for i = 1, #tracks do
                    reaper.SetMediaTrackInfo_Value(tracks[i], "D_PAN", 0)
                end
                RESET = nil
            end
            if RVS and not RESET then
                local pan_delta = pan - old_pan
                Pan(pan_delta, nil, "D_PAN")
                -- local mouse_delta = { reaper.ImGui_GetMouseDelta(ctx) }
                --if mouse_delta[2] ~= 0 or mouse_delta[1] ~= 0 then
                --     local delta = mouse_delta[1] - mouse_delta[2]
                --Pan(pan_delta, nil, "D_PAN")
                -- end
            end
            if reaper.ImGui_IsItemHovered(ctx) then Pan(nil, vertical, "D_PAN") end
        end
        reaper.ImGui_BeginGroup(ctx)
        vol = VAL2DB(vol)
        RVK, vol = MyKnob('VOL', vol or 0, -150, 12)
        if reaper.ImGui_IsItemHovered(ctx) then
            if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then Fader(0) end
            Fader(nil, vertical)
        end
        if RVK then
            local mouse_delta = { reaper.ImGui_GetMouseDelta(ctx) }
            if mouse_delta[2] ~= 0 or mouse_delta[1] ~= 0 then
                local delta = mouse_delta[1] - mouse_delta[2]
                Fader(nil, delta)
            end
        end
        reaper.ImGui_EndGroup(ctx)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_BeginGroup(ctx)
        local solo = reaper.GetMediaTrackInfo_Value(tracks[1], "I_SOLO")
        if reaper.ImGui_Button(ctx, "S", 20, 25) then
            local toggle_solo = solo == 1 and 0 or 1
            for i = 1, #tracks do
                reaper.SetMediaTrackInfo_Value(tracks[i], "I_SOLO", toggle_solo)
            end
        end
        if solo == 1 then Draw_Color_Rect("yellow") end
        --reaper.ImGui_SameLine(ctx)
        local mute = reaper.GetMediaTrackInfo_Value(tracks[1], "B_MUTE")
        if reaper.ImGui_Button(ctx, "M", 20, 25) then
            local toggle_mute = mute == 1 and 0 or 1
            for i = 1, #tracks do
                reaper.SetMediaTrackInfo_Value(tracks[i], "B_MUTE", toggle_mute)
            end
        end
        if mute == 1 then Draw_Color_Rect("red") end
        reaper.ImGui_EndGroup(ctx)
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) - 3)
        reaper.ImGui_BeginGroup(ctx)
        local fx = reaper.TrackFX_GetChainVisible(tracks[1]) --reaper.TrackFX_GetOpen(tracks[1], 0)
        local fx_enable = reaper.GetMediaTrackInfo_Value(tracks[1], "I_FXEN")
        if reaper.ImGui_Button(ctx, "FX", 25, 32) then
            local toggle_fx_open = fx == (-1 or 0) and 1 or 0
            reaper.TrackFX_Show(tracks[1], 0, toggle_fx_open)
        end
        if reaper.TrackFX_GetCount(tracks[1]) ~= 0 and fx_enable == 1 then
            Draw_Color_Rect("green")
        elseif fx_enable == 0 then
            Draw_Color_Rect("red")
        end
        reaper.ImGui_SetCursorPosY(ctx, reaper.ImGui_GetCursorPosY(ctx) - 3)
        if reaper.ImGui_Button(ctx, "ON", 25, 20) then
            local toggle_fx = fx_enable == 1 and 0 or 1
            for i = 1, #tracks do
                reaper.SetMediaTrackInfo_Value(tracks[i], "I_FXEN", toggle_fx)
            end
        end
        if fx_enable == 0 then Draw_Color_Rect("red") else Draw_Color_Rect("green") end
        reaper.ImGui_EndGroup(ctx)
        reaper.ImGui_End(ctx)
    end
    reaper.ImGui_PopFont(ctx)

    --reaper.ImGui_PopStyleColor(ctx)
    reaper.defer(function() xpcall(GUI, Handle_errors) end)
end

reaper.defer(function() xpcall(GUI, Handle_errors) end)
reaper.atexit(Release)
