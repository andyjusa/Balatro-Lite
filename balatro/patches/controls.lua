-- What a handheld needs from the game whatever it looks like.
--
-- This is neither a layout nor a performance choice: it is that a handheld has
-- no escape key, which is as true of the original Balatro layout as of the
-- small screen one -- that answer is about the desktop's arrangement of the
-- screen, not about the desktop's hardware. So it is loaded in both.
--
-- Which physical button is which used to be answered here too, from a list of
-- devices known to print their letters in the other order. The button setup the
-- launcher runs asks the device in front of the player instead, and corrects the
-- pad below the game where every prompt is drawn from, so the list is gone.

-- Start opens the pause menu, and closes it again. The stock controller binds
-- that to the escape key alone -- as a gamepad button Start does nothing outside
-- the splash screen -- so on a handheld there is no way to reach it. Two claims
-- come first, in the order the stock handler would resolve them: a tutorial step
-- owns the button while its Skip prompt is up, and any on-screen button that has
-- registered Start keeps it. Menus that refuse the escape key are left closed.
local original_button_press_update = Controller.button_press_update
function Controller:button_press_update(button, dt)
    if button == 'start' and not self.locks.frame then
        if G.OVERLAY_TUTORIAL then
            self.frame_buttonpress = true
            G.FUNCS.skip_tutorial_section()
            return
        end
        local claimed = self.button_registry[button]
        claimed = claimed and claimed[1] and not claimed[1].node.under_overlay
        if not claimed then
            self.frame_buttonpress = true
            if G.STATE == G.STATES.SPLASH then
                G:delete_run()
                G:main_menu()
            elseif not G.OVERLAY_MENU then
                G.FUNCS:options()
            elseif not G.OVERLAY_MENU.config.no_esc then
                G.FUNCS:exit_overlay_menu()
            end
            return
        end
    end
    return original_button_press_update(self, button, dt)
end

-- A loaded, active blind can pay $0 (for example a Small Blind at Red Stake
-- or above). The game's reward animation only reveals paying blinds, leaving
-- this one's name and icon above the screen after Continue.
local original_blind_load = Blind.load
function Blind:load(...)
    local result = original_blind_load(self, ...)
    if self.blind_set and self.name ~= '' and G.HUD_blind then
        G.HUD_blind.alignment.offset.y = 0
    end
    return result
end

-- GammaOS on RG Rotate exposes this pad's D-pad as buttons, without a hat.
-- The purchased game's older controller database replaces SDL's working map
-- with hat bindings during startup. Repair only these four inputs after that
-- import; leave face-button setup and every other device's mapping intact.
local original_start_up = Game.start_up
function Game:start_up(...)
    local result = original_start_up(self, ...)
    if love.system.getOS() == 'Android' then
        for _, joystick in ipairs(love.joystick.getJoysticks()) do
            local guid = joystick:getGUID()
            if guid == '05007ad15e040000130b0000ffff3f00' and
               joystick:getHatCount() == 0 then
                -- LÖVE uses one-based button indices (SDL b11 through b14).
                love.joystick.setGamepadMapping(guid, 'dpup', 'button', 12)
                love.joystick.setGamepadMapping(guid, 'dpdown', 'button', 13)
                love.joystick.setGamepadMapping(guid, 'dpleft', 'button', 14)
                love.joystick.setGamepadMapping(guid, 'dpright', 'button', 15)
            end
        end
    end
    return result
end
