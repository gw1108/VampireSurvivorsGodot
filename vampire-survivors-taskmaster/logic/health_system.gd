class_name HealthSystem extends RefCounted

## Player survival each tick: i-frame countdown, passive recovery, enemy contact
## damage (armor-mitigated, one enemy per contact), and death -> revive/game-over.
## Pure. Reads state.index for the contact broadphase (caller rebuilds it first).
##
## Corrections vs the task sketch (kept consistent with this codebase):
##  - query_radius returns *combined* indices (enemies+gems+pickups); we filter to
##    Type.ENEMY and map back via get_entity_local_id. The sketch indexed
##    state.enemies directly with a combined index — wrong slot / out of range when
##    a gem or pickup sits inside the player's hitbox.
##  - guard enemy.def == null so a def-less enemy deals no phantom contact damage
##    (apply_armor's min-1 floor would otherwise hit for 1 with no source).

const IFRAME_DURATION: float = 0.24  # 240ms invulnerability after a hit
const REVIVE_IFRAME_DURATION: float = 1.0  # burst i-frames on revival
const PLAYER_HITBOX: float = 16.0


static func step(state: GameState, dt: float) -> void:
	var player: PlayerState = state.player

	# Tick i-frame timer down toward zero.
	if player.iframe_timer > 0.0:
		player.iframe_timer -= dt

	# Passive recovery (HP/sec), never above max.
	var recovery: float = player.derived.recovery
	if recovery > 0.0 and player.hp < player.derived.max_health:
		player.hp = minf(player.hp + recovery * dt, player.derived.max_health)

	# Contact damage only when not invulnerable.
	if player.iframe_timer <= 0.0:
		_check_contact_damage(state)

	# Death -> revive if any revivals left, else game over.
	if player.hp <= 0.0:
		_on_death(state)


static func _check_contact_damage(state: GameState) -> void:
	var player: PlayerState = state.player
	if state.index == null:
		return
	var nearby := SpatialIndex.query_radius(state.index, player.pos, PLAYER_HITBOX)
	for entry in nearby:
		if SpatialIndex.get_entity_type(state.index, entry) != SpatialIndex.Type.ENEMY:
			continue
		var enemy = state.enemies[SpatialIndex.get_entity_local_id(state.index, entry)]
		if enemy.def == null:
			continue  # no source -> no phantom damage
		var raw_damage: float = enemy.def.power
		var damage := CombatMath.apply_armor(raw_damage, player.derived.armor)
		player.hp -= damage
		player.iframe_timer = IFRAME_DURATION
		break  # only one enemy deals contact damage per hit


static func _on_death(state: GameState) -> void:
	var player: PlayerState = state.player
	if player.revivals > 0:
		player.revivals -= 1
		player.hp = player.derived.max_health * 0.5
		player.iframe_timer = REVIVE_IFRAME_DURATION
	else:
		state.phase = GameState.Phase.GAME_OVER
