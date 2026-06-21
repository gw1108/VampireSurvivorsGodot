extends GdUnitTestSuite

## Performance / scale guard for the simulation pipeline. Builds the task's stress
## scenario (500 enemies + 200 gems + 50 projectiles) and drives the REAL
## RunController._tick pipeline, asserting two things:
##
##   1. it survives at scale within a generous per-tick wall-clock budget, and
##   2. it scales SUB-QUADRATICALLY in enemy count (the task's explicit
##      "SpatialIndex.rebuild - ensure O(n) not O(n^2)" requirement).
##
## The absolute-time ceiling is deliberately loose (machine/CI dependent); the
## scaling-ratio assertion is the robust, machine-independent regression signal:
## 4x the enemies must cost well under the ~16x a quadratic pipeline would incur.
##
## Audit conclusion behind this test (see also the progress notes): the pipeline
## is already O(n) per tick by design — uniform spatial-hash broadphase, swap-remove
## everywhere (no Array.erase), pooled presentation sprites — so no algorithmic
## change was required; this suite pins those properties against regressions.

const SEED: int = 13579

# Loose smoke ceiling for the full stress scene (ms/tick). Not the 8ms target
# (which a headless dev box clears comfortably) — just a catastrophic-regression net.
const TICK_BUDGET_MS: float = 50.0


func _run() -> RunController:
	return auto_free(RunController.new())


func _shared_enemy_def() -> EnemyDef:
	var d := EnemyDef.new()
	d.id = "bat"
	d.power = 5.0
	d.speed = 140.0
	d.xp_value = 1.0
	return d


func _ring(rng: RandomNumberGenerator, min_r: float, max_r: float) -> Vector2:
	var a: float = rng.randf() * TAU
	var dist: float = rng.randf_range(min_r, max_r)
	return Vector2(cos(a), sin(a)) * dist


## Build a stable stress population around the player. Enemies are effectively
## unkillable and spawned beyond contact reach, gems sit past magnet range, and
## projectiles fly in an empty far region — so counts stay constant across the
## measurement window and the timing reflects steady-state pipeline cost, not a
## decaying board.
func _populate(rc: RunController, n_enemies: int, n_gems: int, n_projectiles: int) -> void:
	var p: Vector2 = rc.state.player.pos
	var rng: RandomNumberGenerator = rc.state.rng
	var def := _shared_enemy_def()  # shared read-only def is fine
	rc.state.player.hp = 1.0e9  # never dies during the window -> phase stays PLAYING

	for i in n_enemies:
		var e := Enemy.new()
		e.hp = 1.0e9  # survive the window so the population is constant
		e.def = def
		e.pos = p + _ring(rng, 250.0, 700.0)  # beyond the ~16px contact hitbox
		rc.state.enemies.append(e)

	for i in n_gems:
		var g := Gem.new()
		g.xp = 1.0
		g.tier = Gem.Tier.BLUE
		g.pos = p + _ring(rng, 1000.0, 1400.0)  # past magnet range -> not collected/moved
		rc.state.gems.append(g)

	for i in n_projectiles:
		var pr := Projectile.new()
		pr.pos = p + _ring(rng, 2000.0, 2400.0)  # empty region -> query cost without combat noise
		pr.velocity = _ring(rng, 1.0, 1.0) * 50.0
		pr.damage = 10.0
		pr.pierce_left = 1_000_000  # never exhausts -> count stays constant
		pr.lifetime = 1.0e6
		rc.state.projectiles.append(pr)


func _fresh_scene(n_enemies: int, n_gems: int, n_projectiles: int) -> RunController:
	var rc := _run()
	rc.start_run("antonio")
	# Drop the time-seeded starting spawns; rebuild a deterministic, fixed population.
	rc.state.enemies.clear()
	rc.state.gems.clear()
	rc.state.projectiles.clear()
	rc.state.rng.seed = SEED
	_populate(rc, n_enemies, n_gems, n_projectiles)
	return rc


## Average microseconds per _tick over `ticks`, after a short warm-up.
func _avg_tick_usec(rc: RunController, ticks: int) -> float:
	for w in 5:  # warm-up (def loads, first-touch costs)
		rc._tick(1.0 / 60.0, Vector2.RIGHT)
	var t0: int = Time.get_ticks_usec()
	for i in ticks:
		rc._tick(1.0 / 60.0, Vector2.RIGHT)
	var t1: int = Time.get_ticks_usec()
	return float(t1 - t0) / float(ticks)


# --- scale smoke + budget ---

func test_full_stress_scene_runs_within_budget() -> void:
	var rc := _fresh_scene(500, 200, 50)
	var avg_us := _avg_tick_usec(rc, 120)
	var avg_ms := avg_us / 1000.0
	prints("[perf] 500 enemies + 200 gems + 50 projectiles: %.3f ms/tick" % avg_ms)

	# Population stayed at scale (no crash, no decay, phase still PLAYING).
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_int(rc.state.enemies.size()).is_equal(500)
	assert_int(rc.state.projectiles.size()).is_equal(50)
	assert_float(avg_ms).is_less(TICK_BUDGET_MS)


# --- the real signal: sub-quadratic scaling in enemy count ---

func test_pipeline_scales_sub_quadratically() -> void:
	# Same gems/projectiles; only enemy count varies (150 -> 600, a 4x step).
	var small := _fresh_scene(150, 200, 50)
	var large := _fresh_scene(600, 200, 50)

	var t_small := _avg_tick_usec(small, 120)
	var t_large := _avg_tick_usec(large, 120)
	var ratio := t_large / maxf(t_small, 0.001)
	prints("[perf] scaling 150->600 enemies: %.3f -> %.3f us/tick (ratio %.2fx for 4x N)"
		% [t_small, t_large, ratio])

	# Linear would be ~4x; quadratic ~16x. A ceiling of 8x cleanly separates the two
	# while tolerating measurement noise and fixed per-tick overhead.
	assert_float(ratio).is_less(8.0)
