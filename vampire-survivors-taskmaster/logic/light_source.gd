class_name LightSource extends RefCounted

## A breakable brazier spawned by SpawnDirector; damaged by CombatSystem; on
## break drops from the weighted pickup pool. Plain mutable data.

var pos: Vector2 = Vector2.ZERO
var hp: float = 10.0
