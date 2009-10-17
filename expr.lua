local _G  = _G
local gvt = require 'luagravity'

local setmetatable, assert, type, ipairs, getmetatable, unpack =
      setmetatable, assert, type, ipairs, getmetatable, unpack

module (...)

-- BEHAVIOR

mt_expr = {}

local function expr_set (self, value)
    if self.value == value then
        return gvt.cancel
    end
	self.value = value
    return value
end

function expr_get (self)
    return self.value
end

function is (expr)
    return getmetatable(expr) == mt_expr
end

function new (v)
    local self = setmetatable({
        value = v,
    }, mt_expr)
    self._set = gvt.create('set', self, true, expr_set)
    return self
end

-- DELAY

local function delay_start (self, v)
    gvt.spawn(function()
        gvt.await(self.secs.value)
        gvt.call(self._set, v)
    end)
end

function delay (expr, secs)
    if not is(expr) then
        expr = new(expr)
    end
    if not is(secs) then
        secs = new(secs or 0)
    end
    local self = new()
    self.secs = secs
    self._start = gvt.create('start', self, true, delay_start)
    gvt.link(expr._set, self._start)
    gvt.call(self._start, expr.value)
    return self
end

-- BOOLEAN

local function cond_set (self, v)
    self.old = self.value
    return expr_set(self, v)
end
 
local function cond_true (self, v)
    local old, new = not(not self.old), not(not self.value)
    if (old ~= new) and new then
        return self.value
    else
        return gvt.cancel
    end
end

local function cond_false (self, v)
    local old, new = not(not self.old), not(not self.value)
    if (old ~= new) and (not new) then
        return self.value
    else
        return gvt.cancel
    end
end

function condition (expr)
    if not is(expr) then
        expr = new(expr)
    end
    local self  = new(expr.value)
    self._set   = gvt.create('set',   self, true, cond_set)
    self._true  = gvt.create('true',  self, true, cond_true)
    self._false = gvt.create('false', self, true, cond_false)
    gvt.link(expr._set,  self._set)
    gvt.link(self._set, self._true)
    gvt.link(self._set, self._false)
    return self
end

-- LIFT

local params = {}
local function lift_set (self, _)
	local srcs = self.srcs
	for i, src in ipairs(srcs) do
		if is(src) then
            params[i] = src.value
        else
            params[i] = src
        end
	end
    return expr_set(self, self.fun(unpack(params, 1, #srcs)))
end

function lift (fun)
    return function (...)
        local self = new(nil)
	    self.fun  = fun    ; assert(type(fun) == 'function')
	    self.srcs = {...}
        self._set = gvt.create('set', self, true, lift_set)

        local rev = {}  -- avoids two equal links
	    for i, src in ipairs(self.srcs) do
            if not rev[src] then
                rev[src] = true
		        if is(src) then
                    gvt.link(src._set, self._set)
                end
		    end
	    end
        gvt.call(self._set)
        return self
    end
end

-- VAR

local function attr (self, src)
	if self.src == src then return end
	if self.brk then
		self.brk()
		self.brk = nil
	end
	self.src = src
	if is(src) then
		self.brk = gvt.link(src._set, self._set)
        gvt.call(self._set, src.value)
	else
        gvt.call(self._set, src)
	end
end

function var (v)
    local self = new(v)
	self.src  = nil
	self.brk  = nil
    self.attr = attr
    return self
end

-- INTEGRAL / DERIVATIVE

local function integral_set (self, _)
    local value = self.value + self.expr.value*gvt.dt
    self.value = value
    return value
end

function integral (expr)
    if not is(expr) then
        expr = new(expr)
    end
    local self = new(0)
    self.expr  = expr
    self._set = gvt.create('set', self, true, integral_set)
    gvt.link('dt', self._set)
    gvt.link(expr._set, self._set)
    return self
end

local function derivative_set (self, _)
    local cur  = self.expr.value
    local last = self.last
    local value = (last and (cur-last)/gvt.dt) or nil
    self.last = cur
    self.value = value
    return value
end

function derivative (expr)
    if not is(expr) then
        expr = new(expr)
    end
    local self = new(nil)
    self.expr  = expr
    self.last = nil
    self._set = gvt.create('set', self, true, derivative_set)
    gvt.link('dt', self._set)
    gvt.link(expr._set, self._set)
    return self
end


