class_name VSProjectile
extends Node2D
## A straight-flying bullet. Damages the first enemy it overlaps, then despawns.
## Lifetime-bounded so stray shots clean themselves up.

const RADIUS := 4.0
## Tuned baseline hit radius (at projectile_scale 1.0). The live hitbox is `hit_radius` below, set in
## _ready to scale with the CSV's projectile_scale so the strike range tracks the bolt's rendered size.
static var HIT_RADIUS := BalanceData.get_value("projectile_hit_radius", 10.0)
# The dagger sprite's blade points up-right (-45deg / -PI/4) in the source art, so we
# add PI/4 when aligning it to the travel direction.
const ART_ANGLE_OFFSET := PI / 4.0

var speed := BalanceData.get_value("projectile_base_speed", 430.0)   # default bolt travel speed (the Magic Wand fires at this; the Knife overrides it)
var damage := 2.0
var life := BalanceData.get_value("projectile_base_life", 1.4)       # default seconds before a stray bolt despawns (Knife overrides it)
var dir := Vector2.RIGHT
var pierce := 0                  # extra enemies the bolt passes through (0 = despawn on first hit)
var hit_radius := HIT_RADIUS     # live strike radius, set in _ready to HIT_RADIUS * projectile_scale
var run: VSRun
var _sprite: Sprite2D
var _hit := {}                   # enemies already struck, so a piercing bolt never re-hits one

func _ready() -> void:
	add_to_group("projectiles")
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/projectile_dagger.png")
	_sprite.rotation = dir.angle() + ART_ANGLE_OFFSET
	# Bolt size knob a designer can retune in res://data/balance.csv (default 1.0 = native art size).
	# Scales the sprite AND the hit radius by the same factor, so the strike range stays matched to the
	# rendered bolt. At the default 1.0 hit_radius is exactly the tuned HIT_RADIUS baseline.
	var bolt_scale := BalanceData.get_value("projectile_scale", 1.0)
	_sprite.scale = Vector2.ONE * bolt_scale
	hit_radius = HIT_RADIUS * bolt_scale
	add_child(_sprite)

func _process(delta: float) -> void:
	if run == null:
		return
	# Freeze with the game during level-up / pause / after the run ends (mirrors every other
	# weapon; the sibling world-space bolts VSRunetracer.Bolt / VSFireWand.Fireball do the same).
	if run.phase != "playing":
		return
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if _hit.has(e):
			continue
		if (e.position - position).length() < hit_radius + VSEnemy.RADIUS:
			e.hit(damage, position)
			# A plain bolt dies on its first hit; a Holy Wand bolt keeps going until it has
			# pierced `pierce` further enemies, tracking who it struck so it can't re-drain one.
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1
			_hit[e] = true
