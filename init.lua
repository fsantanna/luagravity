--[[
-- TODO:
-- * Document meta.len/ipairs/pairs
-- * Rewrite the debugging system.
-- * Rewrite the topological order algorithm.
-- * Test rsrc as last parameter of triggers.
-- * await(p) -- em vez de -- p() / TESTES / DOC
-- * tirar o timer daqui
-- * gvt / rct.*
--]]

local _G = _G

local co_running, co_create, co_resume, co_yield, co_status =
      coroutine.running, coroutine.create,
      coroutine.resume, coroutine.yield, coroutine.status

local t_insert, t_remove = table.insert, table.remove

local error, assert, type, pairs, ipairs, setmetatable, getmetatable, tostring =
      error, assert, type, pairs, ipairs, setmetatable, getmetatable, tostring

module (...)

local SS = setmetatable({}, {__mode='k'})
S = nil

local trigger, schedule, run, finish, propagate, updateHeight,
      addEdge, createTimer, checkTimers, check_create

trigger = function (rsrc, edgeType, rdst, param)
    local st, ret
    if (edgeType == 'resume') or (edgeType == 'call') then
        assert(rdst.clearAwaiting)()
        rdst.clearAwaiting = nil
    end

    -- CALL
    S.stack[#S.stack+1] = rdst
    if rdst.zero then
        assert((not rdst.co) and (rdst.state=='ready'))
        rdst.state = 'running'
        if rdst.obj then
            ret = rdst.body(rdst.obj, param, rsrc)
        else
            ret = rdst.body(param, rsrc)
        end
    else
        if edgeType == 'start' then -- reacao duradoura: necessita de co-rotina
            assert((not rdst.co) and (rdst.state=='ready'), rdst.state)
            rdst.co = co_create(rdst.body)
        else -- resume
            assert((edgeType == 'resume') or (edgeType == 'call'), edgeType)
            assert(rdst.co and (rdst.state=='awaiting'))
        end
        assert(co_status(rdst.co) == 'suspended')
        rdst.state = 'running'
        st, ret = co_resume(rdst.co, param, rsrc)
--[[
TEMP: nao fazia sentido passar o obj no resume!
        if rdst.obj and (edgeType == 'start') then
            st, ret = co_resume(rdst.co, rdst.obj, param, rsrc)
        else
            st, ret = co_resume(rdst.co, param, rsrc)
        end
]]
        assert(st, ret)
    end
    S.stack[#S.stack] = nil

    -- not finished
    if (not rdst.zero) and (co_status(rdst.co) == 'suspended') then
        rdst.state = 'awaiting'

    -- finished
    else
        assert(rdst.zero or (co_status(rdst.co) == 'dead'))
        finish(rdst, ret) -- it will set rdst.state = 'ready'
    end

    return ret
end

-- TODO: criar ponteiro LAST e adicionar reacoes de tras pra frente
-- edgeType: 'start', 'resume'
schedule = function (rsrc, edgeType, rdst, param)
    -- optimize when height is not used
    --if not rdst.height then
        --trigger(edgeType, rdst, param)
        --return
    --end

    local cur = rdst.cEdgeType
    rdst.cParam = param
    rdst.cRsrc = rsrc

    if cur then
        assert(cur == edgeType)
    else
        rdst.cEdgeType = edgeType
        local height = rdst.height or 0
        local head, prev = S.torun, nil
        rdst.cHeight = height

        while head and (head.cHeight <= height) do
            prev = head
            head = head.cNext
        end
        if prev then
            prev.cNext = rdst
        else
            S.torun = rdst
        end
        rdst.cNext = head
    end
end

run = function (reactor, param)
    while S.torun
    do
        local rdst = S.torun
        S.torun = rdst.cNext
        rdst.cNext = nil
        local edgeType = rdst.cEdgeType
        rdst.cEdgeType = nil
        trigger(rdst.cRsrc, edgeType, rdst, rdst.cParam)
    end
end

finish = function (reactor, ret)
    reactor.state = 'ready'
    if not reactor.zero then
        reactor.co = nil
    end
    propagate(reactor, reactor.edges, ret)
end

propagate = function (src, edges, ret)
    for rdst, edgeType in pairs(edges) do
        if (ret~=cancel or edgeType=='call') and
           (not is(rdst) or rdst.state~='deactivated') then
            schedule(src, edgeType, rdst, ret)
        end
    end
end

updateHeight = function (rsrc, rdst, edgeType)
    if edgeType ~= 'start' then return end -- TODO: entender isso novamente
    if not rdst.zero then return end
    assert(not rdst._wasVisited, 'tight cycle detected')

    if not rsrc.height then
        rsrc.height = 1
    end
    local new = rsrc.height + 1

    if (rdst.height or 0) >= new then
        return
    end
    rdst.height = new

    rsrc._wasVisited = true
    for r,tp in pairs(rdst.edges) do
        updateHeight(rdst, r, tp)
    end
    rsrc._wasVisited = false
end

addEdge = function (rsrc, rdst, edgeType)
    assert((type(rsrc) == 'string') or is(rsrc))
    assert(is(rdst))
    assert(edgeType)

    local edges
    if type(rsrc) == 'string' then
        edges = S.strings[rsrc] or {}
        S.strings[rsrc] = edges
    else
        edges = rsrc.edges
    end
    assert(not edges[rdst], tostring(rsrc)..' -> '..tostring(rdst)) -- TODO: never tested!

    -- create the link
    edges[rdst] = edgeType
    if type(rsrc) ~= 'string' then
        updateHeight(rsrc, rdst, edgeType)
    end

    return rsrc, rdst
end

remEdge = function (rsrc, rdst, edgeType)
    local edges
    if type(rsrc) == 'string' then
        edges = S.strings[rsrc] or {}
        S.strings[rsrc] = edges
    else
        edges = rsrc.edges
    end
    local tp = edges[rdst]
    assert(tp and (tp == edgeType)) -- TODO: never tested!
    edges[rdst] = nil
end

createTimer = function (msecs, rnow)
    msecs = S.now + msecs
    local I = 1
    for i=#S.timers, 1, -1 do
        local t = S.timers[i]
        if t.msecs > msecs then
            I = i + 1
            break
        end
    end
    local ret = {msecs=msecs,rdst=rnow}
    t_insert(S.timers, I, ret)
    return ret
end

checkTimers = function (dt)
    S.now = S.now + dt
    while true do
        if #S.timers == 0 then break end
        local t = S.timers[#S.timers]
        if t.msecs > S.now then break end
        S.timers[#S.timers] = nil
        schedule('dt', 'resume', t.rdst, t.msecs)
    end
end

cancelTimer = function (timer)
    for i, cur in ipairs(S.timers) do
        if timer == cur then
            t_remove(S.timers, i)
            return
        end
    end
end

check_create = function (reactor, t)
    if not is(reactor) then
        assert(type(reactor) == 'function')
        reactor = create(reactor, t)
    end
    return reactor
end

------------------------
-- EXPORTED FUNCTIONS --
------------------------

mt_reactor = {}
cancel = {}

function kill (reactor)
    assert(reactor.state == 'awaiting', reactor.state)
    reactor.clearAwaiting()
    reactor.clearAwaiting = nil
    return finish(reactor, cancel)
end

function post (event, value)
    local edges = S.strings[event]
    if edges then
        propagate(event, edges, value)
        run()
    end
end

function spawn (rdst, param)
    rdst = check_create(rdst)
    --assert(not rdst.zero)
    schedule(S.stack[#S.stack], 'start', rdst, param)  -- TODO: nao conferi se eh STACK[#STACK] msm
    return rdst
end

function link (rsrc, rdst)
    rdst = check_create(rdst, {zero=true})
    return addEdge(rsrc, rdst, 'start')
end

function unlink (rsrc, rdst)
    return remEdge(rsrc, rdst, 'start')
end

local function _await (edgeType, ...)
    local rnow = S.stack[#S.stack]
    assert(rnow, 'no reactor running')
    assert(not rnow.zero, rnow.name)

    local t = { ... }
    assert(#t > 0)
    for i, v in ipairs(t)
    do
        if v == 0 then v = 'dt' end

        local tp = type(v)

        if tp == 'number' then
            t[i] = false
            if v > 0 then
                assert(not rnow.timer)
                rnow.timer = createTimer(v, rnow)
            else
                assert(v == -1)
            end

        else  -- reactor
            assert((type(v)=='string') or is(v))--, TRACE())
            t[i] = v
            addEdge(v, rnow, edgeType)
        end
    end

    -- remove links/timers after resume
    rnow.clearAwaiting = function ()
        if rnow.timer then
            cancelTimer(rnow.timer)
            rnow.timer = nil
        end
        for i, v in ipairs(t) do
            if v then
                remEdge(v, rnow, edgeType)
            end
        end
    end

    return co_yield()
end

function await (...)
    return _await('resume', ...)
end

function call (rdst, param, ...)
    if rdst.obj and (param == rdst.obj) then
        param = ...
    end
    local ret, rsrc
    if rdst.zero then
        --ret, rsrc = _await('call', spawn(rdst,param))
        ret, rsrc = trigger(S.stack[#S.stack], 'start', rdst, param)  -- TODO: nao conferi se eh STACK[#STACK] msm
    else
        ret, rsrc = _await('call', spawn(rdst,param))
    end
    run() -- make all pending reactor execute before calling reactor
    return ret, rsrc
end

function is (reactor)
    return getmetatable(reactor) == mt_reactor
end

function create (body, t) -- {name,obj,zero}
    t = t or {}
    t.body    = assert(type(body)=='function') and body
    t.name    = t.name or 'anon'
    t.edges   = {}
    t.co      = nil
    t.state   = 'ready'  -- ready, awaiting, running, deactivated
    t.height  = nil
    t.timer   = nil
    t.cEdgeType = nil
    t.cParam  = nil
    t.cNext   = nil
    return setmetatable(t, mt_reactor)
end

function deactivate (reactor)
    assert(reactor.state == 'awaiting')
    reactor.state = 'deactivated'
    if reactor.timer then
        cancelTimer(reactor.timer)
        reactor.timer.msecs = reactor.timer.msecs - S.now
    end
end

function reactivate (reactor)
    assert(reactor.state == 'deactivated')
    reactor.state = 'awaiting'
    if reactor.timer then
        reactor.timer = createTimer(reactor.timer.msecs, reactor)
    end
end

function loop (nextEvent, app, param)
    app = start(app, param)
    while app.state ~= 'ready' do
        local evt, param = nextEvent()
        step(app, evt, param)
    end
end

function start (app, param)
    app = check_create(app, {name='main'})

    S = {
        strings = {},
        timers  = {},

        stack   = {},
        torun   = nil,
        now     = 0,
        dt      = nil,
    }
    SS[app] = S

    spawn(app, param)
    run()
    return app
end

function step (app, evt, param)
    --assert(app.state == 'awaiting')
    S = assert(SS[app])
    if evt == 'dt' then
        S.dt = param
        checkTimers(param)
        run()
    end
    if evt then
        post(evt, param)
    end
end
