class_name PickupSystem extends RefCounted

## Magnetize and collect gems, pickups, and chests. Pure; direct distance loops
## (entity counts are small enough that the SpatialIndex isn't needed here).
##   - gems within COLLECTION_RADIUS are collected -> XP (xGrowth) to Progression;
##     gems within the player's magnet range home toward the player;
##   - pickups apply their effect by type (chicken heal, coins xGreed -> gold,
##     vacuum -> collect all gems); effects owned by other systems are flagged
##     in global_effects for later;
##   - chests are collected (count incremented; content resolution is task 14);
##   - the 400-gem cap merges surplus into a single red gem.

const COLLECTION_RADIUS: float = 16.0
const MAGNET_SPEED: float = 300.0
const GEM_CAP: int = 400


static func step(state: GameState, dt: float) -> void:
	var player_pos: Vector2 = state.player.pos
	_step_gems(state, player_pos, dt)
	_step_pickups(state, player_pos)
	_step_chests(state, player_pos)
	_enforce_gem_cap(state)


static func _step_gems(state: GameState, player_pos: Vector2, dt: float) -> void:
	var magnet_range: float = state.player.derived.magnet
	var growth: float = state.player.derived.growth
	var collected: Array[int] = []
	for i in state.gems.size():
		var gem = state.gems[i]
		var dist: float = player_pos.distance_to(gem.pos)
		if dist <= COLLECTION_RADIUS:
			ProgressionSystem.add_xp(state, gem.xp * growth)
			collected.append(i)
		elif dist <= magnet_range:
			gem.pos += (player_pos - gem.pos).normalized() * MAGNET_SPEED * dt
	_remove_indices(state.gems, collected)


static func _step_pickups(state: GameState, player_pos: Vector2) -> void:
	var greed: float = state.player.derived.greed
	var growth: float = state.player.derived.growth
	var collected: Array[int] = []
	for i in state.pickups.size():
		var pk = state.pickups[i]
		if player_pos.distance_to(pk.pos) <= COLLECTION_RADIUS:
			_apply_pickup(state, pk, greed, growth)
			collected.append(i)
	_remove_indices(state.pickups, collected)


static func _apply_pickup(state: GameState, pk, greed: float, growth: float) -> void:
	match pk.type:
		Pickup.Type.CHICKEN:
			var p: PlayerState = state.player
			p.hp = minf(p.hp + pk.value, p.derived.max_health)
		Pickup.Type.COIN, Pickup.Type.COIN_BAG:
			state.gold += roundi(pk.value * greed)
		Pickup.Type.VACUUM:
			_collect_all_gems(state, growth)
		Pickup.Type.ROSARY:
			state.global_effects["rosary"] = true
		Pickup.Type.OROLOGION:
			state.global_effects["orologion"] = true
		Pickup.Type.NDUJA:
			state.global_effects["nduja"] = true
		Pickup.Type.SORBETTO:
			state.global_effects["sorbetto"] = true
		Pickup.Type.CLOVER:
			state.global_effects["clover"] = true


static func _collect_all_gems(state: GameState, growth: float) -> void:
	var total: float = 0.0
	for gem in state.gems:
		total += gem.xp * growth
	state.gems.clear()
	if total > 0.0:
		ProgressionSystem.add_xp(state, total)


static func _step_chests(state: GameState, player_pos: Vector2) -> void:
	var collected: Array[int] = []
	for i in state.chests.size():
		if player_pos.distance_to(state.chests[i].pos) <= COLLECTION_RADIUS:
			state.chest_count += 1  # content resolution -> ProgressionSystem (task 14)
			collected.append(i)
	_remove_indices(state.chests, collected)


## Merge gems beyond the cap into one red gem so the total never exceeds GEM_CAP.
static func _enforce_gem_cap(state: GameState) -> void:
	if state.gems.size() <= GEM_CAP:
		return
	var excess_xp: float = 0.0
	var last_pos: Vector2 = state.gems[state.gems.size() - 1].pos
	# Trim to GEM_CAP - 1 normal gems, then append one merged red gem -> GEM_CAP.
	while state.gems.size() > GEM_CAP - 1:
		var g = state.gems.pop_back()
		excess_xp += g.xp
		last_pos = g.pos
	var red := Gem.new()
	red.xp = excess_xp
	red.tier = Gem.Tier.RED
	red.pos = last_pos
	state.gems.append(red)


## Swap-remove a set of ascending indices (processed high->low to stay valid).
static func _remove_indices(arr: Array, indices: Array) -> void:
	for j in range(indices.size() - 1, -1, -1):
		var idx: int = indices[j]
		arr[idx] = arr[arr.size() - 1]
		arr.pop_back()
