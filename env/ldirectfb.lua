local _G = _G
local gvt = require 'luagravity'

local ldirectfb = require 'ldirectfb'
local dfb       = ldirectfb.init()
local buffer    = dfb:CreateInputEventBuffer(ldirectfb.DICAPS_ALL, true)
local timeofday = ldirectfb.gettimeofday

module (...)

local FPS = 30
local MPF = 1000 / FPS

local function f_now ()
    local s, us = timeofday()
    return s + us/1000000
end
local NOW = f_now()

local key_map, mouse_map

function ldirectfb.nextEvent ()
    if not buffer:HasEvent() then
        buffer:WaitForEventWithTimeout(0, MPF)
        local now = f_now()
        local dt  = now-NOW
        gvt.dt = dt
        NOW = now
        return 'dt', dt
    else
        local evt = buffer:GetEvent()
        local cls = evt.clazz
	    local tp  = evt.type

        -- INPUT
        if cls == ldirectfb.DFEC_INPUT
        then
            -- KEYBOARD
	        if tp == ldirectfb.DIET_KEYPRESS then
		        local key = key_map[evt.key_symbol]
		        if key then
                    return 'key.press.'..key, key
		        end
	        elseif tp == ldirectfb.DIET_KEYRELEASE then
		        local key = key_map[evt.key_symbol]
		        if key then
                    return 'key.release.'..key, key
		        end

            -- MOUSE
	        elseif tp == ldirectfb.DIET_AXISMOTION then
		        if evt.axis == 0 then
                    return 'mouse.x', evt.axisabs
		        else
                    return 'mouse.y', evt.axisabs
		        end
	        elseif tp == ldirectfb.DIET_BUTTONPRESS then
                return 'mouse.press.'..mouse_map[evt.button]
	        elseif tp == ldirectfb.DIET_BUTTONRELEASE then
                return 'mouse.release.'..mouse_map[evt.button]
            else
                error 'invalid event'
            end

        -- USER
        elseif cls == ldirectfb.DFEC_USER then
            error 'invalid event'
        -- ERROR
        else
            error 'invalid event'
        end
    end
end

local K = ldirectfb
key_map = {
	[K.DIKS_0]='0', [K.DIKS_1]='1', [K.DIKS_2]='2',
	[K.DIKS_3]='3', [K.DIKS_4]='4', [K.DIKS_5]='5',
	[K.DIKS_6]='6', [K.DIKS_7]='7', [K.DIKS_8]='8',
	[K.DIKS_9]='9',

	[K.DIKS_SMALL_A]='a', [K.DIKS_SMALL_B]='b', [K.DIKS_SMALL_C]='c',
	[K.DIKS_SMALL_D]='d', [K.DIKS_SMALL_E]='e', [K.DIKS_SMALL_F]='f',
	[K.DIKS_SMALL_G]='g', [K.DIKS_SMALL_H]='h', [K.DIKS_SMALL_I]='i',
	[K.DIKS_SMALL_J]='j', [K.DIKS_SMALL_K]='k', [K.DIKS_SMALL_L]='l',
	[K.DIKS_SMALL_M]='m', [K.DIKS_SMALL_N]='n', [K.DIKS_SMALL_O]='o',
	[K.DIKS_SMALL_P]='p', [K.DIKS_SMALL_Q]='q', [K.DIKS_SMALL_R]='r',
	[K.DIKS_SMALL_S]='s', [K.DIKS_SMALL_T]='t', [K.DIKS_SMALL_U]='u',
	[K.DIKS_SMALL_V]='v', [K.DIKS_SMALL_W]='w', [K.DIKS_SMALL_X]='x',
	[K.DIKS_SMALL_Y]='y', [K.DIKS_SMALL_Z]='z',

	[K.DIKS_CAPITAL_A]='A', [K.DIKS_CAPITAL_B]='B', [K.DIKS_CAPITAL_C]='C',
	[K.DIKS_CAPITAL_D]='D', [K.DIKS_CAPITAL_E]='E', [K.DIKS_CAPITAL_F]='F',
	[K.DIKS_CAPITAL_G]='G', [K.DIKS_CAPITAL_H]='H', [K.DIKS_CAPITAL_I]='I',
	[K.DIKS_CAPITAL_J]='J', [K.DIKS_CAPITAL_K]='K', [K.DIKS_CAPITAL_L]='L',
	[K.DIKS_CAPITAL_M]='M', [K.DIKS_CAPITAL_N]='N', [K.DIKS_CAPITAL_O]='O',
	[K.DIKS_CAPITAL_P]='P', [K.DIKS_CAPITAL_Q]='Q', [K.DIKS_CAPITAL_R]='R',
	[K.DIKS_CAPITAL_S]='S', [K.DIKS_CAPITAL_T]='T', [K.DIKS_CAPITAL_U]='U',
	[K.DIKS_CAPITAL_V]='V', [K.DIKS_CAPITAL_W]='W', [K.DIKS_CAPITAL_X]='X',
	[K.DIKS_CAPITAL_Y]='Y', [K.DIKS_CAPITAL_Z]='Z',

	[K.DIKS_RETURN]='RETURN', [K.DIKS_BACKSPACE]='BACKSPACE',
	[K.DIKS_ESCAPE]='ESCAPE', [K.DIKS_SPACE]='SPACE',
	[K.DIKS_TAB]='TAB',

 	[K.DIKS_EXCLAMATION_MARK]='!', [K.DIKS_QUOTATION]='"',
	[K.DIKS_ASTERISK]='*', [K.DIKS_NUMBER_SIGN]='#',
	[K.DIKS_PARENTHESIS_LEFT]='(', [K.DIKS_PARENTHESIS_RIGHT]=')',
	[K.DIKS_PLUS_SIGN]='+', [K.DIKS_MINUS_SIGN]='-',
 	[K.DIKS_DOLLAR_SIGN]='$', [K.DIKS_PERCENT_SIGN]='%',
 	[K.DIKS_AMPERSAND]='&', [K.DIKS_APOSTROPHE]="'",
 	[K.DIKS_COMMA]=',', [K.DIKS_PERIOD]='.', [K.DIKS_SLASH]='/',

	[K.DIKS_COLON]=':',    [K.DIKS_LESS_THAN_SIGN]='<',
	[K.DIKS_SEMICOLON]=';', [K.DIKS_EQUALS_SIGN]='=',
	[K.DIKS_GREATER_THAN_SIGN]='>', [K.DIKS_QUESTION_MARK]='?',
 	[K.DIKS_AT]='@',

	[K.DIKS_SQUARE_BRACKET_LEFT]='[', [K.DIKS_SQUARE_BRACKET_RIGHT]=']',
	[K.DIKS_CURLY_BRACKET_LEFT]='{', [K.DIKS_CURLY_BRACKET_RIGHT]='}',
 	[K.DIKS_BACKSLASH]='\\', [K.DIKS_CIRCUMFLEX_ACCENT]='^',
 	[K.DIKS_GRAVE_ACCENT]='`', [K.DIKS_UNDERSCORE]='_',
 	[K.DIKS_VERTICAL_BAR]='|', [K.DIKS_TILDE]='~',
	[K.DIKS_DELETE]='DELETE', [K.DIKS_ENTER]='ENTER',
	[K.DIKS_CURSOR_LEFT]='LEFT', [K.DIKS_CURSOR_RIGHT]='RIGHT',
	[K.DIKS_CURSOR_UP]='UP', [K.DIKS_CURSOR_DOWN]='DOWN',

 	[K.DIKS_INSERT]='INSERT', [K.DIKS_HOME]='HOME',
	[K.DIKS_END]='END', [K.DIKS_PAGE_UP]='PAGE_UP',
	[K.DIKS_PAGE_DOWN]='PAGE_DOWN',

	[K.DIKS_F1]='F1', [K.DIKS_F2]='F2', [K.DIKS_F3]='F3',
	[K.DIKS_F4]='F4', [K.DIKS_F5]='F5', [K.DIKS_F6]='F6',
	[K.DIKS_F7]='F7', [K.DIKS_F8]='F8', [K.DIKS_F9]='F9',
	[K.DIKS_F10]='F10', [K.DIKS_F11]='F11', [K.DIKS_F12]='F12',

}

mouse_map = { [0]='left', [1]='right', [2]='middle' }

return ldirectfb
