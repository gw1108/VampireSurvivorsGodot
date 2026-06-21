class_name Gem extends RefCounted

## An XP gem dropped on enemy death; magnetized & collected by PickupSystem.
## Tier sets the XP value bracket (blue < green < red). Plain mutable data.

enum Tier { BLUE, GREEN, RED }

var pos: Vector2 = Vector2.ZERO
var xp: float = 1.0
var tier: int = Tier.BLUE
