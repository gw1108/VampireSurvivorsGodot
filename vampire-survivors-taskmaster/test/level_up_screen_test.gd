extends SceneTree

## Headless test for the Task 18 LevelUpScreen (OverlayLayer/LevelUpScreen).
##   godot --headless --path . --script res://test/level_up_screen_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so instantiate()/get_node + the GameManager autoload signals
## are live. We mount run.tscn and drive the GameManager level-up FSM.

const RUN_SCENE := preload("res://scenes/run.tscn")

var _failures := 0
var _passes := 0
var _ran := false
var _choice_emitted := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== level_up_screen_test ==")
	var gm = root.get_node_or_null("GameManager")
	_check(gm != null, "GameManager autoload present")
	if gm == null:
		print("== %d passed, %d failed ==" % [_passes, _failures])
		quit(_failures)
		return true
	_test_structure()
	_test_show_and_options(gm)
	_test_select_applies(gm)
	_test_reroll(gm)
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

## Mount run.tscn with a live run (player.stats set so the stat rail populates),
## controller process disabled so nothing ticks behind the manual FSM drive.
func _mount(gm) -> Node:
	gm.run_state = gm._build_run_state()
	gm.run_state.player.stats = StatBlock.new()
	gm.current_state = gm.State.PLAYING
	gm.get_tree().paused = false
	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)
	rc.set_process(false)
	return rc

func _test_structure() -> void:
	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)
	var s = rc.get_node_or_null("OverlayLayer/LevelUpScreen")
	_check(s != null and s.has_method("_on_level_up_requested"), "LevelUpScreen has level_up_screen.gd attached")
	for child in ["Panel/TitleLabel", "Panel/OptionsContainer", "Panel/StatRail", "Panel/RerollButton", "Panel/SkipButton", "Panel/BanishButton"]:
		_check(s != null and s.get_node_or_null(child) != null, "LevelUpScreen/%s exists" % child)
	_check(s != null and s.visible == false, "LevelUpScreen starts hidden")
	rc.queue_free()

func _test_show_and_options(gm) -> void:
	var rc = _mount(gm)
	var s = rc.get_node("OverlayLayer/LevelUpScreen")
	gm.run_state.level_up_queue = 1
	gm.open_level_up()  # -> LEVEL_UP, emits level_up_requested
	_check(s.visible == true, "LevelUpScreen shows on level_up_requested")
	var opts := s.get_node("Panel/OptionsContainer").get_child_count()
	_check(opts >= 1 and opts <= 4, "3-4 option buttons generated (got %d)" % opts)
	_check(opts == s.current_options.size(), "rendered buttons match current_options count")
	_check(s.get_node("Panel/StatRail").get_child_count() > 0, "stat rail is populated from StatBlock")
	# reset FSM for the next sub-test
	gm.current_state = gm.State.PLAYING
	gm.get_tree().paused = false
	rc.queue_free()

func _test_select_applies(gm) -> void:
	var rc = _mount(gm)
	var s = rc.get_node("OverlayLayer/LevelUpScreen")
	_choice_emitted = false
	s.choice_made.connect(func(_c): _choice_emitted = true)
	gm.run_state.level_up_queue = 1
	gm.open_level_up()
	gm.run_state.player.stats_dirty = false  # apply_choice must re-raise it
	s._on_option_selected(0)
	_check(_choice_emitted, "choice_made fires on selection")
	_check(gm.run_state.player.stats_dirty == true, "apply_choice ran (stats_dirty re-raised)")
	_check(s.visible == false, "LevelUpScreen hides after a selection")
	_check(gm.current_state == gm.State.PLAYING, "empty queue resumes the run after selection")
	rc.queue_free()

func _test_reroll(gm) -> void:
	var rc = _mount(gm)
	var s = rc.get_node("OverlayLayer/LevelUpScreen")
	gm.run_state.player.reroll_charges = 2
	gm.run_state.level_up_queue = 1
	gm.open_level_up()
	_check(s.get_node("Panel/RerollButton").disabled == false, "Reroll enabled when charges remain")
	_check(s.get_node("Panel/RerollButton").text == "Reroll (2)", "Reroll button shows charge count")
	s._on_reroll()
	_check(gm.run_state.player.reroll_charges == 1, "reroll spends exactly one charge (no double draw)")
	_check(s.get_node("Panel/OptionsContainer").get_child_count() == s.current_options.size(), "reroll re-renders the new option set")
	# no-op when out of charges
	gm.run_state.player.reroll_charges = 0
	s._update_buttons()
	s._on_reroll()
	_check(gm.run_state.player.reroll_charges == 0, "reroll is a no-op with no charges")
	_check(s.get_node("Panel/RerollButton").disabled == true, "Reroll disabled at 0 charges")
	gm.current_state = gm.State.PLAYING
	gm.get_tree().paused = false
	rc.queue_free()
