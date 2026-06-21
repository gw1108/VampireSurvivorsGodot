class_name GameState extends RefCounted

## The entire mutable state of one run — the single object threaded through
## every pure system. Created by RunController on run start, mutated by every
## system each tick, discarded and recreated on restart. Plain mutable data.

enum Phase { TITLE, PLAYING, PAUSED, LEVEL_UP, GAME_OVER, RESULTS }

var time_elapsed: float = 0.0  # sim seconds
var current_minute: int = 0
var phase: int = Phase.TITLE
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player: PlayerState = PlayerState.new()
var enemies: Array = []  # Array[Enemy]
var projectiles: Array = []  # Array[Projectile]
var zones: Array = []  # Array[DamageZone]
var gems: Array = []  # Array[Gem]
var pickups: Array = []  # Array[Pickup]
var chests: Array = []  # Array[Chest]
var light_sources: Array = []  # Array[LightSource]
# Untyped: SpatialIndex is created in a later task. Set after SpatialIndex exists.
var index = null
var spawn_cursor: int = 0
var event_cursor: int = 0
var chest_count: int = 0
var kills: int = 0
var gold: int = 0
var pending_levelups: int = 0
var current_offer = null  # LevelUpOffer
var global_effects: Dictionary = {}  # orologion/breath/temp-growth timers
