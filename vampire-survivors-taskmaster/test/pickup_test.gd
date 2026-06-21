extends GdUnitTestSuite

## Verifies Pickup construction, defaults, enum, and field access.

func test_defaults() -> void:
	var p := Pickup.new()
	assert_vector(p.pos).is_equal(Vector2.ZERO)
	assert_int(p.type).is_equal(Pickup.Type.COIN)
	assert_float(p.value).is_equal(0.0)


func test_type_enum_has_expected_members() -> void:
	assert_int(Pickup.Type.CHICKEN).is_equal(0)
	assert_int(Pickup.Type.COIN).is_equal(1)
	assert_int(Pickup.Type.CLOVER).is_equal(8)


func test_is_ref_counted() -> void:
	assert_bool(Pickup.new() is RefCounted).is_true()


func test_mutability() -> void:
	var p := Pickup.new()
	p.type = Pickup.Type.CHICKEN
	p.value = 30.0
	p.pos = Vector2(1, 2)
	assert_int(p.type).is_equal(Pickup.Type.CHICKEN)
	assert_float(p.value).is_equal(30.0)
	assert_vector(p.pos).is_equal(Vector2(1, 2))
