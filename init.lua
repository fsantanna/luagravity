--[[
-- TODO:
-- * Rewrite the debugging system.
-- * Rewrite the topological order algorithm.
-- * Test rsrc as last parameter of triggers.
-- * Remove gvt.call(), demand explicit use of spawn/await
-- * GVT reentrante (more than one gvt application per Lua state)
-- * IDX: doc and tests
-- * meta.new, env, nova api, testes, doc
-- * await(p) -- em vez de -- p() / TESTES / DOC
--]]

local _G = _G

local co_running, co_create, co_resume, co_yield, co_status =
      coroutine.running, coroutine.create,
      coroutine.resume, coroutine.yield, coroutine.status

local t_insert, t_remove = table.insert, table.remove

local error, assert, type, pairs, ipairs, setmetatable, getmetatable, tostring =
      error, assert, type, pairs, ipairs, setmetatable, getmetatable, tostring

local traceback = debug.traceback

module (...)

local SS = setmetatable({}, {__mode='k'})
S = nil

local mytraceback = function()
    local stacktrace = ''
    for _, r in ipairs(S.stack) do
        stacktrace = stacktrace .. r.name .. ' | '
    end
    return 'gvt traceback: ' .. stacktrace .. '\n' .. traceback()
end

local myerror = function (msg)
    error((msg or '<no message>') .. '\n' .. mytraceback() .. '\n')
end

local myassert = function (cond, msg)
    if cond then
        return cond
    else
        myerror(msg)
    end
end

local trigger, schedule, run, finish, updateHeight,
      addEdge, createTimer, checkTimers, check_create

trigger = function (rsrc, edgeType, rdst, param)
    local st, ret
    if (edgeType == 'resume') or (edgeType == 'call') then
        myassert(rdst.clearAwaiting)()
        rdst.clearAwaiting = nil
    end

    -- CALL
    S.stack[#S.stack+1] = rdst
    if rdst.zero then
        myassert((not rdst.co) and (rdst.state=='ready'))
        rdst.state = 'running'
        if rdst.obj then
            ret = rdst.fun(rdst.obj, param, rsrc)
        else
            ret = rdst.fun(param, rsrc)
        end
    else
        if edgeType == 'start' then -- reacao duradoura: necessita de co-rotina
            myassert((not rdst.co) and (rdst.state=='ready'), rdst.state)
            rdst.co = co_create(rdst.fun)
        else -- resume
            myassert((edgeType == 'resume') or (edgeType == 'call'), edgeType)
            myassert(rdst.co and (rdst.state=='awaiting'))
        end
        myassert(co_status(rdst.co) == 'suspended')
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
        myassert(st, ret)
    end
    S.stack[#S.stack] = nil

    -- not finished
    if (not rdst.zero) and (co_status(rdst.co) == 'suspended') then
        rdst.state = 'awaiting'

    -- finished
    else
        myassert(rdst.zero or (co_status(rdst.co) == 'dead'))
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
        myassert(cur == edgeType)
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

    -- propagate
    local edges = reactor.edges
    for rdst, edgeType in pairs(edges) do
        if (edgeType == 'call') or (ret ~= cancel) then
            schedule(reactor, edgeType, rdst, ret)
        end
    end
end

updateHeight = function (rsrc, rdst, edgeType)
    if type(rsrc) == 'string' then return end
    if edgeType ~= 'start' then return end -- TODO: entender isso novamente
    if not rdst.zero then return end
    myassert(not rdst._wasVisited, 'tight cycle detected')

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
    myassert((type(rsrc) == 'string') or is(rsrc))
    rdst = check_create(rdst, nil, nil, true)
    myassert(edgeType)

    local edges
    if type(rsrc) == 'string' then
        edges = S.strings[rsrc] or {}
        S.strings[rsrc] = edges
    else
        edges = rsrc.edges
    end
    myassert(not edges[rdst], tostring(rsrc)..' -> '..tostring(rdst)) -- TODO: never tested!

    -- create the link
    edges[rdst] = edgeType
    updateHeight(rsrc, rdst, edgeType)

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
    myassert(tp and (tp == edgeType)) -- TODO: never tested!
    edges[rdst] = nil
end

createTimer = function (time, rnow)
    time = S.now + time
    local I = 1
    for i=#S.timers, 1, -1 do
        local t = S.timers[i]
        if t.time > time then
            I = i + 1
            break
        end
    end
    local ret = {time=time,rdst=rnow,cancelled=false}
    t_insert(S.timers, I, ret)
    return ret
end    

checkTimers = function (dt)
    S.now = S.now + dt
    while true do
        if #S.timers == 0 then break end
        local t = S.timers[#S.timers]
        if t.time > S.now then break end

        S.timers[#S.timers] = nil
        if not t.cancelled then
            myassert(t.rdst.state == 'awaiting', t.rdst.state)
            schedule('dt', 'resume', t.rdst, t.time)
        end
    end
end

check_create = function (reactor, name, obj, zero)
    if not is(reactor) then
        myassert(type(reactor) == 'function')
        reactor = create(name, obj, zero, reactor)
    end
    return reactor
end

------------------------
-- EXPORTED FUNCTIONS --
------------------------

mt_reactor = {}
cancel = {}

function stop (reactor)
    myassert(reactor.state == 'awaiting', reactor.state)
    reactor.clearAwaiting()
    reactor.clearAwaiting = nil
    return finish(reactor, cancel)
end

function post (event, value)
    local edges = S.strings[event]
    if not edges then return end
    for rdst, edgeType in pairs(edges) do
        schedule(event, edgeType, rdst, value)
    end
    run()
end

function spawn (rdst, param)
    rdst = check_create(rdst, nil, nil, false)
    --myassert(not rdst.zero)
    schedule(S.stack[#S.stack], 'start', rdst, param)  -- TODO: nao conferi se eh STACK[#STACK] msm
    return rdst
end

function link (rsrc, rdst)
    return addEdge(rsrc, rdst, 'start')
end

function unlink (rsrc, rdst)
    return remEdge(rsrc, rdst, 'start')
end

local function _await (edgeType, ...)
    local rnow = S.stack[#S.stack]
    myassert(rnow, 'no reactor running')
    myassert(not rnow.zero, rnow.name)

    local t = { ... }
    myassert(#t > 0)
    for i, v in ipairs(t)
    do
        local tp = type(v)

        if tp == 'number' then
            if v == 0 then v = 0.00001 end
            if v > 0 then
                t[i] = createTimer(v, rnow)
            end

        else  -- reactor
            myassert((type(v)=='string') or is(v))--, TRACE())
            t[i] = v
            addEdge(v, rnow, edgeType)
        end
    end

    -- remove links/timers after resume
    rnow.clearAwaiting = function ()
        for i, v in ipairs(t) do
            if (type(v)=='string') or is(v) then
                remEdge(v, rnow, edgeType)
            else
                v.cancelled = true  -- timer
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
        ret, rsrc = _await('call', spawn(rdst,param))
        --ret, rsrc = trigger(S.stack[#S.stack], 'start', rdst, param)  -- TODO: nao conferi se eh STACK[#STACK] msm
    else
        ret, rsrc = _await('call', spawn(rdst,param))
    end
    run() -- make all pending reactor execute before calling reactor
    return ret, rsrc
end

function is (reactor)
    return getmetatable(reactor) == mt_reactor
end

function create (name, obj, zero, fun)
    return setmetatable({
        name    = name or 'anon',
        obj     = obj,
        zero    = zero,
        fun     = fun,
        edges   = {},
        co      = nil,
        state   = 'ready',
        height  = nil,
        cEdgeType = nil,
        cParam  = nil,
        cNext   = nil,
    }, mt_reactor)
end

function loop (app, param, zero)
    app = start(app, param, zero)
    myassert(S.env)
    while app.state ~= 'ready' do
        local evt, param = S.env.nextEvent()
        step(app, evt, param)
    end
end

function start (app, param, zero)
    app = check_create(app, 'main', nil, zero)

    S = {
        env     = nil,
        strings = {},
        timers  = {},

        stack   = {},
        torun   = nil,
        now     = 0,
        dt      = nil,
    }
    SS[app] = S

    schedule(nil, 'start', app, param)
    run()
    return app
end

function step (app, evt, param)
    myassert(app.state == 'awaiting')
    S = myassert(SS[app])
    if evt == 'dt' then
        S.dt = param
        checkTimers(param)
        run()
    end
    if evt then
        post(evt, param)
    end
end

function setEnvironment (env)
    S.env = env
end
function environment (env)  -- TODO: substitute setEnv?
    if env then
        S.env = env
    end
    return S.env
end
