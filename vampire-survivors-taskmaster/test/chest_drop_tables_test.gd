extends SceneTree

## Task 31 — integrity test for the chest / brazier-drop / gem-tier tables in
## GameDatabase, plus the new roll_brazier_drop() weighted roller.
##   godot --headless --path . --script res://test/chest_drop_tables_test.gd
## Exit code == number of failed checks (0 == all passed).
##
## NOTE: this task's sketch proposed re-authoring these tables, but they already
## exist (Task 4) under the canonical wiki-verbatim schema and are consumed by
## ChestSystem / CollisionSystem. The sketch's numbers CONFLICT (chest count
## chances 0.10/0.30/0.60 vs the wiki's 0.03/0.10/0.50) and its flat
## BRAZIER_DROPS dict would clobber the richer weighted+min_level Array. So we
## LOCK the existing data with an integrity test instead of regressing it, and
## add only the genuinely-missing weighted brazier roller.

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== chest_drop_tables_test ==")
	_test_gem_tiers()
	_test_chest_tables()
	_test_brazier_table()
	_test_brazier_roller()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_gem_tiers() -> void:
	_check(GDB.GEM_BLUE_MAX == 2.0, "blue gem threshold is XP <= 2")
	_check(GDB.GEM_GREEN_MAX == 9.0, "green gem threshold is XP <= 9")
	_check(GDB.gem_tier(1.0) == &"blue", "1 XP -> blue")
	_check(GDB.gem_tier(2.0) == &"blue", "2 XP -> blue (boundary)")
	_check(GDB.gem_tier(2.01) == &"green", "just over 2 XP -> green")
	_check(GDB.gem_tier(9.0) == &"green", "9 XP -> green (boundary)")
	_check(GDB.gem_tier(9.01) == &"red", "over 9 XP -> red")

func _test_chest_tables() -> void:
	# Beginner-luck sequence for the first 6 chests.
	_check(GDB.CHEST_BEGINNER_LUCK == [1, 1, 3, 1, 1, 5], "beginner-luck sequence is 1-1-3-1-1-5")
	# Sequential 5 -> 3 -> 1 chances (canonical wiki values, NOT the sketch's).
	var cc: Dictionary = GDB.CHEST_COUNT_CHANCE
	_check(is_equal_approx(float(cc.get("five", -1)), 0.03), "chest 5-item chance 0.03 (wiki)")
	_check(is_equal_approx(float(cc.get("three", -1)), 0.10), "chest 3-item chance 0.10 (wiki)")
	_check(is_equal_approx(float(cc.get("one", -1)), 0.50), "chest 1-item chance 0.50 (wiki)")
	# Gold per tier [min, max].
	var cg: Dictionary = GDB.CHEST_GOLD
	_check(cg.get("one", []) == [100, 200], "1-item chest gold 100-200")
	_check(cg.get("three", []) == [300, 600], "3-item chest gold 300-600")
	_check(cg.get("five", []) == [500, 1000], "5-item chest gold 500-1000")

func _test_brazier_table() -> void:
	var drops: Array = GDB.BRAZIER_DROPS
	_check(drops.size() >= 8, "brazier drop table populated (>=8 entries)")
	var total_weight := 0
	var ids := {}
	var well_formed := true
	for d in drops:
		if not (d.has("pickup") and d.has("weight") and d.has("min_level")):
			well_formed = false
			continue
		total_weight += int(d["weight"])
		ids[d["pickup"]] = true
		if int(d["weight"]) <= 0 or int(d["min_level"]) < 0:
			well_formed = false
	_check(well_formed, "every brazier entry has pickup + positive weight + non-negative min_level")
	_check(total_weight > 0, "brazier weights sum positive")
	_check(ids.has(&"gold_coin") and ids.has(&"chicken") and ids.has(&"rerollo"), "brazier drops include gold, chicken, and a reroll source")

func _test_brazier_roller() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31_31_31
	# Level 0: only entries with min_level 0 are eligible.
	var eligible_l0 := {}
	var gated := {}
	for d in GDB.BRAZIER_DROPS:
		if int(d["min_level"]) <= 0:
			eligible_l0[d["pickup"]] = true
		else:
			gated[d["pickup"]] = true
	var all_in_set := true
	var any_gated_leaked := false
	for i in range(3000):
		var got := GDB.roll_brazier_drop(rng, 0)
		if not eligible_l0.has(got):
			all_in_set = false
		if gated.has(got):
			any_gated_leaked = true
	_check(all_in_set, "level-0 rolls only return min_level-0 pickups")
	_check(not any_gated_leaked, "level-0 rolls never leak a level-gated drop (e.g. vacuum/rosary)")

	# High level: a high-min_level drop (e.g. vacuum, min 12) becomes reachable.
	rng.seed = 7_007
	var saw_high := false
	for i in range(4000):
		if GDB.roll_brazier_drop(rng, 20) == &"vacuum":
			saw_high = true
			break
	_check(saw_high, "high-level rolls can yield a level-gated drop (vacuum at L20)")
	# No eligible entries (all min_level >= 0) -> empty result, no crash.
	_check(GDB.roll_brazier_drop(rng, -1) == &"", "no eligible drops (level -1) returns empty")
	# Deterministic with a fixed seed.
	var a := RandomNumberGenerator.new(); a.seed = 99
	var b := RandomNumberGenerator.new(); b.seed = 99
	_check(GDB.roll_brazier_drop(a, 5) == GDB.roll_brazier_drop(b, 5), "roller is deterministic for a fixed seed")
