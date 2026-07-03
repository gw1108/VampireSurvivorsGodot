class_name VSKingBible
extends Node2D
## An orbiting weapon — the classic Vampire Survivors "King Bible": holy books that
## circle the player, damaging any enemy they sweep through. Unlike the projectile
## (aimed, ranged), the Garlic (a static aura), and the Whip (a directional burst),
## the Bible is a *rotating melee* — constant area denial that rewards kiting the swarm
## through the orbit. Mounted on the player, enabled/scaled by run.bible_level
## (0 = not yet picked: no books, inert). The slice's fourth, mechanically-distinct weapon.

const BASE_ORBIT_RADIUS := 96.0
const RADIUS_PER_LEVEL := 8.0
const ANGULAR_SPEED := 3.2          # rad/s the books orbit the player
const BOOK_HIT_RADIUS := 22.0       # how close a book must pass to strike an enemy
const TICK_INTERVAL := 0.35         # min seconds between a book's hits (avoids per-frame drain)
const BASE_DAMAGE := 4.0
const DAMAGE_PER_LEVEL := 3.0
const MAX_BOOKS := 5
const BOOK_SCALE := 0.5             # 64px source -> ~32px book, legible beside enemies
const BOOK_TEX := "res://art/up_bible.png"

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
	_angle = fmod(_angle + ANGULAR_SPEED * delta, TAU)
	_position_books(count, lvl)
	_cd -= delta
	if _cd <= 0.0:
		_strike(count, lvl)
		_cd = TICK_INTERVAL

## Books grow in number with level so a maxed Bible walls the player in orbiting damage.
func _book_count(lvl: int) -> int:
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
	var hit_any := false
	for i in count:
		var bp: Vector2 = _books[i].global_position
		for e in get_tree().get_nodes_in_group("enemies"):
			var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
			if (e.position - bp).length() < BOOK_HIT_RADIUS + er:
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
