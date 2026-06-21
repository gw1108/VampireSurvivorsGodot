class_name WeaponDef extends Resource

## Immutable definition of a weapon (the static data, authored once from the
## wiki). A runtime WeaponInstance holds a reference to one of these plus its
## mutable level/cooldown. Never mutated at runtime.

@export var id: String
@export var name: String
@export var description: String
@export var base_damage: float
@export var cooldown: float
@export var pierce: int = 1  # -1 = infinite (area/sweep weapons hit all in the area)
@export var projectile_speed: float = 200.0
@export var area: float = 1.0
@export var amount: int = 1
@export var duration: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_mult: float = 1.5
@export var knockback: float = 0.0
@export var levels: Array[Dictionary] = []  # per-level upgrade deltas
