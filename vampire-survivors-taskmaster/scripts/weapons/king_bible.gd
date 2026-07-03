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
const BASE_ORBIT_RADIUS := 88.0
const RADIUS_PER_LEVEL := 6.0
const ANGULAR_SPEED := 3.6          # rad/s the books orbit the player (~0.57 rev/s)
const BOOK_HIT_RADIUS := 27.0       # how close a book must pass to strike an enemy
const TICK_INTERVAL := 0.35         # min seconds between a book's hits (avoids per-frame drain)
const BASE_DAMAGE := 6.0
const DAMAGE_PER_LEVEL := 3.0
const MAX_BOOKS := 5
const BOOK_SCALE := 0.5             # 64px source -> ~32px book, legible beside enemies
const BOOK_TEX := "res://art/up_bible.png"

# Evolved (Unholy Vespers) profile — applied when run.bible_evolved: a full ring of extra
# books orbiting faster, striking more often, harder, and with a wider reach. Gated on the
# weapon already being maxed, so this is the run's payoff for maxing Bible + owning Power.
const EVOLVED_EXTRA_BOOKS := 2      # 5 -> 7 books, a near-solid wall
const EVOLVED_DAMAGE_MULT := 2.2
const EVOLVED_ANGULAR_MULT := 1.35
const EVOLVED_TICK_MULT := 0.6      # shorter cooldown between a book's hits
const EVOLVED_HIT_BONUS := 8.0      # wider strike radius per book

var run: VSRun
var _angle := 0.0
var _cd := 0.0
var _books: Array[Sprite2D] = []
var _built_count := 0

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
	var ang_speed := ANGULAR_SPEED
	if _is_evolved():
		ang_speed *= EVOLVED_ANGULAR_MULT
	_angle = fmod(_angle + ang_speed * delta, TAU)
	_position_books(count, lvl)
	_cd -= delta
	if _cd <= 0.0:
		_strike(count, lvl)
		_cd = TICK_INTERVAL * (EVOLVED_TICK_MULT if _is_evolved() else 1.0)

## True once the run has evolved King Bible into Unholy Vespers.
func _is_evolved() -> bool:
	return run != null and run.bible_evolved

## Books grow in number with level so a maxed Bible walls the player in orbiting damage.
## Evolving fills the ring to its evolved cap regardless of level (evolution needs max level).
func _book_count(lvl: int) -> int:
	if _is_evolved():
		return MAX_BOOKS + EVOLVED_EXTRA_BOOKS
	return clampi(1 + lvl / 2, 1, MAX_BOOKS)

func _orbit_radius(lvl: int) -> float:
	return BASE_ORBIT_RADIUS + RADIUS_PER_LEVEL * float(lvl - 1)

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
	var dmg := (BASE_DAMAGE + DAMAGE_PER_LEVEL * float(lvl)) * run.might_mult()
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
	for i in count:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(BOOK_SCALE, BOOK_SCALE)
		add_child(s)
		_books.append(s)
	_built_count = count
	if count > 0:
		_position_books(count, run.bible_level)
