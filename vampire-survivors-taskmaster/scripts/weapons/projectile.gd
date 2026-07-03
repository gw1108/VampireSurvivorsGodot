class_name VSProjectile
extends Node2D
## A straight-flying bullet. Damages the first enemy it overlaps, then despawns.
## Lifetime-bounded so stray shots clean themselves up.

const RADIUS := 4.0
const HIT_RADIUS := 10.0
# The dagger sprite's blade points up-right (-45deg / -PI/4) in the source art, so we
# add PI/4 when aligning it to the travel direction.
const ART_ANGLE_OFFSET := PI / 4.0

var speed := 430.0
var damage := 2.0
var life := 1.4
var dir := Vector2.RIGHT
var run: VSRun
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("projectiles")
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/projectile_dagger.png")
	_sprite.rotation = dir.angle() + ART_ANGLE_OFFSET
	add_child(_sprite)

func _process(delta: float) -> void:
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if (e.position - position).length() < HIT_RADIUS + VSEnemy.RADIUS:
			e.hit(damage, position)
			queue_free()
			return
