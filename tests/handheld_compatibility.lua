-- No purchased assets required: lua tests/handheld_compatibility.lua
local patch = arg[1] or 'balatro/patches/controls.lua'
local matching_guid = '05007ad15e040000130b0000ffff3f00'
local function setup(os_name, guid, hats)
    local bindings = {dpup='hat', dpdown='hat', dpleft='hat', dpright='hat', a=7}
    local started, writes = false, 0
    Controller = {button_press_update=function() end}
    Game = {start_up=function(_, marker) started=true; return marker end}
    -- Reproduce the source's reward-dependent HUD placement on Continue.
    Blind = {load=function(self, saved)
        self.name, self.blind_set = saved.name, saved.active
        if saved.reward > 0 then G.HUD_blind.alignment.offset.y = 0 end
        return 'loaded'
    end}
    G = {HUD_blind={alignment={offset={y=-10}}}}
    love = {
        system={getOS=function() return os_name end},
        joystick={
            getJoysticks=function() return {{
                getGUID=function() return guid end,
                getHatCount=function() return hats end,
            }} end,
            setGamepadMapping=function(actual_guid, input, kind, index)
                assert(started, 'mapping must follow the source database import')
                assert(actual_guid == guid and kind == 'button')
                writes = writes + 1
                bindings[input] = index
            end,
        },
    }
    dofile(patch)
    return bindings, function() return writes end
end

for _, saved in ipairs({
    {name='Small Blind', active=true, reward=0, expected=0},
    {name='Big Blind', active=true, reward=4, expected=0},
    {name='The Hook', active=true, reward=0, expected=0},
    {name='', active=false, reward=0, expected=-10},
    {name='Unknown', active=false, reward=0, expected=-10},
}) do
    setup('Android', matching_guid, 0)
    local blind = setmetatable({}, {__index=Blind})
    assert(blind:load(saved) == 'loaded', 'source return must survive')
    assert(G.HUD_blind.alignment.offset.y == saved.expected,
        saved.name..': active blind visibility must not depend on its reward')
end

for _, device in ipairs({
    {'Android', matching_guid, 0, true},
    {'Android', matching_guid, 1, false},
    {'Android', 'another-controller-guid', 0, false},
    {'Linux', matching_guid, 0, false},
}) do
    local bindings, writes = setup(device[1], device[2], device[3])
    assert(Game:start_up('started') == 'started', 'source startup result')
    assert(bindings.a == 7, 'face-button calibration must survive')
    assert(writes() == (device[4] and 4 or 0), 'only the affected pad is changed')
    if device[4] then
        assert(bindings.dpup == 12 and bindings.dpdown == 13 and
            bindings.dpleft == 14 and bindings.dpright == 15,
            'D-pad must use the observed Android button indices')
    else
        assert(bindings.dpup == 'hat', 'other mappings must remain unchanged')
    end
end
print('Handheld HUD and controller regressions passed')
