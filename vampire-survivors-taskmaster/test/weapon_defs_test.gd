extends SceneTree

## Headless validation of the Task 28 weapon definitions + weapon_stat_at_level.
##   godot --headless --path . --script res://test/weapon_defs_test.gd
## Exit code == number of failed checks (0 == all passed).
##
## Guards the 8 slice weapons: every required field present, an 8-element level
## curve whose deltas use only known keys, sane bases, and that the new
## weapon_stat_at_level accessor resolves base + deltas correctly (the same math
## WeaponSystem._resolve_weapon relies on). Resolved level-8 totals are checked
## against the hand-summed wiki curves so a bad delta can't slip in unnoticed.

const GDB := preload("res://autoload/game_database.gd")

const EXPECTED := [&"whip", &"knife", &"magic_wand", &"runetracer", &"garlic",
	&"king_bible", &"fire_wand", &"lightning_ring"]
const DELTA_KEYS := ["dmg", "amount", "area", "speed", "cooldown", "duration", "pierce"]
const REQUIRED := ["name", "base_dmg", "cooldown", "amount", "area", "speed",
	"duration", "pierce", "knockback", "pattern", "levels"]

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== weapon_defs_test ==")
	_test_roster()
	_test_shape()
	_test_accessor_resolution()
	_test_resolved_max_levels()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _approx(a: float, b: float, msg: String) -> void:
	_check(is_equal_approx(a, b), "%s (got %f, want %f)" % [msg, a, b])

func _test_roster() -> void:
	_check(GDB.WEAPONS.size() == 8, "exactly 8 weapons defined, got %d" % GDB.WEAPONS.size())
	for id in EXPECTED:
		_check(GDB.WEAPONS.has(id), "weapon '%s' defined" % id)

func _test_shape() -> void:
	for id in EXPECTED:
		var def: Dictionary = GDB.weapon(id)
		for key in REQUIRED:
			_check(def.has(key), "%s has required field '%s'" % [id, key])
		_check(float(def.base_dmg) >= 0.0, "%s base_dmg non-negative" % id)
		_check(float(def.cooldown) > 0.0, "%s cooldown positive" % id)
		_check(int(def.amount) >= 0, "%s amount non-negative" % id)
		# pierce convention: -1 (infinite) or a positive finite count, never 0
		_check(int(def.pierce) == -1 or int(def.pierce) >= 1, "%s pierce is -1 or >=1" % id)
		_check(String(def.pattern) != "", "%s has a non-empty pattern" % id)
		# level curve: 8 entries, base empty, deltas use only known keys
		var levels: Array = def.levels
		_check(levels.size() == 8, "%s has an 8-level curve" % id)
		_check((levels[0] as Dictionary).is_empty(), "%s level-1 entry is the empty base" % id)
		for i in range(1, levels.size()):
			for k in (levels[i] as Dictionary).keys():
				_check(k in DELTA_KEYS, "%s L%d delta key '%s' is a known stat" % [id, i + 1, k])

func _test_accessor_resolution() -> void:
	# unknown id -> 0; level 1 == base only (no deltas); damage maps to base_dmg.
	_approx(GDB.weapon_stat_at_level(&"nope", 8, "dmg"), 0.0, "unknown weapon -> 0")
	_approx(GDB.weapon_stat_at_level(&"whip", 1, "dmg"), 10.0, "whip L1 damage == base_dmg 10 (dmg maps to base_dmg)")
	_approx(GDB.weapon_stat_at_level(&"whip", 1, "area"), 1.0, "whip L1 area == base 1.0")
	# clamp: level beyond the curve resolves the same as level 8
	_approx(GDB.weapon_stat_at_level(&"fire_wand", 99, "dmg"),
		GDB.weapon_stat_at_level(&"fire_wand", 8, "dmg"), "level past curve clamps to max")

func _test_resolved_max_levels() -> void:
	# weapon_stat_at_level returns the FULL resolved value (base + deltas).
	# Totals hand-checked against the per-level curves (and confirmed vs wiki).
	_approx(GDB.weapon_stat_at_level(&"whip", 8, "dmg"), 40.0, "whip L8 damage 40")
	_approx(GDB.weapon_stat_at_level(&"whip", 8, "area"), 1.2, "whip L8 area 1.2")
	_approx(GDB.weapon_stat_at_level(&"whip", 8, "amount"), 2.0, "whip L8 amount 2")
	_approx(GDB.weapon_stat_at_level(&"knife", 8, "dmg"), 16.5, "knife L8 damage 16.5")
	_approx(GDB.weapon_stat_at_level(&"knife", 8, "amount"), 6.0, "knife L8 amount 6")
	_approx(GDB.weapon_stat_at_level(&"knife", 8, "pierce"), 3.0, "knife L8 pierce 3")
	_approx(GDB.weapon_stat_at_level(&"magic_wand", 8, "cooldown"), 1.0, "magic_wand L8 cooldown 1.0")
	_approx(GDB.weapon_stat_at_level(&"magic_wand", 8, "dmg"), 30.0, "magic_wand L8 damage 30")
	_approx(GDB.weapon_stat_at_level(&"fire_wand", 8, "dmg"), 90.0, "fire_wand L8 damage 90")
	_approx(GDB.weapon_stat_at_level(&"fire_wand", 8, "speed"), 1.35, "fire_wand L8 speed 1.35")
	_approx(GDB.weapon_stat_at_level(&"lightning_ring", 8, "dmg"), 65.0, "lightning_ring L8 damage 65")
	_approx(GDB.weapon_stat_at_level(&"lightning_ring", 8, "amount"), 6.0, "lightning_ring L8 amount 6")
	_approx(GDB.weapon_stat_at_level(&"lightning_ring", 8, "area"), 4.0, "lightning_ring L8 area 4")
	# runetracer: 2.25 + (0.3+0.3+0.5) = 3.35 (verbatim level-table sum; wiki
	# summary rounds to 3.25 — documented footnote in WEAPONS). king_bible 3.0+1.0.
	_approx(GDB.weapon_stat_at_level(&"runetracer", 8, "duration"), 3.35, "runetracer L8 duration 3.35")
	_approx(GDB.weapon_stat_at_level(&"king_bible", 8, "duration"), 4.0, "king_bible L8 duration 4.0")
