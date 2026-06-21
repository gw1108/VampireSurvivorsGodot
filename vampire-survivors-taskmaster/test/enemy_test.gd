extends GdUnitTestSuite

## Verifies Enemy construction, defaults, and field access.

func test_defaults() -> void:
	var e := Enemy.new()
	assert_object(e.def).is_null()
	assert_vector(e.pos).is_equal(Vector2.ZERO)
	assert_vector(e.velocity).is_equal(Vector2.ZERO)
	assert_float(e.hp).is_equal(1.0)
	assert_vector(e.knockback).is_equal(Vector2.ZERO)
	assert_float(e.knockback_timer).is_equal(0.0)
	assert_float(e.freeze_timer).is_equal(0.0)
	assert_bool(e.is_boss).is_false()
	assert_bool(e.fixed_direction).is_false()
	assert_bool(e.floaty).is_false()
	assert_dict(e.hit_cooldowns).is_empty()


func test_is_ref_counted() -> void:
	assert_bool(Enemy.new() is RefCounted).is_true()


func test_mutability() -> void:
	var e := Enemy.new()
	e.pos = Vector2(5, 6)
	e.hp = 250.0
	e.is_boss = true
	e.hit_cooldowns[42] = 0.2
	assert_vector(e.pos).is_equal(Vector2(5, 6))
	assert_float(e.hp).is_equal(250.0)
	assert_bool(e.is_boss).is_true()
	assert_float(e.hit_cooldowns[42]).is_equal(0.2)


func test_collections_are_per_instance() -> void:
	var a := Enemy.new()
	var b := Enemy.new()
	a.hit_cooldowns[1] = 1.0
	assert_dict(b.hit_cooldowns).is_empty()
