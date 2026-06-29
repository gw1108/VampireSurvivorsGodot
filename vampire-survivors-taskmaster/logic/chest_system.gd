class_name ChestSystem extends RefCounted

## Pure logic for opening a Treasure Chest: decide the item count (the 1-1-3-1-1-5
## beginner-luck sequence for the first 6 chests, then a Luck-scaled sequential
## roll), auto-grant that many items by reusing LevelingSystem's option pipeline,
## and award tier-scaled gold (x Greed). No scene dependency; `db` is the
## GameDatabase (autoload Node or its script class).
##
## Uses GameDatabase constants (CHEST_BEGINNER_LUCK / CHEST_COUNT_CHANCE /
## CHEST_GOLD) rather than the sketch's hardcoded sequence, roll thresholds, and
## gold ranges, so the data stays single-sourced.

## Open a chest. Mutates `player` (inventory + gold) and `spawn_state`
## (chests_opened). Returns { items: Array, gold: int } where `gold` is the rolled
## amount before Greed (the player receives gold*Greed).
static func open(player: PlayerState, spawn_state: SpawnDirectorState, db, rng: RandomNumberGenerator) -> Dictionary:
	var seq: Array = db.CHEST_BEGINNER_LUCK
	var item_count: int
	if spawn_state.chests_opened < seq.size():
		item_count = int(seq[spawn_state.chests_opened])
	else:
		item_count = _roll_item_count(player, db, rng)
	spawn_state.chests_opened += 1

	var granted: Array = []
	for i in range(item_count):
		var options := LevelingSystem.make_options(player, db, rng)
		if options.is_empty():
			break
		var choice: Dictionary = options[0]  # chests auto-pick
		LevelingSystem.apply_choice(player, db, choice)
		granted.append(choice)

	var gold := _roll_gold(item_count, db, rng)
	var greed: float = player.stats.greed if player.stats != null else 1.0
	player.gold += int(gold * greed)
	return { items = granted, gold = gold }

## Sequential 5 -> 3 -> 1 roll using the GameDatabase chances (x Luck). A chest
## always yields at least one item.
static func _roll_item_count(player, db, rng: RandomNumberGenerator) -> int:
	var luck: float = player.stats.luck if player.stats != null else 1.0
	var chances: Dictionary = db.CHEST_COUNT_CHANCE
	if rng.randf() < float(chances.get("five", 0.03)) * luck:
		return 5
	if rng.randf() < float(chances.get("three", 0.10)) * luck:
		return 3
	return 1

## Roll gold within the tier's [min, max] (GameDatabase.CHEST_GOLD).
static func _roll_gold(item_count: int, db, rng: RandomNumberGenerator) -> int:
	var key := _tier_key(item_count)
	var range_pair: Array = db.CHEST_GOLD.get(key, [100, 200])
	return rng.randi_range(int(range_pair[0]), int(range_pair[1]))

static func _tier_key(item_count: int) -> String:
	if item_count >= 5:
		return "five"
	if item_count >= 3:
		return "three"
	return "one"
