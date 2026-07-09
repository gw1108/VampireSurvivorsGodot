## Pins VSRosary: collecting a Rosary smites every on-screen enemy — clearing ordinary
## waves (a base-HP zombie is killed) while the enormous-HP finale Reaper merely takes a
## dent and survives. The run is a bare state bag (never added to the tree) so no world is
## built; enemies join the "enemies" group via their own _ready. Runs under the project so
## the AgentBridge autoload the smite emits on exists.
extends GdUnitTestSuite

func _state_run() -> VSRun:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	run.elapsed = 0.0                   # no HP ramp -> enemies sit at their base health
	return run

func _spawn_enemy(run: VSRun, t: int) -> VSEnemy:
	var e := VSEnemy.new()
	e.type = t
	e.run = run
	e.target = null                     # no target -> never chases/drifts
	add_child(e)                        # _ready applies stats + joins "enemies"
	auto_free(e)
	return e

func test_rosary_clears_rabble_but_reaper_survives() -> void:
	var run := _state_run()
	var zombie := _spawn_enemy(run, VSEnemy.Type.ZOMBIE)   # 6 base HP
	var reaper := _spawn_enemy(run, VSEnemy.Type.REAPER)   # 600 base HP
	assert_float(zombie.health).is_greater(0.0)
	assert_float(reaper.health).is_equal(600.0)

	var rosary := VSRosary.new()
	rosary.run = run
	add_child(rosary)                   # in-tree so get_parent()/flash spawn resolve
	auto_free(rosary)
	rosary._collect()                   # smite everything on screen

	# The smite (120 dmg) wipes the zombie outright but only dents the 600-HP Reaper.
	assert_float(zombie.health).is_less_equal(0.0)
	assert_float(reaper.health).is_equal(600.0 - VSRosary.SMITE_DAMAGE)
	assert_bool(reaper.health > 0.0).is_true()
