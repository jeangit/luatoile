#!/usr/bin/env lua
-- $$DATE$$ : jeu. 16 janv. 2020 16:35:06

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
    local param, value = line:match("^(%S-)%s*:%s*(.*)")
    if (param) then
      header[param]=value
    end
  until line == ""
  return header
end

local function get()
  local header = read_header()

  for k,v in pairs(header) do
    client:send( k .." = " .. v .. "\n")
  end

end

local function call_command( command, path)
  local command_list = { GET = get }
  if command_list[command] then
    command_list[command]()
  else
    print("[error] Unknown command : client asked ",command)
  end
end

local function mainloop()
  while true do  
    client = server.accept( server)
    local line = client:receive()
    -- 1ère ligne requête
    local command,path,proto = line:match("([A-Z]+)%s+(%S+)%s+(HTTP.+)")
    client:send(string.format('command:"%s" path:"%s" proto:"%s"\n',command,path,proto))
    call_command( command, path)
      

    --print(client:getsockname())

    client:close()
  end
end

init()
mainloop()

