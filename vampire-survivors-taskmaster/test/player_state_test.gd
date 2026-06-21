extends GdUnitTestSuite

## Verifies PlayerState default values, composed objects, and mutability.

func test_defaults() -> void:
	var p := PlayerState.new()
	assert_vector(p.pos).is_equal(Vector2.ZERO)
	assert_vector(p.facing).is_equal(Vector2.RIGHT)
	assert_vector(p.velocity).is_equal(Vector2.ZERO)
	assert_float(p.hp).is_equal(100.0)
	assert_int(p.level).is_equal(1)
	assert_float(p.xp).is_equal(0.0)
	assert_float(p.xp_to_next).is_equal(5.0)
	assert_float(p.iframe_timer).is_equal(0.0)
	assert_int(p.revivals).is_equal(0)
	assert_array(p.weapons).is_empty()
	assert_array(p.passives).is_empty()


func test_is_ref_counted() -> void:
	assert_bool(PlayerState.new() is RefCounted).is_true()


func test_owns_stat_objects() -> void:
	var p := PlayerState.new()
	assert_object(p.stats).is_not_null()
	assert_object(p.derived).is_not_null()
	assert_bool(p.stats is StatBlock).is_true()
	assert_bool(p.derived is ResolvedStats).is_true()


func test_mutability() -> void:
	var p := PlayerState.new()
	p.pos = Vector2(10, 20)
	p.facing = Vector2.LEFT
	p.hp = 42.0
	p.level = 5
	p.weapons.append("whip")
	assert_vector(p.pos).is_equal(Vector2(10, 20))
	assert_vector(p.facing).is_equal(Vector2.LEFT)
	assert_float(p.hp).is_equal(42.0)
	assert_int(p.level).is_equal(5)
	assert_int(p.weapons.size()).is_equal(1)


func test_default_stat_blocks_are_per_instance() -> void:
	var a := PlayerState.new()
	var b := PlayerState.new()
	a.stats.might = 7.0
	assert_float(b.stats.might).is_equal(1.0)
