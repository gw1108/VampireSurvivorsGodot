class_name VSProjectile
extends Node2D
## A straight-flying bullet. Damages the first enemy it overlaps, then despawns.
## Lifetime-bounded so stray shots clean themselves up.

const RADIUS := 4.0
const HIT_RADIUS := 10.0

var speed := 430.0
var damage := 2.0
var life := 1.4
var dir := Vector2.RIGHT
var run: VSRun

func _ready() -> void:
	add_to_group("projectiles")

func _process(delta: float) -> void:
	if run and run.phase != "playing":
		return   # freeze in place while the level-up picker is up
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e.position - position).length() < HIT_RADIUS + e.radius:
			e.hit(damage, position)
			_spawn_impact(position)
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.95, 0.4))

func _spawn_impact(at: Vector2) -> void:
	# Leave a brief spark where the shot lands so hits read instead of vanishing silently.
	if run == null:
		return
	var spark := ImpactSpark.new()
	spark.position = at
	spark.run = run
	run.add_child(spark)

## Short-lived impact spark: an expanding ring + a few warm spokes, then frees itself.
## Self-contained (no scene file), matching the gem/enemy juice effects.
class ImpactSpark extends Node2D:
	const DUR := 0.12

	var run: VSRun
	var _t := DUR

	func _ready() -> void:
		z_index = 100   # pop above the enemy/player sprites for the brief flash

	func _process(delta: float) -> void:
		if run and run.phase != "playing":
			return   # hold with the frozen world (e.g. the level-up picker)
		_t -= delta
		if _t <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var p := clampf(_t / DUR, 0.0, 1.0)   # 1 -> 0
		var grow := 1.0 - p
		var r := 3.0 + grow * 11.0            # ring expands outward
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(1.0, 0.95, 0.6, p * 0.9), 2.0)
		var sr := 2.0 + grow * 9.0            # short radial spokes burst out
		var c := Color(1.0, 1.0, 0.8, p)
		for i in 4:
			var ang := i * PI / 2.0 + PI / 4.0
			draw_line(Vector2.from_angle(ang) * (sr * 0.4), Vector2.from_angle(ang) * sr, c, 1.5)
