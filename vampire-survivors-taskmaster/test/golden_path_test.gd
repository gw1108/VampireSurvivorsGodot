extends GdUnitTestSuite

## THE canonical golden-path test: one full run lifecycle driven through the real
## RunController per-tick pipeline (stats -> movement -> spawning -> spatial index
## -> weapons -> combat -> pickups -> health -> progression), exactly as the live
## game drives it via _physics_process. Per-system behaviour has dedicated unit
## suites; this asserts the systems compose into a playable run end-to-end:
##
##   start a run from a real character def -> player moves -> the whip kills
##   enemies -> XP gems drop, magnetize and are collected -> the player levels up
##   and an offer is surfaced -> a choice resumes play -> death ends the run with
##   a results summary.
##
## A small cluster of weak enemies is injected next to the player so the emergent
## combat/XP chain fires deterministically and fast, while every tick still flows
## through the genuine RunController._tick pipeline (no system is stubbed).


func _controller() -> RunController:
	return auto_free(RunController.new())


## A bat-equivalent enemy (1 HP, dies to a single whip slash, drops 1 XP).
func _weak_enemy(pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.pos = pos
	e.hp = 1.0
	var d := EnemyDef.new()
	d.id = "bat"
	d.power = 5.0
	d.speed = 140.0
	d.xp_value = 1.0
	e.def = d
	return e


func test_golden_path_full_run() -> void:
	var rc := _controller()
	var phases: Array = []
	var offers: Array = []
	var summaries: Array = []
	rc.phase_changed.connect(func(p): phases.append(p))
	rc.level_up_started.connect(func(o): offers.append(o))
	rc.run_ended.connect(func(s): summaries.append(s))

	# --- 1. Start the run: state is built from Antonio's real character def ---
	rc.start_run("antonio")
	assert_object(rc.state).is_not_null()
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_array(phases).contains([GameState.Phase.PLAYING])
	assert_object(rc.state.player.character_def).is_not_null()
	assert_float(rc.state.player.hp).is_equal(120.0)              # Antonio: +20 max HP, full
	assert_int(rc.state.player.weapons.size()).is_equal(1)        # starting weapon
	assert_str(rc.state.player.weapons[0].def.id).is_equal("whip")
	assert_int(rc.state.enemies.size()).is_greater(0)             # starting spawn burst

	# Pin the RNG so the rest of the run is deterministic.
	rc.state.rng.seed = 424242

	# --- 2. Inject a cluster of weak enemies inside the whip's reach ---
	# Placed to the player's right (default facing) so the first whip cast sweeps
	# them. Everything from here runs through the real _tick pipeline.
	var cluster := 6
	for i in cluster:
		rc.state.enemies.append(_weak_enemy(rc.state.player.pos + Vector2(40.0, 0.0)))

	# --- 3. Drive the simulation until progression fires a level-up ---
	# The whip kills the cluster, gems drop, magnetize toward the player, are
	# collected into XP, and crossing the L2 threshold queues a level-up that the
	# tick's phase resolution turns into a LEVEL_UP transition + offer.
	var guard := 0
	while rc.state.phase == GameState.Phase.PLAYING and guard < 600:
		rc._tick(0.05, Vector2.ZERO)
		guard += 1

	assert_int(rc.state.phase).is_equal(GameState.Phase.LEVEL_UP)  # progression drove the transition
	assert_int(rc.state.kills).is_greater(0)                       # combat resolved kills
	assert_bool(rc.state.player.level >= 2).is_true()             # collected XP leveled the player
	assert_int(offers.size()).is_greater(0)                       # offer surfaced to the UI layer
	assert_object(rc.state.current_offer).is_not_null()
	assert_int(rc.state.current_offer.options.size()).is_greater(0)

	# --- 4. Choosing an option applies it and resumes play ---
	var inventory_before := rc.state.player.weapons.size() + rc.state.player.passives.size()
	rc.on_option_chosen(0)
	# Chained level-ups (if any queued) would present another offer; drain them.
	var drain := 0
	while rc.state.phase == GameState.Phase.LEVEL_UP and drain < 20:
		rc.on_option_chosen(0)
		drain += 1
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_float(rc.state.player.iframe_timer).is_equal(RunController.POST_LEVELUP_IFRAMES)
	assert_object(rc.state.current_offer).is_null()
	var inventory_after := rc.state.player.weapons.size() + rc.state.player.passives.size()
	assert_bool(inventory_after >= inventory_before).is_true()    # item added or upgraded

	# --- 5. Player movement flows through the resumed pipeline ---
	var before_pos: Vector2 = rc.state.player.pos
	rc._tick(0.1, Vector2.DOWN)
	assert_vector(rc.state.player.facing).is_equal(Vector2.DOWN)  # facing tracks input
	assert_bool(rc.state.player.pos.y > before_pos.y).is_true()   # actually moved

	# --- 6. Death ends the run and emits a results summary ---
	rc.state.player.hp = 0.0
	rc.state.player.revivals = 0
	rc._tick(0.05, Vector2.ZERO)
	assert_int(rc.state.phase).is_equal(GameState.Phase.GAME_OVER)
	assert_int(summaries.size()).is_equal(1)
	var summary: Dictionary = summaries[0]
	assert_bool(summary.has("kills")).is_true()
	assert_bool(summary.has("gold")).is_true()
	assert_bool(summary.has("level")).is_true()
	assert_bool(summary.has("time_survived")).is_true()
	assert_int(summary["kills"]).is_equal(rc.state.kills)
	assert_int(summary["level"]).is_equal(rc.state.player.level)
