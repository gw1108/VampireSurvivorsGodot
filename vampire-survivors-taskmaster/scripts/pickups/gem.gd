class_name VSGem
extends Node2D
## XP gem dropped on enemy death. Magnetizes toward a nearby player and grants XP on
## pickup. Feeds the level counter that drives the level-up upgrade picker.

const RADIUS := 6.0
const PICKUP := 24.0
const MAGNET := 140.0          # range at which a gem starts homing toward the player (a touch wider than the player sprite's reach so your wake gets swept up)
# Distance-ramped homing: slow at the edge of MAGNET range, accelerating to a "vacuum" snap right
# before pickup. MAGNET_SPEED_MAX is kept comfortably above the player's top speed (base 210, and
# higher with Swift) so a gem behind a fleeing/kiting player still catches up — a flat 240 px/s
# barely beat the 210 base and LOST to a Swift-stacked player, stranding XP and starving level-ups.
const MAGNET_SPEED_MIN := 230.0
const MAGNET_SPEED_MAX := 560.0
const SPRITE := preload("res://art/gem_xp.png")
const SPRITE_RICH := preload("res://art/gem_xp_red.png")   # high-value drop (e.g. a brute): reads RED so soaking a tank pays off
const SPARK_DUR := 0.18   # brief sparkle the gem plays on pickup before freeing

var run: VSRun
var xp_value := 1         # XP granted on pickup; >1 draws the richer red gem (set by the spawner via the enemy)
var vacuum := false       # level-up sweep: when set, this gem homes to the player regardless of distance
var _collected := false
var _spark_t := 0.0

func _ready() -> void:
	add_to_group("gems")

func _process(delta: float) -> void:
	if _collected:
		# Play out the pickup sparkle independent of phase (collect_xp may have just
		# popped the level-up picker) so the gem always finishes and frees.
		_spark_t -= delta
		queue_redraw()
		if _spark_t <= 0.0:
			queue_free()
		return
	if run == null or run.player == null or not is_instance_valid(run.player):
		return
	if run.phase != "playing":
		return   # frozen world: no magnet / pickup while the level-up picker is up
	var pl := run.player
	var to := pl.position - position
	var d := to.length()
	if vacuum and d > 0.5:
		# Level-up sweep: this gem was flagged (in VSRun._show_level_up) to rush the player
		# regardless of distance, so the whole field of XP vacuums in at the snap speed as the
		# world unfreezes — the iconic VS level-up rush. MAGNET_SPEED_MAX stays above any player
		# speed, so even far-flung gems catch up and none are left orphaned.
		position += to / d * MAGNET_SPEED_MAX * delta
	elif d < MAGNET and d > 0.5:
		# Speed ramps up as the gem nears the player (0 at the edge -> 1 at pickup), so the pull
		# starts gentle and snaps in like a vacuum — and the peak stays above any player speed, so
		# fleeing the death-pile never strands the gem.
		var t := 1.0 - clampf(d / MAGNET, 0.0, 1.0)
		var sp := lerpf(MAGNET_SPEED_MIN, MAGNET_SPEED_MAX, t)
		position += to / d * sp * delta
	if d < PICKUP + VSPlayer.RADIUS:
		run.collect_xp(xp_value)
		AgentBridge.emit_event("pickup", {"type": "xp", "value": xp_value})
		_collected = true
		_spark_t = SPARK_DUR
		queue_redraw()
		return
	queue_redraw()

func _draw() -> void:
	var tex := SPRITE_RICH if xp_value > 1 else SPRITE   # richer drops read RED
	if not _collected:
		draw_texture(tex, -tex.get_size() * 0.5)
		return
	# Pickup pop: gem scales up + brightens + fades, with a small expanding star burst.
	var p := clampf(_spark_t / SPARK_DUR, 0.0, 1.0)   # 1 -> 0
	var s := 1.0 + (1.0 - p) * 0.8
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_texture(tex, -tex.get_size() * 0.5, Color(1.8, 1.8, 1.8, p))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # unscaled so the burst grows on its own
	var r := 4.0 + (1.0 - p) * 12.0
	var c := Color(1.0, 1.0, 0.7, p * 0.9)
	for a in 8:
		draw_line(Vector2.ZERO, Vector2.from_angle(a * PI / 4.0) * r, c, 2.0)
