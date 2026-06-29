class_name PickupPool extends RefCounted

## Data-oriented store of XP gems and all collectibles (gold, chicken, Rosary,
## Orologion, Vacuum, Nduja, Rerollo, Treasure Chest). Parallel fixed-capacity
## arrays + integer free-list; pure data.
##
## `gem_count` tracks how many GEM-kind pickups are on the ground so
## CollisionSystem can enforce the 400-gem merge cap (the pool stays agnostic of
## the exact cap value).

const CAPACITY := 512

enum Kind { GEM = 0, GOLD = 1, CHICKEN = 2, ROSARY = 3, OROLOGION = 4, VACUUM = 5, NDUJA = 6, REROLLO = 7, CHEST = 8 }
enum GemTier { BLUE = 0, GREEN = 1, RED = 2 }

var pos: PackedVector2Array
var kind: PackedInt32Array       # see enum Kind
var value: PackedFloat32Array    # gem XP, gold amount, or chest tier seed
var gem_tier: PackedInt32Array   # see enum GemTier (only meaningful for GEM)
var magnetized: Array[bool]
var alive: Array[bool]
var free_list: PackedInt32Array
var active_count: int = 0
var gem_count: int = 0           # live GEM-kind pickups (for the 400-gem cap)

func _init() -> void:
	_preallocate(CAPACITY)

func _preallocate(n: int) -> void:
	pos.resize(n)
	kind.resize(n)
	value.resize(n)
	gem_tier.resize(n)
	magnetized.resize(n)
	alive.resize(n)
	_rebuild_free_list(n)

func _rebuild_free_list(n: int) -> void:
	free_list.resize(n)
	for i in n:
		free_list[i] = n - 1 - i
		alive[i] = false
		magnetized[i] = false
	active_count = 0
	gem_count = 0

func is_full() -> bool:
	return free_list.is_empty()

## Claim a slot for a pickup. `tier` only matters when `pickup_kind == Kind.GEM`.
## Returns slot index or -1 if full.
func spawn(pickup_kind: int, position: Vector2, pickup_value: float, tier: int = GemTier.BLUE) -> int:
	if free_list.is_empty():
		return -1
	var idx := free_list[free_list.size() - 1]
	free_list.resize(free_list.size() - 1)
	pos[idx] = position
	kind[idx] = pickup_kind
	value[idx] = pickup_value
	gem_tier[idx] = tier
	magnetized[idx] = false
	alive[idx] = true
	active_count += 1
	if pickup_kind == Kind.GEM:
		gem_count += 1
	return idx

func despawn(idx: int) -> void:
	if not alive[idx]:
		return
	if kind[idx] == Kind.GEM:
		gem_count -= 1
	alive[idx] = false
	free_list.push_back(idx)
	active_count -= 1

func clear_all() -> void:
	_rebuild_free_list(CAPACITY)
