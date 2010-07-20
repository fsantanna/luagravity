#!/usr/bin/env wsapi.cgi

-- RSP: Reactive Server Pages
-- * all going to client side (we agree)
-- * but still apps in server side
-- * Features:
--   - notion of application, rather than a collection of pages
--   - events instead of pages
--   - variables instead of XXX
--   - state, sequence
--   - reactive vars
-- * Hello World: _html = [[Hello World]]
-- * Hello World: _html=[[Hello]] await'next' _html=[[World]] await'next'
--                _html=[[Googbye World!]]
-- * Steps: _html=[[Im in step.._i]] while true await'next' _i=_i()+1 end
-- multiple pages with request life time vs single file with lasting
-- application

local gvt   = require 'luagravity'
local meta  = require 'luagravity.meta'

local req = require 'wsapi.request'
local res = require 'wsapi.response'

local headers = { ["Content-type"] = "text/html" }

local ID = 1
local SESSIONS = {}

return function (env)
    local req = req.new(env)
    local res = res.new(200, headers)

    local app, app_env
    local app_name, event = string.match(req.path_info, '/([^/]+)/?(.*)')
    local id = tonumber(req.cookies[app_name] or 0)

    if SESSIONS[id] then
        app, app_env, _name, _host = unpack(SESSIONS[id])
        assert(gvt.is(app))
        assert(_name == app_name)
        -- TODO: assert(_host == app_name)
    else
        id = ID ; ID = ID + 1
        app = meta.apply(assert(loadfile(app_name..'.lua')))
        app_env = getfenv(app)
        app = gvt.create(app_name, false, false, app)
        SESSIONS[id] = { app, app_env, app_name, TODO_HOST }
        res:set_cookie(app_name, id)
        gvt.start(app)
    end

    -- TODO: dangerous
    for var, v in pairs(req.GET) do
        if string.sub(v, 1, 1) == '!' then
            v = string.sub(v, 2)
        else
            v = "'"..v.."'"
        end
        local f = loadstring(var.."="..v)
        setfenv(f, app_env)
        f()
        --app_env[var] = v
    end
    if event ~= '' then
        gvt.step(app, event)
    end

    if app.state == 'ready' then
        res:delete_cookie(app_name)
        SESSIONS[id] = nil
    end

    --res:write('session '..id..'<p>'..app_env._html())
    res:write(app_env._html())
    return res:finish()
end
