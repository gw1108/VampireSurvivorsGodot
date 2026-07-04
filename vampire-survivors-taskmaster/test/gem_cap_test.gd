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
