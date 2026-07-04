## Pins the new Luck stat + Gilded Clover / Little Clover pickups (Luck.md, Gilded_Clover.md,
## Little_Clover.md): Little Clover stacks +10% Luck with no cap and scales candelabra weight
## for "Yes" luck-scaled entries only; Gilded Clover banks every on-screen coin and starts a
## Gold Fever. The run is a bare state bag (never added to the tree) so no world is built.
extends GdUnitTestSuite

func _state_run() -> VSRun:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	return run

func test_little_clover_stacks_luck_with_no_cap() -> void:
	var run := _state_run()
	assert_float(run.total_luck()).is_equal(100.0)

	for i in 5:
		var lc := VSLittleClover.new()
		lc.run = run
		add_child(lc)
		auto_free(lc)
		lc._collect()

	assert_float(run.luck_bonus).is_equal(50.0)
	assert_float(run.total_luck()).is_equal(150.0)

func test_candelabra_weight_scales_luck_entries_but_not_flat_ones() -> void:
	var run := _state_run()
	var luck_entry := {"weight": 10.0, "luck_scaled": true}
	var flat_entry := {"weight": 10.0, "luck_scaled": false}
	assert_float(run._candelabra_weight(luck_entry)).is_equal(10.0)
	assert_float(run._candelabra_weight(flat_entry)).is_equal(10.0)

	run.luck_bonus = 30.0   # total_luck() -> 130
	assert_float(run._candelabra_weight(luck_entry)).is_equal(13.0)
	assert_float(run._candelabra_weight(flat_entry)).is_equal(10.0)

func test_gilded_clover_collects_screen_gold_and_starts_gold_fever() -> void:
	var run := _state_run()
	run.elapsed = 5.0
	assert_bool(run.is_gold_fever_active()).is_false()

	var c1 := VSCoin.new()
	c1.run = run
	c1.value = 10
	add_child(c1)
	auto_free(c1)
	var c2 := VSCoin.new()
	c2.run = run
	c2.value = 5
	add_child(c2)
	auto_free(c2)

	var gilded := VSGildedClover.new()
	gilded.run = run
	add_child(gilded)
	auto_free(gilded)
	gilded._collect()
	await await_idle_frame()   # queue_free() on the coins only actually frees at idle time

	assert_int(run.gold).is_equal(15)
	assert_bool(is_instance_valid(c1)).is_false()
	assert_bool(is_instance_valid(c2)).is_false()
	assert_bool(run.is_gold_fever_active()).is_true()
	assert_float(run.gold_fever_until).is_equal(run.elapsed + VSRun.GOLD_FEVER_DURATION)
