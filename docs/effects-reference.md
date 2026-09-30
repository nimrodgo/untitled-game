# Effects Reference

Every effect extends `Effect` (`scripts/data/effect.gd`) and has one shared field:

- `target`: `SELF` or `OPPONENT`, relative to the **owner** (the one who played, bought or used it, or the enemy for intents). **Every effect defaults to `SELF`.** Enemy intents that hit the player set `OPPONENT` explicitly.

Each effect implements these methods:

| Method | Purpose |
|---|---|
| `apply(ctx)` | Does the thing. May be a coroutine: effects that ask the player something `await ctx.encounter.request_choice(...)`. |
| `can_pay(ctx)` | Costs only. Return false when it can't be paid; the card or trinket is then unplayable. Default true. |
| `is_cost()` | True for costs ("Pay 2", "Discard 1", "Pass", "🔥 this"). Generated text puts ➡ after them. |
| `describe()` | Auto card text. Uses `_who()` to add "Opponent " or "You: ". |
| `ai_score()` | A rough value for `SimBot`. Positive means good for the owner. |

## Primitives (`scripts/data/effects/`)

### Coins

| Class | Fields | Does | Auto text |
|---|---|---|---|
| `GainCoinsEffect` | `amount`=1 | +coins | Gain N 🪙 |
| `LoseCoinsEffect` | `amount`=1 | −coins (floor 0) | Lose N 🪙 / You lose N 🪙 |
| `PayCoinsEffect` | `amount`=1 | **Cost:** −coins; unplayable if you don't have them | Pay N 🪙 ➡ |
| `StealCoinsEffect` | `amount`=1 | Moves up to N coins from the opponent to the owner (ignores `target`) | Steal N 🪙 |
| `GainCoinsPerStatEffect` | `stat`, `per`=1 | +`per` × a `PlayerState` stat (`stat=coins` doubles your coins) | Gain N 🪙 for every *stat* |
| `GainCoinsScalingEffect` | `amount`=2, `increase`=2 | Gain `amount` + this card's bonus, then all copies (same `id`) gain `increase` more this encounter | Gain 2 🪙 and increase gain… |

### Drawing and discarding

| Class | Fields | Does |
|---|---|---|
| `DrawCardsEffect` | `amount`=1, `source`=TOP | Draw. `source`: `TOP`, `BOTTOM` (bottom of the deck), `DISCARD_CHOOSE` (you pick from the discard pile) |
| `DiscardCardsEffect` | `amount`=1, `all_hand`, `as_cost`, `draw_that_many` | You pick cards in your hand to discard, or the whole hand. `as_cost`: "Discard 1 ⤵ ➡ …" is unplayable without enough **other** cards. `draw_that_many`: "Discard your hand. Draw that many". |
| `DiscardRandomEffect` | `amount`=1 | Discards random cards from the target's hand (enemy intents: set `target = OPPONENT`) |
| `DiscardFromDeckEffect` | `look`=1 | Look at the top N cards of your deck; discard any of them (in order, optional) |
| `OfferRedrawEffect` | — | For a `CARD_DRAWN` item: you may discard the card just drawn to draw another. Declining, or the start-of-turn draw, doesn't use up the item. |
| `DrawLockEffect` | — | You can't draw additional cards this turn |
| `NextTurnDrawEffect` | `amount`=1 | Draw N extra at the start of your next turn |

### Remove, destroy, move

| Class | Fields | Does |
|---|---|---|
| `TrashCardsEffect` | `destroy`=true, `what`=CHOOSE, `amount`=1, `piles`=all, `curses_only`, `coins_per_card`, `gain_cost_as_coins`, `as_cost` | **Remove** 🗑 (for this encounter, `destroy=false`) or **destroy** 🔥 (permanently). `what`: `SELF` (this card / the played card for items), `CHOOSE` (exactly `amount` from `piles`, fewer only if there aren't enough), `ALL_OTHER_HAND`, `DRAW_PILE` ("your deck"). |
| `MoveCardsEffect` | `from_piles`, `to_zone`, `curses_only`, `amount`=0 | Move cards between piles (no triggers). `amount=0` = all matching cards; otherwise you choose. |
| `TransformCardsEffect` | `into` | Choose any number of cards in your hand; each becomes `into` (upgrades are lost) |
| `AddCardEffect` | `card`, `amount`=1, `zone`=DRAW_SHUFFLE | Creates new copies of a card (curses: "Shuffle C3 into your deck", "Gain C2") |

`piles` / `from_piles` are flags: Hand, Deck (draw pile), Discard. "Remove / destroy" default to all three, "discard" is from the hand unless stated otherwise.

### Playing

| Class | Fields | Does |
|---|---|---|
| `PlayTopCardsEffect` | `amount`=2 | Play the top N cards of your deck. Unplayable ones go to the discard pile. |
| `ReplayEffect` | `mode`=NEXT_CARD, `times`=1 | `NEXT_CARD`: the next card you play this turn is played an additional time. `THIS_CARD` (items on `CARD_PLAYED`): play the card that was just played again. |
| `PlayCopyEffect` | `source`=LAST_PLAYED | Resolve another card's on-play: `LAST_PLAYED` this turn, or a card you choose from those `DESTROYED` this encounter |

All of these **count as playing a card** (cards-played count, `CARD_PLAYED` items).

### Market and trinkets

| Class | Fields | Does |
|---|---|---|
| `BuyCardEffect` | `source`=MARKET, `free`, `zone`=-1, `play_then_destroy` | Buy a card you choose (and can afford) as part of this effect. `source`: `MARKET`, `REMOVED` or `DESTROYED` this encounter. It's a real buy: on-buy, `BEFORE_CARD_BUY` / `CARD_BOUGHT` items. `zone` overrides the destination (`DRAW_TOP` for "place it on top"). `play_then_destroy`: play it right away, then destroy it. |
| `NextBuyToHandEffect` | `amount`=1 | The next card you buy is drawn immediately |
| `SetBuyDestinationEffect` | `destination`=HAND | Sets `ctx.buy_destination` (buy triggers / on-buy only) |
| `SnatchShopCardEffect` | `mode`, `amount`=1 | Removes market card(s): `CHEAPEST`, `PRICIEST`, `RANDOM`, `LEFTMOST` |
| `DestroyShopCardEffect` | `restock`=true | You pick a market card to destroy; its slot gets a new random card |
| `RefreshTrinketsEffect` | `amount`=1, `all` | Used trinkets become usable again (you pick which if there's a choice) |
| `ActivateShopTrinketEffect` | `level`=3 | You pick a market trinket and resolve its level-N effect (its top level if it has fewer). It stays in the market. |

### Turn flow and logic

| Class | Fields | Does |
|---|---|---|
| `PassEffect` | — | Your turn ends right after this action. The enemy doesn't answer it. Text "Pass ➡". |
| `ExtraActionEffect` | — | The enemy skips responding to this action |
| `ExtraRoundEffect` | `amount`=1 | The encounter gets another (normal) round |
| `RetainCardsEffect` | `amount`=1, `optional` | Choose cards in your hand to keep at the end of this turn |
| `ChooseOneEffect` | `options: Array[EffectOption]` | "X OR Y". Options whose costs can't be paid are greyed out. `EffectOption` = `label` + `effects`. |
| `ConditionalEffect` | `condition`, `effects` | Only if: `DISCARD_EMPTY`, `DECK_EMPTY`, `NO_OTHER_CARD_PLAYED` (this turn) |

### Where context-output effects work

| Effect | Works on | Ignored on |
|---|---|---|
| `SetBuyDestinationEffect` | `BEFORE_CARD_BUY` items, a card's own `on_buy` | Everything else |
| `ExtraActionEffect` | Non-instant card `on_play`, card `on_buy`, buy / play items | Trinkets, trinket/enhancement purchases |
| `PassEffect` | Any of your cards, trinkets, options | Enemy intents |

## Card hooks (`CardData`)

| Field | When |
|---|---|
| `on_play` | Played (from the hand or otherwise) |
| `on_buy` | Bought |
| `on_discard` | Discarded **by an effect**. The end-of-round cleanup doesn't count. |
| `on_destroy` | Destroyed |
| `on_turn_end_in_hand` | End of your turn, if still in your hand (C4) |

## Triggers

These are the item `trigger` values in `GameRules.Trigger`. The engine fires each one for the side named below. New ones are appended at the end of the enum.

| Trigger | Fires | Side |
|---|---|---|
| `ENCOUNTER_START` | Once, at `start()` | both |
| `ROUND_START` | After drawing, each round | both |
| `TURN_START` | Right after `ROUND_START` (same moment) | player |
| `HAND_DRAWN` | Right after the start-of-turn draw; cards drawn here don't count as "drawn this turn" | player |
| `CARD_DRAWN` | Each card drawn (`ctx.card`; `ctx.opening_draw` during the start-of-turn draw) | drawer |
| `CURSE_DRAWN` | Each curse drawn, **including the opening hand** | drawer |
| `CARD_DISCARDED` | Each card discarded by an effect (not the cleanup) | owner |
| `CARD_REMOVED` / `CARD_DESTROYED` | A card was removed / destroyed | owner |
| `CARD_TRASHED_FROM_HAND` | A card in the hand was removed or destroyed | owner |
| `BEFORE_CARD_BUY` | After paying, before on-buy and placement | buyer |
| `CARD_BOUGHT` | After placement | buyer |
| `OPPONENT_CARD_BOUGHT` | Same moment | the other side |
| `CARD_PLAYED` | After on-play resolves (also replays and copies) | player |
| `OPPONENT_CARD_PLAYED` | Same moment | enemy |
| `ITEM_BOUGHT` | After an item purchase | player |
| `TRINKET_USED` | After a trinket resolves | player |
| `ROUND_END` | When you pass, before cleanup | both |
| `ENEMY_ACTED` | After each intent | both |

Only **items** listen to triggers. An item fires if `can_trigger()` passes (its per-round and per-encounter limits). "The first card you play each turn…" = `CARD_PLAYED` with `limit_per_round = 1`.

## Zones (`GameRules.Zone`)

| Zone | Placement |
|---|---|
| `HAND` | Added to the hand |
| `DRAW_TOP` | On top of the draw pile (drawn next) |
| `DRAW_SHUFFLE` | Random position in the draw pile. **This is the default for bought cards.** |
| `DISCARD` | Discard pile |
| `DRAW_BOTTOM` | Bottom of the draw pile |

## Text placeholders

These come from `Encounter.text_vars()` and are used as `{name}` in card text.

| Key | Value |
|---|---|
| `cards_drawn_this_turn` (alias `_this_round`) | Cards drawn this round, not counting the opening hand |
| `cards_played_this_turn` (alias `_this_round`) | Cards played this round |
| `coins` | Your coins |
| `round` | Current round number |
| `removed` / `destroyed` | Cards you removed / destroyed this encounter |

## Stats available to `GainCoinsPerStatEffect.stat`

Any `int` field of `PlayerState` works. The useful ones are `cards_drawn_this_turn`, `cards_played_this_turn`, `buys_this_round`, `cards_bought`, and `coins`.
