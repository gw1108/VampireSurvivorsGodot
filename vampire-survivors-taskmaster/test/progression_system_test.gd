extends GdUnitTestSuite

## Tests ProgressionSystem: add_xp threshold crossing, offer generation, choice
## application, and inventory limits.

func _whip_inst(level := 1) -> WeaponInstance:
	var w := WeaponInstance.new()
	w.def = GameData.get_weapon("whip")
	w.level = level
	return w


func _synthetic_weapon(id: String, level := 1) -> WeaponInstance:
	var w := WeaponInstance.new()
	var d := WeaponDef.new()
	d.id = id
	w.def = d
	w.level = level
	return w

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


# --- build_offer ---

func test_offer_new_weapon_when_not_owned() -> void:
	var gs := GameState.new()  # empty inventory; catalog has whip
	var offer := ProgressionSystem.build_offer(gs)
	assert_int(offer.options.size()).is_greater_equal(1)
	var whip_new := false
	for opt: Dictionary in offer.options:
		if opt["kind"] == "weapon" and opt["def"].id == "whip" and not opt["is_upgrade"]:
			whip_new = true
	assert_bool(whip_new).is_true()


func test_offer_upgrade_when_owned() -> void:
	var gs := GameState.new()
	gs.player.weapons = [_whip_inst(1)]
	var offer := ProgressionSystem.build_offer(gs)
	# Whip is owned -> offered as an upgrade (to level 2), not as a new item.
	var found := false
	for opt: Dictionary in offer.options:
		if opt["def"].id == "whip":
			assert_bool(opt["is_upgrade"]).is_true()
			assert_int(opt["target_level"]).is_equal(2)
			found = true
	assert_bool(found).is_true()


func test_maxed_weapon_not_offered_as_upgrade() -> void:
	var gs := GameState.new()
	gs.player.weapons = [_whip_inst(ProgressionSystem.WEAPON_MAX_LEVEL)]  # level 8
	var offer := ProgressionSystem.build_offer(gs)
	for opt: Dictionary in offer.options:
		# The maxed whip must not appear (no upgrade, and owned so not "new").
		assert_bool(opt["def"].id != "whip").is_true()


func test_offer_default_three_options_at_luck_one() -> void:
	# Six synthetic upgradeable weapons -> pool of 6; luck 1 -> exactly 3 shown.
	var gs := GameState.new()
	for i in 6:
		gs.player.weapons.append(_synthetic_weapon("w%d" % i))
	var offer := ProgressionSystem.build_offer(gs)
	assert_int(offer.options.size()).is_equal(3)


func test_offer_is_deterministic_per_seed() -> void:
	var ids_a := _offer_ids(111)
	var ids_b := _offer_ids(111)
	assert_array(ids_a).is_equal(ids_b)  # same seed -> same shuffle/order


func _offer_ids(seed_val: int) -> Array:
	var gs := GameState.new()
	gs.rng.seed = seed_val
	for i in 6:
		gs.player.weapons.append(_synthetic_weapon("w%d" % i))
	var offer := ProgressionSystem.build_offer(gs)
	var ids: Array = []
	for opt: Dictionary in offer.options:
		ids.append(opt["def"].id)
	return ids


func test_full_maxed_inventory_is_max_state() -> void:
	var gs := GameState.new()
	for i in ProgressionSystem.MAX_WEAPONS:
		gs.player.weapons.append(_synthetic_weapon("w%d" % i, ProgressionSystem.WEAPON_MAX_LEVEL))
	# 6 maxed weapons, no passives authored -> nothing to offer.
	var offer := ProgressionSystem.build_offer(gs)
	assert_bool(offer.is_max_state).is_true()
	assert_int(offer.options.size()).is_equal(0)


# --- apply_choice ---

func test_apply_choice_adds_new_weapon() -> void:
	var gs := GameState.new()
	gs.pending_levelups = 1
	gs.current_offer = ProgressionSystem.build_offer(gs)  # whip as new
	ProgressionSystem.apply_choice(gs, 0)
	assert_int(gs.player.weapons.size()).is_equal(1)
	assert_int(gs.player.weapons[0].level).is_equal(1)
	assert_int(gs.pending_levelups).is_equal(0)


func test_apply_choice_upgrades_existing() -> void:
	var gs := GameState.new()
	gs.player.weapons = [_whip_inst(1)]
	gs.pending_levelups = 1
	gs.current_offer = ProgressionSystem.build_offer(gs)
	ProgressionSystem.apply_choice(gs, 0)
	assert_int(gs.player.weapons[0].level).is_equal(2)  # upgraded in place
	assert_int(gs.player.weapons.size()).is_equal(1)  # not duplicated


func test_apply_choice_preserves_character_base_stats() -> void:
	# Regression: recompute must NOT wipe Antonio's +1 armor / 120 HP on level-up.
	var gs := GameState.new()
	gs.player.character_def = GameData.get_character("antonio")
	gs.player.weapons = [_whip_inst(1)]
	gs.pending_levelups = 1
	gs.current_offer = ProgressionSystem.build_offer(gs)
	ProgressionSystem.apply_choice(gs, 0)
	assert_float(gs.player.stats.armor).is_equal(1.0)
	assert_float(gs.player.stats.max_health).is_equal(120.0)
