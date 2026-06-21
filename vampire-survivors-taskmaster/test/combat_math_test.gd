extends GdUnitTestSuite

## Tests CombatMath: damage scaling, crit rolls (chance bounds), armor floor,
## knockback direction/immunity, and squared-range checks with edge cases.

# --- calc_damage ---

func test_calc_damage_scales_by_might() -> void:
	assert_float(CombatMath.calc_damage(10.0, 1.5)).is_equal(15.0)


func test_calc_damage_might_one_is_identity() -> void:
	assert_float(CombatMath.calc_damage(10.0, 1.0)).is_equal(10.0)


func test_calc_damage_zero_base() -> void:
	assert_float(CombatMath.calc_damage(0.0, 2.0)).is_equal(0.0)


# --- roll_crit ---

func test_roll_crit_never_at_zero_chance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 50:
		var r := CombatMath.roll_crit(rng, 0.0, 2.0)
		assert_bool(r["is_crit"]).is_false()
		assert_float(r["multiplier"]).is_equal(1.0)


func test_roll_crit_always_at_full_chance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 50:
		var r := CombatMath.roll_crit(rng, 1.0, 2.0)
		assert_bool(r["is_crit"]).is_true()
		assert_float(r["multiplier"]).is_equal(2.0)


func test_roll_crit_is_deterministic_per_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 777
	b.seed = 777
	for i in 20:
		var ra := CombatMath.roll_crit(a, 0.5, 2.0)
		var rb := CombatMath.roll_crit(b, 0.5, 2.0)
		assert_bool(ra["is_crit"]).is_equal(rb["is_crit"])


# --- apply_armor ---

func test_apply_armor_reduces_damage() -> void:
	assert_float(CombatMath.apply_armor(10.0, 3.0)).is_equal(7.0)


func test_apply_armor_zero_armor_unchanged() -> void:
	assert_float(CombatMath.apply_armor(10.0, 0.0)).is_equal(10.0)


func test_apply_armor_floors_at_one() -> void:
	# Armor exceeding damage still leaves the VS minimum of 1.
	assert_float(CombatMath.apply_armor(5.0, 100.0)).is_equal(1.0)


func test_apply_armor_exact_floor() -> void:
	assert_float(CombatMath.apply_armor(10.0, 9.0)).is_equal(1.0)


# --- calc_knockback ---

func test_calc_knockback_direction_and_force() -> void:
	var kb := CombatMath.calc_knockback(Vector2.ZERO, Vector2(10.0, 0.0), 100.0, 0.0)
	assert_vector(kb).is_equal(Vector2(100.0, 0.0))


func test_calc_knockback_partial_resist_scales() -> void:
	var kb := CombatMath.calc_knockback(Vector2.ZERO, Vector2(10.0, 0.0), 100.0, 0.5)
	assert_vector(kb).is_equal(Vector2(50.0, 0.0))


func test_calc_knockback_full_resist_is_zero() -> void:
	var kb := CombatMath.calc_knockback(Vector2.ZERO, Vector2(10.0, 0.0), 100.0, 1.0)
	assert_vector(kb).is_equal(Vector2.ZERO)


func test_calc_knockback_over_resist_is_zero() -> void:
	var kb := CombatMath.calc_knockback(Vector2.ZERO, Vector2(10.0, 0.0), 100.0, 2.0)
	assert_vector(kb).is_equal(Vector2.ZERO)


func test_calc_knockback_coincident_points_is_zero() -> void:
	var kb := CombatMath.calc_knockback(Vector2(5.0, 5.0), Vector2(5.0, 5.0), 100.0, 0.0)
	assert_vector(kb).is_equal(Vector2.ZERO)


# --- is_in_range ---

func test_is_in_range_within() -> void:
	# (3,4) is distance 5 -> squared 25.
	assert_bool(CombatMath.is_in_range(Vector2.ZERO, Vector2(3.0, 4.0), 26.0)).is_true()


func test_is_in_range_at_boundary_inclusive() -> void:
	assert_bool(CombatMath.is_in_range(Vector2.ZERO, Vector2(3.0, 4.0), 25.0)).is_true()


func test_is_in_range_outside() -> void:
	assert_bool(CombatMath.is_in_range(Vector2.ZERO, Vector2(3.0, 4.0), 24.0)).is_false()
