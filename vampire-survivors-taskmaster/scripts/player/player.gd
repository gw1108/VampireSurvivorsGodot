class_name VSPlayer
extends Node2D
## The player avatar. Move-only (WASD/arrows); the weapon auto-fires. Manual movement +
## distance math (no physics bodies) keeps the slice robust. Pixel-art sprite (Antonio).

signal died
signal damaged(amount: float)

const SPEED := 210.0
const RADIUS := 14.0

var max_health := 100.0
var health := 100.0
var alive := true

var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("player")
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/player.png")
	add_child(_sprite)

func _process(delta: float) -> void:
	if not alive:
		return
	var run := get_parent() as VSRun
	if run and run.phase != "playing":
		return                       # freeze while the level-up screen is up
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed_mult := run.player_speed_mult if run else 1.0
	position += dir * SPEED * speed_mult * delta
	if run:
		position.x = clampf(position.x, -run.arena_half.x, run.arena_half.x)
		position.y = clampf(position.y, -run.arena_half.y, run.arena_half.y)

func take_damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	AgentBridge.emit_event("damage", {"amount": amount, "to": health})
	damaged.emit(amount)
	if health <= 0.0:
		health = 0.0
		alive = false
		if _sprite:
			_sprite.modulate = Color(0.45, 0.45, 0.45)   # greyed-out on death
		died.emit()
