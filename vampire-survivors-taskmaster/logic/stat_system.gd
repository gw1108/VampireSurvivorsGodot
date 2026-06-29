class_name StatSystem extends RefCounted

## Resolve PlayerState inventory + level into the derived StatBlock. Pure logic:
## writes only `player.stats` and clears `stats_dirty`. `db` is the GameDatabase
## (only its `passive(id)` accessor is used); it is passed in rather than
## hard-referenced so the system stays headless-testable. Left untyped so either
## the GameDatabase autoload Node or its script class can be supplied.
##
## Resolution order (GDD Player Stat Model):
##   1. base values
##   2. Antonio's character bonus (+20 Max HP, +1 Armor)
##   3. Antonio's level bonus (+10% Might per 10 levels, capped +50% at L50)
##   4. each passive's per-level contribution
##   5. StatBlock.clamp_all() enforces caps + non-negative floors
##
## Passive stacking is additive (`stat += per_level * level`) except Hollow Heart
## which is multiplicative on Max HP (`stat *= (1 + per_level)^level`). per_level
## values are stored already-signed in GameDatabase (e.g. Empty Tome -0.08), so
## additive application needs no per-stat sign handling.

static func recompute(player, db) -> void:
	var stats: StatBlock = player.stats
	if stats == null:
		stats = StatBlock.new()
		player.stats = stats

	# 1. base values
	stats.max_health = 100.0
	stats.recovery = 0.0
	stats.armor = 0.0
	stats.move_speed = 1.0
	stats.might = 1.0
	stats.area = 1.0
	stats.speed = 1.0
	stats.duration = 1.0
	stats.cooldown = 1.0
	stats.amount = 0.0
	stats.magnet = 30.0   # pickup radius in pixels (GDD base)
	stats.luck = 1.0
	stats.growth = 1.0
	stats.greed = 1.0
	stats.curse = 1.0

	# 2. Antonio's character bonus
	stats.max_health += 20.0
	stats.armor += 1.0

	# 3. Antonio's level bonus: +10% Might every 10 levels, capped at +50%
	stats.might += mini(player.level / 10, 5) * 0.10

	# 4. passive contributions
	for passive in player.passives:
		var def: Dictionary = db.passive(passive.id)
		if def.is_empty():
			continue
		var stat_name: String = def.get("stat", "")
		if stat_name == "":
			continue
		var per_level: float = def.get("per_level", 0.0)
		var lvl: int = passive.level
		if def.get("stacking", "additive") == "multiplicative":
			stats.set(stat_name, float(stats.get(stat_name)) * pow(1.0 + per_level, lvl))
		else:
			stats.set(stat_name, float(stats.get(stat_name)) + per_level * lvl)

	# 5. enforce caps / floors
	stats.clamp_all()
	player.stats_dirty = false
