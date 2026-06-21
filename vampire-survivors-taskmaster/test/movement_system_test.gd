extends GdUnitTestSuite

## Tests MovementSystem: player movement/facing, enemy homing, fixed-direction
## drift, knockback, freeze, and the floaty bob.

func _enemy(pos: Vector2, speed: float) -> Enemy:
	var e := Enemy.new()
	e.pos = pos
	var d := EnemyDef.new()
	d.speed = speed
	e.def = d
	return e


func _state_with(enemies: Array, player_pos := Vector2.ZERO, time := 0.0) -> GameState:
	var gs := GameState.new()
	gs.player.pos = player_pos
	gs.enemies = enemies
	gs.time_elapsed = time
	return gs


# --- player ---

func test_player_moves_right() -> void:
	var p := PlayerState.new()
	MovementSystem.step_player(p, Vector2(1, 0), 1.0)
	assert_vector(p.pos).is_equal(Vector2(100, 0))
	assert_vector(p.facing).is_equal(Vector2(1, 0))
	assert_vector(p.velocity).is_equal(Vector2(100, 0))


func test_player_diagonal_is_normalized() -> void:
	var p := PlayerState.new()
	MovementSystem.step_player(p, Vector2(1, 1), 1.0)
	# Speed is 100 along the diagonal, not 100 per-axis.
	assert_float(p.pos.x).is_equal_approx(70.7107, 0.001)
	assert_float(p.pos.y).is_equal_approx(70.7107, 0.001)


func test_player_no_input_stops_but_keeps_facing() -> void:
	var p := PlayerState.new()
	MovementSystem.step_player(p, Vector2(-1, 0), 1.0)  # face left
	var pos_after_move := p.pos
	MovementSystem.step_player(p, Vector2.ZERO, 1.0)  # release
	assert_vector(p.velocity).is_equal(Vector2.ZERO)
	assert_vector(p.pos).is_equal(pos_after_move)  # did not move
	assert_vector(p.facing).is_equal(Vector2(-1, 0))  # facing retained


func test_player_move_speed_multiplier() -> void:
	var p := PlayerState.new()
	p.derived.move_speed = 2.0
	MovementSystem.step_player(p, Vector2(1, 0), 1.0)
	assert_vector(p.pos).is_equal(Vector2(200, 0))


func test_player_dt_scaling() -> void:
	var p := PlayerState.new()
	MovementSystem.step_player(p, Vector2(1, 0), 0.5)
	assert_vector(p.pos).is_equal(Vector2(50, 0))


# --- enemies ---

func test_enemy_homes_toward_player() -> void:
	var e := _enemy(Vector2(100, 0), 50.0)
	var gs := _state_with([e], Vector2.ZERO)
	MovementSystem.step_enemies(gs, 1.0)
	assert_vector(e.pos).is_equal(Vector2(50, 0))  # moved 50 toward origin
	assert_vector(e.velocity).is_equal(Vector2(-50, 0))


func test_enemy_homing_is_normalized() -> void:
	var e := _enemy(Vector2(300, 400), 50.0)  # distance 500
	var gs := _state_with([e], Vector2.ZERO)
	MovementSystem.step_enemies(gs, 1.0)
	# Moves 50px along the unit direction (-0.6, -0.8).
	assert_vector(e.pos).is_equal_approx(Vector2(270, 360), Vector2(0.01, 0.01))


func test_enemy_frozen_does_not_move() -> void:
	var e := _enemy(Vector2(100, 0), 50.0)
	e.freeze_timer = 1.0
	var gs := _state_with([e], Vector2.ZERO)
	MovementSystem.step_enemies(gs, 0.5)
	assert_vector(e.pos).is_equal(Vector2(100, 0))
	assert_float(e.freeze_timer).is_equal(0.5)


func test_enemy_knockback_overrides_homing() -> void:
	var e := _enemy(Vector2(100, 0), 50.0)
	e.knockback = Vector2(10, 0)  # away from player at origin
	e.knockback_timer = 1.0
	var gs := _state_with([e], Vector2.ZERO)
	MovementSystem.step_enemies(gs, 0.5)
	assert_vector(e.pos).is_equal(Vector2(105, 0))  # knocked back, not homed
	assert_float(e.knockback_timer).is_equal(0.5)


func test_enemy_fixed_direction_ignores_player() -> void:
	var e := Enemy.new()
	e.pos = Vector2(0, 0)
	e.fixed_direction = true
	e.velocity = Vector2(5, 5)
	var gs := _state_with([e], Vector2(1000, 1000))
	MovementSystem.step_enemies(gs, 2.0)
	assert_vector(e.pos).is_equal(Vector2(10, 10))  # along its own velocity


func test_enemy_null_def_does_not_crash() -> void:
	var e := Enemy.new()
	e.pos = Vector2(100, 0)
	e.def = null
	var gs := _state_with([e], Vector2.ZERO)
	MovementSystem.step_enemies(gs, 1.0)
	assert_vector(e.pos).is_equal(Vector2(100, 0))  # no def -> speed 0 -> no move


func test_floaty_adds_vertical_bob() -> void:
	# At the player's position homing is zero, isolating the floaty effect.
	var floaty := Enemy.new()
	floaty.pos = Vector2.ZERO
	floaty.floaty = true
	var plain := Enemy.new()
	plain.pos = Vector2.ZERO
	var gs := _state_with([floaty, plain], Vector2.ZERO, 0.5)  # sin(1.5) != 0
	MovementSystem.step_enemies(gs, 0.1)
	assert_float(floaty.pos.y).is_not_equal(0.0)
	assert_vector(plain.pos).is_equal(Vector2.ZERO)


func test_multiple_enemies_all_step() -> void:
	var e1 := _enemy(Vector2(100, 0), 100.0)
	var e2 := _enemy(Vector2(0, 100), 100.0)
	var gs := _state_with([e1, e2], Vector2.ZERO)
	MovementSystem.step_enemies(gs, 0.5)
	assert_vector(e1.pos).is_equal(Vector2(50, 0))
	assert_vector(e2.pos).is_equal(Vector2(0, 50))
