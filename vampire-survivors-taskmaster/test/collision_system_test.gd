extends SceneTree

## Headless test runner for the Task 7 CollisionSystem (pure logic).
##   godot --headless --path . --script res://test/collision_system_test.gd
## Exit code == number of failed checks (0 == all passed).

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== collision_system_test ==")
	_test_weapon_hit_and_might()
	_test_crit()
	_test_pierce_multi()
	_test_pierce_dedup_permanent()
	_test_aura_retick()
	_test_knockback()
	_test_enemy_death_gem_and_kill()
	_test_boss_death()
	_test_contact_damage()
	_test_contact_iframe_block()
	_test_pickup_magnet_and_collect()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _approx(a: float, b: float, msg: String) -> void:
	_check(is_equal_approx(a, b), "%s (got %f, want %f)" % [msg, a, b])

func _make_state() -> RunState:
	var s := RunState.new()
	s.player = PlayerState.new()
	s.player.stats = StatBlock.new()
	s.player.stats.magnet = 30.0
	s.enemies = EnemyPool.new()
	s.projectiles = ProjectilePool.new()
	s.pickups = PickupPool.new()
	s.grid = SpatialGrid.new()
	s.rng = RandomNumberGenerator.new()
	s.rng.seed = 99
	return s

func _spawn_enemy(s: RunState, pos: Vector2, hp: float, extra: Dictionary = {}) -> int:
	var def := { hp = hp, power = 10.0, move_speed = 100.0, knockback_resist = 0.0, xp = 1.0, ai = "homing" }
	for k in extra:
		def[k] = extra[k]
	var idx: int = s.enemies.spawn(&"zombie", pos, def)
	return idx

func _test_weapon_hit_and_might() -> void:
	var s := _make_state()
	var e := _spawn_enemy(s, Vector2(0, 0), 100.0)
	SpatialIndex.rebuild(s.grid, s.enemies)
	var p: int = s.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { damage = 10.0, pierce = 1 })
	CollisionSystem.resolve(s, null, 0.1)
	_approx(s.enemies.hp[e], 90.0, "damage = weaponBase * might(1) = 10")
	_check(s.enemies.hit_flash[e] > 0.0, "hit sets hit_flash")
	_check(not s.projectiles.alive[p], "pierce-1 projectile despawns after the hit")
	# despawn used the pool path (free_list restored)
	_check(s.projectiles.active_count == 0, "projectile despawn updates active_count (no slot leak)")

	# might scaling
	var s2 := _make_state()
	var e2 := _spawn_enemy(s2, Vector2(0, 0), 100.0)
	s2.player.stats.might = 2.0
	SpatialIndex.rebuild(s2.grid, s2.enemies)
	s2.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { damage = 10.0, pierce = 1 })
	CollisionSystem.resolve(s2, null, 0.1)
	_approx(s2.enemies.hp[e2], 80.0, "might 2.0 doubles damage to 20")

func _test_crit() -> void:
	var s := _make_state()
	var e := _spawn_enemy(s, Vector2(0, 0), 100.0)
	SpatialIndex.rebuild(s.grid, s.enemies)
	s.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { damage = 10.0, pierce = 1, crit_chance = 1.0, crit_mult = 2.0 })
	CollisionSystem.resolve(s, null, 0.1)
	_approx(s.enemies.hp[e], 80.0, "guaranteed crit applies crit_mult (10*2=20)")

func _test_pierce_multi() -> void:
	var s := _make_state()
	var a := _spawn_enemy(s, Vector2(0, 0), 100.0)
	var b := _spawn_enemy(s, Vector2(5, 0), 100.0)
	var c := _spawn_enemy(s, Vector2(10, 0), 100.0)
	SpatialIndex.rebuild(s.grid, s.enemies)
	var p: int = s.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { damage = 10.0, pierce = 3 })
	CollisionSystem.resolve(s, null, 0.1)
	_approx(s.enemies.hp[a], 90.0, "pierce hits enemy A")
	_approx(s.enemies.hp[b], 90.0, "pierce hits enemy B")
	_approx(s.enemies.hp[c], 90.0, "pierce hits enemy C")
	_check(not s.projectiles.alive[p], "pierce exhausted after 3 enemies -> despawn")

func _test_pierce_dedup_permanent() -> void:
	var s := _make_state()
	var e := _spawn_enemy(s, Vector2(0, 0), 100.0)
	SpatialIndex.rebuild(s.grid, s.enemies)
	# infinite pierce (-1), no hit_cooldown -> hits each enemy at most once ever
	var p: int = s.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { damage = 10.0, pierce = -1, hit_cooldown = 0.0 })
	CollisionSystem.resolve(s, null, 0.1)
	CollisionSystem.resolve(s, null, 0.1)
	_approx(s.enemies.hp[e], 90.0, "infinite-pierce hits an enemy only once (de-dup)")
	_check(s.projectiles.alive[p], "infinite-pierce projectile does NOT despawn on hit")

func _test_aura_retick() -> void:
	var s := _make_state()
	var e := _spawn_enemy(s, Vector2(0, 0), 100.0)
	SpatialIndex.rebuild(s.grid, s.enemies)
	# aura: infinite pierce + hit_cooldown -> re-hits after the cooldown elapses
	s.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { damage = 10.0, pierce = -1, hit_cooldown = 0.05 })
	CollisionSystem.resolve(s, null, 0.1)  # hit #1
	CollisionSystem.resolve(s, null, 0.1)  # cooldown (0.05) expired -> hit #2
	_approx(s.enemies.hp[e], 80.0, "aura re-ticks after hit_cooldown (two hits)")

func _test_knockback() -> void:
	var s := _make_state()
	var e := _spawn_enemy(s, Vector2(10, 0), 100.0, { knockback_resist = 0.0 })
	SpatialIndex.rebuild(s.grid, s.enemies)
	s.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { damage = 1.0, pierce = 1 })
	CollisionSystem.resolve(s, null, 0.1)
	_check(s.enemies.vel[e].x > 0.0, "knockback pushes enemy away from projectile (+x)")
	_approx(s.enemies.knockback_timer[e], CollisionSystem.KNOCKBACK_TIME, "knockback timer set")

	# fully resistant enemy gets no knockback
	var s2 := _make_state()
	var e2 := _spawn_enemy(s2, Vector2(10, 0), 100.0, { knockback_resist = 1.0 })
	SpatialIndex.rebuild(s2.grid, s2.enemies)
	s2.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { damage = 1.0, pierce = 1 })
	CollisionSystem.resolve(s2, null, 0.1)
	_check(s2.enemies.vel[e2] == Vector2.ZERO, "fully knockback-resistant enemy not pushed")
	_check(s2.enemies.knockback_timer[e2] == 0.0, "resistant enemy keeps zero knockback timer")

func _test_enemy_death_gem_and_kill() -> void:
	var s := _make_state()
	var e := _spawn_enemy(s, Vector2(50, 50), 5.0, { xp = 5.0 })
	SpatialIndex.rebuild(s.grid, s.enemies)
	s.projectiles.spawn(Vector2(50, 50), Vector2.ZERO, { damage = 10.0, pierce = 1 })
	CollisionSystem.resolve(s, null, 0.1)
	_check(not s.enemies.alive[e], "lethal hit despawns the enemy")
	_check(s.player.kills == 1, "kill counted")
	_check(s.pickups.gem_count == 1, "one XP gem spawned on death")
	# find the gem
	var gem := -1
	for i in PickupPool.CAPACITY:
		if s.pickups.alive[i] and s.pickups.kind[i] == PickupPool.Kind.GEM:
			gem = i
			break
	_check(gem >= 0, "gem present in pickup pool")
	_approx(s.pickups.value[gem], 5.0, "gem carries the enemy XP value")
	_check(s.pickups.gem_tier[gem] == PickupPool.GemTier.GREEN, "xp 5 -> green gem tier")
	_check(s.pickups.pos[gem] == Vector2(50, 50), "gem drops at the enemy position")

func _test_boss_death() -> void:
	var s := _make_state()
	# place the boss away from the player so its dropped gem isn't auto-collected
	var e := _spawn_enemy(s, Vector2(200, 0), 5.0, { xp = 30.0, is_boss = true })
	SpatialIndex.rebuild(s.grid, s.enemies)
	s.projectiles.spawn(Vector2(200, 0), Vector2.ZERO, { damage = 10.0, pierce = 1 })
	var result = CollisionSystem.resolve(s, null, 0.1)
	_check(result.boss_deaths.size() == 1, "boss death recorded for chest dispatch")
	_check(s.pickups.gem_tier[_first_gem(s)] == PickupPool.GemTier.RED, "xp 30 -> red gem tier")

func _first_gem(s: RunState) -> int:
	for i in PickupPool.CAPACITY:
		if s.pickups.alive[i] and s.pickups.kind[i] == PickupPool.Kind.GEM:
			return i
	return -1

func _test_contact_damage() -> void:
	var s := _make_state()
	s.player.pos = Vector2.ZERO
	s.player.hp = 100.0
	s.player.stats.armor = 2.0
	_spawn_enemy(s, Vector2(5, 0), 100.0, { power = 10.0 })  # within PLAYER_RADIUS
	SpatialIndex.rebuild(s.grid, s.enemies)
	CollisionSystem.resolve(s, null, 0.1)
	_approx(s.player.hp, 92.0, "contact damage = max(1, power 10 - armor 2) = 8")
	_approx(s.player.iframe_timer, CollisionSystem.IFRAME_TIME, "contact sets i-frames")

	# minimum 1 damage even through high armor
	var s2 := _make_state()
	s2.player.hp = 100.0
	s2.player.stats.armor = 50.0
	_spawn_enemy(s2, Vector2(5, 0), 100.0, { power = 1.0 })
	SpatialIndex.rebuild(s2.grid, s2.enemies)
	CollisionSystem.resolve(s2, null, 0.1)
	_approx(s2.player.hp, 99.0, "damage floored at 1 regardless of armor")

func _test_contact_iframe_block() -> void:
	var s := _make_state()
	s.player.hp = 100.0
	s.player.iframe_timer = 0.1  # invulnerable
	_spawn_enemy(s, Vector2(5, 0), 100.0, { power = 10.0 })
	SpatialIndex.rebuild(s.grid, s.enemies)
	CollisionSystem.resolve(s, null, 0.1)
	_approx(s.player.hp, 100.0, "no contact damage while i-frames active")

func _test_pickup_magnet_and_collect() -> void:
	var s := _make_state()
	s.player.pos = Vector2.ZERO  # magnet radius 30, collect radius 16
	# gem just outside collect but inside magnet -> magnetized, not collected
	var far: int = s.pickups.spawn(PickupPool.Kind.GEM, Vector2(25, 0), 2.0)
	# gem inside collect -> collected as xp
	var near: int = s.pickups.spawn(PickupPool.Kind.GEM, Vector2(5, 0), 7.0)
	# chest inside collect -> seed recorded
	var chest: int = s.pickups.spawn(PickupPool.Kind.CHEST, Vector2(3, 0), 3.0)
	# chicken inside collect -> effect recorded
	var chick: int = s.pickups.spawn(PickupPool.Kind.CHICKEN, Vector2(2, 0), 30.0)
	var result = CollisionSystem.resolve(s, null, 0.1)
	_check(s.pickups.magnetized[far], "pickup inside magnet radius is magnetized")
	_check(s.pickups.alive[far], "magnetized-but-far pickup not yet collected")
	_check(not s.pickups.alive[near], "pickup inside collect radius is collected")
	_approx(result.xp_gained, 7.0, "collected gem adds its xp")
	_check(result.collected_chests.size() == 1 and is_equal_approx(result.collected_chests[0], 3.0), "chest seed recorded (not slot index)")
	_check(result.collected_effects.size() == 1, "chicken recorded as an effect")
	_check(result.collected_effects[0].kind == PickupPool.Kind.CHICKEN and is_equal_approx(result.collected_effects[0].value, 30.0), "effect carries kind + value")
	_check(not s.pickups.alive[chest] and not s.pickups.alive[chick], "collected chest + chicken despawned")
