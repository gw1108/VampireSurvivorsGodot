class_name Projectile extends RefCounted

## A moving weapon emission with finite pierce. Created by WeaponSystem;
## moved/resolved by CombatSystem; removed on pierce/lifetime/bounce exhaustion.
## Plain mutable data — no behavior. `source_weapon` is a WeaponInstance.

var source_weapon = null
var pos: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var accel: Vector2 = Vector2.ZERO  # per-sec velocity delta (Axe gravity arc); ZERO = straight line
var damage: float = 0.0
var crit_mult: float = 1.0
var crit_chance: float = 0.0
var pierce_left: int = 1
var lifetime: float = 2.0
var bounces_left: int = 0  # Runetracer
var hit_ids: PackedInt64Array = []  # already-hit enemies
var is_boomerang: bool = false
var is_returning: bool = false
var boomerang_range: float = 0.0  # outward distance before a boomerang (Cross) turns back
