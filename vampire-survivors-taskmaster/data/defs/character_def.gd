class_name CharacterDef extends Resource

## Immutable definition of a playable character (Antonio). PlayerState is built
## from this at run start: base StatBlock values + the starting weapon. Never
## mutated at runtime.
##   base_stats:      stat_name -> starting StatBlock value (overrides defaults).
##   growth_bonuses:  stat_name -> additive bonus applied once every
##                    `growth_interval` levels (e.g. Antonio gains +0.10 Might
##                    every 10 levels), accumulating up to `growth_cap`.
##   growth_interval: levels between each growth_bonus application (1 = per level).
##   growth_cap:      stat_name -> max total additive accrued from growth_bonuses.

@export var id: String
@export var name: String
@export var starting_weapon_id: String
@export var base_stats: Dictionary = {}  # stat_name -> starting value
@export var growth_bonuses: Dictionary = {}  # stat_name -> additive per growth step
@export var growth_interval: int = 1  # levels between growth applications
@export var growth_cap: Dictionary = {}  # stat_name -> max total growth additive
@export var max_health: float = 100.0
@export var move_speed: float = 1.0
