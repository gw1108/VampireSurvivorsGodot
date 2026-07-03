class_name BalanceData
extends RefCounted
## Human-editable tuning numbers (player base move speed, weapon damage-per-level) live in
## one CSV — res://data/balance.csv, "id,value,description" — so a designer can rebalance
## without touching script code. Loaded once and cached; a missing/unreadable file or a
## missing row just falls back to the caller's `default` rather than crashing the run.

const CSV_PATH := "res://data/balance.csv"

static var _values: Dictionary = {}
static var _loaded := false

## The balance value for `id` from the CSV, or `default` if the row is absent.
static func get_value(id: String, default: float) -> float:
	_ensure_loaded()
	return float(_values.get(id, default))

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		push_warning("BalanceData: cannot open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header_skipped := false
	while not f.eof_reached():
		var row := f.get_csv_line()
		if not header_skipped:
			header_skipped = true
			continue
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		_values[row[0].strip_edges()] = row[1].strip_edges().to_float()
	f.close()
