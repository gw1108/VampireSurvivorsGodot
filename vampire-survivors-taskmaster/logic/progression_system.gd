class_name ProgressionSystem extends RefCounted

## XP / leveling. NOTE: this file currently implements ONLY add_xp — the slice
## PickupSystem needs to route collected XP. The level-up offer generation
## (build_offer), choice application (apply_choice) and chest resolution
## (open_chest) are added in task 14; do not regress add_xp when extending.
##
## Corrections vs the task-14 sketch (kept consistent with this codebase):
##  - next threshold uses LevelCurve.xp_to_next(player.level) after leveling
##    (the sketch's `+ 1` was off-by-one for our curve definition);
##  - NO +600/+2400 "bonus XP" is granted at L20/L40 — those are requirement
##    increases already baked into LevelCurve.CUMULATIVE_XP, so adding them as
##    free XP would double-count. (The +100% Growth special is a separate buff.)

const MAX_WEAPONS: int = 6
const MAX_PASSIVES: int = 6


## Add XP and cross as many level-up thresholds as it covers, queueing each.
static func add_xp(state: GameState, amount: float) -> void:
	var player: PlayerState = state.player
	player.xp += amount
	while player.xp >= player.xp_to_next:
		player.xp -= player.xp_to_next
		player.level += 1
		state.pending_levelups += 1
		player.xp_to_next = LevelCurve.xp_to_next(player.level)
