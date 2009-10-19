local gvt       = require 'luagravity'
local meta      = require 'luagravity.meta'
local ldirectfb = require 'luagravity.env.ldirectfb'

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

math.randomseed(os.time())
local random, abs = math.random, math.abs

local pairs = pairs

local function intersecting (A, B)
    local Ax1, Ay1 = A._x(), A._y()
    local Ax2, Ay2 = Ax1+A._width(), Ay1+A._height()
    local Bx1, By1 = B._x(), B._y()
    local Bx2, By2 = Bx1+B._width(), By1+B._height()
	return not ((Bx1 > Ax2) or (Bx2 < Ax1) or (By1 > Ay2) or (By2 < Ay1))
end

APP = meta.global(function()

    -- background
    local bg = dfb:CreateImageProvider('background.png')

    -- score
    _score = 0
    local score = {
        font = dfb:CreateFont('vera.ttf', { flags=ldirectfb.DFDESC_HEIGHT, height=25 }),
        x = 10,
        y = 10,
    }

    -- satellite
    local sat = meta.new()
          sat.img = dfb:CreateImageProvider('sat.gif')
          sat._x = -10
          sat._y = screen.height/3
          sat._width  = screen.width/10
          sat._height = screen.height/10

    -- satellite translation
    spawn(function ()
	    local cond = cond(GT(sat._x, screen.width))
        while true do
		    sat._x = -sat._width()
            await(random(10))
		    sat._x = S(50)
            await(cond._true)
        end
    end)

    -- ship
    local ship = meta.new()
          ship.img = dfb:CreateImageProvider('ship1.gif')
          ship._x = screen.width/2
          ship._y = screen.height/2
          ship._width  = screen.width/15
          ship._height = screen.height/15

    _move = function(key)
        if not ship then return end
	    if key == 'UP' then
		    ship._y = ship._y()-8
	    elseif key == 'DOWN' then
		    ship._y = ship._y()+8
	    elseif key == 'LEFT' then
		    ship._x = ship._x()-8
	    elseif key == 'RIGHT' then
		    ship._x = ship._x()+8
	    end
    end
    link('key.press.RIGHT', _move)
    link('key.press.DOWN',  _move)
    link('key.press.LEFT',  _move)
    link('key.press.UP',    _move)

    -- bullets

    local BULS  = {}

    hit = function() end
    _shoot = function ()
        if not ship then return end

        spawn(function()
	        _score = _score() - 1

            local bul = meta.new()
                  bul._x = ship._x() + ship._width()/2
                  bul._y = ship._y() - S(250)
                  bul._width  = screen.width/250
                  bul._height = screen.height/50
                  bul._hit = hit

            BULS[bul] = true
            await(
                cond(LT(bul._y+bul._height, 0))._true,
                bul._hit
            )
            BULS[bul] = nil
        end)
    end
    link('key.press.SPACE', _shoot)

    -- rocks

    local ROCKS = {}
    local img = dfb:CreateImageProvider('rock.gif')
    local pct = { big=15, small=25 }

    function createRock (size, speed, x, y)
        speed = abs(speed)
        spawn(function()
            local rock = meta.new()
                  rock._width  = screen.width/pct[size]
                  rock._height = screen.height/pct[size]
                  rock.size    = size
                  rock.img     = img
                  rock._hit    = hit

	        x = x or random(100, screen.width-100)
	        rock._vx = random(-speed,speed)
            rock._x = x + S(rock._vx)

	        y = y or -50
            rock._vy = random(1, speed)
            rock._y = y + S(rock._vy)

            ROCKS[rock] = true
            await(rock._hit)
            ROCKS[rock] = nil
        end)
    end

    -- rock generator
    spawn(function ()
	    local v = 50
        for i=1, 5 do
            createRock('big', v)   -- five initial rocks
        end
        while true do               -- another each 5 seconds
            await(5)
            createRock('big', v)
		    v = v + 5
	    end
    end)

    -- collisions

    spawn(function()
        local DX, DY = screen.width, screen.height

        while true
        do
            await('dt')
            -- SHIP vs SCREEN
            if ship then
                local x,   y = ship._x(), ship._y()
                local dx, dy = ship._width(), ship._height()
                if (x+dx >= DX) or (x <= 0) or
                   (y+dy >= DY) or (y < 0) then
                    ship = nil
                end
            end

            -- ROCK vs *
            for rock in pairs(ROCKS)
            do
                -- vs screen
                local x,   y = rock._x(), rock._y()
                local dx, dy = rock._width(), rock._height()
                local vx, vy = rock._vx(), rock._vy()
                if (x+dx >= DX and vx > 0) or
                   (x <= 0 and vx < 0) then
			        rock._vx = -vx
                end
                if (y+dy >= DY and vy > 0) or
                   (y <= 0 and vy < 0) then
			        rock._vy = -vy
                end

                -- vs ship
	            if ship and intersecting(rock, ship) then
                    ship = nil
	            end
            end

            -- ROCK vs BULLET
            for bul in pairs(BULS) do
                for rock in pairs(ROCKS) do
                    if intersecting(bul, rock) then
	                    if rock.size == 'big' then
		                    _score = _score() + 10
                            createRock('small', rock._vx(), rock._x(), rock._y())
                            createRock('small', rock._vy(), rock._x(), rock._y())
	                    else
		                    _score = _score() + 15
	                    end
                        rock._hit()
	                    bul._hit()
                        break
                    end
                end
            end
        end
    end)

    -- redrawing
    spawn(function ()
        while true do
            await(0)

            -- background
	        bg:RenderTo(sfc, 0, 0, screen.width, screen.height)

            -- score
	        sfc:SetColor(255, 0, 0, 0)
	        sfc:SetFont(score.font)
	        sfc:DrawString(_score(), score.x, score.y,
                        ldirectfb.DSTF_LEFT+ldirectfb.DSTF_TOP)

            -- satellite
	        sat.img:RenderTo(sfc, sat._x(), sat._y(), sat._width(), sat._height())

            -- ship
            if ship then
	            ship.img:RenderTo(sfc, ship._x(), ship._y(), ship._width(), ship._height())
            else
   	            sfc:SetColor(255, 0, 0, 0)
	            sfc:SetFont(score.font)
	            sfc:DrawString('Voce perdeu!', 200, 200,
                               ldirectfb.DSTF_LEFT+ldirectfb.DSTF_TOP)
            end

            -- rocks
            for rock in pairs(ROCKS) do
                rock.img:RenderTo(sfc, rock._x(), rock._y(), rock._width(), rock._height())
            end

            -- bullets
            sfc:SetColor(255, 255, 255, 255)
            for bul in pairs(BULS) do
                sfc:FillRectangle(bul._x(), bul._y(), bul._width(), bul._height())
            end

            sfc:Flip()
        end
    end)

    await('key.release.ESCAPE')
end)

gvt.setEnvironment(ldirectfb)
gvt.loop(APP)
