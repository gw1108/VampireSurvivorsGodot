class_name VSWeapon
extends Node2D
## Auto-attacking weapon mounted on the player. On a timer it fires a projectile at the
## nearest enemy in range. The core "you move, the weapon fights" Vampire Survivors loop.

const FIRE_INTERVAL := 0.6
const RANGE := 620.0

var run: VSRun
var _cd := 0.0

func _process(delta: float) -> void:
	if run == null or run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		var t := _nearest_enemy()
		if t != null:
			_fire_at(t)
			_cd = FIRE_INTERVAL

func _nearest_enemy() -> VSEnemy:
	var best: VSEnemy = null
	var best_d := RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = (e.position - global_position).length()
		if d < best_d:
			best_d = d
			best = e
	return best

func _fire_at(t: VSEnemy) -> void:
	var p := VSProjectile.new()
	p.position = global_position
	p.dir = (t.position - global_position).normalized()
	p.run = run
	run.add_child(p)
	AgentBridge.emit_event("sfx_played", {"name": "shoot"})
