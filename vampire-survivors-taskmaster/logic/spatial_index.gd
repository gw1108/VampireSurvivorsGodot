class_name SpatialIndex extends RefCounted

## Pure broadphase over the enemy pool. `rebuild` bins every live enemy into the
## SpatialGrid once per tick; `query_circle` returns the alive enemy indices
## whose centers lie within a radius of a point, testing only the cells the query
## circle overlaps. No scene dependency. Replaces running 500+ Area2D monitors.

## Clear and repopulate `grid` from the live enemies in `enemies`.
static func rebuild(grid: SpatialGrid, enemies: EnemyPool) -> void:
	grid.clear()
	for i in EnemyPool.CAPACITY:
		if not enemies.alive[i]:
			continue
		var key := grid.get_cell_key(enemies.pos[i])
		if not grid.cells.has(key):
			grid.cells[key] = PackedInt32Array()
		grid.cells[key].push_back(i)

## Return the slot indices of alive enemies within `radius` of `center`. Walks
## only the cells the bounding box of the query circle touches, then applies an
## exact distance-squared test so the result is a true circle (no false hits).
## `radius`-boundary enemies (distance == radius) are included.
static func query_circle(grid: SpatialGrid, enemies: EnemyPool, center: Vector2, radius: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	var radius_sq := radius * radius
	var min_cell := grid.get_cell_key(center - Vector2(radius, radius))
	var max_cell := grid.get_cell_key(center + Vector2(radius, radius))

	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			var key := Vector2i(cx, cy)
			if not grid.cells.has(key):
				continue
			for idx in grid.cells[key]:
				if not enemies.alive[idx]:
					continue
				if center.distance_squared_to(enemies.pos[idx]) <= radius_sq:
					result.push_back(idx)
	return result
