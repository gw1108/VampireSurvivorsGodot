extends SceneTree

## Headless integration test for the Task 13 RunController conductor.
##   godot --headless --path . --script res://test/run_controller_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so the scene has a live tree (viewport / get_tree). The
## GameManager autoload is mounted at /root/GameManager; we build a RunState with
## its _build_run_state() (no scene change) and drive the controller's tick by
## hand (engine _process is disabled so the steps are deterministic).

const RUN_SCENE := preload("res://scenes/run.tscn")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== run_controller_test ==")
	var gm = root.get_node_or_null("GameManager")
	_check(gm != null, "GameManager autoload present")
	if gm == null:
		print("== %d passed, %d failed ==" % [_passes, _failures])
		quit(_failures)
		return true
	_test_inert_without_run(gm)
	_test_tick_advances(gm)
	_test_death_transition(gm)
	_test_level_up_transition(gm)
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
	root.add_child(rc)       # _ready reads gm.run_state and inits the shells
	rc.set_process(false)    # drive the tick manually for determinism
	return rc

func _start(gm) -> void:
	gm.run_state = gm._build_run_state()
	gm.current_state = gm.State.PLAYING
	gm.get_tree().paused = false

func _test_inert_without_run(gm) -> void:
	gm.run_state = null
	gm.current_state = gm.State.MENU
	var rc = _mount(gm)
	_check(rc.run_state == null, "controller is inert when there is no run_state")
	rc._process(0.016)  # must not crash with a null run
	rc.queue_free()

func _test_tick_advances(gm) -> void:
	_start(gm)
	var rs = gm.run_state
	var rc = _mount(gm)
	_check(rc.run_state == rs, "controller picked up the active run_state in _ready")
	for i in range(3):
		rc._tick(0.1)
	_check(rs.elapsed > 0.0, "elapsed advances (SpawnDirector accumulates delta)")
	_check(rs.player.stats != null, "stats recomputed on the first dirty tick")
	_check(rs.enemies.active_count > 0, "minute-0 periodic spawns produced enemies")
	rc.queue_free()

func _test_death_transition(gm) -> void:
	_start(gm)
	var rs = gm.run_state
	var rc = _mount(gm)
	rs.player.hp = -1.0          # lethal; revival defaults to 0
	rc._tick(0.016)
	_check(gm.current_state == gm.State.GAME_OVER, "lethal HP -> GAME_OVER")
	_check(rs.result.final_level == rs.player.level, "result captured final level")
	_check(rs.result.survival_time == rs.elapsed, "result captured survival time")
	rc.queue_free()

func _test_level_up_transition(gm) -> void:
	_start(gm)
	var rs = gm.run_state
	var rc = _mount(gm)
	rs.player.hp = 120.0         # stay alive so death doesn't pre-empt
	rs.level_up_queue = 1        # a pending level-up
	rc._tick(0.016)
	_check(gm.current_state == gm.State.LEVEL_UP, "pending level_up_queue -> LEVEL_UP")
	# reset so we leave the autoload clean
	gm.current_state = gm.State.MENU
	gm.get_tree().paused = false
	rc.queue_free()
