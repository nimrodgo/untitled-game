# Designing Content

All content is Godot **Resources** (`.tres`). There are two ways to make them:

- **In the editor:** FileSystem → right-click a folder → **New Resource** → pick the type (e.g. `CardData`), then fill in the Inspector. Add effects with the array's **+** button → **New *XxxEffect***.
- **From a script:** see `tools/build_test_content.gd`, which regenerates `content/test/`. If you edit test `.tres` files by hand, re-running that script **overwrites** your changes.

To play your content, point an `EncounterData` at your pools and enemy, then set it (plus a `LoadoutData`) on the **Main** node in `scenes/main.tscn`.

## Resource types

### CardData — a card

| Field | Default | Notes |
|---|---|---|
| `id` | — | StringName for reference |
| `display_name` | "New Card" | |
| `cost` | 1 | Coins to buy it from the market |
| `instant` | false | Playing it is a **free** action |
| `on_play` | [] | Effects when played |
| `on_buy` | [] | Effects once, when bought |
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
| `description` | "" | Auto: "*When…* (*limit*): *effects*" |

### TrinketData + TrinketLevel — an activated ability

- `TrinketData`: `cost` (default 4), `levels: Array[TrinketLevel]`, `description`.
- `TrinketLevel`: `upgrade_cost` (ignored for level 1), `effects`, `text`.
- You can use each trinket once per turn. Upgrading moves it to the next level. The name shows "(Lv N)" only when a trinket has more than one level.
- **Style rule:** don't write "once per turn" or "(free)" on trinkets.

### EnhancementData — a market "upgrade" for one card

| Field | Notes |
|---|---|
| `cost` | default 2 |
| `make_instant` | The card becomes instant |
| `extra_on_play` | Effects added after the card's own on-play effects |
| `description` | Auto-generated if empty |

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
| `card_pool` | [] | Duplicates raise the odds |
| `item_pool`, `trinket_pool`, `enhancement_pool` | [] | Each is drawn without repeats |
| `card_slots` / `item_slots` / `trinket_slots` / `enhancement_slots` | 5 / 2 / 1 / 1 | A pool with no slots is hidden from the market |
| `refill_card_slots` | false | Legacy: refills a card slot right after it's bought |
| `rng_seed` | 0 | 0 = random |

### LoadoutData — what the player starts with

`starting_deck`, `starting_coins` (3), `items`, `trinkets`. Later this will come from the run.

## Writing card text

- **BBCode** works: `[i]`, `[b]`, `[color=#hex]`.
- **Icons:** type these characters and they render as inline SVG icons (the web build has no emoji font):

  | Token | Icon | Use for |
  |---|---|---|
  | `🪙` | coin | coins |
  | `🂠` | card | cards |
  | `⚡` (or `🗲`) | bolt | instant |
  | `🛍` | bag | on-buy (the card frame adds it automatically) |

- **Live values** go in braces and update while you play: `{cards_drawn_this_turn}`, `{cards_played_this_turn}`, `{coins}`, `{round}`. The `_this_round` versions are aliases. The full list is in [effects-reference.md](effects-reference.md#text-placeholders).
- Example: `Gain 1 🪙 for every card drawn this turn ([i]{cards_drawn_this_turn}[/i])`

## Recipes

| I want… | Do this |
|---|---|
| A card that draws | `on_play: [DrawCardsEffect amount=2]` |
| A free coin card | `instant = true`, `on_play: [GainCoinsEffect 1]`, text `⚡Gain 1 🪙` |
| A payoff for drawing | `GainCoinsPerStatEffect stat=cards_drawn_this_turn per=1` |
| "Bought cards go to hand" item | trigger `BEFORE_CARD_BUY`, `SetBuyDestinationEffect destination=HAND` |
| A "first time only" item | `limit_per_encounter = 1` |
| An enemy that taxes you | Intent with `LoseCoinsEffect` (its default target is OPPONENT) |
| An enemy that denies the market | Intent with `SnatchShopCardEffect mode=PRICIEST` |
| Junk cards in the player's deck | Intent with `AddCardEffect card=<junk> zone=DRAW_SHUFFLE` |
| A card that doesn't let the enemy respond | Add `ExtraActionEffect` to `on_play` |

## Current test content (`content/test/`)

| Kind | Name | Cost | Effect |
|---|---|---|---|
| Card | This is a card (`example1`) | 1 | Draw 2 🂠 · 🛍 Draw 1 🂠 |
| Card | This is another card (`example2`) | 0 | ⚡Gain 1 🪙 · 🛍 Gain 1 🪙 |
| Card | Draw Synergy (`drawful`) | 3 | Gain 1 🪙 per card drawn this turn · 🛍 Draw 1 🂠 |
| Item | Rebate | 3 | Gain 1 🪙 when you buy a card |
| Item | Express Delivery | 2 | The first card you buy each encounter goes to your hand |
| Trinket | Coin Trinket | 4 | ⚡Gain 1 🪙 |
| Enemy | TEST Moray | — | Pinch (steal 1) → Toll (you lose 1) → Snatch (priciest market card). 3 actions per round. |
| Encounter | TEST Encounter | — | 3 rounds, target 10, 3 card slots, 2 item slots, 1 trinket slot, 0 upgrade slots |
| Loadout | test_loadout | — | 5× example2 + 3× example1, 3 coins |

The simulator's greedy bot wins about 94% of the time at target 10, so the target is probably too low.
