## Regression test for the "Power/Haste level-up picks only affect the Magic Wand" bug: the
## Power ("damage") and Haste ("firerate") level-up cards mutate run.weapon_damage /
## run.weapon_fire_interval, but historically only VSWeapon (the Magic Wand) ever read those
## vars — a whip/garlic/etc-only build got zero benefit from cards whose text ("+1 weapon
## damage", "+15% fire rate") reads as build-wide. Pins run.power_mult()/haste_mult() (the
## ratios every other weapon now multiplies in alongside might_mult()) and confirms a non-wand
## weapon (the Whip) actually hits harder once Power is picked.
extends GdUnitTestSuite

func test_power_and_haste_multipliers_start_neutral() -> void:
	var run := VSRun.new()
	auto_free(run)
	assert_float(run.power_mult()).is_equal_approx(1.0, 0.001)
	assert_float(run.haste_mult()).is_equal_approx(1.0, 0.001)

func test_power_pick_raises_power_mult_and_haste_pick_lowers_haste_mult() -> void:
	var run := VSRun.new()
	auto_free(run)
	run._apply_upgrade("damage")
	assert_float(run.power_mult()).is_equal_approx(1.2, 0.001)   # 1.0 + POWER_MULT_PER_PICK (0.2) * 1 pick
	run._apply_upgrade("firerate")
	assert_float(run.haste_mult()).is_equal_approx(0.8333, 0.001)   # 1 / (1.0 + HASTE_MULT_PER_PICK (0.2) * 1 pick)

func test_power_pick_boosts_a_non_wand_weapons_damage() -> void:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	run.whip_level = 1
	var whip := VSWhip.new()
	whip.run = run
	add_child(whip)
	auto_free(whip)
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.ZOMBIE
	e.run = run
	e.target = null
	add_child(e)
	auto_free(e)
	e.position = Vector2(100, 0)   # inside whip range (140) and the +x facing wedge

	e.health = 1000.0
	whip._swing(1)
	var dmg_no_power := 1000.0 - e.health

	e.health = 1000.0
	run._apply_upgrade("damage")   # a Power pick — should now ALSO boost the whip, not just the wand
	whip._swing(1)
	var dmg_with_power := 1000.0 - e.health

	assert_float(dmg_with_power).is_greater(dmg_no_power)
