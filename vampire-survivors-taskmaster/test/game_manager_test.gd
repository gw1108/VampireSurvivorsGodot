extends SceneTree

## Headless test runner for the Task 12 GameManager state machine.
##   godot --headless --path . --script res://test/game_manager_test.gd
## Exit code == number of failed checks (0 == all passed).

const GM_SCRIPT := preload("res://autoload/game_manager.gd")

var _failures := 0
var _passes := 0
var _ran := false

# Run on the first frame (not _initialize): nodes added to `root` only have a
# valid get_tree() once the tree is up, which is after _initialize.
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== game_manager_test ==")
	_test_initial_state()
	_test_start_run()
	_test_pause_resume()
	_test_level_up_single()
	_test_level_up_multi()
	_test_game_over()
	_test_to_menu()
	_test_guards()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
	return true

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _fresh_gm():
	var gm = GM_SCRIPT.new()
	root.add_child(gm)
	gm.get_tree().paused = false
	return gm

func _test_initial_state() -> void:
	var gm = _fresh_gm()
	_check(gm.current_state == gm.State.MENU, "initial state is MENU")
	_check(gm.run_state == null, "initial run_state is null")

func _test_start_run() -> void:
	var gm = _fresh_gm()
	var counts := { state = 0, run = 0 }
	gm.state_changed.connect(func(_s): counts.state += 1)
	gm.run_started.connect(func(_rs): counts.run += 1)
	gm.start_run()
	_check(gm.current_state == gm.State.PLAYING, "start_run -> PLAYING")
	_check(gm.get_tree().paused == false, "start_run unpauses")
	var rs = gm.run_state
	_check(rs != null and rs is RunState, "run_state created")
	_check(rs.player is PlayerState, "player created")
	_check(rs.player.hp == 120.0 and rs.player.max_hp == 120.0, "player hp/max_hp 120")
	_check(rs.player.pos == Vector2.ZERO, "player at origin")
	_check(rs.player.weapons.size() == 1, "exactly one starting weapon")
	_check(rs.player.weapons[0].id == &"whip" and rs.player.weapons[0].level == 1, "starting weapon is Whip L1")
	_check(rs.enemies is EnemyPool, "enemies pool wired")
	_check(rs.projectiles is ProjectilePool, "projectiles pool wired")
	_check(rs.pickups is PickupPool, "pickups pool wired")
	_check(rs.floaters is FloatingTextPool, "floaters pool wired")
	_check(rs.grid is SpatialGrid, "grid wired")
	_check(rs.spawn is SpawnDirectorState, "spawn state wired")
	_check(rs.rng is RandomNumberGenerator, "rng wired")
	_check(rs.result is RunResult, "result wired")
	_check(rs.phase == RunState.Phase.PLAYING, "run_state.phase PLAYING")
	_check(counts.state == 1 and counts.run == 1, "state_changed + run_started each emitted once")

func _test_pause_resume() -> void:
	var gm = _fresh_gm()
	gm.start_run()
	gm.pause()
	_check(gm.current_state == gm.State.PAUSED, "pause -> PAUSED")
	_check(gm.get_tree().paused == true, "pause sets tree paused")
	gm.resume()
	_check(gm.current_state == gm.State.PLAYING, "resume -> PLAYING")
	_check(gm.get_tree().paused == false, "resume unpauses tree")
	# resume again is a no-op (not PAUSED)
	gm.resume()
	_check(gm.current_state == gm.State.PLAYING, "resume from PLAYING is a no-op")

func _test_level_up_single() -> void:
	var gm = _fresh_gm()
	gm.start_run()
	gm.run_state.level_up_queue = 1
	var lvl_reqs := { n = 0 }
	gm.level_up_requested.connect(func(): lvl_reqs.n += 1)
	gm.open_level_up()
	_check(gm.current_state == gm.State.LEVEL_UP, "open_level_up -> LEVEL_UP")
	_check(gm.get_tree().paused == true, "level-up pauses tree")
	_check(lvl_reqs.n == 1, "level_up_requested emitted on open")
	gm.close_level_up()
	_check(gm.run_state.level_up_queue == 0, "queue drained to 0")
	_check(gm.current_state == gm.State.PLAYING, "close with empty queue -> PLAYING")
	_check(gm.get_tree().paused == false, "resumes after last level-up")

func _test_level_up_multi() -> void:
	var gm = _fresh_gm()
	gm.start_run()
	gm.run_state.level_up_queue = 3
	var lvl_reqs := { n = 0 }
	gm.level_up_requested.connect(func(): lvl_reqs.n += 1)
	gm.open_level_up()                       # request #1
	gm.close_level_up()                      # queue 3->2, still LEVEL_UP, request #2
	_check(gm.current_state == gm.State.LEVEL_UP, "still LEVEL_UP with queue remaining")
	_check(gm.run_state.level_up_queue == 2, "queue now 2")
	gm.close_level_up()                      # queue 2->1, request #3
	_check(gm.current_state == gm.State.LEVEL_UP, "still LEVEL_UP at queue 1")
	gm.close_level_up()                      # queue 1->0 -> PLAYING
	_check(gm.current_state == gm.State.PLAYING, "drained queue -> PLAYING")
	_check(lvl_reqs.n == 3, "level_up_requested emitted once per pending level (3)")

func _test_game_over() -> void:
	var gm = _fresh_gm()
	gm.start_run()
	var over := { n = 0, result = null }
	gm.game_over_triggered.connect(func(r): over.n += 1; over.result = r)
	var result := RunResult.new()
	result.survival_time = 123.4
	gm.game_over(result)
	_check(gm.current_state == gm.State.GAME_OVER, "game_over -> GAME_OVER")
	_check(gm.get_tree().paused == true, "game_over pauses tree")
	_check(over.n == 1 and over.result == result, "game_over_triggered carries the result")
	_check(gm.run_state.result == result, "result stored on run_state")

func _test_to_menu() -> void:
	var gm = _fresh_gm()
	gm.start_run()
	gm.to_menu()
	_check(gm.current_state == gm.State.MENU, "to_menu -> MENU")
	_check(gm.run_state == null, "to_menu clears run_state")
	_check(gm.get_tree().paused == false, "to_menu unpauses")

func _test_guards() -> void:
	var gm = _fresh_gm()  # MENU
	gm.pause()
	_check(gm.current_state == gm.State.MENU, "pause from MENU is a no-op")
	gm.resume()
	_check(gm.current_state == gm.State.MENU, "resume from MENU is a no-op")
	gm.open_level_up()
	_check(gm.current_state == gm.State.MENU, "open_level_up from MENU is a no-op")
	gm.close_level_up()
	_check(gm.current_state == gm.State.MENU, "close_level_up from MENU is a no-op")
