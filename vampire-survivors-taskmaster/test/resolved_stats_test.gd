extends GdUnitTestSuite

## Verifies ResolvedStats default values and mutability.

func test_defaults() -> void:
	var s := ResolvedStats.new()
	assert_float(s.might).is_equal(1.0)
	assert_float(s.area).is_equal(1.0)
	assert_float(s.cooldown).is_equal(1.0)
	assert_int(s.amount).is_equal(0)
	assert_float(s.duration).is_equal(1.0)
	assert_float(s.speed).is_equal(1.0)
	assert_float(s.move_speed).is_equal(1.0)
	assert_float(s.max_health).is_equal(100.0)
	assert_float(s.recovery).is_equal(0.0)
	assert_float(s.armor).is_equal(0.0)
	assert_float(s.magnet).is_equal(64.0)
	assert_float(s.luck).is_equal(1.0)
	assert_float(s.growth).is_equal(1.0)
	assert_float(s.greed).is_equal(1.0)
	assert_float(s.curse).is_equal(1.0)
	assert_int(s.revival).is_equal(0)


func test_is_ref_counted() -> void:
	assert_bool(ResolvedStats.new() is RefCounted).is_true()


func test_mutability() -> void:
	var s := ResolvedStats.new()
	s.cooldown = 0.6
	s.armor = 5.0
	s.amount = 2
	assert_float(s.cooldown).is_equal(0.6)
	assert_float(s.armor).is_equal(5.0)
	assert_int(s.amount).is_equal(2)
