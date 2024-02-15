-- @metapackage
-- @description Mavriq Lua Sockets
-- @version 1.2
-- @author Mavriq
-- @about
--   # Allows use of Lua Sockets in 'REAPER'
--   Reaper is missing Lua Auxlib in it's embedded version of Lua. As such things such as the luasockets library etc will not work. If loaded they will throw an error for missing symbols when the library tries to access those in the missing AuxLib.
--   
--   Until the REAPER devs fix this, we have to work around the issue. This project does that for all all three REAPER platforms.
--   
--   This package is used by other scripts and doesn't do anything on its own.
--
--   ### Thanks
--   A huge thanks to Sexan and Daniel Lumertz for updating the packages to 5.4 in my absence. And cfillion for doing final testing on mac and linux as I had no access at that moment.
-- @donation: https://www.paypal.com/paypalme/mavriqdev
-- @links
--   Forum Thread https://github.com/available_soon
--   GitHub repository https://github.com/mavriq-dev/mavriq-lua-sockets
-- @changelog
--   V1.2
--    + fix for Reaper 7/Lua 5.4
--   V1.1.2
--    + fix M1
--   V1.1.1
--    + fixed issue with mac silicon due to changes in Reapack
--   V1.1.0
--    + added support for mac silicon
--    + added support for older macs (10.9+)
--   v1.0.0
--    + initial release
--   v1.0.0pre3
--    + linux fix
--   v1.0.0pre2
--    + fixed linux version
--   v1.0.0pre1
--    + initial release
-- @provides
--   /Various/Mavriq-Lua-Sockets/*.lua
--   [win64] /Various/Mavriq-Lua-Sockets/socket/core.dll
--   [darwin64] /Various/Mavriq-Lua-Sockets/socket/core.so
--   [darwin-arm64] /Various/Mavriq-Lua-Sockets/socket/core.so
--   [linux64] /Various/Mavriq-Lua-Sockets/socket/core.so.linux > socket/core.so


-----------------------------------------------------------------------------
-- LuaSocket helper module
-- Author: Diego Nehab
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Declare module and import dependencies
-----------------------------------------------------------------------------
local base = _G
local string = require("string")
local math = require("math")
local socket = require("socket.core")

local _M = socket

-----------------------------------------------------------------------------
-- Exported auxiliar functions
-----------------------------------------------------------------------------
function _M.connect4(address, port, laddress, lport)
    return socket.connect(address, port, laddress, lport, "inet")
end

function _M.connect6(address, port, laddress, lport)
    return socket.connect(address, port, laddress, lport, "inet6")
end

function _M.bind(host, port, backlog)
    if host == "*" then host = "0.0.0.0" end
    local addrinfo, err = socket.dns.getaddrinfo(host);
    if not addrinfo then return nil, err end
    local sock, res
    err = "no info on address"
    for i, alt in base.ipairs(addrinfo) do
        if alt.family == "inet" then
            sock, err = socket.tcp4()
        else
            sock, err = socket.tcp6()
        end
        if not sock then return nil, err end
        sock:setoption("reuseaddr", true)
        res, err = sock:bind(alt.addr, port)
        if not res then
            sock:close()
        else
            res, err = sock:listen(backlog)
            if not res then
                sock:close()
            else
                return sock
            end
        end
    end
    return nil, err
end

_M.try = _M.newtry()

function _M.choose(table)
    return function(name, opt1, opt2)
        if base.type(name) ~= "string" then
            name, opt1, opt2 = "default", name, opt1
        end
        local f = table[name or "nil"]
        if not f then base.error("unknown key (".. base.tostring(name) ..")", 3)
        else return f(opt1, opt2) end
    end
end

-----------------------------------------------------------------------------
-- Socket sources and sinks, conforming to LTN12
-----------------------------------------------------------------------------
-- create namespaces inside LuaSocket namespace
local sourcet, sinkt = {}, {}
_M.sourcet = sourcet
_M.sinkt = sinkt

_M.BLOCKSIZE = 2048

sinkt["close-when-done"] = function(sock)
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function(self, chunk, err)
            if not chunk then
                sock:close()
                return 1
            else return sock:send(chunk) end
        end
    })
end

sinkt["keep-open"] = function(sock)
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function(self, chunk, err)
            if chunk then return sock:send(chunk)
            else return 1 end
        end
    })
end

sinkt["default"] = sinkt["keep-open"]

_M.sink = _M.choose(sinkt)

sourcet["by-length"] = function(sock, length)
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function()
            if length <= 0 then return nil end
            local size = math.min(socket.BLOCKSIZE, length)
            local chunk, err = sock:receive(size)
            if err then return nil, err end
            length = length - string.len(chunk)
            return chunk
        end
    })
end

sourcet["until-closed"] = function(sock)
    local done
    return base.setmetatable({
        getfd = function() return sock:getfd() end,
        dirty = function() return sock:dirty() end
    }, {
        __call = function()
            if done then return nil end
            local chunk, err, partial = sock:receive(socket.BLOCKSIZE)
            if not err then return chunk
            elseif err == "closed" then
                sock:close()
                done = 1
                return partial
            else return nil, err end
        end
    })
end


sourcet["default"] = sourcet["until-closed"]

_M.source = _M.choose(sourcet)

return _M
