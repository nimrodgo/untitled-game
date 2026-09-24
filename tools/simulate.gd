extends SceneTree
## Headless balance/smoke test: a greedy bot plays the player side N times
## against the encounter's scripted enemy.
## Run:  godot --headless --script res://tools/simulate.gd -- [encounter.tres] [loadout.tres] [runs]
## The bot is naive, so treat its win-rate as a rough floor.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var enc_path := args[0] if args.size() > 0 else "res://content/test/encounters/test_encounter.tres"
	var lo_path := args[1] if args.size() > 1 else "res://content/test/loadouts/test_loadout.tres"
	var runs := int(args[2]) if args.size() > 2 else 200

	var data: EncounterData = load(enc_path)
	var lo: LoadoutData = load(lo_path)
	var wins := 0
	var total_coins := 0
	var total_enemy_acts := 0
	for i in runs:
		var enc := Encounter.new(data, lo)
		var acts := [0]
		enc.enemy_turn_pending.connect(func(): acts[0] += 1)
		enc.start()
		var steps := 0
		while not enc.is_over and steps < 2000:
			if enc.active == enc.enemy:
				enc.enemy_act()
			else:
				SimBot.take_turn(enc)
			steps += 1
		if steps >= 2000:
			push_error("Encounter did not terminate!")
		total_coins += enc.player.coins
		total_enemy_acts += acts[0]
		if enc.won:
			wins += 1
	print("%s: %d runs | bot win %.0f%% | avg final coins %.1f (target %d) | enemy acts/encounter %.1f" % [
		data.display_name, runs, 100.0 * wins / runs, float(total_coins) / runs, data.coin_target,
		float(total_enemy_acts) / runs])
	quit()
