local startTime = reaper.time_precise()
local thisCycleTime
local Element = {}
local as

function Element:new(ID, name, func)
    local elm = {}
    elm.ID            = ID
    elm.name          = name
    elm.press         = function()  local start = true
                                    for i = 1, #elm.ID do 
                                      if reaper.JS_VKeys_GetState(startTime-2):byte(elm.ID[i]) == 0 then start = false break -- BREAK IF NOT BOTH KEYS ARE PRESSED
                                     end 
                                   end
                                   return start
                                   end
    elm.down_time     = 0
    elm.last_key_down = false
    elm.last_key_hold = false
    elm.last_key_up   = true
    elm.func          = func
    ----------------------
    setmetatable(elm, self)
    self.__index = self 
    return elm
end

function extended(Child, Parent)
  setmetatable(Child,{__index = Parent})
end

function Element:intercept(int)
  for i = 1, #self.ID do
    reaper.JS_VKeys_Intercept(self.ID[i], int)
  end
end

function Element:onKeyDown(kd) 
  if kd and self.last_key_down == false then 
    if self.name == "Ctrl" and #as ~= 0 then
      for i = 1, 255 do
      --  reaper.JS_VKeys_Intercept(i, 1)
      end
    end
    self.down_time = os.clock()
    self.last_key_down = true 
    self.last_key_up   = false
    key["DOWN"] = self
    return self
  end
end

function Element:OnKeyUp(kd)
  if not kd and self.last_key_down == true and self.last_key_up == false then
    if self.name == "Ctrl" then
      for i = 1, 255 do
      --  reaper.JS_VKeys_Intercept(i, -1)
      end
    end
    self.last_key_up   = true
    self.last_key_down = false
    self.last_key_hold = false
    key["UP"] = self
  end
end

function Element:onKeyHold()
  self.last_key_hold = true
  key["HOLD"] = self
  return self
end

function Element:GetKey()
  local KEY_DOWN = self.press()
  
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

Key = {}
extended(Key,     Element)

function Track_keys(tbl,tbl2)
  as = tbl2
  local prevCycleTime = thisCycleTime or startTime
  thisCycleTime = reaper.time_precise()
 
  key = {} 
  
  for k,v in pairs(tbl) do v:GetKey() end 
  
  if key.DOWN or key.UP or key.HOLD then return key end
end
