extends GdUnitTestSuite

## Tests the light source / brazier system (task 31): SpawnDirector spawns braziers
## on the stage's brazier_interval (ring-positioned), CombatSystem damages them via
## overlapping zones/projectiles, and a broken brazier drops a weighted pickup with
## a sensible default value. PickupTable.default_value mapping is checked too.

func _state() -> GameState:
	var gs := GameState.new()
	gs.rng.seed = 1
	return gs


func _light(pos: Vector2, hp := 10.0) -> LightSource:
	var l := LightSource.new()
	l.pos = pos
	l.hp = hp
	return l


func _zone(pos: Vector2, radius: float, damage: float) -> DamageZone:
	var z := DamageZone.new()
	z.anchor = DamageZone.Anchor.WORLD
	z.pos = pos
	z.radius = radius
	z.damage = damage
	z.lifetime = 1.0
	return z


func _projectile(pos: Vector2, damage: float) -> Projectile:
	var p := Projectile.new()
	p.pos = pos
	p.velocity = Vector2.ZERO
	p.damage = damage
	p.lifetime = 2.0
	p.pierce_left = 1
	return p


func _brazier_stage(interval: float) -> StageDef:
	var s := StageDef.new()
	s.brazier_interval = interval
	s.reaper_minute = 30
	s.waves = []  # no waves -> step returns right after the brazier check
	return s


# --- CombatSystem: damaging & breaking light sources ---

func test_zone_damages_light_source() -> void:
	var gs := _state()
	gs.light_sources = [_light(Vector2.ZERO, 10.0)]
	gs.zones = [_zone(Vector2.ZERO, 50.0, 4.0)]
	CombatSystem.step(gs, 0.016)
	assert_int(gs.light_sources.size()).is_equal(1)  # survived (hp 6)
	assert_float(gs.light_sources[0].hp).is_equal(6.0)


func test_projectile_damages_light_source() -> void:
	var gs := _state()
	gs.light_sources = [_light(Vector2.ZERO, 10.0)]
	gs.projectiles = [_projectile(Vector2(8, 0), 5.0)]  # within PROJECTILE_HIT_RADIUS 16
	CombatSystem.step(gs, 0.016)
	assert_float(gs.light_sources[0].hp).is_equal(5.0)


func test_light_breaks_and_drops_pickup() -> void:
	var gs := _state()
	gs.light_sources = [_light(Vector2(5, 5), 3.0)]
	gs.zones = [_zone(Vector2(5, 5), 50.0, 10.0)]
	CombatSystem.step(gs, 0.016)
	assert_int(gs.light_sources.size()).is_equal(0)   # broken + removed
	assert_int(gs.pickups.size()).is_equal(1)
	assert_vector(gs.pickups[0].pos).is_equal(Vector2(5, 5))  # drops where it broke


func test_light_outside_range_untouched() -> void:
	var gs := _state()
	gs.light_sources = [_light(Vector2(1000, 0), 10.0)]
	gs.zones = [_zone(Vector2.ZERO, 50.0, 10.0)]
	CombatSystem.step(gs, 0.016)
	assert_float(gs.light_sources[0].hp).is_equal(10.0)
	assert_int(gs.pickups.size()).is_equal(0)


func test_no_light_sources_is_safe() -> void:
	var gs := _state()
	gs.zones = [_zone(Vector2.ZERO, 50.0, 10.0)]
	CombatSystem.step(gs, 0.016)  # must not crash with an empty light_sources array
	assert_int(gs.light_sources.size()).is_equal(0)


# --- SpawnDirector: periodic brazier spawning ---

func test_brazier_spawns_after_interval() -> void:
	var gs := _state()
	var stage := _brazier_stage(1.0)
	SpawnDirector.step(gs, stage, 0.5)
	assert_int(gs.light_sources.size()).is_equal(0)  # interval not reached yet
	SpawnDirector.step(gs, stage, 0.6)               # accumulated 1.1 >= 1.0
	assert_int(gs.light_sources.size()).is_equal(1)


func test_brazier_interval_zero_disables() -> void:
	var gs := _state()
	var stage := _brazier_stage(0.0)
	SpawnDirector.step(gs, stage, 100.0)
	assert_int(gs.light_sources.size()).is_equal(0)


func test_brazier_spawns_in_ring() -> void:
	var gs := _state()
	var stage := _brazier_stage(1.0)
	SpawnDirector.step(gs, stage, 1.0)
	assert_int(gs.light_sources.size()).is_equal(1)
	var d := gs.player.pos.distance_to(gs.light_sources[0].pos)
	assert_bool(d >= SpawnDirector.BRAZIER_RING_MIN and d <= SpawnDirector.BRAZIER_RING_MAX).is_true()


# --- PickupTable: default drop values ---

func test_pickup_table_default_values() -> void:
	assert_float(PickupTable.default_value(Pickup.Type.CHICKEN)).is_equal(30.0)
	assert_float(PickupTable.default_value(Pickup.Type.COIN)).is_equal(1.0)
	assert_float(PickupTable.default_value(Pickup.Type.COIN_BAG)).is_equal(10.0)
	assert_float(PickupTable.default_value(Pickup.Type.VACUUM)).is_equal(0.0)  # effect ignores value
