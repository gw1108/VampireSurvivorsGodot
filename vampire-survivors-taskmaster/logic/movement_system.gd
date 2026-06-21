class_name MovementSystem extends RefCounted

## Pure movement: advances the player and every enemy for one tick. Frame-rate
## independent (everything scales by `dt`). No scene-tree access.

const BASE_PLAYER_SPEED: float = 100.0  # pixels/sec at move_speed = 1.0
const INPUT_DEADZONE_SQ: float = 0.01
const FLOAT_FREQ: float = 3.0  # rad/sec of the floaty vertical bob
const FLOAT_AMP: float = 20.0  # px/sec peak speed of the bob


## Advance the player from an input direction. `facing` keeps the last nonzero
## move direction; velocity is zero when there is no meaningful input.
static func step_player(player: PlayerState, input_dir: Vector2, dt: float) -> void:
	if input_dir.length_squared() > INPUT_DEADZONE_SQ:
		input_dir = input_dir.normalized()
		player.facing = input_dir
		player.velocity = input_dir * (BASE_PLAYER_SPEED * player.derived.move_speed)
	else:
		player.velocity = Vector2.ZERO
	player.pos += player.velocity * dt


## Advance every enemy: tick freeze/knockback timers, else home toward the player
## (or drift in a fixed direction for swarms), with an optional floaty bob.
static func step_enemies(state: GameState, dt: float) -> void:
	var player_pos: Vector2 = state.player.pos
	for enemy in state.enemies:
		if enemy.freeze_timer > 0.0:
			enemy.freeze_timer -= dt
			continue
		if enemy.knockback_timer > 0.0:
			enemy.knockback_timer -= dt
			enemy.pos += enemy.knockback * dt
			continue

		if enemy.fixed_direction:
			# Swarm enemies keep their externally-set velocity.
			enemy.pos += enemy.velocity * dt
		else:
			var to_player: Vector2 = player_pos - enemy.pos
			if to_player.length_squared() > 0.0:
				var speed: float = enemy.def.speed if enemy.def != null else 0.0
				enemy.velocity = to_player.normalized() * speed
				enemy.pos += enemy.velocity * dt
			else:
				enemy.velocity = Vector2.ZERO

		if enemy.floaty:
			enemy.pos.y += sin(state.time_elapsed * FLOAT_FREQ) * FLOAT_AMP * dt
