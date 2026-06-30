class_name VSEnemy
extends Node2D
## A basic enemy: walks straight at the player and deals periodic contact damage.
## Distance-based contact (no physics) — robust and cheap with many on screen.

const RADIUS := 12.0

var speed := 62.0
var health := 3.0
var contact_damage := 8.0
var run: VSRun
var target: VSPlayer
var _contact_cd := 0.0

func _ready() -> void:
	add_to_group("enemies")

func _process(delta: float) -> void:
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
	health -= amount
	if health <= 0.0:
		if run:
			run.add_kill(position)
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.9, 0.32, 0.32))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 20, Color(0, 0, 0, 0.4), 1.5)
