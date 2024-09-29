-- @description PipeWire configurator (Linux)
-- @author SeXan
-- @license GPL v3
-- @version 1.02
-- @changelog
--  Hardcode buffers and sample rates

local r = reaper

if not r.ImGui_GetBuiltinPath then
    r.ShowMessageBox("ReaImGui is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
    r.ReaPack_BrowsePackages('"Dear Imgui"')
    return
end

package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
local im = require 'imgui' '0.9.1'

local RATES, BUFFERS
local function GetUpdate()
    RATES, BUFFERS = {}, {}
    local settings = r.ExecProcess(('/usr/bin/pw-metadata -n settings'), 1000)
    for line in settings:gmatch("[^\r\n]+") do
        if line:match("clock%.allowed%-rates") then
            local rates = line:match("clock%.allowed%-rates' value:'%[ (.*) %]")
            for rate in rates:gmatch("[^,]+") do RATES[#RATES + 1] = tonumber(rate) end
        elseif line:match("clock%.%rate") then
            DEF_RATE = tonumber(line:match("clock%.%rate' value:'(%d+)"))
        elseif line:match("clock%.%quantum") then
            DEF_BUF = tonumber(line:match("clock%.%quantum' value:'(%d+)"))
        elseif line:match("clock%.min%-quantum") then
            MIN_BUF = tonumber(line:match("clock%.min%-quantum' value:'(%d+)"))
        elseif line:match("clock%.max%-quantum") then
            MAX_BUF = tonumber(line:match("clock%.max%-quantum' value:'(%d+)"))
        elseif line:match("clock%.force%-quantum") then
            FORCE_BUF = tonumber(line:match("clock%.force%-quantum' value:'(%d+)"))
        elseif line:match("clock%.force%-rate") then
            FORCE_RATE = tonumber(line:match("clock%.force%-rate' value:'(%d+)"))
        end
    end

    local TMP_BUF = MIN_BUF
    while TMP_BUF <= MAX_BUF do
        BUFFERS[#BUFFERS + 1] = TMP_BUF
        TMP_BUF = TMP_BUF * 2
    end
end
GetUpdate()

local ctx = im.CreateContext('PW BUFFER')
local HC_BUFS = { 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192 }
local HC_RATES = { 44100, 48000, 96000, 192000, 384000 }

local function loop()
    im.SetNextWindowSizeConstraints(ctx, 150, 320, 150, 320)
    local visible, open = im.Begin(ctx, 'PipeWire', true)
    local cur_rate = FORCE_RATE ~= 0 and FORCE_RATE or DEF_RATE
    local cur_buffer = FORCE_BUF ~= 0 and FORCE_BUF or DEF_BUF
    if visible then
        im.BeginGroup(ctx)
        im.Text(ctx, "BUFFER")
        for i = 1, #HC_BUFS do
            if im.RadioButton(ctx, HC_BUFS[i], cur_buffer == HC_BUFS[i]) then
                local cmd = ("pw-metadata -n settings 0 clock.force-quantum %s"):format(HC_BUFS[i])
                r.ExecProcess(('/usr/bin/%s'):format(cmd), 1000)
                GetUpdate()
            end
        end
        im.EndGroup(ctx)
        im.SameLine(ctx)
        im.BeginGroup(ctx)
        im.Text(ctx, "SAMPLE RATE")
        for i = 1, #HC_RATES do
            if im.RadioButton(ctx, HC_RATES[i], cur_rate == HC_RATES[i]) then
                local cmd = ("pw-metadata -n settings 0 clock.force-rate %s"):format(HC_RATES[i])
                r.ExecProcess(('/usr/bin/%s'):format(cmd), 1000)
                GetUpdate()
            end
        end
        im.EndGroup(ctx)
        if im.Button(ctx, "RESET TO DEFAULTS") then
            local cmd =
            "pw-metadata -n settings 0 clock.force-rate 0; pw-metadata -n settings 0 clock.force-quantum 0"
            r.ExecProcess(('/bin/bash -c "%s"'):format(cmd), 1000)
            GetUpdate()
        end

        im.End(ctx)
    end

    if open then
        r.defer(loop)
    end
end
r.defer(loop)
