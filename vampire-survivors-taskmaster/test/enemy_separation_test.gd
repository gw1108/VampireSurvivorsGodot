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
