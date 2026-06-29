extends SceneTree

## Headless test runner for the Task 3 SpatialGrid + SpatialIndex.
##   godot --headless --path . --script res://test/spatial_index_test.gd
## Exit code == number of failed checks (0 == all passed).

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== spatial_index_test ==")
	_test_cell_key()
	_test_rebuild()
	_test_rebuild_clears_stale()
	_test_query_circle()
	_test_query_boundary_and_filter()
	_test_query_dead_excluded()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _spawn_at(pool: EnemyPool, positions: Array) -> void:
	for pos in positions:
		pool.spawn(&"zombie", pos, { hp = 1.0 })

func _test_cell_key() -> void:
	var g := SpatialGrid.new()  # cell_size 64
	_check(g.get_cell_key(Vector2(0, 0)) == Vector2i(0, 0), "key (0,0) -> (0,0)")
	_check(g.get_cell_key(Vector2(63.9, 63.9)) == Vector2i(0, 0), "key (63.9,63.9) -> (0,0)")
	_check(g.get_cell_key(Vector2(64, 64)) == Vector2i(1, 1), "key (64,64) -> (1,1)")
	# negative coordinates use floor, so they don't lump with the positive side
	_check(g.get_cell_key(Vector2(-1, -1)) == Vector2i(-1, -1), "key (-1,-1) -> (-1,-1)")
	_check(g.get_cell_key(Vector2(-64, -64)) == Vector2i(-1, -1), "key (-64,-64) -> (-1,-1)")
	_check(g.get_cell_key(Vector2(-65, 0)) == Vector2i(-2, 0), "key (-65,0) -> (-2,0)")
	# custom cell size
	g.cell_size = 100.0
	_check(g.get_cell_key(Vector2(150, 50)) == Vector2i(1, 0), "cell_size 100: (150,50) -> (1,0)")

func _test_rebuild() -> void:
	var g := SpatialGrid.new()
	var p := EnemyPool.new()
	# e0,e1 share cell (0,0); e2 in (3,0); e3 in (-1,-1)
	_spawn_at(p, [Vector2(10, 10), Vector2(20, 20), Vector2(200, 10), Vector2(-10, -10)])
	SpatialIndex.rebuild(g, p)
	_check(g.cells.has(Vector2i(0, 0)), "cell (0,0) present")
	_check(g.cells[Vector2i(0, 0)].size() == 2, "cell (0,0) holds both co-located enemies")
	_check(0 in g.cells[Vector2i(0, 0)] and 1 in g.cells[Vector2i(0, 0)], "cell (0,0) holds indices 0 and 1")
	_check(g.cells.has(Vector2i(3, 0)) and g.cells[Vector2i(3, 0)][0] == 2, "cell (3,0) holds enemy 2")
	_check(g.cells.has(Vector2i(-1, -1)) and g.cells[Vector2i(-1, -1)][0] == 3, "cell (-1,-1) holds enemy 3")
	_check(g.cells.size() == 3, "exactly 3 occupied cells")

	# empty pool -> empty grid
	var g2 := SpatialGrid.new()
	SpatialIndex.rebuild(g2, EnemyPool.new())
	_check(g2.cells.is_empty(), "empty pool yields empty grid")

func _test_rebuild_clears_stale() -> void:
	var g := SpatialGrid.new()
	var p := EnemyPool.new()
	var idx := p.spawn(&"zombie", Vector2(10, 10), { hp = 1.0 })
	SpatialIndex.rebuild(g, p)
	_check(g.cells.has(Vector2i(0, 0)), "enemy initially in cell (0,0)")
	# move the enemy and rebuild; old cell must be gone
	p.pos[idx] = Vector2(500, 500)
	SpatialIndex.rebuild(g, p)
	_check(not g.cells.has(Vector2i(0, 0)), "stale cell removed after rebuild")
	_check(g.cells.has(Vector2i(7, 7)), "enemy now in cell (7,7)")  # 500/64 = 7.8 -> 7

func _test_query_circle() -> void:
	var g := SpatialGrid.new()
	var p := EnemyPool.new()
	# 0:(10,10) 1:(20,20) near; 2:(200,10) far; 3:(-100,-100) far
	_spawn_at(p, [Vector2(10, 10), Vector2(20, 20), Vector2(200, 10), Vector2(-100, -100)])
	SpatialIndex.rebuild(g, p)
	var hits := SpatialIndex.query_circle(g, p, Vector2(15, 15), 20.0)
	_check(hits.size() == 2, "query returns the 2 near enemies")
	_check(0 in hits and 1 in hits, "query returns indices 0 and 1")
	_check(not (2 in hits) and not (3 in hits), "far enemies excluded")

	# negative-coordinate query
	var hits_neg := SpatialIndex.query_circle(g, p, Vector2(-100, -100), 10.0)
	_check(hits_neg.size() == 1 and hits_neg[0] == 3, "negative-coord query finds enemy 3")

	# nothing in range
	var none := SpatialIndex.query_circle(g, p, Vector2(1000, 1000), 30.0)
	_check(none.is_empty(), "query with nothing in range returns empty")

func _test_query_boundary_and_filter() -> void:
	var g := SpatialGrid.new()
	var p := EnemyPool.new()
	# enemy exactly at radius distance, and one far but in a checked cell
	_spawn_at(p, [Vector2(10, 0), Vector2(30, 30)])
	SpatialIndex.rebuild(g, p)
	# enemy 0 at distance exactly 10 from origin -> included (<= radius)
	var on_edge := SpatialIndex.query_circle(g, p, Vector2(0, 0), 10.0)
	_check(0 in on_edge, "enemy exactly at radius is included")
	# enemy 1 is in cell (0,0) too, but dist 42.4 > 20 -> excluded by distance test
	var filtered := SpatialIndex.query_circle(g, p, Vector2(0, 0), 20.0)
	_check(not (1 in filtered), "same-cell-but-out-of-radius enemy excluded by distance filter")

func _test_query_dead_excluded() -> void:
	var g := SpatialGrid.new()
	var p := EnemyPool.new()
	var a := p.spawn(&"zombie", Vector2(5, 5), { hp = 1.0 })
	var b := p.spawn(&"zombie", Vector2(8, 8), { hp = 1.0 })
	SpatialIndex.rebuild(g, p)
	# despawn b WITHOUT rebuilding -> grid still references it, query must skip it
	p.despawn(b)
	var hits := SpatialIndex.query_circle(g, p, Vector2(6, 6), 50.0)
	_check(a in hits, "alive enemy still returned")
	_check(not (b in hits), "dead enemy excluded even with stale grid entry")
