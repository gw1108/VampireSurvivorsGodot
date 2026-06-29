class_name RunState extends RefCounted

## The single root of all mutable run state, threaded into every pure system.
## Created by GameManager on Start, mutated every tick by the systems, and
## discarded on return to menu / recreated on restart. Plain data — no scene
## dependency.
##
## NOTE: the pool/grid/spawn fields are intentionally left untyped here because
## their classes land in later tasks (EnemyPool/ProjectilePool/PickupPool/
## FloatingTextPool -> Task 2, SpatialGrid -> Task 3, SpawnDirectorState ->
## SpawnDirector task). The intended type is named in the trailing comment; a
## later task may add the explicit annotation once the class exists.

enum Phase { PLAYING, LEVEL_UP, PAUSED, GAME_OVER }

var phase: int = Phase.PLAYING  # mirrors sim intent; GameManager owns the screen FSM
var elapsed: float = 0.0

var player: PlayerState

var enemies          # EnemyPool (Task 2)
var projectiles      # ProjectilePool (Task 2)
var pickups          # PickupPool (Task 2)
var floaters         # FloatingTextPool (Task 2)
var grid             # SpatialGrid (Task 3)
var spawn            # SpawnDirectorState (SpawnDirector task)

var rng: RandomNumberGenerator

var level_up_queue: int = 0
var freeze_timer: float = 0.0      # Orologion
var firebreath_timer: float = 0.0  # Nduja

var camera_world_rect: Rect2       # set by the shell each tick for spawn/cull

var result: RunResult              # filled on death
