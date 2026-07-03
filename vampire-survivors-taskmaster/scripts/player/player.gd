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

## Invulnerability frames: after a landed hit the player ignores all further contact damage
## for a brief window (GDD "Damage, Crit, Knockback, I-Frames": base 240 ms). This is what
## lets you tank *through* a crowd — without it, every enemy overlapping you the same instant
## lands its hit independently (each enemy has its own contact cooldown), stacking damage and
## deleting the player unfairly the moment the horde closes in. Ticks only while playing.
const IFRAME_DURATION := 0.24

## Living-avatar motion: a brisk two-step bounce while walking and a slow breathe when standing.
## Both are a couple of pixels of vertical offset on the sprite alone (position untouched), driven
## off the run's own `elapsed` clock so they pause cleanly with the game during level-up.
const WALK_BOB_FREQ := 9.0     # rad/s-ish; a bounce per footfall
const WALK_BOB_AMP := 2.0      # px, sprite rises on each step
const IDLE_SWAY_FREQ := 2.2
const IDLE_SWAY_AMP := 1.2

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
## Remaining invulnerability time (s), armed by a landed hit and counted down each playing
## frame; while > 0 take_damage is a no-op so overlapping enemies can't stack simultaneous hits.
var _iframe_time := 0.0

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
	# Bleed off invulnerability only during live play, matching the enemy contact clocks that
	# also halt on freeze, so a paused/level-up screen never silently burns the i-frame window.
	if _iframe_time > 0.0:
		_iframe_time = maxf(0.0, _iframe_time - delta)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Face the way we move: latch facing off the horizontal axis (unchanged on pure-vertical
	# movement, so the avatar keeps its last heading) and mirror the sprite accordingly.
	if absf(dir.x) > 0.01:
		_facing = 1 if dir.x > 0.0 else -1
	if _sprite:
		_sprite.flip_h = _facing < 0
		_update_bob(dir, run.elapsed if run else 0.0)
	var speed_mult := run.player_speed_mult if run else 1.0
	position += dir * SPEED * speed_mult * delta
	if run:
		position.x = clampf(position.x, -run.arena_half.x, run.arena_half.x)
		position.y = clampf(position.y, -run.arena_half.y, run.arena_half.y)

## Nudge the sprite up and down to sell life: a footfall bounce when a move key is held, a slow
## breathe when idle. `-absf(sin)` keeps the walk cycle lifting off the ground (up is -y) rather
## than sinking below it; the idle sway is a plain gentle oscillation around rest.
func _update_bob(dir: Vector2, elapsed: float) -> void:
	if dir.length_squared() > 0.0001:
		_sprite.position.y = -absf(sin(elapsed * WALK_BOB_FREQ)) * WALK_BOB_AMP
	else:
		_sprite.position.y = sin(elapsed * IDLE_SWAY_FREQ) * IDLE_SWAY_AMP

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
	# Invulnerability window: while a prior hit's i-frames are still up, ignore the hit entirely.
	# This is the shared window VS uses so a wall of enemies overlapping you deals ONE hit, not one
	# per body — the per-enemy contact cooldowns alone can't provide it.
	if _iframe_time > 0.0:
		return
	# Armor passive subtracts flat damage, but at least 1 always gets through so armor can
	# never make the player invulnerable (faithful to VS: chip damage still lands).
	var run := get_parent() as VSRun
	if run and run.armor > 0:
		amount = maxf(1.0, amount - float(run.armor))
	health -= amount
	_iframe_time = IFRAME_DURATION
	_flash_time = HIT_FLASH_DURATION
	AgentBridge.emit_event("damage", {"amount": amount, "to": health})
	damaged.emit(amount)
	if health <= 0.0:
		health = 0.0
		alive = false
		if _sprite:
			_sprite.modulate = Color(0.45, 0.45, 0.45)   # greyed-out on death
		died.emit()
