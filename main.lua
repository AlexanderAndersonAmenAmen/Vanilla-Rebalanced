local MOD = SMODS.current_mod

HNDS = HNDS or {}

SMODS.Atlas {
    key = 'ante_10_atlas',
    path = 'Ante10Blinds.png',
    px = 34,
    py = 34,
    frames = 21,
    fps = 10,
    atlas_table = 'ANIMATION_ATLAS',
}

SMODS.Sound {
    key = 'curse_used',
    path = 'CursedLaugh.ogg',
}

-- Self-contained copy of the Ante 10 boss system.
assert(SMODS.load_file('lib/devil_bosses.lua'))()
assert(SMODS.load_file('blinds/blind_devil.lua'))()
assert(SMODS.load_file('blinds/blind_forbidden_fruit.lua'))()
assert(SMODS.load_file('blinds/blind_perilous_pact.lua'))()
assert(SMODS.load_file('blinds/blind_sinful_soul.lua'))()
assert(SMODS.load_file('blinds/blind_wasted_wish.lua'))()
assert(SMODS.load_file('lib/platinum_support.lua'))()


MOD.optional_features = {
    retrigger_joker = true,
    object_weights = true,
}

local function is_playing_card(card)
    local set = card and card.ability and card.ability.set
    return set == 'Default' or set == 'Enhanced'
end

local function has_active_splash()
    if not SMODS.find_card then return false end
    local splashes = SMODS.find_card('j_splash') or {}
    return next(splashes) ~= nil
end

local function is_wild(card)
    return card and SMODS.has_enhancement and SMODS.has_enhancement(card, 'm_wild')
end

-- Wild Cards can never be debuffed. Splash protects all playing cards while active.
MOD.set_debuff = function(card)
    if is_playing_card(card) and (is_wild(card) or has_active_splash()) then
        return 'prevent_debuff'
    end
end

local function boss_blind_active()
    return G and G.GAME and G.GAME.blind and G.GAME.blind.get_type
        and G.GAME.blind:get_type() == 'Boss'
end

local function add_dollars(amount)
    G.GAME.dollar_buffer = (G.GAME.dollar_buffer or 0) + amount
    return {
        dollars = amount,
        func = function()
            G.E_MANAGER:add_event(Event({
                func = function()
                    G.GAME.dollar_buffer = 0
                    return true
                end
            }))
        end
    }
end

local function count_unique_suits(cards)
    if not cards then return 0 end
    local suits, wilds = {}, 0
    for _, playing_card in ipairs(cards) do
        if not playing_card.debuff and not (SMODS.has_no_suit and SMODS.has_no_suit(playing_card)) then
            if is_wild(playing_card) then
                wilds = wilds + 1
            elseif playing_card.base and playing_card.base.suit then
                suits[playing_card.base.suit] = true
            end
        end
    end
    local count = 0
    for _ in pairs(suits) do count = count + 1 end
    return math.min(4, count + wilds)
end

local function selected_flower_pot_mult()
    if not (G and G.hand and G.hand.highlighted and #G.hand.highlighted > 0) then return 0 end
    if not (G.FUNCS and type(G.FUNCS.get_poker_hand_info) == 'function') then return 0 end

    -- The fourth return value is the actual scoring hand. This excludes extra
    -- highlighted cards that are legal to play but do not contribute to the
    -- detected poker hand (for example, a fifth off-suit card beside a Pair).
    local ok, _, _, _, scoring_hand = pcall(G.FUNCS.get_poker_hand_info, G.hand.highlighted)
    if not ok or type(scoring_hand) ~= 'table' then return 0 end
    return count_unique_suits(scoring_hand)
end

local function stone_card_tally()
    local tally = 0
    for _, playing_card in ipairs((G and G.playing_cards) or {}) do
        if SMODS.has_enhancement(playing_card, 'm_stone') then tally = tally + 1 end
    end
    return tally
end

local function reset_mail_rank()
    if not (G and G.GAME) then return end
    G.GAME.current_round = G.GAME.current_round or {}
    local state = { rank = 'Ace', id = 14 }
    local valid_cards = {}
    for _, playing_card in ipairs(G.playing_cards or {}) do
        if not (SMODS.has_no_rank and SMODS.has_no_rank(playing_card)) then
            valid_cards[#valid_cards + 1] = playing_card
        end
    end
    if #valid_cards > 0 then
        local ante = G.GAME.round_resets and G.GAME.round_resets.ante or 0
        local picked = pseudorandom_element(valid_cards, 'vrb_mail_' .. ante)
        if picked and picked.base then
            state.rank = picked.base.value or state.rank
            state.id = picked.base.id or (picked.get_id and picked:get_id()) or state.id
        end
    end
    G.GAME.current_round.vrb_mail_card = state
end

local function current_mail_rank()
    if not (G and G.GAME) then return { rank = 'Ace', id = 14 } end
    G.GAME.current_round = G.GAME.current_round or {}
    if not G.GAME.current_round.vrb_mail_card then reset_mail_rank() end
    return G.GAME.current_round.vrb_mail_card or { rank = 'Ace', id = 14 }
end

-- Illusion and Magic Trick share one staged shop-card pipeline.
-- Rank, suit, and enhancement are supplied during construction. Edition and
-- seal are applied silently in the immediately following modify context,
-- before create_shop_card_ui is called. This avoids beta-1620a's shop UI race
-- when a playing card receives multiple animated modifiers at once.
local pending_shop_playing_cards = {}

MOD.reset_game_globals = function(run_start)
    reset_mail_rank()
    pending_shop_playing_cards = {}
    if G and G.GAME then G.GAME.vrb_shop_roll_counter = 0 end
end

local function copy_permanent_card_values(target, source)
    if not (target and target.ability and source and source.ability) then return end
    for _, key in ipairs({ 'perma_bonus', 'perma_mult', 'perma_x_mult', 'perma_h_x_mult', 'perma_p_dollars' }) do
        target.ability[key] = source.ability[key]
    end
end

local function is_modified_playing_card(card)
    return card and (
        (card.ability and card.ability.set == 'Enhanced')
        or card.edition ~= nil
        or card.seal ~= nil
    )
end

local function illusion_source_pool()
    local all_cards, modified = {}, {}
    for _, card in ipairs((G and G.playing_cards) or {}) do
        if is_playing_card(card) then
            all_cards[#all_cards + 1] = card
            if is_modified_playing_card(card) then modified[#modified + 1] = card end
        end
    end
    return #modified > 0 and modified or all_cards
end

local function shop_roll_counter()
    G.GAME.vrb_shop_roll_counter = (G.GAME.vrb_shop_roll_counter or 0) + 1
    return G.GAME.vrb_shop_roll_counter
end

local function source_enhancement_key(source)
    local center = source and source.config and source.config.center
    if center and center.key and center.key ~= 'c_base' then return center.key end
end

local function build_shop_playing_card_flags(use_illusion, use_magic_trick)
    local roll = shop_roll_counter()
    local ante = G.GAME.round_resets and G.GAME.round_resets.ante or 0
    local source
    local flags = {
        -- Steamodded may already have polled an Enhanced key because Illusion
        -- is active. Explicitly clear that forced key; the final enhancement
        -- below is the only center that should be used.
        key = false,
        set = 'Base',
        key_append = 'vrb_shop_card_' .. ante .. '_' .. roll,
    }
    local pending = {}

    if use_illusion then
        local pool = illusion_source_pool()
        if #pool > 0 then
            source = pseudorandom_element(pool, pseudoseed('vrb_illusion_' .. ante .. '_' .. roll))
            if source and source.base then
                flags.suit = source.base.suit
                flags.rank = source.base.value
                local enhancement = source_enhancement_key(source)
                if enhancement then
                    flags.set = 'Enhanced'
                    flags.enhancement = enhancement
                end
                pending.edition = source.edition and copy_table(source.edition) or nil
                pending.seal = source.seal
                pending.source = source
            end
        end
    end

    if use_magic_trick then
        local enhancement = SMODS.poll_enhancement({
            key = 'vrb_magic_enhancement_' .. ante .. '_' .. roll,
        })
        if enhancement and G.P_CENTERS[enhancement] then
            flags.set = 'Enhanced'
            flags.enhancement = enhancement
        end

        local edition = SMODS.poll_edition({
            key = 'vrb_magic_edition_' .. ante .. '_' .. roll,
            mod = 2,
            no_negative = true,
        })
        if edition then pending.edition = edition end

        local seal = SMODS.poll_seal({
            key = 'vrb_magic_seal_' .. ante .. '_' .. roll,
            mod = 10,
        })
        if seal then pending.seal = seal end
    end

    pending_shop_playing_cards[#pending_shop_playing_cards + 1] = pending
    return flags
end

local function finish_shop_playing_card(card)
    local pending = table.remove(pending_shop_playing_cards, 1) or {}
    if not is_playing_card(card) then return end

    if pending.source then copy_permanent_card_values(card, pending.source) end

    -- Card:set_edition arguments are (edition, immediate, silent).
    -- Card:set_seal arguments are (seal, silent, immediate).
    -- Both calls are deliberately silent/immediate so no controller locks or
    -- delayed modifier animations can interfere with create_shop_card_ui.
    if pending.edition then card:set_edition(pending.edition, true, true) end
    if pending.seal then card:set_seal(pending.seal, true, true) end

    card.no_ui = nil
    if card.set_cost then card:set_cost() end
end

local function perishable_tally(card)
    return card and card.ability and card.ability.perish_tally
end

-- Steamodded beta-1620a can select the Enhanced shop object type and then
-- perform a non-guaranteed enhancement poll. A failed poll leaves the card
-- key nil and crashes inside create_card before Illusion can modify the card.
-- Only make that exact shop poll guaranteed; all other enhancement polls keep
-- their normal probabilities.
if not SMODS.vrb_enhanced_shop_poll_fix then
    local poll_object_ref = SMODS.poll_object
    SMODS.poll_object = function(args)
        if type(args) == 'table'
            and args.type == 'Enhanced'
            and args.append == 'sho'
            and args.guaranteed == nil
            and G and G.GAME and G.GAME.used_vouchers
            and (G.GAME.used_vouchers.v_illusion or G.GAME.used_vouchers.v_magic_trick)
        then
            local safe_args = {}
            for key, value in pairs(args) do safe_args[key] = value end
            safe_args.guaranteed = true
            return poll_object_ref(safe_args)
        end
        return poll_object_ref(args)
    end
    SMODS.vrb_enhanced_shop_poll_fix = true
end

local function extra_value(card, key, fallback)
    local extra = card and card.ability and card.ability.extra
    if type(extra) == 'table' and extra[key] ~= nil then return extra[key] end
    if type(extra) == 'number' then return extra end
    return fallback
end

-- Stakes ---------------------------------------------------------------------
SMODS.Stake:take_ownership('blue', {
    modifiers = function()
        G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
    end,
})

SMODS.Stake:take_ownership('purple', {
    modifiers = function()
        G.GAME.modifiers.enable_perishables_in_shop = true
    end,
})

SMODS.Stake:take_ownership('orange', {
    modifiers = function()
        G.GAME.modifiers.enable_rentals_in_shop = true
    end,
})

SMODS.Stake:take_ownership('gold', {
    modifiers = function()
        G.GAME.win_ante = 10
        -- Gold Stake keeps the Ante 10 victory condition and custom bosses,
        -- but no longer enables or retains the Blind Upgrade mechanic.
        G.GAME.hnds_platinum_active = false
        G.GAME.hnds_upgraded_blinds = nil
        G.GAME.hnds_blind_upgrades = nil
        G.GAME.hnds_platinum_blind_replacements = nil
        G.GAME.hnds_platinum_boss_stacks = nil
    end,
})

-- Sticker --------------------------------------------------------------------
SMODS.Sticker:take_ownership('perishable', {
    loc_vars = function(self, info_queue, card)
        return { vars = { G.GAME and G.GAME.perishable_rounds or 5, perishable_tally(card) or 0 } }
    end,
    calculate = function(self, card, context)
        if context.end_of_round and not context.repetition and not context.individual then
            local expires_now = card.ability.perishable and card.ability.perish_tally == 1
            card:calculate_perishable()
            if expires_now then card:set_edition('e_negative', true) end
        end
    end,
})

-- Enhancement ----------------------------------------------------------------
SMODS.Enhancement:take_ownership('wild', {
    any_suit = true,
})

-- Jokers ---------------------------------------------------------------------
SMODS.Joker:take_ownership('matador', {
    blueprint_compat = true,
    config = { extra = 5 },
    loc_vars = function(self, info_queue, card)
        return { vars = { extra_value(card, 'dollars', 5) } }
    end,
    calculate = function(self, card, context)
        if context.before and boss_blind_active() then
            return add_dollars(extra_value(card, 'dollars', 5))
        end
    end,
})

SMODS.Joker:take_ownership('superposition', {
    blueprint_compat = true,
    calculate = function(self, card, context)
        if context.joker_main and next(context.poker_hands['Straight'])
            and #G.consumeables.cards + G.GAME.consumeable_buffer < G.consumeables.config.card_limit
        then
            local has_ace = false
            for _, scoring_card in ipairs(context.scoring_hand) do
                if scoring_card:get_id() == 14 then has_ace = true break end
            end
            if has_ace then
                G.GAME.consumeable_buffer = G.GAME.consumeable_buffer + 1
                G.E_MANAGER:add_event(Event({
                    func = function()
                        SMODS.add_card({ set = 'Tarot', key = 'c_fool', key_append = 'vrb_superposition' })
                        G.GAME.consumeable_buffer = 0
                        return true
                    end
                }))
                return { message = localize('k_plus_tarot'), colour = G.C.SECONDARY_SET.Tarot }
            end
        end
    end,
})

SMODS.Joker:take_ownership('splash', {
    blueprint_compat = false,
    calculate = function(self, card, context)
        if context.modify_scoring_hand and not context.blueprint then
            return { add_to_hand = true }
        end
    end,
})

SMODS.Joker:take_ownership('erosion', { rarity = 1, cost = 4 })

SMODS.Joker:take_ownership('flower_pot', {
    blueprint_compat = true,
    loc_vars = function(self, info_queue, card)
        local current = selected_flower_pot_mult()
        return {
            key = current > 0 and 'j_flower_pot' or 'j_vrb_flower_pot_none',
            vars = { current },
        }
    end,
    calculate = function(self, card, context)
        if context.joker_main then
            local unique = count_unique_suits(context.scoring_hand)
            if unique > 0 then return { xmult = unique } end
        end
    end,
})

SMODS.Joker:take_ownership('baron', { rarity = 2 })
SMODS.Joker:take_ownership('mime', { rarity = 3 })
SMODS.Joker:take_ownership('mail', {
    rarity = 2,
    blueprint_compat = true,
    config = { extra = 3 },
    loc_vars = function(self, info_queue, card)
        local mail = current_mail_rank()
        return { vars = { extra_value(card, 'dollars', 3), localize(mail.rank, 'ranks') } }
    end,
    calculate = function(self, card, context)
        local mail = current_mail_rank()
        if context.discard and context.other_card and not context.other_card.debuff
            and context.other_card:get_id() == mail.id
        then
            return add_dollars(extra_value(card, 'dollars', 3))
        end
    end,
})

SMODS.Joker:take_ownership('stone', {
    blueprint_compat = true,
    config = { extra = 30 },
    loc_vars = function(self, info_queue, card)
        if G and G.P_CENTERS and G.P_CENTERS.m_stone then
            info_queue[#info_queue + 1] = G.P_CENTERS.m_stone
        end
        local chips = extra_value(card, 'chips', 30)
        local tally = stone_card_tally()
        return { vars = { chips, chips * tally } }
    end,
    calculate = function(self, card, context)
        if context.joker_main then
            return { chips = extra_value(card, 'chips', 30) * stone_card_tally() }
        end
    end,
})

local suit_jokers = {
    greedy_joker = 'Diamonds',
    lusty_joker = 'Hearts',
    wrathful_joker = 'Spades',
    gluttenous_joker = 'Clubs',
}
for key, suit in pairs(suit_jokers) do
    local owned_suit = suit
    SMODS.Joker:take_ownership(key, {
        blueprint_compat = true,
        config = { extra = { s_mult = 4, suit = owned_suit } },
        loc_vars = function(self, info_queue, card)
            return { vars = { extra_value(card, 's_mult', 4) } }
        end,
        calculate = function(self, card, context)
            if context.individual and context.cardarea == G.play
                and context.other_card:is_suit(card.ability.extra.suit)
            then
                return { mult = card.ability.extra.s_mult }
            end
        end,
    })
end

SMODS.Joker:take_ownership('throwback', {
    blueprint_compat = true,
    config = { extra = 0.5, x_mult = 1 },
    loc_vars = function(self, info_queue, card)
        local skips = G and G.GAME and G.GAME.skips or 0
        local gain = extra_value(card, 'xmult', 0.5)
        return { vars = { gain, 1 + skips * gain } }
    end,
    calculate = function(self, card, context)
        if context.skip_blind and not context.blueprint then
            return {
                message = localize({ type = 'variable', key = 'a_xmult', vars = { 1 + G.GAME.skips * extra_value(card, 'xmult', 0.5) } })
            }
        end
        if context.joker_main then
            return { xmult = 1 + G.GAME.skips * extra_value(card, 'xmult', 0.5) }
        end
    end,
})

SMODS.Joker:take_ownership('seeing_double', {
    blueprint_compat = true,
    config = { extra = 1 },
    loc_vars = function(self, info_queue, card)
        return { vars = {} }
    end,
    calculate = function(self, card, context)
        if context.repetition
            and (context.cardarea == G.play or context.cardarea == G.hand)
            and context.other_card and context.other_card:get_id() == 7
            and not context.other_card.debuff
        then
            local repetitions = extra_value(card, 'repetitions', 1)
            if context.other_card:is_suit('Clubs') then
                repetitions = repetitions + 1
            end
            return { repetitions = repetitions }
        end
    end,
})

SMODS.Joker:take_ownership('ring_master', {
    blueprint_compat = false,
    calculate = function(self, card, context)
        if context.modify_weights and context.pool then
            local owned = {}
            for _, area in ipairs({ G.jokers, G.consumeables }) do
                for _, owned_card in ipairs((area and area.cards) or {}) do
                    local key = owned_card.config and owned_card.config.center and owned_card.config.center.key
                    if key then owned[key] = true end
                end
            end
            for key in pairs(owned) do
                local entry = context.pool[key]
                if entry and entry.weight then entry.weight = entry.weight * 2 end
            end
        end
    end,
})

SMODS.Joker:take_ownership('hiker', {
    blueprint_compat = true,
    config = { extra = 5 },
    loc_vars = function(self, info_queue, card)
        return { vars = { extra_value(card, 'chips', 5) } }
    end,
    calculate = function(self, card, context)
        if context.before and context.scoring_hand then
            local upgraded = false
            for _, scoring_card in ipairs(context.scoring_hand) do
                if not scoring_card.debuff then
                    scoring_card.ability.perma_bonus = (scoring_card.ability.perma_bonus or 0) + extra_value(card, 'chips', 5)
                    upgraded = true
                end
            end
            if upgraded then return { message = localize('k_upgrade_ex'), colour = G.C.CHIPS } end
        end
    end,
})

-- Vouchers -------------------------------------------------------------------
local function handle_shop_playing_card_context(context, use_illusion, use_magic_trick)
    if context.create_shop_card
        and (context.set == 'Base' or context.set == 'Enhanced')
    then
        return {
            shop_create_flags = build_shop_playing_card_flags(use_illusion, use_magic_trick),
        }
    elseif context.modify_shop_card then
        finish_shop_playing_card(context.card)
    end
end

SMODS.Voucher:take_ownership('magic_trick', {
    calculate = function(self, card, context)
        local illusion_active = G and G.GAME and G.GAME.used_vouchers
            and G.GAME.used_vouchers.v_illusion
        return handle_shop_playing_card_context(context, illusion_active, true)
    end,
})

SMODS.Voucher:take_ownership('illusion', {
    calculate = function(self, card, context)
        -- Illusion normally implies Magic Trick is also active, so Magic Trick
        -- owns the combined pipeline. Keep this fallback for debug-spawned or
        -- externally granted Illusion runs where the prerequisite is absent.
        local magic_active = G and G.GAME and G.GAME.used_vouchers
            and G.GAME.used_vouchers.v_magic_trick
        if not magic_active then
            return handle_shop_playing_card_context(context, true, false)
        end
    end,
})

-- Spectral cards --------------------------------------------------------------
SMODS.Consumable:take_ownership('ouija', {
    config = { max_highlighted = 1, mod_num = 1 },
    loc_vars = function(self, info_queue, card)
        return { vars = { 1 } }
    end,
    can_use = function(self, card)
        return G.hand and #G.hand.cards > 1 and #G.hand.highlighted == 1
    end,
    use = function(self, card, area, copier)
        local selected = G.hand.highlighted[1]
        local rank = selected and selected.base and selected.base.value
        if not rank then return end

        G.E_MANAGER:add_event(Event({
            trigger = 'after', delay = 0.4,
            func = function()
                play_sound('tarot1')
                card:juice_up(0.3, 0.5)
                return true
            end
        }))
        for i = 1, #G.hand.cards do
            local target = G.hand.cards[i]
            local percent = 1.15 - (i - 0.999) / (#G.hand.cards - 0.998) * 0.3
            G.E_MANAGER:add_event(Event({
                trigger = 'after', delay = 0.15,
                func = function()
                    target:flip()
                    play_sound('card1', percent)
                    target:juice_up(0.3, 0.3)
                    return true
                end
            }))
        end
        for _, target in ipairs(G.hand.cards) do
            G.E_MANAGER:add_event(Event({
                func = function()
                    SMODS.change_base(target, nil, rank)
                    return true
                end
            }))
        end
        G.hand:change_size(-1)
        for i = 1, #G.hand.cards do
            local target = G.hand.cards[i]
            local percent = 0.85 + (i - 0.999) / (#G.hand.cards - 0.998) * 0.3
            G.E_MANAGER:add_event(Event({
                trigger = 'after', delay = 0.15,
                func = function()
                    target:flip()
                    play_sound('tarot2', percent, 0.6)
                    target:juice_up(0.3, 0.3)
                    return true
                end
            }))
        end
        G.E_MANAGER:add_event(Event({
            trigger = 'after', delay = 0.2,
            func = function() G.hand:unhighlight_all() return true end
        }))
        delay(0.5)
    end,
})

SMODS.Consumable:take_ownership('black_hole', {
    use = function(self, card, area, copier)
        update_hand_text({ sound = 'button', volume = 0.7, pitch = 0.8, delay = 0.3 },
            { handname = localize('k_all_hands'), chips = '...', mult = '...', level = '' })
        G.E_MANAGER:add_event(Event({
            trigger = 'after', delay = 0.2,
            func = function()
                play_sound('tarot1')
                card:juice_up(0.8, 0.5)
                G.TAROT_INTERRUPT_PULSE = true
                return true
            end
        }))
        update_hand_text({ delay = 0 }, { mult = 'X2', chips = 'X2', StatusText = true })
        delay(1.0)
        for _, hand in ipairs(G.handlist or {}) do
            local data = G.GAME.hands[hand]
            if data and data.level and data.level > 0 then
                SMODS.smart_level_up_hand(card, hand, true, data.level)
            end
        end
        G.TAROT_INTERRUPT_PULSE = nil
        update_hand_text({ sound = 'button', volume = 0.7, pitch = 1.1, delay = 0 },
            { mult = 0, chips = 0, handname = '', level = '' })
    end,
    can_use = function(self, card) return true end,
})

-- Planet level gains ----------------------------------------------------------
SMODS.PokerHand:take_ownership('Full House', { l_mult = 4, l_chips = 40 })
SMODS.PokerHand:take_ownership('Flush House', { l_mult = 5, l_chips = 50 })
SMODS.PokerHand:take_ownership('Straight Flush', { l_mult = 6, l_chips = 60 })
