class_name VSPlayer
extends Node2D
## The player avatar. Move-only (WASD/arrows); the weapon auto-fires. Manual movement +
## distance math (no physics bodies) keeps the slice robust. Pixel-art sprite (Antonio).

signal died
signal damaged(amount: float)

## Base move speed lives in res://data/balance.csv (id "player_move_speed") so a designer
## can retune it without touching this script.
static var SPEED := BalanceData.get_value("player_move_speed", 210.0)
## Tuned baseline contact radius (the value the game was balanced against, at player_scale 1.0).
## The live hitbox is the instance `radius` below, which scales with the CSV's player_scale so the
## solid body tracks the art. Kept as a const so callers without the player instance can still read
## the baseline (VSPlayer.RADIUS), exactly as VSEnemy.RADIUS is the enemy's fallback.
const RADIUS := 14.0

## Hit feedback: on taking damage the avatar flashes red for a sliver of a second so a hit
## reads on the character itself, not just as a camera jolt — the same channel the enemies use
## for their white hit-flash, tuned red here to say "you're being hurt" at a glance.
const HIT_FLASH_DURATION := 0.12
const HIT_FLASH_COLOR := Color(1.7, 0.35, 0.35)

## Invulnerability frames: after a landed hit the player ignores all further contact damage
## for a brief window (GDD "Damage, Crit, Knockback, I-Frames": base 240 ms). This is what
## lets you tank *through* a crowd — without it, every enemy overlapping you the same instant
## lands its hit independently (each enemy has its own contact cooldown), stacking damage and
## deleting the player unfairly the moment the horde closes in. Ticks only while playing.
const IFRAME_DURATION := 0.24

## Nduja Fritta Tanta berserk: while VSRun.is_nduja_active() the avatar takes no contact damage
## and a burning aura sears every enemy within NDUJA_RADIUS, dealing NDUJA_DAMAGE on each
## NDUJA_TICK so charging through the horde melts it. The buff itself lives on the run clock
## (VSNduja pickup sets run.nduja_until); the player just reads it each frame.
const NDUJA_RADIUS := 78.0
const NDUJA_DAMAGE := 9.0
const NDUJA_TICK := 0.2
const NDUJA_TINT := Color(1.6, 0.6, 0.25)   # hot orange the sprite pulses toward while ablaze

## Health bar drawn right under the sprite, replacing the old HUD corner "HP N/N" text so the
## player's vitals read at a glance on the avatar itself. Mirrors VSEnemy's mini-boss bar look
## (dark track + red fill) but stays visible at every health level, not just once damaged.
const HEALTH_BAR_HEIGHT := 3.0
const HEALTH_BAR_OFFSET_Y := 28.0   # clears the sprite's visible feet (art is 44px tall)
const HEALTH_BAR_BG_COLOR := Color(0, 0, 0, 0.7)
const HEALTH_BAR_FILL_COLOR := Color(0.85, 0.15, 0.15)
# Once HP drops below this fraction the fill throbs toward the hot alarm red, in lockstep with the
# HUD's low-health vignette. Mirrors hud.gd's LOWHP_THRESHOLD so both danger cues arm together.
const LOWHP_THRESHOLD := 0.30
const HEALTH_BAR_ALARM_COLOR := Color(1.0, 0.3, 0.12)   # hot red the fill throbs toward while critical
# Recovery (Pummarola): while HP regenerates and isn't yet full, the fill breathes faintly toward this
# green so the top-up reads at a glance. Kept quiet (shallow blend, slow beat) and gated above the alarm
# threshold so it never fights the low-HP danger throb for attention.
const HEALTH_BAR_HEAL_COLOR := Color(0.3, 0.9, 0.35)

## Living-avatar motion: a brisk two-step bounce while walking and a slow breathe when standing.
## Both are a couple of pixels of vertical offset on the sprite alone (position untouched), driven
## off the run's own `elapsed` clock so they pause cleanly with the game during level-up.
const WALK_BOB_FREQ := 9.0     # rad/s-ish; a bounce per footfall
const WALK_BOB_AMP := 2.0      # px, sprite rises on each step
const IDLE_SWAY_FREQ := 2.2
const IDLE_SWAY_AMP := 1.2

var max_health := 100.0
var health := 100.0
var alive := true
## Live contact radius, set in _ready to RADIUS * player_scale so the solid body tracks the sprite a
## designer sizes via the CSV. Enemy contact tests this (enemy.gd), so growing/shrinking the art in
## balance.csv grows/shrinks the hitbox by the same factor. Defaults to the tuned RADIUS baseline.
var radius := RADIUS
## Debug god-mode: when set, take_damage ignores all incoming contact damage so the agent
## harness can survive a swarm long enough to observe late-game visuals (crits, VFX, evolutions).
## Only ever set via the agent gate's force_invulnerable command — inert in real builds.
var invulnerable := false

var _sprite: Sprite2D
## Persistent horizontal facing (+1 right, -1 left), driven by move input and mirroring the
## whip/knife convention so the character visibly faces the way it moves (and the way those
## weapons fire). The art faces right by default, so flip_h is set when facing left.
var _facing := 1
## Latched movement heading (unit vector) — the last non-zero direction the player moved, kept
## through idle frames so it reads as "the way we're fleeing." Enemy recycling reads this to bias
## outrun stragglers back in *front* of the player, so a kite keeps running into fresh pressure.
var move_dir := Vector2.RIGHT
## Remaining hit-flash time (s), counting down in _process; set by take_damage.
var _flash_time := 0.0
## Remaining invulnerability time (s), armed by a landed hit and counted down each playing
## frame; while > 0 take_damage is a no-op so overlapping enemies can't stack simultaneous hits.
var _iframe_time := 0.0
## True while a Nduja buff is wreathing the avatar in flame, so the fiery tint + aura ring can be
## cleared exactly once when it lapses. Paired with _nduja_tick_accum, the burn-cadence timer.
var _nduja_glow := false
var _nduja_tick_accum := 0.0
## Free-running heartbeat clock (seconds) driving the HP bar's low-health throb. Advanced every
## alive frame — including the level-up freeze — exactly as hud.gd advances its own _lowhp_pulse,
## so the bar's beat stays in phase with the vignette's without the two nodes having to share state.
var _lowhp_pulse := 0.0

func _ready() -> void:
	add_to_group("player")
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/player.png")
	# Avatar size knob a designer can retune in res://data/balance.csv. Scales the sprite child (not
	# the player node, so the HP bar, mounted weapons, and camera stay put) AND the contact hitbox by
	# the same factor, so the solid body stays matched to the art. At the default 1.0 the radius is
	# exactly the tuned RADIUS baseline — this only moves the hitbox when the CSV row is edited.
	var avatar_scale := BalanceData.get_value("player_scale", 1.0)
	_sprite.scale = Vector2.ONE * avatar_scale
	radius = RADIUS * avatar_scale
	add_child(_sprite)

func _process(delta: float) -> void:
	if not alive:
		return
	# Health can change from several places (contact damage, food pickups, chicken heals,
	# Vitality upgrades), so just redraw the bar every live frame rather than threading a
	# queue_redraw() call through each of them.
	queue_redraw()
	_lowhp_pulse += delta   # heartbeat clock for the HP-bar throb; free-runs like hud's, even on freeze
	_update_hit_flash(delta)
	var run := get_parent() as VSRun
	if run and run.phase != "playing":
		return                       # freeze while the level-up screen is up
	# Bleed off invulnerability only during live play, matching the enemy contact clocks that
	# also halt on freeze, so a paused/level-up screen never silently burns the i-frame window.
	if _iframe_time > 0.0:
		_iframe_time = maxf(0.0, _iframe_time - delta)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Face the way we move: latch facing off the horizontal axis (unchanged on pure-vertical
	# movement, so the avatar keeps its last heading) and mirror the sprite accordingly.
	if absf(dir.x) > 0.01:
		_facing = 1 if dir.x > 0.0 else -1
	# Latch the heading while actually moving so it survives idle frames as the flee direction.
	if dir.length_squared() > 0.0001:
		move_dir = dir.normalized()
	if _sprite:
		_sprite.flip_h = _facing < 0
		_update_bob(dir, run.elapsed if run else 0.0)
	var speed_mult := run.player_speed_mult if run else 1.0
	position += dir * SPEED * speed_mult * delta
	if run:
		position.x = clampf(position.x, -run.arena_half.x, run.arena_half.x)
		position.y = clampf(position.y, -run.arena_half.y, run.arena_half.y)
	_update_nduja(run, delta)

## Nduja Fritta Tanta: while the berserk buff is live, burn every enemy in NDUJA_RADIUS on a tick
## and pulse the sprite toward a hot orange (the invincibility itself is enforced in take_damage).
## When the window lapses, clear the tint + aura ring once so the avatar returns to normal.
func _update_nduja(run: VSRun, delta: float) -> void:
	if run and run.is_nduja_active():
		_nduja_glow = true
		_nduja_tick_accum += delta
		while _nduja_tick_accum >= NDUJA_TICK:
			_nduja_tick_accum -= NDUJA_TICK
			_burn_nearby()
		if _sprite:
			var pulse := 0.5 + 0.5 * sin(run.elapsed * 12.0)
			_sprite.modulate = Color(1, 1, 1).lerp(NDUJA_TINT, 0.5 + 0.5 * pulse)
		queue_redraw()
	elif _nduja_glow:
		_nduja_glow = false
		_nduja_tick_accum = 0.0
		if _sprite and _flash_time <= 0.0:
			_sprite.modulate = Color(1, 1, 1)
		queue_redraw()

## Sear every enemy overlapping the fiery aura this tick. Routes through VSEnemy.hit so burned
## enemies flash, take knockback, and die/pay out exactly like any weapon kill.
func _burn_nearby() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is VSEnemy:
			if position.distance_to(e.position) <= NDUJA_RADIUS + e.radius:
				e.hit(NDUJA_DAMAGE, position)

## Draw the health bar (always) and the translucent flame ring while the Nduja aura is up.
func _draw() -> void:
	_draw_health_bar()
	if not _nduja_glow:
		return
	draw_circle(Vector2.ZERO, NDUJA_RADIUS, Color(1.0, 0.45, 0.12, 0.16))
	draw_arc(Vector2.ZERO, NDUJA_RADIUS, 0.0, TAU, 48, Color(1.0, 0.62, 0.2, 0.55), 2.0)

## Draw the player's HP as a small red bar right under the sprite. Local-space draw, so it
## rides along with the avatar automatically; unlike VSEnemy's version this one never hides,
## since it's now the player's only HP readout (the HUD corner text used to own that job).
func _draw_health_bar() -> void:
	if not alive or max_health <= 0.0:
		return
	var frac := clampf(health / max_health, 0.0, 1.0)
	var w := RADIUS * 2.0
	var bg := Rect2(-w * 0.5, HEALTH_BAR_OFFSET_Y, w, HEALTH_BAR_HEIGHT)
	draw_rect(bg, HEALTH_BAR_BG_COLOR)
	# Below LOWHP_THRESHOLD the fill throbs toward the hot alarm red on the same quickening heartbeat
	# as the HUD vignette (identical beat formula + a synced clock), so bar and vignette pulse as one.
	var fill := HEALTH_BAR_FILL_COLOR
	if frac < LOWHP_THRESHOLD:
		var depth := clampf((LOWHP_THRESHOLD - frac) / LOWHP_THRESHOLD, 0.0, 1.0)
		var beat := 0.55 + 0.45 * (0.5 + 0.5 * sin(_lowhp_pulse * (3.5 + 4.0 * depth)))
		fill = HEALTH_BAR_FILL_COLOR.lerp(HEALTH_BAR_ALARM_COLOR, clampf(depth * beat, 0.0, 1.0))
	else:
		# Recovery cue: only above the alarm threshold so it never competes with the low-HP throb.
		# A slow, shallow green breathe (blend capped low) that quietly signals HP is ticking back up.
		var run := get_parent() as VSRun
		if run and run.recovery > 0.0 and health < max_health:
			var heal_beat := 0.5 + 0.5 * sin(_lowhp_pulse * 2.2)
			fill = HEALTH_BAR_FILL_COLOR.lerp(HEALTH_BAR_HEAL_COLOR, 0.28 * heal_beat)
	draw_rect(Rect2(bg.position, Vector2(w * frac, HEALTH_BAR_HEIGHT)), fill)

## Nudge the sprite up and down to sell life: a footfall bounce when a move key is held, a slow
## breathe when idle. `-absf(sin)` keeps the walk cycle lifting off the ground (up is -y) rather
## than sinking below it; the idle sway is a plain gentle oscillation around rest.
func _update_bob(dir: Vector2, elapsed: float) -> void:
	if dir.length_squared() > 0.0001:
		_sprite.position.y = -absf(sin(elapsed * WALK_BOB_FREQ)) * WALK_BOB_AMP
	else:
		_sprite.position.y = sin(elapsed * IDLE_SWAY_FREQ) * IDLE_SWAY_AMP

## Decay the hit-flash and lerp the sprite from red back to its normal tint. No-op once spent;
## the death grey-out (set in take_damage, with _process returning early while dead) is untouched.
func _update_hit_flash(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time = maxf(0.0, _flash_time - delta)
	if _sprite:
		var f := _flash_time / HIT_FLASH_DURATION
		_sprite.modulate = Color(1, 1, 1).lerp(HIT_FLASH_COLOR, f)

func take_damage(amount: float) -> void:
	if not alive:
		return
	# Debug god-mode (agent gate only): swallow the hit entirely so the harness can outlast a swarm.
	if invulnerable:
		return
	# Invulnerability window: while a prior hit's i-frames are still up, ignore the hit entirely.
	# This is the shared window VS uses so a wall of enemies overlapping you deals ONE hit, not one
	# per body — the per-enemy contact cooldowns alone can't provide it.
	if _iframe_time > 0.0:
		return
	var run := get_parent() as VSRun
	# Nduja Fritta Tanta: while the fiery berserk buff burns, the player is untouchable — charge
	# straight through the horde taking no contact damage while the aura sears it (see _update_nduja).
	if run and run.is_nduja_active():
		return
	# Armor passive subtracts flat damage, but at least 1 always gets through so armor can
	# never make the player invulnerable (faithful to VS: chip damage still lands).
	if run and run.armor > 0:
		amount = maxf(1.0, amount - float(run.armor))
	health -= amount
	_iframe_time = IFRAME_DURATION
	_flash_time = HIT_FLASH_DURATION
	AgentBridge.emit_event("damage", {"amount": amount, "to": health})
	damaged.emit(amount)
	if health <= 0.0:
		health = 0.0
		alive = false
		if _sprite:
			_sprite.modulate = Color(0.45, 0.45, 0.45)   # greyed-out on death
		died.emit()
