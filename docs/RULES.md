# Spades — Official Rules (as implemented by this app)

This document is the single source of truth for game logic. The Dart
engine in `mobile/lib/core/` implements exactly what's written here —
if the two ever disagree, this file wins and the code has a bug.

## 1. Overview

Spades is a trick-taking card game for exactly **4 players** in two
fixed partnerships, played with a standard 52-card deck (no jokers in
the classic mode). Partners sit across from each other. **Spades are
always trump.** The app's default ruleset is **Classic Partnership
Spades**; additional variants are listed in §7 and are selectable from
Game Settings.

## 2. Setup

- One 52-card deck. Ranking within a suit, low to high:
  `2 3 4 5 6 7 8 9 10 J Q K A`.
- 4 players in 2 partnerships: North/South vs. East/West (seats
  alternate between the two teams).
- Deal the entire deck one card at a time, clockwise, giving every
  player exactly **13 cards**.
- Dealer rotates clockwise each hand. First dealer chosen randomly by
  the app.

## 3. Bidding

Starting with the player to the dealer's left and continuing clockwise,
each player bids the number of tricks (0–13) they think **they
personally** will win this hand, based only on their own hand — bids
are simultaneous-feeling but sequential and are locked once spoken.
The first bidder therefore rotates clockwise each hand along with the
dealer.

**House rule (this app):** the human player always bids *after* their
partner (North), so they have the final say on the team's total. If
the clockwise order would put the human before North, the two swap
bidding slots for that hand; West and East keep their normal slots.

- **Regular bid**: any integer from 0 up to the number of cards dealt
  that hand (13 normally; fewer in Progressive Spades, §7).
- **Nil**: a bid of exactly 0, declaring the player believes they will
  win **zero tricks**. High risk/reward — see scoring in §5.
- **Blind Nil** (optional variant, off by default): a player may bid
  Nil *before* looking at their cards, for a doubled bonus/penalty.
    Only legal as the very first bid of the hand, and only when a team
    is at least 100 points behind.
- A partnership's **team bid** is the sum of its two members' bids
  (a Nil bid contributes 0 to the team's trick target but is scored
  separately — see §5). The team bid can never exceed the number of
  tricks in the hand (= cards per player), so the second partner to bid
  is capped at whatever the first partner left.
- There is no bidding "double nil" — each player bids independently.

## 4. Play

- The player to the dealer's left leads the first trick with any card
  **except a spade**, unless that player's entire hand is spades.
- Play proceeds clockwise. Each player must **follow the suit led** if
  able.
- A player with none of the suit led may play **any card**, including
  a spade (this is how a trick gets trumped).
- **Spades cannot be led** until they have been "broken" — i.e., a
  spade has already been played (as a discard, off-suit) on some
  earlier trick — *unless* the leader's hand contains only spades.
- The trick is won by the highest spade played, or, if no spade was
  played, the highest card of the suit led. The trick winner leads
  the next trick.
- Play continues until all 13 tricks are played out.

## 5. Scoring

Scoring happens per partnership at the end of each hand.

### 5.1 Made / set contracts

Let `bid` = sum of the two partners' regular (non-Nil) bids, and
`won` = tricks the team actually took.

- If `won >= bid`: team scores `10 * bid` **plus 1 point per
  overtrick** (`won - bid`), called a **bag**.
- If `won < bid`: the team is **"set"** (or "bagged out") and scores
  `-10 * bid + won` — the flat penalty offset by **1 point per trick
  actually won** (house rule for this app; standard Spades gives no
  credit at all for a set hand). Example: bid 3, won 2 → `-30 + 2 =
  -28`.

### 5.2 Bags / sandbagging penalty

Overtricks accumulate across hands as a running **bag count** per
team (bags persist hand-to-hand, they don't reset).

- Every time a team's cumulative bag count reaches a multiple of
  **10**, they are penalized **−100 points** immediately, and the bag
  counter keeps accumulating (it is *not* reset to 0, it just keeps
  counting up — the penalty re-triggers at 20, 30, 40, …).

### 5.3 Nil bids

Scored **independently of, and in addition to, the team's regular
bid/trick score**:

- Player bid Nil and took **0 tricks**: partnership gains **+100**.
- Player bid Nil but took **1 or more tricks** (failed): partnership
  loses **−100**.
- Any tricks won by a failed-Nil player still count toward the
  partnership's regular trick total (`won`, above) for bag purposes,
  but a *successful* Nil player's 0 tricks contribute 0.
- **Blind Nil** doubles the stakes: **+200** if successful, **−200**
  if failed.
- If both partners bid Nil in the same hand, each is scored
  independently (both can succeed, both can fail, or a mix).

### 5.4 Special edge cases

- **All 13 tricks by one team ("Boston"/shutout)**: no bonus in the
  default ruleset (house-rule toggle available to award a bonus).
- **Team bid of 0 with no Nil** (both partners bid 0 as regular
  bids — some groups disallow this): the app allows it; making it
  scores 0 (10 × 0), overtricks still count as bags.

## 6. Ending the game

- After each hand, add the hand's score to each team's running total.
- The game ends immediately after any hand in which a team's score is
  `>= 500`. If both teams cross 500 in the same hand, the higher score
  wins; an exact tie triggers **sudden-death**: one more hand, high
  score wins outright (bags carry over).
- A team whose score falls to **≤ −200** at any point loses instantly,
  regardless of the other team's score (default toggle: on).
- Default target score (**500**) and loss floor (**−200**) are
  configurable per match in Game Settings.

## 7. Variants (configurable, off by default unless noted)

| Variant | Rule change |
|---|---|
| **Solo Spades** | 4 players, no partnerships — every player for themself. Team bag rules apply per-player. |
| **Whiz** | Every player must bid either Nil or exactly the number of spades in their hand. |
| **Mirror** | Nil bidding disabled entirely; every bid must be 1–13. |
| **Suicide** | 4-player partnership variant where one player on each team is *forced* to bid Nil (or as close as legally possible) each hand. |
| **Jokers (Heart of Spades)** | Add 2 jokers as the two highest trumps (Big Joker > Little Joker > A♠); hand size becomes 13 with a discarded "kitty" mechanic — reserved for a future release. |
| **Progressive Spades** | Hand size increases each round from 1 card up to 13 (used by this repo's original web predictor tool). No Nil, no bag penalty. Included for parity with the existing `index.html` tool. |
| **Blind Nil** | See §3. |

The default match uses **Classic Partnership Spades** with Nil enabled
and Blind Nil disabled; all variants above are exposed as toggles in
the New Game screen so players can match their preferred house rules.

## 8. Turn order & UI conventions

- Seats are fixed clockwise: **South (human) → West → North → East**,
  matching the on-screen table layout (human always at the bottom).
- The current bidder/player is always visually highlighted; legal
  cards are the only ones the human player can lift off their hand.
- AI bots strictly obey §3–§4; they never offer table talk or reveal
  hand contents.
