# Vanilla Rebalance

Target: Balatro 1.0.1o-FULL, Steamodded 1.0.0~BETA-1620a, Lovely 0.9.0.

## Implementation notes

- Magic Trick independently rolls enhancement, edition, and seal using Standard-pack rates, so combinations are possible.
- Illusion samples physical cards in `G.playing_cards`; duplicate cards therefore have proportional weight. When at least one modified card exists, only modified cards are sampled.
- A Wild Card is protected through Steamodded's central debuff hook. Splash applies the same protection to all playing cards while active and retains its all-cards-score behavior.
- Flower Pot counts only cards in the actual scoring hand; each Wild Card counts as one assignable missing suit rather than four suits at once.
- Seeing Double returns two additional repetitions for rank 7 in both played-card and held-card repetition contexts.
and more...
