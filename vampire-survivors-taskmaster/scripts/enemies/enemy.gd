class_name VSEnemy
extends Node2D
## A basic enemy: walks straight at the player and deals periodic contact damage.
## Distance-based contact (no physics) — robust and cheap with many on screen.

const RADIUS := 12.0
const FLASH_DURATION := 0.1

## Enemy archetypes. Each maps to a distinct pixel-art sprite plus stat tuning so
## waves have visual and mechanical variety. The spawner sets `type` before the
## node enters the tree; `_ready` applies the matching sprite + stats.
enum Type { BAT, ZOMBIE, SKELETON, GHOST, MUMMY }

const TYPES := {
	Type.BAT:      {"tex": "res://art/enemy_bat.png",      "speed": 62.0, "health": 3.0,  "damage": 8.0},
	Type.ZOMBIE:   {"tex": "res://art/enemy_zombie.png",   "speed": 42.0, "health": 6.0,  "damage": 10.0},
	Type.SKELETON: {"tex": "res://art/enemy_skeleton.png", "speed": 58.0, "health": 4.0,  "damage": 9.0},
	Type.GHOST:    {"tex": "res://art/enemy_ghost.png",    "speed": 78.0, "health": 2.0,  "damage": 7.0},
	Type.MUMMY:    {"tex": "res://art/enemy_mummy.png",    "speed": 34.0, "health": 10.0, "damage": 12.0},
}

var type: int = Type.BAT
var speed := 62.0
var health := 3.0
var contact_damage := 8.0
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
	contact_damage = cfg["damage"]
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
	if d < RADIUS + VSPlayer.RADIUS and _contact_cd <= 0.0 and target.alive:
		target.take_damage(contact_damage)
		_contact_cd = 0.5

func hit(amount: float, _from: Vector2) -> void:
	if _dying:
		return
	health -= amount
	_flash_time = FLASH_DURATION
	_update_flash()
	if health <= 0.0:
		_die()

func _die() -> void:
	_dying = true
	if run:
		run.add_kill(position)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tw.tween_callback(queue_free)

## Brighten the sprite toward white for the duration of a hit flash.
func _update_flash() -> void:
	if _sprite == null:
		return
	var flash := _flash_time / FLASH_DURATION
	_sprite.modulate = Color(1, 1, 1).lerp(Color(4, 4, 4), flash)
