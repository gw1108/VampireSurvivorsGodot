class_name ProgressionSystem extends RefCounted

## XP / leveling: add_xp threshold crossing, level-up offer generation, and
## choice application. Pure. Each option is a Dictionary:
##   {kind: "weapon"|"passive", def, is_upgrade, target (inst|null), target_level}
##
## Corrections vs the task sketch (kept consistent with this codebase):
##  - next threshold uses LevelCurve.xp_to_next(player.level) after leveling
##    (the sketch's `+ 1` was off-by-one for our curve definition);
##  - NO +600/+2400 "bonus XP" is granted at L20/L40 — those are requirement
##    increases already baked into LevelCurve.CUMULATIVE_XP, so adding them as
##    free XP would double-count. (The +100% Growth special is a separate buff.)
##  - the offer shuffle uses state.rng (Fisher-Yates), NOT Array.shuffle() which
##    uses the GLOBAL rng and would break determinism;
##  - apply_choice recomputes with the player's character_def so a level-up does
##    not wipe the character's base stats (the sketch's recompute_block(player)
##    dropped them);
##  - the catalog is loaded by path, NOT via the GameData autoload (autoloads are
##    not in scope inside a class_name script).

const MAX_WEAPONS: int = 6
const MAX_PASSIVES: int = 6
const WEAPON_MAX_LEVEL: int = 8
const PASSIVE_MAX_LEVEL_DEFAULT: int = 5
const WEAPONS_DIR := "res://data/weapons/"
const PASSIVES_DIR := "res://data/passives/"


## Add XP and cross as many level-up thresholds as it covers, queueing each.
static func add_xp(state: GameState, amount: float) -> void:
	var player: PlayerState = state.player
	player.xp += amount
	while player.xp >= player.xp_to_next:
		player.xp -= player.xp_to_next
		player.level += 1
		state.pending_levelups += 1
		player.xp_to_next = LevelCurve.xp_to_next(player.level)


## Build the 3-4 option level-up offer (upgrades of owned items + new items),
## shuffled deterministically with state.rng. Empty pool -> is_max_state.
static func build_offer(state: GameState) -> LevelUpOffer:
	var offer := LevelUpOffer.new()
	var player: PlayerState = state.player
	var pool: Array = []
	pool.append_array(_get_upgradeable_weapons(player))
	pool.append_array(_get_upgradeable_passives(player))
	if player.weapons.size() < MAX_WEAPONS:
		pool.append_array(_get_new_weapons(player))
	if player.passives.size() < MAX_PASSIVES:
		pool.append_array(_get_new_passives(player))

	if pool.is_empty():
		offer.is_max_state = true  # full + maxed inventory -> gold/chicken (granted by caller)
		return offer

	_shuffle(pool, state.rng)
	var num_options := 3
	if state.rng.randf() < (1.0 - 1.0 / maxf(player.derived.luck, 0.0001)):
		num_options = 4
	var options: Array = []
	for i in mini(num_options, pool.size()):
		options.append(pool[i])
	offer.options = options
	return offer


## Apply the chosen option (add a new item or +1 an existing one), then recompute
## stats and consume one queued level-up.
static func apply_choice(state: GameState, index: int) -> void:
	var player: PlayerState = state.player
	var offer: LevelUpOffer = state.current_offer
	if offer != null and index >= 0 and index < offer.options.size():
		var choice: Dictionary = offer.options[index]
		if choice["is_upgrade"]:
			choice["target"].level += 1
		elif choice["kind"] == "weapon":
			var w := WeaponInstance.new()
			w.def = choice["def"]
			w.level = 1
			player.weapons.append(w)
		else:
			var p := PassiveInstance.new()
			p.def = choice["def"]
			p.level = 1
			player.passives.append(p)
	StatSystem.recompute_block(player, player.character_def)
	state.pending_levelups = maxi(state.pending_levelups - 1, 0)


# --- option gathering ---

static func _get_upgradeable_weapons(player: PlayerState) -> Array:
	var out: Array = []
	for w in player.weapons:
		if w.def != null and w.level < WEAPON_MAX_LEVEL:
			out.append(_upgrade_option("weapon", w))
	return out


static func _get_upgradeable_passives(player: PlayerState) -> Array:
	var out: Array = []
	for p in player.passives:
		var max_level: int = p.def.max_level if p.def != null else PASSIVE_MAX_LEVEL_DEFAULT
		if p.level < max_level:
			out.append(_upgrade_option("passive", p))
	return out


static func _get_new_weapons(player: PlayerState) -> Array:
	return _new_options_from(player.weapons, WEAPONS_DIR, "weapon")


static func _get_new_passives(player: PlayerState) -> Array:
	return _new_options_from(player.passives, PASSIVES_DIR, "passive")


static func _new_options_from(owned: Array, dir_path: String, kind: String) -> Array:
	var owned_ids := {}
	for inst in owned:
		if inst.def != null:
			owned_ids[inst.def.id] = true
	var out: Array = []
	for def in _load_defs(dir_path):
		if not owned_ids.has(def.id):
			out.append(_new_option(kind, def))
	return out


static func _new_option(kind: String, def) -> Dictionary:
	return {"kind": kind, "def": def, "is_upgrade": false, "target": null, "target_level": 1}


static func _upgrade_option(kind: String, inst) -> Dictionary:
	return {"kind": kind, "def": inst.def, "is_upgrade": true, "target": inst, "target_level": inst.level + 1}


# --- helpers ---

## All defs in a data subdir (by path; GameData autoload is not usable here).
static func _load_defs(dir_path: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".tres"):
			var res = load(dir_path + f)
			if res != null:
				out.append(res)
		f = dir.get_next()
	dir.list_dir_end()
	return out


## Deterministic in-place Fisher-Yates shuffle using the run's seeded rng.
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
