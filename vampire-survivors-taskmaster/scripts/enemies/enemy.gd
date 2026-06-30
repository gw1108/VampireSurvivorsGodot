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

var speed := 62.0
var health := 3.0
var contact_damage := 8.0
var radius := RADIUS            # per-enemy body size for contact + shot-catching; spawner sets it bigger for big kinds (brute) so what you see is what you hit
var xp_value := 1               # XP its death gem is worth; spawner bumps it for high-HP kinds (brute) so soaking a tank pays off
var kind := "bat"               # "bat" (slow sturdy) / "ghost" (fast fragile) / "brute" (slow tanky wall); set by spawner
var sprite: Texture2D = SPRITE  # per-enemy art so one VSEnemy class can be any kind
var base_scale := 1.0           # >1 for big kinds (brute) and hardened later-wave enemies; folds into _draw
var tier_tint := Color.WHITE    # red-shift for hardened enemies so their toughness reads at a glance
var run: VSRun
var target: VSPlayer
var _contact_cd := 0.0
var _flash_t := 0.0
var _dying := false
var _die_t := 0.0

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
	if d > 0.5:
		position += to / d * speed * delta
	# Nudge off overlapping neighbors so the swarm reads as a crowd of bodies, not a single
	# stacked sprite, and stays legible when the whole horde piles onto the player.
	position += _separation() * speed * delta
	_contact_cd -= delta
	if d < radius + VSPlayer.RADIUS and _contact_cd <= 0.0 and target.alive:
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

func hit(amount: float, _from: Vector2) -> void:
	if _dying:
		return
	health -= amount
	if health <= 0.0:
		if run:
			run.add_kill(position, xp_value)
		# Leave the group so targeting / projectiles / contact ignore the corpse, then pop.
		remove_from_group("enemies")
		_dying = true
		_die_t = DEATH_POP_DUR
		AgentBridge.emit_event("sfx_played", {"name": "kill"})
		Sfx.play("kill")
		queue_redraw()
	else:
		_flash_t = FLASH_DUR
		AgentBridge.emit_event("sfx_played", {"name": "hit"})
		Sfx.play("hit")
		queue_redraw()

func _draw() -> void:
	var s := base_scale
	var tint := tier_tint
	if _dying:
		var p := clampf(_die_t / DEATH_POP_DUR, 0.0, 1.0)   # 1 -> 0
		s = base_scale * (1.0 + (1.0 - p) * 0.6)   # pop outward as it dies
		tint = Color(1.6, 1.6, 1.6, p)             # bright, fading to transparent
	elif _flash_t > 0.0:
		s = base_scale * (1.0 + (_flash_t / FLASH_DUR) * 0.18)
		tint = Color(2.4, 2.4, 2.4)                # over-bright white hit flash
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_texture(sprite, -sprite.get_size() * 0.5, tint)
