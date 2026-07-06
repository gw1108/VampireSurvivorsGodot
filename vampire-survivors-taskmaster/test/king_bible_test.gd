## Pins VSKingBible in isolation: with bible_level > 0 the orbiting books strike an enemy
## parked on the orbit ring (it loses HP), and while bible_level == 0 the weapon is inert
## (no books, no damage). The run is a bare state bag (never added to the tree, so its _ready
## doesn't build the world's other weapons) — this isolates the Bible from the auto-projectile
## so the assertions only reflect the orbit. Runs under the project, so the AgentBridge
## autoload the strike emits on exists.
extends GdUnitTestSuite

# A VSRun used purely as a state holder for bible_level/phase — NOT added to the tree, so
# _build_world (spawner, projectile weapon, etc.) never runs and can't touch the enemy.
func _state_run(lvl: int) -> VSRun:
	var run := VSRun.new()
	auto_free(run)
	run.phase = "playing"
	run.bible_level = lvl
	return run

# Park a lone stationary enemy on the Bible's orbit radius so an orbiting book must sweep it.
# The test suite is a plain Node (no transform), so the enemy's local pos is its world pos and
# the Bible mounted on the suite orbits the origin.
func _park_enemy_on_ring(run: VSRun, lvl: int) -> VSEnemy:
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.BAT
	e.run = run
	e.target = null                     # no target -> never chases/drifts
	add_child(e)                        # _ready applies stats + joins "enemies"
	auto_free(e)
	var r := VSKingBible.BASE_ORBIT_RADIUS * float(VSKingBible._row(lvl)["area_mult"]) * run.area_mult
	e.position = Vector2(r, 0.0)
	return e

func _run_bible(run: VSRun, frames: int) -> VSKingBible:
	var bible := VSKingBible.new()
	bible.run = run
	add_child(bible)                    # in-tree so get_tree()/enemies group resolve
	auto_free(bible)
	# Drive the weapon deterministically (synchronous loop = no interleaved engine frames).
	for i in frames:
		bible._process(1.0 / 60.0)
	return bible

func test_orbiting_books_strike_enemy_on_ring() -> void:
	var run := _state_run(3)
	var e := _park_enemy_on_ring(run, 3)
	var hp0: float = e.health
	_run_bible(run, 120)                # ~2s: a book sweeps the parked enemy and strikes it
	assert_float(e.health).is_less(hp0)

func test_inert_at_level_zero() -> void:
	var run := _state_run(0)
	var e := _park_enemy_on_ring(run, 1)
	var hp0: float = e.health
	var bible := _run_bible(run, 120)
	assert_float(e.health).is_equal(hp0)   # no Bible picked -> no orbit damage
	assert_int(bible._built_count).is_equal(0)
