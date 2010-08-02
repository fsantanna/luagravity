-- Reacoes Duradouras
-- Propagacao .start
-- Timer
-- Await

local gvt = require 'luagravity'
local env = require 'luagravity.env.simple'

-- testing if `s_f1()` call is synchronous
local _ret

f1 = gvt.create(function()
    gvt.await(10)
    _ret = true
end)

f = gvt.create(function()end)

gvt.loop(env.nextEvent,
    function ()
        gvt.spawn(function()
            gvt.call(f1)
            assert(_ret == true)
        end)

        -- testing if one call to `f` awakes exactly one `gvt.await(f)`
        local _fs = 0
        gvt.spawn(function()
            gvt.await(f)
            _fs = _fs + 1
            gvt.await(f)
            _fs = _fs + 1
            gvt.await(f)
            _fs = _fs + 1
        end)
        gvt.await(0)
        gvt.call(f)
        gvt.call(f)
        assert(_fs == 2, _fs)

        -- testing reaction nesting
        local _ret = {}
        gvt.spawn(function()
            -- it is finished before `_ret[1]=true`
            local r = gvt.spawn(function()
                gvt.await(10)
                _ret[1] = true
            end)

            -- it is not finished
            gvt.spawn(function()
                gvt.await(10)
                _ret[2] = true
            end)

            gvt.await(0)
            gvt.kill(r)

        end)
        gvt.await(20)
        assert(not _ret[1])
        assert(_ret[2])
    end)

-- testing inner reaction terminating outer reaction
--[[
g = function () end
gvt.spawn(function()
    gvt.spawn(function()
        gvt.await(0)
        g()
gvt.await(0)
error'oi'
    end)
    gvt.await(g)
end)
gvt.await(0.1)
]]

print '===> OK'
