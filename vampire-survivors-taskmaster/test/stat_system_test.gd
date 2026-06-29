extends SceneTree

## Headless test runner for the Task 5 StatSystem.
##   godot --headless --path . --script res://test/stat_system_test.gd
## Exit code == number of failed checks (0 == all passed).
## Uses the GameDatabase script class as `db` (passive() is static -> clean call).

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== stat_system_test ==")
	_test_base()
	_test_level_might_bonus()
	_test_single_passives()
	_test_hollow_heart_multiplicative()
	_test_combined_build()
	_test_idempotent_and_reset()
	_test_stats_autocreate()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _approx(a: float, b: float, msg: String) -> void:
	_check(is_equal_approx(a, b), "%s (got %f, want %f)" % [msg, a, b])

func _add_passive(player, id: StringName, level: int) -> void:
	var p := PassiveInstance.new()
	p.id = id
	p.level = level
	player.passives.append(p)

func _test_base() -> void:
	var player := PlayerState.new()  # level 1, no passives
	StatSystem.recompute(player, GDB)
	var s: StatBlock = player.stats
	_approx(s.max_health, 120.0, "base max_health = 100 + 20 (Antonio)")
	_approx(s.armor, 1.0, "base armor = 0 + 1 (Antonio)")
	_approx(s.might, 1.0, "base might 1.0 (no level bonus at L1)")
	_approx(s.move_speed, 1.0, "base move_speed 1.0")
	_approx(s.area, 1.0, "base area 1.0")
	_approx(s.speed, 1.0, "base speed 1.0")
	_approx(s.duration, 1.0, "base duration 1.0")
	_approx(s.cooldown, 1.0, "base cooldown 1.0")
	_approx(s.amount, 0.0, "base amount 0")
	_approx(s.magnet, 30.0, "base magnet 30px")
	_approx(s.recovery, 0.0, "base recovery 0")
	_approx(s.luck, 1.0, "base luck 1.0")
	_approx(s.growth, 1.0, "base growth 1.0")
	_approx(s.greed, 1.0, "base greed 1.0")
	_approx(s.curse, 1.0, "base curse 1.0")
	_check(player.stats_dirty == false, "stats_dirty cleared after recompute")

func _test_level_might_bonus() -> void:
	for case in [[1, 1.0], [9, 1.0], [10, 1.10], [25, 1.20], [50, 1.50], [60, 1.50]]:
		var player := PlayerState.new()
		player.level = case[0]
		StatSystem.recompute(player, GDB)
		_approx(player.stats.might, case[1], "might at level %d" % case[0])

func _test_single_passives() -> void:
	# Spinach L5 -> might +0.5
	var p1 := PlayerState.new()
	_add_passive(p1, &"spinach", 5)
	StatSystem.recompute(p1, GDB)
	_approx(p1.stats.might, 1.5, "Spinach L5 -> might 1.5")
	# Armor L5 -> armor 1 (Antonio) + 5
	var p2 := PlayerState.new()
	_add_passive(p2, &"armor", 5)
	StatSystem.recompute(p2, GDB)
	_approx(p2.stats.armor, 6.0, "Armor L5 -> armor 6")
	# Empty Tome L5 -> cooldown 1.0 - 0.40 (sign correct)
	var p3 := PlayerState.new()
	_add_passive(p3, &"empty_tome", 5)
	StatSystem.recompute(p3, GDB)
	_approx(p3.stats.cooldown, 0.60, "Empty Tome L5 -> cooldown 0.60 (reduced, not increased)")
	# Candelabrador L3 -> area 1.3
	var p4 := PlayerState.new()
	_add_passive(p4, &"candelabrador", 3)
	StatSystem.recompute(p4, GDB)
	_approx(p4.stats.area, 1.3, "Candelabrador L3 -> area 1.3")
	# Bracer L5 -> speed 1.5
	var p5 := PlayerState.new()
	_add_passive(p5, &"bracer", 5)
	StatSystem.recompute(p5, GDB)
	_approx(p5.stats.speed, 1.5, "Bracer L5 -> speed 1.5")
	# Wings L5 -> move_speed 1.5
	var p6 := PlayerState.new()
	_add_passive(p6, &"wings", 5)
	StatSystem.recompute(p6, GDB)
	_approx(p6.stats.move_speed, 1.5, "Wings L5 -> move_speed 1.5")
	# Duplicator L2 -> amount 2
	var p7 := PlayerState.new()
	_add_passive(p7, &"duplicator", 2)
	StatSystem.recompute(p7, GDB)
	_approx(p7.stats.amount, 2.0, "Duplicator L2 -> amount 2")

func _test_hollow_heart_multiplicative() -> void:
	# L1: 120 * 1.2 = 144
	var p1 := PlayerState.new()
	_add_passive(p1, &"hollow_heart", 1)
	StatSystem.recompute(p1, GDB)
	_approx(p1.stats.max_health, 144.0, "Hollow Heart L1 -> 120 * 1.2 = 144")
	# L5: 120 * 1.2^5 = 298.5984 (+149%), NOT the additive 240 (+100%)
	var p5 := PlayerState.new()
	_add_passive(p5, &"hollow_heart", 5)
	StatSystem.recompute(p5, GDB)
	_approx(p5.stats.max_health, 120.0 * pow(1.2, 5), "Hollow Heart L5 -> 120 * 1.2^5 (multiplicative)")
	_check(p5.stats.max_health > 295.0, "Hollow Heart L5 exceeds additive ceiling of 240")

func _test_combined_build() -> void:
	var player := PlayerState.new()
	player.level = 20
	_add_passive(player, &"spinach", 5)       # +0.5 might
	_add_passive(player, &"armor", 3)          # +3 armor
	_add_passive(player, &"hollow_heart", 2)   # x1.2^2 max hp
	_add_passive(player, &"empty_tome", 4)     # -0.32 cooldown
	StatSystem.recompute(player, GDB)
	var s: StatBlock = player.stats
	# might = 1.0 + level(2*0.10) + spinach 0.5
	_approx(s.might, 1.70, "combined might = 1 + 0.20(level) + 0.50(spinach)")
	_approx(s.armor, 4.0, "combined armor = 1 + 3")
	_approx(s.max_health, 120.0 * pow(1.2, 2), "combined max_health = 120 * 1.2^2")
	_approx(s.cooldown, 1.0 - 0.08 * 4, "combined cooldown = 1 - 0.32")

func _test_idempotent_and_reset() -> void:
	var player := PlayerState.new()
	_add_passive(player, &"spinach", 3)  # +0.3 might
	StatSystem.recompute(player, GDB)
	var first := player.stats.might
	StatSystem.recompute(player, GDB)  # twice -> must not accumulate
	_approx(player.stats.might, first, "recompute is idempotent (no accumulation)")
	_approx(player.stats.might, 1.3, "Spinach L3 -> might 1.3")
	# removing the passive and recomputing returns to base
	player.passives.clear()
	StatSystem.recompute(player, GDB)
	_approx(player.stats.might, 1.0, "stats reset to base when passive removed")
	_approx(player.stats.armor, 1.0, "armor reset to Antonio base")

func _test_stats_autocreate() -> void:
	var player := PlayerState.new()
	_check(player.stats == null, "PlayerState.stats starts null")
	StatSystem.recompute(player, GDB)
	_check(player.stats != null and player.stats is StatBlock, "recompute creates StatBlock when null")
