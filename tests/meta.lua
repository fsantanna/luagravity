local gvt  = require 'luagravity'
local expr = require 'luagravity.expr'
local meta = require 'luagravity.meta'
local env = require 'luagravity.env.simple'

local type, assert, print = type, assert, print

gvt.loop(env.nextEvent, meta.apply(
    function ()

        -- REACTORS

        local tot = 1

        function f1   (v) end
        function _f2  (v) tot=tot+1 end
        function __f3 (v) await(_f4) tot=tot*2 end
        function _f4  (v) tot=tot+1 end

        assert(type(f1) == 'function')
        assert(_f2.zero == true)
        assert(__f3.zero == false)

        link(_f2, __f3)
        _f2()
        assert(tot == 2)
        _f4()
        assert(tot == 6)
        spawn(__f3)
        await(0)
        _f4()
        assert(tot == 14, tot)
        unlink(_f2, __f3)
        _f2()
        assert(tot == 15)

        -- BEHAVIORS

        _a = 1
        _b = 2
        _c = _a + _b
        assert(_c() == 3)
        _a = 3
        _b = 4
        assert(_c() == 7)

        _v1 = 1
        _v2 = 2
        _v2 = _v1
        _v1 = 3
        assert((_v1() == 3) and (_v2() == 3))

        -- LIFT

        local fadd = function (a, b) return a+b end
        local ladd = L(fadd)
        _v3 = ladd(_v1, _v2)
        _v4 = ladd(_v1, 2)
        _v1 = 5
        assert((_v1() == 5) and (_v2() == 5) and
               (_v3() == 10) and (_v4() ==7))

        local fnear = function (cur, exp)
            return assert((cur >= exp*0.90) and (cur <= exp*1.10),
                          exp..' vs '..cur)
        end
        local lnear = L(fnear)

        local fequal = function (v1, v2)
            return assert(v1 == v2)
        end
        local lequal = L(fequal)

        local flt = function (v1, v2)
            return assert(v1 < v2)
        end
        local llt = L(flt)

        -- IDX
        --[[
        do
            _k1 = 1
            local t1 = { 1, 2 }
            local _v1 = IDX(t1, _k1)
            assert(_v1() == 1)
            _k1 = 2
            assert(_v1() == 2)

            _k2 = 1
            local t2 = { 1, _v1 }
            local _v2 = IDX(t2, _k2)
            assert(_v2() == 1)
            _k2 = 2
            assert(_v2()() == 2)
            _k1 = 1
            assert(_v2()() == 1)
        end
        ]]

        -- GLITCHES

        _x = 1
        local xx
        local x1 = _x
        for i=1, 50 do
            local x2 = x1 + 1
            llt(x1, x2)
            x1 = x2
            xx = x2
        end
        for i=1, 50 do
            _x = i
        end
        assert(xx() == 100, xx())

        -- VAR

        _v5 = 1
        _v6 = 2
        _v6 = _v5
        assert(_v6() == _v5())
        _v5 = _v4
        assert(_v5() == _v4() and _v6() == 7)
        _v1 = 10
        assert(_v5() == _v4() and _v6() == 12)

        local fadd = function (a, b) return a+b end
        local ladd = L(fadd)
        _v3 = ladd(_v1, _v2)
        local _v4 = ladd(_v1, 2)
        _v1 = 5
        assert((_v1() == 5) and (_v2() == 5) and
               (_v3() == 10) and (_v4() ==7))

        local _v5 = expr.var(1)
        local _v6 = expr.var(2)
        _v6:attr(_v5)
        assert(_v6() == _v5())
        _v5:attr(_v4)
        assert(_v5() == _v4() and _v6() == 7)
        _v1 = 10
        assert(_v5() == _v4() and _v6() == 12)

        -- INTEGRAL / DERIVATIVE

        local s  = S(3)
        local ss = S(3)
        lequal(s, ss)
        await(500)
        fnear(s(), 1500)
        local s1 = s + 1
        llt(s, s1)
        local d1 = D(s1)
        local d2 = D(10000)
        await(100) -- para ter derivada
        await(100) -- para ter derivada
        await(100) -- para ter derivada
        lnear(d1, 3)
        lequal(d2, 0)
        await(1200)
        fnear(s(), 6000)

        -- OO
        local t = meta.new({}, nil, true)
        t.v = 3
        function t:_inc (v)
            self.v = self.v + (v or 1)
        end
        function t:_double ()
            self.v = self.v * 2
        end
        link(t._inc, t._double)
        t:_inc()
        assert(t.v == 8)
        t._inc(2)
        assert(t.v == 20)

        local _s = S(10)
        local _d = D(_s)
        await(5000)
        await(0)
        assert(_s() >= 50000 and _s() <= 51000)
        assert(_d() == 10)

        -- COND
 
        local lt = expr.lift(function(a,b) return a < b end)
        local x = false
        local s = S(1)
        gvt.spawn(function()
            gvt.await(500)
            x = true
        end)
        gvt.await(cond(lt(1000,s)))
        assert(x)

        -- ACCUM
        _a = 1
        _b = 2
        _c = 3
        local t = { _a, _b, _c }
        _all = 0
        for i, _v in ipairs(t) do
            _all = _all.src + _v
        end
        assert(_all() == 6)
        _a = 2
        _b = 4
        assert(_all() == 9)
    end))

print '===> OK'
