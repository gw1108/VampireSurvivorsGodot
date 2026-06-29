extends SceneTree

## Headless validation of the Task 29 passive definitions.
##   godot --headless --path . --script res://test/passive_defs_test.gd
## Exit code == number of failed checks (0 == all passed).
##
## Guards the 8 slice passives' DATA (roster, stat target, per_level, max_level,
## stacking, Armor retaliation) and ties that data to StatSystem so a transcription
## error in per_level/stacking is caught as a wrong resolved stat — not just a
## wrong number in a table. (StatSystem resolution is covered in depth by
## stat_system_test; here we assert just enough to bind data -> behaviour.)

const GDB := preload("res://autoload/game_database.gd")

const EXPECTED := [&"spinach", &"armor", &"hollow_heart", &"empty_tome",
	&"candelabrador", &"bracer", &"wings", &"duplicator"]
const REQUIRED := ["name", "stat", "per_level", "max_level", "stacking"]
# Every passive's stat target must be a real StatBlock field.
const STAT_FIELDS := ["max_health", "armor", "might", "cooldown", "area",
	"speed", "move_speed", "amount", "recovery", "magnet", "luck", "growth",
	"greed", "curse", "duration"]

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== passive_defs_test ==")
	_test_roster()
	_test_shape()
	_test_specifics()
	_test_resolution_binding()
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

func _resolve(id: StringName, level: int) -> PlayerState:
	var p := PlayerState.new()
	var pi := PassiveInstance.new()
	pi.id = id
	pi.level = level
	p.passives.append(pi)
	StatSystem.recompute(p, GDB)
	return p

func _test_roster() -> void:
	_check(GDB.PASSIVES.size() == 8, "exactly 8 passives, got %d" % GDB.PASSIVES.size())
	for id in EXPECTED:
		_check(GDB.PASSIVES.has(id), "passive '%s' defined" % id)

func _test_shape() -> void:
	for id in EXPECTED:
		var def: Dictionary = GDB.passive(id)
		for key in REQUIRED:
			_check(def.has(key), "%s has required field '%s'" % [id, key])
		_check(String(def.stat) in STAT_FIELDS, "%s stat '%s' is a real StatBlock field" % [id, def.stat])
		_check(int(def.max_level) >= 1, "%s max_level >= 1" % id)
		_check(def.stacking == "additive" or def.stacking == "multiplicative",
			"%s stacking is additive|multiplicative" % id)

func _test_specifics() -> void:
	# Only Hollow Heart is multiplicative; everything else additive.
	for id in EXPECTED:
		var expect_mult: bool = id == &"hollow_heart"
		var is_mult: bool = GDB.passive(id).stacking == "multiplicative"
		_check(is_mult == expect_mult, "%s multiplicative == %s" % [id, expect_mult])
	# Duplicator caps at 2; the other seven at 5.
	_check(int(GDB.passive(&"duplicator").max_level) == 2, "Duplicator max_level 2")
	for id in [&"spinach", &"armor", &"hollow_heart", &"empty_tome", &"candelabrador", &"bracer", &"wings"]:
		_check(int(GDB.passive(id).max_level) == 5, "%s max_level 5" % id)
	# Empty Tome reduces cooldown -> negative per_level; the others are positive.
	_check(float(GDB.passive(&"empty_tome").per_level) < 0.0, "Empty Tome per_level is negative (cooldown reduction)")
	for id in [&"spinach", &"armor", &"hollow_heart", &"candelabrador", &"bracer", &"wings", &"duplicator"]:
		_check(float(GDB.passive(id).per_level) > 0.0, "%s per_level positive" % id)
	# Armor carries a retaliatory-damage value.
	_check(GDB.passive(&"armor").has("retaliatory") and float(GDB.passive(&"armor").retaliatory) > 0.0,
		"Armor has a positive retaliatory value")

func _test_resolution_binding() -> void:
	# Bind the data to StatSystem so a bad per_level/stacking surfaces as a stat.
	# Spinach L5: might 1.0 + 5*0.10 = 1.5
	_approx(_resolve(&"spinach", 5).stats.might, 1.5, "Spinach L5 -> might 1.5 (additive)")
	# Hollow Heart L5: multiplicative 120 * 1.2^5 (NOT additive 240)
	_approx(_resolve(&"hollow_heart", 5).stats.max_health, 120.0 * pow(1.2, 5),
		"Hollow Heart L5 -> 120 * 1.2^5 (multiplicative)")
	# Empty Tome L5: cooldown 1.0 - 5*0.08 = 0.60
	_approx(_resolve(&"empty_tome", 5).stats.cooldown, 0.60, "Empty Tome L5 -> cooldown 0.60")
	# Duplicator L2: amount 0 + 2*1 = 2
	_approx(_resolve(&"duplicator", 2).stats.amount, 2.0, "Duplicator L2 -> amount 2")
	# Armor L5: Antonio base armor 1 + 5 = 6
	_approx(_resolve(&"armor", 5).stats.armor, 6.0, "Armor L5 -> armor 6 (incl Antonio +1)")
