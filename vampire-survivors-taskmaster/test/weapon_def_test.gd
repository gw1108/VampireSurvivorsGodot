extends GdUnitTestSuite

## Verifies WeaponDef construction, defaults, and exported field access.

func test_defaults() -> void:
	var w := WeaponDef.new()
	assert_str(w.id).is_empty()
	assert_str(w.name).is_empty()
	assert_str(w.description).is_empty()
	assert_float(w.base_damage).is_equal(0.0)
	assert_float(w.cooldown).is_equal(0.0)
	assert_int(w.pierce).is_equal(1)
	assert_float(w.projectile_speed).is_equal(200.0)
	assert_float(w.area).is_equal(1.0)
	assert_int(w.amount).is_equal(1)
	assert_float(w.duration).is_equal(0.0)
	assert_float(w.crit_chance).is_equal(0.0)
	assert_float(w.crit_mult).is_equal(1.5)
	assert_float(w.knockback).is_equal(0.0)
	assert_array(w.levels).is_empty()


func test_is_resource() -> void:
	assert_bool(WeaponDef.new() is Resource).is_true()


func test_field_assignment() -> void:
	var w := WeaponDef.new()
	w.id = "whip"
	w.name = "Whip"
	w.base_damage = 10.0
	w.cooldown = 1.35
	w.levels.append({"level": 2, "damage": 5.0})
	assert_str(w.id).is_equal("whip")
	assert_str(w.name).is_equal("Whip")
	assert_float(w.base_damage).is_equal(10.0)
	assert_float(w.cooldown).is_equal(1.35)
	assert_int(w.levels.size()).is_equal(1)
