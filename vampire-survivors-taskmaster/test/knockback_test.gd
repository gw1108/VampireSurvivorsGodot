## Pins VSEnemy knockback: a weapon hit shoves the enemy directly away from the hit source,
## scaled by the per-type resistance (heavy ELITE/REAPER barely flinch), and the impulse
## decays as it is applied in _process. The run is a bare state bag so no world is built;
## enemies join the "enemies" group via their own _ready. Runs under the project so the
## AgentBridge autoload the events emit on exists.
extends GdUnitTestSuite

func _state_run() -> VSRun:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	run.elapsed = 0.0                   # no HP ramp -> enemies sit at their base stats
	return run

func _spawn_enemy(run: VSRun, t: int) -> VSEnemy:
	var e := VSEnemy.new()
	e.type = t
	e.run = run
	e.target = null                     # no target -> _process bails (isolate hit() below)
	add_child(e)                        # _ready applies stats + joins "enemies"
	auto_free(e)
	return e

func test_hit_shoves_enemy_away_from_source_and_bosses_resist() -> void:
	var run := _state_run()
	var zombie := _spawn_enemy(run, VSEnemy.Type.ZOMBIE)
	zombie.position = Vector2.ZERO
	var reaper := _spawn_enemy(run, VSEnemy.Type.REAPER)
	reaper.position = Vector2.ZERO

	# Hit both from the LEFT — knockback must point RIGHT (away from the source).
	zombie.hit(5.0, Vector2(-10.0, 0.0))
	reaper.hit(5.0, Vector2(-10.0, 0.0))

	assert_float(zombie._knockback.x).is_greater(0.0)
	assert_float(abs(zombie._knockback.y)).is_less(0.001)
	assert_float(zombie._knockback.length()).is_equal_approx(VSEnemy.KNOCKBACK_IMPULSE, 0.001)

	# The near-immovable Reaper is shoved far less than a normal enemy (knock resist 0.06).
	assert_float(reaper._knockback.length()).is_less(zombie._knockback.length() * 0.2)

func test_dead_centre_hit_adds_no_knockback() -> void:
	var run := _state_run()
	var zombie := _spawn_enemy(run, VSEnemy.Type.ZOMBIE)
	zombie.position = Vector2(50.0, 50.0)
	zombie.hit(5.0, zombie.position)    # source == position -> no direction, no shove
	assert_vector(zombie._knockback).is_equal(Vector2.ZERO)

func test_knockback_moves_position_then_decays() -> void:
	var run := _state_run()
	var zombie := _spawn_enemy(run, VSEnemy.Type.ZOMBIE)
	zombie.position = Vector2.ZERO
	# A target sitting exactly on the enemy zeroes the homing drive, so only knockback moves it.
	var pin := VSPlayer.new()
	auto_free(pin)
	pin.position = Vector2.ZERO
	zombie.target = pin

	zombie.hit(5.0, Vector2(-10.0, 0.0))            # knockback -> +x
	var impulse := zombie._knockback.length()
	zombie._process(0.05)

	assert_float(zombie.position.x).is_greater(0.0)         # got shoved right
	assert_float(zombie._knockback.length()).is_less(impulse)   # impulse bled off
