extends GdUnitTestSuite

## Tests RunController orchestration: run start (state + player from Antonio def +
## starting spawns), the level-up phase transition (single + chained), resume after
## a choice, and the game-over transition. The per-tick pipeline is driven via the
## testable _tick(delta, input_dir) hook so no Input singleton is required.

func _controller() -> RunController:
	return auto_free(RunController.new())


# --- start_run ---

func test_start_run_initializes_playing_state() -> void:
	var rc := _controller()
	var phases: Array = []
	rc.phase_changed.connect(func(p): phases.append(p))
	rc.start_run("antonio")
	assert_object(rc.state).is_not_null()
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_array(phases).contains([GameState.Phase.PLAYING])  # phase_changed emitted


func test_player_built_from_antonio_def() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	var p := rc.state.player
	assert_object(p.character_def).is_not_null()
	assert_float(p.derived.max_health).is_equal(120.0)  # Antonio +20 HP
	assert_float(p.hp).is_equal(120.0)  # starts at full
	assert_int(p.weapons.size()).is_equal(1)  # starting whip
	assert_str(p.weapons[0].def.id).is_equal("whip")
	assert_int(p.revivals).is_equal(int(p.derived.revival))


func test_start_run_spawns_starting_enemies() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	assert_int(rc.state.enemies.size()).is_equal(rc._stage_def.starting_spawn_count)
	assert_int(rc.state.enemies.size()).is_greater(0)


# --- level-up transition ---

func test_tick_enters_level_up_and_emits_offer() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	var offers: Array = []
	rc.level_up_started.connect(func(o): offers.append(o))
	rc.state.pending_levelups = 1
	rc._tick(0.016, Vector2.ZERO)
	assert_int(rc.state.phase).is_equal(GameState.Phase.LEVEL_UP)
	assert_object(rc.state.current_offer).is_not_null()
	assert_int(offers.size()).is_equal(1)


func test_on_option_chosen_resumes_play() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc.state.pending_levelups = 1
	rc._tick(0.016, Vector2.ZERO)  # -> LEVEL_UP
	rc.on_option_chosen(0)
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_float(rc.state.player.iframe_timer).is_equal(RunController.POST_LEVELUP_IFRAMES)
	assert_object(rc.state.current_offer).is_null()


func test_chained_level_ups_present_next_offer() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc.state.pending_levelups = 2
	rc._tick(0.016, Vector2.ZERO)  # -> LEVEL_UP (first offer)
	rc.on_option_chosen(0)  # still one queued
	assert_int(rc.state.phase).is_equal(GameState.Phase.LEVEL_UP)
	assert_object(rc.state.current_offer).is_not_null()
	rc.on_option_chosen(0)  # last one -> resume
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)


# --- game over ---

func test_player_death_ends_run() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	var summaries: Array = []
	rc.run_ended.connect(func(s): summaries.append(s))
	rc.state.player.hp = 0.0
	rc.state.player.revivals = 0
	rc._tick(0.016, Vector2.ZERO)
	assert_int(rc.state.phase).is_equal(GameState.Phase.GAME_OVER)
	assert_int(summaries.size()).is_equal(1)
	assert_bool(summaries[0].has("kills")).is_true()


func test_physics_process_is_inert_when_not_playing() -> void:
	# No state yet -> a physics tick must be a no-op (no crash, nothing spawned).
	var rc := _controller()
	rc._physics_process(0.016)
	assert_object(rc.state).is_null()
