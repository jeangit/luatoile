# :last_quarter_moon_with_face: lunetoile :star:

## A web server written in Lua.

There are two goals for this project.

1. Development with http frameworks , which need http server.
1. Packaging of projects using http frameworks, for local use on desktop.

## How to
### deps needed

1. Obviously, `lua`. Tested with 5.3 and 5.2 flavors, not with `luajit` (but should work).
1. `luasocket`. You can install it with `luarocks` package manager, or directly from your distribution (or from the sources).

It is planned to provide an all-in-one distribution for packaging projects, but for the moment, you have to install yourself tho deps.

### launch
Launch `lunetoile.lua` and it will serve you well (even so, read [the alternatives](#alternatives-in-lua))

### tools
There are some tools available, you call them via the URL.

name | action | localhost only
-----|--------|---------------
`/quit`|end the server| yes
`/whoami`|returns client's header| no

## :construction: TODO :construction:
- [x] serving files to clients.
- [ ] parallelized clients.
- [ ] cookies. :cookie:
- [ ] config file.
- [ ] https.<sub>with localhost, seriously ?!</sub>
- [x] TODO list


## Alternatives in Lua
This project is for __private use__, or at most, not farthest than your LAN.

Use these projects instead, if you plan to serve to the whole internet (you know :trollface: :biohazard: :radioactive: …).

name | link
-----|------
luahttp|https://github.com/daurnimator/lua-http
openresty|http://openresty.org/en/

## Don't read this
__lunetoile__ is a pseudo-word made with two french words : *lune* and *étoile*.

You can translate it as *moonweb* (moon :arrow_right: lua/lune , web :arrow_right: toile).

But in french, it means also *moonstar*, with the shared `'e'` (lun(e) :arrow_right: moon , (e)toile :arrow_right: star).

