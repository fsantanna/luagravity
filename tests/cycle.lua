-- Testing cycles

local gvt = require 'luagravity'
local ldirectfb = require 'luagravity.env.ldirectfb'

gvt.setEnvironment(ldirectfb)
gvt.loop(
    function ()
        -- Testing timer accuracy
        local tot = 0
        local f = gvt.create('f', nil, false,
            function ()
                tot = tot + 1
                gvt.await(0.3)
            end)
        gvt.link(f, f)
        gvt.spawn(f)
        gvt.await(1)

        -- tight cycle
        local a = gvt.create('a', nil, true, function()end)
        local b = gvt.create('b', nil, true, function()end)
        gvt.link(a, b)
        local ret, msg = pcall(gvt.link, b, a)
        assert((not ret) and string.match(msg, 'tight cycle detected'))

        assert(tot == 4, tot)
    end)

print '===> OK'
