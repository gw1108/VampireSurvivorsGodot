## Pins the survival WIN condition: reaching VSRun.RUN_DURATION summons the finale Reaper (the
## run stays "playing"), and only after outlasting it for REAPER_DURATION more seconds does the
## run flip to "victory" — exactly once, banking the run's gold into the meta purse, and it cannot
## be overwritten (or re-banked) by a death signal that lands afterwards. Boots the real run scene
## so the AgentBridge autoload and full world are present.
extends GdUnitTestSuite

func test_survive_to_the_goal_summons_reaper_then_wins_and_banks_gold_once() -> void:
	var runner := scene_runner("res://scenes/run.tscn")
	var run = runner.scene()
	assert_str(run.phase).is_equal("playing")

	run.gold = 7
	var before: int = MetaSave.load_coins()

	# Just short of the goal: still playing, no Reaper yet.
	run.elapsed = VSRun.RUN_DURATION - 1.0
	run._process(0.0)
	assert_str(run.phase).is_equal("playing")
	assert_bool(run.reaper_active).is_false()

	# Reach the goal: the Reaper is summoned and the run stays playing for the last stand.
	run.elapsed = VSRun.RUN_DURATION
	run._process(0.0)
	assert_str(run.phase).is_equal("playing")
	assert_bool(run.reaper_active).is_true()
	assert_int(MetaSave.load_coins()).is_equal(before)   # not banked until the win lands

	# Outlast the Reaper: crossing the deadline wins the run and banks this run's gold.
	run.elapsed = run.reaper_deadline
	run._process(0.0)
	assert_str(run.phase).is_equal("victory")
	assert_int(MetaSave.load_coins()).is_equal(before + 7)

	# A death (or another frame) after victory must not re-bank or overwrite the win.
	run._process(0.0)
	run._on_player_died()
	assert_str(run.phase).is_equal("victory")
	assert_int(MetaSave.load_coins()).is_equal(before + 7)
