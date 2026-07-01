## Boots the main run scene and drives it a few simulated seconds to prove the core
## loop is alive: the scene loads, a player exists, waves spawn, and the auto-weapon
## makes progress (kills, or the Whip is swinging). Doubles as the gate's real signal
## that the game still runs — not just that scripts parse.
extends GdUnitTestSuite

func test_run_boots_spawns_and_makes_progress() -> void:
	var runner := scene_runner("res://scenes/run.tscn")
	var run = runner.scene()
	assert_object(run).is_not_null()
	assert_object(run.player).is_not_null()
	assert_str(run.phase).is_equal("playing")

	# Let waves spawn and the auto-weapon work for ~6 simulated seconds.
	await runner.simulate_frames(360, 16)

	var enemies := run.get_tree().get_nodes_in_group("enemies")
	assert_int(enemies.size()).is_greater(0)

	# The starter is now the Whip — a short-range melee slash with no projectiles — so the
	# "auto-weapon is alive" signal is its swing counter rather than projectiles in flight.
	# (Enemies spawn ~520px out and the whip reaches ~130px, so kills aren't guaranteed in
	# this short window; a swinging weapon is the robust, weapon-agnostic progress signal.)
	var swings: int = run.weapon.fire_count if run.weapon else 0
	var progressed: bool = run.kills > 0 or swings > 0
	assert_bool(progressed).is_true()
