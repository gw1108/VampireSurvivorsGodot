class_name VSWeapon
extends Node2D
## Auto-attacking weapon mounted on the player: the Magic Wand. On a timer it fires at the
## nearest enemy in range. The core "you move, the weapon fights" Vampire Survivors loop. Its
## amount (bolts per volley), flat bonus damage, pierce, and cooldown all come from its own
## per-level table (data/magic_wand_levels.csv, keyed by run.weapon_level) exactly like the Whip
## and Knife — leveling the wand is a wiki-faithful step through that table (base 10 dmg / 1 bolt /
## pierce 1 / 1.2s → max 30 dmg / 4 bolts / pierce 2 / 1.0s), NOT a raw projectile-per-pick count.
## Inert until run.weapon_level > 0 (the "Multishot" pick levels the wand and grants its first shot;
## Antonio does not start with it — his starting weapon is the Whip, see VSRun._init_character).

static var RANGE := BalanceData.get_value("magic_wand_range", 620.0)   # aim-acquire radius: nearest enemy within this is targeted
const SPREAD := 0.14            # radians between extra multishot projectiles

## Lv1 base damage lives in res://data/balance.csv ("magic_wand_base_damage", wiki base 10); the flat
## per-level bonus on top of it lives per-level in data/magic_wand_levels.csv (see LEVELS_CSV below).
## Its own leveling is deliberately independent of the Power passive — the +/-50% variance rolls on
## this base, and Power/Might reach it only through the might_mult()/power_mult() ratios in _fire_at,
## the same as every other weapon (untangled from the old weapon_damage accumulation).
static var BASE_DAMAGE := BalanceData.get_value("magic_wand_base_damage", 10.0)

## Per-level level-up table (wiki Magic_Wand.md "Levels"), editable in res://data/magic_wand_levels.csv —
## one row per level with independently-tunable columns so a designer can retune ANY single level
## without touching this script. Values are cumulative absolutes (each row fully describes the wand at
## that level): amount (bolts per volley), bonus_damage (flat added on top of BASE_DAMAGE), pierce
## (enemies each bolt can hit, wiki base 1), cooldown (seconds between volleys). The wiki pattern is:
## amount 1→4 (adds a bolt on L2/4/6), +10 damage on L5 & L8, pierce 1→2 (+1 on L7), and cooldown
## 1.2→1.0 (−0.2 at L3).
const LEVELS_CSV := "res://data/magic_wand_levels.csv"
static var _levels: Dictionary = {}   # int level -> {"amount": int, "bonus_damage": float, "pierce": int, "cooldown": float}
static var _levels_loaded := false

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
	if run == null or run.weapon_level <= 0:
		return
	if run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		var t := _nearest_enemy()
		if t != null:
			_fire_at(t)
			# Cooldown is the wand's own per-level column; Empty Tome (haste_mult) reaches it here
			# on top, same as every other weapon.
			var interval := float(_row(run.weapon_level)["cooldown"]) * run.haste_mult()
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
	var row := _row(run.weapon_level)
	var count: int = maxi(1, int(row["amount"]))
	if evolved:
		count += EVOLVED_EXTRA_SHOTS
	# CSV pierce is the wiki "enemies hit" (base 1); VSProjectile.pierce counts the EXTRA enemies
	# passed through beyond the first, so subtract one.
	var pierce: int = maxi(0, int(row["pierce"]) - 1)
	# Roll +/-50% variance on the base only; the per-level flat bonus is added after. might_mult()
	# (Antonio's ramp) and power_mult() (Spinach + meta Might) then scale it — identical to the Whip
	# and Knife, so the wand's own leveling stays distinct from the Power/Might multiplier.
	var dmg := (BASE_DAMAGE * run.damage_variance() + float(row["bonus_damage"])) * run.might_mult() * run.power_mult()
	# Fan extra multishot projectiles symmetrically around the aim direction.
	for i in count:
		var offset := (i - (count - 1) * 0.5) * SPREAD
		var p := VSProjectile.new()
		p.position = global_position
		p.dir = base.rotated(offset)
		p.speed *= run.projectile_speed_mult
		p.damage = dmg
		p.pierce = pierce
		if evolved:
			p.damage *= EVOLVED_DAMAGE_MULT
			p.pierce = EVOLVED_PIERCE
		p.run = run
		run.add_child(p)
	AgentBridge.emit_event("sfx_played", {"name": "shoot"})

## The per-level stat row for `level` from data/magic_wand_levels.csv, for callers outside the weapon
## that need the wand's current stats (e.g. VSRun mirrors amount/damage/cooldown into the HUD build
## readout). Clamps to level >= 1.
static func wand_level_stats(level: int) -> Dictionary:
	return _row(maxi(1, level))

## The per-level tuning row for `lvl`, from data/magic_wand_levels.csv. Levels past the table (Limit
## Break) clamp to the highest defined level; a missing CSV reconstructs the wiki deltas so the wand
## never breaks.
static func _row(lvl: int) -> Dictionary:
	_ensure_levels()
	if _levels.has(lvl):
		return _levels[lvl]
	if _levels.is_empty():
		# Reconstruct the wiki deltas: +1 amount on L2/4/6, +10 damage on L5/8, +1 pierce on L7,
		# cooldown 1.2 dropping to 1.0 at L3.
		var amount := 1 + (1 if lvl >= 2 else 0) + (1 if lvl >= 4 else 0) + (1 if lvl >= 6 else 0)
		var bonus := (10.0 if lvl >= 5 else 0.0) + (10.0 if lvl >= 8 else 0.0)
		var pierce := 1 + (1 if lvl >= 7 else 0)
		var cooldown := 1.0 if lvl >= 3 else 1.2
		return {"amount": amount, "bonus_damage": bonus, "pierce": pierce, "cooldown": cooldown}
	var keys := _levels.keys()
	keys.sort()
	return _levels[keys[keys.size() - 1]]

## Parse the per-level table once. Column-name driven (falls back to fixed positions) so the CSV
## can carry extra tuning columns without breaking the loader.
static func _ensure_levels() -> void:
	if _levels_loaded:
		return
	_levels_loaded = true
	var f := FileAccess.open(LEVELS_CSV, FileAccess.READ)
	if f == null:
		push_warning("VSWeapon: cannot open %s (err %d)" % [LEVELS_CSV, FileAccess.get_open_error()])
		return
	var header := f.get_csv_line()
	var col := {}
	for i in header.size():
		col[header[i].strip_edges()] = i
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < 2 or r[0].strip_edges() == "":
			continue
		var lvl := r[int(col.get("level", 0))].strip_edges().to_int()
		_levels[lvl] = {
			"amount": r[int(col.get("amount", 1))].strip_edges().to_int(),
			"bonus_damage": r[int(col.get("bonus_damage", 2))].strip_edges().to_float(),
			"pierce": r[int(col.get("pierce", 3))].strip_edges().to_int(),
			"cooldown": r[int(col.get("cooldown", 4))].strip_edges().to_float(),
		}
	f.close()
