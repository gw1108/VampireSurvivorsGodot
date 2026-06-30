extends Node
## Per-game AgentBridge adapter for the VS slice (the ~15-line piece you write per game).
## Maps VSRun state onto the generic AgentState contract so the agent_play harness can
## read player/enemies/score/phase. The generic transport lives in agent_bridge.gd.
##
## Wired up by VSRun, which adds this as a child of the run scene. Inert unless running
## as a web export with the agent gate on (?agent=1 or the "agent" export feature).

@onready var game: VSRun = get_parent()

# The four movement actions the harness can tap. Their taps are converted into a held
# press (see _hold_move) so the player actually travels during the unfrozen step.
const MOVE_ACTIONS := ["move_up", "move_down", "move_left", "move_right"]
var _held_move := ""   # the single movement direction currently held for the agent ("" = none)

func _ready() -> void:
	AgentBridge.register_provider(_provide)
	AgentBridge.register_command_handler(_on_command)

# func() -> Dictionary : called every frame while the bridge is active.
func _provide() -> Dictionary:
	var p := game.player
	var player_dict: Variant = null
	if p and is_instance_valid(p):
		player_dict = {
			"pos": [p.position.x, p.position.y],
			"velocity": [p.velocity.x, p.velocity.y],
			"health": p.health,
			"max_health": p.max_health,
			"alive": p.alive,
			"extra": {"level": game.level, "xp": game.xp},
		}
	var cam_pos := [0.0, 0.0]
	if p and is_instance_valid(p):
		cam_pos = [p.position.x, p.position.y]
	return {
		"phase": game.phase,
		"player": player_dict,
		"score": game.kills,
		"entities": _entities(),
		"world": {
			"coordinate_space": "pixels",
			"bounds": {"min": [-game.arena_half.x, -game.arena_half.y], "max": [game.arena_half.x, game.arena_half.y]},
			"camera": {"pos": cam_pos, "zoom": 1.0},
		},
		"available_actions": _actions(game.phase),
		"meta": {
			"tick": game.frame_tick,
			"elapsed": game.elapsed,
			"enemies": get_tree().get_nodes_in_group("enemies").size(),
		},
	}

func _actions(phase: String) -> Array:
	if phase == "game_over":
		return ["ui_accept"]
	if phase == "level_up":
		return ["choose_1", "choose_2", "choose_3"]
	return ["move_up", "move_down", "move_left", "move_right"]

func _entities() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		out.append({"id": str(e.get_instance_id()), "type": "enemy", "pos": [e.position.x, e.position.y], "state": "chase"})
	for pr in get_tree().get_nodes_in_group("projectiles"):
		out.append({"id": str(pr.get_instance_id()), "type": "projectile", "pos": [pr.position.x, pr.position.y], "state": "fly"})
	for g in get_tree().get_nodes_in_group("gems"):
		out.append({"id": str(g.get_instance_id()), "type": "xp", "pos": [g.position.x, g.position.y], "state": "idle"})
	return out

# Commands NOT consumed by the bridge itself (set_time_scale/ack/restart) land here.
# Registering this handler suppresses the bridge's default input synthesis, so we
# synthesize press/release/tap ourselves — that's how the harness moves the player and
# picks a level-up upgrade (choose_1/2/3). The harness only ever sends taps, so movement
# taps are converted to a held direction (_hold_move); discrete choices stay real taps.
func _on_command(cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"set_seed":
			game.reseed(int(cmd.get("value", 0)))
		"press":
			_send_action(str(cmd.get("action", "")), true)
		"release":
			_send_action(str(cmd.get("action", "")), false)
		"tap":
			var a := str(cmd.get("action", ""))
			if a in MOVE_ACTIONS:
				_hold_move(a)   # movement: hold the direction so the step actually travels
			else:
				_send_action(a, true)   # discrete choice (choose_1/2/3, ui_accept): a real tap
				_send_action(a, false)
		_:
			pass

# The harness freezes the game, taps ONE action, then unfreezes for a step. A movement
# tap (press+release in the same frozen frame) nets ~0 displacement: the player polls
# Input.get_vector and the action is already released before any time passes, so the
# agent could never actually move. Instead we HOLD the tapped direction — releasing any
# prior one — so get_vector reports it for the whole unfrozen step and the player travels.
# Only one direction is held at a time: pressing an opposite without releasing the current
# one would cancel out inside get_vector. The next movement tap replaces it; a noop step
# leaves it held (continuous VS-style movement), which the persona steers by changing dir.
func _hold_move(action: String) -> void:
	if action == _held_move:
		return
	if _held_move != "":
		_send_action(_held_move, false)
	_held_move = action
	_send_action(action, true)

func _send_action(action: String, pressed: bool) -> void:
	if action == "" or not InputMap.has_action(action):
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
