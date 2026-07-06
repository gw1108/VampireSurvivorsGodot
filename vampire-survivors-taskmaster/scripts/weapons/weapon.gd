class_name VSWeapon
extends Node2D
## Auto-attacking weapon mounted on the player: the Magic Wand. On a timer it fires at the
## nearest enemy in range. The core "you move, the weapon fights" Vampire Survivors loop. Fire
## rate, damage, and projectile count come from VSRun stats mutated by level-up upgrades.
## Inert until run.weapon_count > 0 (the "Multishot" pick grants the wand and its first shot;
## Antonio does not start with it — his starting weapon is the Whip, see VSRun._init_character).

const RANGE := 620.0
const SPREAD := 0.14            # radians between extra multishot projectiles

## The wand's level-1 base damage, read from the same balance key run.weapon_damage seeds from.
## run.weapon_damage accumulates base + flat growth (Power picks, meta Might) into one stat, so we
## subtract this base back out to apply the +/-50% variance to ONLY the base (see run.damage_variance).
static var BASE_DAMAGE := BalanceData.get_value("magic_wand_base_damage", 2.0)

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
	if run == null or run.weapon_count <= 0:
		return
	if run.phase != "playing":
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
		p.speed *= run.projectile_speed_mult
		# Roll +/-50% variance on the base only; flat growth (weapon_damage above the base) is added after.
		# spinach_mult() folds in the Spinach (Power) passive's +10%/pick Might so the wand benefits
		# from it too — meta Might is already in weapon_damage, so we deliberately skip power_mult() here.
		var flat: float = maxf(0.0, run.weapon_damage - BASE_DAMAGE)
		p.damage = (BASE_DAMAGE * run.damage_variance() + flat) * run.might_mult() * run.spinach_mult()
		if evolved:
			p.damage *= EVOLVED_DAMAGE_MULT
			p.pierce = EVOLVED_PIERCE
		p.run = run
		run.add_child(p)
	AgentBridge.emit_event("sfx_played", {"name": "shoot"})
