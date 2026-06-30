extends SceneTree

## Headless test for the Task 17 HUD overlay (HUDLayer/HUD in run.tscn).
##   godot --headless --path . --script res://test/hud_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so instantiate()/get_node have a live tree. We drive the
## HUD's _process by hand (engine processing disabled) so the displayed numbers
## are a deterministic function of the run_state we set.

const RUN_SCENE := preload("res://scenes/run.tscn")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== hud_test ==")
	var gm = root.get_node_or_null("GameManager")
	_check(gm != null, "GameManager autoload present")
	if gm == null:
		print("== %d passed, %d failed ==" % [_passes, _failures])
		quit(_failures)
		return true
	_test_script_attached()
	_test_inert_without_run(gm)
	_test_reflects_state(gm)
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

## Mount run.tscn and return its HUD, with both the controller and the HUD's
## engine _process disabled so nothing ticks behind our manual calls.
func _mount_hud(gm) -> Control:
	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)
	rc.set_process(false)
	var hud: Control = rc.get_node("HUDLayer/HUD")
	hud.set_process(false)
	return hud

func _test_script_attached() -> void:
	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)
	var hud = rc.get_node_or_null("HUDLayer/HUD")
	_check(hud != null and hud.has_method("_update_inventory"), "HUD has the hud.gd script attached")
	for child in ["XPBar", "TimerLabel", "LevelLabel", "GoldLabel", "KillsLabel", "WeaponContainer", "PassiveContainer"]:
		_check(hud != null and hud.get_node_or_null(child) != null, "HUD/%s exists" % child)
	rc.queue_free()

func _test_inert_without_run(gm) -> void:
	gm.run_state = null
	var hud = _mount_hud(gm)
	var before: String = hud.get_node("TimerLabel").text
	hud._process(0.016)  # must not crash with no active run
	_check(hud.get_node("TimerLabel").text == before, "HUD is inert (unchanged) without a run_state")
	hud.get_parent().queue_free()

func _test_reflects_state(gm) -> void:
	gm.run_state = gm._build_run_state()
	gm.current_state = gm.State.PLAYING
	var rs = gm.run_state
	rs.elapsed = 125.0            # 02:05
	rs.player.xp = 2.5
	rs.player.xp_to_next = 5.0    # 50% -> 50 on a 0..100 bar
	rs.player.level = 3
	rs.player.gold = 42
	rs.player.kills = 7
	var hud = _mount_hud(gm)
	hud._process(0.016)
	_check(is_equal_approx(hud.get_node("XPBar").value, 50.0), "XP bar fills to the xp/xp_to_next ratio")
	_check(hud.get_node("TimerLabel").text == "02:05", "timer formats elapsed as MM:SS")
	_check(hud.get_node("LevelLabel").text == "LV 3", "level label shows LV <n>")
	_check(hud.get_node("GoldLabel").text == "42", "gold label shows gold")
	_check(hud.get_node("KillsLabel").text == "7", "kills label shows kills")
	# Antonio's starting kit is one weapon (Whip), no passives.
	_check(hud.get_node("WeaponContainer").get_child_count() == rs.player.weapons.size(), "weapon icons match owned weapon count")
	_check(hud.get_node("PassiveContainer").get_child_count() == rs.player.passives.size(), "passive icons match owned passive count")

	# xp_to_next == 0 must not produce a NaN fill.
	rs.player.xp_to_next = 0.0
	hud._process(0.016)
	_check(hud.get_node("XPBar").value == 0.0, "xp_to_next == 0 leaves the XP bar at 0 (no NaN)")
	hud.get_parent().queue_free()
