#!/usr/bin/env lua
-- $$DATE$$ : mer. 19 févr. 2020 18:24:04

local lfs = require"lfs"
local socket = require"socket"
local client,server
local clients_sessions = {}
local server_name = "lunetoile"
local session_delay = 3600 --length of client session (in seconds)
local is_running = true
local root, root_static
local timeout = 1/100 --10ms

local is_localhost -- will be defined: is_localhost = function( …) …

local function log_client(client,msg)
  local stack_level = 2
  --local stack = debug.traceback(nil,2) -- skip current address (level 1)
  local caller = debug.getinfo( stack_level,'n').name
  if (caller == '?') then
    -- it was called from a function referenced in a table, give line instead
    caller = "line: " .. debug.getinfo( stack_level).currentline
  end
  print(string.format("[%s] %s : %s", caller, client:getsockname(), msg))
end

local function init()
  -- TODO config file ! with root, root_static, port number, server name, session delay
  root = arg[1] and string.gsub(arg[1],"([^%/])$","%1/") or "./"
  root_static = arg[2] and string.gsub(arg[2],"([^%/])$","%1/") or "./"
  if root == root_static then
    print("[ERROR] root and root_static cannot be the same!")
    os.exit(1)
  end
  local port = arg[3] or 8088
  print("Running with ".. _VERSION)
  print(string.format("root dir : %s\nstatic root dir: %s\nlisten on: %d\n",
                      root, root_static, port))
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


local function dir( path)
  local directory = {}
  local check = io.open( path,"r")
  if check then
    for f in lfs.dir( path) do
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
  local path_argument = args["path"] or ""
  --if path_argument then
    -- remove double dots (..) and ending slash (optional)
    path_argument = string.gsub( path_argument, "%.[%.]+[/$]?", "")
  --end
  local absolute_path = root_static .. path_argument
  log_client( client, "dir( " .. absolute_path)
  if is_localhost( client) then
    directory = dir( absolute_path)
  else
    log_client( client," attempted to list " .. absolute_path)
  end

  local buffer = { "<html><body>" }
  if directory then
    for i = 2,#directory do
      local name_with_path = absolute_path .. "/" .. directory[i]
      if lfs.attributes( name_with_path, "mode") == "directory" then
        if directory[i] == ".." then
          --local previous_dir = string.match(path_argument,"(.*)/.+/%.%.[/]?") or "./" --root
          -- we can either go upper in the dir tree, or we are already at the top (./) .
          print("absolute_path",absolute_path)
          local previous_dir = string.match(path_argument,"(.*)/.+[/]?") or ""
          directory[i] = string.format("<a href=/list?path=%s>[..]</a>", previous_dir)
        else
          directory[i] = string.format("<a href=/list?path=%s>[%s]</a>", path_argument .. "/" .. directory[i], directory[i])
        end
      else -- ce n'est pas un directory
        directory[i] = string.format('<a href=/download/%s?path=%s>%s</a>',
                        directory[i],path_argument .. "/" .. directory[i], directory[i])
      end
      table.insert( buffer, directory[i])
    end
  else
    table.insert( buffer, "What are you doing here ?")
    log_client( client, "failed to list " .. absolute_path)
  end
  table.insert( buffer, "<br><a href=\"/\"><h3>Go back home</h3></a></body></html>")
  return table.concat( buffer,"<br>")
end


local function read_header( client)
  local header = {}
  repeat
    line = client:receive() or ""
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
  end
  if buffer == nil then
    buffer = "<html><body><h1>404 : Unavailable " .. filename .. "</h1><br><a href=\"/\"><h3>Go back home</h3></a></body></html>"
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


local function create_session( client)
  local session_id = nil
  repeat
    session_id = tostring( os.clock() + math.random(2^20))
  until clients_sessions[session_id] == nil
  local now = os.time()
  -- date must be given in UTC format (hence the '!' at beginning of format)
  local expire = os.date("!%a, %d %b %Y %H:%M:%S GMT", now + session_delay)
  clients_sessions[session_id] = { id=session_id, ip=client:getsockname(), created=now, expire=expire, logged=false }
  print("creating session",session_id)
  for i,v in pairs(clients_sessions) do print ("create_session",i,v) end

  return clients_sessions[session_id]
end


local function get_session( client)
  local header = read_header( client)
  --for i,v in pairs(header) do print("header",i,v) end
  local cookie = header["Cookie"] or ""
  local session_id = string.match( cookie, "id=([0-9%.]+)") -- get the session id from «Cookie» header
  print("searching session ", session_id)
  for i,v in pairs(clients_sessions) do print ("get_session",i,v) end
  local session = clients_sessions[session_id]
  print("session", session)
  if session == nil or session.created >= os.time() + session_delay then
    session = create_session( client)
  end

  return session
end


local function serve_header_to_client( client, args, contentlength, contenttype)
--[[
  Cookies are either "session cookies" (forgotten when session is over)
  or the cookies aren't session cookies they have expiration dates.
  Cookies are set to the client with the Set-Cookie: header and are sent to servers with the Cookie: header.
  https://developer.mozilla.org/fr/docs/Web/HTTP/Headers/Set-Cookie
--]]
--  local session = clients_sessions[ get_session( client, args)]
  local session = get_session( client, args)
  local cookie = string.format( "Set-Cookie: id=%s; Expires=%s", session.id, session.expire)

  -- we need \r\n\r\n to finish the header part
  -- TODO FIXME : returns real date, and not 35 mai
  client:send( string.format("HTTP/1.0 200 OK\r\nserver: %s\r\ndate: %s\r\ncontent-type: %s; charset=UTF-8\r\ncontent-length: %d\r\n%s\r\n\r\n",
  server_name, "Lundi 35 Mai", contenttype, contentlength, cookie or ""))

end


local function download( client, args)
  local path = args["path"] or "invalid"
  local filename = root_static .. path
  local filesize = lfs.attributes( filename, "size") or 0
  print("[download] file size:",filesize)

  if (filesize > 0) then
    -- TODO FIXME for the moment, the header is downloaded …
    serve_header_to_client( client, args, filesize, "application/octet-stream")
  end

  return filesize

end


local function get( client, path, args)
  local special = { ["/whoami"] = whoami,
                    ["/quit"] = quit ,
                    ["/list"] = list_dir,
                    ["/"] = function() return read_file("index.html") end }
  local buffer = ""
  local filesize = 0 -- if download asked
  -- /download/ has to be treat apart
  if string.match( path,"/download/") then
    filesize = download( client, args)
    if filesize == 0 then buffer = special["/"]() end -- if illegal download, returns index.html
  elseif special[path] then
    buffer = special[path]( client, args)
  else
    local header = read_header( client) -- TODO header : no use for the moment
    buffer = read_file( urldecode(path))
    -- get file
  end
  if buffer then
    serve_header_to_client( client, args, #buffer, "text/html")
    client:send( buffer)
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
    command = command or "no command (nil)"
    log_client( client, "Unknown command : " .. command)
  end
end


local function check_clients_sessions()

end


local tempo = 0

local function delay()
  local sleep_value = 0.05
  local tempo_limit = 5/sleep_value -- value for 5 seconds
  tempo=tempo+1
  if tempo >= tempo_limit then
    tempo = 0
    check_clients_sessions()
  else
    socket.sleep( sleep_value)
  end
end

is_localhost = function( client) --as it's prototyped, must be defined like this
  local is_local = false
  -- getsockname returns ip,port,proto
  local ip = client:getsockname()
  if ip == "127.0.0.1" then
    is_local = true
  else
    log_client( client, " tried to access localhost only feature.")
  end

  return is_local
end


local function mainloop()
  repeat

    -- called at about 100 Hz with no delay (with sleep 0.05, about 20Hz)
    client = server.accept( server)
    if client then

      -- first line : contains command, path, protocol
      local line = client:receive()
      if line then
        local command,url,proto = line:match("([A-Z]+)%s+(%S+)%s+(HTTP.+)")
        print (string.format('command:"%s" url:"%s" proto:"%s"',command,url,proto))
        call_command( client, command, url)
      else
        log_client( client, "sending nil requests.")
      end

      client:close()

    else
      delay()
    end

  until is_running == false
end

local function main()
  init()
  mainloop()
end


main()
