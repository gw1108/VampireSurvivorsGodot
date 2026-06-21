extends GdUnitTestSuite

## End-to-end wiring test for the whole vertical slice. Instantiates the real
## Main.tscn (whose root is the RunController) so _ready discovers and connects
## every screen, then drives the complete phase flow:
##   Title -> Playing -> LevelUp -> Playing -> Pause -> Playing -> Death ->
##   Results -> Title
## and asserts the persistent-widget (menu/HUD) visibility tracks each phase.

const MAIN_SCENE := "res://game/Main.tscn"


func _main() -> RunController:
	var m: RunController = load(MAIN_SCENE).instantiate()
	add_child(m)  # triggers _ready: discovers + wires every screen, enters TITLE look
	return auto_free(m)


func _pause_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	return ev


# --- boot / wiring ---

func test_every_screen_is_wired() -> void:
	var m := _main()
	assert_object(m._hud).is_not_null()
	assert_object(m._main_menu).is_not_null()
	assert_object(m._pause_screen).is_not_null()
	assert_object(m._level_up_screen).is_not_null()
	assert_object(m._death_screen).is_not_null()
	assert_object(m._results_screen).is_not_null()


func test_boots_into_title_look() -> void:
	var m := _main()
	assert_object(m.state).is_null()  # no run started yet
	assert_bool(m._main_menu.visible).is_true()
	assert_bool(m._hud.visible).is_false()
	# every transient overlay starts hidden
	assert_bool(m._pause_screen.visible).is_false()
	assert_bool(m._level_up_screen.visible).is_false()
	assert_bool(m._death_screen.visible).is_false()
	assert_bool(m._results_screen.visible).is_false()


# --- Title -> Playing ---

func test_start_from_menu_enters_playing() -> void:
	var m := _main()
	m._main_menu.start_game.emit()  # menu Start -> start_run
	assert_int(m.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_bool(m._hud.visible).is_true()
	assert_bool(m._main_menu.visible).is_false()


# --- LevelUp overlay ---

func test_level_up_overlay_shows_and_resumes() -> void:
	var m := _main()
	m._main_menu.start_game.emit()
	m.state.pending_levelups = 1
	m._tick(0.016, Vector2.ZERO)  # phase resolution -> LEVEL_UP + show_offer
	assert_int(m.state.phase).is_equal(GameState.Phase.LEVEL_UP)
	assert_bool(m._level_up_screen.visible).is_true()
	assert_bool(m._hud.visible).is_true()  # HUD stays up during the frozen frame
	# Press the first offer button: screen self-hides + emits option_chosen -> controller.
	m._level_up_screen._option_buttons[0].pressed.emit()
	assert_int(m.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_bool(m._level_up_screen.visible).is_false()


# --- Pause overlay ---

func test_pause_overlay_shows_and_resumes() -> void:
	var m := _main()
	m._main_menu.start_game.emit()
	m._unhandled_input(_pause_event())
	assert_int(m.state.phase).is_equal(GameState.Phase.PAUSED)
	assert_bool(m._pause_screen.visible).is_true()
	m._pause_screen.resume_btn.pressed.emit()  # screen self-hides + emits resume_requested
	assert_int(m.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_bool(m._pause_screen.visible).is_false()


# --- Death -> Results -> Title ---

func test_full_loop_death_results_title() -> void:
	var m := _main()
	m._main_menu.start_game.emit()
	# Force an unrecoverable death this tick.
	m.state.player.hp = 0.0
	m.state.player.revivals = 0
	m._tick(0.016, Vector2.ZERO)  # -> GAME_OVER, death screen shown
	assert_int(m.state.phase).is_equal(GameState.Phase.GAME_OVER)
	assert_bool(m._death_screen.visible).is_true()
	assert_bool(m._hud.visible).is_false()

	m._death_screen.continue_btn.pressed.emit()  # self-hides + emits continue -> RESULTS
	assert_int(m.state.phase).is_equal(GameState.Phase.RESULTS)
	assert_bool(m._death_screen.visible).is_false()
	assert_bool(m._results_screen.visible).is_true()

	m._results_screen.done_btn.pressed.emit()  # self-hides + emits done -> TITLE
	assert_int(m.state.phase).is_equal(GameState.Phase.TITLE)
	assert_bool(m._results_screen.visible).is_false()
	assert_bool(m._main_menu.visible).is_true()
	assert_bool(m._hud.visible).is_false()


func test_can_restart_after_returning_to_title() -> void:
	var m := _main()
	m._main_menu.start_game.emit()
	m.state.player.hp = 0.0
	m.state.player.revivals = 0
	m._tick(0.016, Vector2.ZERO)
	m._death_screen.continue_btn.pressed.emit()
	m._results_screen.done_btn.pressed.emit()  # back at TITLE
	# A fresh run starts cleanly from the menu again.
	m._main_menu.start_game.emit()
	assert_int(m.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_bool(m._hud.visible).is_true()
