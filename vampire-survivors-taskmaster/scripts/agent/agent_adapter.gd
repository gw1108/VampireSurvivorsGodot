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
			"enemies": get_tree().get_nodes_in_group("enemies").size() - get_tree().get_nodes_in_group("candelabra").size(),
		},
	}

func _actions(phase: String) -> Array:
	if phase == "game_over":
		return ["ui_accept"]
	if phase == "level_up":
		# Only expose the choices actually on screen.
		var n := 0
		if game.upgrade_screen and is_instance_valid(game.upgrade_screen):
			n = game.upgrade_screen.option_count()
		var out: Array = []
		for i in n:
			out.append("upgrade_%d" % (i + 1))
		# Build-agency actions: Skip is always legal on the picker; Reroll only with budget.
		if game.upgrade_screen and is_instance_valid(game.upgrade_screen):
			out.append("upgrade_skip")
			if game.upgrade_screen.has_rerolls():
				out.append("upgrade_reroll")
		return out
	return ["move_up", "move_down", "move_left", "move_right"]

func _entities() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		# Destructible candelabra share the "enemies" group (so weapons hit them) but are
		# stationary props, not threats — report them under their own type below.
		if not e is VSEnemy:
			continue
		out.append({"id": str(e.get_instance_id()), "type": "enemy", "pos": [e.position.x, e.position.y], "state": "chase"})
	for c in get_tree().get_nodes_in_group("candelabra"):
		out.append({"id": str(c.get_instance_id()), "type": "candelabra", "pos": [c.position.x, c.position.y], "state": "idle"})
	for pr in get_tree().get_nodes_in_group("projectiles"):
		out.append({"id": str(pr.get_instance_id()), "type": "projectile", "pos": [pr.position.x, pr.position.y], "state": "fly"})
	for g in get_tree().get_nodes_in_group("gems"):
		out.append({"id": str(g.get_instance_id()), "type": "xp", "pos": [g.position.x, g.position.y], "state": "idle"})
	return out

# Handles this game's custom commands; everything else (press/release/tap the harness
# sends to move the player and make level-up picks) falls through to the bridge's default
# input synthesizer. Registering a handler at all short-circuits that synthesizer in the
# bridge, so an adapter MUST defer unrecognized types or the JS command channel goes dead.
func _on_command(cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"restart":
			# The bridge forwards restart to the registered handler; without this branch it
			# falls through to default_command (an input synthesizer with no restart path) and
			# is silently swallowed. reload_current_scene is the game's own restart path — the
			# same one game-over/paused ui_accept uses (see run.gd) — so the harness can reset a
			# run without steering the player into death first.
			get_tree().reload_current_scene()
		"set_seed":
			game.reseed(int(cmd.get("value", 0)))
		"force_gold_fever":
			# Gold Fever only starts from a Gilded Clover pickup — a level-30+, weight-1
			# candelabra drop too rare to reach reliably in an automated playtest. Debug-only
			# escape hatch so the harness can exercise/verify it directly; inert in real builds
			# (this whole channel only exists behind the agent gate — see agent_bridge.gd).
			game.start_gold_fever()
		"force_luck":
			# Crit chance scales with the run's +Luck bonus (run.roll_crit: ~+0.5% crit per +1% Luck,
			# capped at 75%). Reaching that cap organically means stacking many Little Clover / Clover
			# picks — too many level-ups to reach reliably in an automated playtest. Debug-only escape
			# hatch: set luck_bonus directly (default 300 -> crit chance pinned at the 75% cap) so the
			# harness can make crits fire on nearly every hit and verify the gold CRIT_TEXT numbers;
			# inert in real builds (this whole channel only exists behind the agent gate — see agent_bridge.gd).
			game.luck_bonus = float(cmd.get("value", 300.0))
		"force_fire_wand":
			# The Fire Wand needs several level-up picks (level 6 = 3 fireballs/volley, per
			# VSFireWand._amount) to lob multiple simultaneous fireballs — too many XP levels to
			# reach reliably in an automated playtest. Debug-only escape hatch so the harness can
			# set the level directly and verify the multi-fireball VFX; inert in real builds (this
			# whole channel only exists behind the agent gate — see agent_bridge.gd).
			game.fire_wand_level = int(cmd.get("value", 6))
		"force_evolution":
			# A weapon evolution (a maxed weapon fused with its paired passive) is the run's
			# rarest, biggest power spike — normally many level-ups deep. Debug-only escape hatch
			# so the harness can fast-forward one weapon to max + its passive; the very next
			# level-up then offers the evolution card (always slot 1), letting a picked upgrade_1
			# verify the "WEAPON EVOLVED!" banner. Defaults to Whip -> Bloody Tear. Inert in real
			# builds (this whole channel only exists behind the agent gate — see agent_bridge.gd).
			game.force_evolution_ready(str(cmd.get("value", "whip")))
		"force_low_health":
			# The low-health warning vignette (hud.gd _refresh_lowhp) only shows once HP drops below
			# LOWHP_THRESHOLD (30%) — hard to reach on demand in an automated playtest without dying.
			# Debug-only escape hatch: set HP to `value` (a fraction of max, default 12%) so the harness
			# can verify the pulsing crimson edge; inert in real builds (agent gate only — agent_bridge.gd).
			var lp := game.player
			if lp != null and is_instance_valid(lp):
				lp.health = clampf(float(cmd.get("value", 0.12)) * lp.max_health, 1.0, lp.max_health)
		_:
			AgentBridge.default_command(cmd)
