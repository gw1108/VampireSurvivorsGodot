class_name LevelingSystem extends RefCounted

## Pure stateless leveling logic: converts XP into levels, builds the 3-4 option
## level-up choice set, and applies a chosen upgrade. No scene dependency.
## `player` is a PlayerState; `db` is GameDatabase (autoload Node or its script
## class) — left untyped so either can be supplied for headless tests, matching
## StatSystem.
##
## DEVIATIONS from the task sketch (intentional, to fit the established model):
##   * `add_xp` RETURNS the number of levels gained instead of writing
##     `player.level_up_queue`. The level-up queue lives on RunState (Task 1),
##     not PlayerState, so the controller adds the return value to
##     `run_state.level_up_queue`. This keeps a single source of truth.
##   * Maxed-item exclusion is DB-driven: a weapon maxes at its `levels.size()`
##     (8) and a passive at its `max_level` (5 for most, but Duplicator = 2).
##     The sketch hardcoded 5 for all passives, which would wrongly keep
##     offering Duplicator past level 2.
##   * `make_options` shuffles with the passed-in `rng` (Fisher-Yates) rather
##     than `Array.shuffle()` (global RNG) so option draws are reproducible when
##     the run RNG is seeded — the whole reason `rng` is threaded in.

const INVENTORY_CAP := 6  # 6 weapons + 6 passives

## Add `amount` XP (scaled by Growth) and resolve any level-ups. Returns the
## number of levels gained this call (0 if none) so the caller can enqueue that
## many level-up screens. A single big gem can cross several thresholds at once.
static func add_xp(player, db, amount: float) -> int:
	var growth_mult: float = player.stats.growth if player.stats != null else 1.0
	player.xp += amount * growth_mult

	var levels_gained := 0
	while player.xp >= player.xp_to_next:
		player.xp -= player.xp_to_next
		player.level += 1
		player.xp_to_next = db.xp_to_next(player.level)
		levels_gained += 1

		# Antonio's level bonus changes (+10% Might every 10 levels) -> re-stat.
		if player.level % 10 == 0:
			player.stats_dirty = true

	return levels_gained

## Build the level-up choice set: 3 options, or 4 with the Luck-driven chance
## (1 - 1/totalLuck). Owned non-maxed items appear as upgrades; new items appear
## while inventory has room. When nothing remains (full + all maxed) the run
## falls back to a gold/Floor-Chicken pair.
static func make_options(player, db, rng: RandomNumberGenerator) -> Array:
	var luck: float = player.stats.luck if player.stats != null else 1.0
	var option_count := 3
	if rng.randf() < (1.0 - 1.0 / luck):
		option_count = 4

	var weapons_full: bool = player.weapons.size() >= INVENTORY_CAP
	var passives_full: bool = player.passives.size() >= INVENTORY_CAP

	var candidates: Array = []

	# Owned items that can still level up.
	for w in player.weapons:
		if w.level < _weapon_max_level(db, w.id):
			candidates.append({type = "weapon_upgrade", id = w.id, level = w.level + 1})
	for p in player.passives:
		if p.level < _passive_max_level(db, p.id):
			candidates.append({type = "passive_upgrade", id = p.id, level = p.level + 1})

	# New items while there is inventory room.
	if not weapons_full:
		for wid in db.WEAPONS.keys():
			if not _has_weapon(player, wid):
				candidates.append({type = "new_weapon", id = wid})
	if not passives_full:
		for pid in db.PASSIVES.keys():
			if not _has_passive(player, pid):
				candidates.append({type = "new_passive", id = pid})

	# Full and fully maxed -> offer the gold / Floor Chicken consolation pair.
	if candidates.is_empty():
		return [{type = "gold", value = 25}, {type = "chicken"}]

	_shuffle(candidates, rng)
	var options: Array = []
	for i in range(mini(option_count, candidates.size())):
		options.append(candidates[i])
	return options

## Apply the player's chosen option, mutating PlayerState in place. Always raises
## `stats_dirty` so the controller re-runs StatSystem afterward.
static func apply_choice(player, db, choice: Dictionary) -> void:
	match choice.type:
		"weapon_upgrade":
			for w in player.weapons:
				if w.id == choice.id:
					w.level = choice.level
					break
		"passive_upgrade":
			for p in player.passives:
				if p.id == choice.id:
					p.level = choice.level
					break
		"new_weapon":
			var inst := WeaponInstance.new()
			inst.id = choice.id
			inst.level = 1
			player.weapons.append(inst)
		"new_passive":
			var inst := PassiveInstance.new()
			inst.id = choice.id
			inst.level = 1
			player.passives.append(inst)
		"gold":
			player.gold += int(choice.value)
		"chicken":
			var cap: float = player.stats.max_health if player.stats != null else player.max_hp
			player.hp = minf(player.hp + 30.0, cap)

	player.stats_dirty = true

## Spend a reroll charge (if any) and redraw the option set. Returns the new
## options, or an empty array when no charge is available.
static func reroll(player, db, rng: RandomNumberGenerator) -> Array:
	if player.reroll_charges <= 0:
		return []
	player.reroll_charges -= 1
	return make_options(player, db, rng)

# --- helpers -----------------------------------------------------------------

static func _weapon_max_level(db, id: StringName) -> int:
	var def: Dictionary = db.weapon(id)
	var levels: Array = def.get("levels", [])
	return levels.size() if not levels.is_empty() else 8

static func _passive_max_level(db, id: StringName) -> int:
	var def: Dictionary = db.passive(id)
	return int(def.get("max_level", 5))

static func _has_weapon(player, id: StringName) -> bool:
	for w in player.weapons:
		if w.id == id:
			return true
	return false

static func _has_passive(player, id: StringName) -> bool:
	for p in player.passives:
		if p.id == id:
			return true
	return false

## In-place Fisher-Yates shuffle driven by the supplied RNG (deterministic when
## seeded), so option draws are reproducible in tests.
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
