# Card Sharks — prototype

Aquatic roguelike deckbuilder where **every encounter is a shop**. You don't fight with damage: you race to
reach a coin target while an enemy steals, taxes and snatches from the market.

Current slice: a full rules engine, a landscape (phone-friendly) placeholder UI, TEST content grouped into
8 card sets, and 5 themed encounters (one is picked at random on every launch). No run layer yet.
Godot **4.6.3**, GDScript, GL Compatibility.

**Playtest:** https://nimrodgo.github.io/untitled-game/ (rebuilt on every push to `main`).

## Quick start
1. Open this folder in Godot 4.6.3 and press **F5**.
2. Drag a card out of your hand to play it. Drag a market card onto your deck to buy it.
3. Have at least 10 coins after round 3.

## Controls
- **Play:** drag a card out of your hand and let go. It glows gold once releasing would play it.
- **Buy a card:** drag it from the market onto your deck (bottom right).
- **Buy an item / trinket:** drag it onto your Items / Trinkets slots (left). Valid targets pulse while you drag.
- **Upgrade (enhancement):** tap the upgrade tile, pay, then tap a card in your hand.
- **Inspect:** tap anything (cards, market tiles, gear, the enemy's intent, your deck) for details and buttons.
- **Card layout:** the main text is what the card does when played; the gold strip with the bag icon at the
  bottom is what it does when bought.
- Landscape only; on a phone held upright the game asks you to rotate. On the web, tap **Fullscreen**, or
  install it as an app (Chrome: in-game **Install** button or menu ⋮ → Add to Home screen).

## Documentation
Everything else lives in [`docs/`](docs/README.md):

| Doc | Contents |
|---|---|
| [game-rules.md](docs/game-rules.md) | How an encounter plays out: rounds, actions, enemy, market, win condition, tunables |
| [architecture.md](docs/architecture.md) | Code layers, classes, signals |
| [content-design.md](docs/content-design.md) | Making cards, items, trinkets, enhancements, enemies, encounters; card sets |
| [effects-reference.md](docs/effects-reference.md) | Every effect primitive, trigger, zone and text placeholder |
| [ui.md](docs/ui.md) | Screen layout, drag and drop, card visuals |
| [tools-and-deploy.md](docs/tools-and-deploy.md) | Simulator, content generators, tests, phone playtest, GitHub Pages deploy |
| [extending.md](docs/extending.md) | Adding mechanics, known gaps |

Ideas for future cards and items are in [`design/ideas.md`](design/ideas.md).

## Headless tools (from the project folder)
```
godot --headless --path . --script res://tools/test_mechanics.gd      # rules tests
godot --headless --path . --script res://tools/simulate.gd -- <encounter.tres> <loadout.tres> <runs>
```
See [tools-and-deploy.md](docs/tools-and-deploy.md) for all tools, including the content generators
(read the warning there before re-running `build_test_content.gd`).
