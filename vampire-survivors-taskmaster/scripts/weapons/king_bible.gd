class_name VSKingBible
extends Node2D
## An orbiting weapon — the classic Vampire Survivors "King Bible": holy books that
## circle the player, damaging any enemy they sweep through. Unlike the projectile
## (aimed, ranged), the Garlic (a static aura), and the Whip (a directional burst),
## the Bible is a *rotating melee* — constant area denial that rewards kiting the swarm
## through the orbit. Mounted on the player, enabled/scaled by run.bible_level
## (0 = not yet picked: no books, inert). The slice's fourth, mechanically-distinct weapon.

# Tuned by eye against the horde (see _debug_bible_shot playtest): the ring is kept
# tight enough to hug the player so enemies must cross the books to reach them (a wide
# ring let fast enemies camp inside, untouched), each book sweeps a wide band so few
# enemies slip through the gaps, and the orbit spins briskly so it reads as active area
# denial. Damage tracks the wiki (base ~10 scaled, ~30 at max level).
static var BASE_ORBIT_RADIUS := BalanceData.get_value("king_bible_orbit_radius", 88.0)
static var ANGULAR_SPEED := BalanceData.get_value("king_bible_angular_speed", 3.6)          # rad/s the books orbit the player at Lv1 (~0.57 rev/s), scaled by the per-level speed_mult
static var BOOK_HIT_RADIUS := BalanceData.get_value("king_bible_book_hit_radius", 27.0)       # how close a book must pass to strike an enemy
## Min seconds between a book's hits (avoids per-frame drain) lives in res://data/balance.csv
## ("king_bible_tick_interval") so a designer can retune fire rate without touching this script.
static var TICK_INTERVAL := BalanceData.get_value("king_bible_tick_interval", 0.35)

## Per-level level-up table (wiki King_Bible.md "Levels"), editable in res://data/king_bible_levels.csv —
## one row per level with independently-tunable columns so a designer can retune ANY single level without
## touching this script. Values are cumulative absolutes (each row fully describes the Bible at that level):
## amount (books orbiting), bonus_damage (flat added on top of BASE_DAMAGE), area_mult (scales orbit radius),
## speed_mult (scales ANGULAR_SPEED). The wiki pattern is: L2/L5/L8 +1 book; L3/L6 +25% area & +30% speed;
## L4/L7 +10 damage (max = 4 books, +20 damage, 150% area, 160% speed → base-10 Bible peaks at 30 damage).
const LEVELS_CSV := "res://data/king_bible_levels.csv"
static var _levels: Dictionary = {}   # int level -> {"amount": int, "bonus_damage": float, "area_mult": float, "speed_mult": float}
static var _levels_loaded := false
## Lv1 base damage lives in res://data/balance.csv ("king_bible_base_damage", wiki base 10); the flat
## per-level bonus on top of it lives per-level in data/king_bible_levels.csv (see LEVELS_CSV above).
static var BASE_DAMAGE := BalanceData.get_value("king_bible_base_damage", 10.0)
static var MAX_BOOKS: int = int(BalanceData.get_value("king_bible_max_books", 4.0))
static var BOOK_SCALE := BalanceData.get_value("king_bible_book_scale", 0.5)             # 64px source -> ~32px book, legible beside enemies
const BOOK_TEX := "res://art/up_bible.png"

# The source up_bible.png is a near-full-frame, dark-brown book (avg RGB ~66,37,25) that
# vanished into the tan skeleton/zombie horde during playtest. In Vampire Survivors the
# King Bible books are bright BLUE. A plain modulate only multiplies (dark * blue = dark),
# and the book fills the whole frame so an outside outline would clip — so instead we recolor
# in a tiny canvas shader: map the book's luminance onto a bright blue, preserving its internal
# page/cover shading, so each book reads instantly as a glowing blue orbit against the crowd.
const BOOK_TINT := Color(0.30, 0.58, 1.0)   # VS holy-book blue
const _BOOK_SHADER := "shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.30, 0.58, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float b = clamp(l * 1.6 + 0.35, 0.0, 1.0);   // lift the dark book into a bright blue
	COLOR = vec4(tint.rgb * b, c.a);
}"

# Evolved (Unholy Vespers) profile — applied when run.bible_evolved: a full ring of extra
# books orbiting faster, striking more often, harder, and with a wider reach. Gated on the
# weapon already being maxed, so this is the run's payoff for maxing Bible + owning Power.
static var EVOLVED_EXTRA_BOOKS: int = int(BalanceData.get_value("king_bible_evolved_extra_books", 2.0))      # 4 -> 6 books, a near-solid wall
static var EVOLVED_DAMAGE_MULT := BalanceData.get_value("king_bible_evolved_damage_mult", 2.2)
static var EVOLVED_ANGULAR_MULT := BalanceData.get_value("king_bible_evolved_angular_mult", 1.35)
static var EVOLVED_TICK_MULT := BalanceData.get_value("king_bible_evolved_tick_mult", 0.6)      # shorter cooldown between a book's hits
static var EVOLVED_HIT_BONUS := BalanceData.get_value("king_bible_evolved_hit_bonus", 8.0)      # wider strike radius per book

var run: VSRun
var _angle := 0.0
var _cd := 0.0
var _books: Array[Sprite2D] = []
var _built_count := 0
var _book_material: ShaderMaterial

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.bible_level
	if lvl <= 0:
		if _built_count != 0:
			_rebuild(0)
		return
	var count := _book_count(lvl)
	if count != _built_count:
		_rebuild(count)
	# Freeze the orbit while paused/leveling so the books hang in place like the other
	# weapons gate on phase; they still show where they'll resume from.
	if run.phase != "playing":
		return
	var ang_speed := ANGULAR_SPEED * float(_row(lvl)["speed_mult"])
	if _is_evolved():
		ang_speed *= EVOLVED_ANGULAR_MULT
	_angle = fmod(_angle + ang_speed * delta, TAU)
	_position_books(count, lvl)
	_cd -= delta
	if _cd <= 0.0:
		_strike(count, lvl)
		_cd = TICK_INTERVAL * (EVOLVED_TICK_MULT if _is_evolved() else 1.0) * run.haste_mult()

## True once the run has evolved King Bible into Unholy Vespers.
func _is_evolved() -> bool:
	return run != null and run.bible_evolved

## Books grow in number with level (per-level "amount" column: 1,2,2,2,3,3,3,4) so a maxed Bible
## walls the player in orbiting damage. Evolving fills the ring to its evolved cap regardless of
## level (evolution needs max level).
func _book_count(lvl: int) -> int:
	if _is_evolved():
		return MAX_BOOKS + EVOLVED_EXTRA_BOOKS
	return clampi(int(_row(lvl)["amount"]), 1, MAX_BOOKS)

func _orbit_radius(lvl: int) -> float:
	# The ring widens only via the per-level Area column (wiki: +25% at Lv3 & Lv6); run.area_mult
	# (Candelabrador) then extends it further on top.
	return BASE_ORBIT_RADIUS * float(_row(lvl)["area_mult"]) * run.area_mult

## Place each book evenly around the ring at the current orbit angle and spin it so the
## sprite tumbles as it travels (purely cosmetic).
func _position_books(count: int, lvl: int) -> void:
	var r := _orbit_radius(lvl)
	for i in count:
		var a := _angle + TAU * float(i) / float(count)
		_books[i].position = Vector2(cos(a), sin(a)) * r
		_books[i].rotation = a

## Damage every enemy currently touching a book. Per-book world position is checked so
## hits track the orbit; the shared cooldown keeps a lingering enemy from draining per frame.
func _strike(count: int, lvl: int) -> void:
	var dmg := (BASE_DAMAGE * run.damage_variance() + float(_row(lvl)["bonus_damage"])) * run.might_mult() * run.power_mult()
	var reach := BOOK_HIT_RADIUS
	if _is_evolved():
		dmg *= EVOLVED_DAMAGE_MULT
		reach += EVOLVED_HIT_BONUS
	var hit_any := false
	for i in count:
		var bp: Vector2 = _books[i].global_position
		for e in get_tree().get_nodes_in_group("enemies"):
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			if (e.position - bp).length() < reach + er:
				e.hit(dmg, bp)
				hit_any = true
	if hit_any:
		AgentBridge.emit_event("sfx_played", {"name": "bible"})

## (Re)build the pool of orbiting book sprites when the count changes (level pick or reset).
func _rebuild(count: int) -> void:
	for b in _books:
		b.queue_free()
	_books.clear()
	var tex := load(BOOK_TEX) as Texture2D
	var mat := _get_book_material()
	for i in count:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(BOOK_SCALE, BOOK_SCALE)
		s.material = mat
		add_child(s)
		_books.append(s)
	_built_count = count
	if count > 0:
		_position_books(count, run.bible_level)

## Lazily build the shared recolor material so every book reads as bright VS-blue. Cached so
## rebuilds (level picks) reuse one Shader/ShaderMaterial rather than recompiling per book.
func _get_book_material() -> ShaderMaterial:
	if _book_material == null:
		var sh := Shader.new()
		sh.code = _BOOK_SHADER
		_book_material = ShaderMaterial.new()
		_book_material.shader = sh
		_book_material.set_shader_parameter("tint", BOOK_TINT)
	return _book_material

## The per-level tuning row for `lvl`, from data/king_bible_levels.csv. Levels past the table (Limit
## Break) clamp to the highest defined level; a missing CSV reconstructs the wiki deltas so the Bible
## never breaks.
static func _row(lvl: int) -> Dictionary:
	_ensure_levels()
	if _levels.has(lvl):
		return _levels[lvl]
	if _levels.is_empty():
		var amount := 1 + (1 if lvl >= 2 else 0) + (1 if lvl >= 5 else 0) + (1 if lvl >= 8 else 0)
		var bonus := (10.0 if lvl >= 4 else 0.0) + (10.0 if lvl >= 7 else 0.0)
		var area := 1.0 + (0.25 if lvl >= 3 else 0.0) + (0.25 if lvl >= 6 else 0.0)
		var speed := 1.0 + (0.3 if lvl >= 3 else 0.0) + (0.3 if lvl >= 6 else 0.0)
		return {"amount": amount, "bonus_damage": bonus, "area_mult": area, "speed_mult": speed}
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
		push_warning("VSKingBible: cannot open %s (err %d)" % [LEVELS_CSV, FileAccess.get_open_error()])
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
			"area_mult": r[int(col.get("area_mult", 3))].strip_edges().to_float(),
			"speed_mult": r[int(col.get("speed_mult", 4))].strip_edges().to_float(),
		}
	f.close()
