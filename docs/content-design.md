# Designing Content

All content is Godot **Resources** (`.tres`). There are two ways to make them:

- **In the editor:** FileSystem → right-click a folder → **New Resource** → pick the type (e.g. `CardData`), then fill in the Inspector. Add effects with the array's **+** button → **New *XxxEffect***.
- **From a script:** see `tools/build_test_content.gd`, which regenerates `content/test/`. If you edit test `.tres` files by hand, re-running that script **overwrites** your changes.

To play your content, point an `EncounterData` at your pools and enemy, then set it (plus a `LoadoutData`) on the **Main** node in `scenes/main.tscn`. The Main node also has `encounter_pool`: if it isn't empty, every run (and every "Play again") picks one of those encounters at random and `encounter_data` is only the fallback. It currently holds the 5 themed encounters.

## Resource types

### CardData — a card

| Field | Default | Notes |
|---|---|---|
| `id` | — | StringName for reference |
| `display_name` | "New Card" | |
| `cost` | 1 | Coins to buy it from the market |
| `instant` | false | Playing it is a **free** action |
| `on_play` | [] | Effects when played |
| `on_buy` | [] | Effects once, when bought. **Every card should have an on-buy**; placeholder ones use `on_buy_text = "TBD"` and no effects |
| `playable` | true | false = can't be played (curses) |
| `on_discard` / `on_destroy` / `on_turn_end_in_hand` | [] | Card hooks (see [effects-reference](effects-reference.md#card-hooks-carddata)) |
| `curse` / `permanent` | false | Curse styling + "curse" filters; permanent = stays between encounters (flag only for now) |
| `on_play_text` / `on_buy_text` | "" | Custom text. Leave it empty to auto-generate from effects. |
| `flavor_text` | "" | Shown in the inspect popup |
| `art`, `tags` | — | Not used yet |

If you write custom text, the auto "INSTANT" tag is hidden. Put ⚡ in the text instead.

### ItemData — a passive item

| Field | Default | Notes |
|---|---|---|
| `cost` | 3 | |
| `trigger` | `CARD_BOUGHT` | When it fires (see [triggers](effects-reference.md#triggers)) |
| `effects` | [] | |
| `limit_per_encounter` / `limit_per_round` | 0 | 0 = unlimited |
| `shop_price_override` | -1 | While you own it, **everything** in the market (cards, items, trinkets, trinket upgrades, enhancements) costs this much (-1 = off; the lowest override wins). Needful uses 0. |
| `restock_bought_cards` | false | While you own it, a market card slot you buy from gets a new random card right away (Stockroom) |
| `description` | "" | Auto: "*When…* (*limit*): *effects*" |

### TrinketData + TrinketLevel — an activated ability

- `TrinketData`: `cost` (default 4), `levels: Array[TrinketLevel]`, `description`.
- `TrinketLevel`: `upgrade_cost` (ignored for level 1), `effects`, `text`. `upgrade_cost` is what you pay when you **buy the trinket again in the market** to reach that level.
- You can use each trinket once per turn. Upgrading moves it to the next level. The name shows "(Lv N)" only when a trinket has more than one level.
- **Style rule:** don't write "once per turn" or "(free)" on trinkets.

### EnhancementData — a market "upgrade" for one card (a card holds at most one)

| Field | Notes |
|---|---|
| `cost` | default 2 |
| `card_set` | Which set it belongs to. Encounters sell the enhancements of their `card_sets` (+ Utility and Coins) |
| `make_instant` | The card becomes instant |
| `extra_on_play` | Effects added after the card's own on-play effects |
| `on_discard` | Effects when an effect discards the card (not the end-of-round cleanup) |
| `retain` | The card stays in hand at the end of every turn |
| `destroy_on_apply` | Buying it destroys the chosen card (permanently) on the spot; nothing is attached |
| `counts_as_curse` | The card counts as a curse (curse triggers, curse filters) |
| `icon` | Icon token (see `Icons`) drawn as a round badge on the enhanced card's corner and on the shop tile. The card text is never changed |
| `description` | Shown on the shop tile and in the hover legend of an enhanced card. Auto-generated if empty |

One enhancement per set, built by `tools/build_enhancements.gd` into `content/test/enhancements/` (names and the price of 3 are placeholders). The shop's upgrade slot is rerolled every round from the encounter's pool, like trinkets.

### EnemyData + EnemyIntent

| EnemyData field | Default | Notes |
|---|---|---|
| `starting_coins` | 0 | |
| `intents` | [] | Loop in order |
| `actions_per_round` | 3 | How many of your actions it answers each round |
| `start_intent` | 0 | Offsets the cycle, so two copies can be out of phase |
| `items` | [] | Passive; it never buys more |
| `portrait`, `color` | —, coral | The portrait isn't rendered yet. It shows an initial in `color`. |

`EnemyIntent`: `display_name`, `kind` (ATTACK / STEAL / SHOP / CURSE / BUFF / OTHER, shown as a label), `effects`, optional `description`, `icon`.
Intent text is auto-phrased from the player's point of view, for example "You lose 1 🪙".

### EncounterData

| Field | Default | Notes |
|---|---|---|
| `rounds` | 3 | |
| `coin_target` | 15 | Win threshold |
| `gold_reward` | 10 | Shown on victory. Not used yet. |
| `enemy` | — | |
| `card_sets` | [] | **Just name the sets**: every card, item, trinket and enhancement of these sets, plus Utility and Coins (`CardSets.ALWAYS_SOLD`), is sold. They are found automatically (`ContentLibrary`, everything under `content/test/`) |
| `card_pool` | [] | Extra cards on top of the sets (or the whole pool if `card_sets` is empty). Duplicates raise the odds |
| `item_pool`, `trinket_pool`, `enhancement_pool` | [] | Same for items / trinkets / upgrades; each is drawn without repeats |
| `card_slots` / `item_slots` / `trinket_slots` / `enhancement_slots` | 5 / 1 / 1 / 1 | A pool with no slots is hidden from the market |
| `refill_card_slots` | false | Legacy: refills a card slot right after it's bought |
| `rng_seed` | 0 | 0 = random |

### LoadoutData — what the player starts with

`starting_deck`, `starting_coins` (3), `items`, `trinkets`. Later this will come from the run.

## Card sets

Every card, item, trinket, enhancement and curse has exactly one `card_set` (enum `CardSets.Id` in `scripts/data/card_sets.gd`). The set tints the tile (`CardSets.color`) and decides what an encounter sells. **The enum numbers are stored in the `.tres` files: only ever append new ids.** Names and colors are placeholders.

| Set | Pieces | Theme |
|---|---|---|
| Curses | 4 | The curses themselves (never sold) |
| Coins | 5 | Simple coin cards (sold everywhere) |
| Draw | 9 | Drawing, fetching from the deck, draw synergy |
| Discard | 11 | Discarding and discard payoffs |
| Trim | 14 | Remove and destroy |
| Retain | 3 | Keeping cards in hand (thin, needs more cards) |
| Utility | 10 | Unique effects: replays, trinket refresh, extra turns (sold everywhere) |
| Market | 8 | Buying, restocking, recovering cards, market manipulation |
| Curse Synergy | 12 | Gaining, moving and cashing in curses |

`ContentLibrary` (`scripts/data/content_library.gd`) scans `res://content/test/{cards,items,trinkets,enhancements}` at runtime, so moving a piece to another set or adding a new `.tres` needs no script re-run. Curses are not scanned. Gotcha: a static func called `set_name` on a `class_name` script collides with `Resource.set_name`; use `display_name`.

## Writing card text

- **BBCode** works: `[i]`, `[b]`, `[color=#hex]`.
- **Icons:** type these characters and they render as inline SVG icons (the web build has no emoji font):

  | Token | Icon | Use for |
  |---|---|---|
  | `🪙` | coin | coins |
  | `🂠` | card | cards |
  | `⚡` (or `🗲`) | bolt | instant |
  | `🛍` | bag | on-buy (the card frame adds it automatically) |
  | `⤵` | tray arrow | discard |
  | `🔥` | flame | destroy |
  | `🗑` | bin | remove |
  | `↺` | circle arrow | refresh |
  | `➡` | arrow | separates a cost from what it pays for: `Pay 2 🪙 ➡ Draw 3 🂠` |

- **Live values** go in braces and update while you play: `{cards_drawn_this_turn}`, `{cards_played_this_turn}`, `{coins}`, `{round}`. The `_this_round` versions are aliases. The full list is in [effects-reference.md](effects-reference.md#text-placeholders).
- Example: `Gain 1 🪙 for every card drawn this turn ([i]{cards_drawn_this_turn}[/i])`
- `{gain}` is per card: the coins the card would give if played right now (Liquidate: `… for each ([i]{gain}[/i])`). `{gain_icons}` is the same amount drawn as coins: N × 🪙 up to 5, else `N🪙` (Snowball: `{gain_icons} and increase…`). Effects report it with `preview_coins()`.

## Recipes

| I want… | Do this |
|---|---|
| A card that draws | `on_play: [DrawCardsEffect amount=2]` |
| A free coin card | `instant = true`, `on_play: [GainCoinsEffect 1]`, text `⚡Gain 1 🪙` |
| A payoff for drawing | `GainCoinsPerStatEffect stat=cards_drawn_this_turn per=1` |
| "Bought cards go to hand" item | trigger `BEFORE_CARD_BUY`, `SetBuyDestinationEffect destination=HAND` |
| A "first time only" item | `limit_per_encounter = 1` |
| An enemy that taxes you | Intent with `LoseCoinsEffect target=OPPONENT` |
| "Discard a card to draw 2" | `DiscardCardsEffect amount=1 as_cost=true`, `DrawCardsEffect 2` |
| "X OR Y" | `ChooseOneEffect` with two `EffectOption`s |
| "🔥 this ➡ …" | `TrashCardsEffect what=SELF as_cost=true` first |
| A curse | `curse=true`, `playable=false`; add it with `AddCardEffect target=SELF` |
| An enemy that denies the market | Intent with `SnatchShopCardEffect mode=PRICIEST` |
| Junk cards in the player's deck | Intent with `AddCardEffect card=<junk> zone=DRAW_BOTTOM target=OPPONENT` |
| A card that doesn't let the enemy respond | Add `ExtraActionEffect` to `on_play` |

## Current test content (`content/test/`)

Cards, items, trinkets and curses come from `tools/build_test_content.gd` (see the warning in [tools-and-deploy.md](tools-and-deploy.md#headless-tools-tools)). Names and costs of the ideas.md content are **placeholders**.

| Kind | What |
|---|---|
| Nimrod's cards | This is a card (`example1`), This is another card (`example2`), Draw Synergy (`drawful`) |
| Idea cards (44) | Every card idea from `design/ideas.md`, plus Pawn (listed under items, meant as a card). P1 is **Snowball** (dummy name). All in the market pool. |
| Curses (`content/test/curses/`) | C1 **Dead Weight** (does nothing), C2 **Barnacle** (permanent), C3 **Driftwood** (play: remove this), C4 **Leaky Purse** (end of turn in hand: lose 2 🪙). Dummy names; the ids match (`dead_weight`, `barnacle`, `driftwood`, `leaky_purse`). Not in the market. |
| Items (17) | Rebate, Express Delivery, the 11 item ideas, Shredder ("when you discard, remove it"), Needful (the whole shop costs 0, every purchase adds a random curse to your deck), **Top Shelf** (Market: when you buy a card you may put it on top of your deck) and **Stockroom** (Market: bought card slots restock) |
| Hunker Down | Retain card, cost 2: "Pass. 📌 your hand this turn" |
| On-buy placeholders | Every card without a real on-buy shows a "TBD" buy strip (`on_buy_text = "TBD"`) |
| Trinkets (7) | Coin Trinket + the 6 trinket ideas, 3 levels each |
| Enemy | TEST Moray: Pinch (steal 1) → Toll (you lose 1) → Snatch (priciest market card). 3 actions per round. |
| Encounter | TEST Encounter: 3 rounds, target 10, 3 card slots, 1 item slot, 1 trinket slot, 0 upgrade slots. Uses explicit pools, no `card_sets`. It is not in `encounter_pool`, but the tests and the simulator use it. |
| Enhancements (8) | One per set except Curses (`content/test/enhancements/`, built by `tools/build_enhancements.gd`): Gilded (Coins), Insight (Draw), Boomerang (Discard), Fleeting (Trim), Anchored (Retain), Hasty (Utility), Franchise (Market), Tainted (Curse Synergy). Placeholder names, price 3 each. |
| Loadout | 5× example2 + 3× example1, 3 coins |
| 5 themed encounters | Built by `tools/build_encounters.gd`; each just lists its two `card_sets` and the shop pools fill themselves by `card_set`. Each sells two sets + Utility + Coins, 3 rounds, target 10, 3 card / 1 item / 1 trinket slot. **Hag's Hex** (Trim + Curse Synergy, Sea Hag), **Ink Cloud** (Draw + Discard, Cuttlefish), **Toll Booth** (Market + Draw, Barracuda + the Toll item), **Loan Shark** (Curse Synergy + Market), **Clutter** (Discard + Trim, Hagfish). Enemies in `content/test/enemies/`, the Toll passive in `content/test/enemy_items/`. Names are placeholders. |

With the idea cards in the pool the greedy bot wins about 55% at target 10 (it plays the new cards badly, so treat it as a floor).
