extends SceneTree

## Headless test runner for the Task 6 MovementSystem (pure logic).
##   godot --headless --path . --script res://test/movement_system_test.gd
## Exit code == number of failed checks (0 == all passed).

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== movement_system_test ==")
	_test_player_movement()
	_test_player_iframe_decay()
	_test_enemy_homing()
	_test_enemy_fixed()
	_test_enemy_frozen()
	_test_enemy_knockback()
	_test_separation()
	_test_projectile_straight_and_lifetime()
	_test_projectile_bounce()
	_test_projectile_orbit()
	_test_projectile_aura()
	_test_projectile_homing()
	_test_pickup_magnet()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _vapprox(a: Vector2, b: Vector2, msg: String) -> void:
	_check(a.is_equal_approx(b), "%s (got %v, want %v)" % [msg, a, b])

func _make_state() -> RunState:
	var s := RunState.new()
	s.player = PlayerState.new()
	s.enemies = EnemyPool.new()
	s.projectiles = ProjectilePool.new()
	s.pickups = PickupPool.new()
	s.grid = SpatialGrid.new()
	return s

func _test_player_movement() -> void:
	var s := _make_state()
	s.player.pos = Vector2.ZERO
	s.player.vel = Vector2(1, 0)  # intent right
	MovementSystem._move_player(s, 0.1)
	_vapprox(s.player.pos, Vector2(20, 0), "player moves base_speed*delta = 20px right")
	_vapprox(s.player.facing, Vector2.RIGHT, "facing follows movement")

	# diagonal intent normalizes (no faster diagonal)
	s.player.pos = Vector2.ZERO
	s.player.vel = Vector2(1, 1)
	MovementSystem._move_player(s, 0.1)
	_check(is_equal_approx(s.player.pos.length(), 20.0), "diagonal move same 20px speed")

	# zero intent -> no move, facing unchanged
	s.player.pos = Vector2(5, 5)
	s.player.facing = Vector2.UP
	s.player.vel = Vector2.ZERO
	MovementSystem._move_player(s, 0.1)
	_vapprox(s.player.pos, Vector2(5, 5), "zero intent keeps position")
	_vapprox(s.player.facing, Vector2.UP, "zero intent keeps facing")

	# move_speed multiplier
	s.player.pos = Vector2.ZERO
	s.player.vel = Vector2(1, 0)
	s.player.stats = StatBlock.new()
	s.player.stats.move_speed = 1.5
	MovementSystem._move_player(s, 0.1)
	_vapprox(s.player.pos, Vector2(30, 0), "move_speed 1.5 -> 30px")

func _test_player_iframe_decay() -> void:
	var s := _make_state()
	s.player.iframe_timer = 0.3
	MovementSystem._move_player(s, 0.1)
	_check(is_equal_approx(s.player.iframe_timer, 0.2), "iframe decays by delta")
	s.player.iframe_timer = 0.05
	MovementSystem._move_player(s, 0.1)
	_check(s.player.iframe_timer == 0.0, "iframe floors at 0")

func _test_enemy_homing() -> void:
	var s := _make_state()
	var idx: int = s.enemies.spawn(&"zombie", Vector2(100, 0), { move_speed = 100.0, ai = "homing" })
	MovementSystem._move_enemies(s, 0.1)  # player at origin
	_vapprox(s.enemies.vel[idx], Vector2(-100, 0), "homing enemy aims at player")
	_vapprox(s.enemies.pos[idx], Vector2(90, 0), "homing enemy moves 10px toward player")

func _test_enemy_fixed() -> void:
	var s := _make_state()
	var idx: int = s.enemies.spawn(&"bat_swarm", Vector2(0, 0), { move_speed = 100.0, ai = "fixed" })
	s.enemies.vel[idx] = Vector2(50, 0)  # SpawnDirector sets a heading
	MovementSystem._move_enemies(s, 0.1)
	_vapprox(s.enemies.vel[idx], Vector2(100, 0), "fixed enemy keeps heading at move_speed")
	_vapprox(s.enemies.pos[idx], Vector2(10, 0), "fixed enemy advances along heading")

func _test_enemy_frozen() -> void:
	var s := _make_state()
	var idx: int = s.enemies.spawn(&"zombie", Vector2(100, 0), { move_speed = 100.0, ai = "homing" })
	s.freeze_timer = 5.0
	MovementSystem._move_enemies(s, 0.1)
	_vapprox(s.enemies.pos[idx], Vector2(100, 0), "frozen enemy does not move")

func _test_enemy_knockback() -> void:
	var s := _make_state()
	var idx: int = s.enemies.spawn(&"zombie", Vector2(0, 0), { move_speed = 100.0, ai = "homing" })
	s.enemies.knockback_timer[idx] = 0.2
	s.enemies.vel[idx] = Vector2(50, 0)  # knockback push set by CollisionSystem
	MovementSystem._move_enemies(s, 0.1)
	_vapprox(s.enemies.pos[idx], Vector2(5, 0), "knockback slides along vel")
	_check(is_equal_approx(s.enemies.knockback_timer[idx], 0.1), "knockback timer decays")
	_vapprox(s.enemies.vel[idx], Vector2(50, 0), "AI does not override during knockback")

func _test_separation() -> void:
	var s := _make_state()
	var a: int = s.enemies.spawn(&"zombie", Vector2(0, 0), { move_speed = 100.0, ai = "none" })
	var b: int = s.enemies.spawn(&"zombie", Vector2(5, 0), { move_speed = 100.0, ai = "none" })
	SpatialIndex.rebuild(s.grid, s.enemies)
	MovementSystem._apply_separation(s, 0.1)
	# symmetric push: a goes left of 0, b goes right of 5
	_check(s.enemies.pos[a].x < 0.0, "overlapping enemy A pushed left")
	_check(s.enemies.pos[b].x > 5.0, "overlapping enemy B pushed right")
	_check(s.enemies.pos[a].x < s.enemies.pos[b].x, "enemies separated")

func _test_projectile_straight_and_lifetime() -> void:
	var s := _make_state()
	# infinite-lifetime (0) straight projectile just moves
	var idx: int = s.projectiles.spawn(Vector2(0, 0), Vector2(100, 0), { behavior = ProjectilePool.Behavior.STRAIGHT, lifetime = 0.0 })
	MovementSystem._move_projectiles(s, 0.1)
	_vapprox(s.projectiles.pos[idx], Vector2(10, 0), "straight projectile moves")
	_check(s.projectiles.alive[idx], "lifetime 0 means no time despawn")
	# time-limited projectile expires
	var t: int = s.projectiles.spawn(Vector2(0, 0), Vector2(100, 0), { behavior = ProjectilePool.Behavior.STRAIGHT, lifetime = 0.15 })
	MovementSystem._move_projectiles(s, 0.1)
	_check(s.projectiles.alive[t], "still alive at lifetime 0.05")
	MovementSystem._move_projectiles(s, 0.1)
	_check(not s.projectiles.alive[t], "despawns when lifetime crosses 0")

func _test_projectile_bounce() -> void:
	var s := _make_state()
	s.camera_world_rect = Rect2(-50, -50, 100, 100)  # edges at +/-50
	var idx: int = s.projectiles.spawn(Vector2(45, 0), Vector2(100, 0), { behavior = ProjectilePool.Behavior.BOUNCE, lifetime = 0.0 })
	MovementSystem._move_projectiles(s, 0.1)  # would reach 55, past the +50 edge
	_check(is_equal_approx(s.projectiles.pos[idx].x, 50.0), "bounce clamps to edge")
	_check(s.projectiles.vel[idx].x < 0.0, "bounce reverses x velocity")

func _test_projectile_orbit() -> void:
	var s := _make_state()
	s.player.pos = Vector2.ZERO
	var idx: int = s.projectiles.spawn(Vector2(10, 0), Vector2.ZERO, { behavior = ProjectilePool.Behavior.ORBIT, lifetime = 0.0 })
	MovementSystem._move_projectiles(s, 0.1)
	_check(is_equal_approx(s.projectiles.pos[idx].length(), 10.0), "orbit preserves radius")
	_check(s.projectiles.pos[idx].y > 0.0, "orbit advances angle (CCW)")
	_check(s.projectiles.pos[idx].x < 10.0, "orbit moved off the start axis")

func _test_projectile_aura() -> void:
	var s := _make_state()
	s.player.pos = Vector2(5, 5)
	var idx: int = s.projectiles.spawn(Vector2(0, 0), Vector2.ZERO, { behavior = ProjectilePool.Behavior.AURA, lifetime = 0.0 })
	MovementSystem._move_projectiles(s, 0.1)
	_vapprox(s.projectiles.pos[idx], Vector2(5, 5), "aura follows the player")

func _test_projectile_homing() -> void:
	var s := _make_state()
	s.enemies.spawn(&"zombie", Vector2(100, 0), { move_speed = 0.0, ai = "homing" })
	SpatialIndex.rebuild(s.grid, s.enemies)
	# projectile moving down at speed 100, enemy is to the right -> should steer right
	var idx: int = s.projectiles.spawn(Vector2(0, 0), Vector2(0, 100), { behavior = ProjectilePool.Behavior.HOMING, lifetime = 0.0 })
	MovementSystem._move_projectiles(s, 0.1)
	_vapprox(s.projectiles.vel[idx], Vector2(100, 0), "homing steers toward nearest enemy, keeps speed")

func _test_pickup_magnet() -> void:
	var s := _make_state()
	s.player.pos = Vector2.ZERO
	var idx: int = s.pickups.spawn(PickupPool.Kind.GEM, Vector2(100, 0), 2.0)
	s.pickups.magnetized[idx] = true
	MovementSystem._move_pickups(s, 0.1)  # 400*0.1 = 40px pull
	_vapprox(s.pickups.pos[idx], Vector2(60, 0), "magnetized pickup pulled toward player")
	# non-magnetized does not move
	var still: int = s.pickups.spawn(PickupPool.Kind.GOLD, Vector2(80, 0), 10.0)
	MovementSystem._move_pickups(s, 0.1)
	_vapprox(s.pickups.pos[still], Vector2(80, 0), "non-magnetized pickup stays put")
	# overshoot clamps to player
	var near: int = s.pickups.spawn(PickupPool.Kind.GEM, Vector2(5, 0), 2.0)
	s.pickups.magnetized[near] = true
	MovementSystem._move_pickups(s, 0.1)
	_vapprox(s.pickups.pos[near], Vector2.ZERO, "pickup within one step snaps to player")
