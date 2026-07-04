## Pins VSEnemy._separation(): enemies inside SEPARATION_RADIUS repel away from a neighbour
## (so the horde spreads into a surrounding mass instead of collapsing onto one point), and
## neighbours beyond the radius exert no pull. Deterministic — no spawner/weapon noise.
extends GdUnitTestSuite

func _make_enemy(at: Vector2) -> VSEnemy:
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.BAT
	e.position = at
	# _ready tolerates a null run (t defaults to 0 for the difficulty ramp).
	add_child(e)   # triggers _ready -> joins the "enemies" group
	auto_free(e)   # freed after each test so cases don't see each other's enemies
	return e

func test_close_neighbour_pushes_away() -> void:
	var a := _make_enemy(Vector2.ZERO)
	_make_enemy(Vector2(10, 0))            # 10px < SEPARATION_RADIUS (26)
	var push: Vector2 = a._separation()
	# a sits left of b, so it should be shoved further left (negative x).
	assert_float(push.length()).is_greater(0.0)
	assert_float(push.x).is_less(0.0)

func test_far_neighbour_no_push() -> void:
	var a := _make_enemy(Vector2.ZERO)
	_make_enemy(Vector2(80, 0))            # 80px > SEPARATION_RADIUS
	var push: Vector2 = a._separation()
	assert_float(push.length()).is_less(0.001)

## Brute-force reference: the old O(n²) scan the grid replaced.
func _brute_separation(e: VSEnemy, all: Array) -> Vector2:
	var push := Vector2.ZERO
	for other in all:
		if other == e:
			continue
		var away: Vector2 = e.position - other.position
		var dist := away.length()
		if dist > 0.001 and dist < VSEnemy.SEPARATION_RADIUS:
			push += away / dist * (1.0 - dist / VSEnemy.SEPARATION_RADIUS)
	return push

## The spatial grid must return EXACTLY what the brute-force scan would, including for
## neighbours that straddle cell boundaries (the real failure mode of a uniform grid: a
## repeller in an adjacent cell must still be found). Build a dense cloud spanning several
## cells and cross-check every enemy's grid result against the brute-force reference.
func test_grid_matches_bruteforce_across_cells() -> void:
	var all: Array = []
	# A 6×6 lattice at 18px spacing (< SEPARATION_RADIUS 26) so neighbours in adjacent cells
	# genuinely repel and many pairs cross cell edges; offset off-origin to exercise negative cells.
	for gx in range(6):
		for gy in range(6):
			all.append(_make_enemy(Vector2(gx * 18 - 40, gy * 18 - 40)))
	for e in all:
		var grid_push: Vector2 = e._separation()
		var brute_push: Vector2 = _brute_separation(e, all)
		assert_float(grid_push.distance_to(brute_push)).is_less(0.001)
