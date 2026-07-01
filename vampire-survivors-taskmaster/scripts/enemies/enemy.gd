class_name VSEnemy
extends Node2D
## An enemy: walks straight at the player and deals periodic contact damage.
## Distance-based contact (no physics) — robust and cheap with many on screen.
## One class, three kinds (set by the spawner): the slow sturdy "bat", a fast
## fragile "ghost" swarmer, and a rare slow/tanky "brute" wall — same logic,
## different sprite + base stats (and the brute draws big via base_scale).

const RADIUS := 12.0
const SPRITE := preload("res://art/enemy_bat.png")
const FLASH_DUR := 0.08       # white over-bright flash when a hit lands but doesn't kill
const DEATH_POP_DUR := 0.14   # brief scale-up + fade "pop" on death before freeing
const SEPARATION := 0.55      # how hard enemies push out of each other (fraction of move speed)
const PERSONAL_SPACE := 1.5   # neighbor-avoidance reach, in multiples of this enemy's body radius
const KNOCKBACK := 150.0      # initial recoil speed (px/s) flung away from a landed hit
const KNOCKBACK_DECEL := 950.0  # how fast the recoil bleeds off (px/s^2); a ~0.16s, ~12px flinch
const DESPAWN_DIST := 1200.0  # recycle an enemy once it falls this far from the player (well beyond the ~950px visible corner, so nothing on-screen ever pops out): the player (157.5) outruns every kind, so a kiter leaves a trail that never catches up — culling it frees the MAX_ENEMIES cap so the spawner keeps refilling the ring around the moving player instead of the field emptying behind you. The reaper is never culled.
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.28)  # soft blob shadow so each body reads as grounded, not floating
const SHADOW_W_FRAC := 0.62   # shadow diameter as a fraction of the sprite width
const SHADOW_FLATTEN := 0.34  # vertical squash → a flat, ground-hugging ellipse
const SHADOW_LIFT := 1.0      # px the ellipse sits above the sprite's bottom edge, under the feet
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.7)  # subtle thin black rim so each body stands out from the busy background
const OUTLINE_PX := 1.5       # rim thickness in px (small/subtle); scales with the sprite (drawn inside the scale transform)
const OUTLINE_OFFSETS: Array[Vector2] = [         # 8-way unit offsets (diagonals normalized) for an even rim
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(0.7071, -0.7071),
	Vector2(-0.7071, 0.7071), Vector2(-0.7071, -0.7071),
]

var speed := 46.5   # bat base move speed (-25% from 62 so movement reads heavier; relative to the player's 157.5, kiting is unchanged)
var health := 3.0
var contact_damage := 8.0
var radius := RADIUS            # per-enemy body size for contact + shot-catching; spawner sets it bigger for big kinds (brute) so what you see is what you hit
var xp_value := 1               # XP its death gem is worth; spawner bumps it for high-HP kinds (brute) so soaking a tank pays off
var kind := "bat"               # "bat" (slow sturdy) / "ghost" (fast fragile) / "brute" (slow tanky wall) / "reaper" (the finale boss); set by spawner
var is_reaper := false           # the time-limit finale boss: its death is the run's WIN condition (notifies run on its lethal hit)
var sprite: Texture2D = SPRITE  # per-enemy art so one VSEnemy class can be any kind
var base_scale := 1.0           # >1 for big kinds (brute) and hardened later-wave enemies; folds into _draw
var tier_tint := Color.WHITE    # red-shift for hardened enemies so their toughness reads at a glance
var run: VSRun
var target: VSPlayer
var _contact_cd := 0.0
var _flash_t := 0.0
var _dying := false
var _die_t := 0.0
var _knockback := Vector2.ZERO   # decaying recoil velocity from the most recent hit

func _ready() -> void:
	add_to_group("enemies")

func _process(delta: float) -> void:
	if run and run.phase != "playing":
		return
	if _dying:
		# Play out the death pop, then clean up. No movement / contact while dying.
		_die_t -= delta
		queue_redraw()
		if _die_t <= 0.0:
			queue_free()
		return
	if _flash_t > 0.0:
		_flash_t -= delta
	if target == null or not is_instance_valid(target):
		return
	var to := target.position - position
	var d := to.length()
	# Recycle enemies that have fallen hopelessly far behind — the player outruns every kind, so a
	# kiter otherwise leaves a permanent trail of stragglers that fill the MAX_ENEMIES cap and starve
	# fresh spawns, emptying the field ahead. Free the slot (silent despawn, no gem/kill) so the
	# spawner refills the ring around the player. Never cull the finale boss (it must reach the duel).
	if d > DESPAWN_DIST and not is_reaper:
		remove_from_group("enemies")
		queue_free()
		return
	if d > 0.5:
		position += to / d * speed * delta
	# Nudge off overlapping neighbors so the swarm reads as a crowd of bodies, not a single
	# stacked sprite, and stays legible when the whole horde piles onto the player.
	position += _separation() * speed * delta
	# Apply + bleed off any hit recoil, so a landed strike flings the body back a touch before
	# the chase reels it in again — weapons read as connecting, not passing through.
	if _knockback != Vector2.ZERO:
		position += _knockback * delta
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECEL * delta)
	# Player collider: ONE rectangle (VSPlayer.HITBOX_HALF, roughly the visible body). The SAME
	# boundary both BLOCKS the enemy — it presses against the body instead of burrowing into the
	# sprite — and, on contact, DEALS damage; "pressed against the player" and "hurting the player"
	# are now a single test. Modelled as that rect inflated by this enemy's radius (Minkowski sum),
	# so the round enemy body rolls along the flat player edge. Resolved LAST, after
	# chase/separation/knockback.
	var ihalf := VSPlayer.HITBOX_HALF + Vector2(radius, radius)
	var off_p := position - target.position
	var touching := absf(off_p.x) < ihalf.x and absf(off_p.y) < ihalf.y
	if touching:
		# Eject along the axis of least penetration to the nearest edge, so the body sits flush
		# just outside the flat side it came in on (fall back to +x if it's dead-centre).
		var pen_x := ihalf.x - absf(off_p.x)
		var pen_y := ihalf.y - absf(off_p.y)
		if pen_x <= pen_y:
			var sx := signf(off_p.x)
			off_p.x = (sx if sx != 0.0 else 1.0) * ihalf.x
		else:
			var sy := signf(off_p.y)
			off_p.y = (sy if sy != 0.0 else 1.0) * ihalf.y
		position = target.position + off_p
	_contact_cd -= delta
	if touching and _contact_cd <= 0.0 and target.alive:
		target.take_damage(contact_damage)
		_contact_cd = 0.5
	queue_redraw()

func _separation() -> Vector2:
	# Sum a soft push away from nearby enemies — stronger the closer they are — then cap it so
	# it only spaces the crowd out; it never overpowers the chase toward the player. The chase
	# pulls in, this pushes apart, so a dense wave settles into a readable ring of bodies around
	# the player instead of a single overlapping stack. O(n) over the (capped, dying excluded)
	# enemy group; cheap at the slice's enemy counts. Reach scales with body size, so a brute
	# claims more personal space than a bat.
	var push := Vector2.ZERO
	var reach := radius * PERSONAL_SPACE
	for other in get_tree().get_nodes_in_group("enemies"):
		var o := other as VSEnemy
		if o == null or o == self:
			continue
		var off := position - o.position
		var od := off.length()
		if od > 0.001 and od < reach:
			push += off / od * (1.0 - od / reach)   # 0 at the edge, ~1 when fully overlapping
	return push.limit_length(1.0) * SEPARATION

func hit(amount: float, from: Vector2) -> void:
	if _dying:
		return
	health -= amount
	if health <= 0.0:
		if run:
			run.add_kill(position, xp_value)
			if is_reaper:
				run._on_reaper_killed()   # slaying the finale boss WINS the run
		_spawn_damage_number(amount, true)   # bigger/brighter — the killing blow
		# Leave the group so targeting / projectiles / contact ignore the corpse, then pop.
		remove_from_group("enemies")
		_dying = true
		_die_t = DEATH_POP_DUR
		AgentBridge.emit_event("sfx_played", {"name": "kill"})
		Sfx.play("kill")
		queue_redraw()
	else:
		_flash_t = FLASH_DUR
		_apply_knockback(from)
		_spawn_damage_number(amount, false)
		AgentBridge.emit_event("sfx_played", {"name": "hit"})
		Sfx.play("hit")
		queue_redraw()

func _apply_knockback(from: Vector2) -> void:
	# Recoil away from the strike source. Some callers (the whip's AABB) pass the enemy's own
	# position, giving a zero direction — fall back to pushing straight away from the player so
	# every weapon flinches. Bigger/tougher kinds (larger radius) flinch less, like more mass.
	var dir := position - from
	if dir.length() < 0.5 and is_instance_valid(target):
		dir = position - target.position
	if dir.length() > 0.001:
		_knockback = dir.normalized() * KNOCKBACK * (RADIUS / radius)

func _spawn_damage_number(amount: float, killed: bool) -> void:
	# Float a rising, fading number above the body so weapon power reads as a quantity, not
	# just a flash. Added to `run` as a sibling (like the impact spark) so it outlives the
	# enemy's death pop; placed above the head so it never sits under the sprite.
	if run == null:
		return
	var dn := DamageNumber.new()
	dn.position = position + Vector2(0.0, -radius - 6.0)
	dn.amount = amount
	dn.killed = killed
	dn.run = run
	run.add_child(dn)

func _draw() -> void:
	var s := base_scale
	var tint := tier_tint
	var shadow_alpha := 1.0
	if _dying:
		var p := clampf(_die_t / DEATH_POP_DUR, 0.0, 1.0)   # 1 -> 0
		s = base_scale * (1.0 + (1.0 - p) * 0.6)   # pop outward as it dies
		tint = Color(1.6, 1.6, 1.6, p)             # bright, fading to transparent
		shadow_alpha = p                           # fade the ground shadow out with the death pop
	elif _flash_t > 0.0:
		s = base_scale * (1.0 + (_flash_t / FLASH_DUR) * 0.18)
		tint = Color(2.4, 2.4, 2.4)                # over-bright white hit flash
	_draw_shadow(shadow_alpha)                     # ground shadow first, beneath the sprite
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	# Subtle thin black rim behind the sprite so the body reads against the busy ground: the
	# silhouette tinted solid black at small 8-way offsets (modulate keeps transparent pixels clear,
	# so only the silhouette darkens). Skipped while dying so the bright fading death pop stays clean.
	if not _dying:
		var half := -sprite.get_size() * 0.5
		for off in OUTLINE_OFFSETS:
			draw_texture(sprite, half + off * OUTLINE_PX, OUTLINE_COLOR)
	draw_texture(sprite, -sprite.get_size() * 0.5, tint)

func _draw_shadow(alpha_mul: float) -> void:
	# A soft, flattened dark ellipse hugging the feet so each body reads as standing on the ground
	# rather than floating over the field. Sized to the enemy's RESTING footprint (base_scale, so a
	# brute casts a bigger shadow than a bat) and drawn first, beneath the sprite — it stays put
	# while the death pop scales the sprite, fading out with it instead of growing. A non-uniform
	# draw transform squashes a circle into the ellipse; reset afterwards so the sprite draws clean.
	var size := sprite.get_size()
	var center := Vector2(0.0, size.y * 0.5 * base_scale - SHADOW_LIFT)
	var rx := size.x * SHADOW_W_FRAC * 0.5 * base_scale
	var col := SHADOW_COLOR
	col.a *= alpha_mul
	draw_set_transform(center, 0.0, Vector2(1.0, SHADOW_FLATTEN))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Short-lived floating damage number: rises and fades, bigger + gold on a kill so the
## killing blow reads. Self-contained (no scene file) and primitive-drawn in _draw() via
## draw_string, matching the impact-spark / gem-sparkle juice pattern; gated on run.phase.
class DamageNumber extends Node2D:
	const DUR := 0.55          # total lifetime (s)
	const RISE := 24.0         # how far it floats up over its life (px)
	const HIT_SIZE := 14       # font size for a normal hit
	const KILL_SIZE := 20      # bigger on the killing blow
	const HIT_COLOR := Color(1.0, 0.96, 0.78)    # warm white for a normal hit
	const KILL_COLOR := Color(1.0, 0.80, 0.25)   # bright gold for a kill

	var amount := 0.0
	var killed := false
	var run: VSRun
	var _t := DUR

	func _ready() -> void:
		z_index = 110   # above the impact spark (100) so the number is never hidden

	func _process(delta: float) -> void:
		if run and run.phase != "playing":
			return   # hold with the frozen world (e.g. the level-up picker / game over)
		_t -= delta
		if _t <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		if font == null:
			return
		var p := clampf(_t / DUR, 0.0, 1.0)   # 1 -> 0
		var rise := (1.0 - p) * RISE
		var alpha := clampf(p * 1.4, 0.0, 1.0)   # hold full, then fade out near the end
		var fsize := KILL_SIZE if killed else HIT_SIZE
		var txt := str(int(round(amount)))
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var origin := Vector2(-w * 0.5, -rise)   # centered over the head, floating up
		var fill := KILL_COLOR if killed else HIT_COLOR
		fill.a = alpha
		var outline := Color(0.0, 0.0, 0.0, alpha * 0.85)
		draw_string_outline(font, origin, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 4, outline)
		draw_string(font, origin, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, fill)
