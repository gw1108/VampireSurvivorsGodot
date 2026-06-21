extends GdUnitTestSuite

## Verifies WeaponInstance construction, defaults, and field access.

func test_defaults() -> void:
	var w := WeaponInstance.new()
	assert_object(w.def).is_null()
	assert_int(w.level).is_equal(1)
	assert_float(w.cooldown_timer).is_equal(0.0)
	assert_dict(w.scratch).is_empty()


func test_is_ref_counted() -> void:
	assert_bool(WeaponInstance.new() is RefCounted).is_true()


func test_mutability() -> void:
	var w := WeaponInstance.new()
	w.level = 8
	w.cooldown_timer = 0.75
	w.scratch["side"] = -1
	assert_int(w.level).is_equal(8)
	assert_float(w.cooldown_timer).is_equal(0.75)
	assert_int(w.scratch["side"]).is_equal(-1)


func test_scratch_is_per_instance() -> void:
	var a := WeaponInstance.new()
	var b := WeaponInstance.new()
	a.scratch["x"] = 1
	assert_dict(b.scratch).is_empty()
