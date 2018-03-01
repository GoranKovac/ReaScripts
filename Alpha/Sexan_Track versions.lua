--[[
 * ReaScript Name: Track versions.lua
 * About: Protools style playlist, track versions (Cubase)
 * Author: SeXan
 * Licence: GPL v3
 * REAPER: 5.0
 * Extensions: None
 * Version: 0.37
--]]
 
--[[
 * Changelog:
 * v0.37 (2018-02-28)
  + Fixed small bug when saving folder that contains subfolders
--]]

-- USER SETTINGS
local manual_naming = false
----------------------------
local Wnd_W,Wnd_H = 220,220
local cur_sel = {[1] = nil}
TrackTB = {}
local get_val
----------------------------------------------
-- Pickle.lua
--------------------------------------------
function pickle(t)
  return Pickle:clone():pickle_(t)
end

Pickle = { clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end }

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
-- EUGENE 27777 GUI TEMPLATE
--------------------------------------------------------------------------------
---   Simple Element Class   ---------------------------------------------------
--------------------------------------------------------------------------------
local Element = {}
function Element:new(x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz,fnt_rgba,num,ver,guid)
    local elm = {}
    elm.def_xywh = {x,y,w,h,fnt_sz} -- its default coord,used for Zoom etc
    elm.x, elm.y, elm.w, elm.h = x, y, w, h
    elm.r, elm.g, elm.b, elm.a = r, g, b, a
    elm.lbl, elm.fnt, elm.fnt_sz  = lbl, fnt, fnt_sz
    elm.fnt_rgba = fnt_rgba
    elm.num ,elm.ver, elm.guid = num, ver, guid
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
  return p_x >= self.x and p_x <= self.x + self.w and p_y >= self.y and p_y <= self.y + self.h
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
  extended(Menu,       Element)
  extended(Button,     Element)
  extended(Frame,      Element)
  extended(Radio_Btns, Element)
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
    -- Get mouse state ---------
          -- in element --------
          if self:mouseIN() then a=a+0.4 end
          -- in elm L_down -----
          if self:mouseDown() then a=a+0.2 end
          -- in elm L_up(released and was previously pressed) --
          if self:mouseClick() and self.onClick then self.onClick() end
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
end--------------------------------------------------------------------------------
---   Frame Class Methods  -----------------------------------------------------
--------------------------------------------------------------------------------
function Frame:draw()
   self:update_xywh() -- Update xywh(if wind changed)
   local r,g,b,a  = self.r,self.g,self.b,self.a
   if self:mouseIN() then a=a+0.1 end
   gfx.set(r,g,b,a)   -- set frame color
   self:draw_frame()  -- draw frame
end
-----------------------------------------------
--- Function: store buttons to ext state ---
-----------------------------------------------
local function save_tracks()
  local all_button_states = {}  
    for k, v in ipairs(TrackTB) do
      all_button_states[#all_button_states+1] = {guid = v.guid, ver = v.ver, num = v.num}
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
      create_button(states[i].ver[j].name, states[i].guid, states[i].ver[j].chunk, states[i].ver[j].ver_id, states[i].num)
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
  update_tbl()
end
--------------------------------------------------------------------------------
---  Function Get Items chunk --------------------------------------------------
--------------------------------------------------------------------------------
function getTrackItems(track)
  if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")== 1 then return end
  local items_chunk, items = {}, {}
  local num_items = reaper.CountTrackMediaItems(track)
    for i=1, num_items, 1 do
      local item = reaper.GetTrackMediaItem(track, i-1)
      local _, it_chunk = reaper.GetItemStateChunk(item, '')
      items_chunk[#items_chunk+1] = pattern(it_chunk)
      items[#items+1] = item
    end
    if #items == 0 then items_chunk[1] = "empty_track" end -- pickle doesn't like empty tables
  return setmetatable(items_chunk, tcmt), items
end
----------------------------------------------------
--- select all items -------------------------------
----------------------------------------------------
local function select_items(track)
  if reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then return end
  --reaper.Main_OnCommand(40289,0)
  local _, items = getTrackItems(track)
  for i = 1 , #items do reaper.SetMediaItemSelected(items[i], true) end
  reaper.UpdateArrange()
end
--------------------------------------------------------------------------------
---  Function Restore Item Position --------------------------------------------
--------------------------------------------------------------------------------
function restoreTrackItems(track, track_items_table, num, job)
  local parent = find_guid(track)
  --local parent_num = num or parent.num -- VERSION NUMBER FOR FOLDER CHANHING (maybe not needed)
  local c_track, track = track, reaper.BR_GetMediaTrackByGUID(0,track)
  local num_items = reaper.CountTrackMediaItems(track)
  reaper.PreventUIRefresh(1)
  for i = 1, num_items, 1 do reaper.DeleteTrackMediaItem(track, reaper.GetTrackMediaItem(track,0)) end
    for i = 1, #track_items_table, 1 do
      if reaper.BR_GetMediaTrackByGUID( 0, track_items_table[i] ) then  -- FOLDER (TRACKS) (table is filled with tracks not items)
        parent.num = num -- check parent version --
        local child = find_guid(track_items_table[i]) -- get child
          for j = 1 , #child.ver do
            if parent.ver[parent.num].ver_id == child.ver[j].ver_id then -- IF FOLDER VER ID MATCH WITH CHILD
              local child_items = child.ver[j].chunk
              restoreTrackItems(track_items_table[i],child_items,j)
              child.num = j -- CHECK THE CHILD BOXES
            end
          end
      else   -- TRACK (ITEMS)
        local item = reaper.AddMediaItemToTrack(track)  
        reaper.SetItemStateChunk(item, track_items_table[i], false) 
        select_items(track,"select") -- select track from version (for easier locating)
        find_guid(c_track).num = num -- check track/child
      end
    end
  reaper.PreventUIRefresh(-1)              
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
end
----------------------------------------------------------------------
--    FUNCTION GET FOLDER CHILDS -------------------------------------
---------------------------------------------------------------------- 
function get_folder(tr)
  if reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") <= 0 then return end -- ignore tracks and last folder child
  local depth, children =  0, {}
  local folderID = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")-1
    for i = folderID + 1 , reaper.CountTracks(0) do -- start from first track after folder
      local child = reaper.GetTrack(0,i)
      local currDepth = reaper.GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
      children[#children+1] = reaper.GetTrackGUID(child)--insert child into array
      depth = depth + currDepth
      if depth < 0 then break end --until we are out of folder 
    end
  return children -- if we only getting folder childs
end
--------------------------------------------------------------------------------
--    FUNCTION CREATE FOLDER ---------------------------------------------------
--------------------------------------------------------------------------------
function create_folder(tr,version_name,ver_id)
  create_track(tr,version_name,ver_id) -- FOLDER 
  local childs = get_folder(tr)
  for i = 1, #childs do
    create_track(reaper.BR_GetMediaTrackByGUID(0,childs[i]),version_name,ver_id) -- create childs
  end
end
--------------------------------------------------------------------------------
---  Function Create Button from TRACK SELECTION -------------------------------
--------------------------------------------------------------------------------
function create_track(tr,version_name,ver_id,job)
  local chunk = getTrackItems(tr) or get_folder(tr) -- items or tracks (if no items then its tracks (folder)
  if chunk[1] == "empty_track" and version_name ~= "Original" then version_name = "Empty" end -- if there is no chunk (no items) call version EMPTY
  create_button(version_name,reaper.GetTrackGUID(tr),chunk,ver_id)
end
--------------------------------------------------------------------------------
---  Function NAMING (for all versions in script -------------------------------
--------------------------------------------------------------------------------
function naming(tbl,string,v_id)
  if tbl == nil then return "Original" end
    if manual_naming then
      local retval, name = reaper.GetUserInputs("Version name ", 1, "Version Name :", "")  
      if not retval or name == "" then return end
      return name
    end
  local name,counter = nil, 0
  for i = 1, #tbl.ver do
    if string == "V" and (#tbl.ver[i].ver_id == 38) then counter = counter + 1
    elseif string == "D" and (v_id  == tbl.ver[i].ver_id or v_id == tbl.ver[i].ver_id:sub(1, -4))then
      counter = counter + 1
    end
    name = string .. string.format("%02d",counter)
  end
  return name
end
-------------------------------------------------------------------------------
---  Function on_click (for all buttons)        -------------------------------
-------------------------------------------------------------------------------
function on_click_function(button)  
  local sel_tr_count = reaper.CountSelectedTracks(0)
    for i = 1, sel_tr_count do    
      ::JUMP::                                               
      local tr = reaper.GetSelectedTrack(0, i-1)
      local guid = reaper.GetTrackGUID(tr)
      local version_name = naming(find_guid(guid),"V")
      if not version_name then return end
      button(tr, version_name, reaper.genGuid()) -- STAVIT FOLDER CHECK
      if version_name == "Original" then goto JUMP end -- make 2 versions as default Original and V1
    end
end
---------------------------------------------------------------------------------------------------------
---   START   -------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
local save_track  = Button:new(15,15,40,20, 0.2,0.2,1.0,0, "Save","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local save_folder = Button:new(60,15,80,20, 0.2,0.2,1.0,0, "Save Folder","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local empty       = Button:new(165,15,40,20, 0.2,0.2,1.0,0, "Empty","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local Folder, Empty, Track = {save_folder}, {empty}, {save_track}
local W_Frame, T_Frame = Frame:new(10,10,Wnd_W-20,Wnd_H-20,  0,0.5,2,0.4 ), Frame:new(10,10,200,30,  0,0.5,2,0.4 )
local Frame = {W_Frame,T_Frame}
--------------------------------------------------------------------------------
---  BUTTONS FUNCTIONS   ------------------------------------------------------
--------------------------------------------------------------------------------
empty.onClick = function()
                local childs = get_folder(reaper.BR_GetMediaTrackByGUID(0,cur_sel[1].guid)) or {}
                childs[#childs+1] = cur_sel[1].guid
                  for i = 1 , #childs do
                    restoreTrackItems(childs[i], {}) -- sending empty table {} removes items from track
                    find_guid(childs[i]).num = 0
                  end
end             
save_folder.onClick = function()
                      on_click_function(create_folder)
end
save_track.onClick = function()
                      on_click_function(create_track)
end
--------------------------------------------------------------------------------
---  Function Create Button ----------------------------------------------------
--------------------------------------------------------------------------------
function create_button(name,guid,chunk,ver_id,num)
  local v_table = {chunk = chunk, ver_id = ver_id, name = name}
  local box = Radio_Btns:new(105,50,120,20,  0.2,0.2,1.0,0.7, "","Arial",15,{0.7, 0.9, 1, 1},1, {v_table}, guid )
  
  if not find_guid(guid) then -- if ID does not exist in the table create new checklist
    TrackTB[#TrackTB+1] = box -- add new box to TrackTB table
  else -- if ID exists in the table then only add new chunk to it
    local version = find_guid(guid) 
    version.ver[#version.ver+1] = v_table -- add state to ver table
    version.num = num or #version.ver
  end
    
  box.onClick = function() -- check box on click action
                local tr
                  for i = 1, reaper.CountSelectedTracks() do
                    local sel_tr = reaper.GetTrackGUID(reaper.GetSelectedTrack(0,i-1))
                    local tr = find_guid(sel_tr)
                    local items = tr.ver[box.num].chunk -- items or tracks (based on if is a track or folder)
                    restoreTrackItems(tr.guid,items,box.num)
                  end
  end -- end box.onClick
  box.onRClick =  function()
                  local r_click_menu = Menu:new(box.x,box.y,box.w,box.h,0.6,0.6,0.6,0.3,"Chan :","Arial",15,{0.7, 0.9, 1, 1},-1,
                                               {"Delete Version","Delete All Except","Rename Version","Duplicate","Save current version"})
                  local menu_TB = {r_click_menu}
                  DRAW_M(menu_TB)
                  
                  local chunk = box.ver[box.num].chunk 
                  
                  if r_click_menu.num == -1 then return -- nothing clicked
                  
                  elseif r_click_menu.num == 1 then --- delete version
                    if box.ver[box.num].name ~= "Original" then -- prevent deleting original if other version exist
                      delete_childs(chunk, box.ver[box.num].ver_id) -- IF FOLDER DELETE CHILDS
                      table.remove(box.ver,box.num) -- REMOVE FROM FOLDER OR TRACK
                    else
                      if #box.ver == 1 then -- if only original left
                        delete_childs(chunk, box.ver[box.num].ver_id) -- IF FOLDER DELETE CHILDS
                        table.remove(box.ver,box.num) -- REMOVE FROM FOLDER OR TRACK
                      end
                    end
                    if #box.ver ~= 0 then
                      if box.num > #box.ver then box.num = #box.ver end
                      local items = box.ver[box.num].chunk
                      restoreTrackItems(box.guid,items,box.num)
                    end
                    update_tbl() -- CHECK AND REMOVE BUTTON FROM MAIN TABLE IF VERSION IS EMPTY
                     
                  elseif r_click_menu.num == 3 then --- rename button
                    local retval, version_name = reaper.GetUserInputs("Rename Version ", 1, "Version Name :", "")  
                    if not retval or version_name == "" then return end
                    box.ver[box.num].name = version_name
                    
                  elseif r_click_menu.num == 5 then -- save current version (save modifications)
                    if string.sub(chunk[1],1,1) == "{" then
                      for i = 1, #chunk do
                        local child = find_guid(chunk[i])
                          if string.sub(child.ver[child.num].chunk[1],1,1) ~= "{" then
                            child.ver[child.num].chunk = getTrackItems(reaper.BR_GetMediaTrackByGUID(0,child.guid))
                          end
                      end
                    else
                      chunk = getTrackItems(reaper.BR_GetMediaTrackByGUID(0,box.guid))
                    end
                  
                  elseif r_click_menu.num == 4 then --- DUPLICATE s                 
                    local duplicate_num = naming(box,"D",box.ver[get_val].ver_id)-- .. " - " .. box.ver[get_val].name
                    local duplicate_name = duplicate_num .. " - " .. box.ver[get_val].name 
                    if reaper.GetMediaTrackInfo_Value(reaper.BR_GetMediaTrackByGUID(0, box.guid), "I_FOLDERDEPTH") == 1 then
                      create_folder(reaper.BR_GetMediaTrackByGUID(0, box.guid),duplicate_name,box.ver[get_val].ver_id .. duplicate_num)
                    else
                      create_track(reaper.BR_GetMediaTrackByGUID(0, box.guid),duplicate_name,box.ver[get_val].ver_id .. duplicate_num)
                    end
                    
                  elseif r_click_menu.num == 2 then --- remove except
                    for i = #box.ver , 2, -1 do
                      if box.num ~= i then table.remove(box.ver,i) end -- TRACK OR MAIN FOLDER - trim to only one version
                    end
                    box.num = #box.ver -- set last active
                    delete_childs(chunk, box.ver[box.num].ver_id, 2) -- IF FOLDER HAS CHILDS THEN TRIM ALL THE CHILDS TO SAME VERSION (2 is job and not to remove ORIGINAL)
                  end
                  save_tracks()
  end -- end box.onRClick
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()                      
end -- end create_button()

--------------------------------------------------------------------------------
---  Function REMOVE PATTERNS FROM CHUNK ---------------------------------------
--------------------------------------------------------------------------------
function pattern(chunk)
  local patterns = {"SEL 0", "SEL 1"}
  for i = 1 , #patterns do chunk = string.gsub(chunk, patterns[i], "") end -- remove SEL part of the chunk (chunk is considered changed if its selected or not)    
  return chunk
end
--------------------------------------------------------------------------------
---  Function SAVE GUI SETTING  ------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
---  Function MAIN -------------------------------------------------------------
--------------------------------------------------------------------------------
function main()
  --count_sel_tr = reaper.CountSelectedTracks()
  --for i = 1, reaper.CountSelectedTracks() do
   -- local sel_tr = reaper.GetSelectedTrack(0,i-1)
  local sel_tr = reaper.GetSelectedTrack(0,0) -- get track 
    if sel_tr then 
      cur_sel[1] = find_guid(reaper.GetTrackGUID(sel_tr)) -- VIEW CURRENT SELECTED TRACK VERSIONS       
      if #cur_sel ~= 0 then DRAW_B(Empty) end-- if track has no version hide empty button (to avoid deleting original items)
      if reaper.GetMediaTrackInfo_Value(sel_tr, "I_FOLDERDEPTH") == 1 then DRAW_B(Folder) else DRAW_B(Track) end-- draw save folder button only if folder track is selected
      DRAW_C(cur_sel)
    end
  --end
  track_deleted()
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
--------------------------------------------------------------------------------
--   INIT   --------------------------------------------------------------------
--------------------------------------------------------------------------------
function Init()
    -- Some gfx Wnd Default Values --
    local R,G,B = 20,20,20               -- 0..255 form
    local Wnd_bgd = R + G*256 + B*65536  -- red+green*256+blue*65536  
    local Wnd_Title = "Schwa for President!"
    local Wnd_Dock,Wnd_X,Wnd_Y = 0,100,320
    Wnd_W,Wnd_H = Wnd_W,Wnd_H -- global values(used for define zoom level)
    -- Init window ------
    gfx.clear = Wnd_bgd         
    gfx.init( Wnd_Title, Wnd_W,Wnd_H, Wnd_Dock, Wnd_X,Wnd_Y )
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
reaper.atexit(save_tracks)
mainloop()
