#!/usr/bin/env lua
-- $$DATE$$ : ven. 17 janv. 2020 11:39:54

local socket = require"socket"
local client,server
local is_running = true

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

local function whoami()
  local header = read_header()

  for k,v in pairs(header) do
    client:send( k .." = " .. v .. "\n")
  end
end

local function quit()
  client:send("disconnected")
  is_running = false
end


local function get( path)
  local special = { ["/whoami"] = whoami, ["/quit"] = quit }

  print(path)
  if special[path] then
    special[path]()
  else
    client:send(path)
    -- get file
  end
end

local function call_command( command, path)
  local command_list = { GET = get }
  if command_list[command] then
    command_list[command]( path)
  else
    print("[error] Unknown command : client asked ",command)
  end
end

local function mainloop()
  while is_running do  
    client = server.accept( server)
    local line = client:receive()
    -- 1ère ligne requête
    local command,path,proto = line:match("([A-Z]+)%s+(%S+)%s+(HTTP.+)")
    print (string.format('command:"%s" path:"%s" proto:"%s"',command,path,proto))
    call_command( command, path)
      

    --print(client:getsockname())

    client:close()
  end
end

init()
mainloop()

