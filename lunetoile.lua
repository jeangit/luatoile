#!/usr/bin/env lua
-- $$DATE$$ : sam. 18 janv. 2020 17:04:02

local socket = require"socket"
local client,server
local is_running = true
local root = "./"

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
                local d = string.char(tonumber(char, 16))
                if d == '.' then d ="" end -- minimal protection against dir exploration
                  -- receives (%x%x) and leaves longer strings
                return d
            end)
  return decoded
end


local function read_header( client)
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

local function read_file( filename)
  local buffer = nil
  local fullpath = root .. filename
  print ("reading : " .. fullpath)
  local hfile = io.open( fullpath, "r")
  if hfile then
    buffer = hfile:read("*a")
    hfile:close()
  else
    buffer = "<html><body><h1>404 : What do you want with " .. filename .. " ?</h1></body></html>"
  end

  return buffer
end


local function whoami( client)
  local buffer = { "<html><body><pre>" }
  local header = read_header( client)
  for k,v in pairs(header) do
    buffer[#buffer+1]= k .." = " .. v
  end
  buffer[#buffer+1] = "</pre></body></html>"
  return table.concat(buffer,"\n")
end

local function is_localhost( client)
  local is_local = false
  -- getsockname returns ip,port,proto
  local ip = client:getsockname()
  if ip == "127.0.0.1" then is_local = true end

  return is_local
end

local function quit( client)
  local buffer = nil
  if is_localhost( client) then
    is_running = false
    return "</html><body><h1>Disconnected</h1><body></html>"
  else
    buffer = read_file( "quit")
  end

  return buffer
end


local function serve_client( client, buffer)
  client:send( string.format("HTTP/1.0 200 OK\r\nserver: lunetoile\r\ndate: %s\r\ncontent-type: text/html; charset=UTF-8\r\ncontent-length: %d\r\n\r\n",
  "Lundi 35 Mai",#buffer))
  client:send( buffer)

end


local function get( client, path)
  local special = { ["/whoami"] = whoami,
                    ["/quit"] = quit ,
                    ["/"] = function() return read_file("index.html") end }
  local buffer = ""

  if special[path] then
    buffer = special[path]( client)
  else
    local header = read_header( client) -- TODO header : no use for the moment
    buffer = read_file( urldecode(path))
    -- get file
  end
  serve_client( client, buffer)
end

local function call_command( client, command, path)
  local command_list = { GET = get }
  if command_list[command] then
    command_list[command]( client, path)
  else
    print("[error] Unknown command : client ",client,"asked ",command)
  end
end

local function mainloop()
  while is_running do
    client = server.accept( server)
    
    -- first line : contains command, path, protocol
    local line = client:receive()
    local command,path,proto = line:match("([A-Z]+)%s+(%S+)%s+(HTTP.+)")
    print (string.format('command:"%s" path:"%s" proto:"%s"',command,path,proto))

    -- TODO FIXME : captures the paramaters before removing them !
    path = string.match( path,"[^?]+") -- remove parameters from URL
    call_command( client, command, path)

    client:close()
  end
end

init()
mainloop()

