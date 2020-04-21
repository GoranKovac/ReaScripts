--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.05
	 * NoIndex: true
--]]
local reaper = reaper
local Key_TB = {}
local key
local key_state, last_key_state
local intercept_keys = -1

local startTime = reaper.time_precise()
local thisCycleTime
local Element = {}

function modifier_name(mod)
   if mod == 4 then return "Ctrl"
   elseif mod == 8 then return"Shift"
   elseif mod == 16 then return "Alt"
   elseif mod == 24 then return "Alt_Shift"
   elseif mod == 12 then return "Ctrl_Shift"
   elseif mod == 20 then return "Ctrl_Alt"
   elseif mod == 28 then return "Ctrl_Shift_Alt"
   else return
   end
end

function Element:new(ID, name, func, m_key)
   local elm = {}
   elm.ID            = ID
   elm.name          = name
   elm.press         = function()  local start = true
                                 for i = 1, #elm.ID do
                                    if key_state:byte(elm.ID[i]) == 0 then start = false break end-- BREAK IF NOT BOTH KEYS ARE PRESSED
                                 end
                                 return start
                                 end
   elm.m_key = m_key
   elm.down_time     = 0
   elm.last_key_down = false
   elm.last_key_hold = false
   elm.last_key_up   = true
   elm.func          = func
   elm.int = -1
   ----------------------
   setmetatable(elm, self)
   self.__index = self
   return elm
end

function Extended(Child, Parent)
   setmetatable(Child,{__index = Parent})
end

local Key = {}
Extended(Key,     Element)

function Element:intercept(int)
  for i = 1, #self.ID do
    reaper.JS_VKeys_Intercept(self.ID[i], int)
  end
end

function Element:exec_func()
   local f_arr = type(tonumber(self.name)) == "number" and tonumber(self.name) or nil
   if self.func then
      _G[self.func](f_arr)
   end
end

function exec_func(tbl)
   local f_arr = type(tonumber(tbl.name)) == "number" and tonumber(tbl.name) or nil
   if tbl.func then--and AREA_ACTIVE then
      _G[tbl.func](f_arr)
   end
     -- if not tbl.m_key then
      --   reaper.JS_VKeys_Intercept(tbl.ID[1],1)
       --  _G[tbl.func](f_arr)
     -- else
     --    if tbl.mod == tbl.m_key then
      --      _G[tbl.func](f_arr)
     --    end
     -- end
  -- end
   --if AREA_ACTIVE then reaper.JS_VKeys_Intercept(tbl.ID[1],-1) end
end

function Element:onKeyDown(kd)
   if kd and self.last_key_down == false then
      self.down_time = os.clock()
      self.last_key_down = true
      self.last_key_up   = false
      key["DOWN"] = self
      --exec_func(self)
      --end
   end
end

function Element:OnKeyUp(kd)
   if not kd and self.last_key_down == true and self.last_key_up == false then
      self.last_key_up   = true
      self.last_key_down = false
      self.last_key_hold = false
      key["UP"] = self
      --self:exec_func()
      --end
   end
end

function Element:onKeyHold()
   self.last_key_hold = true
   --self.int = 1
   --reaper.JS_VKeys_Intercept(self.ID[1],1)
   key["HOLD"] = self
   --self:exec_func()
   --return self
end

function Element:GetKey()
   local KEY_DOWN = self.press()
   --self.mod = modifier_name(reaper.JS_Mouse_GetState(95))

   if KEY_DOWN then
      if self.last_key_up == true and self.last_key_down == false then
         self:onKeyDown(KEY_DOWN)
      elseif self.last_key_up == false and self.last_key_down == true then
         if os.clock() - self.down_time > 0.15 then
            self:onKeyHold()
         end
      end
   elseif not KEY_DOWN and self.last_key_up == false and self.last_key_down == true then
      self:OnKeyUp(KEY_DOWN)
   end
end

function Track_keys()
   local prevCycleTime = thisCycleTime or startTime
   thisCycleTime = reaper.time_precise()
   key_state = reaper.JS_VKeys_GetState(startTime-2)
   key = {}

   if key_state ~= last_key_state then
      for i = 1, #Key_TB do Key_TB[i]:GetKey() end
      last_key_state = key_state
   end

   if key.DOWN then exec_func(key.DOWN) end
   FOLDER_MOD = ((key.HOLD) and (key.HOLD.name == "FOLDER")) and true or nil
end

function Intercept_reaper_key(tbl)
   local val = #tbl ~= 0 and 1 or -1
   if val ~= intercept_keys then
      for i = 1, #Key_TB do
         if Key_TB[i].func then
            Key_TB[i]:intercept(val) -- INTERCEPT OR RELEASE INTERCEPT
         end
      end
      intercept_keys = val
   end
end

function Release_reaper_keys()
   for i = 1, #Key_TB do
      if Key_TB[i].func then
         Key_TB[i]:intercept(-1)
      end
   end
end

for i = 1, 255 do
   local func
   local name = string.char(i)
   if type(tonumber(name)) == "number" then
      func = "Select_as"
   end
   if name == "S" then
      func = "As_split"
   end
   if i == 16 then
      name = "Shift"
   elseif i == 17 then
      name = "Ctrl"
   elseif i == 18 then
      name = "Alt"
   elseif i == 13 then
      name = "Return"
   elseif i == 8 then
      name = "Backspace"
   elseif i == 32 then
      name = "Space"
   elseif i == 20 then
      name = "Caps-Lock"
   elseif i == 27 then
      name = "ESC"
      func = "Remove"
   elseif i == 9 then
      name = "TAB"
   elseif i == 192 then
      name = "~"
   elseif i == 91 then
      name = "Win"
   elseif i == 45 then
      name = "Insert"
   elseif i == 46 then
      name = "Del"
      func = "Del"
   elseif i == 36 then
      name = "Home"
   elseif i == 35 then
      name = "End"
   elseif i == 33 then
      name = "PG-Up"
   elseif i == 34 then
      name = "PG-Down"
   end
      Key_TB[#Key_TB + 1] = Key:new({i}, name, func)

      Key_TB[#Key_TB + 1] = Key:new({17,67}, "COPY", "Copy_mode", "Ctrl") -- COPY (TOGGLE)
      Key_TB[#Key_TB + 1] = Key:new({17,86}, "PASTE", "Copy_Paste", "Ctrl") -- PASTE
      Key_TB[#Key_TB + 1] = Key:new({17,68}, "DUPLICATE", "Duplicate_area","Ctrl") -- PASTE
      Key_TB[#Key_TB + 1] = Key:new({89}, "FOLDER") -- PASTE
end