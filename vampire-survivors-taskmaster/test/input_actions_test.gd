extends GdUnitTestSuite

## Verifies the movement + pause input actions are configured in project.godot
## and bound to the expected keys (WASD + arrows, Escape).

const EXPECTED := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"pause": [KEY_ESCAPE],
}


func _keycodes(action: String) -> Array:
	var out: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append(ev.keycode)
	return out


func test_actions_exist() -> void:
	for action: String in EXPECTED:
		assert_bool(InputMap.has_action(action)).is_true()


func test_actions_have_expected_keys() -> void:
	for action: String in EXPECTED:
		var keys := _keycodes(action)
		for expected_key: int in EXPECTED[action]:
			assert_array(keys).contains([expected_key])


func test_ui_accept_builtin_still_available() -> void:
	# Menu selection relies on the built-in ui_accept (not redefined here).
	assert_bool(InputMap.has_action("ui_accept")).is_true()
