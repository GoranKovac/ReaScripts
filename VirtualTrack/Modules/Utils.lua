--[[
   * Author: SeXan
   * Licence: GPL v3
   * Version: 0.01
	 * NoIndex: true
--]]

function tableToString(table)
  return serializeTable(table)
end

function stringToTable(str)
  local f, err = load("return "..str)
  return f ~= nil and f() or nil
end

function serializeTable(val, name, skipnewlines, depth)
  skipnewlines = skipnewlines or false
  depth = depth or 0
  local tmp = string.rep(" ", depth)
  if name then
    if type(name) == "number" and math.floor(name) == name then
      name = "[" .. name .. "]"
    elseif not string.match(name, '^[a-zA-z_][a-zA-Z0-9_]*$') then
      name = string.gsub(name, "'", "\\'")
      name = "['".. name .. "']"
    end
    tmp = tmp .. name .. " = "
  end
  if type(val) == "table" then
    tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
    for k, v in pairs(val) do
      tmp =  tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
    end
    tmp = tmp .. string.rep(" ", depth) .. "}"
  elseif type(val) == "number" then
    tmp = tmp .. tostring(val)
  elseif type(val) == "string" then
    tmp = tmp .. string.format("%q", val)
  elseif type(val) == "boolean" then
    tmp = tmp .. (val and "true" or "false")
  else
    tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
  end
  return tmp
end

function MSG(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
 end