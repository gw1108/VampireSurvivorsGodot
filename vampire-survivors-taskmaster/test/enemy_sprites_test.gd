extends SceneTree

## Headless test for the Task 24 enemy sprite wiring.
##   godot --headless --path . --script res://test/enemy_sprites_test.gd
## Exit code == number of failed checks (0 == all passed).
## Verifies GameDatabase.enemy_sprite_frames covers the whole ENEMIES roster and
## that every mapped SpriteFrames carries the idle + walk animations ViewSync
## drives. Uses load() so it does not depend on autoload init order.

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== enemy_sprites_test ==")
	# Every enemy id in the stat roster must resolve to a SpriteFrames so no
	# spawned enemy renders blank.
	var all_covered := true
	var all_have_anims := true
	for id in GDB.ENEMIES.keys():
		var frames = GDB.enemy_sprite_frames(id)
		if frames == null:
			all_covered = false
			printerr("    no SpriteFrames for enemy: ", id)
			continue
		if not (frames is SpriteFrames):
			all_covered = false
			printerr("    mapping is not a SpriteFrames: ", id)
			continue
		if not (frames.has_animation(&"walk") and frames.has_animation(&"idle")):
			all_have_anims = false
			printerr("    SpriteFrames missing idle/walk: ", id)
	_check(all_covered, "every ENEMIES id maps to a SpriteFrames")
	_check(all_have_anims, "every enemy SpriteFrames has idle + walk animations")

	# A few explicit spot checks (incl. shared art and the Reaper).
	_check(GDB.enemy_sprite_frames(&"zombie") is SpriteFrames, "zombie has SpriteFrames")
	_check(GDB.enemy_sprite_frames(&"reaper") is SpriteFrames, "reaper has SpriteFrames")
	_check(GDB.enemy_sprite_frames(&"giant_werewolf") == GDB.enemy_sprite_frames(&"werewolf"),
		"boss reuses its base creature art (giant_werewolf == werewolf)")
	_check(GDB.enemy_sprite_frames(&"bat_swarm") == GDB.enemy_sprite_frames(&"bat"),
		"swarm variant reuses base art (bat_swarm == bat)")
	_check(GDB.enemy_sprite_frames(&"giant_mantichana") != GDB.enemy_sprite_frames(&"mantichana"),
		"giant mantichana uses its distinct warrior art")
	_check(GDB.enemy_sprite_frames(&"unknown_thing") == null, "unknown enemy id -> null frames")

	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)
