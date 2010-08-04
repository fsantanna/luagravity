-- Testing gvt.call

local gvt = require 'luagravity'
local env = require 'luagravity.env.simple'

gvt.loop(env.nextEvent,
    function ()
        local tot = 0
        local r = gvt.create(function() gvt.await(0.2) end)
        local a = gvt.create(function() tot=tot+1 gvt.await(0) end)
        local b = gvt.create(function() tot=tot+1 gvt.await(0) end)
        local c = gvt.create(function() tot=tot+1 gvt.await(0) end)
        local d = gvt.create(function() tot=tot+1 gvt.await(0) end)
        local e = gvt.create(function() tot=tot+1 gvt.await(0) end)
        local f = gvt.create(function() tot=tot+1 gvt.await(0) end)
        local g = gvt.create(function() tot=tot+1 gvt.await(0) end)
        local h = gvt.create(function() tot=tot+1 gvt.await(0) end)
        local i = gvt.create(function() tot=tot+1 gvt.await(0) end)
        gvt.link(r, a)
        gvt.link(r, b)
        gvt.link(r, c)
        gvt.link(r, d)
        gvt.link(r, e)
        gvt.link(r, f)
        gvt.link(r, g)
        gvt.link(r, h)
        gvt.link(r, i)
        gvt.call(r)
        assert(tot == 9, tot)
    end)

print '===> OK'
