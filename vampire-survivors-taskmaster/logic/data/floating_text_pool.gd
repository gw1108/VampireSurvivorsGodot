class_name FloatingTextPool extends RefCounted

## Data-oriented store of damage numbers / pickup pops (juice). Parallel
## fixed-capacity arrays + integer free-list; pure data. Aged by a trivial step
## and freed at ttl 0. Optional — can be deferred without touching other systems.

const CAPACITY := 256

var pos: PackedVector2Array
var vel: PackedVector2Array
var text: PackedStringArray
var ttl: PackedFloat32Array       # seconds remaining
var alive: Array[bool]
var free_list: PackedInt32Array
var active_count: int = 0

func _init() -> void:
	_preallocate(CAPACITY)

func _preallocate(n: int) -> void:
	pos.resize(n)
	vel.resize(n)
	text.resize(n)
	ttl.resize(n)
	alive.resize(n)
	_rebuild_free_list(n)

func _rebuild_free_list(n: int) -> void:
	free_list.resize(n)
	for i in n:
		free_list[i] = n - 1 - i
		alive[i] = false
	active_count = 0

func is_full() -> bool:
	return free_list.is_empty()

## Claim a slot for a floating-text entry. Returns slot index or -1 if full.
func spawn(position: Vector2, velocity: Vector2, content: String, time_to_live: float) -> int:
	if free_list.is_empty():
		return -1
	var idx := free_list[free_list.size() - 1]
	free_list.resize(free_list.size() - 1)
	pos[idx] = position
	vel[idx] = velocity
	text[idx] = content
	ttl[idx] = time_to_live
	alive[idx] = true
	active_count += 1
	return idx

func despawn(idx: int) -> void:
	if not alive[idx]:
		return
	alive[idx] = false
	free_list.push_back(idx)
	active_count -= 1

func clear_all() -> void:
	_rebuild_free_list(CAPACITY)
