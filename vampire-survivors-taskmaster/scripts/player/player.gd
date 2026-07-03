class_name VSPlayer
extends Node2D
## The player avatar. Move-only (WASD/arrows); the weapon auto-fires. Manual movement +
## distance math (no physics bodies) keeps the slice robust. Pixel-art sprite (Antonio).

signal died
signal damaged(amount: float)

const SPEED := 210.0
const RADIUS := 14.0

## Hit feedback: on taking damage the avatar flashes red for a sliver of a second so a hit
## reads on the character itself, not just as a camera jolt — the same channel the enemies use
## for their white hit-flash, tuned red here to say "you're being hurt" at a glance.
const HIT_FLASH_DURATION := 0.12
const HIT_FLASH_COLOR := Color(1.7, 0.35, 0.35)

var max_health := 100.0
var health := 100.0
var alive := true

var _sprite: Sprite2D
## Persistent horizontal facing (+1 right, -1 left), driven by move input and mirroring the
## whip/knife convention so the character visibly faces the way it moves (and the way those
## weapons fire). The art faces right by default, so flip_h is set when facing left.
var _facing := 1
## Remaining hit-flash time (s), counting down in _process; set by take_damage.
var _flash_time := 0.0

func _ready() -> void:
	add_to_group("player")
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/player.png")
	add_child(_sprite)

func _process(delta: float) -> void:
	if not alive:
		return
	_update_hit_flash(delta)
	var run := get_parent() as VSRun
	if run and run.phase != "playing":
		return                       # freeze while the level-up screen is up
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Face the way we move: latch facing off the horizontal axis (unchanged on pure-vertical
	# movement, so the avatar keeps its last heading) and mirror the sprite accordingly.
	if absf(dir.x) > 0.01:
		_facing = 1 if dir.x > 0.0 else -1
	if _sprite:
		_sprite.flip_h = _facing < 0
	var speed_mult := run.player_speed_mult if run else 1.0
	position += dir * SPEED * speed_mult * delta
	if run:
		position.x = clampf(position.x, -run.arena_half.x, run.arena_half.x)
		position.y = clampf(position.y, -run.arena_half.y, run.arena_half.y)

## Decay the hit-flash and lerp the sprite from red back to its normal tint. No-op once spent;
## the death grey-out (set in take_damage, with _process returning early while dead) is untouched.
func _update_hit_flash(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time = maxf(0.0, _flash_time - delta)
	if _sprite:
		var f := _flash_time / HIT_FLASH_DURATION
		_sprite.modulate = Color(1, 1, 1).lerp(HIT_FLASH_COLOR, f)

func take_damage(amount: float) -> void:
	if not alive:
		return
	# Armor passive subtracts flat damage, but at least 1 always gets through so armor can
	# never make the player invulnerable (faithful to VS: chip damage still lands).
	var run := get_parent() as VSRun
	if run and run.armor > 0:
		amount = maxf(1.0, amount - float(run.armor))
	health -= amount
	_flash_time = HIT_FLASH_DURATION
	AgentBridge.emit_event("damage", {"amount": amount, "to": health})
	damaged.emit(amount)
	if health <= 0.0:
		health = 0.0
		alive = false
		if _sprite:
			_sprite.modulate = Color(0.45, 0.45, 0.45)   # greyed-out on death
		died.emit()
