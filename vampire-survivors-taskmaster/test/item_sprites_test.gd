extends SceneTree

## Headless test for the Task 25 pickup + projectile sprite wiring.
##   godot --headless --path . --script res://test/item_sprites_test.gd
## Exit code == number of failed checks (0 == all passed).
## Verifies GameDatabase.projectile_sprite covers every weapon and
## pickup_sprite covers every pickup view key, returning real Texture2D
## resources (null for unknown ids). Uses load() so it ignores autoload order.

const GDB := preload("res://autoload/game_database.gd")

# One view key per distinct pickup (matches ViewSync._pickup_key outputs).
const PICKUP_KEYS := [
	&"gem_blue", &"gem_green", &"gem_red", &"gold", &"chicken",
	&"rosary", &"orologion", &"vacuum", &"nduja", &"rerollo", &"chest",
]

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== item_sprites_test ==")
	# Every weapon must have a projectile texture so nothing fires invisibly.
	var all_weapons := true
	for id in GDB.WEAPONS.keys():
		var tex = GDB.projectile_sprite(id)
		if not (tex is Texture2D):
			all_weapons = false
			printerr("    no projectile texture for weapon: ", id)
	_check(all_weapons, "every weapon id has a projectile Texture2D")
	_check(GDB.WEAPON_PROJECTILE_SPRITES.size() == GDB.WEAPONS.size(), "projectile sprite map covers all 8 weapons")

	# Every pickup view key must resolve to a texture.
	var all_pickups := true
	for key in PICKUP_KEYS:
		var tex = GDB.pickup_sprite(key)
		if not (tex is Texture2D):
			all_pickups = false
			printerr("    no pickup texture for key: ", key)
	_check(all_pickups, "every pickup view key has a Texture2D")
	_check(GDB.PICKUP_SPRITES.size() == PICKUP_KEYS.size(), "pickup sprite map covers all distinct kinds")

	# Spot checks: distinct gem tiers + unknown ids.
	_check(GDB.pickup_sprite(&"gem_blue") != GDB.pickup_sprite(&"gem_red"), "gem tiers use distinct textures")
	_check(GDB.projectile_sprite(&"whip") is Texture2D, "whip has a projectile texture")
	_check(GDB.projectile_sprite(&"nope") == null, "unknown weapon -> null projectile texture")
	_check(GDB.pickup_sprite(&"nope") == null, "unknown pickup key -> null texture")

	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)
