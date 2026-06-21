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


func _synthetic_passive(id: String, level := 5) -> PassiveInstance:
	var p := PassiveInstance.new()
	var d := PassiveDef.new()
	d.id = id
	d.max_level = level  # level == max_level -> not upgradeable
	p.def = d
	p.level = level
	return p

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

func test_offer_new_items_when_nothing_owned() -> void:
	# Empty inventory -> every option is a NEW (non-upgrade) item. Seed-independent:
	# with weapons AND passives in the pool the shown subset may be any mix, so we
	# assert the invariant (nothing owned -> nothing to upgrade) rather than a
	# specific weapon appearing.
	var gs := GameState.new()
	var offer := ProgressionSystem.build_offer(gs)
	assert_int(offer.options.size()).is_greater_equal(1)
	for opt: Dictionary in offer.options:
		assert_bool(opt["is_upgrade"]).is_false()


func test_offer_upgrade_when_owned() -> void:
	var gs := GameState.new()
	gs.player.weapons = [_whip_inst(1)]
	# The owned whip must produce an upgrade option (to level 2) in the full pool.
	# (With many catalog weapons it may not land in the shown subset, so check the
	# upgradeable pool directly rather than the shuffled offer.)
	var found := false
	for opt: Dictionary in ProgressionSystem._get_upgradeable_weapons(gs.player):
		if opt["def"].id == "whip":
			assert_bool(opt["is_upgrade"]).is_true()
			assert_int(opt["target_level"]).is_equal(2)
			found = true
	assert_bool(found).is_true()
	# And it is never surfaced as a NEW pickup in a built offer.
	for opt: Dictionary in ProgressionSystem.build_offer(gs).options:
		if opt["def"].id == "whip":
			assert_bool(opt["is_upgrade"]).is_true()


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
	# Passives are now authored, so a maxed inventory must also fill (and max) the
	# passive slots for the pool to be empty.
	for i in ProgressionSystem.MAX_PASSIVES:
		gs.player.passives.append(_synthetic_passive("p%d" % i))
	var offer := ProgressionSystem.build_offer(gs)
	assert_bool(offer.is_max_state).is_true()
	assert_int(offer.options.size()).is_equal(0)


# --- apply_choice ---

func test_apply_choice_adds_new_weapon() -> void:
	var gs := GameState.new()
	gs.pending_levelups = 1
	# Controlled new-weapon option (a random build_offer subset may surface a passive
	# at index 0 now that both weapons and passives are authored).
	var offer := LevelUpOffer.new()
	offer.options = [{
		"kind": "weapon", "def": GameData.get_weapon("whip"), "is_upgrade": false,
		"target": null, "target_level": 1,
	}]
	gs.current_offer = offer
	ProgressionSystem.apply_choice(gs, 0)
	assert_int(gs.player.weapons.size()).is_equal(1)
	assert_int(gs.player.weapons[0].level).is_equal(1)
	assert_int(gs.pending_levelups).is_equal(0)


func test_apply_choice_upgrades_existing() -> void:
	var gs := GameState.new()
	var whip := _whip_inst(1)
	gs.player.weapons = [whip]
	gs.pending_levelups = 1
	# Controlled single-option offer (the shuffled build_offer may not surface the
	# whip upgrade now that the catalog has many weapons).
	var offer := LevelUpOffer.new()
	offer.options = [{
		"kind": "weapon", "def": whip.def, "is_upgrade": true,
		"target": whip, "target_level": 2,
	}]
	gs.current_offer = offer
	ProgressionSystem.apply_choice(gs, 0)
	assert_int(gs.player.weapons[0].level).is_equal(2)  # upgraded in place
	assert_int(gs.player.weapons.size()).is_equal(1)  # not duplicated


func test_apply_choice_preserves_character_base_stats() -> void:
	# Regression: recompute must NOT wipe Antonio's +1 armor / 120 HP on level-up.
	var gs := GameState.new()
	gs.player.character_def = GameData.get_character("antonio")
	var whip := _whip_inst(1)
	gs.player.weapons = [whip]
	gs.pending_levelups = 1
	# Controlled whip-upgrade option: deterministic and does not itself touch armor
	# or max_health (a random stat passive at index 0 would).
	var offer := LevelUpOffer.new()
	offer.options = [{
		"kind": "weapon", "def": whip.def, "is_upgrade": true,
		"target": whip, "target_level": 2,
	}]
	gs.current_offer = offer
	ProgressionSystem.apply_choice(gs, 0)
	assert_float(gs.player.stats.armor).is_equal(1.0)
	assert_float(gs.player.stats.max_health).is_equal(120.0)
