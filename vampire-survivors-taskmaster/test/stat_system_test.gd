extends GdUnitTestSuite

## Tests StatSystem: block->derived copy, cap enforcement, character base +
## growth, and passive stacking. Includes an integration test on Antonio.tres.

func _passive(stat: String, per_level: Array, level: int) -> PassiveInstance:
	var d := PassiveDef.new()
	d.stat_bonuses = {stat: per_level}
	var p := PassiveInstance.new()
	p.def = d
	p.level = level
	return p


func test_resolve_copies_block_to_derived() -> void:
	var player := PlayerState.new()
	player.stats.might = 1.5
	player.stats.magnet = 100.0
	player.stats.amount = 2
	StatSystem.resolve(player)
	assert_float(player.derived.might).is_equal(1.5)
	assert_float(player.derived.magnet).is_equal(100.0)
	assert_int(player.derived.amount).is_equal(2)


func test_resolve_caps_cooldown_floor() -> void:
	var player := PlayerState.new()
	player.stats.cooldown = 0.05  # below the 10% floor
	StatSystem.resolve(player)
	assert_float(player.derived.cooldown).is_equal(0.1)


func test_resolve_caps_move_speed_and_area() -> void:
	var player := PlayerState.new()
	player.stats.move_speed = 5.0
	player.stats.area = 10.0
	StatSystem.resolve(player)
	assert_float(player.derived.move_speed).is_equal(StatSystem.MAX_MOVE_SPEED_MULT)
	assert_float(player.derived.area).is_equal(StatSystem.MAX_AREA_MULT)


func test_resolve_caps_armor_both_ends() -> void:
	var hi := PlayerState.new()
	hi.stats.armor = 250.0
	StatSystem.resolve(hi)
	assert_float(hi.derived.armor).is_equal(StatSystem.MAX_ARMOR)
	var lo := PlayerState.new()
	lo.stats.armor = -5.0
	StatSystem.resolve(lo)
	assert_float(lo.derived.armor).is_equal(StatSystem.MIN_ARMOR)


func test_resolve_stage_curse_modifier() -> void:
	var player := PlayerState.new()
	var stage := StageDef.new()
	stage.stat_modifiers = {"curse": 1.5}
	StatSystem.resolve(player, stage)
	assert_float(player.derived.curse).is_equal(1.5)


func test_recompute_block_resets_to_defaults() -> void:
	var player := PlayerState.new()
	player.stats.might = 99.0  # stale value
	StatSystem.recompute_block(player)
	assert_float(player.stats.might).is_equal(1.0)  # reset
	assert_float(player.stats.max_health).is_equal(100.0)


func test_recompute_block_single_passive() -> void:
	var player := PlayerState.new()
	player.passives.append(_passive("might", [0.1, 0.2, 0.3, 0.4, 0.5], 3))
	StatSystem.recompute_block(player)
	assert_float(player.stats.might).is_equal_approx(1.3, 0.0001)  # 1.0 + 0.3


func test_recompute_block_passive_stacking_additive() -> void:
	var player := PlayerState.new()
	player.passives.append(_passive("might", [0.1, 0.2], 2))  # +0.2
	player.passives.append(_passive("might", [0.1, 0.2], 1))  # +0.1
	StatSystem.recompute_block(player)
	assert_float(player.stats.might).is_equal_approx(1.3, 0.0001)  # 1.0 + 0.2 + 0.1


func test_recompute_block_passive_level_clamps_to_array() -> void:
	var player := PlayerState.new()
	# Level 9 but array only has 3 entries -> clamp to last (0.3).
	player.passives.append(_passive("might", [0.1, 0.2, 0.3], 9))
	StatSystem.recompute_block(player)
	assert_float(player.stats.might).is_equal_approx(1.3, 0.0001)


func test_antonio_base_stats_at_level_1() -> void:
	var antonio: CharacterDef = load("res://data/character_antonio.tres")
	var player := PlayerState.new()
	player.level = 1
	StatSystem.recompute_block(player, antonio)
	StatSystem.resolve(player)
	assert_float(player.derived.max_health).is_equal(120.0)  # +20
	assert_float(player.derived.armor).is_equal(1.0)  # +1
	assert_float(player.derived.might).is_equal(1.0)  # no growth yet


func test_antonio_might_growth_stepped() -> void:
	var antonio: CharacterDef = load("res://data/character_antonio.tres")
	# +10% Might every 10 levels, capped at +50%.
	var cases := {1: 1.0, 9: 1.0, 10: 1.1, 25: 1.2, 50: 1.5, 60: 1.5}
	for level: int in cases:
		var player := PlayerState.new()
		player.level = level
		StatSystem.recompute_block(player, antonio)
		assert_float(player.stats.might).is_equal_approx(cases[level], 0.0001)


func test_character_growth_and_passive_combine() -> void:
	var antonio: CharacterDef = load("res://data/character_antonio.tres")
	var player := PlayerState.new()
	player.level = 10  # +0.1 Might from growth
	player.passives.append(_passive("might", [0.1], 1))  # +0.1 from passive
	StatSystem.recompute_block(player, antonio)
	StatSystem.resolve(player)
	assert_float(player.derived.might).is_equal_approx(1.2, 0.0001)  # 1.0 + 0.1 + 0.1
