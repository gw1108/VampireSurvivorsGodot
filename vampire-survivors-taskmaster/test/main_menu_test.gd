extends SceneTree

## Headless test runner for the Task 20 MainMenu scene.
##   godot --headless --path . --script res://test/main_menu_test.gd
## Exit code == all passed when 0.
## Runs in _process so scene nodes have a live tree (get_tree / focus / %unique).
## The GameManager autoload is mounted at /root/GameManager; the menu looks it up
## by that path, so we drive/inspect the same real instance here.

const MENU_SCENE := preload("res://scenes/main_menu.tscn")
const GM_SCRIPT := preload("res://autoload/game_manager.gd")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== main_menu_test ==")
	var gm = root.get_node_or_null("GameManager")
	_check(gm != null, "GameManager autoload mounted at /root/GameManager")
	if gm == null:
		print("== %d passed, %d failed ==" % [_passes, _failures])
		quit(_failures)
		return true
	gm.get_tree().paused = false

	_test_structure()
	_test_main_scene_setting()
	_test_start_invokes_run(gm)
	_test_quit_wired()

	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
	return true

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_structure() -> void:
	var menu = MENU_SCENE.instantiate()
	root.add_child(menu)
	_check(menu is Control, "MainMenu root is a Control")
	var start = menu.get_node_or_null("%StartButton")
	var quit_btn = menu.get_node_or_null("%QuitButton")
	var title = menu.get_node_or_null("CenterContainer/Panel/VBox/TitleLabel")
	_check(start is Button and start.text == "Start Game", "StartButton present, labeled 'Start Game'")
	_check(quit_btn is Button and quit_btn.text == "Quit", "QuitButton present, labeled 'Quit'")
	_check(title is Label and title.text == "Vampire Survivors Clone", "TitleLabel shows the game title")
	# _ready wired the signals
	_check(start.pressed.is_connected(menu._on_start), "StartButton.pressed connected to _on_start")
	_check(quit_btn.pressed.is_connected(menu._on_quit), "QuitButton.pressed connected to _on_quit")
	menu.queue_free()

func _test_main_scene_setting() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	_check(main_scene == "res://scenes/main_menu.tscn", "project main_scene points at main_menu.tscn")
	# GameManager points its MENU_SCENE constant at the same path
	_check(GM_SCRIPT.MENU_SCENE == "res://scenes/main_menu.tscn", "GameManager.MENU_SCENE matches the scene path")

func _test_start_invokes_run(gm) -> void:
	# Pressing Start must drive GameManager into a live run (PLAYING + run_state).
	gm.current_state = gm.State.MENU
	gm.run_state = null

	var menu = MENU_SCENE.instantiate()
	root.add_child(menu)  # _ready resolves game_manager via /root/GameManager
	menu._on_start()
	_check(gm.current_state == gm.State.PLAYING, "Start enters PLAYING state")
	_check(gm.run_state != null, "Start builds a RunState")
	_check(gm.run_state != null and gm.run_state.player != null and gm.run_state.player.weapons.size() == 1,
		"RunState carries Antonio's starting kit (one weapon)")

	menu.queue_free()
	gm.get_tree().paused = false

func _test_quit_wired() -> void:
	# Can't actually quit mid-test, but confirm the handler exists.
	var menu = MENU_SCENE.instantiate()
	root.add_child(menu)
	_check(menu.has_method("_on_quit"), "menu exposes _on_quit handler")
	menu.queue_free()
