local gvt = require 'luagravity'
local expr = require 'luagravity.expr'
local directfb = require 'luagravity.env.directfb'

local fnear = function (cur, exp)
	return assert((cur >= exp*0.90) and (cur <= exp*1.10), cur)
end
local lnear = expr.lift(fnear)

local fequal = function (v1, v2)
    return assert(v1 == v2)
end
local lequal = expr.lift(fequal)

local flt = function (v1, v2)
    return assert(v1 < v2)
end
local llt = expr.lift(flt)

gvt.setEnvironment(directfb)
gvt.loop(
    function ()
        local v1 = expr.new(1)
        local v2 = expr.new(2)
        gvt.link(v1._set, v2._set)
        gvt.call(v1._set, 3)
        assert((v1.value == 3) and (v2.value == 3))

        local tot = 0
        local a = expr.new(1)
        gvt.link(a._set, function () tot = tot+1 end)
        assert((tot == 0) and (a.value == 1), tot)
        gvt.call(a._set, 2)
        gvt.call(a._set, 2)  -- CANCEL
        assert(a.value == 2)
        assert(tot == 1, tot)

        local b = expr.new(0)
        gvt.link(b._set, function () tot = tot+1 end)
        assert(tot == 1)
        local clr = gvt.link(a._set, b._set)
        gvt.call(a._set, 3)
        gvt.call(a._set, 3)  -- CANCEL
        assert(tot == 3, tot)
        assert((a.value==3) and (b.value==3))
        clr()
        gvt.call(a._set, 4)
        assert(tot == 4)
        assert((a.value==4) and (b.value==3))

        -- LIFT

        local fadd = function (a, b) return a+b end
        local ladd = expr.lift(fadd)
        local v3 = ladd(v1, v2)
        local v4 = ladd(v1, 2)
        gvt.call(v1._set, 5)
        assert((v1.value == 5) and (v2.value == 5) and
               (v3.value == 10) and (v4.value ==7))

        -- GLITCHES

        local x = expr.var(1)
        local xx
        local x1 = x
        for i=1, 50 do
            local x2 = ladd(x1, 1)
            llt(x1, x2)
            x1 = x2
            xx = x2
        end
        for i=1, 50 do
            gvt.call(x._set, i)
        end
        assert(xx.value == 100, xx.value)

        -- VAR

        local v5 = expr.var(1)
        local v6 = expr.var(2)
        v6:attr(v5)
        assert(v6.value == v5.value)
        v5:attr(v4)
        assert(v5.value == v4.value and v6.value == 7)
        gvt.call(v1._set, 10)
        assert(v5.value == v4.value and v6.value == 12)

        local fadd = function (a, b) return a+b end
        local ladd = expr.lift(fadd)
        local v3 = ladd(v1, v2)
        local v4 = ladd(v1, 2)
        gvt.call(v1._set, 5)
        assert((v1.value == 5) and (v2.value == 5) and
               (v3.value == 10) and (v4.value ==7))

        local v5 = expr.var(1)
        local v6 = expr.var(2)
        v6:attr(v5)
        assert(v6.value == v5.value)
        v5:attr(v4)
        assert(v5.value == v4.value and v6.value == 7)
        gvt.call(v1._set, 10)
        assert(v5.value == v4.value and v6.value == 12)

        -- INTEGRAL / DERIVATIVE

        local s  = expr.integral(3)
        local ss = expr.integral(3)
        lequal(s, ss)
        gvt.await(0.5)
        fnear(s.value, 1.5)
        local s1 = ladd(s, 1)
        llt(s, s1)
        local d1 = expr.derivative(s1)
        local d2 = expr.derivative(10000)
        gvt.await(0) -- para ter derivada
        gvt.await(0) -- para ter derivada
        gvt.await(0) -- para ter derivada
        lnear(d1, 3)
        lequal(d2, 0)
        gvt.await(1.5)
        fnear(s.value, 6)

        -- DELAY
        local a = expr.new(0)
        local d = expr.delay(a, 0.25)
        local b = expr.var()
        b:attr(d)
        gvt.await(0.1)
        gvt.call(a._set, 1)
        gvt.call(a._set, 2)
        assert(d.value == nil)
        assert(b.value == nil)
        gvt.await(0.2)
        assert(d.value == 0)
        assert(b.value == 0)
        gvt.await(0.1)
        assert(d.value == 2)
        assert(b.value == 2)

    end)

print '===> OK'
