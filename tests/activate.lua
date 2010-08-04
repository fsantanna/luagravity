-- Rectivate / Deactivate

local gvt = require 'luagravity'

local state

local app = gvt.start(function()
    state = 0
    gvt.await(10)
    state = 1
    gvt.await(10)
    state = 2
end)

assert(state == 0)

gvt.step(app, 'dt', 10)
gvt.step(app, 'dt', 0)
assert(state == 1)

gvt.deactivate(app)
gvt.step(app, 'dt', 10)
gvt.step(app, 'dt', 0)
assert(state == 1)
gvt.step(app, 'dt', 10)
gvt.step(app, 'dt', 0)
assert(state == 1)

gvt.reactivate(app)
gvt.step(app, 'dt', 10)
gvt.step(app, 'dt', 0)
assert(state == 2, state)

print '===> OK'
