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
	var b := _make_enemy(Vector2(10, 0))   # 10px < combined radius: guaranteed overlap
	# Radii are CSV-driven (enemy_base_radius * enemy_scale), so derive the expectation from the
	# live bodies instead of pinning a scale: a is shoved left by HALF the overlap (b corrects
	# its own half).
	var expected := (a.radius + b.radius - 10.0) * 0.5
	var push: Vector2 = a._overlap_correction()
	assert_float(push.length()).is_equal_approx(expected, 0.001)
	assert_float(push.x).is_less(0.0)

func test_non_overlapping_neighbour_no_push() -> void:
	var a := _make_enemy(Vector2.ZERO)
	var b := _make_enemy(Vector2(500, 0))  # far beyond any combined radius: bodies don't touch
	assert_float(a.radius + b.radius).is_less(500.0)   # the premise, kept honest against retunes
	var push: Vector2 = a._overlap_correction()
	assert_float(push.length()).is_less(0.001)

## Brute-force reference: the naive O(n²) "push out of every overlapping enemy" scan the grid replaces.
func _brute_correction(e: VSEnemy, all: Array) -> Vector2:
	var correction := Vector2.ZERO
	for other in all:
		if other == e:
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
## Kept UNDER VSEnemy.MAX_OVERLAP_CHECKS bodies so the per-frame neighbour cap never bites here:
## below the cap the grid scan is exhaustive and must match brute force exactly. (The cap's
## intentional divergence past that density is pinned by test_cap_still_separates_dense_pack.)
func test_grid_matches_bruteforce_across_cells() -> void:
	var all: Array = []
	# A 4×4 lattice at 18px spacing (< combined radius 24) so neighbours in adjacent cells
	# genuinely overlap and many pairs cross cell edges; offset so it straddles the x=0/y=0 cell
	# boundaries (exercising negative cells). 16 bodies < MAX_OVERLAP_CHECKS keeps the scan exhaustive.
	for gx in range(4):
		for gy in range(4):
			all.append(_make_enemy(Vector2(gx * 18 - 27, gy * 18 - 27)))
	for e in all:
		var grid_push: Vector2 = e._overlap_correction()
		var brute_push: Vector2 = _brute_correction(e, all)
		assert_float(grid_push.distance_to(brute_push)).is_less(0.001)

## Density guard: when the horde collapses so tightly that one enemy's 3×3 block holds far more
## bodies than MAX_OVERLAP_CHECKS, the scan stops summing every neighbour (that reversion to O(n²)
## is the frame-crushing blowup this cap exists to prevent). It must still separate correctly:
## an enemy on the edge of the pack is shoved AWAY from the mass. Own-cell-first scan order means
## the capped subset is the nearest bodies, so the push keeps the right direction. Here `a` sits at
## the left edge of a dense cluster entirely to its right, so it must be pushed LEFT.
func test_cap_still_separates_dense_pack() -> void:
	var a := _make_enemy(Vector2.ZERO)
	# 40 bodies (>> MAX_OVERLAP_CHECKS = 16) packed just to the right of `a`, all within the combined
	# radius (24) so every one overlaps it. Deterministic grid, no randomness.
	for i in range(40):
		_make_enemy(Vector2(3.0 + (i % 8) * 2.0, (i / 8) * 2.0))
	var push: Vector2 = a._overlap_correction()
	assert_float(push.length()).is_greater(0.0)   # cap did not zero out separation
	assert_float(push.x).is_less(0.0)              # shoved left, away from the cluster to its right
