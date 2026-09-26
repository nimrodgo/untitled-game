# UI

The whole UI is **built in code** (`scripts/ui/encounter_screen.gd`, attached to `Main`), so it's easy to swap for real scenes and art later. It talks only to `Encounter`.

## Screen layout (1280×720 landscape)

```
┌──────────── LEFT (290px) ─────────────┬──────────────── RIGHT (expands) ────────────────┐
│ Round 1/3     [ 7 / 10 ] ▓▓▓▓▓░░       │  CARDS                                          │
│ ┌ Enemy ──────────────────────────┐   │  [card] [card] [card]                           │
│ │ (M) TEST Moray   2 coins  ●●○   │   │                                                 │
│ │ ┌ NEXT · STEAL ───────────────┐ │   │  ITEMS            TRINKETS        (UPGRADES)    │
│ │ │ Pinch  Steal 1 🪙           │ │   │  [item] [item]    [trinket]                     │
│ │ └─────────────────────────────┘ │   ├─────────────────────────────────────────────────┤
│ └─────────────────────────────────┘   │        ╭hand fanned 5 cards╮     [deck] [Pass]  │
│ TRINKETS [Coin Trinket]  ITEMS [ + ]  │                                                 │
│ [Log] [Fullscreen] [Exit*]            │                                                 │
└───────────────────────────────────────┴─────────────────────────────────────────────────┘
* Exit is hidden on web.
```

- Market tiles **resize to fit the screen**. Cards take about 58% of the market's height when there's a gear row. `_fill_shop()` does the math.
- If the screen is in portrait, a **"Please rotate"** overlay covers everything (`_check_orientation`).
- **Fullscreen** on the web also tries `screen.orientation.lock('landscape')`.

## Interactions

| Gesture | Result | Visual feedback |
|---|---|---|
| Drag a hand card out of the hand area | Play it | The card grows and turns gold once releasing would play it, then pops above the hand |
| Drag a market card onto the **deck** | Buy it | The deck pulses while you drag and glows on hover. The card shrinks as it flies in. |
| Drag an item or trinket onto its **slot panel** | Buy it | Same, with the Items or Trinkets panel |
| Tap anything | Inspect popup, with action buttons (Play / Buy / Use / Upgrade) | — |
| Tap the deck | Deck viewer (the draw pile is sorted so it doesn't reveal the order), hand, played cards, discard | — |
| Tap the intent bubble | The next 4 intents, and actions left | — |
| Upgrade → "Choose card" → tap a hand card | Enhance it | Hand cards get a gold highlight |
| Hover (desktop) | The hand card lifts; market tiles grow slightly | — |

- **Tap vs drag:** moving less than `TAP_SLOP` (16px) counts as a tap. Moving more than `DRAG_START` (14px) starts a drag.
- Input is mouse-based. On phones, touch is emulated as mouse (`project.godot`).

## Components

| File | Class | Role |
|---|---|---|
| `encounter_screen.gd` | — | Builds the layout, refreshes on `changed`, handles market drag, popups, the log, the end overlay, and the enemy timer |
| `card_view.gd` | `CardView` | One tile type for cards, items, trinkets, upgrades and intents. `CardView.make(title, cost, body, bg, size, tag, footer, buy_text)`. Sizes are `SMALL` 124×184, `HAND` 144×200, `LARGE` 360×500. Text scales with size. |
| `hand_view.gd` | `HandView` | Fan layout, hover lift, drag to play, deal-in from the deck. It tracks card `uid`s to animate only new cards. |
| `pile_view.gd` | `PileView` | Deck stack with a count and discard count. It's a drop target and can be tapped. |
| `drop_target.gd` | `DropTarget` | A panel with `IDLE` / `ACTIVE` (pulsing) / `HOVER` (gold) states |
| `fx.gd` | `Fx` | `float_text` (coin ±), `fly_into` (buy), `resolve` (play), `shake` |
| `icons.gd` | `Icons` | Runtime SVG icons for 🪙 🂠 ⚡ 🛍. `rich_label()` and `append()` turn the tokens in text into inline images. |
| `palette.gd` | `Palette` | Placeholder aquatic colors, plus `Palette.box()` as a StyleBox helper |

## Card visual anatomy

```
┌───────────────────────── ●cost┐
│ Name                          │
│ INSTANT (auto tag, only when  │
│   there's no custom text)     │
│ On-play text…                 │
│ + Enhancement names (coral)   │
│ ┌ 🛍 on-buy text (gold strip)┐│
│ └───────────────────────────┘ │
└───────────────────────────────┘
```

**Colors:** cards `CARD` (blue), items `CARD_ITEM` (green), trinkets `CARD_TRINKET` (brown-gold), upgrades `CARD_ENH` (purple).

## Feedback and animation list

- Round banner, and the market fades in on restock.
- Coin `+N` / `−N` floaters next to your counter and the enemy's.
- The intent bubble pulses when the enemy is about to act. It fades once the enemy has no actions left this round.
- When the enemy snatches a card, a ghost flies from the market slot to the enemy portrait.
- The hand dims while the enemy acts.
- New cards are dealt in from the deck.
- The end overlay says "Victory!" or "Sunk." and has **Play again**, which reloads the scene.

## Pattern: ghosts

Every state change rebuilds the market and hand from scratch. So animations use **ghost** copies added to `_fx_layer` (`_add_fx`). Actions that would free the node being dragged are **deferred** with `call_deferred`.
