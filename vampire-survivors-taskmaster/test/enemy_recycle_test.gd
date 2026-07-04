## Pins VSEnemy recycling: a base-trickle enemy the player has outrun by more than DESPAWN_RADIUS
## is teleported back onto the spawn ring around the player (so it keeps threatening a fleeing
## player instead of stranding offscreen and eating the spawner's concurrent-enemy budget), while
## mini-bosses/Reaper are exempt and keep marching. The run is a bare state bag so no world is
## built; enemies join the "enemies" group via their own _ready. Runs under the project so the
## AgentBridge autoload the events emit on exists.
extends GdUnitTestSuite

func _state_run() -> VSRun:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	run.elapsed = 0.0                   # no HP ramp -> enemies sit at their base stats
	return run

func _spawn_enemy(run: VSRun, t: int, at: Vector2, target: VSPlayer) -> VSEnemy:
	var e := VSEnemy.new()
	e.type = t
	e.run = run
	e.target = target
	add_child(e)                        # _ready applies stats + joins "enemies"
	auto_free(e)
	e.position = at                     # set after _ready so it isn't overwritten
	return e

func test_outrun_enemy_recycles_onto_the_spawn_ring() -> void:
	var run := _state_run()
	var player := VSPlayer.new()
	auto_free(player)
	player.position = Vector2.ZERO
	var bat := _spawn_enemy(run, VSEnemy.Type.BAT, Vector2(2000.0, 0.0), player)

	# d = 2000 > DESPAWN_RADIUS (1000): the straggler teleports back to the ring around the player.
	assert_float(bat.position.distance_to(player.position)).is_greater(VSEnemy.DESPAWN_RADIUS)
	bat._process(0.016)
	# Now sits exactly on the spawn ring (520 < arena_half, so no clamp shortens it) — well within
	# DESPAWN_RADIUS and far closer than the 2000px it started at.
	assert_float(bat.position.distance_to(player.position)).is_equal_approx(VSSpawner.SPAWN_RING, 1.0)

func test_boss_does_not_recycle() -> void:
	var run := _state_run()
	var player := VSPlayer.new()
	auto_free(player)
	player.position = Vector2.ZERO
	# An ELITE dragged just as far away must NOT recycle (GDD: bosses don't despawn). Over one
	# tiny frame it only inches toward the player, staying far past the spawn ring.
	var elite := _spawn_enemy(run, VSEnemy.Type.ELITE, Vector2(2000.0, 0.0), player)
	elite._process(0.016)
	assert_float(elite.position.distance_to(player.position)).is_greater(1500.0)
