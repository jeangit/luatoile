#!/usr/bin/env lua
-- $$DATE$$ : ven. 17 janv. 2020 16:02:53

local socket = require"socket"
local client,server
local is_running = true

local function init()
  print("Running with ".. _VERSION)
  local root = arg[1] or "index.html"
  local port = arg[2] or 8088
  server = socket.bind("0.0.0.0", 8088)
end

local function urldecode( url)
  local decoded = string.gsub( url, "%+", " ")
  decoded = string.gsub( decoded, "%%(%x%x)",
            function(char)
                  -- receives (%x%x) and leaves longer strings
                return string.char(tonumber(char, 16))
            end)
  return decoded
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

local function whoami( header)
  local buffer = {}
  local header = read_header()
  for k,v in pairs(header) do
    buffer[#buffer+1]= k .." = " .. v
  end
  return table.concat(buffer,"\n")
end

local function quit()
  --TODO check it's called locally
  --print(client:getsockname())
  client:send("disconnected")
  is_running = false
end


local function serve_client( buffer)
  client:send( string.format("HTTP/1.0 200 OK\r\nserver: luatoile\r\ndate: %s\r\ncontent-type: text/html; charset=UTF-8\r\ncontent-length: %d\r\n\r\n",
  "Lundi 35 Mai",#buffer))
  client:send( buffer)

end


local function get( path)
  local special = { ["/whoami"] = whoami, ["/quit"] = quit , ["/"] = function() return "index.html" end }
  local buffer = ""

  if special[path] then
    buffer = special[path]()
  else
    local header = read_header()
    --client:send("\n" .. urldecode(path))
    -- get file
  end
  serve_client( buffer)
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
    
    -- first line : contains command, path, protocol
    local line = client:receive()
    local command,path,proto = line:match("([A-Z]+)%s+(%S+)%s+(HTTP.+)")
    print (string.format('command:"%s" path:"%s" proto:"%s"',command,path,proto))

    call_command( command, path)

    client:close()
  end
end

init()
mainloop()

