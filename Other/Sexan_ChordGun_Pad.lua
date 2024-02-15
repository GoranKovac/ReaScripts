local r = reaper
local chord_gun_path = r.GetResourcePath() ..
    "/Scripts/ReaTeam Scripts/Various/pandabot_ChordGun/pandabot_ChordGun.lua"
dofile(chord_gun_path)

notes = { 'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B' };
flatNotes = { 'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B' };

gfx.quit()

local ctx = r.ImGui_CreateContext('ChordGunPad')
local draw_list = r.ImGui_GetWindowDrawList(ctx)
r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)

local WND_FLAGS = r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse()
local def_spacing_x, def_spacing_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing())

local function pdefer(func)
    reaper.defer(function()
        local status, err = xpcall(func, debug.traceback)
        if not status then
            local byLine = "([^\r\n]*)\r?\n?"
            local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
            local stack = {}
            for line in string.gmatch(err, byLine) do
                local str = string.match(line, trimPath) or line
                stack[#stack + 1] = str
            end
            r.ShowConsoleMsg(
                "Error: " .. stack[1] .. "\n\n" ..
                "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 3) .. "\n\n" ..
                "Reaper:       \t" .. r.GetAppVersion() .. "\n" ..
                "Platform:     \t" .. r.GetOS()
            )
        end
    end)
end

local buttonWidth = 80
local buttonHeight = 28
local innerSpacing = def_spacing_x
local btn_color_out = 0x25455dff --0x2d2d2dff--0x4355e6ff
local btn_color_in = 0x121212ff  --0x2d2d2dff

local RADIUS = 150
local CUR_POS = 0
local NEW_POS = 0

local items_maj = { "C", "G", "D", "A", "E", "B", "Gb", "Db", "Ab", "Eb", "Bb", "F" }
local items_min = { "Am", "Em", "Bm", "F#m", "C#m", "G#m", "Ebm", "Bbm", "Fm", "Cm", "Gm", "Dm" }

function IncreaseDecreaseBrightness(color, amt, no_alpha)
    function AdjustBrightness(channel, delta)
        if channel + delta < 255 then
            return channel + delta
        else
            return 255
        end
    end

    local alpha = color & 0xFF
    local blue = (color >> 8) & 0xFF
    local green = (color >> 16) & 0xFF
    local red = (color >> 24) & 0xFF

    red = AdjustBrightness(red, amt)
    green = AdjustBrightness(green, amt)
    blue = AdjustBrightness(blue, amt)
    alpha = no_alpha and alpha or AdjustBrightness(alpha, amt)

    return (alpha) | (blue << 8) | (green << 16) | (red << 24)
end

function DrawListButton(name, color, is_selected, is_active)
    local hovered = r.ImGui_IsItemHovered(ctx)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)
    local w, h = xe - xs, ye - ys
    local cur_col = is_selected and IncreaseDecreaseBrightness(0x3fb274ff, 60) or color
    cur_col = is_active and IncreaseDecreaseBrightness(0x4a8ee0ff, 20) or cur_col
    cur_col = hovered and IncreaseDecreaseBrightness(cur_col, 40) or cur_col
    r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, cur_col, 5)

    local label_size = r.ImGui_CalcTextSize(ctx, name)
    local font_size = r.ImGui_GetFontSize(ctx)

    local txt_x = xs + (w / 2) - (label_size / 2)
    local txt_y = ys + (h / 2) - (font_size / 2)

    r.ImGui_DrawList_AddTextEx(draw_list, nil, font_size, txt_x, txt_y, (is_active or is_selected) and 0xff or 0xFFFFFFFF,
        name)
end

local function Keys()
    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_1(), false) then
        previewScaleChordAction(1)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_2(), false) then
        previewScaleChordAction(2)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_3(), false) then
        previewScaleChordAction(3)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_4(), false) then
        previewScaleChordAction(4)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_5(), false) then
        previewScaleChordAction(5)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_6(), false) then
        previewScaleChordAction(6)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_7(), false) then
        previewScaleChordAction(7)
    elseif r.ImGui_IsKeyPressed(ctx,  r.ImGui_Key_Keypad1(), false) then
        previewScaleChordAction(1)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Keypad2(), false) then
        previewScaleChordAction(2)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Keypad3(), false) then
        previewScaleChordAction(3)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Keypad4(), false) then
        previewScaleChordAction(4)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Keypad5(), false) then
        previewScaleChordAction(5)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Keypad6(), false) then
        previewScaleChordAction(6)
    elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Keypad7(), false) then
        previewScaleChordAction(7)
    end
end

local function playScaleChord(chordNotesArray)
    stopNotesFromPlaying()

    for noteIndex = 1, #chordNotesArray do
        playMidiNote(chordNotesArray[noteIndex])
    end

    setNotesThatArePlaying(chordNotesArray)
end

function playOrInsertScaleChord2(scaleNoteIndex, chordTypeIndex)
    local actionDescription = "scale chord " ..
        scaleNoteIndex .. "  (" .. scaleChords[scaleNoteIndex][chordTypeIndex].code .. ")"
    local root = scaleNotes[scaleNoteIndex]
    local chord = scaleChords[scaleNoteIndex][chordTypeIndex]

    local octave = getOctave()
    local chordNotesArray = getChordNotesArray(root, chord, octave)

    if activeTake() ~= nil and notCurrentlyRecording() then
        startUndoBlock()

        if thereAreNotesSelected() then
            changeSelectedNotesToScaleChords(chordNotesArray)
        else
            insertScaleChord(chordNotesArray, false)
        end

        endUndoBlock(actionDescription)
    end

    playScaleChord(chordNotesArray)
    updateChordText(root, chord, chordNotesArray)
end

function ChordButtonSelected(scaleNoteIndex, chordTypeIndex)
    local selectedScaleNote = getSelectedScaleNote()
    local selectedChordType = getSelectedChordType(scaleNoteIndex)

    local chordTypeIsSelected = (tonumber(chordTypeIndex) == tonumber(selectedChordType))
    local scaleNoteIsSelected = (tonumber(scaleNoteIndex) == tonumber(selectedScaleNote))

    return chordTypeIsSelected and scaleNoteIsSelected
end

Achord_store_tbl = {}
for i = 1, #notes do
    Achord_store_tbl[i] = scaleChords
end

local minorSymbols = { 'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii' }
local majorSymbols = { 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII' }
local diminishedSymbol = 'o'
local augmentedSymbol = '+'
local sixthSymbol = '6'
local seventhSymbol = '7'

local prog = {
    ["MAJ"] = {
        ["MAJ"] = { [0] = "I", [1] = "V", [11] = "IV", [-1] = "IV" },
        ["MIN"] = { [0] = "VI", [1] = "III", [2] = "VII", [11] = "II", [-1] = "II" },
    },
    ["MIN"] = {
        ["MAJ"] = { [0] = 3, [1] = 7, [11] = 6, [-1] = 6 },
        ["MIN"] = { [0] = 1, [1] = 5, [2] = 2, [11] = 4, [-1] = 4 },
    },
}


function updateScaleDegreeHeaders2()
    for i = 1, #scaleNotes do
        local symbol = ""

        local chord = scaleChords[i][1]

        if string.match(chord.code, "major") or chord.code == '7' then
            symbol = majorSymbols[i]
        else
            symbol = minorSymbols[i]
        end

        if (chord.code == 'aug') then
            symbol = symbol .. augmentedSymbol
        end

        if (chord.code == 'dim') then
            symbol = symbol .. diminishedSymbol
        end

        if string.match(chord.code, "6") then
            symbol = symbol .. sixthSymbol
        end

        if string.match(chord.code, "7") then
            symbol = symbol .. seventhSymbol
        end
        if i > 1 then r.ImGui_SameLine(ctx) end

        r.ImGui_InvisibleButton(ctx, symbol, buttonWidth, buttonHeight / 1.5)
        DrawListButton(symbol, 0x242424ff)
    end
end

local function DrawChords()
    local scaleNoteIndex = 1
    local col = 1
    local prev_note
    updateScaleDegreeHeaders2()
    local x, y = r.ImGui_GetCursorPos(ctx)

    for note = getScaleTonicNote(), getScaleTonicNote() + 11 do
        if noteIsInScale(note) then
            for chordTypeIndex, chord in ipairs(scaleChords[scaleNoteIndex]) do
                local text = getScaleNoteName(scaleNoteIndex) .. chord['display']

                local numberOfChordsInScale = getNumberOfScaleChordsForScaleNoteIndex(scaleNoteIndex)
                local is_sel = getSelectedChordType(scaleNoteIndex) == (chordTypeIndex)
                local is_active = ChordButtonSelected(scaleNoteIndex, chordTypeIndex)
                if prev_note and prev_note ~= note then
                    x = x + buttonWidth + innerSpacing
                    r.ImGui_SetCursorPos(ctx, x, y)
                    prev_note = note
                    col = col + 1
                else
                    if not prev_note then prev_note = note end
                    r.ImGui_SetCursorPosX(ctx, x)
                end
                if chordTypeIndex > numberOfChordsInScale then
                    local chordIsInScale = false
                    if r.ImGui_InvisibleButton(ctx, text, buttonWidth, buttonHeight) then
                        setSelectedScaleNote(scaleNoteIndex)
                        setSelectedChordType(scaleNoteIndex, chordTypeIndex)
                        playOrInsertScaleChord2(scaleNoteIndex, chordTypeIndex)
                    end
                    DrawListButton(text, btn_color_in, is_sel, is_active)
                else
                    local chordIsInScale = true
                    if r.ImGui_InvisibleButton(ctx, text, buttonWidth, buttonHeight) then
                        setSelectedScaleNote(scaleNoteIndex)
                        setSelectedChordType(scaleNoteIndex, chordTypeIndex)
                        playOrInsertScaleChord2(scaleNoteIndex, chordTypeIndex)
                    end
                    DrawListButton(text, btn_color_out, is_sel, is_active)
                end
            end
            scaleNoteIndex = scaleNoteIndex + 1
        end
    end
end
function Clamp(x, min_x, max_x)
    if x < min_x then return min_x end
    if x > max_x then return max_x end
    return x
end

local last_octave = getOctave()
local last_tonic = getScaleTonicNote()
local last_scale = getScaleType()

local function MWheelInc(val, min, max, val_type)
    if r.ImGui_IsItemHovered(ctx) then
        local vertical = r.ImGui_GetMouseWheel(ctx)
        local we_val = vertical > 0 and 1 or vertical
        we_val = we_val < 0 and -1 or we_val
        if we_val ~= 0 then
            local new_val = Clamp(val - we_val, min, max)
            if val_type == "TONIC" then
                setScaleTonicNote(new_val)
                updateScaleData()


                for j = 0, #items_maj - 1 do
                    if items_maj[j + 1] == notes[new_val] then
                        START_TIME = r.time_precise()
                        NEW_POS = -j
                    end
                end
                for j = 0, #items_min - 1 do
                    if items_min[j + 1] == notes[new_val] then
                        START_TIME = r.time_precise()
                        NEW_POS = -j
                    end
                end

                last_tonic = new_val
            elseif val_type == "SCALE" then
                setScaleType(new_val)
                updateScaleData()
                last_scale = new_val
            elseif val_type == "OCT" then
                setOctave(new_val)
                last_octave = new_val
            end
        end
    end
end

local function TopBar()
    if r.ImGui_BeginChild(ctx, "##TOPBAR", 500, 20) then
        r.ImGui_Text(ctx, "SCALE")
        r.ImGui_SameLine(ctx)
        r.ImGui_SetNextItemWidth(ctx, 45)
        if r.ImGui_BeginCombo(ctx, "##TONIC", notes[last_tonic], r.ImGui_ComboFlags_HeightLarge()) then
            for i = 1, #notes do
                if r.ImGui_Selectable(ctx, notes[i], i == last_tonic) then
                    setScaleTonicNote(i)
                    updateScaleData()

                    for j = 0, #items_maj - 1 do
                        if items_maj[j + 1] == notes[i] then
                            START_TIME = r.time_precise()
                            NEW_POS = -j
                        end
                    end
                    for j = 0, #items_min - 1 do
                        if items_min[j + 1] == notes[i] then
                            START_TIME = r.time_precise()
                            NEW_POS = -j
                        end
                    end

                    last_tonic = i
                end
            end
            r.ImGui_EndCombo(ctx)
        end
        MWheelInc(last_tonic, 1, #notes, "TONIC")
        r.ImGui_SameLine(ctx)
        r.ImGui_SetNextItemWidth(ctx, 120)
        if r.ImGui_BeginCombo(ctx, "##SCALE", scales[last_scale].name, r.ImGui_ComboFlags_HeightLarge()) then
            for i = 1, #scales do
                if r.ImGui_Selectable(ctx, scales[i].name, i == last_scale) then
                    setScaleType(i)
                    updateScaleData()
                    last_scale = i
                end
            end
            r.ImGui_EndCombo(ctx)
        end
        MWheelInc(last_scale, 1, #scales, "SCALE")
        r.ImGui_SameLine(ctx)
        r.ImGui_Text(ctx, "OCT:")
        r.ImGui_SameLine(ctx)
        r.ImGui_SetNextItemWidth(ctx, 45)
        if r.ImGui_BeginCombo(ctx, "##OCT", last_octave, r.ImGui_ComboFlags_HeightLarge()) then
            for i = -8, 8 do
                if r.ImGui_Selectable(ctx, i, i == last_octave) then
                    setOctave(i)
                    last_octave = i
                end
            end
            r.ImGui_EndCombo(ctx)
        end
        MWheelInc(last_octave, -8, 8, "OCT")
        r.ImGui_EndChild(ctx)
    end
end

local function pow(x, p) return x ^ p end
local function outCubic(t, b, c, d)
    t = t / d - 1
    return c * (pow(t, 3) + 1) + b
end

local function Anim(begin_val, end_val, duration_in_sec, call_time)
    local time = r.time_precise() - call_time
    local change = end_val - begin_val
    if time >= duration_in_sec then
        CUR_POS = end_val
        START_TIME = nil
        ANIM_STOP = true
        return end_val
    end
    return outCubic(time, begin_val, change, duration_in_sec)
end

local sin, cos, pi = math.sin, math.cos, math.pi
local btn_w, btn_h = 45, 18

function PiePopupSelectMenu(tbl, sc_type, RADIUS_MAX, aw, ah, vx, vy)
    local RADIUS_MIN = 50.0

    local center_x = vx + (aw / 2)
    local center_y = vy + (ah / 2)

    local item_arc_span = (2 * pi) / #tbl

    local ANIM = START_TIME and Anim(CUR_POS, NEW_POS, 0.2, START_TIME) or CUR_POS
    for i = 0, #tbl - 1 do
        local color = 0x555555FF
        local c_idx = i
        c_idx = i > 6 and c_idx - 12 or c_idx
        local item = i + 1
        local item_label = tbl[item]

        local item_ang_min = item_arc_span * (i - 2.02) - (item_arc_span * 0.5)
        local item_ang_max = item_arc_span * (i - 2.98) - (item_arc_span * 0.5)

        local item_ang_min_a = item_arc_span * (i - 2.02) - (item_arc_span * 0.5) + (ANIM * pi / 6)
        local item_ang_max_a = item_arc_span * (i - 2.98) - (item_arc_span * 0.5) + (ANIM * pi / 6)

        --! DYNAMIC PIE CHORD POSITION
        local pos = {
            center_x + cos((item_ang_min_a + item_ang_max_a) * 0.5) * ((RADIUS_MIN + RADIUS_MAX) * 0.8) - (btn_w * 0.5),
            center_y + sin((item_ang_min_a + item_ang_max_a) * 0.5) * ((RADIUS_MIN + RADIUS_MAX) * 0.5) - (btn_h * 0.5),
        }

        --! FOR STATIC CHORD POSITION TEXT DRAW ABOVE CHORDS
        local pos2 = {
            center_x + cos((item_ang_min + item_ang_max) * 0.5) * ((RADIUS_MIN + RADIUS_MAX) * 0.8) - (btn_w * 0.5),
            center_y + sin((item_ang_min + item_ang_max) * 0.5) * ((RADIUS_MIN + RADIUS_MAX) * 0.5) - (btn_h * 0.5),
        }

        if i == 0 or i == 1 or i == 11 or i == 2 then
            r.ImGui_SetCursorScreenPos(ctx, pos2[1] + btn_w / 2.4, pos2[2] - btn_h / 1.2)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xff)
            --r.ImGui_Text(ctx, prog[LAST_PIE_SCALE][sc_type][i])
            r.ImGui_PopStyleColor(ctx)
        end

        local t_sin = sin((item_ang_min_a + item_ang_max_a) * 0.5)
        local t_cos = cos((item_ang_min_a + item_ang_max_a) * 0.5)

        if t_sin <= -0.49 then
            if t_cos < 0.87 and t_cos > -0.7 then
                if sc_type == "MAJ" and t_sin > -0.8 then
                    --! SKIP MAJOR CHORD
                else
                    -- color = LAST_PIE_SCALE == sc_type and 0xff00ffff or 0xff00ffaa
                end
            end
        elseif t_sin <= 1 and t_sin > 0.8 then
            -- color = LAST_PIE_SCALE == sc_type and 0x00aaaaff or 0x00aaaaaa
        end

        r.ImGui_SetCursorScreenPos(ctx, pos[1], pos[2])
        if r.ImGui_InvisibleButton(ctx, "##2" .. i .. sc_type, btn_w, btn_h) then
            setScaleTonicNote(i + 1)
            updateScaleData()
            last_tonic = i + 1
            --! PLAY CHORD ON PRESS
            -- local note = sc_type == "MIN" and item_label:sub(1, -2) or item_label
            -- onChordRootChange(note)
        end

        local hovered = r.ImGui_IsItemHovered(ctx)
        DrawListButton(item_label, color, hovered)
    end
    --r.ImGui_SetCursorScreenPos(ctx, center_x - 20, center_y)
    --! NOT SURE IF CHANGING KEY FROM HERE IS NEEDED
    -- if r.ImGui_Button(ctx, "-") and ANIM_STOP then
    --   START_TIME = r.time_precise()
    --   NEW_POS = CUR_POS + 1
    -- end
    -- r.ImGui_SameLine(ctx)
    -- if r.ImGui_Button(ctx, "+") and ANIM_STOP then
    --   START_TIME = r.time_precise()
    --   NEW_POS = CUR_POS - 1
    -- end
end

local function Gui()
    TopBar()
    local x, y = r.ImGui_GetCursorPos(ctx)
    DrawChords(x, y)
    r.ImGui_SameLine(ctx)
    r.ImGui_SetCursorPosY(ctx, y)
    if r.ImGui_BeginChild(ctx, "CIRCLE_OF5", 400, 400) then
        local vx, vy = r.ImGui_GetCursorScreenPos(ctx)
        local aw, ah = r.ImGui_GetContentRegionAvail(ctx)

        local sel_maj = PiePopupSelectMenu(items_maj, "MAJ", RADIUS, aw, ah, vx, vy)
        local sel_min = PiePopupSelectMenu(items_min, "MIN", RADIUS - 70, aw, ah, vx, vy)
        r.ImGui_EndChild(ctx)
    end
end

local function Main()
    local visible, open = r.ImGui_Begin(ctx, 'CHORD GUN PAD', true, WND_FLAGS)

    if visible then
        Gui()
        Keys()
        r.ImGui_End(ctx)
    end

    if open then
        pdefer(Main)
    end
end
r.atexit(function() end)
pdefer(Main)
