-- Testing cycles

local gvt = require 'luagravity'
local env = require 'luagravity.env.simple'

gvt.loop(env.nextEvent,
    function ()
        -- Testing timer accuracy
        local tot = 0
        local f = gvt.create(
            function ()
                tot = tot + 1
                gvt.await(30)
            end)
        gvt.link(f, f)
        gvt.spawn(f)
        gvt.await(100)
        assert(tot == 4, tot)

        -- tight cycle
        local a = gvt.create(function()end, {zero=true})
        local b = gvt.create(function()end, {zero=true})
        gvt.link(a, b)
        local ret, msg = pcall(gvt.link, b, a)
        assert((not ret) and string.match(msg, 'tight cycle detected'))
    end)

print '===> OK'
