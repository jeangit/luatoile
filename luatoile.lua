#!/usr/bin/env lua
-- $$DATE$$ : mer. 15 janv. 2020 19:33:05

local socket = require"socket"
local client,server

local function init()
  print("Running with ".. _VERSION)
  local root = arg[1] or "index.html"
  local port = arg[2] or 8088
  server = socket.bind("0.0.0.0", 8088)
end

local function read_header()
  local header = {}
  repeat
    line = client:receive()
    local param, value = line:match("(%S-)%s*:%s*(.*)")
    if (param) then
      header[param]=value
    end
  until line == ""
  return header
end

local function mainloop()
  client = server.accept( server)
  local line = client:receive()
  -- 1ère ligne requête
  local command,path,proto = line:match("([A-Z]+)%s+(%S+)%s+(HTTP.+)")
  local header = read_header()

  client:send(string.format('command:"%s" path:"%s" proto:"%s"\n',verb,path,proto))
  for k,v in pairs(header) do
    client:send( k .." = " .. v .. "\n")
  end

  --print(client:getsockname())

  client:close()
end

init()
mainloop()

