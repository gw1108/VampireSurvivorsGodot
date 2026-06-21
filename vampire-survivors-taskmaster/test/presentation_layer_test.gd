extends GdUnitTestSuite

## Tests PresentationLayer pooling + sync: pools are pre-seeded, sync shows exactly
## one sprite per live entity (at its position) and hides the rest, pools grow past
## the initial size on demand, the player sprite follows + flips by facing, gems are
## tinted by tier, and a def-less enemy does not crash the renderer.

func _layer() -> PresentationLayer:
	var p: PresentationLayer = PresentationLayer.new()
	add_child(p)  # triggers _ready -> pools + player sprite
	return auto_free(p)


func _enemy(pos: Vector2, boss := false) -> Enemy:
	var e := Enemy.new()
	e.pos = pos
	e.is_boss = boss
	return e


func _gem(pos: Vector2, tier: int) -> Gem:
	var g := Gem.new()
	g.pos = pos
	g.tier = tier
	return g


func _visible_count(pool: Array) -> int:
	var n := 0
	for s in pool:
		if s.visible:
			n += 1
	return n


func test_pools_initialized_on_ready() -> void:
	var p := _layer()
	assert_int(p._enemy_pool.size()).is_equal(PresentationLayer.POOL_INITIAL_SIZE)
	assert_int(p._projectile_pool.size()).is_equal(PresentationLayer.POOL_INITIAL_SIZE)
	assert_int(p._gem_pool.size()).is_equal(PresentationLayer.POOL_INITIAL_SIZE)
	assert_object(p._player_sprite).is_not_null()


func test_sync_shows_one_sprite_per_enemy() -> void:
	var p := _layer()
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2(10, 20)), _enemy(Vector2(30, 40)), _enemy(Vector2(50, 60))]
	p.sync(gs)
	assert_int(_visible_count(p._enemy_pool)).is_equal(3)
	assert_vector(p._enemy_pool[0].position).is_equal(Vector2(10, 20))
	assert_vector(p._enemy_pool[2].position).is_equal(Vector2(50, 60))


func test_sync_hides_sprites_when_entities_decrease() -> void:
	var p := _layer()
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2.ZERO), _enemy(Vector2.ONE), _enemy(Vector2(2, 2))]
	p.sync(gs)
	gs.enemies = [_enemy(Vector2.ZERO)]
	p.sync(gs)
	assert_int(_visible_count(p._enemy_pool)).is_equal(1)


func test_pool_expands_beyond_initial_size() -> void:
	var p := _layer()
	var gs := GameState.new()
	var n := PresentationLayer.POOL_INITIAL_SIZE + 5
	for i in n:
		gs.enemies.append(_enemy(Vector2(i, 0)))
	p.sync(gs)
	assert_int(p._enemy_pool.size()).is_greater_equal(n)
	assert_int(_visible_count(p._enemy_pool)).is_equal(n)


func test_player_sprite_follows_and_flips() -> void:
	var p := _layer()
	var gs := GameState.new()
	gs.player.pos = Vector2(100, 50)
	gs.player.facing = Vector2.LEFT
	p.sync(gs)
	assert_vector(p._player_sprite.position).is_equal(Vector2(100, 50))
	assert_bool(p._player_sprite.flip_h).is_true()
	gs.player.facing = Vector2.RIGHT
	p.sync(gs)
	assert_bool(p._player_sprite.flip_h).is_false()


func test_gems_textured_by_tier() -> void:
	var p := _layer()
	var gs := GameState.new()
	gs.gems = [_gem(Vector2.ZERO, Gem.Tier.BLUE), _gem(Vector2.ONE, Gem.Tier.GREEN), _gem(Vector2(2, 2), Gem.Tier.RED)]
	p.sync(gs)
	assert_object(p._gem_pool[0].texture).is_equal(p._tex_gems[Gem.Tier.BLUE])
	assert_object(p._gem_pool[1].texture).is_equal(p._tex_gems[Gem.Tier.GREEN])
	assert_object(p._gem_pool[2].texture).is_equal(p._tex_gems[Gem.Tier.RED])


func test_boss_texture_differs_from_normal_enemy() -> void:
	var p := _layer()
	var gs := GameState.new()
	gs.enemies = [_enemy(Vector2.ZERO, false), _enemy(Vector2.ONE, true)]
	p.sync(gs)
	assert_object(p._enemy_pool[0].texture).is_equal(p._tex_enemy)
	assert_object(p._enemy_pool[1].texture).is_equal(p._tex_boss)


func test_placeholder_textures_loaded() -> void:
	var p := _layer()
	# Real placeholder art is present, so textures must not be the icon fallback.
	assert_object(p._tex_player).is_not_equal(PresentationLayer.FALLBACK)
	assert_object(p._tex_enemy).is_not_equal(PresentationLayer.FALLBACK)
	assert_object(p._tex_gems[Gem.Tier.RED]).is_not_equal(PresentationLayer.FALLBACK)
	assert_object(p._player_sprite.texture).is_equal(p._tex_player)


func test_reaper_uses_distinct_texture() -> void:
	var p := _layer()
	var gs := GameState.new()
	var e := Enemy.new()
	var d := EnemyDef.new()
	d.id = "reaper"
	e.def = d
	e.is_boss = true
	gs.enemies = [e]
	p.sync(gs)
	assert_object(p._enemy_pool[0].texture).is_equal(p._tex_reaper)


func test_null_def_enemy_does_not_crash() -> void:
	var p := _layer()
	var gs := GameState.new()
	var e := Enemy.new()
	e.def = null
	gs.enemies = [e]
	p.sync(gs)
	assert_int(_visible_count(p._enemy_pool)).is_equal(1)
