-- Testing gvt.call

local gvt = require 'luagravity'
local directfb = require 'luagravity.env.directfb'

gvt.setEnvironment(directfb)
gvt.loop(
    function ()
        local tot = 0
        local r = gvt.create('r', nil, false, function() gvt.await(0.2) end)
        local a = gvt.create('a', nil, false, function() tot=tot+1 gvt.await(0) end)
        local b = gvt.create('b', nil, false, function() tot=tot+1 gvt.await(0) end)
        local c = gvt.create('c', nil, false, function() tot=tot+1 gvt.await(0) end)
        local d = gvt.create('d', nil, false, function() tot=tot+1 gvt.await(0) end)
        local e = gvt.create('e', nil, false, function() tot=tot+1 gvt.await(0) end)
        local f = gvt.create('f', nil, false, function() tot=tot+1 gvt.await(0) end)
        local g = gvt.create('g', nil, false, function() tot=tot+1 gvt.await(0) end)
        local h = gvt.create('h', nil, false, function() tot=tot+1 gvt.await(0) end)
        local i = gvt.create('i', nil, false, function() tot=tot+1 gvt.await(0) end)
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
