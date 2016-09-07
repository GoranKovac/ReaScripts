function DBG(str)
--[[
  if str==nil then str="nil" end
  reaper.ShowConsoleMsg(str.."\n")
 ]] 
end

----------------------------------------------
-- Pickle.lua
-- A table serialization utility for lua
-- Steve Dekorte, http://www.dekorte.com, Apr 2000
-- (updated for Lua 5.3 by me)
-- Freeware
----------------------------------------------

function pickle(t)
  return Pickle:clone():pickle_(t)
end

Pickle = {
  clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end 
}

function Pickle:pickle_(root)
  if type(root) ~= "table" then 
    error("can only pickle tables, not ".. type(root).."s")
  end
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
  if type(s) ~= "string" then
    error("can't unpickle a "..type(s)..", only strings")
  end
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

--[[
   * ReaScript Name:Simple GUI template for scripts
   * Lua script for Cockos REAPER
   * Author: EUGEN27771
   * Author URI: http://forum.cockos.com/member.php?u=50462
   * Licence: GPL v3
   * Version: 1.0
  ]]
CheckBox_TB = {}
local last_proj_change_count = reaper.GetProjectStateChangeCount(0)
--------------------------------------------------------------------------------
---   Simple Element Class   ---------------------------------------------------
--------------------------------------------------------------------------------
local Element = {}
function Element:new(x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz,fnt_rgba, norm_val,norm_val2)
    local elm = {}
    elm.def_xywh = {x,y,w,h,fnt_sz} -- its default coord,used for Zoom etc
    elm.x, elm.y, elm.w, elm.h = x, y, w, h
    elm.r, elm.g, elm.b, elm.a = r, g, b, a
    elm.lbl, elm.fnt, elm.fnt_sz  = lbl, fnt, fnt_sz
    elm.fnt_rgba = fnt_rgba
    elm.norm_val = norm_val
    elm.norm_val2 = norm_val2
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
local CheckBox = {}
local Menu = {}
  extended(Menu,       Element)
  extended(Button,     Element)
  extended(Frame,      Element)
  extended(CheckBox,   Element)
--------------------------------------------------------------------------------
---   Menu Class Methods   -----------------------------------------------------
--------------------------------------------------------------------------------
function Menu:set_norm_val()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local val = self.norm_val      -- current value,check
    local menu_tb = self.norm_val2 -- checkbox table
    local menu_str = ""
       for i=1, #menu_tb,1 do
         if i~=val then menu_str = menu_str..menu_tb[i].."|"
                   --else menu_str = menu_str.."!"..menu_tb[i].."|" -- add check
         end
       end
    gfx.x = self.x; gfx.y = self.y + self.h
    local new_val = gfx.showmenu(menu_str)        -- show checkbox menu
    if new_val>0 then self.norm_val = new_val end -- change check(!)
end
------------------------
function Menu:draw()
    -- Get mouse state ---------
    if self:mouseRClick() then self:set_norm_val()
    if self:mouseRClick() and self.onRClick then self.onRClick() end
    end
end  
--------------------------------------------------------------------------------  
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
    --self:draw_frame()   -- frame
    -- Draw label --------------
    gfx.set(table.unpack(self.fnt_rgba))
    gfx.setfont(1, fnt, fnt_sz) -- set label fnt
    self:draw_lbl()             -- draw lbl
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---   CheckBox Class Methods   -------------------------------------------------
--------------------------------------------------------------------------------
function CheckBox:set_norm_val()
    local x,y,w,h  = self.x,self.y,self.w,self.h
    local val = self.norm_val      -- current value,check
    local menu_tb = self.norm_val2 -- checkbox table
    local menu_str = ""
       for i=1, #menu_tb,1 do
         if i~=val then menu_str = menu_str..menu_tb[i].name .."|"
                   else menu_str = menu_str.."!"..menu_tb[i].name.."|" -- add check
         end
       end
    gfx.x = self.x; gfx.y = self.y + self.h
    local new_val = gfx.showmenu(menu_str)        -- show checkbox menu
    if new_val>0 then self.norm_val = new_val end -- change check(!)
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
    if self.norm_val < 1 then return end
    local val = self.norm_val2[self.norm_val].name
    local val_w, val_h = gfx.measurestr(val)
    gfx.x = x+5; gfx.y = y+(h-val_h)/2
    gfx.drawstr(val) -- draw checkbox val
end
------------------------
function CheckBox:draw()
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    -- Get mouse state ---------
          -- in element --------
          if self:mouseIN() then a=a+0.4 end
          -- in elm L_down -----
          if self:mouseDown() then a=a+0.2 end
          -- in elm L_up(released and was previously pressed) --
          if self:mouseClick() then self:set_norm_val() 
            if self:mouseClick() and self.onClick then self.onClick() end
          end
          if self:mouseRClick() and self.onRClick then self.onRClick() end
    -- Draw ch_box body, frame -
    gfx.set(r,g,b,a)    -- set body color
    self:draw_body()    -- body
    --self:draw_frame()   -- frame
    -- Draw label --------------
    gfx.set(table.unpack(self.fnt_rgba))
    gfx.setfont(1, fnt, fnt_sz) -- set label,val fnt
    self:draw_lbl()             -- draw lbl
    self:draw_val()             -- draw val
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
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
function save_tracks()
  DBG("Saving")
  -- here we are going to pickle one big table for all states. This might not be a good
  -- idea, but it's easy enough to change it to save and recall separate pickled states
  -- per button. using pickle.lua prepares us to be storing tables of lines instead
  -- of big chunks.
  local all_button_states = {}
  
  for k, v in ipairs(CheckBox_TB) do
    all_button_states[#all_button_states+1] = {id = v.id , norm_val2 = v.norm_val2 ,type = v.type, norm_val = v.norm_val}
  end
 
  reaper.SetProjExtState(0, "Track_Versions", "States", pickle(all_button_states))
end
-----------------------------------------------------
--- Function: Restore Saved Buttons From extstate ---
-----------------------------------------------------
function restore()
  DBG("Restoring")
  local ok, states = reaper.GetProjExtState(0, "Track_Versions","States")
  if states~="" then
    states = unpickle(states)
    for i = 1, #states do
      local s = states[i]
        for j = 1 , #s.norm_val2 do
          local chunk = s.norm_val2[j].chunk
          local name = s.norm_val2[j].name
          create_button(name,s.id,chunk,s.type,s.norm_val)
        end
    end
  else
    DBG("state=\"\"")
  end
end
---------------------------------------------------------------------
--- Function: Delete button from table it button track is deleted ---
---------------------------------------------------------------------
function track_deleted(tracks)
local temp_del = {}
    
  for k,v in ipairs(CheckBox_TB)do    
    local cnt_tr = reaper.CountTracks(0)
    for i = 0 , cnt_tr-1 do
      local tr = reaper.GetTrack(0, i)
      local guid = reaper.GetTrackGUID(tr)      
      if v.id == guid then
         temp_del[#temp_del+1]=CheckBox_TB[k]
      end
    end
  end
    
CheckBox_TB = temp_del
save_tracks()
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---  Function Check If table HAS GUID  -----------------------------------------
--------------------------------------------------------------------------------
function has_value(tab, val)
  for index, value in ipairs (tab) do
    if value.id == val then
      return true
    end
  end
return false
end
----------------------------------------------------
--- Unselect or select all items -------------------
----------------------------------------------------
local function unselect_items(track,job)
local items={}
local num_items = reaper.CountTrackMediaItems(track)
  --DBG("num_items = "..num_items)
  for i=1, num_items, 1 do
    local item = reaper.GetTrackMediaItem(track, i-1)    
    items[#items+1]=item
  end
  for i = 1 , #items do
    if job == "unselect" then
      reaper.SetMediaItemSelected(items[i], false) 
    elseif job == "select" then
      reaper.SetMediaItemSelected(items[i], true)
    end                             
  end
items = {}
reaper.UpdateArrange()
end
--------------------------------------------------------------------------------
---  Function Get Items chunk --------------------------------------------------
--------------------------------------------------------------------------------
local EMPTY_TABLE = "empty_table"

local function getTrackItems(track)
local items={}
local num_items = reaper.CountTrackMediaItems(track)
  --DBG("num_items = "..num_items)
  for i=1, num_items, 1 do
    local item = reaper.GetTrackMediaItem(track, i-1)
    local _, it_chunk = reaper.GetItemStateChunk(item, '')
    items[#items+1]=it_chunk
  end
  if #items == 0 then items[1]=EMPTY_TABLE end -- pickle doesn't like empty tables
return setmetatable(items, tcmt)
end
--------------------------------------------------------------------------------
---  Function Restore Item Position --------------------------------------------
--------------------------------------------------------------------------------
local function restoreTrackItems(track, track_items_table)
  local num_items = reaper.CountTrackMediaItems(track)
  reaper.PreventUIRefresh(1)
    if num_items>0 and track_items_table[1] ~= EMPTY_TABLE then
      for i = 1, num_items, 1 do
        reaper.DeleteTrackMediaItem(track, reaper.GetTrackMediaItem(track,0))
      end
    end
    for i = 1, #track_items_table, 1 do
      local item = reaper.AddMediaItemToTrack(track)
      reaper.SetItemStateChunk(item, track_items_table[i], false)
    end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end
-----------------------------------------------
---      Function: Get Folder Depth         ---
-----------------------------------------------
function get_track_folder_depth(track_index)
  local folder_depth = 0
  for i=0, track_index do -- loop from start of tracks to "track_index"... 
    local track = reaper.GetTrack(0, i)
    folder_depth = folder_depth + reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") -- ...to get the actual folder depth
  end
  return folder_depth
end 
---------------------------------------------------------------------------------------------------------
---   START   -------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
local save = Button:new(15,15,40,20, 0.2,0.2,1.0,0, "New","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local save_folder = Button:new(60,15,80,20, 0.2,0.2,1.0,0, "New Folder","Arial",15,{0.7, 0.9, 1, 1}, 0 )
local empty = Button:new(165,15,40,20, 0.2,0.2,1.0,0, "Empty","Arial",15,{0.7, 0.9, 1, 1}, 0 )
---------------------------------------------------------------------------------------------------------
local Folder_TB = {save_folder}
local Empty_button = {empty}
local Button_TB = {save}
----------------------------------------------------------------------------------------------------
local W_Frame = Frame:new(10,10,200,100,  0,0.5,2,0.4 )
local T_Frame = Frame:new(10,10,200,30,  0,0.5,2,0.4 )
local Frame_TB = {W_Frame,T_Frame}
--------------------------------------------------------------------------------
---  Function Empty Button On Click  -------------------------------------------
--------------------------------------------------------------------------------
empty.onClick = function()
                local items = {}
                local sel_tr_count = reaper.CountSelectedTracks(0)
                for i=1, sel_tr_count do                                                 
                  local tr = reaper.GetSelectedTrack(0, i-1)
                  local retval, flags = reaper.GetTrackState(tr)
                  if flags&1 == 1 then -- if track is a folder
                    local guid = reaper.GetTrackGUID(tr)
                      for k,v in ipairs(CheckBox_TB)do
                        if v.id == guid then
                           v.norm_val = 0 -- set folders norm_val to 0 (to make menu show nothing selected)
                        end
                      end
                    local job = "empty" 
                    items = create_folder_or_items(tr,version_name,job) -- job will return "items" table,get all items of child tracks
                  else -- every track
                    local num_items = reaper.CountTrackMediaItems(tr) -- get normal track items
                      for i=1, num_items, 1 do
                        local item = reaper.GetTrackMediaItem(tr, i-1)
                        items[#items+1] = item
                      end
                  end
                end 
                
                for i = 1 , #items do  -- remove items             
                  local track = reaper.GetMediaItem_Track(items[i])
                  local guid = reaper.GetTrackGUID(track)
                    for k,v in ipairs(CheckBox_TB)do
                      if v.id == guid then
                        v.norm_val = 0 -- set tracks norm_val to 0 (to make menu show nothing selected)
                      end
                    end
                  reaper.DeleteTrackMediaItem(track, items[i])                               
                end
                items = {}
                reaper.UpdateArrange()                         
end             
--------------------------------------------------------------------------------
---  Function Save FOLDER Button On Click  -------------------------------------
--------------------------------------------------------------------------------
save_folder.onClick = function()
                      local sel_tr_count = reaper.CountSelectedTracks(0)
                      if sel_tr_count == 0 then return end
                      for i=1, sel_tr_count do     -- loop through selected tracks
                        local tr = reaper.GetSelectedTrack(0, i-1)
                        local retval, flags = reaper.GetTrackState(tr)
                        if flags&1 == 1 then -- Folder only
                          local f_GUID  = reaper.GetTrackGUID(tr)
                          local check = has_value(CheckBox_TB,f_GUID)
                            if check == false then
                              version_name = "V1"
                            else
                              for k,v in ipairs(CheckBox_TB)do
                                if v.id == f_GUID then
                                  version_name = "V" .. #v.norm_val2+1
                                end
                              end
                            end
                           
                          --local retval, version_name = reaper.GetUserInputs("Version Name", 1, "Enter Version Name :", "")  
                          --if not retval then return end                               
                          --if version_name == "" then reaper.MB("Enter Valid Name!", "Error", 0)return end
                          local job = "folder"
                          local f_chunk = create_folder_or_items(tr,version_name,job) -- job will return "child_tracks" table (childs GUID) and create versions for every child
                          
                          local f_name  = version_name
                          local f_type  = "FOLDER"  
                          create_button(f_name,f_GUID,f_chunk,f_type,nv)
                          save_tracks()
                        else
                          reaper.MB("Track is not a folder", "Error", 0)
                        end
                      end
end
--------------------------------------------------------------------------------
---  Function Save TRACK Button On Click  --------------------------------------
--------------------------------------------------------------------------------
save.onClick = function()
              local sel_tr_count = reaper.CountSelectedTracks(0)
              if sel_tr_count == 0 then return end              
              --local retval, version_name = reaper.GetUserInputs("Version Name", 1, "Enter Version Name :", "")  
              --if not retval then return end
              --if version_name == "" then reaper.MB("Enter Valid Name!", "Error", 0)return end
              for i=1, sel_tr_count do     -- loop through selected tracks                      
                local tr = reaper.GetSelectedTrack(0, i-1)
                local guid = reaper.GetTrackGUID(tr)
                local check = has_value(CheckBox_TB,guid)
                    if check == false then
                      version_name = "V1"
                    else
                      for k,v in ipairs(CheckBox_TB)do
                        if v.id == guid then
                        version_name = "V" .. #v.norm_val2+1
                        end
                     end
                  end
                create_button_from_selection(tr,version_name,sel_tr_count)
                save_tracks()
              end 
end
--------------------------------------------------------------------------------
---  Function Create FOLDER/Get Folder Items -----------------------------------
--------------------------------------------------------------------------------
function create_folder_or_items(tr,version_name,job)
  local child_tracks = {} -- table for all child data
  local items = {} -- table for storing items that will be removed
  local tr_index = reaper.CSurf_TrackToID(tr, false) - 1 -- get folder track id
  local parent_folder_depth = get_track_folder_depth(tr_index) -- get folder depth
  local total_folder_depth = parent_folder_depth
    for i = tr_index + 1, reaper.CountTracks(0) do                         
      local child_tr = reaper.GetTrack(0, i-1)
      local retval, child_flags = reaper.GetTrackState(child_tr) -- get child track flag
        if child_tr ~= tr then -- do not include main folder track into child tracks
          if job == "folder" then    
            local c_GUID = reaper.GetTrackGUID(child_tr) -- get track GUID
            create_button_from_selection(child_tr,version_name) -- create versions of child tracks on all child tracks
            child_tracks[#child_tracks+1] = c_GUID -- add child_GUID to child_tracks Table (for folder)
          elseif job == "empty" then
            local num_items = reaper.CountTrackMediaItems(child_tr)
            for i=1, num_items, 1 do
              local item = reaper.GetTrackMediaItem(child_tr, i-1)
              items[#items+1] = item
            end
          end
        end
      total_folder_depth = total_folder_depth + reaper.GetMediaTrackInfo_Value(child_tr, "I_FOLDERDEPTH")
      if total_folder_depth <= parent_folder_depth then break end
    end                 
  if job == "folder" then return child_tracks
  elseif job == "empty" then  return items
  end
end
--------------------------------------------------------------------------------
---  Function Create Button from TRACK SELECTION -------------------------------   OVO
--------------------------------------------------------------------------------
function create_button_from_selection(tr,version_name)
  local job = "unselect"
  unselect_items(tr,job)
  local t_chunk = getTrackItems(tr)
  local t_GUID  = reaper.GetTrackGUID(tr)
  local t_name  = version_name
  local t_type  = "TRACK"
  create_button(t_name,t_GUID,t_chunk,t_type,nv)
end
--------------------------------------------------------------------------------
---  Function Create Button ----------------------------------------------------
--------------------------------------------------------------------------------
function create_button(name,GUID,chunk,type,nv)
  local check = has_value(CheckBox_TB,GUID) -- check if ID already exists 
               
  local state = {}  
  state.chunk = chunk
  
  local ch_box = CheckBox:new(70,50,120,20,  0.2,0.2,1.0,0, "Version","Arial",15,{0.7, 0.9, 1, 1}, 1, {state} )
  
  ch_box.id = GUID                            
  ch_box.type = type
  
  if check == false then -- if ID does not exist in the table create new checklist
    state.name = name
    CheckBox_TB[#CheckBox_TB+1] = ch_box -- add new ch_box to CheckBox_TB table  
   
  else -- if ID exists in the table then only add new chunk to it
    for k,v in ipairs(CheckBox_TB)do
      if v.id == GUID then -- if check_box ID is same as track ID then
         state.name = name
         v.norm_val2[#v.norm_val2+1] = state -- add state to norm_val2 table
         if nv ~= nil then v.norm_val = nv -- if nv value exists (from restoring tracks)
         else
         v.norm_val = #v.norm_val2-- set last save as first shown in menu
         end
      end
    end
  end
  
  if ch_box.type == "FOLDER" then -- colors  for button
    ch_box.fnt_rgba = {0.5, 0.9, 0.5, 1}
  end
    
  ch_box.onClick = function() -- check box on click action
                  if ch_box.type == "TRACK" then
                    local ch_GUID = ch_box.id -- get GUID from checbox ID section
                    local tr = reaper.BR_GetMediaTrackByGUID(0,ch_GUID) -- convert it to track
                    if ch_box.norm_val == 0 then return end
                    local items = ch_box.norm_val2[ch_box.norm_val].chunk -- items on track are norm_val2 table SECTION norm_val(which box is clicked)
                    restoreTrackItems(tr,items) -- restore items
                    local job = "select"
                    reaper.Main_OnCommand( 40289, 0 )
                    unselect_items(tr,job) -- select track from version (for easier locating)
                  
                  elseif ch_box.type == "FOLDER" then
                    if ch_box.norm_val == 0 then return end
                    local parent_norm_val = ch_box.norm_val -- get folders norm_val
                    local child_guid = ch_box.norm_val2[ch_box.norm_val] -- child guid table of folder checkbox
                    for i = 1 , #child_guid.chunk do
                      local track = child_guid.chunk[i]
                      for k,v in ipairs(CheckBox_TB)do
                        if v.id == track then -- if tracks ID in folder are found in CheckBox_TB table
                          local c_track = reaper.BR_GetMediaTrackByGUID(0,v.id) -- get track from GUID
                          v.norm_val = parent_norm_val -- child norm_val follows folders norm_val
                          local c_items = v.norm_val2[parent_norm_val].chunk -- items in child tracks are changed with parent nor_val change
                          restoreTrackItems(c_track,c_items)
                          local job = "select"
                          --reaper.Main_OnCommand( 40289, 0 )
                          unselect_items(c_track,job) -- select track from version (for easier locating)
                        end
                      end
                   end
                 end
  end -- end ch_box.onClick
  ch_box.onRClick =  function() 
                  -- x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz,fnt_rgb, norm_val = check, norm_val2 = checkbox table --
                  local r_click_menu = Menu:new(ch_box.x,ch_box.y,ch_box.w,ch_box.h,0.6,0.6,0.6,0.3,"Chan :","Arial",15,{0.7, 0.9, 1, 1},-1,
                                               {"Delete Version","Rename Version","Save current version"})
                  local menu_TB = {r_click_menu}
                  DRAW_M(menu_TB)
                  
                  if r_click_menu.norm_val == -1 then return -- nothing clicked 
                  
                  elseif r_click_menu.norm_val == 1 then --- delete version
                    if ch_box.type == "TRACK" then
                      local ID = ch_box.id
                      table.remove(ch_box.norm_val2,ch_box.norm_val)
                      ch_box.norm_val = #ch_box.norm_val2
                        for k,v in ipairs(CheckBox_TB)do
                          if v.type == "FOLDER" then
                            for i = 1 , #v.norm_val2[v.norm_val].chunk do
                            local child = v.norm_val2[v.norm_val].chunk[i]
                              if ID == child then
                              table.remove(v.norm_val2[v.norm_val].chunk,i)
                              end
                            end
                          end
                        end                            
                      save_tracks()
                      
                    elseif ch_box.type == "FOLDER" then -- delete childs of folder
                      local childs = ch_box.norm_val2[ch_box.norm_val].chunk -- add childs to tabnle
                      table.remove(ch_box.norm_val2,ch_box.norm_val) -- remove folder version
                      ch_box.norm_val = #ch_box.norm_val2 -- change norm_val
                      for i = 1 , #childs do
                        local child = childs[i]
                        for k,v in ipairs(CheckBox_TB)do
                          if child == v.id then
                            table.remove(v.norm_val2,v.norm_val)
                            v.norm_val = #v.norm_val2
                          end
                          if #v.norm_val2==0 then
                            table.remove(CheckBox_TB,k)
                          else
                            local tr = reaper.BR_GetMediaTrackByGUID(0,v.id) -- convert it to track
                            local items = v.norm_val2[v.norm_val].chunk -- items on track are norm_val2 table SECTION norm_val(which box is clicked)
                            restoreTrackItems(tr,items) -- restore items
                          end
                        end
                      end
                      childs = nil
                      save_tracks()                      
                  end
                          
                    if ch_box.norm_val > 0 then -- restore previous/next version after delete (because if version is deleted same items stay)
                      local tr = reaper.BR_GetMediaTrackByGUID(0,ch_box.id) -- convert it to track
                      local items = ch_box.norm_val2[ch_box.norm_val].chunk -- items on track are norm_val2 table SECTION norm_val(which box is clicked)
                      restoreTrackItems(tr,items) -- restore items
                      save_tracks()
                    else
                      for k,v in ipairs(CheckBox_TB)do -- if there are no more versions remove whole CheckBox
                        if #v.norm_val2 == 0 then  
                          table.remove(CheckBox_TB,k)
                          save_tracks()
                        end
                      end
                    end
                                     
                  elseif r_click_menu.norm_val == 2 then --- rename button
                    local retval, version_name = reaper.GetUserInputs("Rename Version ", 1, "Version Name :", "")  
                    if not retval or version_name == "" then return end
                    ch_box.norm_val2[ch_box.norm_val].name = version_name
                    save_tracks()
                  
                  elseif r_click_menu.norm_val == 3 then -- save current version (save modifications)
                    if ch_box.type == "TRACK" then
                    local sel_tr_count = reaper.CountSelectedTracks(0)
                      for i=1, sel_tr_count do     -- loop through selected tracks                      
                      local tr = reaper.GetSelectedTrack(0, i-1)
                      local sel_GUID = reaper.GetTrackGUID(tr)
                      local sel_chunk1= getTrackItems(tr)
                    
                        for k,v in ipairs(CheckBox_TB)do
                          if v.id == sel_GUID then
                            v.norm_val2[v.norm_val].chunk = sel_chunk1
                            save_tracks()
                          end
                        end  
                      end
                    elseif ch_box.type == "FOLDER" then
                      local childs = ch_box.norm_val2[ch_box.norm_val].chunk -- add childs to tabnle
                      for i = 1 , #childs do
                        local child = childs[i]
                        local tr = reaper.BR_GetMediaTrackByGUID(0, child)
                        local sel_chunk1= getTrackItems(tr)
                        for k,v in ipairs(CheckBox_TB)do
                          if v.id == child then
                            v.norm_val2[v.norm_val].chunk = sel_chunk1
                            save_tracks()
                          end
                        end
                      end
                    end  
                  end
                  
  end -- end ch_box.onRClick
end -- end create_button()
--------------------------------------------------------------------------------
---  Function MAIN -------------------------------------------------------------
--------------------------------------------------------------------------------
function main()
 local proj_change_count = reaper.GetProjectStateChangeCount(0)
  if proj_change_count > last_proj_change_count then
    local last_action = reaper.Undo_CanUndo2(0)
    if last_action == "Remove Tracks" then
      track_deleted(last_tracks)
    end
    last_proj_change_count = proj_change_count
  end
  
  local cur_sel = {} -- table for current selected track (show only checkbox of selected track)
  local sel_tr = reaper.GetSelectedTrack(0,0) -- get track
    if sel_tr then
      local sel_chunk = getTrackItems(sel_tr)
      local retval, flags = reaper.GetTrackState(sel_tr)
      local sel_GUID = reaper.GetTrackGUID(sel_tr)
      
      ---(SHOW ONLY Checkbox of SELECTED track)
      for k,v in ipairs(CheckBox_TB)do 
        if sel_GUID == v.id then -- if track guid is same as checbox ID (guid)
         cur_sel[#cur_sel+1] = CheckBox_TB[k] -- add checkbox to curent selected table
       end  
      end 
      
     --- concat to easier check difference between chunk tables
      if #cur_sel ~= 0 and cur_sel[1].norm_val > 0 then
        chunk1 = table.concat(cur_sel[1].norm_val2[cur_sel[1].norm_val].chunk) -- current active version chunk
      end
        chunk2 = table.concat(sel_chunk)  -- selected tracks chunk
        
        -- exclude "ITEM SELECT" CHUNK
        local patterns = {"SEL 0", "SEL 1"}
        for i,v in ipairs(patterns) do
            chunk2 = string.gsub(chunk2, v, "")
            if chunk1 ~= nil then
            chunk1 = string.gsub(chunk1, v, "")
            end
        end
      -------------------AUTO SAVE
      --[[      
      if chunk1 ~= chunk2 then
        for k,v in pairs(cur_sel)do
            if v.type ~= "FOLDER" and sel_chunk[1] ~= EMPTY_TABLE then -- ignore FOLDER tracks and tracks that are empty
            if v.norm_val == 0 then return end
              v.norm_val2[v.norm_val].chunk = sel_chunk --curent selected version is overwriten by current selected tracks chunk
              for i = 1 , #CheckBox_TB do
                if v.id == CheckBox_TB[i].id then -- if checkbox ID is found in table
                  CheckBox_TB[i] = cur_sel[k] -- set that chekbox index as current checkbox
                  save_tracks() --save tracks
                  DBG("SAVE")
                end
              end
            end
          end
        end
   ]]
      if #cur_sel ~= 0 then -- if track has no version hide empty button (to avoid deleting original items)
        DRAW_B(Empty_button)
      end
  
      if flags&1 == 1 then -- draw save folder button only if folder track is selected
        DRAW_B(Folder_TB)
      end
    
    else -- if no track is selected 
      chunk1 = nil
      chunk2 = nil
    
  end -- end sel_tr loop
DRAW_C(cur_sel) -- draw currrent table
end 
----------------------------------------------------------------------------------------------------
---   Main DRAW function   -------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
function DRAW_B(tbl)
    for key,btn     in pairs(tbl)   do btn:draw()    end
end
function DRAW_C(tbl)    
    for key,ch_box  in pairs(tbl)   do ch_box:draw() end 
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
    local Wnd_Title = "CheckListVersion"
    local Wnd_Dock,Wnd_X,Wnd_Y = 0,100,320
    Wnd_W,Wnd_H = 220,120 -- global values(used for define zoom level)
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
    -- if Z_w<0.6 then Z_w = 0.6 elseif Z_w>2 then Z_w = 2 end
    -- if Z_h<0.6 then Z_h = 0.6 elseif Z_h>2 then Z_h = 2 end 
    -- mouse and modkeys --
    if gfx.mouse_cap&1==1   and last_mouse_cap&1==0  or   -- L mouse
       gfx.mouse_cap&2==2   and last_mouse_cap&2==0  or   -- R mouse
       gfx.mouse_cap&64==64 and last_mouse_cap&64==0 then -- M mouse
       mouse_ox, mouse_oy = gfx.mouse_x, gfx.mouse_y 
    end
    Ctrl  = gfx.mouse_cap&4==4
    Shift = gfx.mouse_cap&8==8
    Alt   = gfx.mouse_cap&16==16 -- Shift state
    -------------------------
    -- DRAW,MAIN functions --
      main() -- Main()
      DRAW_F(Frame_TB)  -- draw frame
      DRAW_B(Button_TB) -- Draw Static Buttons 
    -------------------------
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
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
------
Init()
restore()
reaper.atexit(save_tracks)
mainloop()
