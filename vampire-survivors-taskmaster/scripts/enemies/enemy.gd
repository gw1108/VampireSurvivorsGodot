class_name VSEnemy
extends Node2D
## A basic enemy: walks straight at the player and deals periodic contact damage.
## Distance-based contact (no physics) — robust and cheap with many on screen.

const RADIUS := 12.0
const FLASH_DURATION := 0.1
## Boid separation: enemies repel from neighbours within this radius so the horde
## spreads into a mass that SURROUNDS the player instead of every unit collapsing
## onto the exact player position into one overlapping column. STRENGTH weights the
## push against the toward-player drive; at equilibrium they pack ~SEPARATION_RADIUS
## apart, forming the VS-style pincer wall.
const SEPARATION_RADIUS := 26.0
const SEPARATION_STRENGTH := 0.65
## Enemies at or above this max health (mini-bosses like ELITE) get a health bar
## once damaged, so their long HP pool reads as visible progress.
const HEALTH_BAR_MIN_MAX_HEALTH := 40.0

## Enemy archetypes. Each maps to a distinct pixel-art sprite plus stat tuning so
## waves have visual and mechanical variety. The spawner sets `type` before the
## node enters the tree; `_ready` applies the matching sprite + stats.
## ELITE is a periodic mini-boss: a much larger sprite, far more health, a bigger
## contact hit, and a big XP payout to break up the wave rhythm. The spawner
## injects it on a timer rather than through the normal weighted roll.
## REAPER is the run's finale: at the survival time limit VSRun summons a single
## fast, enormous-HP, huge-contact Reaper (VS's death-at-the-clock enemy) that the
## player must outlast for the final ~15s dash to the win — not killed, survived.
enum Type { BAT, ZOMBIE, SKELETON, GHOST, MUMMY, ELITE, REAPER }

const TYPES := {
	Type.BAT:      {"tex": "res://art/enemy_bat.png",      "speed": 62.0, "health": 3.0,   "damage": 8.0,  "xp": 1},
	Type.ZOMBIE:   {"tex": "res://art/enemy_zombie.png",   "speed": 42.0, "health": 6.0,   "damage": 10.0, "xp": 2},
	Type.SKELETON: {"tex": "res://art/enemy_skeleton.png", "speed": 58.0, "health": 4.0,   "damage": 9.0,  "xp": 2},
	Type.GHOST:    {"tex": "res://art/enemy_ghost.png",    "speed": 78.0, "health": 2.0,   "damage": 7.0,  "xp": 1},
	Type.MUMMY:    {"tex": "res://art/enemy_mummy.png",    "speed": 34.0, "health": 10.0,  "damage": 12.0, "xp": 3},
	Type.ELITE:    {"tex": "res://art/enemy_elite.png",    "speed": 40.0, "health": 140.0, "damage": 20.0, "xp": 25, "scale": 2.0, "radius": 22.0, "gems": 5, "knock": 0.25},
	Type.REAPER:   {"tex": "res://art/enemy_reaper.png",   "speed": 130.0, "health": 600.0, "damage": 34.0, "xp": 60, "scale": 2.6, "radius": 30.0, "gems": 10, "knock": 0.06},
}

## Knockback: a weapon hit shoves the enemy directly away from the hit source with an
## impulse (px/s) that decays fast, so a strike reads as a real shove that buys the player
## a sliver of breathing room without launching enemies across the arena. `knock` per-type
## scales it (heavy ELITE/REAPER barely budge, staying the relentless threat they should be).
const KNOCKBACK_IMPULSE := 230.0   # px/s velocity added on a normal-weight enemy hit
const KNOCKBACK_DECAY := 1500.0    # px/s^2 the impulse bleeds off — stops in ~0.15s

var type: int = Type.BAT
var speed := 62.0
var health := 3.0
var max_health := 3.0
var _show_health_bar := false
var contact_damage := 8.0
var xp_value := 1
var radius := RADIUS
var base_scale := 1.0
## How many gems this enemy scatters on death. Elites drop a burst so the big
## payout reads as a jackpot instead of one lone gem.
var gem_drops := 1
## Per-type knockback resistance (1.0 = full shove, 0 = immovable); read from TYPES.
var knock_resist := 1.0
## Current knockback velocity (px/s), decaying to zero in _process; set by hit().
var _knockback := Vector2.ZERO
var run: VSRun
var target: VSPlayer
var _contact_cd := 0.0
var _flash_time := 0.0
var _dying := false

var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("enemies")
	var cfg: Dictionary = TYPES.get(type, TYPES[Type.BAT])
	speed = cfg["speed"]
	# Escalating-threat ramp: enemies spawned later in the run are tougher, so the
	# player's growing level-up power doesn't trivialize every wave — the run keeps
	# a real sense of mounting danger (see GOAL: escalating waves). HP ramps steeply,
	# contact damage gently (a late bat should tank hits, not one-shot the player).
	var t: float = run.elapsed if run else 0.0
	var minutes := minf(t / 60.0, 6.0)                # cap scaling at ~6 minutes
	var hp_mult := 1.0 + minutes * 0.35               # +35% HP per minute, up to ~+210%
	var dmg_mult := 1.0 + minutes * 0.08              # +8% damage per minute, up to ~+48%
	health = cfg["health"] * hp_mult
	max_health = health
	_show_health_bar = max_health >= HEALTH_BAR_MIN_MAX_HEALTH
	contact_damage = cfg["damage"] * dmg_mult
	xp_value = cfg["xp"]
	radius = cfg.get("radius", RADIUS)
	base_scale = cfg.get("scale", 1.0)
	gem_drops = cfg.get("gems", 1)
	knock_resist = cfg.get("knock", 1.0)
	scale = Vector2(base_scale, base_scale)
	_sprite = Sprite2D.new()
	_sprite.texture = load(cfg["tex"])
	add_child(_sprite)

func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		_update_flash()
	if _dying:
		return
	if run and run.phase != "playing":
		return
	if target == null or not is_instance_valid(target):
		return
	# Orologion time-stop: while a Freeze Clock is active every enemy halts in place and deals
	# no contact damage — a breather for the player to reposition (weapons still hit them). An
	# icy tint (when not mid hit-flash) makes the frozen state read at a glance.
	if run and run.is_frozen():
		if _flash_time <= 0.0 and _sprite:
			_sprite.modulate = Color(0.55, 0.8, 1.3)
		return
	elif _flash_time <= 0.0 and _sprite and _sprite.modulate != Color(1, 1, 1):
		_sprite.modulate = Color(1, 1, 1)   # clear any lingering freeze tint once thawed
	var to := target.position - position
	var d := to.length()
	var desired := to / d if d > 0.5 else Vector2.ZERO
	# Blend the toward-player drive with a repulsion from crowded neighbours so the
	# swarm spreads around the player rather than stacking on one point. In dense
	# packs the push counters the inward drive, settling enemies into a surrounding
	# ring while they still press contact range; when spread out the push fades.
	var move := desired + _separation() * SEPARATION_STRENGTH
	var step := Vector2.ZERO
	if move.length() > 0.001:
		step = move.normalized() * speed * delta
	# Layer any active knockback on top of the homing step and bleed it off, so a weapon
	# hit visibly shoves the enemy back for a moment before it resumes its march.
	if _knockback != Vector2.ZERO:
		step += _knockback * delta
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	position += step
	_contact_cd -= delta
	if d < radius + VSPlayer.RADIUS and _contact_cd <= 0.0 and target.alive:
		target.take_damage(contact_damage)
		_contact_cd = 0.5

## Sum of unit repulsions from every enemy inside SEPARATION_RADIUS, each weighted
## by how close it is (nearer neighbours push harder). Returned un-normalized so the
## push grows with crowding; the caller normalizes the blended move. O(n) per enemy
## (O(n²) per frame) which is fine within the spawner's MAX_ENEMIES cap.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var away: Vector2 = position - other.position
		var dist := away.length()
		if dist > 0.001 and dist < SEPARATION_RADIUS:
			push += away / dist * (1.0 - dist / SEPARATION_RADIUS)
	return push

func hit(amount: float, from: Vector2) -> void:
	if _dying:
		return
	health -= amount
	_flash_time = FLASH_DURATION
	_update_flash()
	# Shove away from the hit source, scaled by this enemy's knockback resistance so
	# heavy mini-bosses barely flinch. Impulses stack (rapid hits push harder) but decay
	# fast in _process. A dead-centre hit (from == position) has no direction, so no shove.
	if knock_resist > 0.0:
		var away := position - from
		if away.length() > 0.001:
			_knockback += away.normalized() * KNOCKBACK_IMPULSE * knock_resist
	# Floating white damage number so rising power (Might, Power picks, weapon levels)
	# reads frame-to-frame even when a hit doesn't cross an HP breakpoint. Cosmetic:
	# spawned into the parent's space with a little x jitter so stacked hits stay legible.
	var parent := get_parent()
	if parent != null:
		var at := position + Vector2(randf_range(-6.0, 6.0), -radius)
		VSFloatText.spawn(parent, at, str(int(round(amount))), Color(1, 1, 1))
	if _show_health_bar:
		queue_redraw()
	if health <= 0.0:
		_die()

func _die() -> void:
	_dying = true
	if run:
		var big := type == Type.ELITE or type == Type.REAPER
		run.add_kill(position, xp_value, gem_drops, big)
		if big:
			run.add_camera_shake(0.8)   # elite/reaper pop lands harder than a player hit
		if type == Type.REAPER:
			run.on_reaper_slain()       # overpowering the finale wins the run instantly
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(base_scale * 1.4, base_scale * 1.4), 0.08)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tw.tween_callback(queue_free)

## Draw a small health bar above mini-boss enemies once they've taken damage.
## Coordinates are local, so the node's scale sizes the bar to the sprite.
func _draw() -> void:
	if not _show_health_bar or _dying or health <= 0.0 or health >= max_health:
		return
	var frac := clampf(health / max_health, 0.0, 1.0)
	var w := radius * 2.0
	var h := 3.0
	var top := -radius - 8.0
	var bg := Rect2(-w * 0.5, top, w, h)
	draw_rect(bg, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bg.position, Vector2(w * frac, h)), Color(0.85, 0.15, 0.15))

## Brighten the sprite toward white for the duration of a hit flash.
func _update_flash() -> void:
	if _sprite == null:
		return
	var flash := _flash_time / FLASH_DURATION
	_sprite.modulate = Color(1, 1, 1).lerp(Color(4, 4, 4), flash)
