extends SceneTree

## Headless test for the Task 19 overlay screens (OverlayLayer/PauseScreen and
## OverlayLayer/ResultScreen in run.tscn).
##   godot --headless --path . --script res://test/overlay_screens_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so instantiate()/get_node + the GameManager autoload signals
## are live. We mount run.tscn, drive the GameManager FSM, and assert the screens
## react to state_changed / game_over_triggered.

const RUN_SCENE := preload("res://scenes/run.tscn")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== overlay_screens_test ==")
	var gm = root.get_node_or_null("GameManager")
	_check(gm != null, "GameManager autoload present")
	if gm == null:
		print("== %d passed, %d failed ==" % [_passes, _failures])
		quit(_failures)
		return true
	_test_structure()
	_test_pause(gm)
	_test_result(gm)
	# leave the autoload clean
	gm.run_state = null
	gm.current_state = gm.State.MENU
	gm.get_tree().paused = false
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
	return true

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _mount(gm) -> Node:
	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)
	rc.set_process(false)  # no auto sim tick; we drive the FSM directly
	return rc

func _test_structure() -> void:
	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)
	var pause = rc.get_node_or_null("OverlayLayer/PauseScreen")
	var result = rc.get_node_or_null("OverlayLayer/ResultScreen")
	_check(pause != null and pause.has_method("_update_build_display"), "PauseScreen has pause_screen.gd attached")
	for child in ["Panel/BuildContainer", "Panel/ResumeButton", "Panel/QuitButton"]:
		_check(pause != null and pause.get_node_or_null(child) != null, "PauseScreen/%s exists" % child)
	_check(result != null and result.has_method("_on_game_over"), "ResultScreen has result_screen.gd attached")
	for child in ["Panel/TimeLabel", "Panel/LevelLabel", "Panel/KillsLabel", "Panel/GoldLabel", "Panel/RestartButton", "Panel/MenuButton"]:
		_check(result != null and result.get_node_or_null(child) != null, "ResultScreen/%s exists" % child)
	_check(pause != null and pause.visible == false, "PauseScreen starts hidden")
	_check(result != null and result.visible == false, "ResultScreen starts hidden")
	rc.queue_free()

func _test_pause(gm) -> void:
	# A live run with a known build, then pause via the FSM.
	gm.run_state = gm._build_run_state()
	gm.current_state = gm.State.PLAYING
	gm.get_tree().paused = false
	var ws := WeaponInstance.new()
	ws.id = &"magic_wand"
	ws.level = 3
	gm.run_state.player.weapons.append(ws)  # Whip (L1) + Magic Wand (L3)
	var rc = _mount(gm)
	var pause = rc.get_node("OverlayLayer/PauseScreen")
	gm.pause()
	_check(pause.visible == true, "PauseScreen shows when state -> PAUSED")
	var lines := pause.get_node("Panel/BuildContainer").get_child_count()
	_check(lines == gm.run_state.player.weapons.size() + gm.run_state.player.passives.size(),
		"build display lists one line per owned weapon + passive")
	# resume hides it again
	gm.resume()
	_check(pause.visible == false, "PauseScreen hides when resumed (state -> PLAYING)")
	rc.queue_free()

func _test_result(gm) -> void:
	gm.run_state = gm._build_run_state()
	gm.current_state = gm.State.PLAYING
	gm.get_tree().paused = false
	var rc = _mount(gm)
	var result = rc.get_node("OverlayLayer/ResultScreen")
	var r := RunResult.new()
	r.survival_time = 125.0
	r.final_level = 8
	r.total_kills = 234
	r.total_gold = 56
	gm.game_over(r)
	_check(result.visible == true, "ResultScreen shows on game_over")
	_check(result.get_node("Panel/TimeLabel").text == "Time: 02:05", "result time is MM:SS")
	_check(result.get_node("Panel/LevelLabel").text == "Level: 8", "result level")
	_check(result.get_node("Panel/KillsLabel").text == "Kills: 234", "result kills")
	_check(result.get_node("Panel/GoldLabel").text == "Gold: 56", "result gold")
	rc.queue_free()
