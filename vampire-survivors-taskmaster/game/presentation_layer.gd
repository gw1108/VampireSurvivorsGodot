class_name PresentationLayer extends Node2D

## Pure view: mirrors GameState entity arrays onto pooled Sprite2D nodes each
## frame. Owns one sprite pool per category (reused, never freed during a run) so
## there are no per-frame allocations. sync(state) hides every pooled sprite, then
## positions+shows one per live entity, growing a pool on demand.
##
## Textures are the placeholder art from res://assets/sprites/ (task 33), loaded at
## ready with a fallback to icon.svg if a file is missing. The texture carries each
## category's colour/shape, so modulate stays white.
##
## Correction vs the task sketch: EnemyDef has no `texture` field, so
## `entity.def.texture` is a runtime error — textures are chosen by category here
## (and by gem tier / boss / reaper), not read off the def.

const POOL_INITIAL_SIZE: int = 100
const SPRITE_DIR := "res://assets/sprites/"
const FALLBACK: Texture2D = preload("res://icon.svg")

var _tex_player: Texture2D
var _tex_enemy: Texture2D
var _tex_boss: Texture2D
var _tex_reaper: Texture2D
var _tex_projectile: Texture2D
var _tex_zone: Texture2D
var _tex_pickup: Texture2D
var _tex_gems: Array[Texture2D] = []  # indexed by Gem.Tier (BLUE/GREEN/RED)

var _enemy_pool: Array[Sprite2D] = []
var _projectile_pool: Array[Sprite2D] = []
var _zone_pool: Array[Sprite2D] = []
var _gem_pool: Array[Sprite2D] = []
var _pickup_pool: Array[Sprite2D] = []
var _player_sprite: Sprite2D = null


func _ready() -> void:
	_load_textures()
	_init_pools()
	_create_player_sprite()


func _load_textures() -> void:
	_tex_player = _load_tex("player")
	_tex_enemy = _load_tex("enemy")
	_tex_boss = _load_tex("enemy_boss")
	_tex_reaper = _load_tex("reaper")
	_tex_projectile = _load_tex("projectile")
	_tex_zone = _load_tex("zone")
	_tex_pickup = _load_tex("pickup")
	_tex_gems = [_load_tex("gem_blue"), _load_tex("gem_green"), _load_tex("gem_red")]


## Load a placeholder texture by base name, falling back to the engine icon so a
## missing asset degrades gracefully instead of rendering nothing.
func _load_tex(base_name: String) -> Texture2D:
	var path := SPRITE_DIR + base_name + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	return tex if tex != null else FALLBACK


func _init_pools() -> void:
	for i in POOL_INITIAL_SIZE:
		_enemy_pool.append(_create_sprite())
		_projectile_pool.append(_create_sprite())
		_gem_pool.append(_create_sprite())


func _create_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = FALLBACK
	sprite.visible = false
	add_child(sprite)
	return sprite


func _create_player_sprite() -> void:
	_player_sprite = _create_sprite()
	_player_sprite.texture = _tex_player
	_player_sprite.visible = true


## Mirror the whole GameState onto the sprite pools. Call once per rendered frame.
func sync(state: GameState) -> void:
	_sync_player(state.player)
	_sync_entities(state.enemies, _enemy_pool, "enemy")
	_sync_entities(state.projectiles, _projectile_pool, "projectile")
	_sync_entities(state.zones, _zone_pool, "zone")
	_sync_entities(state.gems, _gem_pool, "gem")
	_sync_entities(state.pickups, _pickup_pool, "pickup")


func _sync_player(player: PlayerState) -> void:
	_player_sprite.position = player.pos
	_player_sprite.flip_h = player.facing.x < 0.0


func _sync_entities(entities: Array, pool: Array[Sprite2D], type: String) -> void:
	for sprite in pool:
		sprite.visible = false
	while pool.size() < entities.size():
		pool.append(_create_sprite())
	for i in entities.size():
		var sprite := pool[i]
		sprite.position = entities[i].pos
		sprite.visible = true
		_apply_visual(sprite, entities[i], type)


func _apply_visual(sprite: Sprite2D, entity, type: String) -> void:
	match type:
		"enemy":
			sprite.texture = _enemy_texture(entity)
		"projectile":
			sprite.texture = _tex_projectile
		"zone":
			sprite.texture = _tex_zone
		"gem":
			sprite.texture = _tex_gems[clampi(entity.tier, 0, _tex_gems.size() - 1)]
		"pickup":
			sprite.texture = _tex_pickup


## Enemy texture by role: the Reaper, then generic bosses, then rank-and-file.
func _enemy_texture(entity) -> Texture2D:
	if entity.def != null and entity.def.id == "reaper":
		return _tex_reaper
	if entity.is_boss:
		return _tex_boss
	return _tex_enemy
