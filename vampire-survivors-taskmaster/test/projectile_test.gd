extends GdUnitTestSuite

## Verifies Projectile construction, defaults, and field access.

func test_defaults() -> void:
	var p := Projectile.new()
	assert_object(p.source_weapon).is_null()
	assert_vector(p.pos).is_equal(Vector2.ZERO)
	assert_vector(p.velocity).is_equal(Vector2.ZERO)
	assert_float(p.damage).is_equal(0.0)
	assert_float(p.crit_mult).is_equal(1.0)
	assert_float(p.crit_chance).is_equal(0.0)
	assert_int(p.pierce_left).is_equal(1)
	assert_float(p.lifetime).is_equal(2.0)
	assert_int(p.bounces_left).is_equal(0)
	assert_array(p.hit_ids).is_empty()
	assert_bool(p.is_boomerang).is_false()
	assert_bool(p.is_returning).is_false()


func test_is_ref_counted() -> void:
	assert_bool(Projectile.new() is RefCounted).is_true()


func test_mutability() -> void:
	var p := Projectile.new()
	p.damage = 12.0
	p.pierce_left = 3
	p.velocity = Vector2(100, 0)
	p.hit_ids.append(7)
	assert_float(p.damage).is_equal(12.0)
	assert_int(p.pierce_left).is_equal(3)
	assert_vector(p.velocity).is_equal(Vector2(100, 0))
	assert_int(p.hit_ids.size()).is_equal(1)


func test_hit_ids_is_packed_int64() -> void:
	var p := Projectile.new()
	assert_bool(p.hit_ids is PackedInt64Array).is_true()
