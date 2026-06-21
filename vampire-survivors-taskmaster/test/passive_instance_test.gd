extends GdUnitTestSuite

## Verifies PassiveInstance construction, defaults, and field access.

func test_defaults() -> void:
	var p := PassiveInstance.new()
	assert_object(p.def).is_null()
	assert_int(p.level).is_equal(1)
	assert_int(p.stacks).is_equal(1)


func test_is_ref_counted() -> void:
	assert_bool(PassiveInstance.new() is RefCounted).is_true()


func test_mutability() -> void:
	var p := PassiveInstance.new()
	p.level = 5
	p.stacks = 5
	assert_int(p.level).is_equal(5)
	assert_int(p.stacks).is_equal(5)
