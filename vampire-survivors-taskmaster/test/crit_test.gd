## Pins VSRun.roll_crit: with no Luck bonus a hit NEVER crits (damage is untouched, which keeps
## the other weapons' damage-assertion tests deterministic), and stacking Luck makes crits fire
## at exactly CRIT_MULTIPLIER x. Regression guard for the crit combat rule.
extends GdUnitTestSuite

func test_no_luck_never_crits() -> void:
	var run := VSRun.new()
	auto_free(run)
	run.luck_bonus = 0.0
	for i in range(500):
		var r: Dictionary = run.roll_crit(10.0)
		assert_bool(r["crit"]).is_false()
		assert_float(r["amount"]).is_equal(10.0)

func test_luck_produces_double_damage_crits() -> void:
	var run := VSRun.new()
	auto_free(run)
	run.luck_bonus = 200.0                 # chance = min(200*0.005, 0.75) = 0.75
	var crits := 0
	for i in range(2000):
		var r: Dictionary = run.roll_crit(10.0)
		if r["crit"]:
			crits += 1
			assert_float(r["amount"]).is_equal(20.0)   # exactly CRIT_MULTIPLIER x
		else:
			assert_float(r["amount"]).is_equal(10.0)
	# ~75% expected; assert a broad band so the test isn't RNG-flaky (~15 sigma of headroom).
	assert_int(crits).is_between(1200, 1600)
