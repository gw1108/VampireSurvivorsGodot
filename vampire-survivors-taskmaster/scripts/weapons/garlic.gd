class_name VSGarlic
extends Node2D
## A close-range damaging aura — the classic Vampire Survivors "Garlic": a translucent
## ring around the player that periodically damages every enemy inside it. Unlike the
## projectile weapon it needs no aiming; it rewards wading *through* the swarm. Mounted on
## the player and enabled/scaled by the run's garlic_level (0 = not yet picked: invisible
## and inert). This is the slice's second, mechanically-distinct weapon so level-up
## "weapon choices" become real, not just stat buffs.

const BASE_RADIUS := 74.0
const RADIUS_PER_LEVEL := 20.0
const TICK_INTERVAL := 0.5        # seconds between damage pulses
const FLASH_TIME := 0.18          # aura brightens briefly on each pulse

var run: VSRun
var _cd := 0.0
var _flash := 0.0

func _process(delta: float) -> void:
	if run == null:
		return
	var lvl: int = run.garlic_level
	if lvl <= 0:
		return
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()                # aura follows the player; one node, cheap
	if run.phase != "playing":
		return
	_cd -= delta
	if _cd <= 0.0:
		_pulse(lvl)
		_cd = TICK_INTERVAL
		_flash = FLASH_TIME

## Damage every enemy currently inside the aura. Damage scales with garlic level.
func _pulse(lvl: int) -> void:
	var r := _radius(lvl)
	var dmg := float(lvl)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var er: float = e.radius if "radius" in e else VSEnemy.RADIUS
		if (e.position - global_position).length() < r + er:
			e.hit(dmg, global_position)
			hit_any = true
	if hit_any:
		AgentBridge.emit_event("sfx_played", {"name": "garlic"})

func _radius(lvl: int) -> float:
	return BASE_RADIUS + RADIUS_PER_LEVEL * float(lvl - 1)

func _draw() -> void:
	if run == null or run.garlic_level <= 0:
		return
	var r := _radius(run.garlic_level)
	var pulse := _flash / FLASH_TIME
	var fill := Color(0.6, 0.9, 0.5, 0.08 + 0.10 * pulse)
	var ring := Color(0.7, 1.0, 0.6, 0.45 + 0.35 * pulse)
	draw_circle(Vector2.ZERO, r, fill)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, ring, 2.0 + 1.5 * pulse)
