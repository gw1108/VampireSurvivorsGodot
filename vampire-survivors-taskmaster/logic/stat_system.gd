class_name StatSystem extends RefCounted

## Pure stat resolution. Two phases (architecture's cached model):
##
##  recompute_block(player, character_def) — rebuilds player.stats (the raw
##    accumulated StatBlock) from character base + level growth + every passive.
##    Called only when the inventory or level changes (cheap to amortize).
##
##  resolve(player, stage_def) — maps player.stats -> player.derived each tick,
##    applies stage modifiers, and clamps to the game caps.
##
## Passives are summed ONCE in recompute_block (NOT re-applied in resolve), so a
## per-tick resolve never iterates the inventory and stats are never double-counted.

# Stat caps.
const MAX_COOLDOWN_REDUCTION: float = 0.9  # cooldown multiplier floored at 10% of base
const MIN_COOLDOWN_MULT: float = 0.1  # = 1 - MAX_COOLDOWN_REDUCTION, kept exact (no float error)
const MAX_MOVE_SPEED_MULT: float = 2.0
const MAX_AREA_MULT: float = 3.0
const MIN_ARMOR: float = 0.0
const MAX_ARMOR: float = 100.0

# The 16 StatBlock/ResolvedStats fields, for generic copy/accumulation.
const STAT_FIELDS: PackedStringArray = [
	"might", "area", "cooldown", "amount", "duration", "speed", "move_speed",
	"max_health", "recovery", "armor", "magnet", "luck", "growth", "greed",
	"curse", "revival",
]


## Map the cached StatBlock to ResolvedStats, apply stage modifiers, clamp caps.
static func resolve(player: PlayerState, stage_def = null) -> void:
	var derived: ResolvedStats = player.derived
	var block: StatBlock = player.stats
	for f in STAT_FIELDS:
		derived.set(f, block.get(f))

	# Stage-wide player modifiers (enemy_* modifiers are read by the enemy
	# systems directly, not folded into the player's derived stats).
	if stage_def != null and stage_def.stat_modifiers is Dictionary:
		if stage_def.stat_modifiers.has("curse"):
			derived.curse *= stage_def.stat_modifiers["curse"]

	# Timed special-pickup buffs (Nduja->Might, Clover->Luck, Sorbetto->Move Speed).
	# Applied here, after the block->derived copy, so they survive the per-tick reset;
	# PickupSystem adds them and ticks their timers down. Before caps so a buffed
	# capped stat (e.g. move_speed) still clamps.
	for buff in player.buffs:
		var bstat: String = buff.get("stat", "")
		if bstat != "" and bstat in STAT_FIELDS:
			derived.set(bstat, float(derived.get(bstat)) * float(buff.get("mult", 1.0)))

	# Caps.
	derived.cooldown = maxf(MIN_COOLDOWN_MULT, derived.cooldown)
	derived.move_speed = minf(derived.move_speed, MAX_MOVE_SPEED_MULT)
	derived.area = minf(derived.area, MAX_AREA_MULT)
	derived.armor = clampf(derived.armor, MIN_ARMOR, MAX_ARMOR)


## Rebuild player.stats from character base + level growth + passive items.
## `character_def` is optional (null -> defaults + passives only).
static func recompute_block(player: PlayerState, character_def = null) -> void:
	var block := StatBlock.new()  # defaults
	if character_def != null:
		block.max_health = character_def.max_health
		block.move_speed = character_def.move_speed
		# Character base stat overrides (e.g. Antonio's +1 Armor).
		for stat in character_def.base_stats:
			if block.get(stat) != null:
				block.set(stat, character_def.base_stats[stat])
		_apply_growth(block, character_def, player.level)
	for passive in player.passives:
		_apply_passive(block, passive)
	player.stats = block


## Add a character's per-level growth (e.g. +10% Might every 10 levels, capped).
static func _apply_growth(block: StatBlock, character_def, level: int) -> void:
	var interval: int = maxi(character_def.growth_interval, 1)
	@warning_ignore("integer_division")
	var steps: int = level / interval  # integer division: L10/10 = 1 step
	if steps <= 0:
		return
	for stat in character_def.growth_bonuses:
		if block.get(stat) == null:
			continue
		var total: float = float(character_def.growth_bonuses[stat]) * steps
		if character_def.growth_cap.has(stat):
			total = minf(total, character_def.growth_cap[stat])
		block.set(stat, block.get(stat) + total)


## Add one passive item's cumulative bonus at its current level (additive).
static func _apply_passive(block: StatBlock, passive) -> void:
	if passive == null or passive.def == null:
		return
	var bonuses = passive.def.stat_bonuses
	if not (bonuses is Dictionary):
		return
	var lvl_idx: int = maxi(passive.level, 1) - 1
	for stat in bonuses:
		if block.get(stat) == null:
			continue
		var arr = bonuses[stat]
		if not (arr is Array) or arr.is_empty():
			continue
		var idx: int = clampi(lvl_idx, 0, arr.size() - 1)
		block.set(stat, block.get(stat) + arr[idx])
