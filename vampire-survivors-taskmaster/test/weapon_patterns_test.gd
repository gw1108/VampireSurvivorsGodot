extends GdUnitTestSuite

## Tests the task-28 weapon patterns (Magic Wand, Knife, Axe, Cross, King Bible,
## Fire Wand, Garlic, Santa Water) via WeaponSystem.cast against the real authored
## .tres defs, plus the three CombatSystem behaviours they rely on: projectile
## acceleration (Axe arc), boomerang return (Cross), and ORBIT zone rotation
## (King Bible).

func _state_with(weapon_id: String, level := 1) -> GameState:
	var gs := GameState.new()
	gs.index = SpatialIndex.new()
	SpatialIndex.rebuild(gs.index, gs.enemies, gs.gems, gs.pickups)
	var w := WeaponInstance.new()
	w.def = GameData.get_weapon(weapon_id)
	w.level = level
	gs.player.weapons = [w]
	return gs


func _add_enemy(gs: GameState, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.hp = 1000.0
	var d := EnemyDef.new()
	d.id = "bat"
	d.xp_value = 1.0
	e.def = d
	e.pos = pos
	gs.enemies.append(e)
	SpatialIndex.rebuild(gs.index, gs.enemies, gs.gems, gs.pickups)
	return e


func _cast(gs: GameState) -> void:
	WeaponSystem.cast(gs, gs.player.weapons[0])


# --- Magic Wand: projectile toward nearest enemy ---

func test_magic_wand_fires_at_nearest_enemy() -> void:
	var gs := _state_with("magic_wand")
	_add_enemy(gs, Vector2(100, 0))
	_cast(gs)
	assert_int(gs.projectiles.size()).is_equal(1)
	var p = gs.projectiles[0]
	assert_float(p.velocity.x).is_greater(0.0)            # aimed at the enemy to the right
	assert_float(absf(p.velocity.y)).is_less(1.0)
	assert_float(p.damage).is_equal(10.0)                 # base, no Might
	assert_object(p.source_weapon).is_same(gs.player.weapons[0])


# --- Knife: facing direction, high speed ---

func test_knife_fires_in_facing_direction() -> void:
	var gs := _state_with("knife")
	gs.player.facing = Vector2.RIGHT
	_cast(gs)
	assert_int(gs.projectiles.size()).is_equal(1)
	var p = gs.projectiles[0]
	assert_float(p.velocity.x).is_equal_approx(380.0, 0.5)  # projectile_speed in facing dir
	assert_float(p.velocity.y).is_equal_approx(0.0, 0.001)


# --- Axe: upward launch + gravity arc ---

func test_axe_launches_up_with_gravity() -> void:
	var gs := _state_with("axe")
	gs.player.facing = Vector2.RIGHT
	_cast(gs)
	var p = gs.projectiles[0]
	assert_float(p.velocity.y).is_less(0.0)   # launched upward (negative y)
	assert_float(p.accel.y).is_greater(0.0)   # gravity pulls it back down
	assert_float(p.velocity.x).is_greater(0.0)  # drifts toward facing


# --- Cross: boomerang ---

func test_cross_is_boomerang() -> void:
	var gs := _state_with("cross")
	_add_enemy(gs, Vector2(100, 0))
	_cast(gs)
	var p = gs.projectiles[0]
	assert_bool(p.is_boomerang).is_true()
	assert_float(p.boomerang_range).is_greater(0.0)
	assert_float(p.velocity.x).is_greater(0.0)


# --- King Bible: orbiting zones ---

func test_king_bible_spawns_orbiters() -> void:
	var gs := _state_with("king_bible")
	_cast(gs)
	assert_int(gs.zones.size()).is_equal(1)  # level 1 amount 1
	var z = gs.zones[0]
	assert_int(z.anchor).is_equal(DamageZone.Anchor.ORBIT)
	assert_float(z.orbit_speed).is_greater(0.0)
	assert_float(z.tick_interval).is_greater(0.0)


func test_king_bible_amount_scales_orbiters() -> void:
	var gs := _state_with("king_bible", 2)  # L2: amount +1 -> 2 orbiters
	_cast(gs)
	assert_int(gs.zones.size()).is_equal(2)


# --- Fire Wand: explosion on a random enemy ---

func test_fire_wand_explodes_on_enemy() -> void:
	var gs := _state_with("fire_wand")
	_add_enemy(gs, Vector2(100, 0))
	_cast(gs)
	assert_int(gs.zones.size()).is_equal(1)
	var z = gs.zones[0]
	assert_int(z.anchor).is_equal(DamageZone.Anchor.WORLD)
	assert_vector(z.pos).is_equal(Vector2(100, 0))  # only enemy -> explosion lands on it
	assert_float(z.lifetime).is_less(1.0)            # brief


# --- Garlic: persistent follow-player aura ---

func test_garlic_is_follow_aura() -> void:
	var gs := _state_with("garlic")
	_cast(gs)
	assert_int(gs.zones.size()).is_equal(1)
	var z = gs.zones[0]
	assert_int(z.anchor).is_equal(DamageZone.Anchor.FOLLOW_PLAYER)
	assert_vector(z.offset).is_equal(Vector2.ZERO)
	assert_float(z.tick_interval).is_greater(0.0)
	assert_float(z.radius).is_greater(0.0)


# --- Santa Water: persistent world puddles ---

func test_santa_water_drops_puddles() -> void:
	var gs := _state_with("santa_water")
	_cast(gs)
	assert_int(gs.zones.size()).is_equal(1)
	var z = gs.zones[0]
	assert_int(z.anchor).is_equal(DamageZone.Anchor.WORLD)
	assert_float(z.tick_interval).is_greater(0.0)
	assert_float(z.lifetime).is_greater(1.0)


# --- global Amount stat adds emissions ---

func test_derived_amount_adds_projectiles() -> void:
	var gs := _state_with("knife")
	gs.player.derived.amount = 2  # +2 -> 3 knives
	_cast(gs)
	assert_int(gs.projectiles.size()).is_equal(3)


# --- CombatSystem support behaviours ---

func _empty_indexed_state() -> GameState:
	var gs := GameState.new()
	gs.index = SpatialIndex.new()
	SpatialIndex.rebuild(gs.index, [], [], [])
	return gs


func test_combat_integrates_projectile_accel() -> void:
	var gs := _empty_indexed_state()
	var p := Projectile.new()
	p.velocity = Vector2(0, -100)
	p.accel = Vector2(0, 200)
	p.lifetime = 5.0
	gs.projectiles.append(p)
	CombatSystem.step(gs, 0.1)
	assert_float(p.velocity.y).is_equal_approx(-80.0, 0.001)  # -100 + 200*0.1


func test_combat_boomerang_turns_back() -> void:
	var gs := _empty_indexed_state()
	gs.player.pos = Vector2.ZERO
	var p := Projectile.new()
	p.pos = Vector2(50, 0)
	p.velocity = Vector2(300, 0)  # moving away from the player
	p.is_boomerang = true
	p.boomerang_range = 40.0      # already beyond range -> must start returning
	p.pierce_left = 99
	p.lifetime = 5.0
	gs.projectiles.append(p)
	CombatSystem.step(gs, 0.01)
	assert_bool(p.is_returning).is_true()
	assert_float(p.velocity.x).is_less(0.0)  # now homing back toward the player


func test_combat_orbit_rotates_zone() -> void:
	var gs := _empty_indexed_state()
	gs.player.pos = Vector2.ZERO
	var z := DamageZone.new()
	z.anchor = DamageZone.Anchor.ORBIT
	z.offset = Vector2(70, 0)
	z.orbit_speed = 3.0
	z.radius = 20.0
	z.lifetime = 5.0
	z.tick_interval = 1.0
	z.tick_timer = 1.0
	gs.zones.append(z)
	CombatSystem.step(gs, 0.1)
	assert_float(z.offset.angle()).is_equal_approx(0.3, 0.001)  # 3.0 rad/s * 0.1s
	assert_float(z.offset.length()).is_equal_approx(70.0, 0.001)  # radius preserved
	assert_vector(z.pos).is_equal(z.offset)  # player at origin -> pos == offset
