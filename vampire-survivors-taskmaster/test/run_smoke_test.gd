## Boots the main run scene and drives it a few simulated seconds to prove the core
## loop is alive: the scene loads, a player exists, waves spawn, and the auto-weapon
## makes progress (kills or projectiles in flight). Doubles as the gate's real signal
## that the game still runs — not just that scripts parse.
extends GdUnitTestSuite

func test_run_boots_spawns_and_makes_progress() -> void:
	var runner := scene_runner("res://scenes/run.tscn")
	var run = runner.scene()
	assert_object(run).is_not_null()
	assert_object(run.player).is_not_null()
	# The run boots frozen on the title screen (only the live AgentBridge web harness
	# auto-starts); start it explicitly, exactly as clicking Start does, to enter play.
	run.start_run()
	assert_str(run.phase).is_equal("playing")

	# Let waves spawn and the auto-weapon work for ~6 simulated seconds.
	await runner.simulate_frames(360, 16)

	var enemies := run.get_tree().get_nodes_in_group("enemies")
	assert_int(enemies.size()).is_greater(0)

	var projectiles := run.get_tree().get_nodes_in_group("projectiles")
	var progressed: bool = run.kills > 0 or projectiles.size() > 0
	assert_bool(progressed).is_true()
