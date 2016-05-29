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


-----------------------------------------------------------------------------------------------
---------                            ReaTrackVersions                                ----------
-----------------------------------------------------------------------------------------------

local last_proj_change_count = reaper.GetProjectStateChangeCount(0)
Button_TB = {}          -- A table for "dynamic" buttons
local Static_Buttons_TB = {}  -- A table for "static" buttons
 -- Variables to set the button drawing pos (updated when new button is created)

local Element = {}
function Element:new(x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz, norm_val, norm_val2, state)
    local elm = {}
    elm.def_xywh = {x,y,w,h,fnt_sz} -- its default coord,used for Zoom etc
    elm.x, elm.y, elm.w, elm.h = x, y, w, h
    elm.r, elm.g, elm.b, elm.a = r, g, b, a
    elm.lbl, elm.fnt, elm.fnt_sz  = lbl, fnt, fnt_sz
    elm.norm_val = norm_val
    elm.norm_val2 = norm_val2
    elm.state = state or {}
    ------
    setmetatable(elm, self)
    self.__index = self 
    return elm
end--------------------------------------------------------------
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
--------------------------------------------------------------------------------
---   Create Element Child Classes(Button,Slider,Knob)   -----------------------
--------------------------------------------------------------------------------
local Button = {}
  extended(Button,     Element)  
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
------------------------function Button:draw()
function Button:draw()
  --DBG("Button::draw")
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
    if self.norm_val == 1 then a = a+0.3 end
    local fnt,fnt_sz = self.fnt, self.fnt_sz
    -- Get mouse state ---------
          -- in element --------
          if self:mouseIN() then a=a+0.1 end
          -- in elm L_down -----
          if self:mouseDown() then a=a+0.2 end
          -- in elm L_up(released and was previously pressed) --
          if self:mouseClick() and self.onClick then self.onClick() end
    -- Draw btn body, frame ----
    gfx.set(r,g,b,a)    -- set body color
    self:draw_body()    -- body
    self:draw_frame()   -- frame
    -- Draw label --------------
    gfx.set(0.7, 0.9, 0.4, 1)   -- set label color
    gfx.setfont(1, fnt, fnt_sz) -- set label fnt
    self:draw_lbl()             -- draw lbl
end             
------------------------------------
--- Create static "store" button ---
------------------------------------
local save_btn = Button:new(10,220,40,20, 0.2,0.2,1.0,0.5, "Save","Arial",15, 0 )


save_btn.onClick =  function()
                    local tr = reaper.GetSelectedTrack(0, 0) 
                          if tr then 
                             --local ret, chunk = reaper.GetTrackStateChunk(tr,"", 0) 
                                   --[[
                                   for k , v in pairs(Button_TB)do
                                       if chunk == v.state.chunk then return end 
                                   end
                                   --]]
                             local retval, version_name = reaper.GetUserInputs("Version Name", 1, "Enter Version Name:", "")  
                                  if not retval then return end                            
                             create_button_from_selection(tr,version_name) 
                             save_tracks() 
                          end                            
                    end                
                    
                    
local Static_Buttons_TB = {save_btn}
-------------------------------------------
----------------------------------------------------------------------------------------------------
---   Main DRAW function   -------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
function DRAW(tbl)
    for key,btn  in pairs(tbl) do btn:draw()  end
end


----------------------------------------------------------------------------------------------------
---  Getting/setting track items functions  --------------------------------------------------------
-- This uses all API with no track chunks involved -------------------------------------------------
----------------------------------------------------------------------------------------------------

local function restoreTrackItems(track, track_items_table)
  local num_items = reaper.CountTrackMediaItems(track)
  reaper.PreventUIRefresh(1)
  if num_items>0 then  
    for i = 1, num_items, 1 do
      reaper.DeleteTrackMediaItem(track, reaper.GetTrackMediaItem(track,0))
    end
  end
  for i = 1, #track_items_table, 1 do
    local item = reaper.AddMediaItemToTrack(track)
    --local item = reaper.CreateNewMIDIItemInProj(track, 1, 1) -- maybe there's another way?
    reaper.SetItemStateChunk(item, track_items_table[i], false)
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end


-- return a table of all item chunks on a track
local function getTrackItems(track)
  local items={}
  local num_items = reaper.CountTrackMediaItems(track)
  --DBG("num_items = "..num_items)
  for i=1, num_items, 1 do
    local item = reaper.GetTrackMediaItem(track, i-1)
    local _, it_chunk = reaper.GetItemStateChunk(item, '')
    items[#items+1]=it_chunk
  end
  return items
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--   INIT   --------------------------------------------------------------------
--------------------------------------------------------------------------------
function Init()
  DBG("Init")
    -- Some gfx Wnd Default Values --
    local R,G,B = 20,20,20               -- 0..255 form
    local Wnd_bgd = R + G*256 + B*65536  -- red+green*256+blue*65536  
    local Wnd_Title = "ReaTrack-Versions"
    local Wnd_Dock,Wnd_X,Wnd_Y = 0,100,320
    Wnd_W,Wnd_H = 235,250 -- global values(used for define zoom level)
    -- Init window ------
    gfx.clear = Wnd_bgd         
    gfx.init( Wnd_Title, Wnd_W,Wnd_H, Wnd_Dock, Wnd_X,Wnd_Y )
    -- Init mouse last --
    last_mouse_cap = 0
    last_x, last_y = 0, 0
    mouse_ox, mouse_oy = -1, -1
end
----------------------------------------
----------------------------------------
--   Mainloop   ------------------------
----------------------------------------
function mainloop()
-- zoom level --
--    Z_w, Z_h = gfx.w/Wnd_W, gfx.h/Wnd_H
--    if Z_w<0.6 then Z_w = 0.6 elseif Z_w>2 then Z_w = 2 end
--    if Z_h<0.6 then Z_h = 0.6 elseif Z_h>2 then Z_h = 2 end 
-- mouse and modkeys --
    if gfx.mouse_cap&1==1   and last_mouse_cap&1==0  or   -- L mouse
       gfx.mouse_cap&2==2   and last_mouse_cap&2==0  or   -- R mouse
       gfx.mouse_cap&64==64 and last_mouse_cap&64==0 then -- M mouse
       mouse_ox, mouse_oy = gfx.mouse_x, gfx.mouse_y 
    end 
    -----------------------
    -----------------------
    main()
    DRAW(Static_Buttons_TB)
    -----------------------
    -----------------------
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
-------------------------------------------
--- Function: Create Button and Define  ---
------------------------------------------- 
function create_button(name,GUID,chunk)
  btn_w = 65              -- width for new buttons
  btn_h = 20              -- height for new buttons
  btn_pad_x = 10          -- x space between buttons
  btn_pad_y = 10          -- y space between buttons

  local state = {}     -- now the things we want to store in our buttons
  state.name = name    -- are stored into a state table, for pickling
  state.GUID = GUID;
  state.chunk = chunk;

  local btn = Button:new(
                 0, --  x
                 0, --  y 
                 btn_w,              --  w
                 btn_h,              --  h
                 0.2,                --  r
                 0.2,                --  g
                 1.0,                --  b
                 0.5,                --  a                             
                 name,               --  track name
                 "Arial",            --  label font
                 15,                 --  label font size
                 0,                  --  norm_val
                 0,                  --  norm_val2
                 state               --  state
                )
                
  local track = reaper.BR_GetMediaTrackByGUID(0, GUID)
  local retval, flags = reaper.GetTrackState(track) -- get track flag
  btn.track=track

  btn.onClick = function()
                  if gfx.mouse_cap&16==16 then --Alt is pressed
                    for i=1,#Button_TB,1 do
                      if Button_TB[i]==btn then
                        table.remove(Button_TB,i)
                        save_tracks()
                        break
                      end
                    end                        
                    return
                  end 
                  ---- add code when clicking on folder button
                  ---- to change all child versions,
                  ---- at the moment it will breake the script if pressed 
                  if flags&1 == 1 then
                    for i = 1 , #btn.state.chunk do
                       local f_track = reaper.BR_GetMediaTrackByGUID(0, btn.state.chunk[i].GUID)
                       btn.track=f_track
                       restoreTrackItems(btn.track, btn.state.chunk[i].chunk)
                    end
                    return
                  end         
                  restoreTrackItems(btn.track, btn.state.chunk)
                end 
              
Button_TB[#Button_TB+1] = btn           
end
----------------------------------------------- 
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
  
  for k, v in ipairs(Button_TB) do
    all_button_states[#all_button_states+1] = v.state
  end
  
  reaper.SetProjExtState(0, "Track_Versions", "States", pickle(all_button_states))
end

-----------------------------------------------
--- Function: Restore Saved Buttons From extstate ---
-----------------------------------------------
function restore()
  DBG("Restoring")
  local ok, states = reaper.GetProjExtState(0, "Track_Versions","States")
  if states~="" then
    states = unpickle(states)
    for i = 1, #states do
      local s = states[i]
      create_button(s.name,s.GUID,s.chunk)
    end
  else
    DBG("state=\"\"")
  end
end

-----------------------------------------------
--- Function: Get Folder Depth ---
-----------------------------------------------
function get_track_folder_depth(track_index)
  local folder_depth = 0
  for i=0, track_index do -- loop from start of tracks to "track_index"... 
    local track = reaper.GetTrack(0, i)
    folder_depth = folder_depth + reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") -- ...to get the actual folder depth
  end
  return folder_depth
end

-----------------------------------------------
--- Function: Create Buttons From Selection ---
-----------------------------------------------
function create_button_from_selection(tr,version_name)
local retval, flags = reaper.GetTrackState(tr) -- get track flag
         
             if flags&1 == 1 then -- if track is a folder
                child_tracks = {} -- table for all child data           
                local tr_index = reaper.CSurf_TrackToID(tr, false) - 1 -- get folder track id
                local parent_folder_depth = get_track_folder_depth(tr_index) -- get folder depth
                
                for i = tr_index + 2, reaper.CountTracks(0) do                         
                    local child_tr = reaper.GetTrack(0, i-1)
                    local retval, child_flags = reaper.GetTrackState(child_tr) -- get child track flag
                    
                    if child_flags&1 ~= 1 then -- if child is not a folder
                    -----------create button for child tracks
                       local c_chunk = getTrackItems(child_tr)
                       local c_GUID  = reaper.GetTrackGUID(child_tr)
                       local c_name  = version_name
                       child_tracks[#child_tracks+1] = { name = version_name , GUID = c_GUID , chunk = c_chunk}
                       create_button(c_name,c_GUID,c_chunk)
                    end
                    
                    child_track_folder_depth = parent_folder_depth + reaper.GetMediaTrackInfo_Value(child_tr, "I_FOLDERDEPTH")
                    if child_track_folder_depth < parent_folder_depth then break end 
                end
             ---------- create button in folder track for with all child data                      
             local f_chunk = child_tracks
             local f_GUID  = reaper.GetTrackGUID(tr)
             local f_name  = "Folder :" .. version_name
             create_button(f_name,f_GUID,f_chunk)              
             else
             -------------create button for selected track
             local t_chunk = getTrackItems(tr)
             local t_GUID  = reaper.GetTrackGUID(tr)
             local t_name  = version_name
             create_button(t_name,t_GUID,t_chunk)
             end
end
-----------------------------------------------
--- Function: Delete button from table it button track is deleted ---
-----------------------------------------------
function track_deleted()
local temp_del = {}

  for k,v in ipairs(Button_TB)do
      local cnt_tr = reaper.CountTracks(0)
      for i = 0 , cnt_tr-1 do
          local tr = reaper.GetTrack(0, i)
          local guid = reaper.GetTrackGUID(tr)
          if v.state.GUID == guid then
             temp_del[#temp_del+1]=Button_TB[k]
          end
      end
  end
  
Button_TB = temp_del
save_tracks()
end
----------------------------------------
--   Main  -----------------------------
----------------------------------------
function main()
local proj_change_count = reaper.GetProjectStateChangeCount(0)
  if proj_change_count > last_proj_change_count then
      local last_action = reaper.Undo_CanUndo2(0)
      if last_action == "Remove Tracks" then
         track_deleted()
      end
      last_proj_change_count = proj_change_count
  end
local count_tracks = reaper.CountSelectedTracks(0)  
local sel_track = reaper.GetSelectedTrack(0,0)
  
----------print track name in window

for i = 1, count_tracks do
  s_track = reaper.GetSelectedTrack(0,i-1)
end

  if sel_track then
     local guid = reaper.GetTrackGUID(sel_track)
     local retval, title_name = reaper.GetSetMediaTrackInfo_String(sel_track, "P_NAME", "", false)
     if count_tracks > 1 then
     title_name = "Multiple Tracks Selected"
     end
     gfx.x = 10
     gfx.y = 8
     gfx.printf("Current Track : " .. title_name)
     
----------show only buttons for currently selected track , add them to current_track table  
local current_track = {}
     for k,v in pairs(Button_TB) do
         if guid == v.state.GUID then
            current_track[#current_track+1] = Button_TB[k]
         end         
     end

--[[ --------highlight selected button, this needs a better approach (in the button table somehow
local current_items = getTrackItems(sel_track)
     for k,v in ipairs(current_track)do
        if #current_items == #v.state.chunk then
            v.norm_val = 1
            else
            v.norm_val = 0
            end
      end
]]      
----------position of the buttons of current track table on the fly-------------
local pos_x = 10
local pos_y = 30
local btn_pos_counter = 0
    
     for k,v in pairs(current_track)do
         v.x = pos_x
         v.y = pos_y + ((btn_h + btn_pad_y)*btn_pos_counter)
             if v.y + btn_h + btn_pad_y >= gfx.h-50 then
                btn_pos_counter=-1
                pos_y=30
                pos_x = pos_x + btn_w + btn_pad_x
             end
         btn_pos_counter = btn_pos_counter + 1
      end           
  DRAW(current_track)
  end      
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Init()
restore()
mainloop()
