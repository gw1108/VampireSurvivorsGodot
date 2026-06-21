extends GdUnitTestSuite

## Verifies LevelCurve XP thresholds against the wiki-documented curve.

func test_xp_to_next_early_levels() -> void:
	# 5 to reach L2, then +10 each level.
	assert_float(LevelCurve.xp_to_next(1)).is_equal(5.0)
	assert_float(LevelCurve.xp_to_next(2)).is_equal(15.0)
	assert_float(LevelCurve.xp_to_next(3)).is_equal(25.0)
	assert_float(LevelCurve.xp_to_next(19)).is_equal(185.0)


func test_level_20_special() -> void:
	# 195 base + 600 special.
	assert_float(LevelCurve.xp_to_next(20)).is_equal(795.0)


func test_cumulative_totals() -> void:
	assert_float(LevelCurve.total_xp_for_level(1)).is_equal(0.0)
	assert_float(LevelCurve.total_xp_for_level(20)).is_equal(1805.0)
	assert_float(LevelCurve.total_xp_for_level(40)).is_equal(9886.5)
	assert_float(LevelCurve.total_xp_for_level(60)).is_equal(27848.0)


func test_default_player_matches_curve() -> void:
	# PlayerState defaults xp_to_next to 5.0 at level 1.
	assert_float(LevelCurve.xp_to_next(1)).is_equal(PlayerState.new().xp_to_next)


func test_beyond_table_extends_by_16() -> void:
	# Increment at L59->60 is 936; each level past extends by +16.
	assert_float(LevelCurve.xp_to_next(59)).is_equal(936.0)
	assert_float(LevelCurve.xp_to_next(60)).is_equal(952.0)
	assert_float(LevelCurve.xp_to_next(61)).is_equal(968.0)


func test_clamps_invalid_level() -> void:
	assert_float(LevelCurve.total_xp_for_level(0)).is_equal(0.0)
	assert_float(LevelCurve.total_xp_for_level(-5)).is_equal(0.0)
