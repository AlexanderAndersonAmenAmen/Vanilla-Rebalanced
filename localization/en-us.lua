return {
    descriptions = {
        Stake = {
            stake_blue = {
                name = 'Blue Stake',
                text = {
                    'Required score scales',
                    'faster for each {C:attention}Ante{}',
                    '{s:0.8}Applies all previous Stakes',
                },
            },
            stake_purple = {
                name = 'Purple Stake',
                text = {
                    'Shop can have {C:attention}Perishable{} Jokers',
                    '{s:0.8}Applies all previous Stakes',
                },
            },
            stake_orange = {
                name = 'Orange Stake',
                text = {
                    'Shop can have {C:attention}Rental{} Jokers',
                    '{s:0.8}Applies all previous Stakes',
                },
            },
            stake_gold = {
                name = 'Gold Stake',
                text = {
                    'Defeat Ante {C:attention}10 Boss{} to win',
                    '{s:0.8}Applies all previous Stakes',
                },
            },
        },
        Other = {
            perishable = {
                name = 'Perishable',
                text = {
                    'Becomes {C:dark_edition}Negative{} and',
                    'debuffed after {C:attention}#1#{} rounds',
                    '{C:inactive}({C:attention}#2#{C:inactive} remaining)',
                },
            },
        },
        Enhanced = {
            m_wild = {
                name = 'Wild Card',
                text = {
                    "Can't be debuffed",
                    'Can be used',
                    'as any suit',
                },
            },
        },
        Joker = {
            j_matador = {
                name = 'Matador',
                text = {
                    'Gain {C:money}$#1#{} per hand',
                    'played vs {C:attention}Boss Blind{}',
                },
            },
            j_superposition = {
                name = 'Superposition',
                text = {
                    'Create a {C:tarot}Fool{} card',
                    'if poker hand contains',
                    'an {C:attention}Ace{} and a {C:attention}Straight{}',
                    '{C:inactive}(Must have room)',
                },
            },
            j_splash = {
                name = 'Splash',
                text = { 'Played cards {C:attention}always{} score' },
            },
            j_erosion = {
                name = 'Erosion',
                text = {
                    '{C:mult}+#1#{} Mult for each',
                    'card below {C:attention}#3#{}',
                    'in your full deck',
                    '{C:inactive}(Currently {C:mult}+#2#{C:inactive} Mult)',
                },
            },
            j_flower_pot = {
                name = 'Flower Pot',
                text = {
                    'Gives {X:mult,C:white}X{} Mult equal to the',
                    'number of {C:attention}unique suits{}',
                    'in played poker hand',
                    '{C:inactive}(Currently {X:mult,C:white}X#1#{C:inactive} Mult)',
                },
            },
            j_vrb_flower_pot_none = {
                name = 'Flower Pot',
                text = {
                    'Gives {X:mult,C:white}X{} Mult equal to the',
                    'number of {C:attention}unique suits{}',
                    'in played poker hand',
                    '{C:inactive}(Currently none)',
                },
            },
            j_mail = {
                name = 'Mail-In Rebate',
                text = {
                    'Earn {C:money}$#1#{} for each',
                    'discarded {C:attention}#2#{}, rank',
                    'changes every round',
                },
            },
            j_stone = {
                name = 'Stone Joker',
                text = {
                    'Gives {C:chips}+#1#{} Chips for',
                    'each {C:attention}Stone Card{}',
                    'in your full deck',
                    '{C:inactive}(Currently {C:chips}+#2#{C:inactive} Chips)',
                },
            },
            j_greedy_joker = { name = 'Greedy Joker', text = { 'Played cards with', '{C:diamonds}Diamond{} suit give', '{C:mult}+#1#{} Mult when scored' } },
            j_lusty_joker = { name = 'Lusty Joker', text = { 'Played cards with', '{C:hearts}Heart{} suit give', '{C:mult}+#1#{} Mult when scored' } },
            j_wrathful_joker = { name = 'Wrathful Joker', text = { 'Played cards with', '{C:spades}Spade{} suit give', '{C:mult}+#1#{} Mult when scored' } },
            j_gluttenous_joker = { name = 'Gluttonous Joker', text = { 'Played cards with', '{C:clubs}Club{} suit give', '{C:mult}+#1#{} Mult when scored' } },
            j_throwback = {
                name = 'Throwback',
                text = {
                    '{X:mult,C:white}X#1#{} Mult for each',
                    '{C:attention}Blind{} skipped this run',
                    '{C:inactive}(Currently {X:mult,C:white}X#2#{C:inactive} Mult)',
                },
            },
            j_seeing_double = {
                name = 'Seeing Double',
                text = {
                    'Retrigger all {C:attention}7s{}',
                    'Retrigger them an',
                    'additional time if',
                    'their suit is {C:clubs}Clubs{}',
                },
            },
            j_ring_master = {
                name = 'Showman',
                text = {
                    '{C:attention}Joker{}, {C:tarot}Tarot{}, {C:planet}Planet{}',
                    'and {C:spectral}Spectral{} cards may',
                    'appear multiple times',
                },
            },
            j_hiker = {
                name = 'Hiker',
                text = {
                    'Every played {C:attention}card{}',
                    'permanently gains {C:chips}+#1#{}',
                    'Chips when scoring',
                },
            },
        },

        Blind = {
            bl_vrb_blind_devil = {
                name = 'The Devil',
                text = { 'Summons #1#,', '#2#, #3#' },
            },
            bl_vrb_forbidden_fruit = {
                name = 'Forbidden Fruit',
                text = { 'Debuff 6 cards in deck', 'per Tag used this run' },
            },
            bl_vrb_perilous_pact = {
                name = 'Perilous Pact',
                text = { 'Caps each hand at', '50% of required score' },
            },
            bl_vrb_sinful_soul = {
                name = 'Sinful Soul',
                text = { '+20% Blind size per $1', "of Jokers' sell value" },
            },
            bl_vrb_wasted_wish = {
                name = 'Wasted Wish',
                text = { 'Vouchers are', 'disabled this Ante' },
            },
        },
        Voucher = {
            v_magic_trick = {
                name = 'Magic Trick',
                text = {
                    '{C:attention}Playing cards{}',
                    'can be purchased',
                    'from the {C:attention}shop{}',
                },
            },
            v_illusion = {
                name = 'Illusion',
                text = {
                    'Cards from your {C:attention}deck{}',
                    'can appear in the shop',
                },
            },
        },
        Spectral = {
            c_ouija = {
                name = 'Ouija',
                text = {
                    'Select {C:attention}1{} card',
                    'Converts all cards',
                    'in hand to its {C:attention}rank{}',
                    '{C:red}-1{} hand size',
                },
            },
            c_black_hole = {
                name = 'Black Hole',
                text = { 'Double the level', 'of all {C:attention}poker hands{}' },
            },
        },
    },
    misc = {
        dictionary = {
            hnds_devil_name_default = 'The Devil',
            hnds_devil_name_legion = 'Legion',
            hnds_devil_name_old_nick = 'Old Nick',
            hnds_devil_name_deceiver = 'The Deceiver',
            hnds_devil_name_tempter = 'The Tempter',
            hnds_devil_name_adversary = 'The Adversary',
            hnds_devil_name_prince_of_darkness = 'Prince of Darkness',
            hnds_devil_name_belial = 'Belial',
            hnds_devil_name_apollyon = 'Apollyon',
            hnds_devil_name_lucifer = 'Lucifer',
            hnds_devil_name_abaddon = 'Abaddon',
            hnds_devil_name_leviathan = 'Leviathan',
        },
    },
}
