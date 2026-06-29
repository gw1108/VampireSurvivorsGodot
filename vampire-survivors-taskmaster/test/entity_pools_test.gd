extends SceneTree

## Headless test runner for the Task 2 entity pools.
##   godot --headless --path . --script res://test/entity_pools_test.gd
## Exit code == number of failed checks (0 == all passed).

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== entity_pools_test ==")
	_test_enemy_pool()
	_test_enemy_pool_capacity()
	_test_projectile_pool()
	_test_pickup_pool()
	_test_floating_text_pool()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_enemy_pool() -> void:
	var p := EnemyPool.new()
	_check(p.free_list.size() == EnemyPool.CAPACITY, "enemy free_list starts full (512)")
	_check(p.active_count == 0, "enemy active_count starts 0")
	_check(not p.alive[0] and not p.alive[511], "all slots start dead")

	var def := { hp = 10.0, power = 10.0, move_speed = 100.0, knockback_resist = 0.8, xp = 1.0, ai = "homing" }
	var a := p.spawn(&"zombie", Vector2(5, 7), def)
	var b := p.spawn(&"zombie", Vector2(1, 1), def)
	var c := p.spawn(&"zombie", Vector2(2, 2), def)
	_check(a == 0 and b == 1 and c == 2, "slots allocate in ascending index order (0,1,2)")
	_check(p.active_count == 3, "active_count == 3 after 3 spawns")
	_check(p.free_list.size() == EnemyPool.CAPACITY - 3, "free_list shrank by 3")
	# fields initialized from def
	_check(p.pos[a] == Vector2(5, 7), "spawn sets pos")
	_check(p.hp[a] == 10.0 and p.max_hp[a] == 10.0, "spawn sets hp/max_hp")
	_check(p.power[a] == 10.0 and p.move_speed[a] == 100.0, "spawn sets power/move_speed")
	# knockback_resist 0.8 is stored as 32-bit float -> compare approximately
	_check(is_equal_approx(p.knockback_resist[a], 0.8) and p.xp_value[a] == 1.0, "spawn sets knockback_resist/xp")
	_check(p.type_id[a] == &"zombie", "spawn sets type_id")
	_check(p.ai_kind[a] == EnemyPool.Ai.HOMING, "homing -> Ai.HOMING")
	_check(p.is_boss[a] == false, "is_boss defaults false")
	_check(p.vel[a] == Vector2.ZERO and p.knockback_timer[a] == 0.0 and p.hit_flash[a] == 0.0, "transient fields zeroed")
	_check(p.alive[a], "spawned slot is alive")

	# ai mapping + boss flag from def
	var boss := p.spawn(&"giant_mummy", Vector2.ZERO, { hp = 250.0, ai = "fixed", is_boss = true })
	_check(p.ai_kind[boss] == EnemyPool.Ai.FIXED, "fixed -> Ai.FIXED")
	_check(p.is_boss[boss] == true, "is_boss true from def")

	# despawn + reuse (free-list LIFO)
	p.despawn(b)
	_check(not p.alive[b], "despawned slot is dead")
	_check(p.active_count == 3, "active_count drops to 3 after one despawn (was 4)")
	var reused := p.spawn(&"zombie", Vector2.ZERO, def)
	_check(reused == b, "freed slot is reused (LIFO)")
	# double despawn is a no-op
	var before := p.active_count
	p.despawn(b)
	p.despawn(b)
	_check(p.active_count == before - 1, "double despawn only decrements once")

	# clear_all resets everything
	p.clear_all()
	_check(p.active_count == 0, "clear_all resets active_count")
	_check(p.free_list.size() == EnemyPool.CAPACITY, "clear_all refills free_list")
	_check(not p.alive[0] and not p.alive[2], "clear_all marks slots dead")

func _test_enemy_pool_capacity() -> void:
	var p := EnemyPool.new()
	var def := { hp = 1.0 }
	for i in EnemyPool.CAPACITY:
		_check_silent(p.spawn(&"zombie", Vector2.ZERO, def) == i)
	_check(not _silent_fail, "all CAPACITY spawns returned ascending indices")
	_check(p.is_full(), "pool reports full at capacity")
	_check(p.active_count == EnemyPool.CAPACITY, "active_count == CAPACITY when full")
	_check(p.spawn(&"zombie", Vector2.ZERO, def) == -1, "spawn returns -1 when full")

var _silent_fail := false
func _check_silent(cond: bool) -> void:
	if not cond:
		_silent_fail = true

func _test_projectile_pool() -> void:
	var p := ProjectilePool.new()
	_check(p.recent_hits.size() == ProjectilePool.CAPACITY, "recent_hits sized to capacity")
	_check(p.recent_hits[0] is Dictionary, "recent_hits slots are real dicts, not null")
	var idx := p.spawn(Vector2(1, 0), Vector2(100, 0), {
		damage = 12.5, pierce = 3, lifetime = 2.0, area_scale = 1.5,
		behavior = ProjectilePool.Behavior.BOUNCE, owner_weapon = &"runetracer",
		type_id = &"rune", crit_chance = 0.1, crit_mult = 2.0, hit_cooldown = 0.25,
	})
	_check(idx == 0, "first projectile at slot 0")
	_check(p.damage[idx] == 12.5 and p.pierce_left[idx] == 3, "spawn sets damage/pierce")
	_check(p.behavior[idx] == ProjectilePool.Behavior.BOUNCE, "spawn sets behavior")
	_check(p.owner_weapon[idx] == &"runetracer", "spawn sets owner_weapon")
	_check(p.area_scale[idx] == 1.5 and p.hit_cooldown[idx] == 0.25, "spawn sets area_scale/hit_cooldown")
	# defaults when params omitted
	var d := p.spawn(Vector2.ZERO, Vector2.ZERO, {})
	_check(p.pierce_left[d] == 1 and p.area_scale[d] == 1.0 and p.crit_mult[d] == 1.0, "params default sensibly")
	# recent_hits is cleared on (re)spawn
	p.recent_hits[idx][5] = 0.5
	p.despawn(idx)
	var reused := p.spawn(Vector2.ZERO, Vector2.ZERO, {})
	_check(reused == idx, "freed projectile slot reused")
	_check(p.recent_hits[reused].is_empty(), "recent_hits cleared on respawn")
	_check(p.active_count == 2, "projectile active_count tracks correctly")

func _test_pickup_pool() -> void:
	var p := PickupPool.new()
	_check(p.gem_count == 0, "gem_count starts 0")
	var g1 := p.spawn(PickupPool.Kind.GEM, Vector2(1, 1), 2.0, PickupPool.GemTier.BLUE)
	var g2 := p.spawn(PickupPool.Kind.GEM, Vector2(2, 2), 5.0, PickupPool.GemTier.GREEN)
	var gold := p.spawn(PickupPool.Kind.GOLD, Vector2(3, 3), 10.0)
	_check(p.gem_count == 2, "gem_count counts only GEM kind")
	_check(p.active_count == 3, "pickup active_count counts all kinds")
	_check(p.kind[gold] == PickupPool.Kind.GOLD and p.value[gold] == 10.0, "non-gem stored with value")
	_check(p.gem_tier[g2] == PickupPool.GemTier.GREEN, "gem tier stored")
	_check(not p.magnetized[g1], "magnetized defaults false")
	p.despawn(g1)
	_check(p.gem_count == 1, "despawning a gem decrements gem_count")
	p.despawn(gold)
	_check(p.gem_count == 1, "despawning a non-gem does not touch gem_count")
	p.clear_all()
	_check(p.gem_count == 0 and p.active_count == 0, "clear_all resets gem_count + active_count")

func _test_floating_text_pool() -> void:
	var p := FloatingTextPool.new()
	var idx := p.spawn(Vector2(4, 4), Vector2(0, -20), "123", 0.8)
	_check(idx == 0, "first floater at slot 0")
	# ttl 0.8 is stored as 32-bit float -> compare approximately
	_check(p.text[idx] == "123" and is_equal_approx(p.ttl[idx], 0.8), "spawn stores text/ttl")
	_check(p.vel[idx] == Vector2(0, -20), "spawn stores velocity")
	_check(p.active_count == 1, "floater active_count == 1")
	p.despawn(idx)
	_check(p.active_count == 0 and not p.alive[idx], "floater despawn works")
