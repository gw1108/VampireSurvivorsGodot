## Pins VSCandelabra: a candelabra accrues weapon damage and, once its small HP pool is spent,
## shatters — freeing itself and dropping exactly ONE bonus pickup (Rosary/Magnet/coin/food).
## The run is a bare state bag (never added to the tree) so no world is built; drop_candelabra_bonus
## parents its pickup onto that run, so counting run's children isolates the drop. Runs under the
## project so the AgentBridge autoload the spawn events emit on exists.
extends GdUnitTestSuite

func _state_run() -> VSRun:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	return run

func test_partial_hits_survive_then_final_hit_shatters_and_drops_one() -> void:
	var run := _state_run()
	assert_int(run.get_child_count()).is_equal(0)   # bare state bag: no world, no drops yet

	var c := VSCandelabra.new()
	c.run = run
	add_child(c)                                     # in-tree so get_parent()/flash resolve
	auto_free(c)

	# A hit that leaves 1 HP must NOT break it.
	c.hit(VSCandelabra.HEALTH - 1.0, c.position)
	assert_bool(c._broken).is_false()
	assert_int(run.get_child_count()).is_equal(0)    # nothing dropped yet

	# The hit that spends the last HP shatters it and rolls exactly one bonus onto the run.
	c.hit(2.0, c.position)
	assert_bool(c._broken).is_true()
	assert_int(run.get_child_count()).is_equal(1)

	var drop := run.get_child(0)
	var is_pickup: bool = drop is VSRosary or drop is VSMagnet or drop is VSCoin or drop is VSFood
	assert_bool(is_pickup).is_true()
