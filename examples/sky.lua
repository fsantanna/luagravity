local _G = _G
local gvt       = require 'luagravity'
local ldirectfb = require 'luagravity.env.ldirectfb'
local meta      = require 'luagravity.meta'

local rand = math.random

local dfb = ldirectfb.init()
dfb:SetCooperativeLevel(ldirectfb.DFSCL_FULLSCREEN)
local dsc = {
	flags = ldirectfb.DSDESC_CAPS;
	caps  = ldirectfb.DSCAPS_PRIMARY + ldirectfb.DSCAPS_FLIPPING;
}
local sfc = dfb:CreateSurface(dsc)
local dx, dy = sfc:GetSize()
local screen = {
    surface = sfc,
    width   = dx,
    height  = dy,
}

local rects = {}
local function redraw ()
    sfc:SetColor(0, 0, 0, 255)
    sfc:FillRectangle(0, 0, screen.width, screen.height)

    sfc:SetColor(0, 0, 255, 255)
    for _, r in ipairs(rects) do
        sfc:FillRectangle(r._x(), r._y(), r._width(), r._height())
    end

    sfc:Flip()
end

gvt.setEnvironment(ldirectfb)

gvt.loop(function ()
    meta.global()
    for i=1, 15
    do
     local r = meta.new()
        rects[#rects+1] = r
        r._x = screen.width/2 + S(rand(-20,20))

        r._y = -10
        local v = 1 + (delay(r._y)^1.3 / screen.height)
     r._y = S(rand(1,15)*v)

     local dim = 1 + r._y/5
     r._width  = dim
     r._height = dim
    end

    spawn(function()
        while true do
            await(0)
            redraw()
        end
    end)

    await('key.release.ESCAPE')
end)
