class_name Pickup extends RefCounted

## A non-gem collectible from drops/braziers, collected by PickupSystem which
## applies its effect by `type`. `value` carries the per-type magnitude
## (heal amount, coin value, effect duration). Plain mutable data.

enum Type { CHICKEN, COIN, COIN_BAG, VACUUM, ROSARY, OROLOGION, NDUJA, SORBETTO, CLOVER }

var pos: Vector2 = Vector2.ZERO
var type: int = Type.COIN
var value: float = 0.0
