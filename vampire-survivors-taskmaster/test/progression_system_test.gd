extends GdUnitTestSuite

## Tests ProgressionSystem.add_xp (XP accumulation + level-up threshold crossing).
## (build_offer/apply_choice/open_chest are added in task 14.)

func test_add_xp_below_threshold() -> void:
	var gs := GameState.new()
	ProgressionSystem.add_xp(gs, 3.0)
	assert_float(gs.player.xp).is_equal(3.0)
	assert_int(gs.player.level).is_equal(1)
	assert_int(gs.pending_levelups).is_equal(0)


func test_add_xp_single_level_up() -> void:
	var gs := GameState.new()  # level 1, xp_to_next 5
	ProgressionSystem.add_xp(gs, 5.0)
	assert_int(gs.player.level).is_equal(2)
	assert_float(gs.player.xp).is_equal(0.0)
	assert_int(gs.pending_levelups).is_equal(1)
	assert_float(gs.player.xp_to_next).is_equal(15.0)  # cost 2->3


func test_add_xp_carryover() -> void:
	var gs := GameState.new()
	ProgressionSystem.add_xp(gs, 20.0)  # 5 (->L2) + 15 (->L3) = 20 exactly
	assert_int(gs.player.level).is_equal(3)
	assert_float(gs.player.xp).is_equal(0.0)
	assert_int(gs.pending_levelups).is_equal(2)


func test_add_xp_multi_level_to_six() -> void:
	# Cumulative XP to reach level 6 is 125 (wiki curve).
	var gs := GameState.new()
	ProgressionSystem.add_xp(gs, 125.0)
	assert_int(gs.player.level).is_equal(6)
	assert_float(gs.player.xp).is_equal(0.0)
	assert_int(gs.pending_levelups).is_equal(5)


func test_add_xp_to_level_20_uses_baked_special() -> void:
	# Cumulative to L20 = 1805. Threshold 20->21 must be 795 (195 + 600 baked in),
	# and NO extra bonus XP is granted.
	var gs := GameState.new()
	ProgressionSystem.add_xp(gs, 1805.0)
	assert_int(gs.player.level).is_equal(20)
	assert_float(gs.player.xp).is_equal(0.0)
	assert_float(gs.player.xp_to_next).is_equal(795.0)
	assert_int(gs.pending_levelups).is_equal(19)
