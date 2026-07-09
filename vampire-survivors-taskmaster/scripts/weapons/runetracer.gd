class_name VSRunetracer
extends Node2D
## A ricochet weapon — the classic Vampire Survivors "Runetracer": on its cooldown it hurls a
## spinning rune polyhedron that BOUNCES off the edges of the arena and ping-pongs straight through
## the horde, striking every enemy it passes (with a short per-enemy re-hit delay so a single rune
## racks up many hits as it caroms around). Unlike the aimed Magic Wand, the melee Whip, the static
## Garlic aura, the orbiting King Bible, the field-wide Lightning smites, and the forward-thrown
## Knife, the Runetracer is fire-and-forget area denial that owns the WHOLE playfield for its lifetime
## — a bouncing hazard that thins the swarm from angles nothing else covers. Mounted on the player,
## enabled/scaled by run.runetracer_level (0 = not yet picked: inert). The slice's seventh,
## mechanically-distinct weapon (per the GDD's designed 8-weapon set).

## Lv1 base damage lives in res://data/balance.csv ("runetracer_base_damage", wiki base 10); the flat
## per-level bonus on top of it lives per-level in data/runetracer_levels.csv (see LEVELS_CSV below).
static var BASE_DAMAGE := BalanceData.get_value("runetracer_base_damage", 10.0)
## Base cooldown + per-level tighten live in res://data/balance.csv ("runetracer_base_interval" /
## "runetracer_interval_per_level") so a designer can retune fire rate without touching this script.
## (The wiki level table only governs amount/damage/speed/duration — cadence stays a balance knob.)
static var BASE_INTERVAL := BalanceData.get_value("runetracer_base_interval", 3.0)
static var INTERVAL_PER_LEVEL := BalanceData.get_value("runetracer_interval_per_level", 0.15)
static var MIN_INTERVAL := BalanceData.get_value("runetracer_min_interval", 1.4)
static var BASE_SPEED := BalanceData.get_value("runetracer_base_speed", 260.0)  # px/sec at 100% speed_mult — a brisk carom, not a bullet

## Per-level level-up table (wiki Runetracer.md "Levels"), editable in res://data/runetracer_levels.csv —
## one row per level with independently-tunable columns so a designer can retune ANY single level
## without touching this script. Values are cumulative absolutes (each row fully describes the rune at
## that level): amount (runes per volley, wiki 1→3), bonus_damage (flat added on top of BASE_DAMAGE,
## +5 on L2/L3/L5/L6 → +20 total for wiki max 30), speed_mult (scales BASE_SPEED, wiki 100%→140% via
## +20% on L2/L5), duration (bounce lifetime in seconds, wiki 2.25→3.35 via +0.3 on L3/L6, +0.5 on L8).
const LEVELS_CSV := "res://data/runetracer_levels.csv"
static var _levels: Dictionary = {}   # int level -> {"amount": int, "bonus_damage": float, "speed_mult": float, "duration": float}
static var _levels_loaded := false

# NO FUTURE (evolved): the same bouncing rune, but MORE of them, caroming faster and longer,
# each a bigger, harder-hitting hazard — set once run.runetracer_evolved flips (see run.gd).
static var EVO_BONUS_AMOUNT: int = int(BalanceData.get_value("runetracer_evo_bonus_amount", 2.0))          # extra runes per volley on top of the level count…
static var EVO_MAX_AMOUNT: int = int(BalanceData.get_value("runetracer_evo_max_amount", 6.0))            # …raising the cap so a maxed NO FUTURE saturates the arena
static var EVO_DAMAGE_MULT := BalanceData.get_value("runetracer_evo_damage_mult", 1.6)         # each rune bites noticeably harder
static var EVO_SPEED_MULT := BalanceData.get_value("runetracer_evo_speed_mult", 1.35)         # a faster carom covers the field quicker
static var EVO_LIFE_BONUS := BalanceData.get_value("runetracer_evo_life_bonus", 2.0)          # runes linger far longer, ping-ponging through more of the horde
static var EVO_RADIUS := BalanceData.get_value("runetracer_evo_radius", 14.0)             # a fatter rune (base 9) sweeps a wider lane through the swarm

var run: VSRun
var _cd := 0.0

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.runetracer_level
	if lvl <= 0:
		return
	if run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		_fire(lvl)
		_cd = _interval(lvl)

## Cooldown between volleys, shrinking modestly with level (never below MIN_INTERVAL so a maxed
## Runetracer stays a periodic hazard rather than a constant screen-full of runes).
func _interval(lvl: int) -> float:
	return maxf(MIN_INTERVAL, BASE_INTERVAL - INTERVAL_PER_LEVEL * float(lvl - 1)) * run.haste_mult()

## Runes per volley: the per-level table's amount (wiki 1→3), plus the evolution's fan bonus (which
## also lifts the cap so a maxed NO FUTURE saturates the arena).
func _amount(lvl: int) -> int:
	var evolved: bool = run != null and run.runetracer_evolved
	var amount := int(_row(lvl)["amount"])
	if evolved:
		amount = mini(amount + EVO_BONUS_AMOUNT, EVO_MAX_AMOUNT)
	return amount

## One volley: launch `amount` runes from the player in evenly-spread directions so multiple runes
## fan out to different corners of the arena rather than overlapping.
func _fire(lvl: int) -> void:
	var evolved: bool = run.runetracer_evolved
	var row := _row(lvl)
	var dmg := (BASE_DAMAGE * run.damage_variance() + float(row["bonus_damage"])) * run.might_mult() * run.power_mult()
	# speed_mult is the wiki per-level Speed (100%→140%); Bracer passive speeds the carom up on top.
	var speed := BASE_SPEED * float(row["speed_mult"]) * run.projectile_speed_mult
	var life := float(row["duration"])
	if evolved:
		dmg *= EVO_DAMAGE_MULT
		speed *= EVO_SPEED_MULT
		life += EVO_LIFE_BONUS
	var count := _amount(lvl)
	var base_ang := randf() * TAU
	for i in count:
		var ang := base_ang + TAU * float(i) / float(count)
		var b := Bolt.new()
		b.position = global_position
		b.vel = Vector2(cos(ang), sin(ang)) * speed
		b.damage = dmg
		b.life = life
		b.life0 = life
		b.run = run
		if evolved:
			b.radius = EVO_RADIUS
		run.add_child(b)
	AgentBridge.emit_event("sfx_played", {"name": "runetracer"})


## The per-level tuning row for `lvl`, from data/runetracer_levels.csv. Levels past the table (Limit
## Break) clamp to the highest defined level; a missing CSV reconstructs the wiki deltas so the rune
## never breaks.
static func _row(lvl: int) -> Dictionary:
	_ensure_levels()
	if _levels.has(lvl):
		return _levels[lvl]
	if _levels.is_empty():
		# Reconstruct the wiki deltas: +1 amount on L4/L7, +5 damage on L2/L3/L5/L6,
		# +20% speed on L2/L5, duration 2.25 +0.3 on L3/L6 +0.5 on L8.
		var amount := 1 + (1 if lvl >= 4 else 0) + (1 if lvl >= 7 else 0)
		var bonus := (5.0 if lvl >= 2 else 0.0) + (5.0 if lvl >= 3 else 0.0) + (5.0 if lvl >= 5 else 0.0) + (5.0 if lvl >= 6 else 0.0)
		var speed_mult := 1.0 + (0.2 if lvl >= 2 else 0.0) + (0.2 if lvl >= 5 else 0.0)
		var duration := 2.25 + (0.3 if lvl >= 3 else 0.0) + (0.3 if lvl >= 6 else 0.0) + (0.5 if lvl >= 8 else 0.0)
		return {"amount": amount, "bonus_damage": bonus, "speed_mult": speed_mult, "duration": duration}
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
		push_warning("VSRunetracer: cannot open %s (err %d)" % [LEVELS_CSV, FileAccess.get_open_error()])
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
			"speed_mult": r[int(col.get("speed_mult", 3))].strip_edges().to_float(),
			"duration": r[int(col.get("duration", 4))].strip_edges().to_float(),
		}
	f.close()


## The bouncing rune projectile. Lives in world space as a child of the run (not the player) so it
## caroms independently, reflecting off the arena bounds and piercing every enemy it overlaps. A
## per-enemy re-hit cooldown lets one rune strike the same enemy repeatedly as it passes back through.
class Bolt:
	extends Node2D

	static var BASE_RADIUS := BalanceData.get_value("runetracer_hit_radius", 9.0)        # rune's own hit radius (NO FUTURE runes set a fatter one)
	static var REHIT := BalanceData.get_value("runetracer_rehit_interval", 0.45)            # seconds before a rune may strike the same enemy again
	static var SPRITE_SCALE := BalanceData.get_value("runetracer_sprite_scale", 0.9)

	var vel := Vector2.RIGHT
	var damage := 10.0
	var life := 4.0
	var life0 := 4.0
	var radius := BASE_RADIUS      # hit radius; the evolved weapon enlarges it per-rune
	var run: VSRun
	var _hit_cd := {}              # enemy -> seconds until it can be struck again
	var _sprite: Sprite2D
	var _spin := 0.0

	func _ready() -> void:
		add_to_group("projectiles")
		z_index = 1
		_sprite = Sprite2D.new()
		_sprite.texture = load("res://art/weapon_runetracer.png")
		# Scale the sprite with the hit radius so a fatter NO FUTURE rune also reads bigger.
		var s := SPRITE_SCALE * (radius / BASE_RADIUS)
		_sprite.scale = Vector2(s, s)
		add_child(_sprite)

	func _process(delta: float) -> void:
		if run == null:
			return
		# Freeze with the game during level-up / after the run ends (mirrors every other weapon).
		if run.phase != "playing":
			return
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		position += vel * delta
		# Reflect off the arena bounds so the rune stays in play and ping-pongs across the field.
		var h: Vector2 = run.arena_half
		if position.x < -h.x:
			position.x = -h.x
			vel.x = absf(vel.x)
		elif position.x > h.x:
			position.x = h.x
			vel.x = -absf(vel.x)
		if position.y < -h.y:
			position.y = -h.y
			vel.y = absf(vel.y)
		elif position.y > h.y:
			position.y = h.y
			vel.y = -absf(vel.y)
		# Tick down each enemy's re-hit timer.
		for e in _hit_cd.keys():
			_hit_cd[e] = float(_hit_cd[e]) - delta
		# Pierce: strike every overlapping enemy that's off its re-hit cooldown.
		for e in get_tree().get_nodes_in_group("enemies"):
			# The "enemies" group also holds destructible props (candelabra); only strike real enemies.
			if not e is VSEnemy:
				continue
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			if (e.position - position).length() < radius + er:
				if float(_hit_cd.get(e, 0.0)) > 0.0:
					continue
				e.hit(damage, position)
				_hit_cd[e] = REHIT
		# Spin the polyhedron as it flies, and fade it out over its final half-second.
		_spin += delta * 6.0
		_sprite.rotation = _spin
		_sprite.modulate = Color(1, 1, 1, clampf(life / 0.5, 0.0, 1.0))
