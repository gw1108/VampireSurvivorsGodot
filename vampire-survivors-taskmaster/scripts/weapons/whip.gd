class_name VSWhip
extends Node2D
## "Whip" — Antonio's starting weapon (per the GDD). On a timer it cracks a wide, short horizontal
## slash box, PIERCING every enemy caught in it. The FIRST crack comes out FLAT toward the player's
## facing (right -> east, left -> west) with NO vertical offset. Multishot (Duplicator) adds more
## cracks, alternating BACKWARD then FORWARD and stacking each new one a row UP on its own side, so a
## fully-stacked whip reads as a forward column and a backward column climbing off the player (see
## _swing_strikes). No aim, no chase — the core VS "you move, the weapon fights" loop; capped at
## MAX_DIRS cracks. Replaces the Magic Wand projectile as the starter; the projectile weapon
## (VSWeapon / VSProjectile) stays in the codebase as a future level-up weapon (Magic Wand is one of
## the GDD's eight) — it's just no longer what Antonio starts with. The on-hit flourish is the warrior
## VFX-3 slash sprite, rotated to read horizontal (WhipSlash), mirrored for backward cracks.

# Strike box, sized off the player sprite: ~3 player-widths of horizontal reach, ~1.2 player
# heights tall — a wide, short zone that reads as a horizontal crack.
const PLAYER_W := 49.0              # player.png width
const PLAYER_H := 52.0              # player.png height
const STRIKE_W := PLAYER_W * 3.0    # ~147px horizontal reach
const STRIKE_H := PLAYER_H * 1.2    # ~62px tall
const OVERLAP := 10.0               # how far the box's near edge sits behind the player centre (covers the flank)
const HSEP := STRIKE_W * 0.5 - OVERLAP   # horizontal offset of a swing's box centre from the player (~64px)
const VSEP := 30.0                  # vertical step between stacked cracks — each extra crack climbs one VSEP UP on its side
const SLASH_ROT := 1.0              # rotation (rad) that lays the diagonal warrior slash MOSTLY HORIZONTAL with a slight up-tilt (0.6 read too steep/diagonal) — EYEBALL/tune; mirrored for backward cracks in _spawn_slash
const SLASH_SCALE := 1.5            # scales the 95px VFX toward the ~147px box — tune by eye
# Each crack's box centre sits HSEP to its side (forward = facing, backward = opposite) and VSEP*row
# UP from the player (y is negative for "up" in Godot's y-down space); rows climb as Multishot stacks
# more cracks (see _swing_strikes). MAX_DIRS caps how many cracks one swing can stack.
const MAX_DIRS := 4                 # the whip tops out at four stacked cracks — also the Duplicator cap (run.gd)

var run: VSRun
# Upgradeable stats (see VSRun.apply_upgrade): Power raises damage, Haste lowers fire_interval,
# Multishot raises projectile_count (an extra simultaneous swing on the opposite flank).
var fire_interval := 1.1
var damage := 5.0
var projectile_count := 1          # "Amount": swings per fire (Multishot). Named to match apply_upgrade("projectile").
var fire_count := 0                # swings performed — the run-scene smoke test reads this as "the weapon is alive"
var _cd := 0.0

func _process(delta: float) -> void:
	if run == null or run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		_fire()
		_cd = fire_interval

func _fire() -> void:
	# A whip swings on its cooldown whether or not anything's in reach (like VS). The first crack comes
	# out FLAT toward the player's facing (no vertical offset); Multishot adds more, alternating
	# backward/forward and stacking each new crack one row UP on its own side (see _swing_strikes).
	var n := clampi(projectile_count, 1, MAX_DIRS)
	for st in _swing_strikes(n):
		_strike(st.x, int(st.y))
	fire_count += 1
	AgentBridge.emit_event("sfx_played", {"name": "shoot"})
	Sfx.play("shoot")

func _facing_sign() -> float:
	# Strike toward the player's last heading (right = +1, left = -1). The whip is a child of the
	# player, so its parent carries the facing the sprite is mirrored to.
	var p := get_parent() as VSPlayer
	return p._facing if p else 1.0

func _swing_strikes(n: int) -> Array[Vector2]:
	# The n cracks for this swing, as (hsign, row) packed into a Vector2, in the order Multishot grows
	# them. hsign is the world horizontal of the crack (facing = +1 right / -1 left); row is how many
	# VSEP steps UP it sits. Cracks alternate forward (even i) / backward (odd i), and each side climbs
	# its own column:
	#   i=0  forward,  row 0  — the single whip: flat toward facing, no vertical offset
	#   i=1  backward, row 1  — NW of the player when facing right
	#   i=2  forward,  row 1  — stacked one row up on the previous forward
	#   i=3  backward, row 2  — stacked one row up on the previous backward
	# …forward indices climb rows 0,1,2…; backward indices climb rows 1,2,3….
	var fx := _facing_sign()
	var out: Array[Vector2] = []
	for i in n:
		var forward := i % 2 == 0
		var hsign := fx if forward else -fx
		var row := (i / 2) if forward else (i / 2 + 1)
		out.append(Vector2(hsign, row))
	return out

func _strike(hsign: float, row: int) -> void:
	# Damage every enemy inside the horizontal box (pierce). global_position is the player's (this
	# node is a child of the player). The box centre sits HSEP to the crack's side and VSEP*row UP
	# (y is down in Godot, so up is negative). get_nodes_in_group returns a snapshot and hit() only
	# marks the corpse _dying + drops it from the group, so cracking many in one loop never doubles.
	var centre := global_position + Vector2(HSEP * hsign, -VSEP * row)
	var hw := STRIKE_W * 0.5
	var hh := STRIKE_H * 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = e.position - centre
		if absf(d.x) <= hw + e.radius and absf(d.y) <= hh + e.radius:
			e.hit(damage, e.position)
	_spawn_slash(centre, hsign)

func _spawn_slash(centre: Vector2, hsign: float) -> void:
	if run == null:
		return
	var fx := WhipSlash.new()
	fx.run = run
	fx.position = centre                                   # run sits at the world origin, so local == global here
	# Lay the warrior slash MOSTLY HORIZONTAL (SLASH_ROT flattens the diagonal sprite), tilted a little
	# up. A crack to the player's LEFT (hsign < 0) is the horizontal mirror of one to the right: negate
	# the rotation AND flip x (scale.x < 0) so the slash sweeps toward its own side.
	var mirror := hsign < 0.0
	fx.rotation = -SLASH_ROT if mirror else SLASH_ROT
	fx.scale = Vector2(-SLASH_SCALE if mirror else SLASH_SCALE, SLASH_SCALE)
	run.add_child(fx)

## One-shot whip-slash VFX: plays the 10-frame warrior VFX-3 slash strip once (rotated/placed by
## the spawner so it reads as a horizontal crack), fading the tail out, then frees itself. Self-
## contained (no scene file), matching the impact-spark / gem-sparkle juice pattern.
class WhipSlash extends Node2D:
	const SHEET := preload("res://art/whip_slash.png")
	const FRAMES := 10
	const FW := 95          # frame cell width in the strip
	const FH := 98          # frame cell height
	const DUR := 0.22       # total play time for the 10-frame swing

	var run: VSRun
	var _t := 0.0

	func _ready() -> void:
		z_index = 50        # over enemies/player so the crack reads, under the impact spark (100)

	func _process(delta: float) -> void:
		if run and run.phase != "playing":
			return           # hold with the frozen world (level-up picker / game over)
		_t += delta
		if _t >= DUR:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var p := clampf(_t / DUR, 0.0, 1.0)
		var f := clampi(int(p * FRAMES), 0, FRAMES - 1)
		var src := Rect2(f * FW, 0, FW, FH)
		var dst := Rect2(-FW * 0.5, -FH * 0.5, FW, FH)                   # centred on the node origin
		var a := 1.0 if p < 0.7 else clampf((1.0 - p) / 0.3, 0.0, 1.0)   # fade the tail out
		draw_texture_rect_region(SHEET, dst, src, Color(1.0, 1.0, 1.0, a))
