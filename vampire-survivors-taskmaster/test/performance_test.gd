## Performance regression pin for the late-game crush: boots the real run scene, packs the
## worst-case dense horde (VSSpawner.COLLIDER_SAFE_CAP enemies collapsed into a tight ball on the
## player) plus the on-ground gem cap (VSRun.MAX_GROUND_GEMS gems on screen), then measures the
## per-frame CPU cost of simulating that field and asserts it stays inside the 60fps frame budget.
##
## Why this is the right worst case: prior profiling (see completions) proved late-game FPS is
## DENSITY-driven, not raw-count-driven — a spread-out field is cheap, but when the horde collapses
## into a handful of 60px COLLIDE_CELL cells each enemy's 3×3 overlap scan can revert toward O(n²).
## VSEnemy.MAX_OVERLAP_CHECKS bounds that scan; this test pins that it stays bounded. If the grid /
## cap regresses, the packed-crush sim cost roughly doubles and blows past the budget here.
##
## What we assert on: the PURE entity-simulation sweep (one _process pass over every live enemy +
## gem) — the actual CPU work that gates whether the logic keeps up at 60fps, and the exact term the
## O(n²) blowup lives in. We deliberately do NOT assert on the gdUnit `simulate_frames` wall-clock
## (printed for context only): it carries per-call harness/await overhead that swings 12–20ms
## run-to-run independent of the game and would make the gate flaky. The real shipping FPS was
## separately verified in a Web-export run (~78fps at the ~274-body crush; see completions) — the
## faithful render path this headless proxy can't reproduce — so this test guards the algorithm, not
## the exact frame rate.
extends GdUnitTestSuite

## 60fps budget: a frame must simulate in under 1000/60 ms to hold 60fps.
const FRAME_BUDGET_MS := 1000.0 / 60.0
## Enemies packed onto the player — the validated late-game ceiling (the real Mad Forest 300-alive cap).
const HORDE := VSSpawner.COLLIDER_SAFE_CAP
## Loose gems on the ground at once — the GDD on-ground cap.
const GEMS := VSRun.MAX_GROUND_GEMS
const WARMUP_FRAMES := 24    # let the packed ball collapse into the steady crush wall before timing
const SAMPLE_FRAMES := 40    # timed frames; the MEDIAN is the "typical FPS" the player sees

func _median(values: Array) -> float:
	values.sort()
	var n := values.size()
	if n == 0:
		return 0.0
	if n % 2 == 1:
		return values[n / 2]
	return (values[n / 2 - 1] + values[n / 2]) * 0.5

func test_packed_crush_holds_60fps() -> void:
	var runner := scene_runner("res://scenes/run.tscn")
	var run = runner.scene()
	run.start_run()
	assert_str(run.phase).is_equal("playing")

	# Keep the field stable for the whole measurement: the player can't die (so the sim never flips
	# to game_over and short-circuits every enemy _process), and the injected enemies can't be killed
	# by the starting whip inside the sample window — both would thin the horde and understate the cost.
	run.player.invulnerable = true
	var center: Vector2 = run.player.position

	# Pack the worst-case DENSE crush: HORDE enemies dropped in a tight ball on the player so their
	# bodies fully interpenetrate and collapse into the same few grid cells — the density case the
	# overlap-scan cap exists to keep linear. Deterministic (fixed seed) so the packing never flakes.
	seed(0xC0FFEE)
	for i in range(HORDE):
		var e := VSEnemy.new()
		e.type = VSEnemy.Type.BAT
		# A ~120px disc around the player: many bodies per 60px cell, the collapsed-crush worst case.
		var ang := randf() * TAU
		var r := sqrt(randf()) * 120.0
		e.position = center + Vector2(cos(ang), sin(ang)) * r
		e.run = run
		e.target = run.player
		run.add_child(e)
		# _ready ran on add_child and set BAT's 3 HP; make it effectively unkillable for the window.
		e.health = 1.0e9
		e.max_health = 1.0e9

	# Fill the ground to the gem cap, out past the magnet radius so none get vacuumed up mid-sample
	# (which would drop the node count). Their per-frame magnet _process is still exercised.
	for i in range(GEMS):
		var a := TAU * float(i) / float(GEMS)
		var rr := 220.0 + float(i % 5) * 40.0   # 220–380px ring: on screen, well beyond the 95px magnet
		run._spawn_gem(center + Vector2(cos(a), sin(a)) * rr, 1)

	# Let the ball collapse into the steady crush before timing.
	await runner.simulate_frames(WARMUP_FRAMES, 16)

	var enemy_count: int = run.get_tree().get_nodes_in_group("enemies").size()
	var gem_count: int = run.get_tree().get_nodes_in_group("gems").size()
	# Confirm we actually measured the intended load (guards against the whip/pickups quietly
	# emptying the field, which would make a "pass" meaningless).
	assert_int(enemy_count).is_greater_equal(HORDE)
	assert_int(gem_count).is_equal(GEMS)

	# Sample the two costs per frame: (1) the gdUnit full-frame wall-clock (context/print only, noisy),
	# and (2) the pure entity-sim sweep — one _process pass over every live enemy + gem, the real
	# per-frame CPU work. Advancing a real engine frame each iteration bumps Engine.get_process_frames,
	# so the first enemy in each sweep rebuilds the shared collision grid exactly as a live frame does.
	var frame_samples: Array = []
	var ent_samples: Array = []
	for i in range(SAMPLE_FRAMES):
		var t0 := Time.get_ticks_usec()
		await runner.simulate_frames(1, 16)
		frame_samples.append(float(Time.get_ticks_usec() - t0) / 1000.0)   # ms
		var te := Time.get_ticks_usec()
		for e in run.get_tree().get_nodes_in_group("enemies"):
			if e is VSEnemy:
				e._process(1.0 / 60.0)
		for g in run.get_tree().get_nodes_in_group("gems"):
			g._process(1.0 / 60.0)
		ent_samples.append(float(Time.get_ticks_usec() - te) / 1000.0)

	var ent_median := _median(ent_samples)
	var frame_median := _median(frame_samples)
	print("[perf] packed crush: %d enemies + %d gems (budget %.2f ms / 60fps)" % [enemy_count, gem_count, FRAME_BUDGET_MS])
	print("[perf]   pure entity-sim sweep ms min/median/max = %.2f / %.2f / %.2f  (~%.0f fps)" % [
		ent_samples.min(), ent_median, ent_samples.max(), 1000.0 / maxf(ent_median, 0.0001)])
	print("[perf]   full-frame wall-clock ms min/median/max = %.2f / %.2f / %.2f  (context only, harness overhead)" % [
		frame_samples.min(), frame_median, frame_samples.max()])

	# The core assertion: the typical (median) pure-sim frame cost stays inside the 60fps budget. Now
	# ~9ms (~1.9x headroom); if a future change reverts the packed-density collision to super-linear
	# this roughly doubles and crosses the budget — the signal to open an "improve FPS" workshop task.
	assert_float(ent_median).is_less(FRAME_BUDGET_MS)
