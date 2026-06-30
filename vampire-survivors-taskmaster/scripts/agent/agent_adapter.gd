extends Node
## Per-game AgentBridge adapter for the VS slice (the ~15-line piece you write per game).
## Maps VSRun state onto the generic AgentState contract so the agent_play harness can
## read player/enemies/score/phase. The generic transport lives in agent_bridge.gd.
##
## Wired up by VSRun, which adds this as a child of the run scene. Inert unless running
## as a web export with the agent gate on (?agent=1 or the "agent" export feature).

@onready var game: VSRun = get_parent()

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
			"velocity": [0.0, 0.0],
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

# Only commands NOT handled by the bridge (press/release/tap/set_time_scale/ack/restart).
func _on_command(cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"set_seed":
			game.reseed(int(cmd.get("value", 0)))
		_:
			pass
