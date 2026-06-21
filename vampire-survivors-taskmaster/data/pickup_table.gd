class_name PickupTable extends RefCounted

## Weighted drop pool for braziers / light sources (and the generic drop roll).
## Static data — never instantiated as game state. Keys are Pickup.Type; values
## are relative weights. NOTE: these weights are initial estimates and should be
## validated against the wiki when the data layer is fully authored; the roll
## mechanism below is the stable part of the contract.

const WEIGHTS: Dictionary = {
	Pickup.Type.COIN: 40,
	Pickup.Type.CHICKEN: 8,
	Pickup.Type.COIN_BAG: 6,
	Pickup.Type.VACUUM: 3,
	Pickup.Type.ROSARY: 2,
	Pickup.Type.OROLOGION: 2,
	Pickup.Type.NDUJA: 1,
	Pickup.Type.SORBETTO: 1,
	Pickup.Type.CLOVER: 1,
}


## Sum of all relative weights.
static func total_weight() -> int:
	var sum: int = 0
	for w: int in WEIGHTS.values():
		sum += w
	return sum


## Roll a weighted Pickup.Type using the seeded RNG (deterministic per seed).
static func roll(rng: RandomNumberGenerator) -> int:
	var pick: int = rng.randi_range(1, total_weight())
	var acc: int = 0
	for type: int in WEIGHTS.keys():
		acc += WEIGHTS[type]
		if pick <= acc:
			return type
	return Pickup.Type.COIN  # unreachable; defensive fallback
