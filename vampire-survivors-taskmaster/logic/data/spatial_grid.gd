class_name SpatialGrid extends RefCounted

## Uniform-grid spatial hash: a broadphase index of enemy slot-indices keyed by
## cell. Cleared and rebuilt from EnemyPool at the top of each tick by
## SpatialIndex; read by CollisionSystem queries. Pure data.

var cell_size: float = 64.0
var cells: Dictionary = {}  # Vector2i -> PackedInt32Array of enemy slot indices

func clear() -> void:
	cells.clear()

## Cell key for a world position. Uses floor (not truncation toward zero) so
## cells are uniform across negative coordinates on the endless field — e.g.
## x=-1 and x=-64 fall in different cells, not lumped with the positive side.
func get_cell_key(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))
