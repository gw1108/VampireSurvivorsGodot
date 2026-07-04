## Pins VSEnemy._overlap_correction(): enemies carry solid circular colliders, so an enemy that
## overlaps a neighbour is shoved directly away by HALF the overlap (the neighbour corrects its own
## half), while a neighbour whose body doesn't touch this one exerts no push. Deterministic — no
## spawner/weapon noise.
extends GdUnitTestSuite

func _make_enemy(at: Vector2) -> VSEnemy:
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.BAT
	e.position = at
	# _ready tolerates a null run (t defaults to 0 for the difficulty ramp).
	add_child(e)   # triggers _ready -> joins the "enemies" group
	auto_free(e)   # freed after each test so cases don't see each other's enemies
	return e

func test_overlapping_neighbour_pushes_away() -> void:
	var a := _make_enemy(Vector2.ZERO)
	_make_enemy(Vector2(10, 0))            # 10px < combined radius (2 * RADIUS = 24)
	var push: Vector2 = a._overlap_correction()
	# a sits left of b and they overlap, so it should be shoved further left (negative x) by
	# half the overlap: half of (24 - 10) = 7px.
	assert_float(push.length()).is_equal_approx(7.0, 0.001)
	assert_float(push.x).is_less(0.0)

func test_non_overlapping_neighbour_no_push() -> void:
	var a := _make_enemy(Vector2.ZERO)
	_make_enemy(Vector2(30, 0))            # 30px > combined radius (24): bodies don't touch
	var push: Vector2 = a._overlap_correction()
	assert_float(push.length()).is_less(0.001)

## Brute-force reference: the naive O(n²) "push out of every overlapping enemy" scan the grid replaces.
func _brute_correction(e: VSEnemy, all: Array) -> Vector2:
	var correction := Vector2.ZERO
	for other in all:
		if other == e or other.type == VSEnemy.Type.GHOST:
			continue
		var min_d: float = e.radius + other.radius
		var away: Vector2 = e.position - other.position
		var dist := away.length()
		if dist > 0.001 and dist < min_d:
			correction += away / dist * (min_d - dist) * 0.5
	return correction

## The spatial grid must return EXACTLY what the brute-force scan would, including for
## neighbours that straddle cell boundaries (the real failure mode of a uniform grid: a
## colliding body in an adjacent cell must still be found). Build a dense cloud spanning several
## cells and cross-check every enemy's grid result against the brute-force reference.
func test_grid_matches_bruteforce_across_cells() -> void:
	var all: Array = []
	# A 6×6 lattice at 18px spacing (< combined radius 24) so neighbours in adjacent cells
	# genuinely overlap and many pairs cross cell edges; offset off-origin to exercise negative cells.
	for gx in range(6):
		for gy in range(6):
			all.append(_make_enemy(Vector2(gx * 18 - 40, gy * 18 - 40)))
	for e in all:
		var grid_push: Vector2 = e._overlap_correction()
		var brute_push: Vector2 = _brute_correction(e, all)
		assert_float(grid_push.distance_to(brute_push)).is_less(0.001)
