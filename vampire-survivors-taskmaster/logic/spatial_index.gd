class_name SpatialIndex extends RefCounted

## Uniform spatial-hash grid for overlap/nearest queries without physics nodes.
## Rebuilt each tick from the entity arrays. Enemies, then gems, then pickups are
## packed into parallel "combined" arrays (entity_positions/types/ids); bucket
## entries and query_radius results are *combined* indices into those arrays.
## Layout: enemies occupy combined indices [0, enemy_count), gems the next
## gem_count, pickups the next pickup_count. Use get_entity_type()/­
## get_entity_local_id() to map a combined index back to its source array.
##
## Note: cells use floori() (not the truncating int() in the original sketch) so
## bucketing is uniform across the origin — the world is boundless and the player
## freely visits negative coordinates.

enum Type { ENEMY, GEM, PICKUP }

const CELL_SIZE: float = 64.0

var buckets: Dictionary = {}  # Vector2i -> Array[int] (combined indices)
var entity_positions: PackedVector2Array = PackedVector2Array()
var entity_types: PackedInt32Array = PackedInt32Array()  # Type per combined index
var entity_ids: PackedInt32Array = PackedInt32Array()  # source-array index per entry
var enemy_count: int = 0
var gem_count: int = 0
var pickup_count: int = 0


## Rebuild the grid from the current entity arrays (each element exposes `.pos`).
static func rebuild(index: SpatialIndex, enemies: Array, gems: Array, pickups: Array) -> void:
	index.buckets.clear()
	index.entity_positions.clear()
	index.entity_types.clear()
	index.entity_ids.clear()
	index.enemy_count = enemies.size()
	index.gem_count = gems.size()
	index.pickup_count = pickups.size()
	for i in enemies.size():
		_add_entity(index, enemies[i].pos, Type.ENEMY, i)
	for i in gems.size():
		_add_entity(index, gems[i].pos, Type.GEM, i)
	for i in pickups.size():
		_add_entity(index, pickups[i].pos, Type.PICKUP, i)


static func _add_entity(index: SpatialIndex, pos: Vector2, type: int, local_id: int) -> void:
	var entry: int = index.entity_positions.size()
	index.entity_positions.append(pos)
	index.entity_types.append(type)
	index.entity_ids.append(local_id)
	var cell := _pos_to_cell(pos)
	if not index.buckets.has(cell):
		index.buckets[cell] = []
	index.buckets[cell].append(entry)


static func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))


## All entities whose position is within `r` of `center`, as combined indices.
static func query_radius(index: SpatialIndex, center: Vector2, r: float) -> PackedInt32Array:
	var results: PackedInt32Array = PackedInt32Array()
	var r2 := r * r
	var min_cell := _pos_to_cell(center - Vector2(r, r))
	var max_cell := _pos_to_cell(center + Vector2(r, r))
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if index.buckets.has(cell):
				for entry: int in index.buckets[cell]:
					if center.distance_squared_to(index.entity_positions[entry]) <= r2:
						results.append(entry)
	return results


## Nearest enemy's source-array index, or -1 if there are none. Linear over the
## enemy entries (O(enemies)); exact, and cheap at the design's bounded counts.
## A grid spiral is the documented optimization path if profiling demands it.
static func nearest_enemy(index: SpatialIndex, from: Vector2) -> int:
	var best_id := -1
	var best_d2 := INF
	for entry in index.enemy_count:
		var d2 := from.distance_squared_to(index.entity_positions[entry])
		if d2 < best_d2:
			best_d2 = d2
			best_id = index.entity_ids[entry]
	return best_id


## A uniformly-random enemy's source-array index, or -1 if there are none.
static func random_enemy(index: SpatialIndex, rng: RandomNumberGenerator) -> int:
	if index.enemy_count <= 0:
		return -1
	var entry := rng.randi_range(0, index.enemy_count - 1)
	return index.entity_ids[entry]


# --- accessors to interpret combined indices returned by query_radius ---

static func get_entity_type(index: SpatialIndex, entry: int) -> int:
	return index.entity_types[entry]


static func get_entity_local_id(index: SpatialIndex, entry: int) -> int:
	return index.entity_ids[entry]


static func get_entity_position(index: SpatialIndex, entry: int) -> Vector2:
	return index.entity_positions[entry]
