 --[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.04
	 * NoIndex: true
--]]

 -- TRANSLATION OF VARIOUS VALUES TO OTHER RANGE
 -- CURRENTLY IT IS USED TO CONVERT ENVELOPE POINTS VALUES TO PIXELS OF THE TRACK HEIGHT
local reaper = reaper

 -- SINCE THERE IS NO NATIVE WAY TO GET AI LANE HEIGHT IT IS CALCULATED MANUALLY
local function env_AI_lane(val)
	local lane
	if val >= 52 then lane = 14
	elseif val < 52 and val >= 48 then lane = 13
	elseif val < 48 and val >= 44 then lane = 12
	elseif val < 44 and val >= 40 then lane = 11
	elseif val < 40 and val >= 36 then lane = 10
	elseif val < 36 and val >= 32 then lane = 9
	elseif val < 32 and val >= 28 then lane = 8
	elseif val < 218 then lane = 7
	end
	return lane
end

function get_item_type(item)
	local take = reaper.GetMediaItemTake(item, 0)
  	local source = reaper.GetMediaItemTake_Source(take)
  	return reaper.GetMediaSourceType(source, "")
end

function Get_item_ghosts(tr, items, as_start, as_end)
	if not items then return end
	local Element = Get_class_tbl()
	local ghosts = {}
	for i = 1, #items do
		local item = items[i]
		local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
		local item_lenght = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
		local take = reaper.GetMediaItemTake(item, 0)
		if not take then return end
		local item_start, item_len = New_items_position_in_area(as_start, as_end, item_start, item_lenght)
		local x, w = Convert_time_to_pixel(item_start, item_len)
		local y, h = Get_tr_TBH(tr)
		ghosts[#ghosts + 1] = Element:new(x, y, w, h, "ghost", item_start, item_len, {w, h} )
		reaper.JS_LICE_Clear(ghosts[#ghosts].bm, 0xAA002244)
		local peaks = (not reaper.TakeIsMIDI(take)) and Get_Item_Peaks(item, item_start, item_len) or Get_MIDI_notes(item, item_start, item_len)
		if reaper.TakeIsMIDI(take) then
			Draw_midi(peaks, ghosts[#ghosts].bm, item_start, item_len, w, h)
		else
			Draw_peak(peaks, ghosts[#ghosts].bm, h)
		end
	end
	return ghosts
end

function Get_AI_or_ENV_ghosts(env_tr, env_points, AI, as_start, as_end)
	--if not AI and not env_points then return end
	--if not AI then return end
	local ghosts = {}
	Get_AI_ghosts(env_tr, AI, ghosts)
	Get_env_ghosts(env_tr, env_points, ghosts, as_start, as_end)
	return ghosts
end

function Get_AI_ghosts(env_tr, AI, ghosts)
	if not AI then return end
	local Element = Get_class_tbl()
	for i = 1, #AI do
		local AI_pos = AI[i].info["D_POSITION"]
		local AI_len = AI[i].info["D_LENGTH"]
		local x, w = Convert_time_to_pixel(AI_pos, AI_len)
		local y, h = Get_tr_TBH(env_tr)
		ghosts[#ghosts + 1] = Element:new(x, y, w, h, "ghost", AI_pos, AI_len, {w, h} )
		reaper.JS_LICE_Clear(ghosts[#ghosts].bm, 0xAA002244)
		reaper.JS_LICE_FillRect(ghosts[#ghosts].bm, 0, Round(h-h/10), w, Round(h/10), 0xFF00FFFF, 0.5, "COPY" )
		Draw_env(env_tr, AI[i].points, ghosts[#ghosts].bm, x, h)
	end
	return ghosts
end

function Get_env_ghosts(env_tr, env_points, ghosts, as_start, as_end)
	--if not env_points then return end
	local Element = Get_class_tbl()
	--local first_point, last_point, points_lenght = env_points[1].time, env_points[#env_points].time, (env_points[#env_points].time - env_points[1].time) -- DRAW ONLY WHERE ENVELOPES ARE INSTEAD OF WHOLE SELECTED AREA
	--local x, w = Convert_time_to_pixel(first_point, points_lenght)
	local x, w = Convert_time_to_pixel(as_start, as_end-as_start)
	local y, h = Get_tr_TBH(env_tr)
	ghosts[#ghosts + 1] = Element:new(x, y, w, h, "ghost", as_start, as_end-as_start, {w, h}) -- {w, h} are stored ghost static w,h so they do not update
	--ghosts[#ghosts + 1] = Element:new(x, y, w, h, "ghost", first_point, points_lenght, {w, h}) -- {w, h} are stored ghost static w,h so they do not update
	reaper.JS_LICE_Clear(ghosts[#ghosts].bm, 0xAA002244)
	Draw_env(env_tr, env_points, ghosts[#ghosts].bm, x, h,as_start, as_end)
	return ghosts
end

function Get_MIDI_notes(item, item_start, item_len)
	--local take = reaper.GetActiveTake(item)
	--if not take then return end
	local item_end = item_start + item_len
	local t = {}
	for j = 1, reaper.CountTakes( item ) do
		t[j] = {}
		local take = reaper.GetMediaItemTake( item, j-1 )
		local ret, notecnt = reaper.MIDI_CountEvts(take)
		for i=1, notecnt do
			local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i-1)
			local startppqpos_to_proj_time = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
			if startppqpos_to_proj_time < item_start then
				startppqpos_to_proj_time = item_start
			elseif startppqpos_to_proj_time > item_end then
				break
			end
			local endppqpos_to_proj_time = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
			if endppqpos_to_proj_time > item_end then
				endppqpos_to_proj_time = item_end
			end
			t[j][#t[j]+1] = startppqpos_to_proj_time
			t[j][#t[j]+1] = endppqpos_to_proj_time
			t[j][#t[j]+1] = pitch
		end
	end
	return t
end

 -- GET ITEM PEAKS
function Get_Item_Peaks(item, item_start, item_len)
	local peaks = {}
	for j = 1, reaper.CountTakes( item ) do
		local take = reaper.GetMediaItemTake( item, j-1 )
	--local take = reaper.GetActiveTake(item)
	--if not take then return end
		local _, w = Convert_time_to_pixel(item_start, item_len)
		w = w > 0 and w or 1 -- FIX CRASHING IF WITH IS LESS THAN 1 PIXEL
		local scaled_len = item_len/ item_len * w
		local PCM_source = reaper.GetMediaItemTake_Source(take)
		local n_chans = reaper.GetMediaSourceNumChannels(PCM_source)
		local peakrate = scaled_len/item_len
		local n_spls = math.floor(item_len * peakrate + 0.5) -- its Peak Samples
		local want_extra_type = -1  -- 's' char
		local buf = reaper.new_array(n_spls*n_chans*2) -- no spectral info
		buf.clear()         -- Clear buffer
		local retval = reaper.GetMediaItemTake_Peaks(take, peakrate,  item_start, n_chans, n_spls, want_extra_type, buf);
		local spl_cnt  = (retval &0xfffff)        -- sample_count

		peaks[j] = {}

		if spl_cnt > 0 then
			for i = 1, n_chans do
				peaks[j][i] = {} -- create a table for each channel
			end
			local s = 0 -- table size counter
			for pos = 1, n_spls*n_chans, n_chans do -- move bufferpos to start of next max peak
				-- loop through channels
				for i = 1, n_chans do
				local p = peaks[j][i]
				p[s+1] = buf[pos+i-1]                   -- max peak
				p[s+2] = buf[pos+n_chans*n_spls+i-1]    -- min peak
				end
				s = s + 2
			end
			end
		end
	return peaks
end

 -- DRAW ENVELOPE "PEAKS" TO GHOSTS IMAGE
function Draw_env(env_tr, env, bm, x, h, as_start, as_end)
	local env_mode = reaper.GetEnvelopeScalingMode( env_tr )

	local minValue = env_prop(env_tr,"minValue")
	local maxValue = env_prop(env_tr,"maxValue")
	local final_h = h - env_AI_lane(h)

	--local retval, cur_as_start, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env_tr, as_start, 0, 0) -- DESTINATION END POINT -- CURENT VALUE AT THAT POSITION
	--local retval, cur_as_end, dVdS, ddVdS, dddVdS = reaper.Envelope_Evaluate(env_tr, as_end, 0, 0) -- DESTINATION END POINT -- CURENT VALUE AT THAT POSITION

	if not env then	env = { [1] = {time = as_start} } end

	for i = 1, #env-1 do
		local e_x = env[i].time
		local e_x1 = env[i+1].time
		local e_y = env_mode == 1 and reaper.ScaleFromEnvelopeMode(1, env[i].value) or env[i].value
		local e_y1 = env_mode == 1 and reaper.ScaleFromEnvelopeMode(1, env[i+1].value) or env[i+1].value

		e_x = Convert_time_to_pixel(e_x,0,0)
		e_x1 = Convert_time_to_pixel(e_x1,0,0)
		e_y = TranslateRange(e_y, minValue, maxValue, final_h, 0)
		e_y1 = TranslateRange(e_y1, minValue, maxValue, final_h, 0)

		reaper.JS_LICE_Line( bm, e_x - x, e_y, e_x1 - x, e_y1, 0xFF00FFFF,1, "COPY", true )
		reaper.JS_LICE_FillCircle( bm, e_x - x, e_y, 2, 0xFF00FFFF,1, "COPY", true )
	end
end

function Min_max(tbl)
	local min = tbl[3]
	local max = tbl[3]
	for i = 3, #tbl, 3 do
	   if tbl[i] < min then
		  min = tbl[i]
	   elseif tbl[i] > max then
		max	= tbl[i]
	   end -- FIND LOWEST (FIRST) TIME SEL START
	end
	return min,max
 end

-- DRAW MIDI NOTES TO GHOST IMAGE
function Draw_midi(peaks,bm, pos, len, w, h)
	local note_h = Round((h/128)+5)
	if note_h < 1 then note_h = 1 end
	for j = 1, #peaks do
		local min,max = Min_max(peaks[j]) -- MINIMAL AND MAXIMUIM PITCH IN PEAKS 
		for i=1, #peaks[j], 3 do
			local startppq, endppq, pitch = peaks[j][i], peaks[j][i+1], peaks[j][i+2]
			startppq = Round((startppq - pos) / len * w)
			endppq = Round((endppq - pos) / len * w)
			local note_w = Round(endppq - startppq)
			if note_w < 1 then note_w = 1 end
			local y = (min == max) and h/2 or TranslateRange(pitch, max, min, 10, h-20)
			reaper.JS_LICE_FillRect( bm, startppq, Round((y/#peaks) + ((h/#peaks) *(j-1))), note_w, note_h, 0xFF00FFFF, 0.5, "COPY" )
		end
	end
end

-- DRAW ITEM PEAKS TO GHOST IMAGE
function Draw_peak(peaks, bm, h)
	for i = 1, #peaks do
		local chan_count = #peaks[i]
			if chan_count > 0 then
			local channel_h = h / chan_count
			local channel_half_h = (0.5) * channel_h
			for chan = 1, chan_count do
				local t = peaks[i][chan]
				local channel_y1 = channel_h*(chan-1)
				local channel_y2 = channel_y1 + channel_h
				local channel_center_y = channel_y1 + (0.5*channel_h)
				for j = 1, #t-1 do
					local max_peak = channel_center_y - (t[j] * channel_half_h)
					local min_peak = channel_center_y - (t[j+1] * channel_half_h)

					if max_peak < channel_center_y and max_peak < channel_y1 then
						max_peak = channel_y1
					else
						if max_peak > channel_center_y and max_peak > channel_y2 then
							max_peak = channel_y2
						end
					end

					if min_peak < channel_center_y and min_peak < channel_y1 then
						min_peak = channel_y1
					else
						if min_peak > channel_center_y and min_peak > channel_y2 then
							min_peak = channel_y2
						end
					end
					reaper.JS_LICE_Line(bm, 0.5*j, Round((max_peak/#peaks) + (h/#peaks) *(i-1)), 0.5*j, Round((min_peak/#peaks) + (h/#peaks) *(i-1)), 0xFF00FFFF,1, "COPY", true )
				end
			end
		end
	end
end