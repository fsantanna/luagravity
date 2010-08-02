local gvt = require 'luagravity'
local env = require 'luagravity.env.simple'

local a = 0

local A = gvt.loop(env.nextEvent,
    function ()
        a = a + 1
        gvt.await(0)
        a = a + 1
    end)

assert(a == 2)

local B = gvt.loop(env.nextEvent,
    function ()
        a = a + 1
        gvt.await(0)
        a = a + 1
    end)

assert(a == 4)

local b, c = 0, 0

local B = gvt.start(
    function ()
        b = b + 1
        gvt.await('x')
        b = b + 1
    end)

local C = gvt.start(
    function ()
        c = c + 1
        gvt.await('x')
        c = c + 1
    end)

assert(b == 1)
assert(c == 1)

gvt.step(B, 'x')
assert(b == 2)
assert(c == 1)

gvt.step(C, 'x')
assert(b == 2)
assert(c == 2)

print '===> OK'
