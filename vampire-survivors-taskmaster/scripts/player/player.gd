class_name VSPlayer
extends Node2D
## The player avatar. Move-only (WASD/arrows); the weapon auto-fires. Manual movement +
## distance math (no physics bodies) keeps the slice robust. Renders the Antonio pixel-art
## sprite; HITBOX_HALF is the ONE rectangle collider enemies both bump into and get hurt by.

signal died

const HITBOX_HALF := Vector2(16.0, 21.0)  # unified enemy collider (half-extents ≈ the visible body, ~32x42 vs the 49x52 sprite): the SINGLE rectangle an enemy both presses against (can't burrow in) AND deals contact damage across — see VSEnemy._process
const RADIUS := 14.0       # body radius used ONLY for gem-pickup assist (gem.gd); NOT the enemy hurt collider anymore — that's HITBOX_HALF
const SPRITE := preload("res://art/player.png")
const HURT_FLASH := 0.12   # seconds the red damage flash lasts
const HP_BAR_W := 44.0     # health bar width (px) — a touch under the sprite width
const HP_BAR_H := 5.0      # health bar height (px)
const HP_BAR_GAP := 5.0    # gap between the sprite's bottom edge and the bar
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.28)  # soft blob shadow so the body reads as grounded, not floating
const SHADOW_W_FRAC := 0.58   # shadow diameter as a fraction of the sprite width
const SHADOW_FLATTEN := 0.34  # vertical squash → a flat, ground-hugging ellipse
const SHADOW_LIFT := 2.0      # px the ellipse sits above the sprite's bottom edge, under the feet
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.7)  # subtle thin black rim so the body stands out from the busy background
const OUTLINE_PX := 1.5       # rim thickness in px (small/subtle)
const OUTLINE_OFFSETS: Array[Vector2] = [         # 8-way unit offsets (diagonals normalized) for an even rim
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(0.7071, -0.7071),
	Vector2(-0.7071, 0.7071), Vector2(-0.7071, -0.7071),
]

const BASE_SPEED := 157.5   # base move speed (-25% from 210 for a heavier, more deliberate slice); the Wings passive adds +12% OF THIS per pick — see VSRun.apply_upgrade("speed")
var speed := BASE_SPEED      # current move speed; Wings raises it additively off BASE_SPEED so every pick is a clean, predictable +12% (not compounding 1.12^n)
var max_health := 100.0
var health := 100.0
var armor := 0.0     # flat contact-damage reduction (floored so a touch always stings); raised by VSRun.apply_upgrade("armor") (Armor)
var alive := true
var velocity := Vector2.ZERO   # actual per-frame motion (px/s), reported to the agent harness; zero when frozen/dead/wall-clamped
var _hurt_t := 0.0   # >0 while flashing red from a recent hit
var _facing := 1.0   # 1 = facing right (sprite's default), -1 = facing left; holds the last non-zero horizontal heading

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
	if velocity.x != 0.0:
		_facing = signf(velocity.x)   # remember heading so the sprite faces where it last moved
	queue_redraw()

func take_damage(amount: float) -> void:
	if not alive:
		return
	# Armor: flat mitigation on every contact hit. Floored at 1 so a touch always still stings
	# (stacking can't make you invulnerable). Reduce here at the top so health, the "damage"
	# event, and the flash all read the actual damage taken.
	if armor > 0.0:
		amount = maxf(1.0, amount - armor)
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
	_draw_shadow()   # ground shadow first, beneath the sprite
	# Tint white = normal; grey out on death. Centered on the node origin (the logical position).
	var tint := Color.WHITE if alive else Color(0.45, 0.45, 0.45)
	if alive and _hurt_t > 0.0:
		tint = Color(2.2, 0.6, 0.6)   # brief over-bright red flash on taking a hit
	# Mirror horizontally to face the last heading. A negative-width rect flips the sprite,
	# but Godot normalizes it by negating the size and setting FLIP_H WITHOUT moving the
	# position — so the origin must stay pinned to the LEFT edge (-w*0.5) in both headings, or
	# the flipped sprite slides a full width off the body. Only the width carries _facing's sign.
	var size := SPRITE.get_size()
	var rect := Rect2(-size.x * 0.5, -size.y * 0.5, size.x * _facing, size.y)
	_draw_outline(rect)   # subtle black rim behind the sprite so the body pops off the ground
	draw_texture_rect(SPRITE, rect, false, tint)
	if alive:
		_draw_health_bar()

func _draw_outline(rect: Rect2) -> void:
	# A subtle thin black rim: the sprite silhouette tinted solid black, drawn at small 8-way
	# offsets behind the real sprite so the body reads against the busy ground. modulate keeps
	# transparent pixels clear, so only the silhouette darkens (no box). Reuses the same flipped
	# rect so the rim follows the facing. Primitive-drawn like the rest of the slice's juice.
	for off in OUTLINE_OFFSETS:
		draw_texture_rect(SPRITE, Rect2(rect.position + off * OUTLINE_PX, rect.size), false, OUTLINE_COLOR)

func _draw_shadow() -> void:
	# A soft, flattened dark ellipse hugging the feet so the avatar reads as standing on the
	# ground rather than floating over the busy arena. A non-uniform draw transform squashes a
	# circle into the ground ellipse; the transform is reset afterwards so the sprite + health
	# bar draw unscaled. Drawn with primitives, matching the rest of the slice's juice.
	var size := SPRITE.get_size()
	var center := Vector2(0.0, size.y * 0.5 - SHADOW_LIFT)
	var rx := size.x * SHADOW_W_FRAC * 0.5
	draw_set_transform(center, 0.0, Vector2(1.0, SHADOW_FLATTEN))
	draw_circle(Vector2.ZERO, rx, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_health_bar() -> void:
	# A small red health bar hugging the bottom of the sprite — diegetic, so the player's
	# gaze stays on the action instead of darting to a HUD corner. Black outline + dark track
	# for contrast over the busy ground, with a red fill that shrinks left-to-right as health
	# drains. Drawn with primitives like the rest of the juice (aura / spark / gem).
	var top := SPRITE.get_size().y * 0.5 + HP_BAR_GAP
	var left := -HP_BAR_W * 0.5
	var ratio := clampf(health / max_health, 0.0, 1.0)
	var track := Rect2(left, top, HP_BAR_W, HP_BAR_H)
	draw_rect(track.grow(1.0), Color(0, 0, 0, 0.7))                       # 1px outline / backdrop
	draw_rect(track, Color(0.20, 0.04, 0.04, 0.85))                       # empty (dark red) track
	draw_rect(Rect2(left, top, HP_BAR_W * ratio, HP_BAR_H), Color(0.86, 0.18, 0.18))  # red fill
