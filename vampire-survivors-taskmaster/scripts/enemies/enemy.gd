class_name VSEnemy
extends Node2D
## A basic enemy: walks straight at the player and deals periodic contact damage.
## Distance-based contact (no physics) — robust and cheap with many on screen.

const RADIUS := 12.0
const FLASH_DURATION := 0.1
## Enemies at or above this max health (mini-bosses like ELITE) get a health bar
## once damaged, so their long HP pool reads as visible progress.
const HEALTH_BAR_MIN_MAX_HEALTH := 40.0

## Enemy archetypes. Each maps to a distinct pixel-art sprite plus stat tuning so
## waves have visual and mechanical variety. The spawner sets `type` before the
## node enters the tree; `_ready` applies the matching sprite + stats.
## ELITE is a periodic mini-boss: a much larger sprite, far more health, a bigger
## contact hit, and a big XP payout to break up the wave rhythm. The spawner
## injects it on a timer rather than through the normal weighted roll.
enum Type { BAT, ZOMBIE, SKELETON, GHOST, MUMMY, ELITE }

const TYPES := {
	Type.BAT:      {"tex": "res://art/enemy_bat.png",      "speed": 62.0, "health": 3.0,   "damage": 8.0,  "xp": 1},
	Type.ZOMBIE:   {"tex": "res://art/enemy_zombie.png",   "speed": 42.0, "health": 6.0,   "damage": 10.0, "xp": 2},
	Type.SKELETON: {"tex": "res://art/enemy_skeleton.png", "speed": 58.0, "health": 4.0,   "damage": 9.0,  "xp": 2},
	Type.GHOST:    {"tex": "res://art/enemy_ghost.png",    "speed": 78.0, "health": 2.0,   "damage": 7.0,  "xp": 1},
	Type.MUMMY:    {"tex": "res://art/enemy_mummy.png",    "speed": 34.0, "health": 10.0,  "damage": 12.0, "xp": 3},
	Type.ELITE:    {"tex": "res://art/enemy_elite.png",    "speed": 40.0, "health": 140.0, "damage": 20.0, "xp": 25, "scale": 2.0, "radius": 22.0},
}

var type: int = Type.BAT
var speed := 62.0
var health := 3.0
var max_health := 3.0
var _show_health_bar := false
var contact_damage := 8.0
var xp_value := 1
var radius := RADIUS
var base_scale := 1.0
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
	health = cfg["health"]
	max_health = health
	_show_health_bar = max_health >= HEALTH_BAR_MIN_MAX_HEALTH
	contact_damage = cfg["damage"]
	xp_value = cfg["xp"]
	radius = cfg.get("radius", RADIUS)
	base_scale = cfg.get("scale", 1.0)
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
	var to := target.position - position
	var d := to.length()
	if d > 0.5:
		position += to / d * speed * delta
	_contact_cd -= delta
	if d < radius + VSPlayer.RADIUS and _contact_cd <= 0.0 and target.alive:
		target.take_damage(contact_damage)
		_contact_cd = 0.5

func hit(amount: float, _from: Vector2) -> void:
	if _dying:
		return
	health -= amount
	_flash_time = FLASH_DURATION
	_update_flash()
	if _show_health_bar:
		queue_redraw()
	if health <= 0.0:
		_die()

func _die() -> void:
	_dying = true
	if run:
		run.add_kill(position, xp_value)
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
