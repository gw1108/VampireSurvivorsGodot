class_name VSPlayer
extends Node2D
## The player avatar. Move-only (WASD/arrows); the weapon auto-fires. Manual movement +
## distance math (no physics bodies) keeps the slice robust. Renders the Antonio pixel-art
## sprite (RADIUS stays the contact hitbox; the sprite is intentionally a touch larger).

signal died

const RADIUS := 14.0
const SPRITE := preload("res://art/player.png")
const HURT_FLASH := 0.12   # seconds the red damage flash lasts

var speed := 210.0   # upgradeable: VSRun.apply_upgrade("speed") raises it
var max_health := 100.0
var health := 100.0
var alive := true
var velocity := Vector2.ZERO   # actual per-frame motion (px/s), reported to the agent harness; zero when frozen/dead/wall-clamped
var _hurt_t := 0.0   # >0 while flashing red from a recent hit

func _ready() -> void:
	add_to_group("player")

func _process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return
	if _hurt_t > 0.0:
		_hurt_t -= delta
		queue_redraw()
	var run := get_parent() as VSRun
	if run and run.phase != "playing":
		velocity = Vector2.ZERO
		return   # freeze movement while the level-up picker is up (or on game over)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var prev := position
	position += dir * speed * delta
	if run:
		position.x = clampf(position.x, -run.arena_half.x, run.arena_half.x)
		position.y = clampf(position.y, -run.arena_half.y, run.arena_half.y)
	# Actual displacement, not intended — reports zero on a wall and follows the real speed multiplier.
	velocity = (position - prev) / delta if delta > 0.0 else Vector2.ZERO
	queue_redraw()

func take_damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	_hurt_t = HURT_FLASH
	AgentBridge.emit_event("damage", {"amount": amount, "to": health})
	AgentBridge.emit_event("sfx_played", {"name": "hurt"})
	Sfx.play("hurt")
	var run := get_parent() as VSRun
	if run:
		run.add_shake(7.0, 0.22)   # camera kick so a hit is felt, not just shown
	if health <= 0.0:
		health = 0.0
		alive = false
		died.emit()
	queue_redraw()

func _draw() -> void:
	# Tint white = normal; grey out on death. Centered on the node origin (the logical position).
	var tint := Color.WHITE if alive else Color(0.45, 0.45, 0.45)
	if alive and _hurt_t > 0.0:
		tint = Color(2.2, 0.6, 0.6)   # brief over-bright red flash on taking a hit
	draw_texture(SPRITE, -SPRITE.get_size() * 0.5, tint)
