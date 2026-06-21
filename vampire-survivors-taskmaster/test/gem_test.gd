extends GdUnitTestSuite

## Verifies Gem construction, defaults, enum, and field access.

func test_defaults() -> void:
	var g := Gem.new()
	assert_vector(g.pos).is_equal(Vector2.ZERO)
	assert_float(g.xp).is_equal(1.0)
	assert_int(g.tier).is_equal(Gem.Tier.BLUE)


func test_tier_enum_values() -> void:
	assert_int(Gem.Tier.BLUE).is_equal(0)
	assert_int(Gem.Tier.GREEN).is_equal(1)
	assert_int(Gem.Tier.RED).is_equal(2)


func test_is_ref_counted() -> void:
	assert_bool(Gem.new() is RefCounted).is_true()


func test_mutability() -> void:
	var g := Gem.new()
	g.pos = Vector2(3, 4)
	g.xp = 50.0
	g.tier = Gem.Tier.RED
	assert_vector(g.pos).is_equal(Vector2(3, 4))
	assert_float(g.xp).is_equal(50.0)
	assert_int(g.tier).is_equal(Gem.Tier.RED)
