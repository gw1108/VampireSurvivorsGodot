class_name VSCandelabra
extends Node2D
## Destructible light source — the Vampire Survivors candelabra/brazier. A few are scattered
## across the arena at run start; any weapon that sweeps through one shatters it, rolling a
## random bonus pickup (Rosary screen-clear, Magnet, a coin bag, or a floor chicken — see
## VSRun.drop_candelabra_bonus). Rewards exploring the arena and gives the lucky drops a
## reliable-ish source beyond rare kill drops.
##
## It joins the "enemies" group so every existing AREA weapon (Whip/Garlic/King Bible) damages
## it for free with no per-weapon wiring — but it never moves, never touches the player, and
## never pays out a kill (its own _process below). The aimed auto-projectile deliberately skips
## props (see VSWeapon._nearest_enemy) so it doesn't waste bolts on scenery, and the AgentBridge
## adapter reports candelabra as their own entity type, not as threats.

static var HEALTH := BalanceData.get_value("candelabra_health", 6.0)            # a couple of whip lashes / garlic pulses shatter it
static var RADIUS := BalanceData.get_value("candelabra_radius", 18.0)           # hit radius the area weapons test against
# The source candelabra.png is a 256px canvas — huge beside the ~40px player/enemies. Scale it
# down to read as a believable tall light source (~1.5x player height), not a screen-filling prop.
static var SPRITE_SCALE := BalanceData.get_value("candelabra_sprite_scale", 0.28)

var run: VSRun
var health := HEALTH
var radius := RADIUS
var _broken := false
var _t := 0.0
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("enemies")      # so all area weapons damage it with no per-weapon wiring
	add_to_group("candelabra")
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/candelabra.png")
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(_sprite)

func _process(delta: float) -> void:
	# Gentle warm candle flicker so the light source reads as alive, not scenery debris.
	_t += delta
	if _sprite:
		var glow := 0.5 + 0.5 * sin(_t * 6.0)
		_sprite.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.15, 0.75), glow)

## Weapon-hit entry point, matching VSEnemy.hit() so area weapons strike it uniformly.
## Accrues damage and shatters (dropping a bonus) once its small HP pool is spent.
func hit(amount: float, _from: Vector2) -> void:
	if _broken:
		return
	health -= amount
	if health <= 0.0:
		_break()

func _break() -> void:
	_broken = true
	var parent := get_parent()
	if parent != null:
		# Warm shatter bloom + golden shard burst so breaking a light source reads as a
		# rewarding, satisfying little event worth seeking out.
		VSPickupFlash.spawn(parent, position, Color(1.0, 0.82, 0.4))
		VSCandelabraShatter.spawn(parent, position)
	if run:
		run.add_camera_shake(0.25)   # a tiny jolt so the shatter lands with weight
		run.drop_candelabra_bonus(position)
	AgentBridge.emit_event("despawn", {"type": "candelabra", "pos": [position.x, position.y]})
	queue_free()
