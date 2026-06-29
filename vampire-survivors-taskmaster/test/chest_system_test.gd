extends SceneTree

## Headless test runner for the Task 11 ChestSystem.
##   godot --headless --path . --script res://test/chest_system_test.gd
## Exit code == number of failed checks (0 == all passed).

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== chest_system_test ==")
	_test_beginner_sequence()
	_test_gold_tiers()
	_test_greed_scaling()
	_test_post_sequence_roll()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _player() -> PlayerState:
	var p := PlayerState.new()
	var whip := WeaponInstance.new()
	whip.id = &"whip"
	p.weapons.append(whip)
	StatSystem.recompute(p, GDB)  # luck 1, greed 1
	return p

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _test_beginner_sequence() -> void:
	# First 6 chests follow 1-1-3-1-1-5 regardless of luck/rng.
	var p := _player()
	var ss := SpawnDirectorState.new()
	var rng := _rng(7)
	var counts: Array = []
	for i in range(6):
		var result := ChestSystem.open(p, ss, GDB, rng)
		counts.append((result.items as Array).size())
	_check(counts == [1, 1, 3, 1, 1, 5], "beginner-luck sequence 1-1-3-1-1-5 (got %s)" % str(counts))
	_check(ss.chests_opened == 6, "chests_opened advanced to 6")

func _test_gold_tiers() -> void:
	# Gold falls inside the tier band for the chest's item count.
	var p := _player()
	var ss := SpawnDirectorState.new()
	var rng := _rng(3)
	# chest 1 -> count 1 -> [100,200]
	var r1 := ChestSystem.open(p, ss, GDB, rng)
	_check(int(r1.gold) >= 100 and int(r1.gold) <= 200, "1-item chest gold in [100,200] (got %d)" % int(r1.gold))
	# chest 3 -> count 3 -> [300,600]
	ChestSystem.open(p, ss, GDB, rng)  # chest 2 (count 1)
	var r3 := ChestSystem.open(p, ss, GDB, rng)  # chest 3 (count 3)
	_check(int(r3.gold) >= 300 and int(r3.gold) <= 600, "3-item chest gold in [300,600] (got %d)" % int(r3.gold))
	# advance to chest 6 (count 5) -> [500,1000]
	ChestSystem.open(p, ss, GDB, rng)  # 4
	ChestSystem.open(p, ss, GDB, rng)  # 5
	var r5 := ChestSystem.open(p, ss, GDB, rng)  # 6 (count 5)
	_check(int(r5.gold) >= 500 and int(r5.gold) <= 1000, "5-item chest gold in [500,1000] (got %d)" % int(r5.gold))

func _test_greed_scaling() -> void:
	var p := _player()
	p.stats.greed = 2.0
	var ss := SpawnDirectorState.new()
	var before := p.gold
	var result := ChestSystem.open(p, ss, GDB, _rng(5))
	var applied := p.gold - before
	_check(applied == int(int(result.gold) * 2.0), "gold applied to player is rolled * greed (2x)")
	_check(int(result.gold) != applied, "returned gold is pre-greed, applied is post-greed")

func _test_post_sequence_roll() -> void:
	# After the 6 beginner chests, item count comes from the Luck-scaled roll.
	var p := _player()
	var ss := SpawnDirectorState.new()
	ss.chests_opened = 6  # past the beginner sequence
	var result := ChestSystem.open(p, ss, GDB, _rng(11))
	var n := (result.items as Array).size()
	_check(n == 1 or n == 3 or n == 5, "post-sequence chest yields 1, 3, or 5 items (got %d)" % n)
	_check(ss.chests_opened == 7, "chests_opened still increments past the sequence")
