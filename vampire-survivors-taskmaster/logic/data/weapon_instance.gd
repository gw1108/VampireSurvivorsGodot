class_name WeaponInstance extends RefCounted

## One owned weapon's runtime state. Plain data.
## `runtime` is per-pattern scratch (e.g. King Bible orbit angle,
## Runetracer bounce seed) owned by WeaponSystem.

var id: StringName = &""
var level: int = 1
var cooldown_timer: float = 0.0
var runtime: Dictionary = {}
