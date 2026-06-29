extends SceneTree

## Headless test runner for the GameDatabase autoload (Task 4).
##   godot --headless --path . --script res://test/game_database_test.gd
## Exit code == number of failed checks (0 == all passed).
##
## Uses load() + static/const access so it does not depend on autoload init order.

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== game_database_test ==")
	_test_weapons()
	_test_passives()
	_test_enemies()
	_test_waves()
	_test_xp_curve()
	_test_gem_tiers()
	_test_braziers_and_pickups()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_weapons() -> void:
	var expected := [&"whip", &"knife", &"magic_wand", &"runetracer", &"garlic", &"king_bible", &"fire_wand", &"lightning_ring"]
	_check(GDB.WEAPONS.size() == 8, "8 weapons defined")
	for id in expected:
		_check(GDB.WEAPONS.has(id), "weapon present: %s" % id)
		var w: Dictionary = GDB.weapon(id)
		_check(w.has("base_dmg") and w.has("cooldown") and w.has("amount"), "%s has base stats" % id)
		_check((w["levels"] as Array).size() == 8, "%s has 8 level entries" % id)
		_check((w["levels"] as Array)[0].is_empty(), "%s level[0] is empty base" % id)
	_check(GDB.weapon(&"whip")["base_dmg"] == 10.0, "whip base_dmg 10")
	_check(GDB.weapon(&"whip")["cooldown"] == 1.35, "whip cooldown 1.35")
	_check(GDB.weapon(&"knife")["base_dmg"] == 6.5, "knife base_dmg 6.5")
	_check(GDB.weapon(&"fire_wand")["amount"] == 3, "fire_wand amount 3")
	_check(GDB.weapon(&"fire_wand")["speed"] == 0.75, "fire_wand base speed 0.75")
	# resolve whip to level 8: base 10 + 5*5 (L3,L4,L5,L6,L7,L8 each +5 except... )
	var whip: Dictionary = GDB.weapon(&"whip")
	var dmg: float = whip["base_dmg"]
	var amount: int = whip["amount"]
	for i in range(1, 8):  # apply L2..L8 deltas
		var d: Dictionary = (whip["levels"] as Array)[i]
		dmg += d.get("dmg", 0.0)
		amount += int(d.get("amount", 0))
	_check(dmg == 40.0, "whip L8 damage resolves to 40 (10 + 6x5)")
	_check(amount == 2, "whip L8 amount resolves to 2")
	_check(GDB.weapon(&"nonexistent").is_empty(), "unknown weapon returns empty dict")

func _test_passives() -> void:
	var expected := [&"spinach", &"armor", &"hollow_heart", &"empty_tome", &"candelabrador", &"bracer", &"wings", &"duplicator"]
	_check(GDB.PASSIVES.size() == 8, "8 passives defined")
	for id in expected:
		_check(GDB.PASSIVES.has(id), "passive present: %s" % id)
	_check(GDB.passive(&"spinach")["stat"] == "might", "spinach -> might")
	_check(GDB.passive(&"spinach")["per_level"] == 0.10, "spinach +10%/lvl")
	_check(GDB.passive(&"spinach")["max_level"] == 5, "spinach max 5")
	_check(GDB.passive(&"hollow_heart")["stacking"] == "multiplicative", "hollow_heart multiplicative")
	_check(GDB.passive(&"empty_tome")["per_level"] == -0.08, "empty_tome -8%/lvl")
	_check(GDB.passive(&"duplicator")["max_level"] == 2, "duplicator max 2")
	_check(GDB.passive(&"armor")["per_level"] == 1.0, "armor +1/lvl")

func _test_enemies() -> void:
	_check(GDB.enemy(&"zombie")["hp"] == 10.0, "zombie hp 10")
	_check(GDB.enemy(&"zombie")["power"] == 10.0, "zombie power 10")
	_check(GDB.enemy(&"zombie")["xp"] == 1.0, "zombie xp 1")
	_check(GDB.enemy(&"skeleton")["hp"] == 15.0, "skeleton hp 15")
	_check(GDB.enemy(&"ghost")["move_speed"] == 200.0, "ghost move_speed 200")
	_check(GDB.enemy(&"big_mummy")["hp"] == 500.0, "big_mummy hp 500")
	_check(GDB.enemy(&"reaper")["power"] == 65535.0, "reaper power 65535")
	_check(GDB.enemy(&"reaper")["immune"] == true, "reaper immune")
	_check(GDB.enemy(&"reaper")["knockback_resist"] < 0.0, "reaper negative knockback")
	_check(GDB.enemy(&"glowing_bat").get("is_boss", false) == true, "glowing_bat is boss")
	_check(GDB.enemy(&"ghost_swarm")["ai"] == "fixed", "ghost_swarm fixed AI")
	_check(GDB.enemy(&"zombie").get("is_boss", false) == false, "zombie not a boss")
	_check(GDB.enemy(&"nope").is_empty(), "unknown enemy returns empty dict")

func _test_waves() -> void:
	_check(GDB.MAD_FOREST_WAVES.size() == 31, "31 wave entries (minutes 0..30)")
	_check(GDB.wave(0)["count"] == 15, "M0 count 15")
	_check(GDB.wave(0)["interval"] == 1.0, "M0 interval 1.0")
	_check(GDB.wave(1)["boss"] == &"glowing_bat", "M1 boss glowing_bat")
	_check(GDB.wave(30)["boss"] == &"reaper", "M30 boss reaper")
	_check(GDB.wave(30).get("clear_field", false) == true, "M30 clears field")
	# every enemy/boss id referenced in the table must exist in ENEMIES
	var ok := true
	for w in GDB.MAD_FOREST_WAVES:
		for e in (w["enemies"] as Array):
			if not GDB.ENEMIES.has(e):
				ok = false
				printerr("    wave references unknown enemy: ", e)
		var b: StringName = w["boss"]
		if b != &"" and not GDB.ENEMIES.has(b):
			ok = false
			printerr("    wave references unknown boss: ", b)
	_check(ok, "all wave enemy/boss ids exist in ENEMIES")
	# clamp behaviour past the table
	_check(GDB.wave(45)["boss"] == &"reaper", "minute past 30 clamps to Reaper wave")
	_check(GDB.wave(-3)["count"] == 15, "negative minute clamps to M0")

func _test_xp_curve() -> void:
	_check(GDB.xp_to_next(1) == 5.0, "xp L1->L2 = 5")
	_check(GDB.xp_to_next(2) == 15.0, "xp L2->L3 = 15")
	_check(GDB.xp_to_next(19) == 185.0, "xp L19->L20 = 185")
	_check(GDB.xp_to_next(20) == 795.0, "xp L20->L21 = 195 + 600 lump")
	_check(GDB.xp_to_next(21) == 208.0, "xp L21->L22 = 208")
	_check(GDB.xp_to_next(40) == 2855.0, "xp L40->L41 = 455 + 2400 lump")
	_check(GDB.xp_to_next(41) == 471.0, "xp L41->L42 = 471")
	# cumulative checks vs the wiki's total-XP table
	var to_l10 := 0.0
	for l in range(1, 10):
		to_l10 += GDB.xp_to_next(l)
	_check(to_l10 == 405.0, "cumulative XP to reach L10 == 405")
	var to_l20 := 0.0
	for l in range(1, 20):
		to_l20 += GDB.xp_to_next(l)
	_check(to_l20 == 1805.0, "cumulative XP to reach L20 == 1805")

func _test_gem_tiers() -> void:
	_check(GDB.gem_tier(1.0) == &"blue", "1 XP -> blue")
	_check(GDB.gem_tier(2.0) == &"blue", "2 XP -> blue (boundary)")
	_check(GDB.gem_tier(5.0) == &"green", "5 XP -> green")
	_check(GDB.gem_tier(9.0) == &"green", "9 XP -> green (boundary)")
	_check(GDB.gem_tier(10.0) == &"red", "10 XP -> red")
	_check(GDB.GEM_GROUND_CAP == 400, "gem ground cap 400")

func _test_braziers_and_pickups() -> void:
	_check(GDB.CHICKEN_HEAL == 30.0, "chicken heals 30")
	_check(GDB.COIN_VALUES[&"coin_bag"] == 10, "coin_bag = 10")
	_check(GDB.COIN_VALUES[&"rich_coin_bag"] == 100, "rich_coin_bag = 100")
	_check(GDB.CHEST_BEGINNER_LUCK == [1, 1, 3, 1, 1, 5], "beginner-luck sequence 1-1-3-1-1-5")
	_check(GDB.ALIVE_CAP_PERIODIC == 300, "periodic alive cap 300")
	_check(GDB.ALIVE_CAP_HARD == 500, "hard alive cap 500")
	_check(GDB.BRAZIER_DROPS.size() >= 8, "brazier drop table populated")
	var total_weight := 0
	var has_chicken := false
	for d in GDB.BRAZIER_DROPS:
		total_weight += int(d["weight"])
		if d["pickup"] == &"chicken":
			has_chicken = true
	_check(total_weight > 0, "brazier drop weights sum positive")
	_check(has_chicken, "brazier drops include chicken")
