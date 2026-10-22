-- Run from the repository root: lua tests/small_screen_packs.lua
-- No purchased game files are needed. These fixtures exercise the patch's
-- public update wrappers and the offset contract used by consumable callbacks.
local patch = arg[1] or 'balatro/patches/small_screen.lua'
local packs = {'arcana', 'spectral', 'standard', 'buffoon', 'celestial'}
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function close(a, b)
    return math.abs(a - b) < 0.00001
end

local function box(w, h, major, y)
    local b = {T={w=w, h=h}, VT={}, alignment={offset={x=0, y=y}},
        states={visible=true, collide={can=true}, hover={can=true}, click={can=true}}}
    function b:set_alignment(a)
        self.major, self.alignment.offset = a.major, a.offset
    end
    function b:align_to_major()
        self.T.x = self.major.T.x + (self.major.T.w-self.T.w)/2 +
            self.alignment.offset.x
        self.T.y = self.major.T.y + self.alignment.offset.y
    end
    function b:hard_set_VT()
        self.VT.x, self.VT.y = self.T.x, self.T.y
    end
    function b:recalculate()
        self.recalculations = (self.recalculations or 0)+1
    end
    b.major = major
    b:align_to_major()
    return b
end

local function setup(width, height)
    love = {graphics={getDimensions=function() return width, height end}}
    G = {CARD_W=2.4*35/41, CARD_H=2.4*47/41, FUNCS={}, UIDEF={}}
    Game, CardArea, DynaText, Card_Character, Card, UIBox = {}, {}, {}, {}, {}, {}
    Moveable = {extend=function() return {} end}
    function Game:update_shop() return 'shop update' end
    for _, pack in ipairs(packs) do
        -- Shape of the stock UIBox_dyn_container used by all five titles. The
        -- 30-tile filler must be removed before the engine calculates height.
        _G['create_UIBox_'..pack..'_pack'] = function(marker)
            return {config={marker=marker}, nodes={
                {config={minh=2}, nodes={}},
                {config={padding=0.03}, nodes={
                    {config={padding=0.05}, nodes={
                        {config={minh=30, padding=0.08}, nodes={
                            {config={minh=1.25}, nodes={}}
                        }}
                    }}
                }}
            }}
        end
        Game['update_'..pack..'_pack'] = function()
            -- Source pack updates hide the hand-anchored shop at 11 every frame.
            if G.shop then G.shop.alignment.offset.y = 11 end
            return 'pack update'
        end
    end
    dofile(patch)
    G.ROOM_ATTACH = {T={x=0, y=0, w=G.TILE_W, h=G.TILE_H}}
    G.hand = {T={x=0.2, y=G.TILE_H-0.95*G.CARD_H-0.62, w=6.8*G.CARD_W}}
    G.deck = {T={x=G.TILE_W-2.3}}
    G.shop = box(13, 7.5, G.ROOM_ATTACH, 11)
    local function node(visible, hover)
        return {states={visible=visible, hover={can=hover},
            collide={can=true}, click={can=true}, drag={can=false}}}
    end
    G.shop.UIRoot = {children={node(true, true)}}
    G.shop_jokers = node(true, false)
    G.shop_jokers.cards = {node(true, true)}
    G.shop_jokers.cards[1].children = {h_popup=node(false, true)}
    G.shop_vouchers = node(false, false)
    G.shop_booster = node(true, true)
    Game:update_shop(0)
end

for _, dimensions in ipairs({{720,720}, {1024,768}, {1280,720}, {1920,800}}) do
    for _, pack in ipairs(packs) do
        setup(dimensions[1], dimensions[2])
        local definition = _G['create_UIBox_'..pack..'_pack']('argument')
        local background = definition.nodes[2].nodes[1].nodes[1]
        check(background.config.minh == nil, pack..': 30-tile title filler removed')
        check(background.nodes[1].config.minh == 1.25 and
            definition.nodes[1].config.minh == 2 and
            definition.config.marker == 'argument', pack..': pack content retained')
        local update = Game['update_'..pack..'_pack']
        local shop_y = G.shop.T.y
        local original_top = G.hand.T.y-2.2
        -- Include a tall measured panel as well as the compact card/Skip row.
        for _, h in ipairs({5.1, 6.2}) do
            G.booster_pack = box(12, h, G.hand, -2.2)
            local b = G.booster_pack
            check(update(Game, 0) == 'pack update', pack..': source result')
            check(close(b.T.x+b.T.w/2, G.TILE_W/2), pack..': room centred')
            check(b.T.y+b.T.h <= G.TILE_H-0.2+0.00001, pack..': Skip stays on screen')
            check(b.T.y >= 0.2, pack..': cards stay on screen')
            if original_top+h <= G.TILE_H-0.2 then
                check(close(b.T.y, original_top), pack..': raised hand gap retained')
            end
            check(G.shop.T.y >= G.TILE_H, pack..': shop completely hidden')
            check(not G.shop.states.visible and not G.shop.states.collide.can and
                not G.shop.UIRoot.children[1].states.visible,
                pack..': shop UI hidden and disabled')
            check(not G.shop_jokers.states.visible and
                not G.shop_jokers.cards[1].states.visible and
                not G.shop_jokers.cards[1].states.hover.can and
                not G.shop_jokers.cards[1].children.h_popup.states.visible,
                pack..': separately drawn shop cards and tooltip hidden')

            -- use_card stashes the resting offset before sliding a consumable
            -- out; repeated pack frames must not show it or lose its return y.
            local offset = b.alignment.offset
            local resting = offset.y
            offset.py, offset.y = resting, 29
            local shop_offset = G.shop.alignment.offset
            shop_offset.py, shop_offset.y = shop_y, 29
            update(Game, 0)
            check(b.alignment.offset == offset and offset.y == 29 and
                offset.py == resting, pack..': consuming pack remains hidden')
            check(G.shop.alignment.offset == shop_offset and
                shop_offset.py == shop_y, pack..': shop return offset survives')

            -- A multiple-choice pack restores the same box for another choice.
            offset.y, offset.py = offset.py, nil
            update(Game, 0)
            check(close(b.T.y, G.hand.T.y+resting), pack..': next choice restored')

            -- Skip/end_consumeable exits without a py marker.
            offset.y = 9
            update(Game, 0)
            check(offset.y == 9, pack..': skip exit is not cancelled')
            b:align_to_major()
            check(b.T.y >= G.TILE_H, pack..': skip exit stays below screen')
            G.booster_pack = nil
            shop_offset.y, shop_offset.py = shop_offset.py, nil
            check(Game:update_shop(0) == 'shop update', pack..': shop source result')
            check(G.shop.recalculations == (h == 5.1 and 1 or 2),
                pack..': static shop UI re-laid out on return')
            check(close(G.shop.T.y, shop_y), pack..': shop returns after pack')
            check(G.shop.states.visible and G.shop.states.collide.can and
                G.shop.UIRoot.children[1].states.visible and
                G.shop_jokers.cards[1].states.visible and
                G.shop_jokers.cards[1].states.hover.can,
                pack..': shop UI and cards enabled after pack')
            check(not G.shop_vouchers.states.visible and
                not G.shop_jokers.states.hover.can and
                not G.shop_jokers.cards[1].states.drag.can and
                not G.shop_jokers.cards[1].children.h_popup.states.visible,
                pack..': previous hidden and disabled states retained')
            check(G.shop.T.y+G.shop.T.h <= G.TILE_H-0.2+0.00001,
                pack..': restored shop fits screen')
        end

        -- The shop's own consumable animation must also keep its temporary hide.
        local offset = G.shop.alignment.offset
        offset.py, offset.y = shop_y, 29
        Game:update_shop(0)
        check(offset.y == 29 and offset.py == shop_y, pack..': shop consuming hide')
        offset.y, offset.py = offset.py, nil
        Game:update_shop(0)
        check(close(G.shop.T.y, shop_y), pack..': shop consuming restore')
    end
end
print('small-screen pack contracts: '..checks..' checks passed')
