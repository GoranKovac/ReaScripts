--[[
 * ReaScript Name: TrackVersionsWIP.lua
 * About: Protools style playlist, track versions (Cubase)
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 0.4
--]]
 
--[[
 * Changelog:
 * v0.4 (2018-03-10)
  + More fixes to copy to destination for multitracks and view time selection
  + In View all version mode,view time selection mode is not allowed

--]]

-- USER SETTINGS
local view = 0
local time_sel_test = true
local manual_naming = false
local color = 0 -- 1 for checkboxes, 2 for fonts , 3 for both, 0 for default
local store_original = true -- set enable-disable storing original version
local auto_loop_rec = true -- make versions from recorded takes
--------------------------------------------------------------------------
local last_tr_h = nil
local Wnd_W,Wnd_H = 320,240
local cur_tr, get_val, sel_item, folder
cur_sel = {[1] = nil}
local TrackTB = {}
local env_type =  {  
                    [1] = {name = "Volume",                       v = 1},
                    [2] = {name = "Pan" ,                         v = 0},
                    [3] = {name = "Width",                        v = 0},
                    [4] = {name = "Volume".. " " .. "(Pre-FX)",   v = 0},
                    [5] = {name = "Pan"   .. " " .. "(Pre-FX)",   v = 0},
                    [6] = {name = "Width" .. " " .. "(Pre-FX)",   v = 0},
                    [7] = {name = "Trim"  .. " " .. "Volume",     v = 0},
                    [8] = {name = "Mute",                         v = 0},
                    [9] = {name = "Last_menu",                    v = 1}
                  }
----------------------------------------------
-- Pickle.lua
--------------------------------------------
function pickle(t)
  return Pickle:clone():pickle_(t)
end

Pickle = { clone = function (t) local nt = {}; for i, v in pairs(t) do nt[i] = v end return nt end }

function Pickle:pickle_(root)
  if type(root) ~= "table" then error("can only pickle tables, not ".. type(root).."s") end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""
  
  while #self._refToTable > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s.."{\n"
    
    for i, v in pairs(t) do
        s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
    s = s.."},\n"
  end

  return string.format("{%s}", s)
end

function Pickle:value_(v)
  local vtype = type(v)
  if     vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else error("pickle a "..type(v).." is not supported")
  end  
end

function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then 
    if t == self then error("can't pickle the pickle class") end
    table.insert(self._refToTable, t)
    ref = #self._refToTable
    self._tableToRef[t] = ref
  end
  return ref
end
----------------------------------------------
-- unpickle
----------------------------------------------
function unpickle(s)
  if type(s) ~= "string" then error("can't unpickle a "..type(s)..", only strings") end
  local gentables = load("return "..s)
  local tables = gentables()
  for tnum = 1, #tables do
    local t = tables[tnum]
    local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end
--------------------------------------------------------------------------------
---   Simple Element Class   ---------------------------------------------------
--------------------------------------------------------------------------------
local Element = {}
function Element:new(x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz,fnt_rgba,num,ver,guid,env,fipm, dest)
    local elm = {}
    elm.def_xywh = {x,y,w,h,fnt_sz} -- its default coord,used for Zoom etc
    elm.x, elm.y, elm.w, elm.h = x, y, w, h
    elm.r, elm.g, elm.b, elm.a = r, g, b, a
    elm.lbl, elm.fnt, elm.fnt_sz  = lbl, fnt, fnt_sz
    elm.fnt_rgba = fnt_rgba
    elm.num ,elm.ver, elm.guid, elm.env, elm.fipm, elm.dest = num, ver, guid, env, fipm, dest
    ------
    setmetatable(elm, self)
    self.__index = self 
    return elm
end
--------------------------------------------------------------
--- Function for Child Classes(args = Child,Parent Class) ----
--------------------------------------------------------------
function extended(Child, Parent)
  setmetatable(Child,{__index = Parent}) 
end
--------------------------------------------------------------
---   Element Class Methods(Main Methods)   ------------------
--------------------------------------------------------------
function Element:update_xywh()
  if not Z_w or not Z_h then return end -- return if zoom not defined
  self.x, self.w = math.ceil(self.def_xywh[1]* Z_w) , math.ceil(self.def_xywh[3]* Z_w) -- upd x,w
  self.y, self.h = math.ceil(self.def_xywh[2]* Z_h) , math.ceil(self.def_xywh[4]* Z_h) -- upd y,h
  if self.fnt_sz then --fix it!--
     self.fnt_sz = math.max(9,self.def_xywh[5]* (Z_w+Z_h)/2)
     self.fnt_sz = math.min(22,self.fnt_sz)
  end       
end
------------------------
function Element:pointIN(p_x, p_y)
  return p_x >= self.x and p_x <= self.x + self.w/1.3 and p_y >= self.y and p_y <= self.y + self.h
end
--------
function Element:mouseIN()
  return gfx.mouse_cap&1==0 and self:pointIN(gfx.mouse_x,gfx.mouse_y)
end
------------------------
function Element:mouseDown()
  return gfx.mouse_cap&1==1 and self:pointIN(mouse_ox,mouse_oy)
end
--------
function Element:mouseUp() -- its actual for sliders and knobs only!
  return gfx.mouse_cap&1==0 and self:pointIN(mouse_ox,mouse_oy)
end
--------
function Element:mouseClick()
  return gfx.mouse_cap&1==0 and last_mouse_cap&1==1 and
  self:pointIN(gfx.mouse_x,gfx.mouse_y) and self:pointIN(mouse_ox,mouse_oy)         
end
---------
function Element:mouseRClick()
  return gfx.mouse_cap&2==0 and last_mouse_cap&2==2 and
  self:pointIN(gfx.mouse_x,gfx.mouse_y) and self:pointIN(mouse_ox,mouse_oy)         
end
------------------------
function Element:mouseR_Down()
  return gfx.mouse_cap&2==2 and self:pointIN(mouse_ox,mouse_oy)
end
--------
function Element:mouseM_Down()
  return gfx.mouse_cap&64==64 and self:pointIN(mouse_ox,mouse_oy)
end
------------------------
function Element:draw_frame()
  local x,y,w,h  = self.x,self.y,self.w,self.h
  gfx.rect(x, y, w, h, false)            -- frame1
  gfx.roundrect(x, y, w-1, h-1, 3, true) -- frame2         
end
----------------------------------------------------------------------------------------------------
---   Create Element Child Classes(Button,Slider,Knob)   -------------------------------------------
----------------------------------------------------------------------------------------------------
local Button = {}
local Frame = {}
local Radio_Btns = {}
local Menu = {}
local CheckBox = {}
local Title = {}
  extended(Title,      Element)
  extended(Menu,       Element)
  extended(Button,     Element)
  extended(Frame,      Element)
  extended(Radio_Btns, Element)
  extended(CheckBox,   Element)
--------------------------------------------------------------------------------
---   Menu Class Methods   -----------------------------------------------------
--------------------------------------------------------------------------------
function Menu:set_num()
    local x,y,w,h  = self.x,self.y,self.w,self.h 
    local val = self.num      -- current value,check
    local menu_tb = self.ver -- checkbox table
    local menu_str = ""
      for i=1, #menu_tb,1 do
        if i~=val then menu_str = menu_str..menu_tb[i].."|" end
      end
    gfx.x = self.x; gfx.y = gfx.mouse_y + 13
    local new_val = gfx.showmenu(menu_str)        -- show checkbox menu
    if new_val>0 then self.num = new_val end -- change check(!)
end
------------------------
function Menu:draw()
    -- Get mouse state ---------
    if self:mouseRClick() then self:set_num()
      if self:mouseRClick() and self.onRClick then self.onRClick() end
    end
    if self:mouseClick() then self:set_num()
      if self:mouseClick() and self.onClick then self.onClick() end
    end
end 
function Menu:draw2()
    -- Get mouse state ---------
    if self:mouseClick() then self:set_num()
    if self:mouseClick() and self.onClick then self.onClick() end
    end
end
function Title:draw()
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = x; gfx.y = y+(h-lbl_h)/2
    gfx.drawstr(self.lbl)
end  
--------------------------------------------------------------------------------
---   Button Class Methods   ---------------------------------------------------
--------------------------------------------------------------------------------
function Button:draw_body()
    gfx.rect(self.x,self.y,self.w,self.h, true) -- draw btn body
end
--------
function Button:draw_lbl()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = x+(w-lbl_w)/2; gfx.y = y+(h-lbl_h)/2
    gfx.drawstr(self.lbl)
end
------------------------
function Button:draw()
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    if self.num == 1 then r,g,b,a = 0.2,0.5,0.6,1 end
    -- Get mouse state ---------
          -- in element --------
          if self:mouseIN() then a=a+0.1 end
          -- in elm L_down -----
          if self:mouseDown() then a=a+0.2 end
          -- in elm L_up(released and was previously pressed) --
          if self:mouseClick() and self.onClick then self.onClick() end
          if self:mouseRClick() and self.onRClick then self.onRClick() end
    -- Draw btn body, frame ----
    gfx.set(r,g,b,a)    -- set body color
    self:draw_body()    -- body
    self:draw_frame()   -- frame
    -- Draw label --------------
    gfx.set(table.unpack(self.fnt_rgba))
    gfx.setfont(1, fnt, fnt_sz) -- set label fnt
    self:draw_lbl()             -- draw lbl
end
--------------------------------------------------------------------------------
---   Radio_Btns Class Methods   -----------------------------------------------
-------------------------------------------------------------------------------- 
-- adapted from Slider
function Radio_Btns:set_val_m_wheel()
    if gfx.mouse_wheel == 0 then return false end  -- return if m_wheel = 0
    if gfx.mouse_wheel < 0 then self.num = math.min(self.num+1, #self.ver) end
    if gfx.mouse_wheel > 0 then self.num = math.max(self.num-1, 1) end
    return true
end
--------
function Radio_Btns:set_num(job)
  local y,h = self.y,self.h  
  -- pad the options in from the frame a bit
  y,h = y + 2, h - 4
  local opt_tb = self.ver 
  local VAL = math.floor(( (gfx.mouse_y-y)/h ) * #opt_tb) + 1
  if VAL<1 then VAL=1 elseif VAL> #opt_tb then VAL = #opt_tb end
  get_val = VAL  -- FOR HIGHLIGHTING
  if not job then self.num = VAL end --
end
--------
function Radio_Btns:draw_body()
  local x,y,w,h = self.x,self.y,self.w,self.h  
  -- pad the options in from the frame a bit
  x,y,w,h = x - 2, y + 2, w - 4, h - 4
  local val = self.num
  local opt_tb = self.ver
  local num_opts = #opt_tb  
  local opt_spacing = self.opt_spacing
  local r = (opt_spacing / 2.5)
  local center_offset = ((opt_spacing - (2.5 * r)) / 2)
  -- adjust the options to be centered in their spaces
  x, y = x + center_offset, y + center_offset
  for i = 1, num_opts do
    local opt_y = y + ((i - 1) * opt_spacing )
    gfx.circle(x + r, opt_y + r, r, false)
    if i == val then      
      --fill in the whole circle
      gfx.circle(x + r, opt_y + r, r, true)
      --draw a smaller dot
      gfx.circle(x + r, opt_y + r, r * 0.5, true)
      --give the dot a frame
      gfx.circle(x + r, opt_y + r, r * 0.5, false)
    elseif i == get_val then
      gfx.circle(x + r, opt_y + r, r * 0.7, true)       
    end
  end
end
--------
function Radio_Btns:draw_vals()
  local x,y,w,h = self.x,self.y,self.w,self.h  
  -- pad the options in from the frame a bit
  x,y,w,h = x + 2, y + 2, w - 4, h - 4
  local opt_tb = self.ver
  local num_opts = #opt_tb
  local opt_spacing = self.opt_spacing
  -- to match up with the options
  local r = opt_spacing / 3
  local center_offset = ((opt_spacing - (2.5 * r)) / 2)
  x, y = x + opt_spacing + center_offset, y + center_offset 
  for i = 1, num_opts do
    local opt_y = y + ((i - 1) * opt_spacing)
    gfx.x, gfx.y = x, opt_y
    gfx.drawstr(opt_tb[i].name)
  end
end
--------
-- Copied from Checkbox:draw_lbl()
function Radio_Btns:draw_lbl()  
  local x,y,h  = self.x, self.y + 2, self.h - 4
  local num_opts = #self.ver
  local opt_spacing = self.opt_spacing
  local r = opt_spacing / 2
  local center_offset = ((opt_spacing - (2.5 * r)) / 2)
  y = y + center_offset  
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = x-lbl_w-5; gfx.y = y
    gfx.drawstr(self.lbl) 
end
--------
function Radio_Btns:draw()
  self:update_xywh()
  local r,g,b,a = self.r,self.g,self.b,self.a
  local fnt,fnt_sz = self.fnt, self.fnt_sz 
  self.h = (self.fnt_sz+5) * #self.ver 
  self.opt_spacing = (self.h / (#self.ver or 1))
  -- Get mouse state ---------
    -- in element --------
    if self:mouseIN() then --a=a+0.1 
       self:set_num("get")
        if self:set_val_m_wheel() then         
          if self.onClick then self.onClick() end 
        end
    else get_val = nil
    end
    -- in elm L_down -----
    if self:mouseDown() then a=a+0.2 end
    -- in elm L_up(released and was previously pressed) --
    if self:mouseClick() then 
     self:set_num()
     if self.onClick then self.onClick() end
    end
    -- right click support
    if self:mouseRClick() and self.onRClick then self.onRClick() end
    gfx.set(r,g,b,a)  
  --self:draw_frame()  
  self:draw_body()
  gfx.set(table.unpack(self.fnt_rgba))
  gfx.setfont(1, fnt, fnt_sz) 
  self:draw_vals()
  self:draw_lbl()
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---   CheckBox Class Methods   -------------------------------------------------
--------------------------------------------------------------------------------
function CheckBox:set_val_m_wheel()
    if gfx.mouse_wheel == 0 then return false end  -- return if m_wheel = 0
    if gfx.mouse_wheel < 0 then self.num = math.min(self.num+1, #self.ver) end
    if gfx.mouse_wheel > 0 then self.num = math.max(self.num-1, 1) end
    return true
end
function CheckBox:set_num()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local val = self.num      -- current value,check
    local menu_tb = self.ver -- checkbox table
    local menu_str = ""
       for i=1, #menu_tb,1 do
         if i~=val then menu_str = menu_str..menu_tb[i].."|"
                   else menu_str = menu_str.."!"..menu_tb[i].."|" -- add check
         end
       end
    gfx.x = self.x; gfx.y = self.y + self.h
    local new_val = gfx.showmenu(menu_str)        -- show checkbox menu
    if new_val>0 then self.num = new_val end -- change check(!)
end
--------
function CheckBox:draw_body()
    gfx.rect(self.x,self.y,self.w,self.h, true) -- draw checkbox body
end
--------
function CheckBox:draw_lbl()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local lbl_w, lbl_h = gfx.measurestr(self.lbl)
    gfx.x = x-lbl_w-5; gfx.y = y+(h-lbl_h)/2
    gfx.drawstr(self.lbl) -- draw checkbox label
end
--------
function CheckBox:draw_val()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local val = self.ver[self.num]
    local val_w, val_h = gfx.measurestr(val)
    gfx.x = x+(w-val_w)/2; gfx.y = y+(h-val_h)/2
    gfx.drawstr(val) -- draw checkbox val
end
------------------------
function CheckBox:draw()
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    -- Get mouse state ---------
          -- in element --------
          if self:mouseIN() then a=a+0.1 
            if self:set_val_m_wheel() then
              if self:onRClick() then self.onRClick() end
            end
          end
          -- in elm L_down -----
          if self:mouseDown() then a=a+0.2 end
          if self:mouseRClick() and self.onRClick then self:set_num() self.onRClick() end
          if self:mouseClick() and self.onClick then self.onClick() end
          --end
    -- Draw ch_box body, frame -
    gfx.set(r,g,b,a)    -- set body color
    self:draw_body()    -- body
    self:draw_frame()   -- frame
    -- Draw label --------------
    gfx.set(table.unpack(self.fnt_rgba))   -- set label,val color
    gfx.setfont(1, fnt, fnt_sz) -- set label,val fnt
    self:draw_lbl()             -- draw lbl
    self:draw_val()             -- draw val
end

--------------------------------------------------------------------------------
---   Frame Class Methods  -----------------------------------------------------
--------------------------------------------------------------------------------
function Frame:draw()
   self:update_xywh() -- Update xywh(if wind changed)
   local r,g,b,a  = self.r,self.g,self.b,self.a
   if self:mouseIN() then end
   gfx.set(r,g,b,a)   -- set frame color
   self:draw_frame()  -- draw frame
end
-----------------------------------------------
--- Function: store buttons to ext state ---
-----------------------------------------------
local function save_tracks()
  local all_button_states = {}  
    for k, v in ipairs(TrackTB) do
      all_button_states[#all_button_states+1] = {guid = v.guid, ver = v.ver, num = v.num, env = v.env, fipm = v.fipm, dest = v.dest}
    end 
  reaper.SetProjExtState(0, "Track_Versions", "States", pickle(all_button_states))
end
-----------------------------------------------------
--- Function: Restore Saved Buttons From extstate ---
-----------------------------------------------------
local function restore()
  local ok, states = reaper.GetProjExtState(0, "Track_Versions","States")
  if states ~= "" then states = unpickle(states) end
  for i = 1, #states do
    for j = 1 , #states[i].ver do
      create_button(states[i].ver[j].name, states[i].guid, states[i].ver[j].chunk, states[i].ver[j].ver_id, states[i].num, states[i].env, states[i].fipm)
    end
  end
end
---------------------------------------------------------------------
--- Function: Delete button from table it button track is deleted ---
---------------------------------------------------------------------
local function track_deleted()
  for j = #TrackTB, 1 , -1 do -- SCAN FOLDERS
    for k = #TrackTB[j].ver, 1, -1 do          
      local chunk = TrackTB[j].ver[k].chunk
        for l = #chunk, 1, -1 do  
          if chunk[l] and string.sub(chunk[l],1,1) == "{" then  -- FIND IF TRACK IS IN A FOLDER DATA (IF GUID IS FOUND)
            if not reaper.ValidatePtr( reaper.BR_GetMediaTrackByGUID( 0, chunk[l] ) , "MediaTrack*")then table.remove(chunk,l) end -- remove child if not found
            if #chunk == 0 then table.remove(TrackTB[j].ver,k) end -- if no more tracks in folder, remove chunk
          end 
        end
    end
  end

  for i = #TrackTB, 1 , -1 do -- scan whole table
    local tr = reaper.BR_GetMediaTrackByGUID( 0, TrackTB[i].guid )      
    if not reaper.ValidatePtr(tr, "MediaTrack*") then table.remove(TrackTB,i) end-- IF TRACK FROM TABLE DOES NOT EXIST IN REAPER
  end
  if #TrackTB == 0 then cur_sel[1] = nil end
  update_tbl()
  save_tracks()
end
--------------------------------------------------------------------------------
---  Function Get Items chunk --------------------------------------------------
--------------------------------------------------------------------------------
function check_item_guid(tab,item,m_type)
  local _, chunk = reaper.GetItemStateChunk(item, '') 
  if not tab then return chunk end -- if there are no versions
  
  local item_guid = reaper.BR_GetMediaItemGUID(item)     
  local take =  reaper.GetMediaItemTake( item, 0 )
  local source = reaper.GetMediaItemTake_Source( take )
  local m_type = m_type or reaper.GetMediaSourceType( source, "" )
  
  local take_guid = reaper.BR_GetMediaItemTakeGUID( take )
  local POOL_guid
  
    for i = 1 , #tab.ver do
      for j = 1 ,#tab.ver[i].chunk do
        local in_table = "{"..tab.ver[i].chunk[j]:match('{(%S+)}').."}"     
          if in_table == item_guid then
            item_guid = item_guid:sub(2, -2):gsub('%-', '%%-')
            take_guid = take_guid:sub(2, -2):gsub('%-', '%%-')
            if m_type and m_type:find("MIDI") then POOL_guid = string.match(chunk, "POOLEDEVTS {(%S+)}"):gsub('%-', '%%-') end -- MIDI ITEM
            local new_item_guid = reaper.genGuid():sub(2, -2)
            local new_take_guid = reaper.genGuid():sub(2, -2)
            local new_POOL_guid = reaper.genGuid():sub(2, -2) -- MIDI ITEM
            if m_type and m_type:find("MIDI") then chunk = string.gsub(chunk, POOL_guid, new_POOL_guid) end-- MIDI ITEM
            chunk = string.gsub(chunk, item_guid, new_item_guid)
            chunk = string.gsub(chunk, take_guid, new_take_guid)
            return chunk
          end
      end
  end
return chunk
end
--------------------------------------------------------------------------------
---  Function Get Items chunk --------------------------------------------------
--------------------------------------------------------------------------------
function getTrackItems(track,job)
  if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")== 1 and not job then return end  
  local items_chunk, items, ts_items = {}, {}, {}
  local num_items = reaper.CountTrackMediaItems(track)
    for i=1, num_items, 1 do
      local item = reaper.GetTrackMediaItem(track, i-1)
      items[#items+1] = item
    end
    ----- time selection
    --for i = 1 ,#items do
      --if get_items_in_ts(items[i]) then
        --ts_item_position(item)
      --  ts_items[#ts_items+1]= get_items_in_ts(items[i])
      --end
    --end
    --if #ts_items == 0 or not find_guid(reaper.GetTrackGUID(track)) or #find_guid(reaper.GetTrackGUID(track)).ver < 2 then ts_items = nil end -- do not create TS ITEMS if there are no VERSIONS
    local items_tb = items--ts_items or items
    for i = 1, #items_tb do
      ------------------------ DO NOT ALLOW SAME ITEM OR TAKE GUIDS -------------------------
      local it_chunk = check_item_guid(find_guid(reaper.GetTrackGUID(track)),items_tb[i])
      ------------------------ DO NOT ALLOW SAME ITEM GUIDS -------------------------  
      items_chunk[#items_chunk+1] = pattern(it_chunk)
    end 
    
  --if #items_tb == 0 then items_chunk[1] = "empty_track" end -- pickle doesn't like empty tables -- THIS IS FOR EMTPY VERSIONS BUT WE USE THEM FOR NEW EMPTY CHUNK SO WE DONT NEED IT ATM
  return setmetatable(items_chunk, tcmt), items
end
--------------------------------------------------------------------------------
---  Function GET ITEMS IN TS  --------------------------------
--------------------------------------------------------------------------------
function get_items_in_ts(item)
  local tsStart, tsEnd = get_time_sel()
  local item_start = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
  local item_len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
  local item_dur = item_start + item_len
  if (tsStart >= item_start and tsStart <= item_dur) or -- if time selection start is in item
     (tsEnd >= item_start and tsEnd <= item_dur) or
     (tsStart <= item_start and tsEnd >= item_dur)then -- if time selection end is in the item
      return item
  end
end
----------------------------------------------------
--- select all items -------------------------------
----------------------------------------------------
local function select_items(track)
  if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then return end
  local _, items = getTrackItems(track)
  for i = 1 , #items do reaper.SetMediaItemSelected(items[i], true) end
  reaper.UpdateArrange()
end

---------------------------------------------------
---      Function: FIND GUID Value Key of track ---
---------------------------------------------------
function find_guid(guid)
  for i = 1 , #TrackTB do
    if TrackTB[i].guid == guid then return TrackTB[i], i end
  end
end
----------------------------------------------------------------------
--    FUNCTION GET FOLDER CHILDS -------------------------------------
---------------------------------------------------------------------- 
function delete_childs(childs,ref,job)
  local n = job or 1
  for i = 1, #childs do
    if reaper.BR_GetMediaTrackByGUID(0,childs[i]) then
      local child = find_guid(childs[i])
        if not child then return end
        for j = #child.ver , n, -1 do
          if not job then
            if ref == child.ver[j].ver_id then table.remove(child.ver,j) child.num = #child.ver end
          else
            if ref ~= child.ver[j].ver_id then table.remove(child.ver,j) child.num = #child.ver end 
          end
        end
      if child.fipm == 1 then sort_fipm(child,reaper.BR_GetMediaTrackByGUID(0,childs[i])) end
    end                        
  end
end
----------------------------------------------------------------------
--    FUNCTION UPDATE TBL AFTER DELETE -------------------------------
----------------------------------------------------------------------
function update_tbl()
  for i = #TrackTB , 1, -1 do
    if #TrackTB[i].ver == 0 then table.remove(TrackTB,i) end
  end
  if #TrackTB == 0 then  cur_sel[1] = nil end
end
----------------------------------------------------------------------
--    FUNCTION GET FOLDER CHILDS -------------------------------------
---------------------------------------------------------------------- 
function get_folder(tr)
  if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") <= 0 then return end -- ignore tracks and last folder child
  local depth, children =  0, {}
  local folderID = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")-1
    for i = folderID + 1 , reaper.CountTracks(0)-1 do -- start from first track after folder
      local child = reaper.GetTrack(0,i)
      local currDepth = reaper.GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
      children[#children+1] = reaper.GetTrackGUID(child)--insert child into array
      depth = depth + currDepth
      if depth <= -1 then break end --until we are out of folder 
    end
  return children -- if we only getting folder childs
end
--------------------------------------------------------------------------------
--    FUNCTION CREATE FOLDER ---------------------------------------------------
--------------------------------------------------------------------------------
function create_folder(tr,version_name,ver_id)
  if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") ~= 1 then return end
  local trim_name = string.sub(version_name, 5) -- exclue "F -" from main folder
  local childs = get_folder(tr)
  for i = 1, #childs do
    create_child = create_track(reaper.BR_GetMediaTrackByGUID(0,childs[i]),version_name,ver_id) -- create childs
  end
  create_track(tr,trim_name,ver_id) -- create FOLDER only if childs have item chunk (note "empty")
end
--------------------------------------------------------------------------------
---  Function Create Button from TRACK SELECTION -------------------------------
--------------------------------------------------------------------------------
function create_track(tr,version_name,ver_id,job)
  local chunk = getTrackItems(tr,job) or get_folder(tr) -- items or tracks (if no items then its tracks (folder)
  --if chunk[1] == "empty_track" then return end --and version_name ~= "Original" then version_name = version_name .. " Empty" end -- if there is no chunk (no items) call version EMPTY
  create_button(version_name,reaper.GetTrackGUID(tr),chunk,ver_id)
end
--------------------------------------------------------------------------------
---  Function NAMING (for all versions in script -------------------------------
--------------------------------------------------------------------------------
local pass_name
function naming(tbl,string,v_id)
  if tbl == nil then
    if store_original then return "Main" 
    elseif not store_original and not manual_naming then return "V01"
    elseif not store_original and manual_naming then 
      if not pass_name then
        local retval, name = reaper.GetUserInputs("Version name ", 1, "Version Name :", "")
        if not retval or name == "" then return end
        pass_name = name
        return name
      else
        return pass_name
      end
    end
  end
  
  if manual_naming then
    if not pass_name then
      local retval, name = reaper.GetUserInputs("Version name ", 1, "Version Name :", "")
      if not retval or name == "" then return end
      pass_name = name
      return pass_name
    else
      return pass_name
    end
  end
  
  local name,counter = nil, 0
  if not store_original then counter = 1 end
  for i = 1, #tbl.ver do
    if string == "V" and (#tbl.ver[i].ver_id == 38) then counter = counter + 1
    elseif string == "D" and (v_id  == tbl.ver[i].ver_id or v_id == tbl.ver[i].ver_id:sub(1, -4))then
      counter = counter + 1
    elseif string == "Comp" then counter = counter + 1
    end
    name = string .. string.format("%02d",counter)
  end
  return name
end
-------------------------------------------------------------------------------
---  Function on_click (for all buttons)        -------------------------------
-------------------------------------------------------------------------------
function on_click_function(button,name)
  local sel_tr_count = reaper.CountSelectedTracks(0)
    for i = 1, sel_tr_count do 
      ::JUMP::                     
      local tr = reaper.GetSelectedTrack(0, i-1)
      local guid = reaper.GetTrackGUID(tr)
      if find_guid(guid) then new_empty(guid) end
      local version_name = naming(find_guid(guid),name) -- first one is duplicate
      if not version_name then return end
      if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then version_name = "F - " .. version_name end  
      button(tr, version_name, reaper.genGuid(),"track") -- "track" to exclued creating folder chunk in gettrackitems function (would result a crash)
      
      --if not find_guid(guid) then return 
      if #find_guid(guid).ver == 1 then goto JUMP end
      --elseif find_guid(guid) then new_empty() end
      --elseif #find_guid(guid).ver == 1 and name == "D" then goto JUMP --end -- create two versions at once
      --end
    end
    pass_name = nil
end
---------------------------------------------------------------------------------------------------------
---   START   -------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
local all         = Button:new(20,15,25,20, 0.2,0.2,1.0,0.4, "All","Arial",15,{0.7, 0.9, 1, 1}, 0)
local multi_edit  = Button:new(100,15,60,20, 0.2,0.2,1.0,0.4, "Multi edit","Arial",15,{0.7, 0.9, 1, 1}, 0)
local copy        = Button:new(20,106,75,20, 0.2,0.2,1.0,0.4, "To ","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local delete      = Button:new(20,136,75,20, 0.2,0.2,1.0,0.4, "Delete","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local rename      = Button:new(20,166,75,20, 0.2,0.2,1.0,0.4, "Rename","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local view_ts     = Button:new(20,196,75,20, 0.2,0.2,1.0,0.4, "View TS","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local comp        = Button:new(52,15,40,20, 0.2,0.2,1.0,0.4, "COMP","Arial",15,{0.7, 0.9, 1, 1}, 0)
local menu_btn    = Button:new(125,15,30,20, 0.2,0.2,1.0,0, "Menu","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local duplicate   = Button:new(20,76,75,20, 0.2,0.2,1.0,0.4, "Duplicate","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local empty       = Button:new(20,46,75,20, 0.2,0.2,1.0,0.4, "Empty","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local ch_box1     = CheckBox:new(212,46,85,20,  0.2,0.5,0.6,0.3, "","Arial",15,{0.7, 0.9, 1, 1}, 1, {})
local box_env     = Radio_Btns:new(216,70,120,20,  0.3,0.8,0.3,0.7, "","Arial",15,{0.7, 0.9, 1, 1}, 1, {})
local W_Frame, T_Frame = Frame:new(10,10,Wnd_W-20,Wnd_H-20,  0,0.5,2,0.4 ), Frame:new(10,10,Wnd_W-20,30,  0,0.5,2,0.4 )
local Empty, Env, Frame, CheckBox_TB, env = {empty,duplicate}, {save_env}, {W_Frame,T_Frame}, {ch_box1}, {box_env}
local Copy = {copy,delete,rename}
local all_tb,comp_tb = {all,view_ts},{comp}
local multi_tb = {multi_edit}
--local global_m = {menu_btn}
for i = 1, #env_type-1 do
  ch_box1.ver[#ch_box1.ver + 1] = env_type[i].name
end
--------------------------------------------------------------------------------
---  Function Restore Item Position --------------------------------------------
--------------------------------------------------------------------------------
function restoreTrackItems(track, num, job)
  local track, track_tb = reaper.BR_GetMediaTrackByGUID( 0,track), find_guid(track)
  local track_items_table = job or track_tb.ver[num].chunk -- (we send {} as job from empty click)
  local num_items = reaper.CountTrackMediaItems(track)
    
    ----- REMOVE ALL ITEMS ON TRACK TO SET NEW ONE FROM VERSION
  if track_tb.fipm == 0 then  
    for i = num_items, 1, -1 do 
      local item = reaper.GetTrackMediaItem(track,i-1) 
      reaper.DeleteTrackMediaItem(track,item)
    end
  else
    track_tb.num = num
    mute_view(track_tb)
  end
  
  ----- IF WE ARE IN VIEW TIME SELECTION MODE SET THE SAVED VERSION/SOURCE STATIC
  if view == 1 then
    track_tb.stored = {}
    cur_ts_items = {} 
    for i = 1 ,#stored_version do
      local tr_tbl = find_guid(stored_version[i].guid)
        if has_id(tr_tbl,stored_version[i].ver_id) then
          local _, items = has_id(tr_tbl,stored_version[i].ver_id)
          for j = 1 , #items do
            if track_tb.guid == stored_version[i].guid then -- MAKE SURE ITEMS ARE ON SAME TRACK (ELSE ITEMS GET MIXED UP)
              reaper.SetItemStateChunk(reaper.AddMediaItemToTrack(track), items[j], false) -- set saved source (version)
            end
          end
       end
    end
  end
  -------------------------------------------------------------------------------------------------------------------
    for i = 1, #track_items_table, 1 do
      if reaper.BR_GetMediaTrackByGUID( 0, track_items_table[i] ) then  -- FOLDER (TRACKS) (table is filled with tracks not items)
        track_tb.num = num -- check parent version --
        local child = find_guid(track_items_table[i]) -- get child
          if has_id(child,track_tb.ver[track_tb.num].ver_id) then 
            local pointer = has_id(child,track_tb.ver[track_tb.num].ver_id)
            child.num = pointer -- CHECK THE CHILD BOXES
            restoreTrackItems(track_items_table[i],pointer) -- SEND INDIVIDUAL CHILDS
          end
      else   -- TRACK OR FOLDER CHILDS (ITEMS)
        if track_tb.fipm == 0 then
          track_tb.num = num
          local item = reaper.AddMediaItemToTrack(track)
            if view == 1 then -- TIME SELECTION VIEW
              for j = 1 , #stored_version do
                --if AAA[j].ver_id ~= track_tb.ver[track_tb.num].ver_id and track_tb.guid == AAA[j].guid then reaper.SetItemStateChunk(item, track_items_table[i], false) end -- PREVENT ADDING SAME VERSION AS SOURCE (THEY GET OVERLAPED) and make sure items get on right track
                if track_tb.guid == stored_version[j].guid and stored_version[j].ver_id ~= track_tb.ver[track_tb.num].ver_id then reaper.SetItemStateChunk(item, track_items_table[i], false) end -- PREVENT ADDING SAME VERSION AS SOURCE (THEY GET OVERLAPED) and make sure items get on right track
              end
              if ts_item_position(item) then track_tb.stored[#track_tb.stored+1] = show_ts_version(item) else reaper.DeleteTrackMediaItem(track, item) end -- TIMESELECTION VIEW,
            else  -- NORMAL VIEW
              track_tb.stored = nil
              reaper.SetItemStateChunk(item, track_items_table[i], false) -- SETTING NORMAL VERSION
            end
        end
      end
    end
end
--------------------------------------------------------------------------------
---  BUTTONS FUNCTIONS   ------------------------------------------------------
--------------------------------------------------------------------------------
function new_empty(guid)
  local childs = get_folder(reaper.BR_GetMediaTrackByGUID(0,guid)) or {guid}
    for i = 1 , #childs do
      restoreTrackItems(childs[i], 0,{}) -- sending empty table {} removes items from track
      find_guid(childs[i]).num = #find_guid(childs[i]).ver
      find_guid(childs[i]).fipm = 0 -- disable FIPM 
      reaper.SetMediaTrackInfo_Value( reaper.BR_GetMediaTrackByGUID(0,childs[i]), "B_FREEMODE",0) -- disable FIPM 
    end
end
-------------------------------------------------------------------------------
---  BUTTONS FUNCTIONS   ------------------------------------------------------
-------------------------------------------------------------------------------
view_ts.onClick = function()
  if all.num == 1 then return end
  if view_ts.num == 0 then view_ts.num = 1 view = 1 else view_ts.num = 0 view = 0 end
  
  local tbl
  if get_folder(reaper.BR_GetMediaTrackByGUID(0,cur_sel[1].guid)) then
    tbl = get_folder(reaper.BR_GetMediaTrackByGUID(0,cur_sel[1].guid))
  elseif #multi_tracks ~= 0 then
    tbl = multi_tracks
  else
    tbl = {cur_sel[1].guid}
  end
  
  if view == 1 then 
    stored_version = {}
    
    for i = 1,#tbl do
      local track = find_guid(tbl[i]) 
      track.stored_num = track.num
    end
    
      for i = 1,#tbl do
        local items = {}
        local track = find_guid(tbl[i]) 
        local id = track.ver[track.num].ver_id
        stored_version[#stored_version+1]= {guid = track.guid, num = track.num, ver_id = id}
      end
  else -- restore saved version/source
    reaper.PreventUIRefresh(1)
    for i = 1 , #stored_version do
      restoreTrackItems(stored_version[i].guid, stored_version[i].num)
    end  
    stored_version = nil
    --cur_ts_items = nil
    reaper.PreventUIRefresh(-1)
    for i = 1,#tbl do
      local track = find_guid(tbl[i]) 
      track.stored_num = nil
    end
    
  end
end

empty.onClick = function()
                  --if cur_sel[1] then new_empty() end
                  if empty.lbl:find("Folder") then
                    on_click_function(create_folder,"V")
                  else
                    on_click_function(create_track,"V")
                  end
                  reaper.UpdateArrange()
end

multi_tracks = {}
multi_edit.onClick = function()
    if multi_edit.num == 0 then multi_edit.num = 1 else multi_edit.num = 0 end
end
multi_edit.onRClick = function()
                      local me_menu = Menu:new(multi_edit.x,multi_edit.y,multi_edit.w,multi_edit.h,0.6,0.6,0.6,0.3,"","Arial",15,{0.7, 0.9, 1, 1},-1,{"Add Track","Remove Track"})
                      local me_menu_TB = {me_menu}
                      DRAW_M(me_menu_TB)
                      
                      for i = 1, reaper.CountSelectedTracks() do 
                        local sel_tr = reaper.GetTrackGUID(reaper.GetSelectedTrack(0,i-1))
                      
                        if me_menu.num == 1 then -- ADD TRACK
                          if not has_value2(multi_tracks,sel_tr) then -- prevent adding same track
                          multi_tracks[#multi_tracks+1] = sel_tr
                          end
                          
                        elseif me_menu.num == 2 then -- REMOVE TRACK
                          for i = 1 , #multi_tracks do
                            if multi_tracks[i] == sel_tr then multi_tracks[i] = nil end
                          end
                        else
                          return
                        end
                      end
                      
                     -- if #multi_tracks ~= 0 then CHANGE COLOR OF BUTTON end
end


copy.onRClick = function()
                  local cp_menu = Menu:new(copy.x,copy.y,copy.w,copy.h,0.6,0.6,0.6,0.3,"","Arial",15,{0.7, 0.9, 1, 1},-1,{})
                  for i = 1 ,#cur_sel[1].ver do cp_menu.ver[#cp_menu.ver+1] = cur_sel[1].ver[i].name end
                  local cp_menu_TB = {cp_menu}
                  DRAW_M(cp_menu_TB)
                
                  if cp_menu.num == -1 then return end
                
                  cur_sel[1].dest = cp_menu.num

                end
function multi_or_single_edit(tbl)
  reaper.PreventUIRefresh(1)
  local items = {}
  --GET ITEMS--------------
    for i = 1, #tbl do
      if view == 1 then
        for k = 1 ,#find_guid(tbl[i]).stored do
          items[#items+1] = find_guid(tbl[i]).stored[k]
        end
      end
      if all.num == 0 then -- SINGLE VIEW
        for j = 1,  reaper.CountTrackMediaItems( reaper.BR_GetMediaTrackByGUID( 0, tbl[i] ) ) do
          local item = reaper.GetTrackMediaItem( reaper.BR_GetMediaTrackByGUID( 0, tbl[i] ), j-1 )
          if get_time_sel() and get_items_in_ts(item) and view == 0 then items[#items+1] = get_items_in_ts(item) --end --  IF ITEM IS IN TIME SELECTION
          elseif not get_time_sel() and reaper.IsMediaItemSelected( item ) == true and view == 0 then items[#items+1] = item-- sel=true-- IF ITEM IS SELECTED, MAKE FLAG SEL TRUE
          end
        end
      else -- MULTIVIEW
        local cur_items = mute_view(find_guid(tbl[i]))
        for i = 1, #cur_items do
        if get_time_sel() and get_items_in_ts(cur_items[i]) then items[#items+1] = get_items_in_ts(cur_items[i])
        elseif not get_time_sel() and reaper.IsMediaItemSelected(cur_items[i]) == true then items[#items+1] = cur_items[i]
        end
      end
    end
  end
  --GET ITEMS FOR DESTINATION
  local data = {}
  local parent = find_guid(multi_parent)
  local destination_chunk
    for i = 1, #items do
      local chunk, fipm_item
      local item = items[i]
      local tr =  reaper.GetMediaItemTrack( item )
      local tr_guid = reaper.GetTrackGUID( tr )
      local tr_tbl = find_guid(tr_guid)
      
      if get_time_sel() and view == 0 then 
        fipm_item, chunk = make_item_from_ts(tr_tbl,item,tr)
        data[#data+1] = {tr_guid = tr_guid, chunk = chunk}
      elseif view == 1 then
        chunk = check_item_guid(tr_tbl,item)
        chunk = {pattern(chunk)} -- add it to chunk table
        data[#data+1] = {tr_guid = tr_guid, chunk = chunk}
      elseif not get_time_sel() and view == 0 then
        chunk = check_item_guid(tr_tbl,item)
        chunk = {pattern(chunk)} -- add it to chunk table
        data[#data+1] = {tr_guid = tr_guid, chunk = chunk}
      end
      if reaper.IsMediaItemSelected( item ) == true then reaper.SetMediaItemSelected( item, false ) end
    end
    
    --SET ITEMS TO DESTINATION 
      local destination 
      for i = 1, #data do
        local tr_tbl = find_guid(data[i].tr_guid)
        
        if view == 1 then -- IF VIEW TIME SELECTION MODE IS ON SET DESTINATION TO IT
          destination = tr_tbl.stored_num--has_id(tr_tbl,stored_version[j].ver_id)
        else
          destination = tr_tbl.dest
        end
        
        local tr_guid = tr_tbl.guid
        local tr = reaper.BR_GetMediaTrackByGUID( 0, tr_guid )  
    
        if all.num == 1 then   -- IF WE ARE IN MULTI VIEW
          fipm_item = reaper.AddMediaItemToTrack( tr )
          reaper.SetItemStateChunk(fipm_item, data[i].chunk[1], false)
          local destination_chunk = tr_tbl.ver[destination].chunk
          for j = 1, #data[i].chunk do destination_chunk[#destination_chunk+1] = data[i].chunk[j] end     
              
          update_fipm(tr_tbl) -- update FIPM (arrange new item)
              
          reaper.SetMediaItemSelected( fipm_item, true ) -- select it so command below can work
          reaper.Main_OnCommand(40930,0) -- trim content behind item 
              
          local stored_num = tr_tbl.num -- store current num
          local items = mute_view(tr_tbl,fipm_item) -- get items of version we just pasted item
          local fipm_chunk = {}
            for j = 1, #items do
              local _, item_chunk = reaper.GetItemStateChunk(items[j], '')  -- gets its chunk             
              fipm_chunk[#fipm_chunk+1] = pattern(item_chunk) -- add it to chunk table
            end
          tr_tbl.ver[destination].chunk = fipm_chunk -- replace whole chunk with new one (we need this because we trim content behind certain item)
          reaper.SetMediaItemSelected( fipm_item, false )
          restoreTrackItems(tr_guid,stored_num)
        else
          local stored_num = tr_tbl.num -- store current version num
          restoreTrackItems(tr_guid,destination) -- set version we will modify
          local fipm_item = reaper.AddMediaItemToTrack( tr )
          reaper.SetItemStateChunk(fipm_item, data[i].chunk[1], false)
          reaper.SetMediaItemSelected( fipm_item, true )
          reaper.Main_OnCommand(40930,0) -- trim content behind item 
          reaper.SetMediaItemSelected( fipm_item, false )
          tr_tbl.ver[destination].chunk = getTrackItems(tr) -- store chunk to version we are modifyng
          restoreTrackItems(tr_guid,stored_num) -- restore previous version
        end
      end
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end               
copy.onClick = function()
                if view == 0 and cur_sel[1].dest == cur_sel[1].num then return end -- prevent adding chunk of current version to current version
                ------------------------------
                --local tbl
                if multi_edit.num == 1 then --else tbl = {cur_sel[1].guid} end
                  multi_or_single_edit(multi_tracks)
                else
                  multi_or_single_edit({cur_sel[1].guid})
                end
          end
 
duplicate.onClick = function()
                if empty.lbl:find("Folder") then
                  on_click_function(create_folder,"D")
                else
                  on_click_function(create_track,"D")
                end
end

rename.onClick = function()
                    local box = find_guid(cur_sel[1].guid)
                    if not box.ver[box.num].name:find("Main") then -- prevent renaming original
                      local retval, version_name = reaper.GetUserInputs("Rename Version ", 1, "Version Name :", "")  
                      if not retval or version_name == "" then return end
                      box.ver[box.num].name = version_name
                    end
end

delete.onClick = function()
                    reaper.PreventUIRefresh(1)
                    local box = find_guid(cur_sel[1].guid)
                    if box.ver[box.num].name ~= "Main" then -- prevent deleting original if other version exist
                      delete_childs(box.ver[box.num].chunk, box.ver[box.num].ver_id) -- IF FOLDER DELETE CHILDS
                      table.remove(box.ver,box.num) -- REMOVE FROM FOLDER OR TRACK
                    else
                      if #box.ver == 1 then -- if only original left
                        delete_childs(box.ver[get_val].chunk, box.ver[box.num].ver_id) -- IF FOLDER DELETE CHILDS
                        table.remove(box.ver,box.num) -- REMOVE FROM FOLDER OR TRACK
                      end
                    end
                    if #box.ver ~= 0 and box.num ~= 0 then
                      if box.num > #box.ver then box.num = #box.ver box.dest = 1 end
                        if box.fipm == 1 then sort_fipm(box,cur_tr)
                        else restoreTrackItems(box.guid,box.num)
                        end
                    end
                    update_tbl() -- CHECK AND REMOVE BUTTON FROM MAIN TABLE IF VERSION IS EMPTY
                    reaper.PreventUIRefresh(-1)
end

ch_box1.onRClick = function()                  
                  cur_sel[1].env["Last_menu"] = ch_box1.num -- set last checked menu
end

ch_box1.onClick = function()
                  get_env() -- save envelope
end

menu_btn.onClick = function()
                    DRAW_M(menu_TB)
                    
                    if menu.num == -1 then return -- nothing clicked
                    elseif menu.num == 1 then manual_naming = not manual_naming
                    elseif menu.num == 2 then rec_takes = not rec_takes
                    elseif menu.num == 3 then store_original = not store_original
                    elseif menu.num == 4 then color = 1
                    elseif menu.num == 5 then color = 2
                    elseif menu.num == 6 then color = 3
                    end
                    
end

all.onClick = function ()
  reaper.PreventUIRefresh(1)
  if all.num == 0 then all.num = 1 else all.num = 0 end
  
  local tracks
    if get_folder(reaper.BR_GetMediaTrackByGUID(0,cur_sel[1].guid)) then
      tracks = get_folder(reaper.BR_GetMediaTrackByGUID(0,cur_sel[1].guid))
    elseif #multi_tracks ~= 0 then
      tracks = multi_tracks
    else
      tracks = {cur_sel[1].guid}
    end
  
  
  if get_folder(cur_tr) then 
    cur_sel[1].fipm = all.num 
    reaper.SetMediaTrackInfo_Value( cur_tr, "B_FREEMODE", cur_sel[1].fipm)
  end
  for i = 1 ,#tracks do
    local tr = reaper.BR_GetMediaTrackByGUID( 0, tracks[i] )
    local track = find_guid(tracks[i])
    track.fipm = all.num    
    reaper.SetMediaTrackInfo_Value( tr, "B_FREEMODE", track.fipm)
    local num_items = reaper.CountTrackMediaItems(tr)
      if all.num == 0 then
        for i = 1, num_items, 1 do reaper.DeleteTrackMediaItem(tr, reaper.GetTrackMediaItem(tr,0)) end -- remove all items from track       
        if track.num == 0 then restoreTrackItems(tracks[i], 0,{}) else restoreTrackItems(track.guid, track.num) end
      else   
        sort_fipm(track,tr)
      end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
end

local cur_comp_id
comp.onClick = function ()
  if comp.num == 0 then 
    comp.num = 1
    cur_comp_id = reaper.genGuid() 
  else 
    comp.num = 0 
    cur_comp_id = nil
  end
end
-------------------------------------------------------------------------------
---  Function SORT ITEMS IN FIPM MODE  ----------------------------------------
-------------------------------------------------------------------------------
function sort_fipm(tbl,tr)
  if not tbl then return end
  reaper.PreventUIRefresh(1)
  local num_items = reaper.CountTrackMediaItems(tr)
  for i = 1, num_items, 1 do reaper.DeleteTrackMediaItem(tr, reaper.GetTrackMediaItem(tr,0)) end -- remove all items from track            
  local track_h =  reaper.GetMediaTrackInfo_Value( tr, "I_WNDH")
  local offset = 0
  if track_h <= 42 then offset = 15 end
  local item_bar_h = ((19-offset) / track_h)
    for i = 1 , #tbl.ver do
      local chunk = tbl.ver[i].chunk
      local chunk_items_num = #tbl.ver
        for j = 1 , #chunk do
          local item = reaper.AddMediaItemToTrack(tr)
          reaper.SetItemStateChunk(item, chunk[j], false) -- set all versions on same track
          local item_h_FIPM = (1 - (chunk_items_num-1) * item_bar_h) / chunk_items_num
          local set_item_H = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_H", item_h_FIPM ) -- set item height (divide with number of items)
          local set_item_Y = reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", ((i-1) * (item_h_FIPM + item_bar_h))) -- add Y position
        end
    end
  mute_view(tbl)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
-------------------------------------------------------------------------------
---  Function REFRESH FIPM ----------------------
-------------------------------------------------------------------------------
function update_fipm(tbl)
  local offset = 0
  local cnt = #tbl.ver -- number of versions (because if split happens it should stay with current version)
  local track_h =  reaper.GetMediaTrackInfo_Value(  reaper.BR_GetMediaTrackByGUID( 0, tbl.guid ), "I_WNDH")
  if track_h <= 42 then offset = 15 end
  local bar_h_FIPM = ((19-offset) / track_h)
  local item_h_FIPM = (1 - (cnt-1) * bar_h_FIPM) / cnt 
  for i = 1 , cnt do
    for j = 1, #tbl.ver[i].chunk do
      local item = "{"..tbl.ver[i].chunk[j]:match('{(%S+)}').."}"
      item = reaper.BR_GetMediaItemByGUID( 0, item )
      if not item then return end
      local set_item_H =  reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_H", item_h_FIPM) -- set new item height 
      local set_item_Y =  reaper.SetMediaItemInfo_Value(item, "F_FREEMODE_Y", ((i-1) * (bar_h_FIPM + item_h_FIPM)))
    end
  end
  reaper.UpdateArrange()
end
-------------------------------------------------------------------------------
---  Function DONT KNOW WHY THE FUCK IS THIS HERE ANYWAY ----------------------
-------------------------------------------------------------------------------
function bool_to_number(value)
  return value and 1 or 0
end
-------------------------------------------------------------------------------
---  Function DONT KNOW WHY THE FUCK IS THIS HERE ANYWAY ----------------------
-------------------------------------------------------------------------------
function to_bool(value)
  if value == 1 then return true else return false end
end
-------------------------------------------------------------------------------
---  Function GET TRACK ENVELOPE ----------------------------------------------
-------------------------------------------------------------------------------
function get_env(job)
  local env, env_name, retval
  local tr = reaper.BR_GetMediaTrackByGUID(0,cur_sel[1].guid)
  local envs = reaper.CountTrackEnvelopes(tr)
    for i = 0, envs-1 do
      env = reaper.GetTrackEnvelope(tr, i)
      retval, env_name = reaper.GetEnvelopeName(env, "")
      if env_name == ch_box1.ver[ch_box1.num] then break end -- save only envelope that menu shows (VOLUME-PAN etc)
    end
    
  local sel_env = reaper.GetSelectedEnvelope( 0 ) --- for checking if other tracks envelope is selected
  if sel_env then 
    local env_tr = reaper.BR_EnvAlloc( sel_env, false )
    if reaper.GetTrackGUID(reaper.BR_EnvGetParentTrack( env_tr )) ~= cur_sel[1].guid then return end -- do not create envelope version if from other track  
  end
  if not env then return end
  
  local retval, strNeedBig = reaper.GetEnvelopeStateChunk(env, "", true)
  local visible = string.find(strNeedBig, "VIS 1")
  
  if not visible then return end
  
  reaper.Main_OnCommand(40331,0) -- unselect all points
  local retval, str = reaper.GetEnvelopeStateChunk(env, "", true) -- save current envelope chunk
  local trim = string.find(str, "PT") -- find where point chunk begins
  str = string.sub(str, trim-2) -- trim it before (we save only envelope points)
  local track = find_guid(cur_sel[1].guid)
  if job then return str end
  track.env[#track.env+1] = { [env_name] = str , name = env_name .. " " .. #set_env_box(cur_sel[1],"get_lenght")+1, id = reaper.genGuid()}
  track.env[ch_box1.ver[ch_box1.num]] = #set_env_box(cur_sel[1],"get_lenght")
end
--------------------------------------------------------------------------------
---  Function CHECKBOX FILTER TABLE  -------------------------------------------
--------------------------------------------------------------------------------
function set_env_box(tbl,job)
  if not tbl then return end
  local temp = {}  
  for i = 1 , #tbl.env do
    if type(tbl.env[i]) ~= "number" and tbl.env[i][ch_box1.ver[ch_box1.num]] then 
      temp[#temp+1]= tbl.env[i] -- add env table from main track to temp table
    end
  end
  if not job then envelope(tbl,temp) end
  return temp
end
--------------------------------------------------------------------------------
---  Function MERGE ENVELOPE CHUNKS  -------------------------------------------
--------------------------------------------------------------------------------
function set_envelope_chunk(env,point_chunk)
  local _, str = reaper.GetEnvelopeStateChunk(env, "", true)
  local trim = string.find(str, "PT")
  str = string.sub(str, 0,trim-3) -- trim it after
  local env_chunk = str .. point_chunk
  return env_chunk
end
--------------------------------------------------------------------------------
---  Function SET ENVELOPE VERSION  --------------------------------------------
--------------------------------------------------------------------------------
function envelope(tbl,data) 
  ch_box1.num = tbl.env["Last_menu"] -- restore last checked menu
  if not tbl then return end
  box_env.num, box_env.ver = tbl.env[ch_box1.ver[ch_box1.num]], data -- set stored num from main table (Volume,Pan,Width), set data table as ver
  local tr = reaper.BR_GetMediaTrackByGUID(0,tbl.guid)

  box_env.onClick = function()
                  local env = reaper.GetTrackEnvelopeByName( tr, ch_box1.ver[ch_box1.num] ) 
                  local point_chunk = box_env.ver[box_env.num][ch_box1.ver[ch_box1.num]]
                  local env_chunk = set_envelope_chunk(env,point_chunk)
                  reaper.SetEnvelopeStateChunk(env, env_chunk, false )
                  tbl.env[ch_box1.ver[ch_box1.num]] = box_env.num -- change check in original table                  
  end
  
  box_env.onRClick = function()
                    local r_click_menu = Menu:new(box_env.x,box_env.y,box_env.w,box_env.h,0.6,0.6,0.6,0.3,"Chan :","Arial",15,{0.7, 0.9, 1, 1},-1,
                                                                          {"Delete Version","Rename Version","Save current version"})
                    local menu_TB = {r_click_menu}
                    DRAW_M(menu_TB)
                    local env_id = box_env.ver[box_env.num].id --selected
                    local env_id_h = box_env.ver[get_val].id --highlighted
                    local env_type = ch_box1.ver[ch_box1.num]
                    
                    if r_click_menu.num == -1 then return -- nothing clicked
                                     
                    elseif r_click_menu.num == 1 then --- delete version
                        table.remove(box_env.ver,box_env.num) -- remove from envelope button
                          for i = #tbl.env , 1, -1 do
                            if tbl.env[i].id == env_id then table.remove(tbl.env,i) end -- remove from main button
                          end
                      if box_env.num > #set_env_box(cur_sel[1],"get") then 
                        tbl.env[ch_box1.ver[ch_box1.num]] = #set_env_box(cur_sel[1],"get") 
                        box_env.num = #set_env_box(cur_sel[1],"get")
                      end
                      if box_env.num ~= 0 then
                        local point_chunk = box_env.ver[box_env.num][ch_box1.ver[ch_box1.num]]
                        local env = reaper.GetTrackEnvelopeByName( tr, ch_box1.ver[ch_box1.num] )
                        local env_chunk = set_envelope_chunk(env,point_chunk)
                        reaper.SetEnvelopeStateChunk(env, env_chunk, false )
                      end
                      
                    elseif r_click_menu.num == 2 then --- rename version
                      local retval, version_name = reaper.GetUserInputs("Rename Version ", 1, "Version Name :", "")  
                      if not retval or version_name == "" then return end
                        for i = #tbl.env , 1, -1 do
                          if tbl.env[i].id == env_id_h then tbl.env[i].name = version_name end -- remove from main button
                        end
                        
                    elseif r_click_menu.num == 3 then --- Save version
                        for i = #tbl.env , 1, -1 do
                          if tbl.env[i].id == env_id then tbl.env[i][env_type] = get_env("get") end -- remove from main button
                        end
                    end
  end
  ------------------- AUTOSELECT ENVELOPE MENU BASED ON SELECTED TRACKS ENVELOPE -------------------
  local sametrack
  local sel_env = reaper.GetSelectedEnvelope( 0 ) -- if envelope is selected 
    if sel_env then
      local retval, env_name = reaper.GetEnvelopeName(sel_env, "")
      local env_tr = reaper.BR_EnvAlloc( sel_env, false )
      if reaper.GetTrackGUID(reaper.BR_EnvGetParentTrack( env_tr )) ~= cur_sel[1].guid then sametrack = true end--or ch_box1.ver[ch_box1.num] ~= env_name then end -- do not create envelope version if from other track or does not match current checbox name
        
        for i = 1 , #ch_box1.ver do 
          if env_name == ch_box1.ver[i] then tbl.env["Last_menu"] = i end
        end
    end
 
  if not sametrack then DRAW_C(env) end -- if other track envelope is selected do not show versions
  if reaper.CountSelectedTracks() < 2 then DRAW_CH(CheckBox_TB) end -- disable checbox envelope button if multiple tracks selected
end
--------------------------------------------------------------------------------------------
function literalize(str) -- http://stackoverflow.com/questions/1745448/lua-plain-string-gsub
     if str then  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", function(c) return "%" .. c end) end
end
-------------------------------------------------------------------------------------------------------------
---  Function GET INTIGER FROM ITEM IN FIPM MODE  (SELECTING ITEM SELECTS VERSION AND VICE VERSA ------------
-------------------------------------------------------------------------------------------------------------
function get_num_from_cordinate2(tbl,item) -- gets num value from table if selected item guid is found
  local item_guid = reaper.BR_GetMediaItemGUID( item )
    for i = 1, #tbl.ver do
      for j = 1, #tbl.ver[i].chunk do
        local stored_guid = "{"..tbl.ver[i].chunk[j]:match('{(%S+)}').."}"
        if item_guid == stored_guid then
          return i
        else
        end
      end
    end
end
--------------------------------------------------------------------------------
---  Function MUTE VIEW (VIEW ALL VERSION AT ONCE   ----------------------------
--------------------------------------------------------------------------------
function mute_view(tbl,prt)
  if not tbl then return end
  local num
  local tr = reaper.BR_GetMediaTrackByGUID(0,tbl.guid)
  local items = {}
  local sel_item = reaper.GetSelectedMediaItem(0,0)
    
  if sel_item and get_num_from_cordinate2(tbl,sel_item) ~= nil then tbl.num = get_num_from_cordinate2(tbl,sel_item) num = get_num_from_cordinate2(tbl,sel_item) end -- set version to selected media item (avoid seting track num to nil with "get_num_from_cordinate2(tbl,sel_item) ~= nil"      
      
    for i = 1, reaper.CountTrackMediaItems(tr) do -- go to all items and mute all which are not selected via click or by version in gui
      local item = reaper.GetTrackMediaItem(tr, i-1)
      if tbl.num == get_num_from_cordinate2(tbl,item) or get_num_from_cordinate2(tbl,item) == nil then -- avoid muting splitted items with "get_num_from_cordinate2(tbl,item) ~= nil"
        reaper.SetMediaItemInfo_Value( item, "B_MUTE", 0 )
        items[#items+1] = item
      else
        reaper.SetMediaItemInfo_Value( item, "B_MUTE", 1 )
      end
    end
  reaper.UpdateArrange()
  return items,num
end 
--------------------------------------------------------------------------------
---  Function Get Tracks -------------------------------------------------------
--------------------------------------------------------------------------------   
function get_tracks()
  local tracks = {}
  if has_value2(multi_tracks,cur_sel[1].guid) and multi_edit.num == 1 then return multi_tracks  -- IF CURRENTLY SELECTED TRACK IS IN GROUP
  elseif not has_value2(multi_tracks,cur_sel[1].guid) and multi_edit.num == 1 or multi_edit.num == 0 then --IF SELECTED TRACK IS NOT IN GROUP OD GROUP EDITING IS DISABLES
    for i = 1, reaper.CountSelectedTracks() do 
      local sel_tr = reaper.GetTrackGUID(reaper.GetSelectedTrack(0,i-1))
      tracks[#tracks+1] = sel_tr
    end
    return tracks
  end
end              
--------------------------------------------------------------------------------
---  Function Create Button ----------------------------------------------------
--------------------------------------------------------------------------------
function create_button(name,guid,chunk,ver_id,num,env,fipm,dest)
  local v_table = {chunk = chunk, ver_id = ver_id, name = name}  
  local env_tb = env or {}
  local fipm, dest = fipm or 0, dest or 1
  
  if not env then
    for i = 1, #env_type do
      env_tb[env_type[i].name] = env_type[i].v
    end
  end
  local tr = reaper.BR_GetMediaTrackByGUID( 0, guid )
  local box = Radio_Btns:new(116,46,120,20,  0.2,0.2,1.0,0.7, "","Arial",15,{0.7, 0.9, 1, 1},1, {v_table}, guid , env_tb, fipm, dest)
  if not find_guid(guid) then -- if ID does not exist in the table create new checklist
    TrackTB[#TrackTB+1] = box -- add new box 
  else -- if ID exists in the table then only add new chunk to it
    local version = find_guid(guid)
    version.ver[#version.ver+1] = v_table -- add state to ver table (insert at last index)
    version.num = num or #version.ver
  end
    
  box.onClick = function() -- check box on click action
                reaper.PreventUIRefresh(1)
                reaper.Main_OnCommand(40289,0) -- unselect all items
                --[[
                if multi_edit.num == 0 then
                  for i = 1, reaper.CountSelectedTracks() do 
                    local sel_tr = reaper.GetTrackGUID(reaper.GetSelectedTrack(0,i-1))
                    local tr = find_guid(sel_tr)
                      if tr and box.num <= #tr.ver then -- for multiselection (if other track does not have same number of versions,or if other track exists in table)
                        if tr.last_num ~= box.num then restoreTrackItems(tr.guid,box.num) tr.last_num = box.num end -- prevent activating current button (save cpu)
                      end
                  end
                else
                  for i = 1, #multi_tracks do
                    local tr = find_guid(multi_tracks[i])
                    --restoreTrackItems(tr.guid,box.num)
                     -- if tr and box.num <= #tr.ver then -- for multiselection (if other track does not have same number of versions,or if other track exists in table)
                        if tr.last_num ~= box.num then restoreTrackItems(tr.guid,box.num) tr.last_num = box.num end -- prevent activating current button (save cpu)
                      --end
                  end
                end
                ]]
                local tracks = get_tracks()
                for i = 1, #tracks do
                  local tr = find_guid(tracks[i])
                  if tr and box.num <= #tr.ver then -- for multiselection (if other track does not have same number of versions,or if other track exists in table)
                    if tr.last_num ~= box.num then restoreTrackItems(tr.guid,box.num) tr.last_num = box.num end -- prevent activating current button (save cpu)
                  end
                end
                
                reaper.PreventUIRefresh(-1)
                reaper.UpdateArrange()
  end -- end box.onClick
  box.onRClick =  function()
                  local r_click_menu = Menu:new(box.x,box.y,box.w,box.h,0.6,0.6,0.6,0.3,"Chan :","Arial",15,{0.7, 0.9, 1, 1},-1,
                                               {"Delete Version","Delete All Except","Rename Version","Duplicate","Save current version"})
                  local menu_TB = {r_click_menu}
                  DRAW_M(menu_TB)
                  
                  if r_click_menu.num == -1 then return -- nothing clicked
                  
                  elseif r_click_menu.num == 1 then --- delete version
                    if box.ver[get_val].name ~= "Main" then -- prevent deleting original if other version exist
                      delete_childs(box.ver[get_val].chunk, box.ver[get_val].ver_id) -- IF FOLDER DELETE CHILDS
                      table.remove(box.ver,get_val) -- REMOVE FROM FOLDER OR TRACK
                    else
                      if #box.ver == 1 then -- if only original left
                        delete_childs(box.ver[get_val].chunk, box.ver[get_val].ver_id) -- IF FOLDER DELETE CHILDS
                        table.remove(box.ver,get_val) -- REMOVE FROM FOLDER OR TRACK
                      end
                    end
                    if #box.ver ~= 0 and box.num ~= 0 then
                      if box.num > #box.ver then box.num = #box.ver end
                        if box.fipm == 1 then sort_fipm(box,cur_tr)
                        else restoreTrackItems(box.guid,box.num)
                        end
                    end
                    update_tbl() -- CHECK AND REMOVE BUTTON FROM MAIN TABLE IF VERSION IS EMPTY
                     
                  elseif r_click_menu.num == 3 then --- rename button
                    if not box.ver[get_val].name:find("Main") then -- prevent renaming original
                      local retval, version_name = reaper.GetUserInputs("Rename Version ", 1, "Version Name :", "")  
                      if not retval or version_name == "" then return end
                      box.ver[get_val].name = version_name
                    end
                    
                  elseif r_click_menu.num == 5 then -- save current version (save modifications)
                    if box.num == 0 then return end
                    if string.sub(box.ver[box.num].chunk[1],1,1) == "{" then -- FOLDER
                      for i = 1, #box.ver[box.num].chunk do
                        local child = find_guid(box.ver[box.num].chunk[i])
                          if string.sub(child.ver[child.num].chunk[1],1,1) ~= "{" then -- NOT SUBFOLDER (SINCE IT CONTAINS ONLY GUIDS OF CHILDS AND VID)
                            child.ver[child.num].chunk = getTrackItems(reaper.BR_GetMediaTrackByGUID(0,child.guid))
                          end
                      end
                    else
                      if all.num == 1 then
                        local items = mute_view(box)
                        local chunk = {}
                          for i = 1, #items do
                            local _, item_chunk = reaper.GetItemStateChunk(items[i], '')  -- gets its chunk             
                            chunk[#chunk+1] = pattern(item_chunk) -- add it to chunk table
                          end
                            box.ver[box.num].chunk = chunk                        
                      else
                        box.ver[box.num].chunk = getTrackItems(reaper.BR_GetMediaTrackByGUID(0,box.guid))
                      end
                    end
                  
                  elseif r_click_menu.num == 4 then --- DUPLICATE
                    local chunk = box.ver[get_val].chunk  
                    local duplicate_num = naming(box,"D",box.ver[get_val].ver_id)-- .. " - " .. box.ver[get_val].name
                    local duplicate_name = duplicate_num .. " - " .. box.ver[get_val].name 
                    local ver_id = box.ver[get_val].ver_id .. duplicate_num
                    if reaper.GetMediaTrackInfo_Value(reaper.BR_GetMediaTrackByGUID(0, box.guid), "I_FOLDERDEPTH") == 1 then
                      local p_vid = box.ver[get_val].ver_id
                      create_button(duplicate_name,box.guid,chunk,ver_id)
                        for i = 1, #chunk do
                          local child = find_guid(chunk[i])
                            for j = 1, #child.ver do
                              if child.ver[j].ver_id == p_vid then
                                local c_chunk = child.ver[j].chunk
                                --c_chunk = check_item_guid(TrackTB,val,c_chunk)
                                local c_name = child.ver[j].name
                                local c_vid = child.ver[j].ver_id .. duplicate_num
                                local duplicate_num = naming(child,"D",child.ver[j].ver_id)-- .. " - " .. box.ver[get_val].name
                                local duplicate_name = duplicate_num .. " - " .. child.ver[j].name
                                create_button(duplicate_name,child.guid,c_chunk,ver_id)
                              end
                            end
                        end
                      --create_folder(reaper.BR_GetMediaTrackByGUID(0, box.guid),duplicate_name,box.ver[get_val].ver_id .. duplicate_num)
                    else 
                      create_button(duplicate_name,box.guid,chunk,ver_id)                 
                      --create_track(reaper.BR_GetMediaTrackByGUID(0, box.guid),duplicate_name,box.ver[get_val].ver_id .. duplicate_num)
                    end
                    
                  elseif r_click_menu.num == 2 then --- remove except
                    for i = #box.ver , 2, -1 do
                      if box.num ~= i then table.remove(box.ver,i) end -- TRACK OR MAIN FOLDER - trim to only one version
                    end
                    box.num = #box.ver -- set last active
                    delete_childs(box.ver[box.num].chunk, box.ver[box.num].ver_id, 2) -- IF FOLDER HAS CHILDS THEN TRIM ALL THE CHILDS TO SAME VERSION (2 is job and not to remove ORIGINAL)
                  end
                  save_tracks()
  end -- end box.onRClick
  --reaper.UpdateArrange()                      
end -- end create_button()
--------------------------------------------------------------------------------
---  Function REMOVE PATTERNS FROM CHUNK ---------------------------------------
--------------------------------------------------------------------------------
function pattern(chunk,guid)
  local patterns = {"SEL 0", "SEL 1"}
  for i = 1 , #patterns do chunk = string.gsub(chunk, patterns[i], "") end -- remove SEL part of the chunk (chunk is considered changed if its selected or not)    
  if guid then
    chunk = string.gsub(chunk, guid, "")
  end 
  return chunk
end
--------------------------------------------------------------------------------
---  Function round number  ----------------------------------------------------
--------------------------------------------------------------------------------
function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end
--------------------------------------------------------------------------------
---  Function SET COLORS -------------------------------------------------------
--------------------------------------------------------------------------------
function set_color(tr,tbl,job)
  if not tbl then return end
  local tbl_col = {tbl, env[1]}
  local col =  reaper.GetTrackColor( tr )
  local r, g, b = reaper.ColorFromNative( col )
  r,g,b = round(r/255,1), round(g/255,1), round(b/255,1)
  for i = 1, #tbl_col do
  if job == 1 then
    tbl_col[i].r,tbl_col[i].g,tbl_col[i].b = r,g,b
  elseif job == 2 then
    tbl_col[i].fnt_rgba = {r,g,b,1}
  elseif job == 3 then 
    tbl_col[i].r,tbl_col[i].g,tbl_col[i].b = r,g,b
    tbl_col[i].fnt_rgba = {r,g,b,1}
  end
  end
end
--------------------------------------------------------------------------------
---  Function GET TIME SELECTION  ----------------------------------------------
--------------------------------------------------------------------------------
function get_time_sel()
local t_start, t_end = reaper.GetSet_LoopTimeRange(0, true, 0, 0, false)
  if t_start == 0 and t_end == 0 then return false
  else
  return t_start, t_end
  end
end
--------------------------------------------------------------------------------
---  Function SOME RANDOM SHIT DONT KNOW WHERE I USE IT  -----------------------
--------------------------------------------------------------------------------
function has_undo(tab, val)
  for i = 1 , #tab do
    local in_table = tab[i]
    if in_table == val then
      return i
    end
  end
return false
end

function has_value2(tab, val)
  for i = 1 , #tab do
    local in_table = tab[i]
    if in_table == val then
      return i
    end
  end
return false
end
--------------------------------------------------------------------------------
---  Function FIND IF VER ID EXISTS IN TABLE  ----------------------------------
--------------------------------------------------------------------------------
function has_id(tab, val)
  for i = 1 , #tab.ver do
    local in_table = tab.ver[i].ver_id
    if in_table == val then
      return i, tab.ver[i].chunk
    end
  end
return false
end

function has_item(tbl,val)
  local item_guid = reaper.BR_GetMediaItemGUID( val )
  for i = 1, #tbl do
    local stored_guid = "{"..tbl[i]:match('{(%S+)}').."}"
    if item_guid == stored_guid then
      return item_guid
    end
  end
end

function has_item2(tbl,val)
  local item_guid = reaper.BR_GetMediaItemGUID( val )
  for i = 1, #tbl do
    for j = 1, #tbl[i].items do
      local stored_guid = tbl[i].items[j]
        if item_guid == stored_guid then
          return item_guid
        end
    end
  end
end

function has_track(tbl,val)
  local track_guid = reaper.GetTrackGUID( val )
  for i = 1, #tbl do
    local stored_guid = tbl[i].guid
    if track_guid == stored_guid then
      return tbl[i]
    end
  end
end
--------------------------------------------------------------------------------
---  Function MAKE VERSION FROM RECORDED TAKES  --------------------------------
--------------------------------------------------------------------------------
function takes_to_version()
  reaper.PreventUIRefresh(1)
  local rec_tb = {}
  
  --reaper.Main_OnCommand(41329,0) -- New Recordings Create New items in separate Lanes
 
  for j = reaper.CountSelectedMediaItems( 0 ),1, -1 do   -- reverse because is error prone to deleting shit inside
    local s_item = reaper.GetSelectedMediaItem(0, j-1)
    local _, item_chunk = reaper.GetItemStateChunk(s_item, '')  -- gets its chunk
    local tr = reaper.GetMediaItemTrack( s_item )
      if #rec_tb == 0 or tr ~= rec_tb[#rec_tb].track then    
        rec_tb[#rec_tb+1] = {chunk = {item_chunk}, track = tr }
      else
        rec_tb[#rec_tb].chunk[#rec_tb[#rec_tb].chunk+1] = item_chunk
      end
     reaper.DeleteTrackMediaItem(tr,s_item)
  end
   
    for i = 1, #rec_tb do 
      local t = 1 
      local tr = reaper.GetTrackGUID(rec_tb[i].track)
        for j = #rec_tb[i].chunk ,1, -1 do
          local chunk = {rec_tb[i].chunk[j]}
          create_button("Take ".. t, tr, chunk, reaper.genGuid())   -- create version from it with Take prefix
          t = t + 1
          restoreTrackItems(tr,#find_guid(tr).ver) -- restore them
      end
    end
  if reaper.GetToggleCommandState( 41329 ) == 1 then reaper.Main_OnCommand(41329,0) end -- if crteate new recordings to separate lanes is activated deactivate it  
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

function title_and_button_upd(tr)  
  local retval, name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false) 
  local tr_num = math.floor(reaper.GetMediaTrackInfo_Value( tr, "IP_TRACKNUMBER" ))
  if cur_sel[1] and cur_sel[1].dest > 0 and #cur_sel[1].ver ~= 0 then copy.lbl = "To - " .. cur_sel[1].ver[cur_sel[1].dest].name end
  if view == 1 then copy.lbl = "To - " .. cur_sel[1].ver[cur_sel[1].stored_num].name end
  --Wnd_Title = tr_num .. " : " .. name
 -- local title = Title:new(55,15,70,20, 0.2,0.2,1.0,0, tr_num .. " : " .. name, "Arial",15,{0.7, 0.9, 1, 1}, 0 )
 -- local title_TB = {title}
  if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then empty.lbl = "New Folder" else empty.lbl = "New Track" end-- else DRAW_B(Track) end-- draw save folder button only if folder track is selected  DRAW_B(Folder)  
  --DRAW_M(title_TB)
end
--------------------------------------------------------------------------------
---  Function SET ITEM POSITION AND LENGHT BASED ON TS  ------------------------
--------------------------------------------------------------------------------
function ts_item_position(item)
  local tsStart, tsEnd = get_time_sel()  
  local item_lenght =  reaper.GetMediaItemInfo_Value( item, "D_LENGTH" ) 
  local item_start = reaper.GetMediaItemInfo_Value( item, "D_POSITION")
  local item_dur = item_lenght + item_start 
    
  local new_start,new_item_lenght,offset
    if tsStart < item_start and tsEnd > item_start and tsEnd < item_dur then
      new_start,new_item_lenght,offset = item_start, tsEnd-item_start, 0
      return new_start,new_item_lenght,offset,item
      ----- IF TS START IS IN ITEM BUT TS END IS OUTSIDE THEN COPY ONLY PART FROM TS START TO ITEM END
    elseif tsStart < item_dur and tsStart > item_start and tsEnd > item_dur then
      new_start,new_item_lenght,offset = tsStart, item_dur-tsStart,( tsStart-item_start )
      return new_start,new_item_lenght,offset,item 
      ------ IF BOTH TS START AND TS END ARE IN ITEM COPY PART FROM TS START TO TS END
    elseif tsStart >= item_start and tsEnd <= item_dur then
      new_start,new_item_lenght,offset = tsStart, tsEnd-tsStart, ( tsStart-item_start )
      return new_start,new_item_lenght,offset,item
      ------ IF BOTH TS START AND TS END ARE OUT OF ITEM BUT ITEM IS IN TS COPY ITEM START END
    elseif tsStart <= item_start and tsEnd > item_dur then
      new_start,new_item_lenght,offset = item_start, item_lenght, 0
      return new_start,new_item_lenght,offset,item
    end
end
--------------------------------------------------------
---  Function SHRINK ITEMS TO TIME SELECTION --
--------------------------------------------------------
function show_ts_version(item)
  local take = reaper.GetMediaItemTake( item, 0 )
  if not take then return end 
  local new_item_start,new_item_lenght, offset = ts_item_position(item)
    
  reaper.SetMediaItemInfo_Value( item, "D_POSITION", new_item_start )
  reaper.SetMediaItemInfo_Value( item, "D_LENGTH", new_item_lenght )
  
  local takeOffset = reaper.GetMediaItemTakeInfo_Value(take,"D_STARTOFFS")
  reaper.SetMediaItemTakeInfo_Value( take, "D_STARTOFFS", takeOffset + offset)
  
  reaper.SetMediaItemSelected( item, true )
  reaper.Main_OnCommand(40930,0) -- trim content behind item -- SPAMMING UNDO HISTORY
  reaper.SetMediaItemSelected( item, false )
  return item
end
--------------------------------------------------------
---  Function MAKE ITEMS BASED TIME SELECTION (SWIPING)--
--------------------------------------------------------
function make_item_from_ts(tbl,item,track)
  local filename,clonedsource
  local take =  reaper.GetMediaItemTake( item, 0 )
  local source = reaper.GetMediaItemTake_Source( take )
  local m_type = reaper.GetMediaSourceType( source, "" )
  local item_volume = reaper.GetMediaItemInfo_Value( item, "D_VOL" )
  
  local swipedItem = reaper.AddMediaItemToTrack( track )
  local swipedTake = reaper.AddTakeToMediaItem( swipedItem )
  
  if m_type:find("MIDI") then
    local midi_chunk = check_item_guid(tbl,item,m_type)
    reaper.SetItemStateChunk(swipedItem,  midi_chunk, false)
  else
    filename = reaper.GetMediaSourceFileName(source, "")
    clonedsource = reaper.PCM_Source_CreateFromFile(filename)
  end
  
  local new_item_start,new_item_lenght, offset = ts_item_position(item)
  reaper.SetMediaItemInfo_Value( swipedItem, "D_POSITION", new_item_start )
  reaper.SetMediaItemInfo_Value( swipedItem, "D_LENGTH", new_item_lenght )
  local swipedTakeOffset =  reaper.GetMediaItemTakeInfo_Value(take,"D_STARTOFFS")
  reaper.SetMediaItemTakeInfo_Value( swipedTake, "D_STARTOFFS", swipedTakeOffset + offset)
  
  if m_type:find("MIDI") == nil then reaper.SetMediaItemTake_Source(swipedTake, clonedsource) end
  
  reaper.SetMediaItemInfo_Value( swipedItem, "D_VOL", item_volume )
  
  local _, swipe_chunk = reaper.GetItemStateChunk(swipedItem, '')
  swipe_chunk = {pattern(swipe_chunk)}
  
  return swipedItem,swipe_chunk
end
--------------------------------------------------------------------------------
---  Function SWIPE COMPING   --------------------------------------------------
--------------------------------------------------------------------------------
function comping(tbl)
    if not tbl then return end
    local tsStart, tsEnd = get_time_sel()
    
    local tracks = tbl
    if folder then tracks = get_folder(cur_tr) end
    
    for i = 1, #tracks do
      local track =  reaper.BR_GetMediaTrackByGUID(0,tracks[i]) -- get curent track
      local tr_tbl = find_guid(tracks[i])
      local unmuted_items = mute_view(tr_tbl)
      local tsitems = {}
      local filename, clonedsource
    
      for i = 1 , #unmuted_items do
        if get_items_in_ts(unmuted_items[i]) then
          tsitems[#tsitems+1] = get_items_in_ts(unmuted_items[i])
        end
      end
     
      --if #tsitems == 0 then return end
    
      for i = 1, #tsitems do
        local tsitem = tsitems[i]
        local ItemTrack = reaper.GetMediaItem_Track( tsitem ) -- get item track
      
        if ItemTrack ~= track then return end -- if sel item track is not the same as sel track end
        if cur_comp_id == tr_tbl.ver[tr_tbl.num].ver_id then return end -- DO NOT ALLOW CREATING COMP OF ITSELF (IF COMP IS SELECTED JUST TO PREVIEW)     
      
        reaper.Undo_BeginBlock()
        local swipedItem, swipe_chunk = make_item_from_ts(tr_tbl,tsitem,track)
        local num = has_id(tr_tbl, cur_comp_id)
          
          if not num then --and is_folder ~= 1 then
            local cur_num = tr_tbl.num -- store current selected version
            create_button("COMP",tr_tbl.guid,swipe_chunk,cur_comp_id) -- 1 is to insert at first position
            --else create_button("COMP",tr_tbl.guid,get_folder(track),cur_comp_id) -- child is a folder
            tr_tbl.num = cur_num -- prevent switching to latest created version while creating new comp
          else
            tr_tbl.ver[num].chunk[#tr_tbl.ver[num].chunk+1] = swipe_chunk[1]
          end
             
        if tr_tbl.num ~= get_num_from_cordinate2(tr_tbl,swipedItem) then reaper.SetMediaItemInfo_Value( swipedItem, "B_MUTE", 1 ) end -- mute newly created comp items (for preventing double playback)
      
      end
      
      if folder then
        local f_num = has_id(cur_sel[1], cur_comp_id)
        if not f_num then
          local cur_num = cur_sel[1].num -- store current selected version 
          create_button("COMP",cur_sel[1].guid,get_folder(cur_tr),cur_comp_id)
          cur_sel[1].num = cur_num 
        end
      end
      
    update_fipm(tr_tbl)
  end
  
    prevStart,prevEnd = tsStart,tsEnd
    reaper.UpdateArrange()
    reaper.Undo_EndBlock( "Swipe comp", 0 )
    reaper.Undo_OnStateChange( "Swipe comp" )
end
--------------------------------------------------------------------------------
---  Function GET TRANSPORT AND LOOP STATE -------------------------------------
--------------------------------------------------------------------------------
function get_transport()
  local trans, loop = reaper.GetPlayState(), reaper.GetSetRepeat(-1)
  if trans&5 == 5 then -- if recording
    if reaper.GetToggleCommandState( 41329 ) == 0 then reaper.Main_OnCommand(41329,0) end -- if create new lanes when recording is off turn it on
  end
  if trans&5 == 5 and loop == 1 then return true end
end
--------------------------------------------------------------------------------
---  Function AUTO SAVE --------------------------------------------------------
--------------------------------------------------------------------------------
function auto_save(last_action)
local tracks_tbl = {}
--if not cur_sel[1] or folder or cur_sel[1].num == 0 then return end
local ignore =  {"marquee item selection","change media item selection","unselect all items","remove material behind selected items" } -- undo which will ignore auto save
  if not has_undo(ignore,last_action) then
    if last_action:find("item") or last_action:find("recorded media") or last_action:find("midi editor: insert notes") then
      local cnt = reaper.CountSelectedMediaItems(0)
      ---- if no items are selected (track only)
      if cnt == 0 and not folder then tracks_tbl[#tracks_tbl+1] = cur_sel[1] end
      ---- if multiple items across tracks are selected get that tracks
        for i = 1 , cnt do
          local sel_item = reaper.GetSelectedMediaItem( 0, i-1 )
          local tr = reaper.GetMediaItemTrack( sel_item )
          local tr_guid = reaper.GetTrackGUID(tr)
          local tbl = find_guid(tr_guid)
          if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") ~= 1 then -- AVOID SAVING ITEMS ON FOLDERS
            tracks_tbl[#tracks_tbl+1] = tbl
          end
        end
        for i = 1, #tracks_tbl do
          local track = tracks_tbl[i]
            if all.num == 0 then -- if multi view is disable
              ------------TRACK --------------------------------                     
              track.ver[track.num].chunk = getTrackItems(reaper.BR_GetMediaTrackByGUID( 0, track.guid))
            else -- if multi view is enabled
              local items = mute_view(track)
              local chunk = {}
                for i = 1, #items do
                  local _, item_chunk = reaper.GetItemStateChunk(items[i], '')  -- gets its chunk             
                  chunk[#chunk+1] = pattern(item_chunk) -- add it to chunk table
                end
              track.ver[track.num].chunk = chunk
            end
        end   
    end
  end
end
--------------------------------------------------------------------------------
---  Function MAIN -------------------------------------------------------------
--------------------------------------------------------------------------------
function main()
  local sel_item
  local sel_tr = reaper.GetSelectedTrack(0,0) -- get track 
    if sel_tr then
      cur_tr = sel_tr
      title_and_button_upd(sel_tr) -- update title name (track name) buttons etc
      folder = to_bool(reaper.GetMediaTrackInfo_Value(cur_tr, "I_FOLDERDEPTH"))
      local tr_h =  reaper.GetMediaTrackInfo_Value(cur_tr, "I_WNDH")
      cur_sel[1] = find_guid(reaper.GetTrackGUID(sel_tr)) -- VIEW CURRENT SELECTED TRACK VERSIONS
      all.num = reaper.GetMediaTrackInfo_Value( cur_tr, "B_FREEMODE" ) -- check if track is in FIP mode (highlight button)       
      set_env_box(cur_sel[1])
      set_color(sel_tr,cur_sel[1],color) 
      if cur_sel[1] and #cur_sel[1].ver > 1 then DRAW_B(all_tb) DRAW_B(Copy) else reaper.SetMediaTrackInfo_Value( cur_tr, "B_FREEMODE",0 ) end -- if there are more than 1 version show all version buttons (else disable FIPM)
      if all.num == 1 then DRAW_B(comp_tb)
        if tr_h ~= last_tr_h then
          for i = 1, #TrackTB do
            if TrackTB[i].fipm == 1 then
            update_fipm(TrackTB[i])
            end
          end 
          last_tr_h = tr_h
        end
      end
      DRAW_B(multi_tb)
      DRAW_C(cur_sel)
    end
    local tracks
    local proj_change_count = reaper.GetProjectStateChangeCount(0)
      if proj_change_count > last_proj_change_count then      
        local last_action = reaper.Undo_CanUndo2(0)
          if last_action == nil then return end
            last_action = reaper.Undo_CanUndo2(0):lower()
            auto_save(last_action)
            if last_action:find("remove tracks") then track_deleted()  -- run only if action "Remove tracks" is found
            elseif last_action:find("recorded media") then takes_to_version() -- IF REC_TAKES IS ENABLED MAKE VERSIONS FROM TAKE
            elseif last_action:find("time selection change") and comp.num == 1 then if multi_edit.num == 1 and #multi_tracks ~= 0 then tracks = multi_tracks else tracks = {cur_sel[1].guid} end comping(tracks)
            elseif ( last_action:find("change media item selection") or last_action:find("change track selection") ) and all.num == 1 then
              mute_view(cur_sel[1])
                if multi_edit.num == 1 then 
                  for i=1, #multi_tracks do
                    local tr = find_guid(multi_tracks[i])
                    restoreTrackItems(tr.guid,cur_sel[1].num)
                  end
                end
            end
        last_proj_change_count = proj_change_count
      end
end
----------------------------------------------------------------------------------------------------
---   Main DRAW function   -------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
function DRAW_B(tbl)
    for key,btn     in pairs(tbl)   do btn:draw()    end
end
function DRAW_C(tbl)    
    for key,box     in pairs(tbl)   do box:draw()    end 
end
function DRAW_F(tbl)
    for key,frame   in pairs(tbl)   do frame:draw()  end 
end
function DRAW_M(tbl)
    for key,menu    in pairs(tbl)   do menu:draw()   end
end
function DRAW_CH(tbl)
    for key,ch_box  in pairs(tbl)   do ch_box:draw() end 
end
--------------------------------------------------------------------------------
--   SAVE GUI   ----------------------------------------------------------------
--------------------------------------------------------------------------------
function store_gui()
  dock, x, y, w, h = gfx.dock(-1,0,0,0,0)
  gui_pos =  {dock = dock , x = x, y = y, w = w , h = h }
  reaper.SetProjExtState(0,"Track_Versions", "Dock_state", pickle(gui_pos))
end

function exit()
  --track_deleted()
  save_tracks()
  store_gui()
  gfx.quit()
end
--------------------------------------------------------------------------------
--   INIT   --------------------------------------------------------------------
--------------------------------------------------------------------------------
function Init()
    last_proj_change_count = reaper.GetProjectStateChangeCount(0)
    -- Some gfx Wnd Default Values --
    local R,G,B = 20,20,20               -- 0..255 form
    local Wnd_bgd = R + G*256 + B*65536  -- red+green*256+blue*65536  
    local Wnd_Title = "Track Versions"
    --local Wnd_X,Wnd_Y = 100,320
    Wnd_W,Wnd_H = Wnd_W,Wnd_H -- global values(used for define zoom level)
    -- Init window ------
    local ok, state = reaper.GetProjExtState(0,"Track_Versions", "Dock_state")
    if state ~= "" then state = unpickle(state) end
    --state = unpickle(state)
    Wnd_Dock = state.dock or 0
    Wnd_X = state.x or 100
    Wnd_Y = state.y or 320
    gfx.clear = Wnd_bgd         
    gfx.init( Wnd_Title, Wnd_W,Wnd_H, Wnd_Dock, Wnd_X, Wnd_Y )
    -- Init mouse last --
    last_mouse_cap = 0
    last_x, last_y = 0, 0
    mouse_ox, mouse_oy = -1, -1
end
----------------------------------------
--   Mainloop   ------------------------
----------------------------------------
function mainloop()
    -- zoom level --
    Z_w, Z_h = gfx.w/Wnd_W, gfx.h/Wnd_H
    -- if Z_w<0.6 then Z_w = 0.6 elseif Z_w>5 then Z_w = 5 end
    -- if Z_h<0.6 then Z_h = 0.6 elseif Z_h>5 then Z_h = 5 end 
    -- mouse and modkeys --
    if gfx.mouse_cap&1==1   and last_mouse_cap&1==0  or   -- L mouse
       gfx.mouse_cap&2==2   and last_mouse_cap&2==0  or   -- R mouse
       gfx.mouse_cap&64==64 and last_mouse_cap&64==0 then -- M mouse
       mouse_ox, mouse_oy = gfx.mouse_x, gfx.mouse_y 
    end
    Ctrl  = gfx.mouse_cap&4==4
    Shift = gfx.mouse_cap&8==8
    Alt   = gfx.mouse_cap&16==16 -- Shift state
    -- DRAW,MAIN functions --
      main() -- Main()
      DRAW_F(Frame)  -- draw frame
      DRAW_B(Empty)
      --DRAW_B(global_m)
    -------------------------
    last_mouse_cap = gfx.mouse_cap
    last_x, last_y = gfx.mouse_x, gfx.mouse_y
    gfx.mouse_wheel = 0 -- reset gfx.mouse_wheel 
    char = gfx.getchar()
    if char==32 then reaper.Main_OnCommand(40044, 0) end -- play 
    if char~=-1 then reaper.defer(mainloop) end          -- defer
    -----------  
    gfx.update()
    -----------
end
--------------------------------------------------------------------------------
Init()
restore()
reaper.atexit(exit)
mainloop()
