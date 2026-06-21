extends GdUnitTestSuite

## Tests WeaponSystem: cooldown ticking/reset and the Whip emission pattern.
## Uses the real authored whip.tres via GameData for level-scaling fidelity.

func _whip(level := 1) -> WeaponInstance:
	var w := WeaponInstance.new()
	w.def = GameData.get_weapon("whip")
	w.level = level
	return w


func _state_with_whip(level := 1) -> GameState:
	var gs := GameState.new()
	gs.player.weapons = [_whip(level)]
	return gs


# --- cooldown ---

func test_cooldown_ticks_without_firing() -> void:
	var gs := _state_with_whip()
	gs.player.weapons[0].cooldown_timer = 1.0
	WeaponSystem.step(gs, 0.3)
	assert_float(gs.player.weapons[0].cooldown_timer).is_equal_approx(0.7, 0.0001)
	assert_int(gs.zones.size()).is_equal(0)


func test_fires_and_resets_cooldown() -> void:
	var gs := _state_with_whip()  # cooldown_timer starts at 0 -> fires immediately
	WeaponSystem.step(gs, 0.1)
	assert_int(gs.zones.size()).is_equal(1)  # level 1 amount 1 -> one slash
	assert_float(gs.player.weapons[0].cooldown_timer).is_equal_approx(1.35, 0.0001)


func test_cooldown_reduction_applies() -> void:
	var gs := _state_with_whip()
	gs.player.derived.cooldown = 0.5
	WeaponSystem.step(gs, 0.1)
	assert_float(gs.player.weapons[0].cooldown_timer).is_equal_approx(0.675, 0.0001)  # 1.35 * 0.5


func test_multiple_weapons_independent() -> void:
	var gs := _state_with_whip()
	var late := _whip()
	late.cooldown_timer = 5.0  # not ready
	gs.player.weapons.append(late)
	WeaponSystem.step(gs, 0.1)
	# Only the ready weapon fired.
	assert_int(gs.zones.size()).is_equal(1)
	assert_float(late.cooldown_timer).is_equal_approx(4.9, 0.0001)


# --- whip pattern ---

func test_whip_zone_fields() -> void:
	var gs := _state_with_whip()
	gs.player.facing = Vector2.RIGHT
	WeaponSystem.cast(gs, gs.player.weapons[0])
	var z = gs.zones[0]
	assert_int(z.anchor).is_equal(DamageZone.Anchor.FOLLOW_PLAYER)
	assert_float(z.damage).is_equal(10.0)  # base, no Might
	assert_float(z.radius).is_equal(60.0)  # 60 * area 1.0
	assert_vector(z.offset).is_equal(Vector2(40, 0))  # facing * reach
	assert_object(z.source_weapon).is_same(gs.player.weapons[0])


func test_whip_damage_scales_with_level() -> void:
	# Level 3 whip: base 10 + L3 (+5) = 15; amount 1 + L2 (+1) = 2.
	var gs := _state_with_whip(3)
	WeaponSystem.cast(gs, gs.player.weapons[0])
	assert_int(gs.zones.size()).is_equal(2)  # amount 2
	assert_float(gs.zones[0].damage).is_equal(15.0)


func test_whip_amount_alternates_sides() -> void:
	var gs := _state_with_whip(2)  # amount 2
	gs.player.facing = Vector2.RIGHT
	WeaponSystem.cast(gs, gs.player.weapons[0])
	# Slash 0 forward, slash 1 backward.
	assert_vector(gs.zones[0].offset).is_equal(Vector2(40, 0))
	assert_vector(gs.zones[1].offset).is_equal(Vector2(-40, 0))


func test_whip_side_flips_across_casts() -> void:
	var gs := _state_with_whip(2)
	gs.player.facing = Vector2.RIGHT
	WeaponSystem.cast(gs, gs.player.weapons[0])
	gs.zones.clear()
	WeaponSystem.cast(gs, gs.player.weapons[0])  # starting side now flipped
	assert_vector(gs.zones[0].offset).is_equal(Vector2(-40, 0))


func test_whip_area_scales_radius() -> void:
	var gs := _state_with_whip()
	gs.player.derived.area = 2.0
	WeaponSystem.cast(gs, gs.player.weapons[0])
	assert_float(gs.zones[0].radius).is_equal(120.0)  # 60 * 2.0


func test_whip_amount_from_derived() -> void:
	var gs := _state_with_whip()  # level 1 amount 1
	gs.player.derived.amount = 1  # +1 -> 2 slashes
	WeaponSystem.cast(gs, gs.player.weapons[0])
	assert_int(gs.zones.size()).is_equal(2)


func test_whip_follows_facing_direction() -> void:
	var gs := _state_with_whip()
	gs.player.facing = Vector2.UP
	WeaponSystem.cast(gs, gs.player.weapons[0])
	assert_vector(gs.zones[0].offset).is_equal(Vector2(0, -40))


func test_unknown_weapon_does_not_crash() -> void:
	var gs := GameState.new()
	var w := WeaponInstance.new()
	var d := WeaponDef.new()
	d.id = "not_implemented_yet"
	d.cooldown = 1.0
	w.def = d
	gs.player.weapons = [w]
	WeaponSystem.step(gs, 0.1)
	assert_int(gs.zones.size()).is_equal(0)  # no pattern, no crash


func test_null_def_skipped() -> void:
	var gs := GameState.new()
	var w := WeaponInstance.new()
	w.def = null
	gs.player.weapons = [w]
	WeaponSystem.step(gs, 0.1)  # must not crash
	assert_int(gs.zones.size()).is_equal(0)
