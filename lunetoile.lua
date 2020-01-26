#!/usr/bin/env lua
-- $$DATE$$ : Sun 26 Jan 2020 10:51:39AM

local lfs = require"lfs"
local socket = require"socket"
local client,server
local is_running = true
local root
local timeout = 1/100 --10ms

local function init()
  root = arg[1] and tring.gsub(arg[1],"([^%/])$","%1/") or "./"
  local port = arg[2] or 8088
  print("Running with ".. _VERSION)
  print(string.format("root dir : %s\nlisten on: %d\n", root, port))
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

local function is_localhost( client)
  local is_local = false
  -- getsockname returns ip,port,proto
  local ip = client:getsockname()
  if ip == "127.0.0.1" then is_local = true end

  return is_local
end

local function dir( local_path)
  local directory = {}
  -- TODO: tester ouverture de répertoire « Permission Denied »
  local check = io.open( local_path,"r")
  if check then
    for f in lfs.dir( local_path) do
      table.insert( directory, f)
    end
    io.close(check)
    table.sort( directory)
  else
    directory = nil
  end

  return directory
end

local function list_dir( client, args)
  local directory = nil
  --local relative_local_path = string.match( args, ".*path=(.*)[%/%&]?.*") or "."
  local relative_local_path = args["path"]
  if relative_local_path then
    -- remove ending slash (optional)  and dots
    relative_local_path = string.gsub(relative_local_path,"%.[%.]+[/$]?","")
  else
    relative_local_path = "."
  end
  local local_path = root .. relative_local_path
  print("demande: ",local_path)
  if is_localhost( client) then
    directory = dir( local_path)
  end

  local buffer = "<html><body>"
  if directory then
    for i = 2,#directory do
      local name_with_path = relative_local_path .. "/" .. directory[i]
      if lfs.attributes( name_with_path, "mode") == "directory" then
        if directory[i] == ".." then
          --local previous_dir = string.match(relative_local_path,"(.*)/.+/%.%.[/]?") or "./" --root
          local previous_dir = string.match(relative_local_path,"(.*)/.+[/]?") or "./" --root
          print(relative_local_path, previous_dir)
          directory[i] = string.format("<a href=/list?path=%s>[..]</a>", previous_dir)
        else
          directory[i] = string.format("<a href=/list?path=%s>[%s]</a>", name_with_path, directory[i])
          --directory[i] = string.format("<a href=/list?path=%s>%s</a>", directory[i], directory[i])
        end
      else -- ce n'est pas un directory
        directory[i] = string.format('<a href=/download/%s?path=%s>%s</a>',
                        directory[i],name_with_path, directory[i])
      end
      -- FIXME : utiliser une table plutot que cette horrible concaténation
      buffer = buffer .. directory[i] .. "<br>"
    end
  else
    buffer = buffer .. "What are you doing here ?<br>"
  end
  buffer = buffer .. "<br><a href=\"/\"><h3>Go back home</h3></a></body></html>"
  return buffer
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
  --local cookie = "Set-Cookie: " .. args --just a quick test (FIXME faire une fonction d'extraction)
  local cookie = args["Set-Cookie"] and "Set-Cookie: " .. args["Set-Cookie"] or ""

  -- we need \r\n\r\n to finish the header part
  client:send( string.format("HTTP/1.0 200 OK\r\nserver: lunetoile\r\ndate: %s\r\ncontent-type: text/html; charset=UTF-8\r\ncontent-length: %d\r\n%s\r\n\r\n",
  "Lundi 35 Mai",#buffer, cookie or ""))
  client:send( buffer)

end

-- factoriser avec serve_client()
local function download( client, args)
  for k,v in pairs(args) do print(k,v) end
  local filename = args["path"]
  local filesize = lfs.attributes( filename, "size") or 0
  print("taille",filesize)

  local cookie = args["Set-Cookie"] and "Set-Cookie: " .. args["Set-Cookie"] or ""

  client:send( string.format("HTTP/1.0 200 OK\r\nserver: lunetoile\r\ndate: %s\r\ncontent-type: application/octet-stream; charset=UTF-8\r\ncontent-length: %d\r\n%s\r\n\r\n",
  "Lundi 35 Mai", filesize, cookie))


end


local function get( client, path, args)
  local special = { ["/whoami"] = whoami,
                    ["/quit"] = quit ,
                    ["/list"] = list_dir,
                    ["/"] = function() return read_file("index.html") end }
  local buffer = ""
  -- /download/ has to be treat separatly
  if string.match( path,"/download/") then
    download( client, args)
  elseif special[path] then
    buffer = special[path]( client, args)
  else
    local header = read_header( client) -- TODO header : no use for the moment
    buffer = read_file( urldecode(path))
    -- get file
  end
  if buffer then
    serve_client( client, buffer, args)
  end
end

local function call_command( client, command, url)
  local command_list = { GET = get }
  if command_list[command] then
    -- extracting first part of url (path) and the optionnal arguments after '?'
    local path,str_args = string.match( url,"([^%?]*)%??(.*)")
    -- put the arguments in a table
    local args = {}
    for k,v in string.gmatch( str_args, "([^=]+)=([^&]+)") do args[k] = v end
    -- for k,v in pairs(args) do print("args",k,v) end
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

