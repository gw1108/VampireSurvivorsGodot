extends GdUnitTestSuite

## Tests MainMenu (start/quit buttons emit start_game/quit_game; quit does NOT
## directly quit the runner) and RunController's start wiring (_on_start_requested
## begins a run).

const MENU_SCENE := "res://ui/main_menu.tscn"


func _menu() -> MainMenu:
	var m: MainMenu = load(MENU_SCENE).instantiate()
	add_child(m)  # triggers _ready (connect buttons + grab focus)
	return auto_free(m)


func _controller() -> RunController:
	return auto_free(RunController.new())


func test_start_button_emits_start_game() -> void:
	var m := _menu()
	var fired: Array = []
	m.start_game.connect(func(): fired.append(true))
	m.start_btn.pressed.emit()
	assert_int(fired.size()).is_equal(1)


func test_quit_button_emits_quit_game() -> void:
	var m := _menu()
	var fired: Array = []
	m.quit_game.connect(func(): fired.append(true))
	m.quit_btn.pressed.emit()
	assert_int(fired.size()).is_equal(1)


func test_buttons_have_expected_labels() -> void:
	var m := _menu()
	assert_str(m.start_btn.text).contains("Start")
	assert_str(m.quit_btn.text).is_equal("Quit")


func test_start_request_begins_run() -> void:
	var rc := _controller()
	rc._on_start_requested()  # menu null -> just starts the run
	assert_object(rc.state).is_not_null()
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)
