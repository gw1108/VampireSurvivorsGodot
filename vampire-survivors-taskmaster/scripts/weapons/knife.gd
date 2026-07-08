class_name VSKnife
extends Node2D
## A directional fast-fire weapon — the classic Vampire Survivors "Knife": on a short cooldown
## it hurls fast VSProjectiles straight in the direction the player is MOVING, no aiming. Unlike
## the Magic Wand (auto-aims the nearest enemy), the Whip (melee arc), the Garlic (static aura),
## the King Bible (orbit), and the Lightning Ring (random smites), the Knife rewards steering the
## player into the horde: it fires where you point, fast and hard, punching a lane through whatever
## you run toward. Facing tracks the full movement heading — 8 directions with WASD (straight up on
## W, down-left on A+S, …) or the precise angle for analog stick/mouse steering — and persists
## while standing still, so an idle player throws the way they last ran. Mounted on the player,
## enabled/scaled by run.knife_level (0 = not yet picked: no throws, inert). The slice's sixth,
## mechanically-distinct weapon.
##
## Per the wiki, the knives from Amount are fired in a short VOLLEY in parallel (all along the same
## heading), spaced apart in time by the per-level Projectile Interval — NOT fanned out in space.
## Levels 4/6/8 tighten that interval, grouping each volley into a denser stream of blades.

## Lv1 base damage lives in res://data/balance.csv ("knife_base_damage", wiki base 6.5); the flat
## per-level bonus on top of it lives per-level in data/knife_levels.csv (see LEVELS_CSV below).
static var BASE_DAMAGE := BalanceData.get_value("knife_base_damage", 6.5)
## Cooldown between VOLLEYS lives in res://data/balance.csv ("knife_base_interval"). This is the
## wait between throws; per the wiki it is a flat 1.0s that does NOT scale per level — only the
## intra-volley "proj_interval" column below (which spaces knives WITHIN one throw) tightens with
## level, on L4/6/8.
static var BASE_INTERVAL := BalanceData.get_value("knife_base_interval", 1.0)
const KNIFE_SPEED := 540.0            # faster than the aimed wand's bolt — the Knife's signature
const KNIFE_LIFE := 1.1

## Per-level level-up table (wiki Knife.md "Levels"), editable in res://data/knife_levels.csv —
## one row per level with independently-tunable columns so a designer can retune ANY single level
## without touching this script. Values are cumulative absolutes (each row fully describes the
## knife at that level): amount (knives per volley), bonus_damage (flat added on top of BASE_DAMAGE),
## pierce (enemies each knife can hit, wiki base 1), proj_interval (seconds between knives WITHIN a
## volley). The wiki pattern is: amount 1→6 (adds a knife on L2,3,4,6,7), +5 damage on L3 & L7,
## pierce 1→3 (+1 on L5 & L8), and proj_interval 0.10→0.04 (tightens on L4/L6/L8).
const LEVELS_CSV := "res://data/knife_levels.csv"
static var _levels: Dictionary = {}   # int level -> {"amount": int, "bonus_damage": float, "pierce": int, "proj_interval": float}
static var _levels_loaded := false

# Evolved (Thousand Edges) profile — applied when run.knife_evolved: the Knife's cadence
# collapses toward a continuous stream (volley interval scaled right down, floor lowered far), it
# hurls a wider volley per throw, and each blade bites much harder. The payoff for maxing the
# Knife alongside Haste. Mirrors the Whip / King Bible / Holy Wand evolution pattern.
const EVOLVED_INTERVAL_MULT := 0.30   # ~a third the cadence — a near-solid stream of blades
const EVOLVED_MIN_INTERVAL := 0.14    # far lower floor so late Thousand Edges barely pauses
const EVOLVED_AMOUNT_BONUS := 3       # +3 knives per volley over the base amount
const EVOLVED_DAMAGE_MULT := 1.7      # each blade bites much deeper

var run: VSRun
var _cd := 0.0
var _facing := Vector2.RIGHT   # latched full movement heading (unit vector); throws travel along it
# In-flight volley state: knives fire one at a time, spaced by _burst_interval, all along the
# heading/stats latched when the volley started (a volley is parallel, per the wiki).
var _burst_left := 0
var _burst_cd := 0.0
var _burst_dir := Vector2.RIGHT
var _burst_dmg := 0.0
var _burst_pierce := 0
var _burst_interval := 0.10

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.knife_level
	if lvl <= 0:
		return
	if run.phase != "playing":
		return
	# Track the full movement heading so the knife throws exactly the way the player moves — 8
	# directions with WASD (straight up on W alone, down-left on A+S, …), or the precise angle
	# for analog stick/mouse steering. get_vector is already normalized + deadzoned. The last
	# non-zero heading wins and persists while standing still, so an idle player still throws the
	# direction they last ran.
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if mv.length_squared() > 0.01:
		_facing = mv.normalized()
	# Drain any in-flight volley: fire the next knife(s) whose spacing has elapsed this frame.
	if _burst_left > 0:
		_burst_cd -= delta
		while _burst_left > 0 and _burst_cd <= 0.0:
			_fire_one()
			_burst_left -= 1
			_burst_cd += _burst_interval
	# Start a new volley once the between-throw cooldown expires and the last volley has emptied.
	_cd -= delta
	if _cd <= 0.0 and _burst_left <= 0:
		_start_burst(lvl)
		_cd = _interval()

## Cooldown between VOLLEYS. Per the wiki this is a flat base (1.0s) that does not scale per level —
## only the intra-volley proj_interval tightens with level. Evolution and Haste still modulate it.
func _interval() -> float:
	var base := BASE_INTERVAL
	if _is_evolved():
		return maxf(EVOLVED_MIN_INTERVAL, base * EVOLVED_INTERVAL_MULT) * run.haste_mult()
	return base * run.haste_mult()

## True once the run has evolved Knife into Thousand Edges.
func _is_evolved() -> bool:
	return run != null and run.knife_evolved

## Knives per volley: the per-level table's amount, plus the evolution's fan bonus.
func _amount(lvl: int) -> int:
	var amount := int(_row(lvl)["amount"])
	if _is_evolved():
		amount += EVOLVED_AMOUNT_BONUS
	return amount

## Begin one volley: latch the heading, damage, pierce and intra-volley spacing, then fire the
## first knife immediately; the rest stream out over the following frames (see _process).
func _start_burst(lvl: int) -> void:
	var row := _row(lvl)
	_burst_dir = _facing
	var dmg := (BASE_DAMAGE * run.damage_variance() + float(row["bonus_damage"])) * run.might_mult() * run.power_mult()
	if _is_evolved():
		dmg *= EVOLVED_DAMAGE_MULT
	_burst_dmg = dmg
	# CSV pierce is the wiki "enemies hit" (base 1); VSProjectile.pierce counts the EXTRA enemies
	# passed through beyond the first, so subtract one.
	_burst_pierce = maxi(0, int(row["pierce"]) - 1)
	_burst_interval = float(row["proj_interval"])
	_burst_left = _amount(lvl)
	if _burst_left > 0:
		_fire_one()
		_burst_left -= 1
		_burst_cd = _burst_interval
	AgentBridge.emit_event("sfx_played", {"name": "knife"})

## Hurl a single fast bolt along the latched volley heading.
func _fire_one() -> void:
	var p := VSProjectile.new()
	p.position = global_position
	p.dir = _burst_dir
	p.speed = KNIFE_SPEED * run.projectile_speed_mult   # Bracer passive speeds the knife up
	p.life = KNIFE_LIFE
	p.damage = _burst_dmg
	p.pierce = _burst_pierce
	p.run = run
	run.add_child(p)

## The per-level tuning row for `lvl`, from data/knife_levels.csv. Levels past the table (Limit
## Break) clamp to the highest defined level; a missing CSV reconstructs the wiki deltas so the
## knife never breaks.
static func _row(lvl: int) -> Dictionary:
	_ensure_levels()
	if _levels.has(lvl):
		return _levels[lvl]
	if _levels.is_empty():
		# Reconstruct the wiki deltas: +1 amount on L2/3/4/6/7, +5 damage on L3/7,
		# +1 pierce on L5/8, interval 0.10 tightening -0.02 on L4/6/8.
		var amount := 1
		for al in [2, 3, 4, 6, 7]:
			if lvl >= al:
				amount += 1
		var bonus := (5.0 if lvl >= 3 else 0.0) + (5.0 if lvl >= 7 else 0.0)
		var pierce := 1 + (1 if lvl >= 5 else 0) + (1 if lvl >= 8 else 0)
		var interval := 0.10 - (0.02 if lvl >= 4 else 0.0) - (0.02 if lvl >= 6 else 0.0) - (0.02 if lvl >= 8 else 0.0)
		return {"amount": amount, "bonus_damage": bonus, "pierce": pierce, "proj_interval": interval}
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
		push_warning("VSKnife: cannot open %s (err %d)" % [LEVELS_CSV, FileAccess.get_open_error()])
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
			"proj_interval": r[int(col.get("proj_interval", 4))].strip_edges().to_float(),
		}
	f.close()
