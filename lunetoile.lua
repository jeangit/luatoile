#!/usr/bin/env lua
-- $$DATE$$ : lun. 20 janv. 2020 14:14:34

local socket = require"socket"
local client,server
local is_running = true
local root = "./"
local timeout = 1/100 --10ms

local function init()
  print("Running with ".. _VERSION)
  local root = arg[1] or "index.html"
  local port = arg[2] or 8088
  server = socket.bind( "0.0.0.0", 8088)
  if not server:settimeout( timeout) then
    print("[ERROR] init()->server:settimeout")
  end
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


local function serve_client( client, buffer, args)
--[[
  Cookies are either "session cookies" which typically are forgotten when the session is over which is often translated to equal when browser quits, or the cookies aren't session cookies they have expiration dates after which the client will throw them away.
--]]
-- Cookies are set to the client with the Set-Cookie: header and are sent to servers with the Cookie: header.
  local cookie = "Set-Cookie: " .. args --just a quick test (FIXME remove)


  client:send( string.format("HTTP/1.0 200 OK\r\nserver: lunetoile\r\ndate: %s\r\ncontent-type: text/html; charset=UTF-8\r\ncontent-length: %d\r\n%s\r\n",
  "Lundi 35 Mai",#buffer, cookie or ""))
  client:send( buffer)

end


local function get( client, path, args)
  local special = { ["/whoami"] = whoami,
                    ["/quit"] = quit ,
                    ["/"] = function() return read_file("index.html") end }
  local buffer = ""

  if special[path] then
    buffer = special[path]( client, args)
  else
    local header = read_header( client) -- TODO header : no use for the moment
    buffer = read_file( urldecode(path))
    -- get file
  end
  serve_client( client, buffer, args)
end

local function call_command( client, command, url)
  local command_list = { GET = get }
  if command_list[command] then
    local path,args = string.match( url,"(.*)%?(.*)")
    command_list[command]( client, path, args)
  else
    print("[error] Unknown command : client ",client,"asked ",command)
  end
end

local function mainloop()
  while is_running do
    client = server.accept( server)
    if client then

      -- first line : contains command, path, protocol
      local line = client:receive()
      local command,url,proto = line:match("([A-Z]+)%s+(%S+)%s+(HTTP.+)")
      print (string.format('command:"%s" url:"%s" proto:"%s"',command,url,proto))

      call_command( client, command, url)

      client:close()
    end
  end
end

init()
mainloop()

