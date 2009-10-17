local gvt      = require 'luagravity'
local meta     = require 'luagravity.meta'
local directfb = require 'luagravity.env.directfb'

local dfb = directfb.init()
dfb:SetCooperativeLevel(directfb.DFSCL_FULLSCREEN)
local dsc = {
	flags = directfb.DSDESC_CAPS;
	caps  = directfb.DSCAPS_PRIMARY + directfb.DSCAPS_FLIPPING;
}
local sfc = dfb:CreateSurface(dsc)
local dx, dy = sfc:GetSize()
local screen = {
    surface = sfc,
    width   = dx,
    height  = dy,
}

local r = meta.new()
      r._x = 100
      r._y = 100
      r._width  = 50
      r._height = 50

local function redraw ()
    sfc:SetColor(0, 0, 0, 255)
    sfc:FillRectangle(0, 0, screen.width, screen.height)
    sfc:SetColor(0, 0, 255, 255)
    sfc:FillRectangle(r._x(), r._y(), r._width(), r._height())
    sfc:Flip()
end

gvt.setEnvironment(directfb)

gvt.loop(function ()
    meta.global()

    -- Reactor that tracks the rectangle movement.
    spawn(function()
        while true do
            await('key.press.RIGHT')  -- expects RIGHT
            r._x = r._x() + S(80)     -- makes X move right
            r._y = r._y()             -- holds on Y

            await('key.press.DOWN')   -- expects DOWN
            r._x = r._x()             -- holds on X
            r._y = r._y() + S(80)     -- makes Y move down

            await('key.press.LEFT')   -- expects LEFT
            r._x = r._x() - S(80)     -- makes X move LEFT
            r._y = r._y()             -- holds on Y

            await('key.press.UP')     -- expects UP
            r._x = r._x()             -- holds on X
            r._y = r._y() - S(80)     -- makes Y move UP

            -- back to await RIGHT
        end
    end)

    spawn(function()
        while true do
            await(0)
            redraw()
        end
    end)

    await('key.release.ESCAPE')
end)
