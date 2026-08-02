--[[
We have a lot of hooks here, they do global stuff and helps with specifit effects from Jokers, Blinds and more

Sections:
  Badge colour
  Cursed Sticker exclusivity
  Platinum Stake
  Career stats & card destruction unlocks (Energized, Last Laugh)
  Black Seal & voucher card destruction / scoring
  Card cost modifications (Coffee Break, Art, Premium Deck, Curses)
  Shop card creation (Most Wanted, Blood Stake curses)
  Krusty food negative edition
  DNA Tag joker copy
  Circus Deck (find_joker extension)
  Crystal Deck (double-showdown boss selection)
  Challenge description tab edition patch
  Impostor rank-spoofing system
  Base blind increase curse (price_ante_scaling)
  end_round dispatcher (calls per-subsystem functions)
  Blind.set_blind dispatcher (calls per-subsystem functions)
]]




-------------------------------------------------------------------
-- Handsome Devils hooks
-------------------------------------------------------------------

HNDS = HNDS or {}



-------------------------------------------------------------------
-- Devil system
--
-- main.lua already loads lib/devil_bosses.lua before blinds/blind_devil.lua.
-- Do not load either file again here; double registration corrupts state and
-- makes debugging the blind much harder.
-------------------------------------------------------------------

-------------------------------------------------------------------
-- ANTE 10 SHOWDOWN BOSS POOL
-------------------------------------------------------------------

local get_new_boss_ref = get_new_boss

HNDS.ANTE_10_BOSS_POOL = HNDS.ANTE_10_BOSS_POOL or {
    "bl_vrb_blind_devil",
    "bl_vrb_forbidden_fruit",
    "bl_vrb_perilous_pact",
    "bl_vrb_sinful_soul",
    "bl_vrb_wasted_wish",
}

local function get_ante_10_boss()
    local pool = {}
    for _, key in ipairs(HNDS.ANTE_10_BOSS_POOL) do
        if G.P_BLINDS and G.P_BLINDS[key] then
            pool[#pool + 1] = key
        end
    end

    if #pool == 0 then return get_new_boss_ref() end

    local chosen = pseudorandom_element(pool, pseudoseed("hnds_ante_10_boss"))
        or pool[1]

    if HNDS.set_wasted_wish_active then
        HNDS.set_wasted_wish_active(chosen == "bl_vrb_wasted_wish")
    end

    if chosen == "bl_vrb_blind_devil" and HNDS.prepare_devil_encounter then
        HNDS.prepare_devil_encounter()
    end

    return chosen
end

local function hnds_crystal_replaces_ante_8_showdown()
    if not (G and G.GAME and G.GAME.round_resets) then return false end
    local modifiers = G.GAME.modifiers or {}
    local selected_back = G.GAME.selected_back and G.GAME.selected_back.effect
        and G.GAME.selected_back.effect.center
    local crystal_deck = modifiers.hnds_crystal_ante_8_replacement == true
        or (selected_back and selected_back.key == "b_hnds_crystal")
    -- Crystal only replaces the normal Ante 8 showdown. Platinum and higher
    -- move the run's showdown/win Ante to 10, so Ante 8 must remain an ordinary
    -- Boss Blind on those stakes.
    return crystal_deck
        and G.GAME.round_resets.ante == 8
        and G.GAME.win_ante == 8
end

function get_new_boss()
    if G.GAME
        and not G.GAME.hnds_bypass_ante_10_force
        and G.GAME.round_resets
        and (hnds_crystal_replaces_ante_8_showdown()
            or (G.GAME.round_resets.ante == 10 and G.GAME.win_ante == 10))
    then
        return get_ante_10_boss()
    end

    return get_new_boss_ref()
end

HNDS.get_new_boss_unforced = function()
    if not (G and G.GAME) then return get_new_boss_ref() end

    local previous = G.GAME.hnds_bypass_ante_10_force
    G.GAME.hnds_bypass_ante_10_force = true
    local ok, boss = pcall(get_new_boss)
    G.GAME.hnds_bypass_ante_10_force = previous
    if not ok then error(boss) end
    return boss
end

-------------------------------------------------------------------
-- ANTE 10 GLOBAL BOSS SUPPORT
-------------------------------------------------------------------

-- Perilous Pact calls this from a narrow Lovely patch at the final hand-score
-- addition. Keeping the cap here makes it compatible with ordinary numbers
-- and with Big-number mods that overload comparison/arithmetic operators.
function HNDS.cap_perilous_pact_score(score)
    if not (G and G.GAME and G.GAME.blind and not G.GAME.blind.disabled) then
        return score
    end

    local blind_center = G.GAME.blind.config and G.GAME.blind.config.blind
    local blind_key = blind_center and blind_center.key
    local is_perilous = G.GAME.hnds_perilous_pact_active
        or blind_key == "bl_vrb_perilous_pact"
        or blind_key == "perilous_pact"
    if not is_perilous then return score end

    local cap = G.GAME.blind.chips * 0.50
    local ok, exceeds = pcall(function()
        local lhs = type(to_big) == "function" and to_big(score) or score
        local rhs = type(to_big) == "function" and to_big(cap) or cap
        return lhs > rhs
    end)
    if ok and exceeds then return cap end
    return score
end

local function hnds_copy_table_shallow(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function hnds_wasted_wish_fake_voucher(center, key)
    local config = center and center.config or {}
    local ability = type(copy_table) == "function" and copy_table(config)
        or hnds_copy_table_shallow(config)
    return {
        ability = ability,
        config = { center = center, center_key = key },
    }
end

local function hnds_wasted_wish_unredeem_custom_vouchers(vouchers)
    local undone = {}
    for key, owned in pairs(vouchers or {}) do
        local center = owned and G.P_CENTERS and G.P_CENTERS[key]
        local slot_voucher = key == "v_crystal_ball"
            or key == "v_antimatter"
        if not slot_voucher
            and center and type(center.unredeem) == "function"
        then
            local fake = hnds_wasted_wish_fake_voucher(center, key)
            local ok = pcall(center.unredeem, center, fake)
            if ok then undone[key] = true end
        end
    end
    return undone
end

local function hnds_wasted_wish_redeem_custom_vouchers(vouchers, undone)
    for key, was_undone in pairs(undone or {}) do
        local center = was_undone and vouchers and vouchers[key]
            and G.P_CENTERS and G.P_CENTERS[key]
        if center and type(center.redeem) == "function" then
            local fake = hnds_wasted_wish_fake_voucher(center, key)
            pcall(center.redeem, center, fake)
        end
    end
end

local function hnds_wasted_wish_has(vouchers, key)
    return vouchers and vouchers[key] and true or false
end

local function hnds_wasted_wish_extra(key, fallback)
    local center = G and G.P_CENTERS and G.P_CENTERS[key]
    local extra = center and center.config and center.config.extra
    if type(extra) == "number" then return extra end
    if type(extra) == "table" then
        return tonumber(extra.hands or extra.discards or extra.slots
            or extra.size or extra.deduction or extra.shop_size) or fallback
    end
    return fallback
end

local function hnds_wasted_wish_build_adjustments(vouchers)
    local adjustments = {
        hands = 0,
        discards = 0,
        hand_size = 0,
        consumable_slots = 0,
        joker_slots = 0,
        shop_size = 0,
        reroll_cost = 0,
    }

    for _, key in ipairs({ "v_grabber", "v_nacho_tong" }) do
        if hnds_wasted_wish_has(vouchers, key) then
            adjustments.hands = adjustments.hands
                - hnds_wasted_wish_extra(key, 1)
        end
    end
    if hnds_wasted_wish_has(vouchers, "v_hieroglyph") then
        adjustments.hands = adjustments.hands
            + hnds_wasted_wish_extra("v_hieroglyph", 1)
    end

    for _, key in ipairs({ "v_wasteful", "v_recyclomancy" }) do
        if hnds_wasted_wish_has(vouchers, key) then
            adjustments.discards = adjustments.discards
                - hnds_wasted_wish_extra(key, 1)
        end
    end
    if hnds_wasted_wish_has(vouchers, "v_petroglyph") then
        adjustments.discards = adjustments.discards
            + hnds_wasted_wish_extra("v_petroglyph", 1)
    end

    for _, key in ipairs({ "v_paint_brush", "v_palette" }) do
        if hnds_wasted_wish_has(vouchers, key) then
            adjustments.hand_size = adjustments.hand_size
                - hnds_wasted_wish_extra(key, 1)
        end
    end

    if hnds_wasted_wish_has(vouchers, "v_crystal_ball") then
        adjustments.consumable_slots = adjustments.consumable_slots - 1
    end
    if hnds_wasted_wish_has(vouchers, "v_antimatter") then
        adjustments.joker_slots = adjustments.joker_slots - 1
    end

    for _, key in ipairs({ "v_overstock_norm", "v_overstock_plus" }) do
        if hnds_wasted_wish_has(vouchers, key) then
            adjustments.shop_size = adjustments.shop_size
                - hnds_wasted_wish_extra(key, 1)
        end
    end

    for _, key in ipairs({ "v_reroll_surplus", "v_reroll_glut" }) do
        if hnds_wasted_wish_has(vouchers, key) then
            adjustments.reroll_cost = adjustments.reroll_cost
                + hnds_wasted_wish_extra(key, 2)
        end
    end

    return adjustments
end

local function hnds_wasted_wish_snapshot_overrides(vouchers)
    local snapshot = {}
    local function save(field)
        snapshot[field] = G.GAME[field]
    end

    if hnds_wasted_wish_has(vouchers, "v_clearance_sale")
        or hnds_wasted_wish_has(vouchers, "v_liquidation")
    then
        save("discount_percent")
        G.GAME.discount_percent = 0
        for _, card in pairs(G.I and G.I.CARD or {}) do
            if card.set_cost then card:set_cost() end
        end
    end

    if hnds_wasted_wish_has(vouchers, "v_hone")
        or hnds_wasted_wish_has(vouchers, "v_glow_up")
    then
        save("edition_rate")
        G.GAME.edition_rate = 1
    end

    if hnds_wasted_wish_has(vouchers, "v_tarot_merchant")
        or hnds_wasted_wish_has(vouchers, "v_tarot_tycoon")
    then
        save("tarot_rate")
        G.GAME.tarot_rate = 4
    end

    if hnds_wasted_wish_has(vouchers, "v_planet_merchant")
        or hnds_wasted_wish_has(vouchers, "v_planet_tycoon")
    then
        save("planet_rate")
        G.GAME.planet_rate = 4
    end

    if hnds_wasted_wish_has(vouchers, "v_magic_trick")
        or hnds_wasted_wish_has(vouchers, "v_illusion")
    then
        save("playing_card_rate")
        G.GAME.playing_card_rate = 0
    end

    if hnds_wasted_wish_has(vouchers, "v_seed_money")
        or hnds_wasted_wish_has(vouchers, "v_money_tree")
    then
        save("interest_cap")
        G.GAME.interest_cap = 25
    end

    return snapshot
end

local function hnds_wasted_wish_restore_overrides(snapshot)
    for field, value in pairs(snapshot or {}) do
        G.GAME[field] = value
    end
    if snapshot and snapshot.discount_percent ~= nil then
        for _, card in pairs(G.I and G.I.CARD or {}) do
            if card.set_cost then card:set_cost() end
        end
    end
end

local function hnds_wasted_wish_apply_adjustments(adjustments, direction)
    adjustments = adjustments or {}
    direction = direction or 1

    local hands = direction * (adjustments.hands or 0)
    local discards = direction * (adjustments.discards or 0)
    local hand_size = direction * (adjustments.hand_size or 0)
    local shop_size = direction * (adjustments.shop_size or 0)
    local reroll_cost = direction * (adjustments.reroll_cost or 0)

    if G.GAME.round_resets then
        G.GAME.round_resets.hands = math.max(1,
            (G.GAME.round_resets.hands or 0) + hands)
        G.GAME.round_resets.discards = math.max(0,
            (G.GAME.round_resets.discards or 0) + discards)
        G.GAME.round_resets.reroll_cost = math.max(0,
            (G.GAME.round_resets.reroll_cost or 0) + reroll_cost)
    end

    if G.hand and hand_size ~= 0 then G.hand:change_size(hand_size) end
    if shop_size ~= 0 and type(change_shop_size) == "function" then
        change_shop_size(shop_size)
    end
    if G.GAME.current_round and G.GAME.current_round.reroll_cost ~= nil then
        G.GAME.current_round.reroll_cost = math.max(0,
            G.GAME.current_round.reroll_cost + reroll_cost)
    end
end

-- Crystal Ball and Antimatter change CardArea limits directly, so hiding
-- G.GAME.used_vouchers is not enough after those CardAreas already exist.
-- Remove only their own bonus, never derive a new limit from nil/zero, and
-- remember the exact bonus to add back when Wasted Wish stops being active.
local function hnds_wasted_wish_disable_slot_bonuses(adjustments)
    if not (G and G.GAME) then return end
    adjustments = adjustments or {}

    local state = G.GAME.hnds_wasted_wish_slot_state or {}
    G.GAME.hnds_wasted_wish_slot_state = state

    local consumable_bonus = math.max(0,
        -(tonumber(adjustments.consumable_slots) or 0))
    local joker_bonus = math.max(0,
        -(tonumber(adjustments.joker_slots) or 0))

    state.consumable_bonus = state.consumable_bonus or consumable_bonus
    state.joker_bonus = state.joker_bonus or joker_bonus

    if consumable_bonus > 0 and state.consumable_processed == nil then
        local area = G.consumeables
        local limit = area and area.config
            and tonumber(area.config.card_limit)
        if limit and limit > consumable_bonus then
            area.config.card_limit = math.max(1, limit - consumable_bonus)
            state.consumable_processed = true
        else
            -- If the CardArea is not ready yet (or already has a base-sized
            -- limit), the empty voucher proxy will make it initialize without
            -- Crystal Ball's bonus. Do not subtract again later.
            state.consumable_processed = false
        end
    end

    if joker_bonus > 0 and state.joker_processed == nil then
        local area = G.jokers
        local limit = area and area.config
            and tonumber(area.config.card_limit)
        if limit and limit > joker_bonus then
            area.config.card_limit = math.max(1, limit - joker_bonus)
            state.joker_processed = true
        else
            state.joker_processed = false
        end
    end
end

local function hnds_wasted_wish_restore_slot_bonuses()
    if not (G and G.GAME) then return end
    local state = G.GAME.hnds_wasted_wish_slot_state or {}

    local consumable_bonus = tonumber(state.consumable_bonus) or 0
    if consumable_bonus > 0 and G.consumeables and G.consumeables.config then
        local limit = tonumber(G.consumeables.config.card_limit)
        if limit then
            G.consumeables.config.card_limit = math.max(1,
                limit + consumable_bonus)
        end
    end

    local joker_bonus = tonumber(state.joker_bonus) or 0
    if joker_bonus > 0 and G.jokers and G.jokers.config then
        local limit = tonumber(G.jokers.config.card_limit)
        if limit then
            G.jokers.config.card_limit = math.max(1,
                limit + joker_bonus)
        end
    end

    G.GAME.hnds_wasted_wish_slot_state = nil
end

local function hnds_install_wasted_wish_voucher_proxy()
    if not (G and G.GAME and G.GAME.hnds_wasted_wish_active) then return end
    local backup = G.GAME.hnds_wasted_wish_used_vouchers or {}
    G.GAME.hnds_wasted_wish_used_vouchers = backup

    local current = G.GAME.used_vouchers
    if type(current) == "table" then
        for key, value in pairs(current) do
            if value ~= nil then backup[key] = value end
        end
    end

    local proxy = {}
    setmetatable(proxy, {
        __newindex = function(_, key, value)
            backup[key] = value
        end,
    })
    G.GAME.used_vouchers = proxy
end

function HNDS.set_wasted_wish_active(active)
    if not (G and G.GAME) then return end
    active = active and true or false

    if active then
        if not G.GAME.hnds_wasted_wish_active then
            local vouchers = hnds_copy_table_shallow(G.GAME.used_vouchers)
            G.GAME.hnds_wasted_wish_used_vouchers = vouchers
            G.GAME.hnds_wasted_wish_adjustments =
                hnds_wasted_wish_build_adjustments(vouchers)
            G.GAME.hnds_wasted_wish_overrides =
                hnds_wasted_wish_snapshot_overrides(vouchers)
            G.GAME.hnds_wasted_wish_unredeemed =
                hnds_wasted_wish_unredeem_custom_vouchers(vouchers)
            hnds_wasted_wish_apply_adjustments(
                G.GAME.hnds_wasted_wish_adjustments, 1)
            hnds_wasted_wish_disable_slot_bonuses(
                G.GAME.hnds_wasted_wish_adjustments)
        end
        G.GAME.hnds_wasted_wish_active = true
        G.GAME.hnds_wasted_wish_ante =
            G.GAME.round_resets and G.GAME.round_resets.ante or nil
        hnds_install_wasted_wish_voucher_proxy()
    elseif G.GAME.hnds_wasted_wish_active
        or G.GAME.hnds_wasted_wish_used_vouchers
    then
        local restored = G.GAME.hnds_wasted_wish_used_vouchers or {}
        for key, value in pairs(G.GAME.used_vouchers or {}) do
            restored[key] = value
        end
        G.GAME.used_vouchers = restored

        hnds_wasted_wish_apply_adjustments(
            G.GAME.hnds_wasted_wish_adjustments, -1)
        hnds_wasted_wish_restore_slot_bonuses()
        hnds_wasted_wish_restore_overrides(
            G.GAME.hnds_wasted_wish_overrides)
        hnds_wasted_wish_redeem_custom_vouchers(
            restored,
            G.GAME.hnds_wasted_wish_unredeemed)

        G.GAME.hnds_wasted_wish_used_vouchers = nil
        G.GAME.hnds_wasted_wish_adjustments = nil
        G.GAME.hnds_wasted_wish_overrides = nil
        G.GAME.hnds_wasted_wish_unredeemed = nil
        G.GAME.hnds_wasted_wish_slot_state = nil
        G.GAME.hnds_wasted_wish_active = nil
        G.GAME.hnds_wasted_wish_ante = nil
    end
end

-- Vouchers remain purchasable while Wasted Wish is active. After redemption,
-- rebuild the disabled-voucher snapshot so the newly bought Voucher is owned
-- but its effect stays suppressed until Wasted Wish ends or is rerolled away.
if Card and Card.redeem and not Card._hnds_wasted_wish_redeem then
    Card._hnds_wasted_wish_redeem = true
    local hnds_wasted_wish_redeem_ref = Card.redeem

    function Card:redeem(...)
        local refresh_after = G and G.GAME
            and G.GAME.hnds_wasted_wish_active
            and self.ability and self.ability.set == "Voucher"

        local result = hnds_wasted_wish_redeem_ref(self, ...)

        if refresh_after and G and G.E_MANAGER then
            G.E_MANAGER:add_event(Event({
                trigger = "after",
                delay = 0.05,
                func = function()
                    if G.GAME and G.GAME.hnds_wasted_wish_active then
                        HNDS.set_wasted_wish_active(false)
                        HNDS.set_wasted_wish_active(true)
                    end
                    return true
                end,
            }))
        end

        return result
    end
end

local function hnds_update_ante_10_runtime()
    if not (G and G.GAME) then return end
    local now = G.TIMERS and G.TIMERS.REAL or os.clock()
    if now < (G.GAME.hnds_ante_10_next_runtime_update or 0) then return end
    G.GAME.hnds_ante_10_next_runtime_update = now + 0.10

    local active_blind_key = G.GAME.blind and G.GAME.blind.config
        and G.GAME.blind.config.blind and G.GAME.blind.config.blind.key

    if G.GAME.hnds_perilous_pact_active
        and active_blind_key ~= "bl_vrb_perilous_pact"
    then
        G.GAME.hnds_perilous_pact_active = nil
    end

    if G.GAME.hnds_sinful_soul_active
        and active_blind_key ~= "bl_vrb_sinful_soul"
        and HNDS.clear_sinful_soul
    then
        HNDS.clear_sinful_soul()
    end

    if G.GAME.hnds_wasted_wish_active then
        local ante = G.GAME.round_resets and G.GAME.round_resets.ante
        if ante ~= G.GAME.hnds_wasted_wish_ante then
            HNDS.set_wasted_wish_active(false)
        else
            -- Save files do not preserve metatables; reinstall the proxy after
            -- loading so Voucher checks stay disabled for the rest of the Ante.
            local mt = type(G.GAME.used_vouchers) == "table"
                and getmetatable(G.GAME.used_vouchers)
            if not (mt and mt.__newindex) then
                hnds_install_wasted_wish_voucher_proxy()
            end

            -- CardAreas may be created shortly after boss selection. Apply the
            -- slot removal once they exist, without ever turning a missing or
            -- zero-valued limit into zero slots.
            hnds_wasted_wish_disable_slot_bonuses(
                G.GAME.hnds_wasted_wish_adjustments)
        end
    end
end



-------------------------------------------------------------------
-- TAG POP COUNTER (Forbidden Fruit)
-------------------------------------------------------------------

-- Count a Tag exactly once when it actually triggers. Creation, holding and
-- copying do not count by themselves; a copied Tag counts when it later pops.
if Tag and type(Tag.apply_to_run) == "function" and not HNDS._tag_pop_hooked then
    HNDS._tag_pop_hooked = true
    local tag_apply_to_run_ref = Tag.apply_to_run

    function Tag:apply_to_run(context)
        local was_triggered = self.triggered == true
        local result = tag_apply_to_run_ref(self, context)

        if not was_triggered
            and self.triggered == true
            and not self.hnds_pop_counted
            and G and G.GAME
        then
            self.hnds_pop_counted = true
            G.GAME.hnds_tags_popped = (G.GAME.hnds_tags_popped or 0) + 1
        end

        return result
    end
end


-- The original mod calls this helper from a broad Card:update dispatcher.
-- Keep only the Ante-10 cleanup/update portion needed by these copied bosses.
if Card and Card.update and not Card._vrb_ante10_runtime then
    Card._vrb_ante10_runtime = true
    local vrb_ante10_card_update_ref = Card.update
    function Card:update(dt)
        local ret = vrb_ante10_card_update_ref(self, dt)
        hnds_update_ante_10_runtime()
        return ret
    end
end
