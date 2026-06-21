extends Node

## Autoload singleton (registered as `GameData`) that loads and exposes the
## immutable data layer once at startup. Weapons/enemies/passives live in their
## own subdirs; characters and stages are individual .tres at the data/ root and
## are routed by type. The level curve is delegated to the LevelCurve class (the
## single source of truth) rather than duplicated here.
##
## No class_name: the autoload's global name `GameData` is the accessor.

const DATA_ROOT := "res://data/"

var _weapons: Dictionary = {}     # id -> WeaponDef
var _enemies: Dictionary = {}     # id -> EnemyDef
var _passives: Dictionary = {}    # id -> PassiveDef
var _characters: Dictionary = {}  # id -> CharacterDef
var _stages: Dictionary = {}      # id -> StageDef


func _ready() -> void:
	_load_subdir(DATA_ROOT + "weapons/", _weapons)
	_load_subdir(DATA_ROOT + "enemies/", _enemies)
	_load_subdir(DATA_ROOT + "passives/", _passives)
	_load_root_defs()


## Load every .tres in a subdir into `dict` keyed by its `id`.
func _load_subdir(path: String, dict: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return  # e.g. passives not authored yet
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tres"):
			var res = load(path + file)
			if res != null and "id" in res:
				dict[res.id] = res
		file = dir.get_next()
	dir.list_dir_end()


## Load the individual character/stage .tres at the data root, routed by type.
func _load_root_defs() -> void:
	var dir := DirAccess.open(DATA_ROOT)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tres"):
			var res = load(DATA_ROOT + file)
			if res is CharacterDef:
				_characters[res.id] = res
			elif res is StageDef:
				_stages[res.id] = res
		file = dir.get_next()
	dir.list_dir_end()


# --- single-item accessors (null if unknown) ---

func get_weapon(id: String) -> WeaponDef:
	return _weapons.get(id)


func get_enemy(id: String) -> EnemyDef:
	return _enemies.get(id)


func get_passive(id: String) -> PassiveDef:
	return _passives.get(id)


func get_character(id: String) -> CharacterDef:
	return _characters.get(id)


func get_stage(id: String) -> StageDef:
	return _stages.get(id)


# --- collection accessors (typed copies) ---

func get_all_weapons() -> Array[WeaponDef]:
	var out: Array[WeaponDef] = []
	for w in _weapons.values():
		out.append(w)
	return out


func get_all_enemies() -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for e in _enemies.values():
		out.append(e)
	return out


func get_all_passives() -> Array[PassiveDef]:
	var out: Array[PassiveDef] = []
	for p in _passives.values():
		out.append(p)
	return out


# --- level curve (delegates to LevelCurve, the single source of truth) ---

## XP required to advance from `level` to `level + 1`.
func get_xp_for_level(level: int) -> float:
	return LevelCurve.xp_to_next(level)


## Total XP required to have reached `level` (from level 1).
func get_total_xp_for_level(level: int) -> float:
	return LevelCurve.total_xp_for_level(level)
