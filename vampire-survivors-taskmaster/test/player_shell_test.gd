extends SceneTree

## Headless test runner for the Task 14 PlayerShell.
##   godot --headless --path . --script res://test/player_shell_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so scene nodes have a live tree (viewport/get_tree).

const PS_SCRIPT := preload("res://nodes/player_shell.gd")
const PS_SCENE := preload("res://scenes/player_shell.tscn")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== player_shell_test ==")
	_test_input_actions()
	_test_snap_to_8()
	_test_scene_render()
	_test_camera_rect()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
	return true

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _vapprox(a: Vector2, b: Vector2, msg: String) -> void:
	_check(a.is_equal_approx(b), "%s (got %v, want %v)" % [msg, a, b])

func _test_input_actions() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "pause"]:
		_check(InputMap.has_action(action), "input action registered: %s" % action)
	# move actions each have two bindings (key + arrow); pause has one
	_check(InputMap.action_get_events("move_left").size() == 2, "move_left has WASD + arrow bindings")
	_check(InputMap.action_get_events("pause").size() == 1, "pause has one binding (ESC)")

func _test_snap_to_8() -> void:
	# below deadzone -> zero
	_check(PS_SCRIPT.snap_to_8(Vector2.ZERO) == Vector2.ZERO, "zero input -> ZERO")
	_check(PS_SCRIPT.snap_to_8(Vector2(0.05, 0)) == Vector2.ZERO, "below-deadzone input -> ZERO")
	# cardinals
	_vapprox(PS_SCRIPT.snap_to_8(Vector2(1, 0)), Vector2.RIGHT, "right cardinal")
	_vapprox(PS_SCRIPT.snap_to_8(Vector2(-1, 0)), Vector2.LEFT, "left cardinal")
	_vapprox(PS_SCRIPT.snap_to_8(Vector2(0, 1)), Vector2.DOWN, "down cardinal")
	_vapprox(PS_SCRIPT.snap_to_8(Vector2(0, -1)), Vector2.UP, "up cardinal")
	# diagonal -> unit diagonal
	_vapprox(PS_SCRIPT.snap_to_8(Vector2(1, 1)), Vector2(1, 1).normalized(), "down-right diagonal")
	_vapprox(PS_SCRIPT.snap_to_8(Vector2(-1, -1)), Vector2(-1, -1).normalized(), "up-left diagonal")
	# near-cardinal snaps to cardinal
	_vapprox(PS_SCRIPT.snap_to_8(Vector2(0.9, 0.1)), Vector2.RIGHT, "shallow angle snaps to right")
	# result is always a unit vector when nonzero
	var d := PS_SCRIPT.snap_to_8(Vector2(0.3, 0.7))
	_check(is_equal_approx(d.length(), 1.0), "snapped nonzero result is unit length")

func _test_scene_render() -> void:
	var shell = PS_SCENE.instantiate()
	root.add_child(shell)
	_check(shell.camera.zoom == Vector2(2, 2), "camera zoom set to integer 2x in _ready")

	var state := PlayerState.new()
	state.pos = Vector2(50, 60)
	shell.init(state)
	_check(shell.position == Vector2(50, 60), "init places shell at player pos")

	# facing right, full hp, idle
	state.pos = Vector2(10, 20)
	state.facing = Vector2.RIGHT
	state.vel = Vector2.ZERO
	state.hp = 120.0
	state.max_hp = 120.0
	state.iframe_timer = 0.0
	shell.render(state)
	_check(shell.position == Vector2(10, 20), "render syncs position")
	_check(shell.sprite.flip_h == false, "facing right -> not flipped")
	_check(shell.sprite.animation == &"idle", "zero velocity -> idle animation")
	_check(shell.health_bar.visible == false, "full hp -> health bar hidden")
	_check(is_equal_approx(shell.sprite.modulate.a, 1.0), "no i-frames -> full alpha")

	# facing left
	state.facing = Vector2.LEFT
	shell.render(state)
	_check(shell.sprite.flip_h == true, "facing left -> flipped")

	# moving -> walk
	state.vel = Vector2(50, 0)
	shell.render(state)
	_check(shell.sprite.animation == &"walk", "nonzero velocity -> walk animation")

	# damaged -> health bar shows and scales
	state.hp = 60.0
	shell.render(state)
	_check(shell.health_bar.visible == true, "hp < max -> health bar visible")
	_check(is_equal_approx(shell.health_bar.value, 50.0), "health bar value = hp/max*100")

	# i-frame flash -> alpha modulated below 1
	state.iframe_timer = 0.1
	shell.render(state)
	var expected_a := 0.5 + 0.5 * sin(0.1 * 30.0)
	_check(is_equal_approx(shell.sprite.modulate.a, expected_a), "i-frame flash modulates alpha")
	_check(shell.sprite.modulate.a < 1.0, "i-frame alpha is dimmed")

	shell.queue_free()

func _test_camera_rect() -> void:
	var shell = PS_SCENE.instantiate()
	root.add_child(shell)
	var state := PlayerState.new()
	state.pos = Vector2(100, 200)
	shell.init(state)
	var rect: Rect2 = shell.get_camera_rect()
	var vp: Vector2 = shell.get_viewport_rect().size
	_vapprox(rect.size, vp / 2.0, "camera rect size = viewport / zoom")
	_vapprox(rect.get_center(), Vector2(100, 200), "camera rect centered on player")
	shell.queue_free()
