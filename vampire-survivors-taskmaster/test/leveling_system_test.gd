extends SceneTree

## Headless test runner for the Task 10 LevelingSystem.
##   godot --headless --path . --script res://test/leveling_system_test.gd
## Exit code == number of failed checks (0 == all passed).
## Uses the GameDatabase script class as `db` (static accessors -> clean calls).

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== leveling_system_test ==")
	_test_add_xp_single_level()
	_test_add_xp_multi_level()
	_test_add_xp_growth_multiplier()
	_test_add_xp_no_level()
	_test_add_xp_dirty_every_ten()
	_test_options_count_and_unique()
	_test_options_full_inventory_only_upgrades()
	_test_options_excludes_maxed()
	_test_options_all_maxed_fallback()
	_test_options_deterministic()
	_test_apply_weapon_upgrade()
	_test_apply_passive_upgrade()
	_test_apply_new_weapon_and_passive()
	_test_apply_gold_and_chicken()
	_test_reroll()
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

func _fresh() -> PlayerState:
	var p := PlayerState.new()
	StatSystem.recompute(p, GDB)  # populates stats (luck 1.0, max_health 120)
	return p

func _add_weapon(p: PlayerState, id: StringName, level: int) -> void:
	var w := WeaponInstance.new()
	w.id = id
	w.level = level
	p.weapons.append(w)

func _add_passive(p: PlayerState, id: StringName, level: int) -> void:
	var pi := PassiveInstance.new()
	pi.id = id
	pi.level = level
	p.passives.append(pi)

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

# --- add_xp ------------------------------------------------------------------

func _test_add_xp_single_level() -> void:
	var p := _fresh()  # L1, xp 0, xp_to_next 5
	var gained := LevelingSystem.add_xp(p, GDB, 5.0)
	_check(gained == 1, "add_xp 5 at L1 -> 1 level gained")
	_check(p.level == 2, "level advanced to 2")
	_approx(p.xp, 0.0, "leftover xp 0 after exact threshold")
	_approx(p.xp_to_next, GDB.xp_to_next(2), "xp_to_next refreshed for L2 (15)")
	_approx(GDB.xp_to_next(2), 15.0, "xp_to_next(2) == 15 (sanity)")

func _test_add_xp_multi_level() -> void:
	# Thresholds from L1: 5,15,25,35,45 -> 100 xp lands at L5 with 20 leftover.
	var p := _fresh()
	var gained := LevelingSystem.add_xp(p, GDB, 100.0)
	_check(gained == 4, "big gem of 100 xp -> 4 levels gained")
	_check(p.level == 5, "level advanced to 5")
	_approx(p.xp, 20.0, "leftover xp 20 after crossing four thresholds")
	_approx(p.xp_to_next, 45.0, "xp_to_next == 45 at L5")

func _test_add_xp_growth_multiplier() -> void:
	var p := _fresh()
	p.stats.growth = 2.0  # 2.5 raw -> 5.0 effective -> exactly one level
	var gained := LevelingSystem.add_xp(p, GDB, 2.5)
	_check(gained == 1 and p.level == 2, "growth 2.0 doubles XP gain (2.5 -> level up)")

func _test_add_xp_no_level() -> void:
	var p := _fresh()
	p.stats_dirty = false
	var gained := LevelingSystem.add_xp(p, GDB, 3.0)  # below 5 threshold
	_check(gained == 0 and p.level == 1, "sub-threshold XP gains no level")
	_approx(p.xp, 3.0, "xp accumulates toward next level")
	_check(p.stats_dirty == false, "no level -> stats_dirty untouched (non-10 optimization)")

func _test_add_xp_dirty_every_ten() -> void:
	var p := _fresh()
	p.level = 9
	p.xp_to_next = GDB.xp_to_next(9)
	p.stats_dirty = false
	var gained := LevelingSystem.add_xp(p, GDB, GDB.xp_to_next(9))
	_check(gained == 1 and p.level == 10, "advanced to L10")
	_check(p.stats_dirty == true, "crossing a multiple of 10 raises stats_dirty (Might bonus)")

# --- make_options ------------------------------------------------------------

func _opt_key(o: Dictionary) -> String:
	return "%s:%s" % [o.type, o.get("id", "")]

func _test_options_count_and_unique() -> void:
	for s in range(20):
		var p := _fresh()  # empty inventory, luck 1.0
		_add_weapon(p, &"whip", 1)
		var opts := LevelingSystem.make_options(p, GDB, _rng(s))
		_check(opts.size() == 3, "base luck -> exactly 3 options (seed %d)" % s)
		var seen := {}
		var dup := false
		for o in opts:
			var k := _opt_key(o)
			if seen.has(k):
				dup = true
			seen[k] = true
		_check(not dup, "options are unique (seed %d)" % s)

func _test_options_full_inventory_only_upgrades() -> void:
	var p := _fresh()
	for wid in [&"whip", &"knife", &"magic_wand", &"runetracer", &"garlic", &"king_bible"]:
		_add_weapon(p, wid, 1)
	for pid in [&"spinach", &"armor", &"hollow_heart", &"empty_tome", &"candelabrador", &"bracer"]:
		_add_passive(p, pid, 1)
	var only_upgrades := true
	var levels_ok := true
	for s in range(15):
		for o in LevelingSystem.make_options(p, GDB, _rng(s)):
			if o.type != "weapon_upgrade" and o.type != "passive_upgrade":
				only_upgrades = false
			elif o.level != 2:
				levels_ok = false
	_check(only_upgrades, "full inventory -> no new_* options, only upgrades")
	_check(levels_ok, "upgrade options target current level + 1")

func _test_options_excludes_maxed() -> void:
	# Whip maxed at 8; Duplicator maxed at its DB max_level (2) -> never offered.
	var p := _fresh()
	_add_weapon(p, &"whip", 8)
	for wid in [&"knife", &"magic_wand", &"runetracer", &"garlic", &"king_bible"]:
		_add_weapon(p, wid, 1)
	_add_passive(p, &"duplicator", 2)
	for pid in [&"spinach", &"armor", &"hollow_heart", &"empty_tome", &"candelabrador"]:
		_add_passive(p, pid, 1)
	var saw_maxed := false
	for s in range(30):
		for o in LevelingSystem.make_options(p, GDB, _rng(s)):
			if o.get("id", &"") == &"whip" or o.get("id", &"") == &"duplicator":
				saw_maxed = true
	_check(not saw_maxed, "maxed Whip (8) and Duplicator (2) are excluded from options")

func _test_options_all_maxed_fallback() -> void:
	var p := _fresh()
	for wid in [&"whip", &"knife", &"magic_wand", &"runetracer", &"garlic", &"king_bible"]:
		_add_weapon(p, wid, 8)
	for pid in [&"spinach", &"armor", &"hollow_heart", &"empty_tome", &"candelabrador", &"bracer"]:
		_add_passive(p, pid, 5)
	var opts := LevelingSystem.make_options(p, GDB, _rng(1))
	_check(opts.size() == 2, "fully maxed -> 2 consolation options")
	_check(opts[0].type == "gold" and opts[0].value == 25, "first consolation is 25 gold")
	_check(opts[1].type == "chicken", "second consolation is Floor Chicken")

func _test_options_deterministic() -> void:
	var pa := _fresh()
	var pb := _fresh()
	for pp in [pa, pb]:
		_add_weapon(pp, &"whip", 1)
	var oa := LevelingSystem.make_options(pa, GDB, _rng(12345))
	var ob := LevelingSystem.make_options(pb, GDB, _rng(12345))
	var same := oa.size() == ob.size()
	if same:
		for i in range(oa.size()):
			if _opt_key(oa[i]) != _opt_key(ob[i]):
				same = false
	_check(same, "same seed + same state -> identical option set (reproducible)")

# --- apply_choice ------------------------------------------------------------

func _test_apply_weapon_upgrade() -> void:
	var p := _fresh()
	_add_weapon(p, &"whip", 1)
	p.stats_dirty = false
	LevelingSystem.apply_choice(p, GDB, {type = "weapon_upgrade", id = &"whip", level = 2})
	_check(p.weapons[0].level == 2, "weapon_upgrade raises owned weapon level")
	_check(p.stats_dirty == true, "apply_choice raises stats_dirty")

func _test_apply_passive_upgrade() -> void:
	var p := _fresh()
	_add_passive(p, &"spinach", 1)
	LevelingSystem.apply_choice(p, GDB, {type = "passive_upgrade", id = &"spinach", level = 3})
	_check(p.passives[0].level == 3, "passive_upgrade sets chosen level")

func _test_apply_new_weapon_and_passive() -> void:
	var p := _fresh()
	LevelingSystem.apply_choice(p, GDB, {type = "new_weapon", id = &"knife"})
	_check(p.weapons.size() == 1 and p.weapons[0].id == &"knife" and p.weapons[0].level == 1,
		"new_weapon appends a level-1 WeaponInstance")
	LevelingSystem.apply_choice(p, GDB, {type = "new_passive", id = &"armor"})
	_check(p.passives.size() == 1 and p.passives[0].id == &"armor" and p.passives[0].level == 1,
		"new_passive appends a level-1 PassiveInstance")

func _test_apply_gold_and_chicken() -> void:
	var p := _fresh()  # stats.max_health == 120
	LevelingSystem.apply_choice(p, GDB, {type = "gold", value = 25})
	_check(p.gold == 25, "gold option adds its value")
	p.hp = 50.0
	LevelingSystem.apply_choice(p, GDB, {type = "chicken"})
	_approx(p.hp, 80.0, "chicken heals 30")
	p.hp = 110.0
	LevelingSystem.apply_choice(p, GDB, {type = "chicken"})
	_approx(p.hp, 120.0, "chicken heal clamps to max_health")

# --- reroll ------------------------------------------------------------------

func _test_reroll() -> void:
	var p := _fresh()
	_add_weapon(p, &"whip", 1)
	var empty := LevelingSystem.reroll(p, GDB, _rng(0))
	_check(empty.is_empty() and p.reroll_charges == 0, "reroll with 0 charges -> empty, no charge spent")
	p.reroll_charges = 2
	var opts := LevelingSystem.reroll(p, GDB, _rng(0))
	_check(opts.size() == 3 and p.reroll_charges == 1, "reroll with charges redraws and spends one charge")
