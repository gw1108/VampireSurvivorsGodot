extends SceneTree

## Headless test for the Task 22 project configuration.
##   godot --headless --path . --script res://test/project_settings_test.gd
## Exit code == number of failed checks (0 == all passed).
## Asserts the required ProjectSettings, autoload registrations, and input
## actions are present. Runs in _initialize (ProjectSettings/InputMap are
## populated before the main loop).

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== project_settings_test ==")

	# Display / window.
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1445, "viewport width 1445")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == 900, "viewport height 900")
	_check(ProjectSettings.get_setting("display/window/size/resizable") == true, "window resizable")
	# stretch "disabled" reveals more field on resize instead of scaling sprites.
	_check(str(ProjectSettings.get_setting("display/window/stretch/mode", "disabled")) == "disabled", "stretch mode disabled")

	# Rendering: NEAREST canvas filtering + GL Compatibility.
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0, "default texture filter NEAREST (0)")
	_check(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "gl_compatibility", "renderer is gl_compatibility")

	# Main scene.
	_check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/main_menu.tscn", "main scene is the menu")

	# Autoloads registered.
	for name in ["GameManager", "GameDatabase", "AudioManager"]:
		_check(ProjectSettings.has_setting("autoload/" + name), "autoload registered: %s" % name)

	# Input actions: WASD + arrows for movement, Escape for pause.
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"pause"]:
		_check(InputMap.has_action(action), "input action present: %s" % action)
	# Movement actions bind two keys each (a letter + an arrow).
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		_check(InputMap.action_get_events(action).size() >= 2, "%s bound to >=2 keys (WASD + arrow)" % action)
	_check(_action_has_physical_key(&"move_up", KEY_W), "move_up bound to W")
	_check(_action_has_physical_key(&"move_left", KEY_A), "move_left bound to A")
	_check(_action_has_physical_key(&"pause", KEY_ESCAPE), "pause bound to Escape")

	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _action_has_physical_key(action: StringName, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev.physical_keycode == keycode or ev.keycode == keycode):
			return true
	return false

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)
