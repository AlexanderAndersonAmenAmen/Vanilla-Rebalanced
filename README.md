# Vanilla Rebalance

Target: Balatro 1.0.1o-FULL, Steamodded 1.0.0~BETA-1620a, Lovely 0.9.0.

Install by extracting the `VanillaRebalance` folder into Balatro's Mods folder.



## Implementation notes

- Magic Trick independently rolls enhancement, edition, and seal using Standard-pack rates, so combinations are possible.
- Illusion samples physical cards in `G.playing_cards`; duplicate cards therefore have proportional weight. When at least one modified card exists, only modified cards are sampled.
- A Wild Card is protected through Steamodded's central debuff hook. Splash applies the same protection to all playing cards while active and retains its all-cards-score behavior.
- Flower Pot counts only cards in the actual scoring hand; each Wild Card counts as one assignable missing suit rather than four suits at once.
- Seeing Double returns two additional repetitions for rank 7 in both played-card and held-card repetition contexts.

## Gold Stake

Gold Stake requires Ante 10 and uses the five copied Ante 10 bosses. The Blind Upgrade mechanic has been removed. Handsome Devils is not required.

## Attribution

The self-contained Ante 10 boss artwork/code was adapted from the supplied Handsome Devils build (Kars, sup3p, Eris H. Nova, and Marffe).
## 1.0.4 fixes

- Prevents Illusion/Magic Trick shop generation from passing a nil Enhanced-card key to Steamodded.
- Seeing Double retriggers every 7 once and Club-suit 7s one additional time.


## Version 1.0.6

- Illusion now constructs copied deck cards through the native shop-card creation path, preserving purchase buttons.
- Magic Trick remains active with Illusion and applies independent enhancement, edition, and seal rolls after the Illusion copy is created.

## v1.0.6 shop-card UI fix

- Illusion and Magic Trick now use one staged playing-card generation pipeline.
- Rank, suit, and enhancement are selected before card construction.
- Edition and seal are applied silently and immediately before the native shop UI is created.
- Multi-modifier playing cards no longer lose their buy UI or interfere with neighboring shop cards.
