extends GdUnitTestSuite

## Verifies Chest construction, defaults, and field access.

func test_defaults() -> void:
	var c := Chest.new()
	assert_vector(c.pos).is_equal(Vector2.ZERO)
	assert_int(c.rolled_count).is_equal(0)


func test_is_ref_counted() -> void:
	assert_bool(Chest.new() is RefCounted).is_true()


func test_mutability() -> void:
	var c := Chest.new()
	c.pos = Vector2(9, 9)
	c.rolled_count = 5
	assert_vector(c.pos).is_equal(Vector2(9, 9))
	assert_int(c.rolled_count).is_equal(5)
