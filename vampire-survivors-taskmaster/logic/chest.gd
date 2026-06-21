class_name Chest extends RefCounted

## Dropped by bosses; opened by PickupSystem -> ProgressionSystem. `rolled_count`
## (1/3/5 items) is resolved when the chest is opened. Plain mutable data.

var pos: Vector2 = Vector2.ZERO
var rolled_count: int = 0  # resolved on open
