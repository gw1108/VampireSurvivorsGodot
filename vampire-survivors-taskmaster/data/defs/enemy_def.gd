class_name EnemyDef extends Resource

## Immutable definition of an enemy type. A runtime Enemy holds a reference to
## one of these plus its mutable hp/pos. Never mutated at runtime.

@export var id: String
@export var name: String
@export var hp: float
@export var power: float  # contact damage
@export var speed: float
@export var knockback_resist: float = 0.0  # 1.0 = fully immune (bosses)
@export var xp_value: float = 1.0
@export var is_boss: bool = false
