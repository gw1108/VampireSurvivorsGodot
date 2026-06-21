extends GdUnitTestSuite

## Loads and validates the authored Antonio + Whip .tres data against wiki specs.

const ANTONIO_PATH := "res://data/character_antonio.tres"
const WHIP_PATH := "res://data/weapons/whip.tres"


func test_antonio_loads_as_character_def() -> void:
	var a = load(ANTONIO_PATH)
	assert_object(a).is_not_null()
	assert_bool(a is CharacterDef).is_true()


func test_antonio_stats() -> void:
	var a: CharacterDef = load(ANTONIO_PATH)
	assert_str(a.id).is_equal("antonio")
	assert_str(a.name).is_equal("Antonio Belpaese")
	assert_str(a.starting_weapon_id).is_equal("whip")
	assert_float(a.max_health).is_equal(120.0)  # +20 Max Health
	assert_float(a.base_stats["armor"]).is_equal(1.0)  # +1 Armor
	# +10% Might every 10 levels, capped at +50%.
	assert_float(a.growth_bonuses["might"]).is_equal(0.1)
	assert_int(a.growth_interval).is_equal(10)
	assert_float(a.growth_cap["might"]).is_equal(0.5)


func test_whip_loads_as_weapon_def() -> void:
	var w = load(WHIP_PATH)
	assert_object(w).is_not_null()
	assert_bool(w is WeaponDef).is_true()


func test_whip_base_stats() -> void:
	var w: WeaponDef = load(WHIP_PATH)
	assert_str(w.id).is_equal("whip")
	assert_str(w.name).is_equal("Whip")
	assert_float(w.base_damage).is_equal(10.0)
	assert_float(w.cooldown).is_equal(1.35)
	assert_int(w.pierce).is_equal(-1)  # infinite within sweep
	assert_int(w.amount).is_equal(1)
	assert_float(w.area).is_equal(1.0)
	assert_float(w.knockback).is_equal(1.0)


func test_whip_level_progression() -> void:
	var w: WeaponDef = load(WHIP_PATH)
	assert_int(w.levels.size()).is_equal(7)  # levels 2..8
	# Totals across all level-ups: +30 damage, +20% area, +1 amount.
	var dmg := 0.0
	var area := 0.0
	var amount := 0
	for entry: Dictionary in w.levels:
		dmg += entry.get("damage", 0.0)
		area += entry.get("area", 0.0)
		amount += entry.get("amount", 0)
	assert_float(dmg).is_equal(30.0)
	assert_float(area).is_equal_approx(0.2, 0.0001)
	assert_int(amount).is_equal(1)


func test_whip_max_damage_matches_wiki() -> void:
	# Base 10 + 30 from levels = 40 (wiki max-damage).
	var w: WeaponDef = load(WHIP_PATH)
	var max_dmg := w.base_damage
	for entry: Dictionary in w.levels:
		max_dmg += entry.get("damage", 0.0)
	assert_float(max_dmg).is_equal(40.0)
