extends SceneTree

## Headless test for the Task 23 Antonio sprite import.
##   godot --headless --path . --script res://test/antonio_sprite_test.gd
## Exit code == number of failed checks (0 == all passed).
## Locks the SpriteFrames asset + the on-screen size target. Runs in _process so
## the player scene can be instantiated (needs a live tree).

const FRAMES := preload("res://assets/sprites/antonio.tres")
const PS_SCENE := preload("res://scenes/player_shell.tscn")
const CAMERA_ZOOM := 2

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== antonio_sprite_test ==")
	_test_frames()
	_test_scene_size()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
	return true

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_frames() -> void:
	_check(FRAMES is SpriteFrames, "antonio.tres is a SpriteFrames")
	_check(FRAMES.has_animation("idle"), "has an 'idle' animation")
	_check(FRAMES.has_animation("walk"), "has a 'walk' animation")
	_check(FRAMES.get_animation_loop("idle"), "idle loops")
	_check(FRAMES.get_animation_loop("walk"), "walk loops")
	_check(is_equal_approx(FRAMES.get_animation_speed("idle"), 8.0), "idle plays at 8 fps")
	_check(is_equal_approx(FRAMES.get_animation_speed("walk"), 12.0), "walk plays at 12 fps")
	# the frame is the real Antonio art (1024px), not a tiny placeholder
	var tex := FRAMES.get_frame_texture("idle", 0)
	_check(tex != null, "idle frame has a texture")
	_check(tex != null and tex.get_width() == 1024 and tex.get_height() == 1024,
		"idle frame is the 1024x1024 Antonio art (got %s)" % (str(tex.get_size()) if tex else "null"))

func _test_scene_size() -> void:
	# On-screen target ~50x62 at zoom 2 -> native ~25x31. The 1024px art is scaled
	# down; check the resulting on-screen footprint is in the ~40-80px ballpark.
	var shell = PS_SCENE.instantiate()
	root.add_child(shell)
	var sprite: AnimatedSprite2D = shell.sprite
	_check(sprite.sprite_frames == FRAMES, "PlayerShell uses the Antonio SpriteFrames")
	_check(sprite.centered, "Antonio sprite is centered on the player position")
	var native_h := 1024.0 * sprite.scale.y
	var onscreen_h := native_h * CAMERA_ZOOM
	_check(onscreen_h >= 40.0 and onscreen_h <= 90.0,
		"on-screen sprite height ~50-62px target (got %.0f)" % onscreen_h)
	shell.queue_free()
