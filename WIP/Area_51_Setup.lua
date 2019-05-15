local ascii = {}
groups = {}

for i = 1, 255 do
  local name = string.char(i)
  if i == 16 then name = "Shift"
  elseif i == 17  then name = "Ctrl"
  elseif i == 18  then name = "Alt"
  elseif i == 13  then name = "Return"
  elseif i == 8   then name = "Backspace"
  elseif i == 32  then name = "Space"
  elseif i == 20  then name = "Caps-Lock"
  elseif i == 9   then name = "TAB"
  elseif i == 192 then name = "~"
  elseif i == 91  then name = "Win"
  elseif i == 45  then name = "Insert"
  elseif i == 46  then name = "Del"
  elseif i == 36  then name = "Home"
  elseif i == 35  then name = "End"
  elseif i == 33  then name = "PG-Up"
  elseif i == 33  then name = "PG-Down"
  end
  ascii[i] = {name = name, press = false}
end

local function nl()
  gfx.y = gfx.y + 15
end

local function drawline(str)
  gfx.x = 0
  gfx.drawstr(str)
  nl()
end

local function has_keys(tab, val)
  for i = 1 , #tab do
    local in_table = tab[i].keys
    if in_table == val then return tab[i] end
  end
end

local function main()
  local keys, temp = {}, {}
  
  local k_state = reaper.JS_VKeys_GetState(0)
  
  --[[
  local m_state = reaper.JS_Mouse_GetState(3)
  
  if m_state & 1 ~= 0 then
    keys[#keys+1] = "Mouse L"
  elseif m_state & 2 ~= 0 then
  
    keys[#keys+1] = "Mouse R"
  end
  ]]
  
  for k, v in pairs(ascii) do
    if k_state:byte(k) ~= 0 and k ~= 13 then
      v.press = true
      keys[#keys+1] = v.name
      temp[k] = v
    else
      v.press = false
      v.press = false
    end
  end
  
  if k_state:byte(0x0D) ~= 0 then -- CONFIRM (enter key)
    if not has_keys(groups, table.concat(keys, ' + ')) and table.concat(keys, ' + ') ~= "" then
      groups[#groups+1] = temp
      groups[#groups].all_press = false
      groups[#groups].keys = table.concat(keys, ' + ')
    end
  end
  
  for i = 1, #groups do
    groups[i].all_press = true
    for k,v in pairs(groups[i]) do
      if type(k) ~= "string" then -- AVOID ".all_press"
        if not v.press then groups[i].all_press = false break end
      end
    end
    drawline(string.format(" Key Group: " .. i .. " => %s - %s", groups[i].keys, string.upper(tostring(groups[i].all_press))))
  end
  
  
  gfx.y = 35
  drawline(" KEYS FOR INTERCEPTING "); nl()
  drawline(string.format(" Keys => %s", table.concat(keys, ' + '))); nl()
  
  reaper.defer(main)
end
gfx.init("Area 51 SETUP",400,200,0,0)
main()
