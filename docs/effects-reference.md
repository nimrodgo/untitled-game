# Effects Reference

Every effect extends `Effect` (`scripts/data/effect.gd`) and has one shared field:

- `target`: `SELF` or `OPPONENT`, relative to the **owner** (the one who played, bought or used it, or the enemy for intents).

Each effect implements three methods:

| Method | Purpose |
|---|---|
| `apply(ctx)` | Does the thing |
| `describe()` | Auto card text. Uses `_who()` to add "Opponent " or "You: ". |
| `ai_score()` | A rough value for `SimBot`. Positive means good for the owner. |

## Primitives (`scripts/data/effects/`)

| Class | Fields | Default target | Does | Auto text |
|---|---|---|---|---|
| `GainCoinsEffect` | `amount`=1 | SELF | +coins | Gain N 🪙 |
| `LoseCoinsEffect` | `amount`=1 | OPPONENT | −coins (floor 0) | Lose N 🪙 / You lose N 🪙 |
| `StealCoinsEffect` | `amount`=1 | *ignored* | Moves up to N coins from the opponent to the owner | Steal N 🪙 |
| `GainCoinsPerStatEffect` | `stat`, `per`=1 | SELF | +`per` × a `PlayerState` stat | Gain N 🪙 for every *stat* |
| `DrawCardsEffect` | `amount`=1 | SELF | Draws (reshuffles the discard if needed) | Draw N 🂠 |
| `DiscardRandomEffect` | `amount`=1 | OPPONENT | Discards random cards from hand | Discard N 🂠 at random |
| `AddCardEffect` | `card`, `amount`=1, `zone`=DRAW_SHUFFLE | OPPONENT | Creates new copies of a card | Add N *X* to *zone* |
| `SetBuyDestinationEffect` | `destination`=HAND | — | Sets `ctx.buy_destination` | Bought card goes to… |
| `ExtraActionEffect` | — | — | Sets `ctx.grant_extra_action` (the enemy skips responding) | Take another action |
| `SnatchShopCardEffect` | `mode`, `amount`=1 | — | Removes market card(s) | Snatch the priciest market card |

**Snatch modes:** `CHEAPEST`, `PRICIEST` (default), `RANDOM`, `LEFTMOST`. Ties go to the leftmost card.

### Where context-output effects work

| Effect | Works on | Ignored on |
|---|---|---|
| `SetBuyDestinationEffect` | `BEFORE_CARD_BUY` items, a card's own `on_buy` | Everything else |
| `ExtraActionEffect` | Non-instant card `on_play`, card `on_buy`, `BEFORE_CARD_BUY`/`CARD_BOUGHT`/`CARD_PLAYED` items, `ITEM_BOUGHT` items | Trinkets, trinket/enhancement purchases |

## Triggers

These are the item `trigger` values in `GameRules.Trigger`. The engine fires each one for the side named below.

| Trigger | Fires | Side |
|---|---|---|
| `ENCOUNTER_START` | Once, at `start()` | both |
| `ROUND_START` | After drawing, each round | both |
| `TURN_START` | Right after `ROUND_START` (same moment) | player |
| `BEFORE_CARD_BUY` | After paying, before on-buy and placement | buyer |
| `CARD_BOUGHT` | After placement | buyer |
| `OPPONENT_CARD_BOUGHT` | Same moment | the other side |
| `CARD_PLAYED` | After on-play resolves | player |
| `OPPONENT_CARD_PLAYED` | Same moment | enemy |
| `ITEM_BOUGHT` | After an item purchase | player |
| `TRINKET_USED` | After a trinket resolves | player |
| `ROUND_END` | When you pass, before cleanup | both |
| `ENEMY_ACTED` | After each intent | both |

Only **items** listen to triggers. An item fires if `can_trigger()` passes (its per-round and per-encounter limits).

## Zones (`GameRules.Zone`)

| Zone | Placement |
|---|---|
| `HAND` | Added to the hand |
| `DRAW_TOP` | On top of the draw pile (drawn next) |
| `DRAW_SHUFFLE` | Random position in the draw pile. **This is the default for bought cards.** |
| `DISCARD` | Discard pile |

## Text placeholders

These come from `Encounter.text_vars()` and are used as `{name}` in card text.

| Key | Value |
|---|---|
| `cards_drawn_this_turn` (alias `_this_round`) | Cards drawn this round, not counting the opening hand |
| `cards_played_this_turn` (alias `_this_round`) | Cards played this round |
| `coins` | Your coins |
| `round` | Current round number |

## Stats available to `GainCoinsPerStatEffect.stat`

Any `int` field of `PlayerState` works. The useful ones are `cards_drawn_this_turn`, `cards_played_this_turn`, `buys_this_round`, `cards_bought`, and `coins`.
