extends SceneTree

## Headless test runner for the Task 15 ViewSync.
##   godot --headless --path . --script res://test/view_sync_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so the visual nodes have a live tree.

const VS_SCRIPT := preload("res://nodes/view_sync.gd")
const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== view_sync_test ==")
	# one ViewSync, injected layers, shared RunState pools
	var vs = VS_SCRIPT.new()
	root.add_child(vs)
	var layers := {
		enemy = Node2D.new(), projectile = Node2D.new(),
		pickup = Node2D.new(), floater = Node2D.new(),
	}
	for k in layers:
		root.add_child(layers[k])
	var rs := _make_run_state()
	vs.init(rs, GDB, layers)

	_test_pool_creation(vs, layers)
	_test_sync_enemies(vs, rs)
	_test_sync_projectiles(vs, rs)
	_test_sync_pickups(vs, rs)
	_test_sync_floaters(vs, rs)
	_test_sync_all(vs, rs)
	_test_fallback_layer()

	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
	return true

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _make_run_state() -> RunState:
	var rs := RunState.new()
	rs.enemies = EnemyPool.new()
	rs.projectiles = ProjectilePool.new()
	rs.pickups = PickupPool.new()
	rs.floaters = FloatingTextPool.new()
	return rs

func _test_pool_creation(vs, layers: Dictionary) -> void:
	_check(vs.enemy_sprites.size() == EnemyPool.CAPACITY, "enemy sprite pool sized to capacity (512)")
	_check(vs.projectile_sprites.size() == ProjectilePool.CAPACITY, "projectile sprite pool sized to capacity (1024)")
	_check(vs.pickup_sprites.size() == PickupPool.CAPACITY, "pickup sprite pool sized to capacity (512)")
	_check(vs.floater_labels.size() == FloatingTextPool.CAPACITY, "floater label pool sized to capacity (256)")
	_check(vs.enemy_sprites[0] is AnimatedSprite2D, "enemy sprites are AnimatedSprite2D")
	_check(vs.projectile_sprites[0] is Sprite2D, "projectile sprites are Sprite2D")
	_check(vs.floater_labels[0] is Label, "floaters are Labels")
	_check(vs.enemy_sprites[0].visible == false, "sprites start hidden")
	# sprites parented under the injected layers
	_check(layers.enemy.get_child_count() == EnemyPool.CAPACITY, "enemy sprites parented to injected layer")
	_check(vs.enemy_layer == layers.enemy, "injected enemy layer used")

func _test_sync_enemies(vs, rs) -> void:
	var e: EnemyPool = rs.enemies
	var a := e.spawn(&"zombie", Vector2(10, 20), { hp = 10.0 })
	var b := e.spawn(&"zombie", Vector2(30, 40), { hp = 10.0 })
	e.hit_flash[a] = 0.2
	vs.sync_enemies(e)
	_check(vs.enemy_sprites[a].visible and vs.enemy_sprites[a].position == Vector2(10, 20), "alive enemy synced visible at pos")
	_check(vs.enemy_sprites[b].visible and vs.enemy_sprites[b].position == Vector2(30, 40), "second enemy synced")
	_check(vs.enemy_sprites[a].modulate == vs.HIT_FLASH_MODULATE, "hit-flash enemy uses flash modulate")
	_check(vs.enemy_sprites[b].modulate == Color.WHITE, "non-flashing enemy uses white modulate")
	_check(vs.enemy_sprites[2].visible == false, "unused slot stays hidden")
	# despawn and re-sync -> hidden
	e.despawn(a)
	vs.sync_enemies(e)
	_check(vs.enemy_sprites[a].visible == false, "despawned enemy hidden after sync")
	_check(vs.enemy_sprites[b].visible == true, "other enemy still visible")

func _test_sync_projectiles(vs, rs) -> void:
	var p: ProjectilePool = rs.projectiles
	var idx := p.spawn(Vector2(5, 5), Vector2(10, 0), { area_scale = 2.0 })
	vs.sync_projectiles(p)
	_check(vs.projectile_sprites[idx].visible, "projectile visible after sync")
	_check(vs.projectile_sprites[idx].position == Vector2(5, 5), "projectile position synced")
	_check(vs.projectile_sprites[idx].scale == Vector2(2, 2), "projectile scale from area_scale")
	_check(is_equal_approx(vs.projectile_sprites[idx].rotation, 0.0), "projectile rotation from velocity angle")
	p.despawn(idx)
	vs.sync_projectiles(p)
	_check(vs.projectile_sprites[idx].visible == false, "despawned projectile hidden")

func _test_sync_pickups(vs, rs) -> void:
	var p: PickupPool = rs.pickups
	var idx := p.spawn(PickupPool.Kind.GEM, Vector2(7, 8), 2.0, PickupPool.GemTier.BLUE)
	vs.sync_pickups(p)
	_check(vs.pickup_sprites[idx].visible, "pickup visible after sync")
	_check(vs.pickup_sprites[idx].position == Vector2(7, 8), "pickup position synced")
	p.despawn(idx)
	vs.sync_pickups(p)
	_check(vs.pickup_sprites[idx].visible == false, "despawned pickup hidden")

func _test_sync_floaters(vs, rs) -> void:
	var f: FloatingTextPool = rs.floaters
	var idx := f.spawn(Vector2(3, 4), Vector2(0, -10), "99", 0.5)
	vs.sync_floaters(f)
	_check(vs.floater_labels[idx].visible, "floater visible after sync")
	_check(vs.floater_labels[idx].text == "99", "floater text synced")
	_check(vs.floater_labels[idx].position == Vector2(3, 4), "floater position synced")
	f.despawn(idx)
	vs.sync_floaters(f)
	_check(vs.floater_labels[idx].visible == false, "despawned floater hidden")

func _test_sync_all(vs, rs) -> void:
	# clear pools, spawn one of each, sync_all reads run_state directly
	rs.enemies.clear_all()
	rs.projectiles.clear_all()
	rs.pickups.clear_all()
	rs.floaters.clear_all()
	var ei: int = rs.enemies.spawn(&"zombie", Vector2(1, 1), { hp = 10.0 })
	var pi: int = rs.projectiles.spawn(Vector2(2, 2), Vector2.ZERO, {})
	var ki: int = rs.pickups.spawn(PickupPool.Kind.GOLD, Vector2(3, 3), 10.0)
	var fi: int = rs.floaters.spawn(Vector2(4, 4), Vector2.ZERO, "x", 1.0)
	vs.sync_all()
	_check(vs.enemy_sprites[ei].visible, "sync_all syncs enemies")
	_check(vs.projectile_sprites[pi].visible, "sync_all syncs projectiles")
	_check(vs.pickup_sprites[ki].visible, "sync_all syncs pickups")
	_check(vs.floater_labels[fi].visible, "sync_all syncs floaters")

func _test_fallback_layer() -> void:
	# with no injected layers and no parent run scene, layers fall back to
	# children of the ViewSync node so it still works standalone.
	var vs = VS_SCRIPT.new()
	root.add_child(vs)
	var rs := _make_run_state()
	vs.init(rs, GDB)  # no layers
	_check(vs.enemy_layer != null and vs.enemy_layer.get_parent() == vs, "fallback enemy layer is a child of ViewSync")
	_check(vs.enemy_sprites.size() == EnemyPool.CAPACITY, "fallback still creates the sprite pool")
	vs.queue_free()
