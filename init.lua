--[[
-- TODO:
-- * Rewrite the debugging system.
-- * Rewrite the topological order algorithm.
--]]

local _G = _G

local co_running, co_create, co_resume, co_yield, co_status =
      coroutine.running, coroutine.create,
      coroutine.resume, coroutine.yield, coroutine.status

local t_insert, t_remove = table.insert, table.remove

local error, assert, type, pairs, ipairs, setmetatable, getmetatable =
      error, assert, type, pairs, ipairs, setmetatable, getmetatable

local TRACE = debug.traceback

module (...)

local STRINGS = {}
local TIMERS  = {}
local STACK   = {}
local NOW     = 0
local ENV

local traceback = function()
    local stacktrace = ''
    for _, r in ipairs(STACK) do
        stacktrace = stacktrace .. r.name .. ' | '
    end
    return 'gvt traceback: ' .. stacktrace .. '\n' .. TRACE()
end
_G.TRACEBACK = traceback

local oldError = error
local error = function (msg)
    oldError((msg or '<no message>') .. '\n' .. traceback() .. '\n')
end

local assert = function (cond, msg)
    if cond then
        return cond
    else
        error(msg)
    end
end

local trigger, edge2action, schedule, run, finish, updateHeight,
      addEdge, createTimer, checkTimers, check_create

-- action: start or resume
trigger = function (action, rdst, param)
    assert( (action=='resume' and rdst.state=='awaiting') or
            (action=='start' and rdst.state=='ready'),
            rdst.name .. ' is already running (' ..rdst.state..')' )

    local st, ret

    -- CALL
    STACK[#STACK+1] = rdst
    rdst.state = 'running'
    if rdst.zero then
        if rdst.obj then
            ret = rdst.fun(rdst.obj, param)
        else
            ret = rdst.fun(param)
        end
    else
        if action == 'start' then -- reacao duradoura: necessita de co-rotina
            rdst.co = co_create(rdst.fun)
        else -- resume
            assert(action == 'resume')
            rdst.clearAwaiting()
            rdst.clearAwaiting = nil
        end
        assert(co_status(rdst.co) == 'suspended')
        if rdst.obj and (action == 'start') then
            st, ret = co_resume(rdst.co, rdst.obj, param)
        else
            st, ret = co_resume(rdst.co, param)
        end
        assert(st, ret)
    end
    STACK[#STACK] = nil

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

-- edgeType: 'link', 'await', 'spawn'
edge2action = function (edgeType)
    local action
    if (edgeType == 'spawn') or (edgeType == 'link') then
        action = 'start'
    else
        action = 'resume'
    end
    return action
end

local NEXT = nil
-- TODO: criar ponteiro LAST e adicionar reacoes de tras pra frente
-- action: 'start', 'resume'
schedule = function (action, rdst, param)
    -- optimize when height is not used
    --if not rdst.height then
        --trigger(action, rdst, param)
        --return
    --end

    local cur = rdst.cAction
    rdst.cParam = param

    if cur then
        assert(cur == action)
    else
        rdst.cAction = action
        local height = rdst.height or 0
        local head, prev = NEXT, nil
        rdst.cHeight = height

        while head and (head.cHeight <= height) do
            prev = head
            head = head.cNext
        end
        if prev then
            prev.cNext = rdst
        else
            NEXT = rdst
        end
        rdst.cNext = head
    end
end

run = function (reactor, param)
    while NEXT
    do
        local rdst = NEXT
        NEXT = rdst.cNext
        rdst.cNext = nil
        local action = rdst.cAction
        rdst.cAction = nil
        trigger(action, rdst, rdst.cParam)
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
        if ret ~= cancel then
            schedule(edge2action(edgeType), rdst, ret)
        end
    end
end

-- edgeType: link, await
updateHeight = function (rsrc, rdst, edgeType)
    if type(rsrc) == 'string' then return end
    if edgeType ~= 'link' then return end
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
    rdst = check_create(rdst, nil, nil, true)
    assert(edgeType)

    local edges
    if type(rsrc) == 'string' then
        edges = STRINGS[rsrc] or {}
        STRINGS[rsrc] = edges
    else
        edges = rsrc.edges
    end
    assert(not edges[rdst]) -- TODO: never tested!

    -- create the link
    edges[rdst] = edgeType
    updateHeight(rsrc, rdst, edgeType)

    return rsrc, rdst
end

remEdge = function (rsrc, rdst, edgeType)
    local edges
    if type(rsrc) == 'string' then
        edges = STRINGS[rsrc] or {}
        STRINGS[rsrc] = edges
    else
        edges = rsrc.edges
    end
    local tp = edges[rdst]
    assert(tp and (tp == edgeType)) -- TODO: never tested!
    edges[rdst] = nil
end

createTimer = function (time, rnow)
    time = NOW + time
    local I = 1
    for i=#TIMERS, 1, -1 do
        local t = TIMERS[i]
        if t.time > time then
            I = i + 1
            break
        end
    end
    local ret = {time=time,rdst=rnow,cancelled=false}
    t_insert(TIMERS, I, ret)
    return ret
end    

checkTimers = function (dt)
    NOW = NOW + dt
    while true do
        if #TIMERS == 0 then break end
        local t = TIMERS[#TIMERS]
        if t.time > NOW then break end

        TIMERS[#TIMERS] = nil
        if not t.cancelled then
            assert(t.rdst.state == 'awaiting', t.rdst.state)
            schedule('resume', t.rdst, t.time)
        end
    end
end

check_create = function (reactor, name, obj, zero)
    if not is(reactor) then
        assert(type(reactor) == 'function')
        reactor = create(name, obj, zero, reactor)
    end
    return reactor
end

------------------------
-- EXPORTED FUNCTIONS --
------------------------

mt_reactor = {}
cancel = {}
dt = nil

function stop (reactor)
    assert(reactor.state == 'awaiting', reactor.state)
    reactor.clearAwaiting()
    reactor.clearAwaiting = nil
    return finish(reactor, cancel)
end

function post (event, value)
    local edges = STRINGS[event]
    if not edges then return end
    for rdst, edgeType in pairs(edges) do
        schedule(edge2action(edgeType), rdst, value)
    end
    run()
end

function spawn (rdst, param)
    rdst = check_create(rdst, nil, nil, false)
    assert(not rdst.zero)
    schedule('start', rdst, param)
    return rdst
end

function call (rdst, param, ...)
    if rdst.obj and (param == rdst.obj) then
        param = ...
    end
    local ret
    if rdst.zero then
        ret = trigger('start', rdst, param)
    else
        -- TODO: assert if there is a delayed reactor in the stack
        schedule('start', rdst, param)
        ret = await(rdst)
        --await(0)
    end
    run() -- make all pending reactor execute before calling reactor
    return ret
end

function link (rsrc, rdst)
    return addEdge(rsrc, rdst, 'link')
end

function unlink (rsrc, rdst)
    return remEdge(rsrc, rdst, 'link')
end

function await (...)
    local rnow = STACK[#STACK]
    assert(not rnow.zero, rnow.name)

    local t = { ... }
    assert(#t > 0)
    for i, v in ipairs(t)
    do
        local tp = type(v)

        if tp == 'number' then
            if v == 0 then v = 0.00001 end
            if v > 0 then
                t[i] = createTimer(v, rnow)
            end

        else  -- reactor
            assert((type(v)=='string') or is(v))--, TRACE())
            t[i] = v
            addEdge(v, rnow, 'await')
        end
    end

    -- remove links/timers after resume
    rnow.clearAwaiting = function ()
        for i, v in ipairs(t) do
            if (type(v)=='string') or is(v) then
                remEdge(v, rnow, 'await')
            else
                v.cancelled = true  -- timer
            end
        end
    end

    return co_yield()
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
        cAction = nil,
        cParam  = nil,
        cNext   = nil,
    }, mt_reactor)
end

function loop (app, param, zero)
    assert(ENV)
    link('dt', checkTimers)
    app = check_create(app, 'main', nil, zero)
    schedule('start', app, param)
    run()
    while app.state ~= 'ready' do
        local evt, param = ENV.nextEvent()
        if evt == 'dt' then dt = param end
        if evt then
            post(evt, param)
        end
    end
end

function setEnvironment (env)
    ENV = env
end
function environment (env)  -- TODO: substitute setEnv?
    if env then
        ENV = env
    end
    return ENV
end
