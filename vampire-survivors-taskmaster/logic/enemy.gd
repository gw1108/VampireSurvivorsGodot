class_name Enemy extends RefCounted

## One alive monster. Created by SpawnDirector; mutated by Movement/Combat; on
## death Combat spawns a Gem (+ optional drop/chest) and swap-removes it.
## Plain mutable data — no behavior. `def` is an EnemyDef (data layer, later task).

var def = null  # EnemyDef resource
var pos: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var hp: float = 1.0
var knockback: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var freeze_timer: float = 0.0
var is_boss: bool = false
var fixed_direction: bool = false
var floaty: bool = false
var hit_cooldowns: Dictionary = {}  # source_id -> timer (per-hit-delay weapons)
