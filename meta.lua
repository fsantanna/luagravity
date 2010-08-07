local gvt  = require 'luagravity'
local expr = require 'luagravity.expr'

local rawset, setmetatable, type, setfenv, getfenv, _pairs, _ipairs, select, assert, print, loadfile =
      rawset, setmetatable, type, setfenv, getfenv,  pairs,  ipairs, select, assert, print, loadfile
local s_sub = string.sub

module (...)

local mt_expr = expr.mt_expr
mt_expr.__call   = expr.expr_get
mt_expr.__add    = expr.lift(function(a, b) return a and b and  a + b end);
mt_expr.__sub    = expr.lift(function(a, b) return a and b and  a - b end);
mt_expr.__mul    = expr.lift(function(a, b) return a and b and  a * b end);
mt_expr.__div    = expr.lift(function(a, b) return a and b and  a / b end);
mt_expr.__mod    = expr.lift(function(a, b) return a and b and  a % b end);
mt_expr.__pow    = expr.lift(function(a, b) return a and b and  a ^ b end);
mt_expr.__unm    = expr.lift(function(a)    return    a    and   -a   end);
mt_expr.__concat = expr.lift(function(a, b) return a and b and a .. b end);

gvt.mt_reactor.__call = gvt.call

local mt_t = {
    __index = function (t, k)
        return t.__vars[k] or (t.__env and t.__env[k]) or nil
    end,

	__newindex = function (t, k, v)
        if s_sub(k, 1, 1) == '_' then
            if type(v) == 'function' then
                local inst = (s_sub(k, 2, 2) ~= '_')
                v = gvt.create(v, {name=k, obj=(t.__obj and t), zero=inst})
            else
                local var = t.__vars[k] or expr.var()
                var:attr(v)
                v = var
            end
        end
        t.__vars[k] = v
    end,
}

local cond = function (e)
    return expr.condition(e)._true
end
local notcond = function (e)
    return expr.condition(e)._false
end

local function incenv (env)
    if type(env) == 'table' then
        return env
    end
    return (env or 1) + 1
end

function apply (f, env)
    local t = new(nil, incenv(env), false)

    t.spawn  = gvt.spawn
    t.call   = gvt.call
    t.kill   = gvt.kill
    t.link   = gvt.link
    t.unlink = gvt.unlink
    t.await  = gvt.await
    t.cancel = gvt.cancel
    t.post   = gvt.post
    t.deactivate = gvt.deactivate
    t.reactivate = gvt.reactivate

    t.cond    = cond
    t.notcond = notcond
    t.delay   = expr.delay
    t.L       = expr.lift
    t.S       = expr.integral
    t.D       = expr.derivative
    t.LEN     = expr.lift(function(a) return a and #a end);
    t.EQ      = expr.lift(function(a, b) return a and b and a == b end);
    t.NEQ     = expr.lift(function(a, b) return a and b and a ~= b end);
    t.LT      = expr.lift(function(a, b) return a and b and  a < b end);
    t.LE      = expr.lift(function(a, b) return a and b and a <= b end);
    t.GT      = expr.lift(function(a, b) return a and b and  a > b end);
    t.GE      = expr.lift(function(a, b) return a and b and a >= b end);
    t.NOT     = expr.lift(function(a) return not a end);
    t.OR      = expr.lift(function(a, b) return a or b end);
    t.AND     = expr.lift(function(a, b) return a and b end);
--[[
    -- nao funciona, caso do cart
    t.IDX     = expr.lift(function(t, k) return t and k and expr.is(t[k]) and t[k]() or t[k] end);
]]

    if f then
        return setfenv(f, t), t
    else
        return setfenv(2, t), t
    end
end

function dofile (filename, env)
    local f = apply(assert(loadfile(filename)), incenv(env))
    return f() or getfenv(f)
end

function len (t)
    return #t.__vars
end
function ipairs (t)
    return _ipairs(t.__vars)
end
function pairs (t)
    return _pairs(t.__vars)
end

function new (t, env, isObj)
    local ret = setmetatable({
        __env  = (type(env)=='table') and env or getfenv(incenv(env)) or false,
        __obj  = isObj,
        __vars = {},
    }, mt_t)
    if t then
        for k, v in _pairs(t) do
            ret[k] = v
        end
    end
    return ret
end
