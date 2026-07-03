class_name VSEnemy
extends Node2D
## A basic enemy: walks straight at the player and deals periodic contact damage.
## Distance-based contact (no physics) — robust and cheap with many on screen.

const RADIUS := 12.0
const FLASH_DURATION := 0.1

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
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/enemy_bat.png")
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
