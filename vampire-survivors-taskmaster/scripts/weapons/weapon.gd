class_name VSWeapon
extends Node2D
## Auto-attacking weapon mounted on the player. On a timer it fires at the nearest enemy
## in range. The core "you move, the weapon fights" Vampire Survivors loop. Fire rate,
## damage, and projectile count come from VSRun stats mutated by level-up upgrades.

const RANGE := 620.0
const SPREAD := 0.14            # radians between extra multishot projectiles

# Evolved (Holy Wand) profile — applied when run.projectile_evolved: the Magic Wand becomes a
# relentless piercing storm. Gated on Multishot being maxed + Haste owned, so this is the run's
# payoff for maxing the projectile line. Mirrors the King Bible / Bloody Tear evolution pattern.
const EVOLVED_EXTRA_SHOTS := 2      # +2 bolts on top of the current multishot count
const EVOLVED_DAMAGE_MULT := 1.6
const EVOLVED_CD_MULT := 0.6        # fires markedly faster
const EVOLVED_PIERCE := 3           # each bolt passes through 3 further enemies

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
			var interval := run.weapon_fire_interval
			if run.projectile_evolved:
				interval *= EVOLVED_CD_MULT
			_cd = interval

func _nearest_enemy() -> VSEnemy:
	var best: VSEnemy = null
	var best_d := RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		# The "enemies" group also holds destructible props (candelabra); the aimed weapon
		# only targets real enemies so it never wastes bolts on scenery.
		if not e is VSEnemy:
			continue
		var d: float = (e.position - global_position).length()
		if d < best_d:
			best_d = d
			best = e
	return best

func _fire_at(t: VSEnemy) -> void:
	var base := (t.position - global_position).normalized()
	var evolved := run.projectile_evolved
	var count: int = maxi(1, run.weapon_count)
	if evolved:
		count += EVOLVED_EXTRA_SHOTS
	# Fan extra multishot projectiles symmetrically around the aim direction.
	for i in count:
		var offset := (i - (count - 1) * 0.5) * SPREAD
		var p := VSProjectile.new()
		p.position = global_position
		p.dir = base.rotated(offset)
		p.damage = run.weapon_damage * run.might_mult()
		if evolved:
			p.damage *= EVOLVED_DAMAGE_MULT
			p.pierce = EVOLVED_PIERCE
		p.run = run
		run.add_child(p)
	AgentBridge.emit_event("sfx_played", {"name": "shoot"})
