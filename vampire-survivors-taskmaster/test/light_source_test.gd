extends GdUnitTestSuite

## Verifies LightSource construction, defaults, and field access.

func test_defaults() -> void:
	var l := LightSource.new()
	assert_vector(l.pos).is_equal(Vector2.ZERO)
	assert_float(l.hp).is_equal(10.0)


func test_is_ref_counted() -> void:
	assert_bool(LightSource.new() is RefCounted).is_true()


func test_mutability() -> void:
	var l := LightSource.new()
	l.pos = Vector2(7, 8)
	l.hp = 3.0
	assert_vector(l.pos).is_equal(Vector2(7, 8))
	assert_float(l.hp).is_equal(3.0)
