local gvt = require 'luagravity'
local env = require 'luagravity.env.simple'

local _start, _stop = 0, 0

local f_start = function(v)
    v = v or 0
    _start = _start + 1
    return v + 1
end

start = gvt.create('start', nil, true, f_start)

local f_stop = function(v)
    v = v or 0
    _stop = _stop + 1
    return v + 1
end

stop = gvt.create('stop', nil, true, f_stop)

gvt.loop(
    function ()
        gvt.setEnvironment(env)

        -- Reacoes
        gvt.call(start)
        gvt.call(stop)
        gvt.call(start)
        gvt.call(stop)
        assert((_start==2) and (_stop==2))

        local rm = gvt.link(start, stop)

        gvt.call(start)
        assert((_start==3) and (_stop==3), _stop)

        -- Quebra de elo "explicita"
        gvt.unlink(start, stop)
        gvt.call(start)
        assert((_start==4) and (_stop==3))

        gvt.link(start, stop)
        gvt.link(stop, function (v)
            assert(v == 3, v)
        end)
        gvt.call(start, 1)
        assert((_start==5) and (_stop==4))

        -- STRINGS
        gvt.link('start', f_start)
        gvt.link('stop',  f_stop)
        gvt.post('start', 1)
        gvt.post('stop', 1)
        gvt.post('start', 1)
        gvt.post('stop', 1)
        assert((_start==7) and (_stop==6))

    end)

print '===> OK'
