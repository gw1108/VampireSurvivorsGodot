class_name PresentationLayer extends Node2D

## Pure view: mirrors GameState entity arrays onto pooled Sprite2D nodes each
## frame. Owns one sprite pool per category (reused, never freed during a run) so
## there are no per-frame allocations. sync(state) hides every pooled sprite, then
## positions+shows one per live entity, growing a pool on demand.
##
## Corrections vs the task sketch (kept consistent with this codebase):
##  - EnemyDef has no `texture` field, so `entity.def.texture` is a runtime error.
##    Per the task ("placeholder textures initially") all sprites share one
##    placeholder texture and are tinted per category / gem tier instead.

const POOL_INITIAL_SIZE: int = 100
const PLACEHOLDER: Texture2D = preload("res://icon.svg")

# Placeholder category tints (until real art lands).
const PLAYER_COLOR := Color.WHITE
const ENEMY_COLOR := Color(1.0, 0.4, 0.4)
const BOSS_COLOR := Color(0.8, 0.2, 0.8)
const PROJECTILE_COLOR := Color(1.0, 1.0, 0.3)
const ZONE_COLOR := Color(1.0, 0.6, 0.2, 0.4)
const PICKUP_COLOR := Color(0.4, 1.0, 0.4)
const GEM_COLORS := [Color.CYAN, Color.GREEN, Color.RED]  # Gem.Tier BLUE/GREEN/RED

var _enemy_pool: Array[Sprite2D] = []
var _projectile_pool: Array[Sprite2D] = []
var _zone_pool: Array[Sprite2D] = []
var _gem_pool: Array[Sprite2D] = []
var _pickup_pool: Array[Sprite2D] = []
var _player_sprite: Sprite2D = null


func _ready() -> void:
	_init_pools()
	_create_player_sprite()


func _init_pools() -> void:
	for i in POOL_INITIAL_SIZE:
		_enemy_pool.append(_create_sprite())
		_projectile_pool.append(_create_sprite())
		_gem_pool.append(_create_sprite())


func _create_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = PLACEHOLDER
	sprite.visible = false
	add_child(sprite)
	return sprite


func _create_player_sprite() -> void:
	_player_sprite = _create_sprite()
	_player_sprite.modulate = PLAYER_COLOR
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
	sprite.texture = PLACEHOLDER
	match type:
		"enemy":
			sprite.modulate = BOSS_COLOR if entity.is_boss else ENEMY_COLOR
		"projectile":
			sprite.modulate = PROJECTILE_COLOR
		"zone":
			sprite.modulate = ZONE_COLOR
		"gem":
			sprite.modulate = GEM_COLORS[clampi(entity.tier, 0, GEM_COLORS.size() - 1)]
		"pickup":
			sprite.modulate = PICKUP_COLOR
