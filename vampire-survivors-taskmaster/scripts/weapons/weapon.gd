class_name VSWeapon
extends Node2D
## Auto-attacking weapon mounted on the player. On a timer it fires a projectile at the
## nearest enemy in range. The core "you move, the weapon fights" Vampire Survivors loop.

const RANGE := 620.0
const SPREAD := 0.244   # ~14 deg between shots when projectile_count > 1

var run: VSRun
# Upgradeable stats (see VSRun.apply_upgrade): Haste lowers fire_interval, Power raises
# damage, Multishot raises projectile_count.
var fire_interval := 0.6
var damage := 2.0
var projectile_count := 1
var _cd := 0.0

func _process(delta: float) -> void:
	if run == null or run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		var t := _nearest_enemy()
		if t != null:
			_fire_at(t)
			_cd = fire_interval

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
	# Fire projectile_count shots in a small fan centred on the aim line (Multishot upgrade).
	var base := (t.position - global_position).angle()
	var n := maxi(1, projectile_count)
	for i in n:
		var offset := 0.0
		if n > 1:
			offset = SPREAD * (float(i) - float(n - 1) * 0.5)
		var p := VSProjectile.new()
		p.position = global_position
		p.dir = Vector2.from_angle(base + offset)
		p.damage = damage
		p.run = run
		run.add_child(p)
	AgentBridge.emit_event("sfx_played", {"name": "shoot"})
	Sfx.play("shoot")
