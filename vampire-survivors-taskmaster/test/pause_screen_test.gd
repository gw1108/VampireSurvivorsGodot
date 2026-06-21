extends GdUnitTestSuite

## Tests PauseScreen (hidden on ready, show_pause visibility, resume/quit button
## signals, pause-key toggles closed) and RunController's pause integration
## (pause input -> PAUSED, resume -> PLAYING, quit -> GAME_OVER + run_ended).

const PAUSE_SCENE := "res://ui/pause_screen.tscn"


func _pause_screen() -> PauseScreen:
	var s: PauseScreen = load(PAUSE_SCENE).instantiate()
	add_child(s)  # triggers _ready (hide + connect buttons)
	return auto_free(s)


func _controller() -> RunController:
	return auto_free(RunController.new())


func _pause_action() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	return ev


# --- PauseScreen view ---

func test_hidden_on_ready() -> void:
	var s := _pause_screen()
	assert_bool(s.visible).is_false()


func test_show_pause_makes_visible() -> void:
	var s := _pause_screen()
	s.show_pause()
	assert_bool(s.visible).is_true()


func test_resume_button_emits_and_hides() -> void:
	var s := _pause_screen()
	s.show_pause()
	var fired: Array = []
	s.resume_requested.connect(func(): fired.append(true))
	s.resume_btn.pressed.emit()
	assert_int(fired.size()).is_equal(1)
	assert_bool(s.visible).is_false()


func test_quit_button_emits_and_hides() -> void:
	var s := _pause_screen()
	s.show_pause()
	var fired: Array = []
	s.quit_requested.connect(func(): fired.append(true))
	s.quit_btn.pressed.emit()
	assert_int(fired.size()).is_equal(1)
	assert_bool(s.visible).is_false()


func test_pause_key_resumes_when_visible() -> void:
	var s := _pause_screen()
	s.show_pause()
	var fired: Array = []
	s.resume_requested.connect(func(): fired.append(true))
	s._input(_pause_action())
	assert_int(fired.size()).is_equal(1)
	assert_bool(s.visible).is_false()


func test_pause_key_ignored_when_hidden() -> void:
	var s := _pause_screen()  # hidden
	var fired: Array = []
	s.resume_requested.connect(func(): fired.append(true))
	s._input(_pause_action())
	assert_int(fired.size()).is_equal(0)


# --- RunController integration ---

func test_pause_input_pauses_run() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._unhandled_input(_pause_action())
	assert_int(rc.state.phase).is_equal(GameState.Phase.PAUSED)


func test_pause_ignored_when_no_state() -> void:
	var rc := _controller()  # no run started
	rc._unhandled_input(_pause_action())  # must not crash
	assert_object(rc.state).is_null()


func test_resume_request_returns_to_playing() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._open_pause()
	rc._on_resume_requested()
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)


func test_quit_request_ends_run() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._open_pause()
	var summaries: Array = []
	rc.run_ended.connect(func(s): summaries.append(s))
	rc._on_quit_requested()
	assert_int(rc.state.phase).is_equal(GameState.Phase.GAME_OVER)
	assert_int(summaries.size()).is_equal(1)


func test_physics_process_frozen_while_paused() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._open_pause()
	var enemies_before := rc.state.enemies.size()
	var time_before := rc.state.time_elapsed
	rc._physics_process(0.1)  # gated off by PAUSED phase
	assert_int(rc.state.enemies.size()).is_equal(enemies_before)
	assert_float(rc.state.time_elapsed).is_equal(time_before)
