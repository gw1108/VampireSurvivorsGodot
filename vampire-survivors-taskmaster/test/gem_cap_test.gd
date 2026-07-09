## Pins the GDD on-ground gem cap: however many gems drop, at most VSRun.MAX_GROUND_GEMS live gem
## nodes exist at once, and the total XP they carry is conserved — every drop past the cap folds
## its XP into an existing gem (absorb()) instead of spawning a node. Regression guard against a
## late-game field that out-drops the player's pickup rate ballooning into thousands of live nodes.
extends GdUnitTestSuite

func _sum_gem_xp(run) -> int:
	var total := 0
	for g in run.get_tree().get_nodes_in_group("gems"):
		total += g.value
	return total

func test_ground_gem_cap_holds_and_conserves_xp() -> void:
	var runner := scene_runner("res://scenes/run.tscn")
	var run = runner.scene()
	run.start_run()
	assert_str(run.phase).is_equal("playing")

	var cap: int = VSRun.MAX_GROUND_GEMS
	var before_xp := _sum_gem_xp(run)

	# Drop far more gems than the cap, all well outside the player's magnet radius (player starts
	# near the origin) and without simulating frames, so none are collected — every drop past the
	# cap must merge into an existing gem, never add a node.
	var injected := 0
	for i in range(cap + 250):
		var at := Vector2(1200.0 + float(i % 40) * 20.0, -600.0 + float(i) * 3.0)
		run._spawn_gem(at, 1)
		injected += 1

	# Node count holds at the cap (we overshot it well past), and no XP was lost or double-counted.
	assert_int(run.get_tree().get_nodes_in_group("gems").size()).is_equal(cap)
	assert_int(_sum_gem_xp(run)).is_equal(before_xp + injected)

## Wiki rule at the cap: excess XP folds into a single RED gem — the on-screen gem furthest from the
## player — while one unreachable OFF-screen gem is drained into that same accumulator. Pins the
## on/off-screen split, the red accumulator flag, and XP conservation across the consolidation.
func test_over_cap_drop_folds_into_furthest_onscreen_red_gem_and_drains_offscreen() -> void:
	var runner := scene_runner("res://scenes/run.tscn")
	var run = runner.scene()
	run.start_run()
	assert_str(run.phase).is_equal("playing")

	var cap: int = VSRun.MAX_GROUND_GEMS
	var here: Vector2 = run.player.position

	# Fill the field to exactly the cap with on-screen gems near the player plus two off-screen ones,
	# all placed as nodes because each drop lands while the count is still below the cap.
	var near: int = cap - 2
	for i in range(near):
		# Fan the on-screen gems out to distinct short distances so one is unambiguously "furthest".
		run._spawn_gem(here + Vector2(8.0 + float(i % 40), 4.0 + float(i % 30)), 1)
	run._spawn_gem(here + Vector2(3000.0, 0.0), 1)     # off-screen
	run._spawn_gem(here + Vector2(0.0, -3200.0), 1)    # off-screen
	assert_int(run.get_tree().get_nodes_in_group("gems").size()).is_equal(cap)
	var before_xp := _sum_gem_xp(run)

	# One more drop: over the cap, so it must fold (no new node) and drain one off-screen gem.
	run._spawn_gem(here + Vector2(5.0, 5.0), 5)

	# One off-screen gem was consolidated out of the group; XP is conserved (the drained gem's value
	# plus the +5 drop both landed in the accumulator).
	var gems := run.get_tree().get_nodes_in_group("gems")
	assert_int(gems.size()).is_equal(cap - 1)
	assert_int(_sum_gem_xp(run)).is_equal(before_xp + 5)

	# Exactly one accumulator gem exists, it is on screen (near the player, not at a 3000px offset),
	# and it carries the folded reward (its original 1 + the drained off-screen 1 + the 5 drop = 7).
	var accumulators := []
	for g in gems:
		if g.is_accumulator:
			accumulators.append(g)
	assert_int(accumulators.size()).is_equal(1)
	var acc = accumulators[0]
	assert_int(acc.value).is_equal(7)
	assert_bool(acc.position.distance_to(here) < 500.0).is_true()
