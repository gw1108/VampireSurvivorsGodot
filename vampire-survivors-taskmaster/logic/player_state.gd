class_name PlayerState extends RefCounted

## Antonio's runtime state. Created from the CharacterDef at run start and
## mutated by the Movement/Health/Progression/Pickup/Stat systems each tick.
## Plain mutable data — no behavior.

var pos: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT  # last nonzero move dir; default right
var velocity: Vector2 = Vector2.ZERO
var hp: float = 100.0
var level: int = 1
var xp: float = 0.0
var xp_to_next: float = 5.0
var iframe_timer: float = 0.0
var revivals: int = 0
var weapons: Array = []  # Array[WeaponInstance] (≤6)
var passives: Array = []  # Array[PassiveInstance] (≤6)
var stats: StatBlock = StatBlock.new()
var derived: ResolvedStats = ResolvedStats.new()
var character_def = null  # CharacterDef this player was built from (for stat recompute)
