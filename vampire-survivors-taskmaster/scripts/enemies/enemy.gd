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

func _ready() -> void:
	add_to_group("enemies")

func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		queue_redraw()
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
	queue_redraw()

func hit(amount: float, _from: Vector2) -> void:
	if _dying:
		return
	health -= amount
	_flash_time = FLASH_DURATION
	if health <= 0.0:
		_die()
	else:
		queue_redraw()

func _die() -> void:
	_dying = true
	if run:
		run.add_kill(position)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.1)
	tw.tween_callback(queue_free)

func _draw() -> void:
	var flash := _flash_time / FLASH_DURATION
	var body := Color(0.9, 0.32, 0.32).lerp(Color(1, 1, 1), flash)
	draw_circle(Vector2.ZERO, RADIUS, body)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 20, Color(0, 0, 0, 0.4), 1.5)
