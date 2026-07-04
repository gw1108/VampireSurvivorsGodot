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

	# Let waves spawn and the auto-weapon work for ~8 simulated seconds. Antonio's starting
	# loadout is melee-only (the level-1 Whip, 140px reach; the Magic Wand is pick-only), and
	# bats spawn at SPAWN_RING=520px closing at 62px/s — they don't enter whip range until ~6s,
	# so 6s left the loop with nothing struck. 8s (500 frames) gives the nearest bats time to
	# march into the lash.
	await runner.simulate_frames(500, 16)

	var enemies := run.get_tree().get_nodes_in_group("enemies")
	assert_int(enemies.size()).is_greater(0)

	# Progress = the auto-weapon connected. Count a kill, a projectile in flight, OR any enemy
	# that has taken damage (health below its max) — the last proves the whip swung and landed
	# without hinging on a precise one-shot-kill window.
	var projectiles := run.get_tree().get_nodes_in_group("projectiles")
	var enemy_damaged := false
	for e in enemies:
		if e.health < e.max_health:
			enemy_damaged = true
			break
	var progressed: bool = run.kills > 0 or projectiles.size() > 0 or enemy_damaged
	assert_bool(progressed).is_true()
