extends GdUnitTestSuite

## Verifies PickupTable weights and the seeded weighted roll.

func test_total_weight_matches_sum() -> void:
	var sum: int = 0
	for w: int in PickupTable.WEIGHTS.values():
		sum += w
	assert_int(PickupTable.total_weight()).is_equal(sum)
	assert_int(PickupTable.total_weight()).is_greater(0)


func test_roll_returns_valid_type() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 50:
		var t: int = PickupTable.roll(rng)
		assert_bool(PickupTable.WEIGHTS.has(t)).is_true()


func test_roll_is_deterministic_per_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 777
	b.seed = 777
	for i in 20:
		assert_int(PickupTable.roll(a)).is_equal(PickupTable.roll(b))
