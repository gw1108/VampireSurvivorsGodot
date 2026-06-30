extends SceneTree

## Headless structural test for the Task 16 run.tscn hierarchy.
##   godot --headless --path . --script res://test/run_scene_structure_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so instantiate()/get_node have a live tree. The scene is
## mounted with no active run (gm.run_state == null) so RunController stays inert
## and we only assert the node graph.

const RUN_SCENE := preload("res://scenes/run.tscn")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== run_scene_structure_test ==")
	var gm = root.get_node_or_null("GameManager")
	if gm != null:
		gm.run_state = null  # keep RunController inert during structural checks

	var rc = RUN_SCENE.instantiate()
	root.add_child(rc)

	_test_world_layers(rc)
	_test_draw_order(rc)
	_test_player(rc)
	_test_canvas_layers(rc)
	_test_overlays(rc)

	rc.queue_free()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
	return true

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_world_layers(rc: Node) -> void:
	_check(rc.get_node_or_null("World") is Node2D, "World is a Node2D")
	var ground = rc.get_node_or_null("World/GroundLayer")
	_check(ground is Sprite2D, "World/GroundLayer is a Sprite2D")
	_check(ground != null and ground.z_index < 0, "GroundLayer draws beneath entities (z_index < 0)")
	for layer in ["PickupLayer", "EnemyLayer", "ProjectileLayer", "FloatingTextLayer"]:
		_check(rc.get_node_or_null("World/" + layer) is Node2D, "World/%s is a Node2D (ViewSync target)" % layer)
	_check(rc.get_node_or_null("ViewSync") is Node, "ViewSync node present")

func _test_draw_order(rc: Node) -> void:
	# Sibling order in World == draw order: ground < pickups < enemies < projectiles < player < floaters.
	var order := ["GroundLayer", "PickupLayer", "EnemyLayer", "ProjectileLayer", "Player", "FloatingTextLayer"]
	var prev := -1
	var monotonic := true
	for name in order:
		var n = rc.get_node_or_null("World/" + name)
		if n == null:
			monotonic = false
			break
		if n.get_index() <= prev:
			monotonic = false
		prev = n.get_index()
	_check(monotonic, "World layers are ordered ground->pickups->enemies->projectiles->player->floaters")

func _test_player(rc: Node) -> void:
	var player = rc.get_node_or_null("World/Player")
	_check(player != null and player.has_method("_gather_input"), "World/Player is the PlayerShell")
	_check(rc.get_node_or_null("World/Player/AnimatedSprite2D") is AnimatedSprite2D, "Player has AnimatedSprite2D")
	_check(rc.get_node_or_null("World/Player/HealthBar") != null, "Player has a HealthBar")
	_check(rc.get_node_or_null("World/Player/Camera2D") is Camera2D, "Player has a Camera2D")

func _test_canvas_layers(rc: Node) -> void:
	var hud_layer = rc.get_node_or_null("HUDLayer")
	_check(hud_layer is CanvasLayer and hud_layer.layer == 1, "HUDLayer is CanvasLayer layer=1")
	_check(rc.get_node_or_null("HUDLayer/HUD") is Control, "HUDLayer/HUD is a Control")
	var overlay = rc.get_node_or_null("OverlayLayer")
	_check(overlay is CanvasLayer and overlay.layer == 2, "OverlayLayer is CanvasLayer layer=2 (above HUD)")

func _test_overlays(rc: Node) -> void:
	for screen_name in ["LevelUpScreen", "PauseScreen", "ResultScreen"]:
		var s = rc.get_node_or_null("OverlayLayer/" + screen_name)
		_check(s is Control, "OverlayLayer/%s is a Control" % screen_name)
		if s != null:
			_check(s.process_mode == Node.PROCESS_MODE_ALWAYS, "%s runs while paused (PROCESS_MODE_ALWAYS)" % screen_name)
			_check(s.visible == false, "%s starts hidden" % screen_name)
