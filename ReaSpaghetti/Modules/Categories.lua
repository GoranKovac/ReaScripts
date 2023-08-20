--@noindex
--NoIndex: true

string.startswith = function(self, str)
    return self:find('^' .. str) ~= nil
end

local r = reaper

local CAT = {
    [1] = { name = "TRACK", api = {
        "GetTrack",
        --"GetSetTrack",
        "SetTrack",
        "TrackFX",
        "GetMediaTrack",
        "SetMediaTrack",
    }, list = {} },

    [2] = { name = "ITEMS", api = {
        "MediaItem",
        "GetItem",
        --"GetSetItem",
        "SetItem",
        --"GetMediaItem",
        --"SetMediaItem",
        "GetTake",
        "TakeFX",
    }, list = {} },

    [3] = { name = "ENVELOPE", api = {
        "Envelope"
        --"GetEnvelope",
        --"GetSetEnvelope",
        --"SetEnvelope"
    }, list = {} },

    [4] = { name = "SWS", api = {
        "BR_",
        "CF_",
        "FNG_",
        "SNM_",
        "SN_",
        "ULT_",
        "NF_",
        "MRP_",
    }, list = {} },

    [5] = { name = "IMGUI", api = {
        "ImGui_"
    }, list = {} },

    [6] = { name = "JS_API", api = {
        "JS_",
        "Xen_",
    }, list = {} },

    [7] = { name = "REAPACK", api = {
        "ReaPack_"
    }, list = {} },

    [8] = { name = "PROJECT", api = {
        "Project"
    }, list = {} },

    [9] = { name = "TEMPO", api = {
        "Tempo"
    }, list = {} },

    [10] = { name = "AUDIOACCESSOR", api = {
        "AudioAccessor"
    }, list = {} },
    [11] = { name = "CONSOLE", api = {
        "Console"
    }, list = {} },

    [12] = { name = "CSURF", api = {
        "CSurf_"
    }, list = {} }
}

function GetCAT()
    return CAT
end

for k, v in pairs(r) do
    if r.APIExists(k) then
        for i = 1, #CAT do
            for j = 1, #CAT[i].api do
                if k:match(CAT[i].api[j]) then
                    CAT[i].list[#CAT[i].list + 1] = k
                end
            end
        end
    end
end

for i = #CAT, 1, -1 do
    if #CAT[i].list == 0 then table.remove(CAT, i) end
    table.sort(CAT[i].list)
end
