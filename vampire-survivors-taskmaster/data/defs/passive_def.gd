class_name PassiveDef extends Resource

## Immutable definition of a passive item. A runtime PassiveInstance references
## one of these plus its mutable level. `stat_bonuses` maps a StatBlock field
## name to a per-level Array of values (index = level-1). Never mutated at runtime.

@export var id: String
@export var name: String
@export var description: String
@export var max_level: int = 5
@export var stat_bonuses: Dictionary = {}  # stat_name -> Array of per-level values
