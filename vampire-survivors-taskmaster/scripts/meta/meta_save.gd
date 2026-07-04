class_name MetaSave
extends RefCounted
## Persisted between-run meta-currency store for the VS "coins" economy.
##
## A run banks coins into VSRun.gold, which resets every run. On game-over the run
## deposits that gold here (see VSRun._on_player_died) so the purse carries across
## runs and can later fund a PowerUp shop. One flat JSON file under user://.
##
## Deliberately paranoid about the file, because a wiped balance is worse than a
## dropped deposit: a missing, empty, truncated, or corrupt save reads as zero
## coins instead of crashing, and every write lands in a temp file that is then
## swapped into place — so a crash mid-write can't leave a half-written save that
## would zero out the player's accumulated coins.

const SAVE_PATH := "user://meta_save.json"
const TMP_PATH := "user://meta_save.json.tmp"
const SCHEMA_VERSION := 1
# 64-bit signed ints top out near 9.2e18; cap the bank far below that so no plausible
# run of deposits can ever wrap the balance negative.
const COINS_MAX := 1_000_000_000_000  # 1e12 — beyond any real run, still overflow-safe


## Total coins banked across all runs, or 0 if the save is absent/unreadable/corrupt.
static func load_coins() -> int:
	return _sanitize(_load_data().get("coins", 0))


## Deposit `amount` coins (negatives and non-positive values ignored) and persist the
## new total. Returns the new total. A failed write leaves the prior balance intact.
static func add_coins(amount: int) -> int:
	var data := _load_data()
	var current := _sanitize(data.get("coins", 0))
	var total := clampi(current + maxi(amount, 0), 0, COINS_MAX)
	data["coins"] = total
	data["version"] = SCHEMA_VERSION
	_save_data(data)
	return total


## Spend `amount` coins if the balance covers it, persisting the reduced total. Returns
## true on success (balance debited + saved), false with no change if `amount` is
## non-positive or exceeds the banked coins. This is the withdraw half of the economy —
## the PowerUp shop's primitive for turning banked coins into permanent boosts.
static func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return false
	var data := _load_data()
	var current := _sanitize(data.get("coins", 0))
	if amount > current:
		return false
	data["coins"] = current - amount
	data["version"] = SCHEMA_VERSION
	_save_data(data)
	return true


## Purchased permanent-PowerUp levels, id -> level. Missing/garbage reads as {} so a
## fresh or corrupt save simply grants no boosts. Non-int levels are dropped, not crashed.
static func load_powerups() -> Dictionary:
	var raw: Variant = _load_data().get("powerups", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var out := {}
	for id in raw.keys():
		out[str(id)] = _sanitize(raw[id])
	return out


## Current purchased level of one PowerUp id (0 if never bought).
static func powerup_level(id: String) -> int:
	return _sanitize(load_powerups().get(id, 0))


## Buy one level of PowerUp `id`: atomically debit `cost` coins and bump its level, but
## only if the player can afford it AND it's below `max_level`. Coins and the level are
## written in a SINGLE save so the two can never drift apart (a crash can't leave a paid
## level un-granted or vice-versa). Returns true on a successful purchase.
static func buy_powerup(id: String, cost: int, max_level: int) -> bool:
	if cost < 0:
		return false
	var data := _load_data()
	var current := _sanitize(data.get("coins", 0))
	if cost > current:
		return false
	var powerups: Variant = data.get("powerups", {})
	if typeof(powerups) != TYPE_DICTIONARY:
		powerups = {}
	var lvl := _sanitize(powerups.get(id, 0))
	if lvl >= max_level:
		return false
	powerups[id] = lvl + 1
	data["powerups"] = powerups
	data["coins"] = current - cost
	data["version"] = SCHEMA_VERSION
	_save_data(data)
	return true


## Whether unlockable `id` has been earned in some past (or the current) run. VS-style
## content unlocks survive across runs, so they live here rather than on the transient
## VSRun. Missing/garbage reads as not-unlocked, so a fresh or corrupt save gates every
## unlockable — matching a brand-new profile.
static func is_unlocked(id: String) -> bool:
	var raw: Variant = _load_data().get("unlocks", [])
	if typeof(raw) != TYPE_ARRAY:
		return false
	return raw.has(id)


## Persist that unlockable `id` has been earned (e.g. the Clover passive after a first
## Little Clover pickup). Idempotent: re-unlocking an already-earned id is a no-op that
## skips the disk write, so it's cheap to call on every pickup.
static func unlock(id: String) -> void:
	var data := _load_data()
	var raw: Variant = data.get("unlocks", [])
	var unlocks: Array = raw if typeof(raw) == TYPE_ARRAY else []
	if unlocks.has(id):
		return
	unlocks.append(id)
	data["unlocks"] = unlocks
	data["version"] = SCHEMA_VERSION
	_save_data(data)


## Coerce whatever came off disk (int, float, string, or garbage) into a valid,
## in-range coin count. Anything non-numeric collapses to 0.
static func _sanitize(value: Variant) -> int:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return clampi(int(value), 0, COINS_MAX)
		TYPE_STRING:
			return clampi(int(str(value).to_int()), 0, COINS_MAX)
		_:
			return 0


static func _load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("MetaSave: cannot open %s (err %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MetaSave: corrupt save at %s, treating as empty" % SAVE_PATH)
		return {}
	return parsed


static func _save_data(data: Dictionary) -> void:
	# Write to a temp file first, then swap it into place, so an interrupted write
	# can never truncate the real save and lose the player's banked coins.
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("MetaSave: cannot write %s (err %d)" % [TMP_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("MetaSave: cannot open user:// to commit save")
		return
	# rename() won't overwrite an existing target on every platform (notably Windows),
	# so drop the old save first. Not perfectly atomic, but the temp write already
	# guards the common failure — a truncated write from a crash mid-store.
	if dir.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH)
	var err := dir.rename(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_warning("MetaSave: failed to commit save (err %d)" % err)
