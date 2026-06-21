class_name PickupSystem extends RefCounted

## Magnetize and collect gems, pickups, and chests. Pure; direct distance loops
## (entity counts are small enough that the SpatialIndex isn't needed for collection).
##   - gems within COLLECTION_RADIUS are collected -> XP (xGrowth) to Progression;
##     gems within the player's magnet range home toward the player;
##   - pickups apply their effect by type:
##       chicken -> heal (value), coin/coin_bag -> gold (xGreed), vacuum -> collect
##       all gems, rosary -> kill every non-boss enemy, orologion -> freeze every
##       enemy, nduja/clover/sorbetto -> a timed stat buff (Might/Luck/Move Speed);
##   - chests are opened (items applied; count incremented);
##   - the 400-gem cap merges surplus into a single red gem.
##
## Timed buffs live on PlayerState.buffs and are *applied* in StatSystem.resolve (so
## they survive the per-tick stat reset); they are added here on collection and
## counted down each step by _tick_buffs.

const COLLECTION_RADIUS: float = 16.0
const MAGNET_SPEED: float = 300.0
const GEM_CAP: int = 400

# Special-pickup tuning.
const OROLOGION_FREEZE_DURATION: float = 8.0  # seconds every enemy stays frozen
const TEMP_BUFF_DURATION: float = 10.0        # seconds a collected stat buff lasts
const NDUJA_MIGHT_MULT: float = 2.0
const CLOVER_LUCK_MULT: float = 2.0
const SORBETTO_SPEED_MULT: float = 1.5  # placeholder magnitude; systems.md pairs nduja/sorbetto


static func step(state: GameState, dt: float) -> void:
	_tick_buffs(state, dt)
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
			_kill_all_enemies(state)
		Pickup.Type.OROLOGION:
			_freeze_all_enemies(state, OROLOGION_FREEZE_DURATION)
		Pickup.Type.NDUJA:
			_apply_temp_buff(state, "might", NDUJA_MIGHT_MULT, TEMP_BUFF_DURATION)
		Pickup.Type.CLOVER:
			_apply_temp_buff(state, "luck", CLOVER_LUCK_MULT, TEMP_BUFF_DURATION)
		Pickup.Type.SORBETTO:
			_apply_temp_buff(state, "move_speed", SORBETTO_SPEED_MULT, TEMP_BUFF_DURATION)


## Vacuum: bank every gem's XP at once and clear the field.
static func _collect_all_gems(state: GameState, growth: float) -> void:
	var total: float = 0.0
	for gem in state.gems:
		total += gem.xp * growth
	state.gems.clear()
	if total > 0.0:
		ProgressionSystem.add_xp(state, total)


## Rosary: kill every non-boss enemy (each counts as a kill and drops its XP gem),
## then drop them from the board. Reuses CombatSystem's death handler so kill/gem
## logic stays in one place. The SpatialIndex is rebuilt afterward because
## HealthSystem (next in the tick) broadphases against it — a now-stale index would
## map to removed / out-of-range enemy slots.
static func _kill_all_enemies(state: GameState) -> void:
	var killed_any := false
	for enemy in state.enemies:
		if not enemy.is_boss:
			CombatSystem._on_enemy_death(state, enemy)
			killed_any = true
	if not killed_any:
		return
	state.enemies = state.enemies.filter(func(e): return e.is_boss)
	if state.index != null:
		SpatialIndex.rebuild(state.index, state.enemies, state.gems, state.pickups)


## Orologion: freeze every enemy. MovementSystem holds an enemy still while its
## freeze_timer is positive and ticks it down. Bosses included, as in the source game.
static func _freeze_all_enemies(state: GameState, duration: float) -> void:
	for enemy in state.enemies:
		enemy.freeze_timer = duration


## Add a timed multiplicative stat buff, refreshing any existing buff on the same
## stat (re-collecting resets the timer rather than stacking the multiplier).
static func _apply_temp_buff(state: GameState, stat: String, mult: float, duration: float) -> void:
	var buffs: Array = state.player.buffs
	for i in range(buffs.size() - 1, -1, -1):
		if buffs[i].get("stat") == stat:
			buffs.remove_at(i)
	buffs.append({"stat": stat, "mult": mult, "time_left": duration})


## Count active buffs down and drop the expired ones.
static func _tick_buffs(state: GameState, dt: float) -> void:
	var buffs: Array = state.player.buffs
	for i in range(buffs.size() - 1, -1, -1):
		buffs[i]["time_left"] -= dt
		if buffs[i]["time_left"] <= 0.0:
			buffs.remove_at(i)


static func _step_chests(state: GameState, player_pos: Vector2) -> void:
	var collected: Array[int] = []
	for i in state.chests.size():
		if player_pos.distance_to(state.chests[i].pos) <= COLLECTION_RADIUS:
			ProgressionSystem.open_chest(state, state.chests[i])  # rolls + applies items
			state.chest_count += 1
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
