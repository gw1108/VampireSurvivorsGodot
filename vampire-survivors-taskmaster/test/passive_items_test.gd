extends GdUnitTestSuite

## Verifies the 16 authored passive items (task 29) load via GameData and apply
## their cumulative per-level bonuses through StatSystem.recompute_block onto the
## player's StatBlock, using the REAL .tres (not inline defs). StatSystem already
## consumes passives in recompute_block; this pins the authored data is correct.

const ALL_IDS := [
	"spinach", "armor", "hollow_heart", "pummarola", "empty_tome",
	"candelabrador", "bracer", "spellbinder", "duplicator", "wings",
	"attractorb", "clover", "crown", "stone_mask", "skull_omaniac", "tiragisu",
]


func _player_with(passive_id: String, level: int) -> PlayerState:
	var p := PlayerState.new()
	var inst := PassiveInstance.new()
	inst.def = GameData.get_passive(passive_id)
	inst.level = level
	p.passives.append(inst)
	StatSystem.recompute_block(p)  # null character_def -> defaults + this passive
	return p


func test_all_sixteen_passives_load() -> void:
	for id in ALL_IDS:
		assert_object(GameData.get_passive(id)).is_not_null()
	assert_int(GameData.get_all_passives().size()).is_equal(16)


# --- multiplier stats (base 1.0, +X% => +0.0X cumulative) ---

func test_spinach_might() -> void:
	assert_float(_player_with("spinach", 3).stats.might).is_equal_approx(1.3, 0.0001)


func test_candelabrador_area() -> void:
	assert_float(_player_with("candelabrador", 5).stats.area).is_equal_approx(1.5, 0.0001)


func test_empty_tome_cooldown_reduction() -> void:
	assert_float(_player_with("empty_tome", 5).stats.cooldown).is_equal_approx(0.6, 0.0001)  # 1.0 - 0.4


func test_wings_move_speed() -> void:
	assert_float(_player_with("wings", 5).stats.move_speed).is_equal_approx(1.5, 0.0001)


func test_crown_growth() -> void:
	assert_float(_player_with("crown", 5).stats.growth).is_equal_approx(1.4, 0.0001)


func test_bracer_speed() -> void:
	assert_float(_player_with("bracer", 2).stats.speed).is_equal_approx(1.2, 0.0001)


# --- absolute stats ---

func test_armor_flat() -> void:
	assert_float(_player_with("armor", 5).stats.armor).is_equal(5.0)


func test_hollow_heart_max_health() -> void:
	assert_float(_player_with("hollow_heart", 2).stats.max_health).is_equal(140.0)  # 100 + 40


func test_pummarola_recovery() -> void:
	assert_float(_player_with("pummarola", 5).stats.recovery).is_equal_approx(1.0, 0.0001)


func test_attractorb_magnet() -> void:
	assert_float(_player_with("attractorb", 1).stats.magnet).is_equal(80.0)  # 64 + 16


func test_duplicator_amount() -> void:
	assert_int(_player_with("duplicator", 2).stats.amount).is_equal(2)  # 0 + 2


func test_duplicator_max_level_is_two() -> void:
	assert_int(GameData.get_passive("duplicator").max_level).is_equal(2)


func test_tiragisu_revival() -> void:
	assert_int(_player_with("tiragisu", 2).stats.revival).is_equal(2)
	assert_int(GameData.get_passive("tiragisu").max_level).is_equal(2)


# --- the bonus reaches derived after resolve() ---

func test_passive_flows_through_to_derived() -> void:
	var p := _player_with("spinach", 5)  # might 1.5 in the block
	StatSystem.resolve(p, null)
	assert_float(p.derived.might).is_equal_approx(1.5, 0.0001)
