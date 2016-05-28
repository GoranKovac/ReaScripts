local last_proj_change_count = reaper.GetProjectStateChangeCount(0)
local Button_TB = {}          -- A table for "dynamic" buttons
local Static_Buttons_TB = {}  -- A table for "static" buttons
 -- Variables to set the button drawing pos (updated when new button is created)

local Element = {}
function Element:new(x,y,w,h, r,g,b,a, lbl,fnt,fnt_sz, norm_val, norm_val2, tr_guid, tr_chunk)
    local elm = {}
    elm.def_xywh = {x,y,w,h,fnt_sz} -- its default coord,used for Zoom etc
    elm.x, elm.y, elm.w, elm.h = x, y, w, h
    elm.r, elm.g, elm.b, elm.a = r, g, b, a
    elm.lbl, elm.fnt, elm.fnt_sz  = lbl, fnt, fnt_sz
    elm.norm_val = norm_val
    elm.norm_val2 = norm_val2
    elm.tr_guid = tr_guid
    elm.tr_chunk = tr_chunk
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
    self:update_xywh() -- Update xywh(if wind changed)
    local r,g,b,a  = self.r,self.g,self.b,self.a
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
                             local ret, chunk = reaper.GetTrackStateChunk(tr,"", 0) 
                                   for k , v in pairs(Button_TB)do
                                       if chunk == v.tr_chunk then return end 
                                   end
                             local retval, version_name = reaper.GetUserInputs("Version Name", 1, "Enter Version Name:", "")  
                                  if not retval then return end                            
                             create_button_from_selection(version_name) 
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
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--   INIT   --------------------------------------------------------------------
--------------------------------------------------------------------------------
function Init()
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
                 GUID,               --  tr_guid
                 chunk               --  tr_chunk
                )
                
local track = reaper.BR_GetMediaTrackByGUID(0, btn.tr_guid)

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
              reaper.SetTrackStateChunk(track, chunk)         
              end 
              
Button_TB[#Button_TB+1] = btn           
end
----------------------------------------------- 
-----------------------------------------------
--- Function: convert string to table pStringe = string , pPatern = "," (simbol for separating)
-----------------------------------------------
function split(pString, pPattern)
local Table = {}
local fpat = "(.-)" .. pPattern
local last_end = 1
local s, e, cap = pString:find(fpat, 1)
while s do
  if s ~= 1 or cap ~= "" then
   table.insert(Table,cap)
  end
  last_end = e+1
  s, e, cap = pString:find(fpat, last_end)
end
if last_end <= #pString then
  cap = pString:sub(last_end)
  table.insert(Table, cap)
end
return Table
end

----------------------------------------------- 
-----------------------------------------------
--- Function: store buttons to ext state ---
-----------------------------------------------
function save_tracks()
local save_chunk = {}  
local save_name = {}
   
     for k , v in ipairs(Button_TB) do
     save_chunk[#save_chunk+1] = v.tr_chunk .. ","
     save_name[#save_name+1] = v.lbl .. ","
    end
    
     local concat_save_chunk = table.concat(save_chunk)
     local concat_save_name = table.concat(save_name)
     reaper.SetProjExtState(0,"Track_Versions","Chunk",concat_save_chunk)
     reaper.SetProjExtState(0,"Track_Versions","Name",concat_save_name)
end
-----------------------------------------------
--- Function: Restore Saved Buttons From extstate ---
-----------------------------------------------
function restore()
local retval, rs_chunk = reaper.GetProjExtState(0, "Track_Versions","Chunk")
local retval, rs_name = reaper.GetProjExtState(0, "Track_Versions","Name")
local restore_save_chunk = split(rs_chunk, ",")
local restore_save_name = split(rs_name, ",")

  for i = 1 , #restore_save_chunk do
    local chunk = restore_save_chunk[i]
    local name =  restore_save_name[i]
    local GUID = chunk:match("TRACKID ([^ ]+)\n")
    create_button(name,GUID,chunk)
  end
  
end
-----------------------------------------------
--- Function: Create Buttons From Selection ---
-----------------------------------------------
function create_button_from_selection(version_name)
local tr = reaper.GetSelectedTrack(0,0)

      if tr then
         local ret, chunk = reaper.GetTrackStateChunk(tr,"", 0)
         local GUID = chunk:match("TRACKID ([^ ]+)\n")
         local name = version_name
         create_button(name,GUID,chunk)
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
          if v.tr_guid == guid then
             temp_del[#temp_del+1]=Button_TB[k]
          end
      end
  end
  
Button_TB = temp_del
temp_del = {}
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
  
local sel_track = reaper.GetSelectedTrack(0,0)
  
----------print track name in window
  if sel_track then
     local guid = reaper.GetTrackGUID(sel_track)
     local retval, title_name = reaper.GetSetMediaTrackInfo_String(sel_track, "P_NAME", "", false)
     gfx.x = 10
     gfx.y = 8
     gfx.printf("Current Track : " .. title_name)
     
----------show only buttons for currently selected track to a current_track table  
local current_track = {}
     for k,v in pairs(Button_TB) do
         if guid == v.tr_guid then
            current_track[#current_track+1] = Button_TB[k]
         end
     end

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
