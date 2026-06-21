class_name StageDef extends Resource

## Immutable definition of a stage (Mad Forest). Holds the per-minute wave
## script, boss/event schedule, brazier spawn points, alive caps, and the
## stage-wide stat modifiers. Read by SpawnDirector and StatSystem. Never
## mutated at runtime. Dictionary entry shapes (authored in the .tres):
##   waves:  {minute:int, enemy_ids:Array, min_alive:int, interval:float}
##   bosses: {minute:int, enemy_id:String, count:int}
##   events: {minute:int, kind:String, ...}

@export var id: String
@export var name: String
@export var duration: float = 1800.0  # seconds (30 minutes)
@export var stat_modifiers: Dictionary = {}  # stat_name -> multiplier (stage-wide)
@export var waves: Array[Dictionary] = []
@export var bosses: Array[Dictionary] = []
@export var events: Array[Dictionary] = []
@export var brazier_positions: Array[Vector2] = []
@export var starting_spawn_count: int = 10  # spawned on the first frame
@export var max_alive_soft: int = 300  # periodic-spawn halt
@export var max_alive_hard: int = 500  # absolute cap
@export var reaper_minute: int = 30  # The Reaper arrives at 30:00
