--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.02
   * NoIndex: true
--]]

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local reaper = reaper

require("Modules/VTCommon")
require("Modules/Class")
require("Modules/Mouse")
require("Modules/Utils")

Check_Requirements()

local cur_group = reaper.gmem_read(1)
local tracks = GetTrackGroup(cur_group) or {}

reaper.gmem_attach('VirtualTrack_GROUPS')

--function MSG(a) reaper.ShowConsoleMsg(a .. "\n") end

function GuiInit()
    group_list = Restore_GROUPS_FROM_Project_EXT_STATE()
    CTX = reaper.ImGui_CreateContext('VT_GROUPS') -- Add VERSION TODO
    FONT = reaper.ImGui_CreateFont('sans-serif', 15) -- Create the fonts you need
    reaper.ImGui_AttachFont(CTX, FONT)-- Attach the fonts you need
end

function ToolTip(text)
    if reaper.ImGui_IsItemHovered(CTX) then
        reaper.ImGui_BeginTooltip(CTX)
        reaper.ImGui_PushTextWrapPos(CTX, reaper.ImGui_GetFontSize(CTX) * 35.0)
        reaper.ImGui_PushTextWrapPos(CTX, 200)
        reaper.ImGui_Text(CTX, text)
        reaper.ImGui_PopTextWrapPos(CTX)
        reaper.ImGui_EndTooltip(CTX)
    end
end

function Store_GROUPS_TO_Project_EXT_STATE()
    local storedTable = { groups = group_list }
    local serialized = tableToString(storedTable)
    reaper.SetProjExtState( 0, "VirtualTrack", "GROUPS", serialized )
end

function Restore_GROUPS_FROM_Project_EXT_STATE()
    local group_list = {}
    local rv, stored = reaper.GetProjExtState( 0, "VirtualTrack", "GROUPS" )
    if rv == 1 and stored ~= nil then
        local storedTable = stringToTable(stored)
        if storedTable ~= nil then return storedTable.groups end
    end
    for i = 1, 32 do
        group_list[i] = { name = "GROUP " .. i, enabled = true }
    end
    return group_list
end

function Add_Tracks()
    local sel_tracks = {}
    local stored_tbl = Get_Stored_PEXT_STATE_TBL()
    for i = 1,  reaper.CountSelectedTracks(0) do
        local track = reaper.GetSelectedTrack(0, i - 1)
        if stored_tbl[track] then
            sel_tracks[track] = stored_tbl[track]
        end
    end
    for _, v in pairs(sel_tracks) do
        SetGroup(v, cur_group, true)
    end
    tracks = GetTrackGroup(cur_group)
end

function Main()
    local window_flags = reaper.ImGui_WindowFlags_NoResize()-- set flags here. I put an autoresize
    reaper.ImGui_SetNextWindowSize(CTX, 260, 255, reaper.ImGui_Cond_Once())-- Set the size of the windows.  Use in the 4th argument reaper.ImGui_Cond_FirstUseEver() to just apply at the first user run, so ImGUI remembers user resize s2
    reaper.ImGui_PushFont(CTX, FONT) -- Says you want to start using a specific font

    local visible, open  = reaper.ImGui_Begin(CTX, 'Virtual Tracks GROUPS', true, window_flags)

    if visible then
        -----------
        -- GUI HERE
        -----------
        reaper.ImGui_SetNextItemWidth(CTX, 147) -- OPTIONAL if you want to set docker width
        if reaper.ImGui_BeginCombo(CTX, '##docker', group_list[cur_group].name or group_list[1].name) then -- putting ## in the id section will make it without any name text in the UI
            for i = 1, #group_list do -- Iterate for each element in the combo list
                local is_selected = i == cur_group
                if reaper.ImGui_Selectable(CTX, group_list[i].name, is_selected) then --this create each of the combo item. Be carefull if they have the same name you have ID problems. This is why I put ..'##'..i at the end. try to remove it and click on repeted nameded elements.
                    cur_group = i
                    tracks = GetTrackGroup(i)
                end
            end
            reaper.ImGui_EndCombo(CTX)
        end

        reaper.ImGui_SameLine(CTX)

        RV, group_list[cur_group].enabled = reaper.ImGui_Checkbox(CTX, 'ENABLED', group_list[cur_group].enabled)
        ToolTip('Enable or disable current group')

        if reaper.ImGui_BeginListBox(CTX, '##listbox',-1) then -- -1 set width to the end of the window
            for k, v in pairs(tracks) do -- Iterate for each element in the combo list
                if reaper.ValidatePtr( k, "MediaTrack*" ) then
                    local _, buf = reaper.GetTrackName( k )
                    if reaper.ImGui_Selectable(CTX, buf..'##', v.Select) then --this create each of items. Be carefull if they have the same name you have ID problems. This is why I put ..'##'..i at the end. try to remove it and click on repeted nameded elements.
                        if (reaper.ImGui_GetKeyMods(CTX) & reaper.ImGui_KeyModFlags_Shift()) == 0 then
                            for _, info in pairs(tracks) do info.Select = false end
                        end
                        v.Select = not v.Select
                    end
                else
                    tracks[k] = nil
                end
            end
            reaper.ImGui_EndListBox(CTX)
        end

        if reaper.ImGui_Button(CTX, 'Add Track', -1) then Add_Tracks() end -- -1 set width to the end of the window
        ToolTip('Add selected tracks from TCP or MCP view')

        if reaper.ImGui_Button(CTX, 'Remove Track', -1) then -- -1 set width to the end of the window
            for _, v in pairs(tracks) do
                if v.Select then
                    SetGroup(v, cur_group, false)
                end
            end
            tracks = GetTrackGroup(cur_group)
        end
        ToolTip('Remove tracks from list view')
        ----------
        -- END GUI
        ----------
        reaper.ImGui_End(CTX)
        end

        reaper.ImGui_PopFont(CTX) -- Pop Font

        if open then
            reaper.defer(Main)
        else
            Store_GROUPS_TO_Project_EXT_STATE()
            reaper.ImGui_DestroyContext(CTX)
        end
    end

GuiInit()
Main()
