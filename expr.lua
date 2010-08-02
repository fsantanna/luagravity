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
    self._set = gvt.create(expr_set, {name='set',obj=self,zero=true})
    return self
end

-- DELAY

local function delay_start (self, v)
    gvt.spawn(function()
        gvt.await(self.msecs.value)
        gvt.call(self._set, v)
    end)
end

function delay (expr, msecs)
    if not is(expr) then
        expr = new(expr)
    end
    if not is(msecs) then
        msecs = new(msecs or 0)
    end
    local self = new()
    self.msecs = msecs
    self._start = gvt.create(delay_start, {name='start',obj=self,zero=true})
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
    self._set   = gvt.create(cond_set,   {name='set',  obj=self,zero=true})
    self._true  = gvt.create(cond_true,  {name='true', obj=self,zero=true})
    self._false = gvt.create(cond_false, {name='false',obj=self,zero=true})
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
        self._set = gvt.create(lift_set, {name='set',obj=self,zero=true})
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
	if is(self.src) then
		gvt.unlink(self.src._set, self._set)
	end
	self.src = src
	if is(src) then
		gvt.link(src._set, self._set)
        gvt.call(self._set, src.value)
	else
        gvt.call(self._set, src)
	end
end

function var (v)
    local self = new(v)
	self.src  = nil
    self.attr = attr
    return self
end

-- INTEGRAL / DERIVATIVE

local function integral_set (self, _)
    local value = self.value + self.expr.value*gvt.S.dt
    self.value = value
    return value
end

function integral (expr)
    if not is(expr) then
        expr = new(expr)
    end
    local self = new(0)
    self.expr  = expr
    self._set = gvt.create(integral_set, {name='set',obj=self,zero=true})
    gvt.link('dt', self._set)
    gvt.link(expr._set, self._set)
    return self
end

local function derivative_set (self, _)
    local cur  = self.expr.value
    local last = self.last
    local value = (last and (cur-last)/gvt.S.dt) or nil
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
    self._set = gvt.create(derivative_set, {name='set',obj=self,zero=true})
    gvt.link('dt', self._set)
    gvt.link(expr._set, self._set)
    return self
end


