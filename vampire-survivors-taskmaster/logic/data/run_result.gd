class_name RunResult extends RefCounted

## Snapshot of a finished run, filled by the death check and shown on the
## result screen. Plain data — no scene dependency.

var survival_time: float = 0.0
var final_level: int = 1
var total_kills: int = 0
var total_gold: int = 0
