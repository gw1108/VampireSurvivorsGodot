## Pins VSCandelabra: a candelabra accrues weapon damage and, once its small HP pool is spent,
## shatters — freeing itself and dropping exactly ONE bonus per CANDELABRA_TABLE (run.gd). Most
## entries spawn a pickup node (Rosary/Orologion/Vacuum/Nduja/coin/food); Rerollo banks a reroll
## directly AND pops a "+1 Reroll" VSFloatText, so every shatter parents exactly one child onto
## the run — a pickup node, or that float-text pop.
## The run is a bare state bag (never added to the tree) so no world is built; drop_candelabra_bonus
## parents its drop onto that run, so counting run's children isolates it. Runs under the
## project so the AgentBridge autoload the spawn events emit on exists.
extends GdUnitTestSuite

func _state_run() -> VSRun:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	return run

## Every pickup node class VSRun.drop_candelabra_bonus can spawn, kept in sync with
## CANDELABRA_TABLE's id->node mapping. Rerollo is the one non-pickup outcome — it drops a
## VSFloatText pop and banks the reroll — so _assert_valid_drop below handles it separately.
func _is_known_pickup(drop: Node) -> bool:
	return drop is VSRosary or drop is VSMagnet or drop is VSCoin \
		or drop is VSFood or drop is VSNduja or drop is VSFrozenClock \
		or drop is VSLittleClover or drop is VSGildedClover

## A candelabra shatter drops exactly one child. It is valid iff it is either a known pickup, or
## the Rerollo outcome: a VSFloatText "+1 Reroll" pop that also incremented the run's reroll budget.
func _assert_valid_drop(run: VSRun, drop: Node, rerolls_before: int) -> void:
	if drop is VSFloatText:
		assert_int(run.rerolls_left).is_equal(rerolls_before + 1)   # Rerollo: banks the reroll
	else:
		assert_bool(_is_known_pickup(drop)).is_true()

func test_partial_hits_survive_then_final_hit_shatters_and_drops_one() -> void:
	seed(20240704)   # deterministic roll so the gate never flakes on an unlucky candelabra drop
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

	# The hit that spends the last HP shatters it and rolls exactly one bonus onto the run
	# (a pickup node, or Rerollo's "+1 Reroll" float-text pop).
	var rerolls_before := run.rerolls_left
	c.hit(2.0, c.position)
	assert_bool(c._broken).is_true()
	assert_int(run.get_child_count()).is_equal(1)
	_assert_valid_drop(run, run.get_child(0), rerolls_before)

## Deterministic audit of the ENTIRE table: level 30 makes every entry eligible, and a fixed seed
## gives reproducible coverage, so this can never itself be a source of gate flake. Every shatter
## must drop exactly one child that is either a known pickup or Rerollo's float-text pop — nothing
## else. If a new CANDELABRA_TABLE entry ever spawns a class missing from _assert_valid_drop, this
## fails deterministically instead of flaking.
func test_every_candelabra_drop_is_a_known_pickup_or_rerollo() -> void:
	seed(1337)
	for i in 800:
		var run := _state_run()
		run.level = 30
		var before := run.rerolls_left
		run.drop_candelabra_bonus(Vector2.ZERO)
		assert_int(run.get_child_count()).is_equal(1)
		_assert_valid_drop(run, run.get_child(0), before)
