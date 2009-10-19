local gvt  = require 'luagravity'
local expr = require 'luagravity.expr'

local rawset, setmetatable, type, setfenv =
      rawset, setmetatable, type, setfenv
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
mt_expr.__unm    = expr.lift(function(a)    return       a and     -a end);
mt_expr.__concat = expr.lift(function(a, b) return a and b and a .. b end);

gvt.mt_reactor.__call = gvt.call

local mt_t = {
	__index = function (t, k)
        return t.__vars[k]
	end,

	__newindex = function (t, k, v)
        if s_sub(k, 1, 1) ~= '_' then
			rawset(t, k, v)
            return
        end

		if type(v) == 'function' then
            local inst = (s_sub(k, 2, 2) ~= '_')
            rawset(t, k, gvt.create(k, t.__obj and t, inst, v))
        else
			local var = t.__vars[k] or expr.var()
            t.__vars[k] = var
            var:attr(v)
        end
	end,
}

local cond = function (e)
    return expr.condition(e)._true
end
local notcond = function (e)
    return expr.condition(e)._false
end

function global (f)
    local t = new(false)

    t.spawn  = gvt.spawn
    t.call   = gvt.call
    t.stop   = gvt.stop
    t.link   = gvt.link
    t.unlink = gvt.unlink
    t.await  = gvt.await
    t.cancel = gvt.cancel

    t.delay   = expr.delay
    t.cond    = cond
    t.notcond = notcond
    t.L       = expr.lift
    t.S       = expr.integral
    t.D       = expr.derivative
	t.LEN     = expr.lift(function(a) return a and #a end);
	t.EQ      = expr.lift(function(a, b) return a and b and a == b end);
	t.LT      = expr.lift(function(a, b) return a and b and  a < b end);
	t.LE      = expr.lift(function(a, b) return a and b and a <= b end);
	t.GT      = expr.lift(function(a, b) return a and b and  a > b end);
	t.GE      = expr.lift(function(a, b) return a and b and a >= b end);
	t.NOT     = expr.lift(function(a) return not a end);
	t.OR      = expr.lift(function(a, b) return a or b end);
	t.AND     = expr.lift(function(a, b) return a and b end);

    if f then
        return setfenv(f, t)
    else
        return setfenv(2, t)
    end
end

function new (obj)
    return setmetatable({
        __obj  = obj,    -- true/false
        __vars = {},
    }, mt_t)
end
