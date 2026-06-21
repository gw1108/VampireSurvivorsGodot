class_name PassiveInstance extends RefCounted

## An owned passive item in the player's inventory (≤6). Created/leveled by
## ProgressionSystem; its modifiers feed StatSystem. `def` is a PassiveDef
## (data layer, later task). Plain mutable data.

var def = null  # PassiveDef resource
var level: int = 1
var stacks: int = 1
