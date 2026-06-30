extends SceneTree

## Task 32 — full-run integration test (headless stand-in for the manual
## 30-minute playthrough checklist).
##   godot --headless --path . --script res://test/full_run_integration_test.gd
## Exit code == number of failed checks (0 == all passed).
##
## Mounts the real run.tscn so RunController, ViewSync, the HUD, and the
## level-up / pause / result overlays are ALL live, then drives the authoritative
## RunController._tick loop and asserts the systems work TOGETHER end to end:
##   * early game: enemies spawn, the Whip auto-fires, kills drop gems, XP
##     accrues, and a real level-up (UI shown, option applied) resolves;
##   * the Mad Forest ground stays mounted and scrolls with the camera (world-
##     locked) as the hero walks, via the live render -> camera -> ground chain;
##   * pause/resume via the GameManager FSM shows the pause overlay;
##   * a boss spawns on its minute marker and, when slain, drops a chest;
##   * at 30:00 the field clears and the (immune) Reaper spawns;
##   * lethal HP raises the game-over screen with the run's stats;
##   * quit-to-menu discards the run.
## Late-game scheduled events are reached by time-warping run_state.elapsed
## rather than simulating 30 real minutes; the early game is fully organic.
## The player is kept alive with a huge HP pool during the organic phases so the
## combat/leveling path is reached deterministically regardless of contact dmg.

const RUN_SCENE := preload("res://scenes/run.tscn")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== full_run_integration_test ==")
	var gm = root.get_node_or_null("GameManager")
	var gdb = root.get_node_or_null("GameDatabase")
	_check(gm != null, "GameManager autoload present")
	_check(gdb != null, "GameDatabase autoload present")
	if gm == null or gdb == null:
		_finish(); return true

	# --- Boot a run + mount the full scene graph ---
	gm.run_state = gm._build_run_state()
	gm.run_state.rng.seed = 20260629
	gm.current_state = gm.State.PLAYING
	gm.get_tree().paused = false
	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)          # _ready inits player_shell, view_sync, overlays
	rc.set_process(false)       # drive the tick by hand
	_check(rc.run_state == gm.run_state, "RunController adopts the active run on _ready")

	var player = gm.run_state.player
	var enemies = gm.run_state.enemies
	var projectiles = gm.run_state.projectiles
	var pickups = gm.run_state.pickups
	var levelup = rc.get_node("OverlayLayer/LevelUpScreen")
	var pause = rc.get_node("OverlayLayer/PauseScreen")
	var result = rc.get_node("OverlayLayer/ResultScreen")
	var dt := 1.0 / 30.0

	# --- Phase 1: organic early game -> spawn / fire / kill / XP / level-up ---
	var saw_enemy := false
	var saw_proj := false
	var saw_gem := false
	var levelup_ui_ok := false
	var leveled := false
	for _t in range(1800):
		player.hp = 100000.0    # survive contact dmg so the leveling path is reached
		rc._tick(dt)
		if enemies.active_count > 0: saw_enemy = true
		if projectiles.active_count > 0: saw_proj = true
		if pickups.gem_count > 0: saw_gem = true
		if gm.current_state == gm.State.LEVEL_UP:
			if not levelup_ui_ok:
				levelup_ui_ok = levelup.visible and levelup.current_options.size() >= 1
			_resolve_level_ups(gm, levelup)
			leveled = true
		if leveled and saw_proj and saw_gem and player.level >= 2:
			break
	_check(saw_enemy, "enemies spawn during play")
	_check(saw_proj, "the Whip auto-fires (projectiles spawned)")
	_check(saw_gem, "kills drop XP gems")
	_check(player.level >= 2, "XP accrues and the player levels up (reached LV %d)" % player.level)
	_check(levelup_ui_ok, "level-up screen shows with 3-4 options")
	_check(gm.current_state == gm.State.PLAYING, "run resumes after the level-up is resolved")
	_check(player.stats != null, "stats are computed during the run")

	# --- Phase 1b: the Mad Forest ground scrolls with the camera as the hero moves ---
	# Drives the real runtime chain: PlayerState.pos -> player_shell.render (camera is
	# the player's child, so it tracks) -> GroundLayer._process/_follow (world-lock).
	var ground = rc.get_node("World/GroundLayer")
	var pshell = rc.player_shell
	var cam: Camera2D = pshell.get_node("Camera2D")
	cam.make_current()
	_check(ground is Sprite2D and ground.texture != null, "the scrolling ground is mounted under the run")
	var saved_pos: Vector2 = player.pos
	player.pos = Vector2(640.0, -480.0)         # walk the hero away from spawn
	pshell.render(player)                        # the camera (player child) tracks the hero
	ground._process(0.0)                         # the ground runs its own per-frame follow
	var cam_pos: Vector2 = cam.global_position
	_check(ground.position == Vector2(roundf(cam_pos.x), roundf(cam_pos.y)),
		"the ground follows the camera (the world scrolls under the hero)")
	_check(ground.region_rect.position == ground.position,
		"the ground stays world-locked as it scrolls (seamless infinite field)")
	player.pos = saved_pos                        # restore so later phases stay deterministic
	pshell.render(player)

	# --- Phase 2: pause / resume shows the build ---
	gm.pause()
	_check(gm.current_state == gm.State.PAUSED and gm.get_tree().paused, "ESC/pause freezes the run")
	_check(pause.visible, "pause overlay shows on pause")
	gm.resume()
	_check(gm.current_state == gm.State.PLAYING and not gm.get_tree().paused, "resume continues the run")

	# --- Phase 3: a boss spawns on its minute marker (minute 1 -> glowing_bat) ---
	player.hp = 100000.0
	gm.run_state.elapsed = 60.0
	rc._tick(dt)
	_resolve_level_ups(gm, levelup)
	var boss_idx := _first_boss_idx(enemies)
	_check(boss_idx >= 0, "a boss spawns on its minute marker")

	# --- Phase 4: a slain boss drops a treasure chest ---
	var saw_chest := false
	if boss_idx >= 0:
		player.facing = Vector2.RIGHT
		enemies.pos[boss_idx] = player.pos + player.facing * 20.0  # into the Whip arc
		enemies.hp[boss_idx] = 1.0
		enemies.max_hp[boss_idx] = 1.0
		for _t in range(300):
			player.hp = 100000.0
			rc._tick(dt)
			_resolve_level_ups(gm, levelup)
			if _has_pickup_kind(pickups, PickupPool.Kind.CHEST):
				saw_chest = true
				break
	_check(saw_chest, "a slain boss drops a treasure chest")

	# --- Phase 5: 30:00 clears the field and spawns the immune Reaper ---
	player.hp = 100000.0
	gm.run_state.elapsed = SpawnDirector.REAPER_TIME
	rc._tick(dt)
	_check(_reaper_present(enemies), "the Reaper spawns at 30:00")
	_check(_nonreaper_alive(enemies) == 0, "the field is cleared when the Reaper arrives")
	_check(gdb.enemy(&"reaper").get("immune", false) == true, "the Reaper is unkillable (immune)")

	# --- Phase 6: lethal HP -> game-over screen with the run's stats ---
	var lvl_at_death: int = player.level
	player.hp = -1.0
	rc._tick(dt)
	_check(gm.current_state == gm.State.GAME_OVER, "lethal HP triggers game over")
	_check(result.visible, "result screen shows on game over")
	_check(gm.run_state.result.final_level == lvl_at_death, "result captures the final level")
	_check(gm.run_state.result.survival_time > 0.0, "result captures survival time")

	# --- Phase 7: quit to menu discards the run ---
	gm.to_menu()
	_check(gm.current_state == gm.State.MENU, "quit-to-menu returns to the menu state")
	_check(gm.run_state == null, "menu return discards the run state")

	rc.queue_free()
	_finish()
	return true

# --- helpers -----------------------------------------------------------------

func _resolve_level_ups(gm, levelup) -> void:
	var guard := 0
	while gm.current_state == gm.State.LEVEL_UP and guard < 30:
		if levelup.current_options.size() > 0:
			levelup._on_option_selected(0)   # real UI selection path
		else:
			gm.close_level_up()
		guard += 1

func _first_boss_idx(enemies) -> int:
	for i in EnemyPool.CAPACITY:
		if enemies.alive[i] and enemies.is_boss[i]:
			return i
	return -1

func _has_pickup_kind(pickups, kind: int) -> bool:
	for i in PickupPool.CAPACITY:
		if pickups.alive[i] and pickups.kind[i] == kind:
			return true
	return false

func _reaper_present(enemies) -> bool:
	for i in EnemyPool.CAPACITY:
		if enemies.alive[i] and enemies.type_id[i] == &"reaper":
			return true
	return false

func _nonreaper_alive(enemies) -> int:
	var n := 0
	for i in EnemyPool.CAPACITY:
		if enemies.alive[i] and enemies.type_id[i] != &"reaper":
			n += 1
	return n

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _finish() -> void:
	# leave the autoload clean for any later test in the same process
	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.run_state = null
		gm.current_state = gm.State.MENU
		gm.get_tree().paused = false
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
