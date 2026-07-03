class_name VSWeapon
extends Node2D
## Auto-attacking weapon mounted on the player. On a timer it fires at the nearest enemy
## in range. The core "you move, the weapon fights" Vampire Survivors loop. Fire rate,
## damage, and projectile count come from VSRun stats mutated by level-up upgrades.

const RANGE := 620.0
const SPREAD := 0.14            # radians between extra multishot projectiles

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
			_cd = run.weapon_fire_interval

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
	var base := (t.position - global_position).normalized()
	var count: int = maxi(1, run.weapon_count)
	# Fan extra multishot projectiles symmetrically around the aim direction.
	for i in count:
		var offset := (i - (count - 1) * 0.5) * SPREAD
		var p := VSProjectile.new()
		p.position = global_position
		p.dir = base.rotated(offset)
		p.damage = run.weapon_damage
		p.run = run
		run.add_child(p)
	AgentBridge.emit_event("sfx_played", {"name": "shoot"})
