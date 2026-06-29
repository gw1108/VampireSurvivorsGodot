class_name ProjectilePool extends RefCounted

## Data-oriented store of all weapon-spawned shapes (bolts, knives, fireballs,
## runetracers) and persistent area emitters (Garlic aura, orbiting Bibles)
## modeled as projectiles with special behavior/lifetime. Parallel fixed-capacity
## arrays + integer free-list; pure data.
##
## `recent_hits[idx]` is a per-slot Dictionary (enemy slot index -> re-hit
## cooldown remaining) used by piercing and repeat-tick (aura) weapons so the
## same enemy is not damaged every frame.

const CAPACITY := 1024

enum Behavior { STRAIGHT = 0, HOMING = 1, BOUNCE = 2, ORBIT = 3, AURA = 4 }

var pos: PackedVector2Array
var vel: PackedVector2Array
var damage: PackedFloat32Array
var pierce_left: PackedInt32Array       # remaining hits; -1 == infinite (AoE)
var lifetime: PackedFloat32Array        # seconds remaining
var area_scale: PackedFloat32Array
var behavior: PackedInt32Array          # see enum Behavior
var owner_weapon: Array[StringName]
var type_id: Array[StringName]
var crit_chance: PackedFloat32Array
var crit_mult: PackedFloat32Array
var hit_cooldown: PackedFloat32Array    # repeat-tick interval for aura/orbit
var recent_hits: Array[Dictionary]      # per-slot pierce / re-hit tracking
var alive: Array[bool]
var free_list: PackedInt32Array
var active_count: int = 0

func _init() -> void:
	_preallocate(CAPACITY)

func _preallocate(n: int) -> void:
	pos.resize(n)
	vel.resize(n)
	damage.resize(n)
	pierce_left.resize(n)
	lifetime.resize(n)
	area_scale.resize(n)
	behavior.resize(n)
	owner_weapon.resize(n)
	type_id.resize(n)
	crit_chance.resize(n)
	crit_mult.resize(n)
	hit_cooldown.resize(n)
	recent_hits.resize(n)
	alive.resize(n)
	for i in n:
		# typed Array[Dictionary].resize fills with null; give each slot a dict
		recent_hits[i] = {}
	_rebuild_free_list(n)

func _rebuild_free_list(n: int) -> void:
	free_list.resize(n)
	for i in n:
		free_list[i] = n - 1 - i
		alive[i] = false
	active_count = 0

func is_full() -> bool:
	return free_list.is_empty()

## Claim a slot for a projectile. `params` keys (all optional, sensible
## defaults): damage, pierce, lifetime, area_scale, behavior, owner_weapon,
## type_id, crit_chance, crit_mult, hit_cooldown. Returns slot index or -1.
func spawn(position: Vector2, velocity: Vector2, params: Dictionary) -> int:
	if free_list.is_empty():
		return -1
	var idx := free_list[free_list.size() - 1]
	free_list.resize(free_list.size() - 1)
	pos[idx] = position
	vel[idx] = velocity
	damage[idx] = params.get("damage", 0.0)
	pierce_left[idx] = params.get("pierce", 1)
	lifetime[idx] = params.get("lifetime", 0.0)
	area_scale[idx] = params.get("area_scale", 1.0)
	behavior[idx] = params.get("behavior", Behavior.STRAIGHT)
	owner_weapon[idx] = params.get("owner_weapon", &"")
	type_id[idx] = params.get("type_id", &"")
	crit_chance[idx] = params.get("crit_chance", 0.0)
	crit_mult[idx] = params.get("crit_mult", 1.0)
	hit_cooldown[idx] = params.get("hit_cooldown", 0.0)
	recent_hits[idx].clear()
	alive[idx] = true
	active_count += 1
	return idx

func despawn(idx: int) -> void:
	if not alive[idx]:
		return
	alive[idx] = false
	recent_hits[idx].clear()
	free_list.push_back(idx)
	active_count -= 1

func clear_all() -> void:
	for i in CAPACITY:
		recent_hits[i].clear()
	_rebuild_free_list(CAPACITY)
