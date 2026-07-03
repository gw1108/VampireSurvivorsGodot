## Pins the survival WIN condition: outlasting VSRun.RUN_DURATION flips the run to the
## "victory" phase exactly once, banks the run's gold into the meta purse, and cannot be
## overwritten (or re-banked) by a death signal that lands afterwards. Boots the real run
## scene so the AgentBridge autoload and full world are present.
extends GdUnitTestSuite

func test_survive_to_the_goal_wins_and_banks_gold_once() -> void:
	var runner := scene_runner("res://scenes/run.tscn")
	var run = runner.scene()
	assert_str(run.phase).is_equal("playing")

	run.gold = 7
	var before: int = MetaSave.load_coins()

	# Just short of the goal: still playing.
	run.elapsed = VSRun.RUN_DURATION - 1.0
	run._process(0.0)
	assert_str(run.phase).is_equal("playing")

	# Cross the goal: the run is won and this run's gold is banked.
	run.elapsed = VSRun.RUN_DURATION
	run._process(0.0)
	assert_str(run.phase).is_equal("victory")
	assert_int(MetaSave.load_coins()).is_equal(before + 7)

	# A death (or another frame) after victory must not re-bank or overwrite the win.
	run._process(0.0)
	run._on_player_died()
	assert_str(run.phase).is_equal("victory")
	assert_int(MetaSave.load_coins()).is_equal(before + 7)
