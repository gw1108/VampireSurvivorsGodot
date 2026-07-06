## Pins Antonio Belpaese's whip-start and his signature Might ramp — behaviours a playtest
## measurement pass surfaced as worth keeping honest. In that pass the Whip solo-cleared a Lv1
## zombie field (2.4 kills/s) while the Magic Wand's per-hit damage stat was far weaker, and the
## Might ramp only began to "read" at Lv20 (10.8 dmg one-shot a 10hp mummy that Lv1/Lv10's
## 9.0/9.9 could not). These tests guard against silent regressions: someone clearing whip_level
## at character init, or breaking the +10%/10-levels (capped +50%) Might formula.
##
## Isolated like king_bible_test: the run is a bare state bag (never entered into the tree, so
## _build_world / the spawner / the Magic Wand never run) except a whip node parented to the
## suite so its get_tree()/"enemies" group query resolves. Runs under the project so AgentBridge
## (the whip's swing sfx event) exists.
extends GdUnitTestSuite

func _state_run(char_level: int, whip_level: int) -> VSRun:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	run.level = char_level
	run.whip_level = whip_level
	return run

# Antonio begins the run already wielding the Whip at Lv 1 (player null here -> the +20 HP bump
# is skipped, but the whip-ownership flags, which is what we assert, still land).
func test_antonio_starts_with_the_whip() -> void:
	var run := VSRun.new()
	auto_free(run)
	run._init_character()
	assert_int(run.whip_level).is_equal(1)
	assert_int(run.upgrade_levels.get("whip", 0)).is_equal(1)

# +10% Damage every 10 character levels, capped at +50% (Lv 50+), per the offline wiki table.
func test_might_ramp_matches_wiki() -> void:
	var run := _state_run(1, 1)
	run.level = 1;  assert_float(run.might_mult()).is_equal_approx(1.0, 0.001)
	run.level = 9;  assert_float(run.might_mult()).is_equal_approx(1.0, 0.001)
	run.level = 10; assert_float(run.might_mult()).is_equal_approx(1.1, 0.001)
	run.level = 20; assert_float(run.might_mult()).is_equal_approx(1.2, 0.001)
	run.level = 50; assert_float(run.might_mult()).is_equal_approx(1.5, 0.001)
	run.level = 90; assert_float(run.might_mult()).is_equal_approx(1.5, 0.001)   # stays capped

func _park_zombie(run: VSRun, at: Vector2) -> VSEnemy:
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.ZOMBIE
	e.run = run
	e.target = null                     # no target -> never drifts out of the wedge
	add_child(e)                        # _ready applies stats + joins "enemies"
	auto_free(e)
	e.position = at
	return e

# A Lv1 lash out-damages the Magic Wand's per-hit damage stat by a wide margin, so Antonio
# genuinely plays as a whip character from the first second — the Magic Wand (which he doesn't
# even start with; see test_antonio_does_not_start_with_the_magic_wand below) is a poke by comparison.
func test_whip_lash_outclears_the_base_projectile() -> void:
	var run := _state_run(1, 1)
	var e := _park_zombie(run, Vector2(100, 0))   # inside range (140) and the +x facing wedge
	var whip := VSWhip.new()
	whip.run = run
	add_child(whip)
	auto_free(whip)
	# Lash damage now rolls +/-50% base variance per swing (VSRun.damage_variance), so sum many
	# swings to average out the noise, then confirm the whip's per-lash output dwarfs the wand's.
	var total := 0.0
	for i in 200:
		e.health = 1000.0
		whip._swing(1)
		total += 1000.0 - e.health
	var avg_lash := total / 200.0
	assert_float(avg_lash).is_greater(run.weapon_damage)   # ~10 dmg/lash vs the wand's weapon_damage (2)
	assert_float(run.weapon_damage).is_less(6.0)

# Antonio's only starting weapon is the Whip (see test_antonio_starts_with_the_whip above) — the
# Magic Wand (VSWeapon) must stay silent/inert until a "Multishot" pick grants it, or he'd fire
# daggers from frame one despite owning no such weapon.
func test_antonio_does_not_start_with_the_magic_wand() -> void:
	var run := VSRun.new()
	auto_free(run)
	run._init_character()
	assert_int(run.weapon_count).is_equal(0)
	assert_int(run.upgrade_levels.get("multishot", 0)).is_equal(0)
