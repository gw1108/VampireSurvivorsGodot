extends GdUnitTestSuite

## Integration tests for the core simulation: every assertion is produced by
## driving the REAL RunController._tick pipeline (stats -> movement -> spawning ->
## index -> weapons -> combat -> pickups -> health -> progression), the same path
## _physics_process uses live. Complements golden_path_test (one scripted full
## run) with focused pipeline invariants and a same-seed determinism guarantee.
##
## Helpers reuse RunController.start_run to build a real run from Antonio's def,
## then reset to a deterministic baseline so RNG-sensitive behaviour (spawns, crit
## rolls, offer shuffles) is reproducible. No system is stubbed.

const SEED: int = 987654321


func _run() -> RunController:
	return auto_free(RunController.new())


## A weak enemy with a real EnemyDef (drops `xp` XP on death).
func _enemy(pos: Vector2, hp: float = 1.0, xp: float = 1.0) -> Enemy:
	var e := Enemy.new()
	e.pos = pos
	e.hp = hp
	var d := EnemyDef.new()
	d.id = "bat"
	d.power = 5.0
	d.speed = 140.0
	d.xp_value = xp
	e.def = d
	return e


## Reset a freshly-started run to a fixed, reproducible baseline: clear the
## time-seeded starting spawns and counters, then pin the RNG. After this two runs
## are bit-identical, so the same tick sequence yields the same state.
func _baseline(rc: RunController) -> void:
	rc.state.enemies.clear()
	rc.state.gems.clear()
	rc.state.pickups.clear()
	rc.state.projectiles.clear()
	rc.state.zones.clear()
	rc.state.spawn_cursor = 0
	rc.state.spawn_timer = 0.0
	rc.state.time_elapsed = 0.0
	rc.state.current_minute = 0
	rc.state.kills = 0
	rc.state.gold = 0
	rc.state.rng.seed = SEED  # assigning seed also resets the generator's state


# --- full tick pipeline ---

func test_full_tick_pipeline_moves_player_and_advances_time() -> void:
	var rc := _run()
	rc.start_run("antonio")
	rc.state.enemies.clear()  # isolate movement/time from combat & level-ups

	# Simulate 60 ticks (~1 second) holding right.
	for i in 60:
		rc._tick(1.0 / 60.0, Vector2.RIGHT)

	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_float(rc.state.player.pos.x).is_greater(0.0)           # player moved right
	assert_vector(rc.state.player.facing).is_equal(Vector2.RIGHT)  # facing tracks input
	assert_float(rc.state.time_elapsed).is_equal_approx(1.0, 0.01)  # SpawnDirector advanced time


# --- emergent combat: an enemy spawns, is killed, drops a gem ---

func test_enemy_is_killed_and_drops_a_gem() -> void:
	var rc := _run()
	rc.start_run("antonio")
	rc.state.enemies.clear()
	rc.state.rng.seed = SEED
	# One weak enemy inside the whip's reach (player faces right by default).
	rc.state.enemies.append(_enemy(rc.state.player.pos + Vector2(40.0, 0.0)))

	var ticks := 0
	while rc.state.kills < 1 and ticks < 300:
		rc._tick(1.0 / 60.0, Vector2.ZERO)
		ticks += 1

	assert_int(rc.state.kills).is_greater_equal(1)        # the whip killed it
	assert_int(rc.state.gems.size()).is_greater_equal(1)  # death dropped an XP gem


# --- progression: XP crosses the level threshold and queues a level-up ---

func test_add_xp_queues_level_up() -> void:
	var rc := _run()
	rc.start_run("antonio")
	var level_before := rc.state.player.level

	ProgressionSystem.add_xp(rc.state, 100.0)

	assert_int(rc.state.pending_levelups).is_greater(0)
	assert_int(rc.state.player.level).is_greater(level_before)


# --- determinism: same seed + same inputs -> identical outcome ---

func _scripted_dir(i: int) -> Vector2:
	# A fixed, varied input pattern so movement (and the systems it feeds) differs
	# tick-to-tick but is identical across runs.
	match i % 4:
		0: return Vector2.RIGHT
		1: return Vector2.DOWN
		2: return Vector2.LEFT
		_: return Vector2.UP


## Drive a deterministic scenario: pinned seed, a fixed enemy cluster (xp_value 0
## so the run never leaves PLAYING and the whole pipeline runs every tick), and a
## scripted input sequence. Returns a signature of the resulting state.
func _deterministic_signature() -> Array:
	var rc := _run()
	rc.start_run("antonio")
	_baseline(rc)
	for i in 8:
		# hp 25 so enemies survive several hits -> crit rolls (RNG) affect outcomes
		rc.state.enemies.append(_enemy(rc.state.player.pos + Vector2(30.0 + i * 4.0, (i - 4) * 6.0), 25.0, 0.0))

	for i in 150:
		rc._tick(0.05, _scripted_dir(i))

	return [
		rc.state.kills,
		rc.state.gold,
		rc.state.player.level,
		rc.state.pending_levelups,
		rc.state.enemies.size(),
		rc.state.gems.size(),
		rc.state.player.pos,
		snappedf(rc.state.player.xp, 0.00001),
		snappedf(rc.state.player.hp, 0.00001),
	]


func test_same_seed_produces_identical_run() -> void:
	var first := _deterministic_signature()
	var second := _deterministic_signature()
	assert_array(second).is_equal(first)


func test_seeded_run_actually_simulated() -> void:
	# Guard against a vacuous determinism pass: the scenario must really advance the
	# simulation (kills happen, time elapses), not trivially match by doing nothing.
	var rc := _run()
	rc.start_run("antonio")
	_baseline(rc)
	for i in 8:
		rc.state.enemies.append(_enemy(rc.state.player.pos + Vector2(30.0 + i * 4.0, (i - 4) * 6.0), 25.0, 0.0))
	for i in 150:
		rc._tick(0.05, _scripted_dir(i))
	assert_int(rc.state.kills).is_greater(0)
	assert_float(rc.state.time_elapsed).is_greater(0.0)
