class_name EnemyPool extends RefCounted

## Data-oriented store of all live enemies, bosses, the Reaper, and braziers,
## as parallel fixed-capacity arrays with an integer free-list. Nothing is
## allocated mid-run: spawn() pops a free slot, despawn() pushes it back.
## Pure data — no scene dependency, no GameDatabase coupling (callers pass the
## enemy def dict in).

const CAPACITY := 512

enum Ai { HOMING = 0, FIXED = 1, WAVY = 2, NONE = 3 }
const _AI_MAP := { "homing": Ai.HOMING, "fixed": Ai.FIXED, "wavy": Ai.WAVY, "none": Ai.NONE }

var pos: PackedVector2Array
var vel: PackedVector2Array
var hp: PackedFloat32Array
var max_hp: PackedFloat32Array
var power: PackedFloat32Array
var move_speed: PackedFloat32Array
var knockback_resist: PackedFloat32Array
var xp_value: PackedFloat32Array
var type_id: Array[StringName]
var ai_kind: PackedInt32Array       # see enum Ai
var is_boss: Array[bool]
var knockback_timer: PackedFloat32Array
var hit_flash: PackedFloat32Array
var alive: Array[bool]
var free_list: PackedInt32Array
var active_count: int = 0

func _init() -> void:
	_preallocate(CAPACITY)

func _preallocate(n: int) -> void:
	pos.resize(n)
	vel.resize(n)
	hp.resize(n)
	max_hp.resize(n)
	power.resize(n)
	move_speed.resize(n)
	knockback_resist.resize(n)
	xp_value.resize(n)
	type_id.resize(n)
	ai_kind.resize(n)
	is_boss.resize(n)
	knockback_timer.resize(n)
	hit_flash.resize(n)
	alive.resize(n)
	_rebuild_free_list(n)

## Reset the free-list to hold every slot (descending so slots allocate in
## ascending index order) and mark all slots dead.
func _rebuild_free_list(n: int) -> void:
	free_list.resize(n)
	for i in n:
		free_list[i] = n - 1 - i
		alive[i] = false
	active_count = 0

func is_full() -> bool:
	return free_list.is_empty()

## Claim a slot for an enemy of `id`, initialized from `def` (a GameDatabase
## enemy dict: hp/power/move_speed/knockback_resist/xp/ai/is_boss). Returns the
## slot index, or -1 if the pool is full. NOTE: extends the spec stub's
## (position, def) signature with the type id, which the def dict does not carry.
func spawn(id: StringName, position: Vector2, def: Dictionary) -> int:
	if free_list.is_empty():
		return -1
	var idx := free_list[free_list.size() - 1]
	free_list.resize(free_list.size() - 1)
	pos[idx] = position
	vel[idx] = Vector2.ZERO
	hp[idx] = def.get("hp", 1.0)
	max_hp[idx] = hp[idx]
	power[idx] = def.get("power", 0.0)
	move_speed[idx] = def.get("move_speed", 0.0)
	knockback_resist[idx] = def.get("knockback_resist", 0.0)
	xp_value[idx] = def.get("xp", 0.0)
	type_id[idx] = id
	ai_kind[idx] = _AI_MAP.get(def.get("ai", "homing"), Ai.HOMING)
	is_boss[idx] = def.get("is_boss", false)
	knockback_timer[idx] = 0.0
	hit_flash[idx] = 0.0
	alive[idx] = true
	active_count += 1
	return idx

func despawn(idx: int) -> void:
	if not alive[idx]:
		return
	alive[idx] = false
	free_list.push_back(idx)
	active_count -= 1

## Free every slot at once (the Reaper-spawn field clear).
func clear_all() -> void:
	_rebuild_free_list(CAPACITY)
