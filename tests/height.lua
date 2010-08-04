local gvt = require 'luagravity'
local env = require 'luagravity.env.simple'

gvt.loop(env.nextEvent,
    function ()
        local zero = gvt.create(function()end, {zero=true})
        local ret, msg = pcall(gvt.link, zero, zero)
        assert((not ret) and string.match(msg, 'tight cycle detected'))

        local tot = 0
        local a = gvt.create(function() return 'o' end, {zero=true})
        local b = gvt.create(function() return 22 end, {zero=true})
        local c = gvt.create(
            function (p1)
                -- TODO: se der erro, testar o inverso (OU)
                assert(p1 == 22)
                tot = tot + 1
            end, {zero=true})
        gvt.link(a, b)
        gvt.link(a, c)
        gvt.link(b, c)
        gvt.call(a)
        assert(tot == 1)

        local x = gvt.create(function () return nil end, {zero=true})
        local y = gvt.create(function () return false end, {zero=true})
        gvt.link(a, x)
        gvt.link(a, y)
        local d = gvt.create(
            function ()
                local ret = gvt.await(x, y)
                assert(ret==nil or ret==false)
            end)
        gvt.spawn(d)
        gvt.await(0)
        gvt.call(a)

        --[[
        -- a1 --> s_a2 ==> a1
        local a1 = gvt.create('a1',nil,true,function()end)
        local a2 = gvt.create('a2',nil,false,function() gvt.await(a1) end)
        gvt.spawn(a2)
        gvt.await(0)
        local ret, msg = pcall(gvt.link,a2, a1)
        assert((not ret) and string.match(msg, 'tight cycle detected'))
        ]]

        -- b2 --> s_b1 ==> s_b1
        local b2 = gvt.create(function()end, {zero=true})
        local b1 = gvt.create(function() gvt.await(b2) end)
        gvt.spawn(b1)
        gvt.link(b1, b1)
        gvt.await(0)
        gvt.call(b2)
        -- bb2 --> s_bb1 ==> s_bb1
        local bb2 = gvt.create(function()end, {zero=true})
        local bb1 = gvt.create(function() gvt.await(bb2) end)
        gvt.link(bb1, bb1) -- diferenca em relacao ao anterior
        gvt.spawn(bb1)       -- diferenca em relacao ao anterior
        gvt.await(0)
        gvt.call(bb2)

--[[
        local f1 = gvt.create('f1',nil,false,function() gvt.await(x) end)
        local f2 = gvt.create('f2',nil,true,function()end)
        gvt.link(f1, f2)
        assert(f1.heightOut < f2.heightIn)
        gvt.link(f2, f1)
        assert(f1.heightIn > f2.heightOut)
]]

        -- s_1 <-- x1
        -- s_2 <-- x2
        -- s_1 ==> s_2
        -- s_2 ==> x1
        local t1, t2 = 0, 0
        local x1 = gvt.create(function()end, {zero=true})
        local x2 = gvt.create(function()end, {zero=true})
        local z1 = gvt.create(function() gvt.await(x1) t1=t1+1 end)
        local z2 = gvt.create(function() gvt.await(x2) t2=t2+1 end)
        gvt.link(z1, z2)
        gvt.link(z2, x1)
        for i=0, 10 do
            gvt.spawn(z1)
            gvt.await(0)
            assert(t1 == i)
            assert(t2 == i)
            gvt.call(x1)
            assert(t1 == i+1)
            assert(t2 == i)
            gvt.call(x2)
            assert(t1 == i+1)
            assert(t2 == i+1)
        end
    end)

print '===> OK'
