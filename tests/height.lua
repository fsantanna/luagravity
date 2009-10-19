local gvt = require 'luagravity'
local ldirectfb = require 'luagravity.env.ldirectfb'

gvt.setEnvironment(ldirectfb)
gvt.loop(
    function ()
        local zero = gvt.create('zero',nil,true,function()end)
        local ret, msg = pcall(gvt.link, zero, zero)
        assert((not ret) and string.match(msg, 'tight cycle detected'))

        local tot = 0
        local a = gvt.create('a',nil,true,function() return 'o' end)
        local b = gvt.create('b',nil,true,function() return 22 end)
        local c = gvt.create('c',nil,true,
            function (p1)
                -- TODO: se der erro, testar o inverso (OU)
                assert(p1 == 22)
                tot = tot + 1
            end)
        gvt.link(a, b)
        gvt.link(a, c)
        gvt.link(b, c)
        gvt.call(a)
        assert(tot == 1)

        local x = gvt.create('x',nil,true,function () return nil end)
        local y = gvt.create('y',nil,true,function () return false end)
        gvt.link(a, x)
        gvt.link(a, y)
        local d = gvt.create('d',nil,false,
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
        local b2 = gvt.create('b2',nil,true,function()end)
        local b1 = gvt.create('b1',nil,false,function() gvt.await(b2) end)
        gvt.spawn(b1)
        gvt.link(b1, b1)
        gvt.await(0)
        gvt.call(b2)
        -- bb2 --> s_bb1 ==> s_bb1
        local bb2 = gvt.create('bb2',nil,true,function()end)
        local bb1 = gvt.create('bb1',nil,false,function() gvt.await(bb2) end)
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
        local x1 = gvt.create('x1',nil,true,function()end)
        local x2 = gvt.create('x2',nil,true,function()end)
        local z1 = gvt.create('z1',nil,false,function() gvt.await(x1) t1=t1+1 end)
        local z2 = gvt.create('z2',nil,false,function() gvt.await(x2) t2=t2+1 end)
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
