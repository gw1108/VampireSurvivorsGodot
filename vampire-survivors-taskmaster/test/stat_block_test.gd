extends GdUnitTestSuite

## Verifies StatBlock default values and mutability.

func test_defaults() -> void:
	var s := StatBlock.new()
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
	assert_bool(StatBlock.new() is RefCounted).is_true()


func test_mutability() -> void:
	var s := StatBlock.new()
	s.might = 2.5
	s.amount = 3
	s.magnet = 128.0
	s.revival = 1
	assert_float(s.might).is_equal(2.5)
	assert_int(s.amount).is_equal(3)
	assert_float(s.magnet).is_equal(128.0)
	assert_int(s.revival).is_equal(1)


func test_instances_are_independent() -> void:
	var a := StatBlock.new()
	var b := StatBlock.new()
	a.might = 9.0
	assert_float(b.might).is_equal(1.0)
