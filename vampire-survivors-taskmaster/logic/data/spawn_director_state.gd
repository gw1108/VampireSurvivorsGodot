class_name SpawnDirectorState extends RefCounted

## Bookkeeping for the verbatim Mad Forest spawn curve. Plain data, advanced by
## SpawnDirector each tick. (Created here so GameManager can wire the RunState
## graph; SpawnDirector logic lives in res://logic/spawn_director.gd.)

var minute: int = 0
var periodic_timer: float = 0.0
var event_cursor: int = 0
var boss_cursor: int = 0
var brazier_timer: float = 0.0
var brazier_count: int = 0
var chests_opened: int = 0      # for the 1-1-3-1-1-5 beginner-luck sequence
var reaper_timer: float = 0.0
