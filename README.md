# Card Sharks — prototype

Aquatic roguelike deckbuilder where every encounter is a shop. Current slice:
one encounter, full rules engine, landscape (phone-friendly) placeholder UI, TEST content.

## Encounter rules (as implemented)
- An encounter lasts `rounds` rounds (default 3). Win = at least `coin_target` coins after the last round.
- Round start: you draw up to 5.
- Your **turn** = any number of FREE actions, then exactly ONE action (or Pass).
  - Free: play Instant cards, use a trinket (once per turn).
  - Action: play a non-instant card, buy a card / item / trinket / upgrade, or upgrade a trinket.
  - Pass: ends the round.
- The **enemy** doesn't play cards. It follows a scripted intent cycle (like Slay the Spire): after
  each of your actions it resolves its NEXT intent, which is always shown in advance. Intents are
  just effect lists (steal, make you lose coins, snatch a market card, shuffle junk into your deck…).
  The enemy can have passive items; it never buys items or trinkets.
- Bought cards resolve their **on-buy** effects, then get shuffled into your draw pile.
- Played cards stay "in play" until the round ends, then go to discard (prevents infinite draw loops).

Tunables live in `scripts/core/game_rules.gd` (which buys cost your action, how often the enemy acts, …).

## Controls
- Drag a card from your hand into the middle area to play it.
- Tap anything (cards, shop tiles, items, trinkets, the enemy's intent) to inspect it and see its actions.
- Shop is split into tabs: Cards / Items / Trinkets / Upgrades.
- Landscape only; on a phone held upright the game asks you to rotate.

## Playtest from anywhere (GitHub Pages)
Every push to `main` builds the Web version and publishes it to
`https://<your-user>.github.io/<repo>/` via `.github/workflows/deploy-web.yml`.
The Web export template is bundled in `export_templates/`, so the build needs no downloads besides Godot.

One-time setup:
1. Create a new **public** repository on github.com (Pages on private repos needs a paid plan).
   Don't add a README/.gitignore there — the project already has them.
2. Push this folder to it. Easiest: GitHub Desktop → File → Add local repository → pick this folder →
   "create a repository" → Publish. Or from a terminal in this folder:
   ```
   git init -b main
   git add .
   git commit -m "Card Sharks prototype"
   git remote add origin https://github.com/<your-user>/<repo>.git
   git push -u origin main
   ```
3. On GitHub: repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
   Then **Actions → "Deploy web build to GitHub Pages" → Run workflow** (only needed the first time;
   afterwards every push redeploys automatically, ~2 minutes).
4. Open the link on your phone, turn it sideways, and tap **Fullscreen** (locks landscape on Android).

Same-Wi-Fi alternative without GitHub: `playtest_mobile.bat` exports and serves the build over HTTPS
from your PC (`tools/serve_web.gd`); accept the self-signed certificate warning on the phone.

## Where things are
- `scripts/data/` — Resource types you design with: CardData, ItemData, TrinketData (+TrinketLevel),
  EnhancementData, EnemyData (+EnemyIntent), EncounterData, LoadoutData.
- `scripts/data/effects/` — effect primitives (gain/lose/steal coins, draw, discard, buy destination,
  extra action, snatch market card, add card). New mechanics = new Effect subclass.
- `scripts/core/encounter.gd` — rules engine (UI-agnostic).
- `scripts/ui/` — code-built mobile UI (`encounter_screen.gd`, `hand_view.gd` = drag/fan, `card_view.gd`).
- `scripts/sim/sim_bot.gd` — greedy player bot, used only by the simulator.
- `content/_placeholder/` — TEST content only, to exercise systems. Replace freely.

## Designing content
In the editor: FileSystem → right-click a folder → New Resource → CardData (etc.). Add effects in the
inspector arrays. Enemies: create an EnemyData and add EnemyIntent entries to `intents` (they loop in order).
Point an EncounterData at your enemy and pools, and set it on the Main node in `scenes/main.tscn`.

## Tools (headless)
- `godot --headless --script res://tools/simulate.gd -- <encounter.tres> <loadout.tres> <runs>`
  Greedy bot vs the scripted enemy N times; prints win rate / avg coins / enemy actions.
- `godot --headless --script res://tools/build_placeholder_content.gd` regenerates TEST content.
