extends GdUnitTestSuite

## Verifies DamageZone construction, defaults, enum, and field access.

func test_defaults() -> void:
	var z := DamageZone.new()
	assert_object(z.source_weapon).is_null()
	assert_int(z.anchor).is_equal(DamageZone.Anchor.WORLD)
	assert_vector(z.pos).is_equal(Vector2.ZERO)
	assert_vector(z.offset).is_equal(Vector2.ZERO)
	assert_float(z.angle).is_equal(0.0)
	assert_float(z.radius).is_equal(32.0)
	assert_float(z.damage).is_equal(0.0)
	assert_float(z.tick_interval).is_equal(0.5)
	assert_float(z.tick_timer).is_equal(0.0)
	assert_float(z.lifetime).is_equal(1.0)
	assert_array(z.hit_ids).is_empty()


func test_anchor_enum_values() -> void:
	assert_int(DamageZone.Anchor.FOLLOW_PLAYER).is_equal(0)
	assert_int(DamageZone.Anchor.WORLD).is_equal(1)
	assert_int(DamageZone.Anchor.ORBIT).is_equal(2)


func test_is_ref_counted() -> void:
	assert_bool(DamageZone.new() is RefCounted).is_true()


func test_mutability() -> void:
	var z := DamageZone.new()
	z.anchor = DamageZone.Anchor.ORBIT
	z.radius = 80.0
	z.damage = 5.0
	assert_int(z.anchor).is_equal(DamageZone.Anchor.ORBIT)
	assert_float(z.radius).is_equal(80.0)
	assert_float(z.damage).is_equal(5.0)
