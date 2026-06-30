extends SceneTree

## Headless test for the Task 26 Mad Forest ground (World/GroundLayer).
##   godot --headless --path . --script res://test/ground_layer_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so instantiate()/get_node + the viewport/camera are live.
## Mounts run.tscn with no active run (RunController inert) and asserts the
## ground is a single repeating quad that follows the camera (world-locked).

const RUN_SCENE := preload("res://scenes/run.tscn")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== ground_layer_test ==")
	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.run_state = null  # keep RunController inert; we only test the ground
	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)

	var ground = rc.get_node_or_null("World/GroundLayer")
	_check(ground is Sprite2D, "GroundLayer is a Sprite2D")
	if ground == null:
		_finish(rc); return true

	# Configuration (set in _ready).
	_check(ground.z_index < 0, "ground draws beneath entities (z_index < 0)")
	_check(ground.texture != null, "ground has the grass texture")
	_check(ground.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED, "texture_repeat enabled (seamless tiling)")
	_check(ground.region_enabled, "region enabled (one quad tiles the texture)")
	_check(ground.region_rect.size.x >= 1445.0 and ground.region_rect.size.y >= 900.0, "quad covers the viewport with margin")
	_check(ground.has_method("_follow"), "ground has the follow script attached")

	# Follow behaviour: the quad position and its texture sample origin track the
	# camera and stay equal -> the grass reads as world-locked (no apparent slide).
	var cam = rc.get_node_or_null("World/Player/Camera2D")
	_check(cam is Camera2D, "player Camera2D present")
	if cam != null:
		cam.make_current()
		_check(root.get_camera_2d() == cam, "player camera is the active 2D camera")
		cam.global_position = Vector2(1234.4, -567.6)
		ground._follow()
		_check(ground.position == Vector2(1234.0, -568.0), "ground snaps its position to the (pixel-rounded) camera")
		_check(ground.region_rect.position == ground.position, "texture region offset tracks position (world-locked, seamless)")
		# moving the camera keeps the same texel under a fixed world point
		var before := _texel_origin(ground)
		cam.global_position = Vector2(5000.0, 5000.0)
		ground._follow()
		_check(ground.position == Vector2(5000.0, 5000.0), "ground re-follows the camera after it moves")
		_check(_texel_origin(ground) == before, "world->texel mapping is invariant as the camera moves (seamless infinite ground)")

	_finish(rc)
	return true

## The texel sampled at the quad's top-left world corner, as a constant offset:
## region.position - (position - size/2). If this is invariant across camera
## moves, the ground is world-locked (the whole point of the follow trick).
func _texel_origin(g) -> Vector2:
	return g.region_rect.position - (g.position - g.region_rect.size * 0.5)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _finish(rc) -> void:
	rc.queue_free()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
