class_name WeaponInstance extends RefCounted

## An owned weapon in the player's inventory (≤6). Created/leveled by
## ProgressionSystem; its cooldown is ticked and pattern cast by WeaponSystem.
## `scratch` holds per-weapon runtime state (Whip side alternation, Pentagram
## 90s timer, etc.). `def` is a WeaponDef (data layer, later task). Mutable data.

var def = null  # WeaponDef resource
var level: int = 1  # 1..8
var cooldown_timer: float = 0.0
var scratch: Dictionary = {}
