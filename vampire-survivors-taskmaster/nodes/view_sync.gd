extends Node

## Renders the data pools by syncing fixed pools of dumb visual nodes from the
## data each tick. Owns only the visual node pools the engine requires; carries
## no game logic, mutates no game state. (A MultiMeshInstance2D swap-in for the
## enemy layer would live entirely here.)
##
## Visual pools are sized to each data pool's CAPACITY so slot i always maps to
## visual node i (no silent under-rendering). Per-type visual assets
## (SpriteFrames / textures by type_id / kind) are wired by the art pass; this
## shell only syncs position / visible / scale / rotation / modulate / text.

var run_state: RunState
var game_db

var enemy_sprites: Array[AnimatedSprite2D] = []
var projectile_sprites: Array[Sprite2D] = []
var pickup_sprites: Array[Sprite2D] = []
var floater_labels: Array[Label] = []

var enemy_layer: Node2D
var projectile_layer: Node2D
var pickup_layer: Node2D
var floater_layer: Node2D

const HIT_FLASH_MODULATE := Color(2.0, 2.0, 2.0, 1.0)

## Wire state + db, resolve the four visual layers, and pre-instance the node
## pools. `layers` (optional) injects {enemy, projectile, pickup, floater}
## Node2Ds; any omitted layer is resolved from the parent run scene
## (World/<X>Layer) or, if absent, created as a child of this node so ViewSync
## works standalone and under test.
func init(state: RunState, db, layers: Dictionary = {}) -> void:
	run_state = state
	game_db = db
	enemy_layer = _resolve_layer(layers, "enemy", "World/EnemyLayer")
	projectile_layer = _resolve_layer(layers, "projectile", "World/ProjectileLayer")
	pickup_layer = _resolve_layer(layers, "pickup", "World/PickupLayer")
	floater_layer = _resolve_layer(layers, "floater", "World/FloatingTextLayer")
	_create_enemy_pool(EnemyPool.CAPACITY)
	_create_projectile_pool(ProjectilePool.CAPACITY)
	_create_pickup_pool(PickupPool.CAPACITY)
	_create_floater_pool(FloatingTextPool.CAPACITY)

func _resolve_layer(layers: Dictionary, key: String, scene_path: String) -> Node2D:
	if layers.has(key) and layers[key] is Node2D:
		return layers[key]
	var parent := get_parent()
	if parent:
		var found := parent.get_node_or_null(scene_path)
		if found is Node2D:
			return found
	var layer := Node2D.new()
	layer.name = key.capitalize() + "Layer"
	add_child(layer)
	return layer

func _create_enemy_pool(count: int) -> void:
	for i in count:
		var sprite := AnimatedSprite2D.new()
		sprite.visible = false
		enemy_layer.add_child(sprite)
		enemy_sprites.append(sprite)

func _create_projectile_pool(count: int) -> void:
	for i in count:
		var sprite := Sprite2D.new()
		sprite.visible = false
		projectile_layer.add_child(sprite)
		projectile_sprites.append(sprite)

func _create_pickup_pool(count: int) -> void:
	for i in count:
		var sprite := Sprite2D.new()
		sprite.visible = false
		pickup_layer.add_child(sprite)
		pickup_sprites.append(sprite)

func _create_floater_pool(count: int) -> void:
	for i in count:
		var label := Label.new()
		label.visible = false
		floater_layer.add_child(label)
		floater_labels.append(label)

## Sync every layer from the current RunState pools (the controller's per-tick
## entry point).
func sync_all() -> void:
	if run_state == null:
		return
	sync_enemies(run_state.enemies)
	sync_projectiles(run_state.projectiles)
	sync_pickups(run_state.pickups)
	sync_floaters(run_state.floaters)

func sync_enemies(enemies: EnemyPool) -> void:
	var n := mini(enemy_sprites.size(), EnemyPool.CAPACITY)
	for i in n:
		var sprite := enemy_sprites[i]
		if enemies.alive[i]:
			sprite.position = enemies.pos[i]
			sprite.modulate = HIT_FLASH_MODULATE if enemies.hit_flash[i] > 0.0 else Color.WHITE
			# Swap in the enemy's SpriteFrames (by type) only when it changes, then
			# (re)start the walk loop. null frames (unmapped id) leaves the slot as-is.
			var frames: SpriteFrames = game_db.enemy_sprite_frames(enemies.type_id[i])
			if frames != null and sprite.sprite_frames != frames:
				sprite.sprite_frames = frames
				sprite.play(&"walk")
			sprite.visible = true
		else:
			sprite.visible = false

func sync_projectiles(projectiles: ProjectilePool) -> void:
	var n := mini(projectile_sprites.size(), ProjectilePool.CAPACITY)
	for i in n:
		var sprite := projectile_sprites[i]
		if projectiles.alive[i]:
			sprite.position = projectiles.pos[i]
			sprite.scale = Vector2.ONE * projectiles.area_scale[i]
			if projectiles.vel[i].length_squared() > 0.0:
				sprite.rotation = projectiles.vel[i].angle()
			# Texture by owning weapon; null (unmapped) leaves the slot's last one.
			var tex: Texture2D = game_db.projectile_sprite(projectiles.owner_weapon[i])
			if tex != null and sprite.texture != tex:
				sprite.texture = tex
			sprite.visible = true
		else:
			sprite.visible = false

func sync_pickups(pickups: PickupPool) -> void:
	var n := mini(pickup_sprites.size(), PickupPool.CAPACITY)
	for i in n:
		var sprite := pickup_sprites[i]
		if pickups.alive[i]:
			sprite.position = pickups.pos[i]
			# Texture by pickup kind (+ gem tier); null leaves the slot's last one.
			var tex: Texture2D = game_db.pickup_sprite(_pickup_key(pickups.kind[i], pickups.gem_tier[i]))
			if tex != null and sprite.texture != tex:
				sprite.texture = tex
			sprite.visible = true
		else:
			sprite.visible = false

## Map a PickupPool kind (+ gem tier for gems) to its PICKUP_SPRITES view key.
func _pickup_key(kind: int, gem_tier: int) -> StringName:
	match kind:
		PickupPool.Kind.GEM:
			match gem_tier:
				PickupPool.GemTier.GREEN: return &"gem_green"
				PickupPool.GemTier.RED: return &"gem_red"
				_: return &"gem_blue"
		PickupPool.Kind.GOLD: return &"gold"
		PickupPool.Kind.CHICKEN: return &"chicken"
		PickupPool.Kind.ROSARY: return &"rosary"
		PickupPool.Kind.OROLOGION: return &"orologion"
		PickupPool.Kind.VACUUM: return &"vacuum"
		PickupPool.Kind.NDUJA: return &"nduja"
		PickupPool.Kind.REROLLO: return &"rerollo"
		PickupPool.Kind.CHEST: return &"chest"
	return &""

func sync_floaters(floaters: FloatingTextPool) -> void:
	var n := mini(floater_labels.size(), FloatingTextPool.CAPACITY)
	for i in n:
		var label := floater_labels[i]
		if floaters.alive[i]:
			label.position = floaters.pos[i]
			label.text = floaters.text[i]
			label.visible = true
		else:
			label.visible = false
