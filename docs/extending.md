# Extending the Game

## Add a new effect (the most common change)

1. Create `scripts/data/effects/my_effect.gd`:

   ```gdscript
   class_name MyEffect
   extends Effect

   @export var amount: int = 1

   func apply(ctx: EffectContext) -> void:
       var who := ctx.resolve(target)
       # Mutate state only through Encounter helpers when one exists
       # (change_coins, draw_cards, add_card...) so logging stays consistent.

   func describe() -> String:
       return "%sDo %d thing" % [_who(), amount]   # _who() handles "Opponent"/"You:"

   func ai_score() -> float:
       return 1.0 * amount                          # used only by SimBot
   ```

   Don't change `target` in `_init()`: the saved default is always SELF, so a SELF target on such an effect wouldn't be saved. If the effect asks the player something, make `apply` a coroutine and `await ctx.encounter.request_choice(req)` (or `choose_cards(...)`). If it's a cost, override `can_pay` and `is_cost`.

2. Refresh the class cache (open the editor once). The effect now shows up in every Inspector effect array.
3. If it needs new state, add a field to `PlayerState` or `EffectContext`. If it needs a new engine operation, add a helper to `Encounter` that logs.

## Add a new trigger

1. Add it to `GameRules.Trigger`. **Append it at the end**, because saved `.tres` files store the number.
2. Call `_fire(GameRules.Trigger.X, side, _ctx(side))` at the right point in `Encounter`.
3. Add a phrase for it in `ItemData.get_description()`.

## Add a new stat or text placeholder

1. Add the field to `PlayerState` and reset it in `_start_round()` if it's per-round.
2. Update it wherever it changes.
3. Expose it in `Encounter.text_vars()` for `{name}` in text. `GainCoinsPerStatEffect` can use any `PlayerState` field automatically.

## Add a new card set

1. Append the id to `CardSets.Id` and an entry to `_INFO` (name, color) in `scripts/data/card_sets.gd`. **Only append**: the numbers are stored in `.tres` files.
2. Set `card_set` on the new pieces (`.tres` files, or the `SETS` map in `tools/build_test_content.gd`).
3. List the set in an encounter's `card_sets`. Nothing else: `ContentLibrary` finds the pieces by scanning `content/test/`.

## Add a new purchasable category

This touches everything, in this order: a new Data resource → `EncounterData` pool and slots → `ShopState` (bag, `setup`, `restock`, `take_*`) → `Encounter` (`can_buy_*`, `buy_*`, and an `*_IS_ACTION` rule) → the `_fill_shop()` group plus a drop target.

## Change the rules

Try `game_rules.gd` first. Run the simulator before and after any rule change:

```
godot --headless --path . --script res://tools/simulate.gd -- res://content/test/encounters/test_encounter.tres res://content/test/loadouts/test_loadout.tres 500
```

---

## Known gaps and quirks

| Area | Note |
|---|---|
| Run layer | No map, gold, persistent deck or loadout from the run yet. `gold_reward`, `CardData.art`, `tags` and `EnemyData.portrait` are unused. |
| Doc drift | `ItemData`'s header comment says items are bought "as a free action", but `ITEM_BUY_IS_ACTION = true`. |
| Item text | `ENEMY_ACTED` has no phrase in `ItemData.get_description()`. Write a custom description for items with that trigger. |
| Extra action | Ignored for trinket, trinket-upgrade and enhancement purchases (see [effects-reference.md](effects-reference.md#where-context-output-effects-work)). |
| Instant + enemy | Instant cards never trigger an enemy response, even with `ExtraActionEffect`. |
| Copies | `PlayCopyEffect` / replays resolve the original card's effects with that card as "this card", so copying "🔥 this ➡ …" destroys the original. |
| Curses | `permanent` is only a flag until the run layer exists. |
| Enemy choices | Enemies never get choices; effects that ask the player something are meant for the player's side. |
| `StealCoinsEffect` | Ignores `target`. It always takes from the opponent. |
| Test content | `tools/build_test_content.gd` is out of sync with the hand-edited `.tres` files, so regenerating overwrites those edits (see [tools-and-deploy.md](tools-and-deploy.md#headless-tools-tools)). Prefer editing the `.tres` files directly. |
| Enhancements | Only a card **in your hand** can be enhanced; there is no picker for the deck or discard pile. Prices (3) and names are placeholders. Fleeting ("immediately 🔥") is implemented as destroy-after-play, which is still to be confirmed. |
| Card sets | Retain has only 2 pieces. Market and Draw have no trinkets, Coins has no item. Toll Booth only sells the Coin Trinket, so Borrowed Power (Utility) is dead there. |
| Balance | The greedy bot wins about 55% at target 10 on the TEST Encounter. On the themed encounters it wins roughly 16–24% (Hag's Hex, Loan Shark) to 64–86% (Ink Cloud, Toll Booth, Clutter). It undervalues curse synergy, so treat these as a floor; the targets are untuned. |
| UI | Everything is built in code with placeholder colors and no art. Emoji rely on the `Icons` SVG set. |

## Next candidates

- The run layer: map, gold, persistent deck, loadout carried between encounters.
- Enhancements that scale with progression.
- Real card and enemy design by Nimrod, and art.
