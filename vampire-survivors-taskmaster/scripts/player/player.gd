class_name VSPlayer
extends Node2D
## The player avatar. Move-only (WASD/arrows); the weapon auto-fires. Manual movement +
## distance math (no physics bodies) keeps the slice robust. Placeholder vector art.

signal died

const SPEED := 210.0
const RADIUS := 14.0

var max_health := 100.0
var health := 100.0
var alive := true

func _ready() -> void:
	add_to_group("player")

func _process(delta: float) -> void:
	if not alive:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += dir * SPEED * delta
	var run := get_parent() as VSRun
	if run:
		position.x = clampf(position.x, -run.arena_half.x, run.arena_half.x)
		position.y = clampf(position.y, -run.arena_half.y, run.arena_half.y)
	queue_redraw()

func take_damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	AgentBridge.emit_event("damage", {"amount": amount, "to": health})
	if health <= 0.0:
		health = 0.0
		alive = false
		died.emit()
	queue_redraw()

func _draw() -> void:
	var col := Color(0.3, 0.9, 0.45) if alive else Color(0.45, 0.45, 0.45)
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 2.0)
