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

	# Give the smoke run a deterministic auto-attack. Antonio's real starting loadout is
	# melee-only (the level-1 Whip is directional — a ±50° wedge on the facing side — and with
	# no input in the sim it only lashes right, so whether a randomly-placed bat is struck is
	# RNG-dependent and flaky for a gate). Enabling the Magic Wand (weapon_count>0) makes it
	# aim at the nearest enemy within its 620px range every fire interval; since bats spawn at
	# SPAWN_RING=520px an enemy is always in range, so a projectile fires reliably — a stable
	# signal that the "you move, the weapon fights" loop is alive.
	run.weapon_count = 1

	# Let waves spawn and the auto-weapon work for a few simulated seconds.
	await runner.simulate_frames(500, 16)

	var enemies := run.get_tree().get_nodes_in_group("enemies")
	assert_int(enemies.size()).is_greater(0)

	# Progress = the auto-weapon worked. Count a projectile in flight (the wand fired), a kill,
	# OR any enemy that has taken damage (the whip also swings) — any one proves the loop is
	# alive without hinging on a precise one-shot-kill window.
	var projectiles := run.get_tree().get_nodes_in_group("projectiles")
	var enemy_damaged := false
	for e in enemies:
		# The "enemies" group also holds destructible props (VSCandelabra) that carry health
		# but no max_health — guard the access so the damage check never crashes on scenery.
		if "max_health" in e and e.health < e.max_health:
			enemy_damaged = true
			break
	var progressed: bool = run.kills > 0 or projectiles.size() > 0 or enemy_damaged
	assert_bool(progressed).is_true()
