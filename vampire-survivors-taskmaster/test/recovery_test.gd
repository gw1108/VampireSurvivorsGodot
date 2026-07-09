## Regression test for the Recovery (Pummarola) passive: a "recovery" level-up pick regenerates
## HP over time while playing. Pins the wiki numbers (+0.2 HP/s per level, additive) and the two
## guards the regen tick carries — it never overheals past max_health, and a dead player never
## heals. See VSRun.recovery / VSRun._process and the "recovery" UPGRADE_POOL entry.
extends GdUnitTestSuite

func test_recovery_starts_at_zero() -> void:
	var run := VSRun.new()
	auto_free(run)
	assert_float(run.recovery).is_equal_approx(0.0, 0.001)

func test_each_pick_adds_the_wiki_rate() -> void:
	var run := VSRun.new()
	auto_free(run)
	run._apply_upgrade("recovery")
	assert_float(run.recovery).is_equal_approx(0.2, 0.001)   # +0.2 HP/s per level (Pummarola)
	run._apply_upgrade("recovery")
	assert_float(run.recovery).is_equal_approx(0.4, 0.001)   # additive stacking

func test_recovery_regenerates_hp_over_time_capped_at_max() -> void:
	var run := VSRun.new()
	auto_free(run)
	var p := VSPlayer.new()
	add_child(p)
	auto_free(p)
	run.player = p
	p.max_health = 100.0
	p.health = 50.0
	run.recovery = 0.4
	run.phase = "playing"
	var before := p.health
	var t := 0.0
	while t < 1.0:
		run._process(1.0 / 60.0)   # one simulated second of play
		t += 1.0 / 60.0
	assert_float(p.health - before).is_equal_approx(0.4, 0.03)   # ~0.4 HP healed in 1s
	# Overheal guard: at full HP a big tick adds nothing past the cap.
	p.health = p.max_health
	run._process(10.0)
	assert_float(p.health).is_equal_approx(p.max_health, 0.001)

func test_dead_player_does_not_regenerate() -> void:
	var run := VSRun.new()
	auto_free(run)
	var p := VSPlayer.new()
	add_child(p)
	auto_free(p)
	run.player = p
	p.max_health = 100.0
	p.health = 50.0
	p.alive = false
	run.recovery = 1.0
	run.phase = "playing"
	run._process(1.0)
	assert_float(p.health).is_equal_approx(50.0, 0.001)
