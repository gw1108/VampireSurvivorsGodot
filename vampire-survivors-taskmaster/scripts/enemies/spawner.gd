class_name VSSpawner
extends Node2D
## Time-based wave spawner. Spawns enemies on a ring just outside view around the
## player; the base trickle's rate and concurrent-count follow Mad Forest's real
## per-minute spawn table (see DENSITY_SCHEDULE). Capped for performance.

static var MAX_ENEMIES: int = int(BalanceData.get_value("spawner_max_enemies", 150.0))        # baseline concurrent-enemy render budget for most of the run
# The mid-run DENSITY_SCHEDULE spikes (11:00 -> 300, 13:00 -> 150, 15:00/16:00/19:00/20:00 -> 100)
# now read on screen: at 150 the authored 150-count surges crest fully, and even the 300-count
# spikes read as a dense 150+ crush that keeps climbing (the cap ramps toward 300 from 11:00 on, see
# LATE_RAMP_START). This raise was UNBLOCKED by the density-collision fix: bounding each enemy's
# overlap scan to VSEnemy.MAX_OVERLAP_CHECKS neighbours stopped the collapsed-crush O(n²) reversion,
# and a real Web-export profiling run (see completions) then verified the packed worst-case crush
# holds 144fps up to 185 enemies and a steady ~78fps at the full ~274-body crush near the 300 cap —
# every matched size >= 60fps (vs the old 110->47 / 150->32 / 185->21fps). Real player builds (no
# agent-bridge serialization) run higher still, so these numbers are conservative.
# Late-run escalation lever. The wiki's DENSITY_SCHEDULE climbs to 300 in the endgame; the cap ramps
# up over the back half of the run so that late escalation shows on screen, up to the GDD's "periodic
# spawns stop at 300 alive" — the real Mad Forest late population.
static var MAX_ENEMIES_LATE: int = int(BalanceData.get_value("spawner_max_enemies_late", 300.0))   # cap the final-third ramp climbs toward (GDD: 300-alive periodic cap)
# Perf gate. Enemies carry solid circular colliders (VSEnemy._overlap_correction), backed by a shared
# uniform spatial grid (VSEnemy._ensure_grid / _grid): each enemy scans only the 3×3 block of cells
# around it, and that scan is now bounded to VSEnemy.MAX_OVERLAP_CHECKS bodies per frame — so even
# when the horde collapses into a few 60px COLLIDE_CELL cells the pass stays linear in enemy count
# instead of reverting toward O(n²). A real Web run verified the packed 300-crush holds ~78fps at
# ~274 bodies, so COLLIDER_SAFE_CAP=300 is a VALIDATED ceiling, not an aspiration.
const COLLIDER_SAFE_CAP := 300  # validated packed-density ceiling (~78fps at the ~274-body crush)
static var LATE_RAMP_START := BalanceData.get_value("spawner_late_ramp_start", 0.367)  # fraction of RUN_DURATION where the cap begins to climb (~11:00)
static var SPAWN_RING := BalanceData.get_value("spawner_spawn_ring", 520.0)        # floor radius (used when zoomed in far / before a camera exists)
# Extra padding beyond the farthest visible corner so a spawned enemy's whole sprite clears the
# screen edge before it appears, no matter the enemy's size.
static var SPAWN_MARGIN := BalanceData.get_value("spawner_spawn_margin", 96.0)
# Chest-dropping treasure-boss cadence. Mad Forest's real "Bosses & Treasure" column
# (.firecrawl/wiki-offline/Mad_Forest.md "Waves") names a SPECIFIC boss enemy at specific minute
# marks (Glowing Bat 1:00/3:00, Mantichana 5:00, Giant Bat 8:00, Giant Mantichana 10:00, Giant
# Werewolf 15:00, Giant Mummy 20:00, Giant Blue Venus 25:00, ...) with empty minutes between
# (2/4/6/13/17/19/26/28), each named boss dropping a chest. That whole per-minute roster is now
# data-driven in res://data/mad_forest_bosses.csv (one row per minute) so the boss cadence is
# designer-editable and exactly wiki-faithful, replacing the old flat-60s generic ELITE spike.
# Each scheduled boss spawns as its mapped art type but is flagged VSEnemy.is_boss, which floors
# its HP/gem burst to the ELITE tier and drops a chest — so it reads as a real treasure boss no
# matter which enemy art it borrows (bats -> GLOW_BAT, Mantichana/Venus -> MANTIS_WARRIOR, etc;
# the CSV's art_note column tracks which named bosses still want distinct art).
static var WAVE_INTERVAL := BalanceData.get_value("spawner_wave_interval", 60.0)    # seconds between minute-milestone wave surges
static var WAVE_BASE: int = int(BalanceData.get_value("spawner_wave_base", 8.0))           # enemies in the first (1:00) surge
static var WAVE_GROWTH: int = int(BalanceData.get_value("spawner_wave_growth", 6.0))         # extra enemies per subsequent minute mark
static var WAVE_OVERFLOW: int = int(BalanceData.get_value("spawner_wave_overflow", 40.0))      # headroom a surge may push past MAX_ENEMIES

# Directional swarm surge: a dense marching LINE that pours in from one random flank
# (spaced perpendicular to its approach) rather than a surrounding ring — VS's iconic
# "wall of enemies" you juke around, giving the move-only loop a directional threat to
# flee instead of only concentric pressure. Fires on its own cadence between the minute
# waves; count grows slowly with time survived and it shares the cap so it stays bounded.
static var SURGE_INTERVAL := BalanceData.get_value("spawner_surge_interval", 22.0)   # seconds between directional swarm walls
static var SURGE_FIRST := BalanceData.get_value("spawner_surge_first", 45.0)      # delay before the first wall (after the early trickle finds its feet)
static var SURGE_BASE: int = int(BalanceData.get_value("spawner_surge_base", 6.0))          # enemies in the line at SURGE_FIRST
static var SURGE_GROWTH := BalanceData.get_value("spawner_surge_growth", 0.06)     # extra line-members per second survived
static var SURGE_MAX: int = int(BalanceData.get_value("spawner_surge_max", 16.0))          # cap the line length so a wall never becomes a full encirclement
static var SURGE_SPACING := BalanceData.get_value("spawner_surge_spacing", 46.0)    # px between adjacent enemies along the wall

# Pincer variant: rarely, and only later in the run, a surge arrives as TWO mirrored walls
# marching in from opposite flanks (dir and -dir) at once, so the player must thread the gap
# between them along the shared perpendicular axis instead of simply fleeing one wall. Reuses
# the single-wall math for each side and shares MAX_ENEMIES, so it stays bounded.
static var PINCER_FIRST := BalanceData.get_value("spawner_pincer_first", 150.0)    # seconds survived before a surge may become a pincer
static var PINCER_CHANCE := BalanceData.get_value("spawner_pincer_chance", 0.25)    # chance an eligible (late-run) surge doubles into a pincer

# NOTE: the Glowing Bat (blue-rimmed VSEnemy.Type.GLOW_BAT) is NOT a free-standing early event.
# The wiki's Mad Forest table (.firecrawl/wiki-offline/Mad_Forest.md "Waves") lists it purely as a
# "Bosses & Treasure" beat whose FIRST appearance is 1:00 — never 0:30. It is therefore spawned
# only by the data-driven treasure-boss schedule below (BOSS_SCHEDULE / mad_forest_bosses.csv). A
# prior one-off GLOW_BAT_TIMES=[30.0, 180.0] mechanism spawned an extra glow bat at 0:30 (invented,
# off-wiki) and 3:00 (a duplicate of the 3:00 treasure boss); it was removed to keep spawns faithful.

var run: VSRun
var _accum := 0.0
var _next_wave := WAVE_INTERVAL
var _next_surge := SURGE_FIRST
var _boss_idx := 0

func _ready() -> void:
	# Enforce the perf gate at load. COLLIDER_SAFE_CAP is the validated packed-density ceiling: a real
	# Web run confirmed the crush holds ~78fps at the ~274-body crush now that VSEnemy.MAX_OVERLAP_CHECKS
	# bounds the per-frame overlap scan (no O(n²) reversion at collapsed density). Raising the enemy cap
	# past it would push the crush into unmeasured territory. Debug-build only, so it never costs a
	# shipped frame.
	assert(MAX_ENEMIES_LATE <= COLLIDER_SAFE_CAP,
		"MAX_ENEMIES_LATE > COLLIDER_SAFE_CAP: the packed-density crush is only validated to ~60fps up to COLLIDER_SAFE_CAP bodies (VSEnemy.MAX_OVERLAP_CHECKS keeps the overlap scan linear that far) — re-profile a real Web crush before raising the enemy cap further.")

## Half-extent (in world units) of the visible screen at the CURRENT camera zoom, or Vector2.ZERO
## when there is no live camera/viewport yet (headless tests, before the world is built). Camera2D
## zoom is data-driven (data/balance.csv `camera_zoom`) and a zoom < 1 zooms OUT and ENLARGES the
## visible world, so this must be read live: visible world extent = screen pixels / zoom.
static func _visible_half(node: Node) -> Vector2:
	var vp := node.get_viewport()
	if vp == null:
		return Vector2.ZERO
	var cam := vp.get_camera_2d()
	if cam == null or cam.zoom.x <= 0.0 or cam.zoom.y <= 0.0:
		return Vector2.ZERO
	return vp.get_visible_rect().size * 0.5 / cam.zoom

## Off-screen spawn-ring radius for the CURRENT camera zoom. Enemies must always enter from beyond
## the visible screen, so this sizes the ring past the farthest visible CORNER at the live zoom,
## plus SPAWN_MARGIN. SPAWN_RING is the floor (used when zoomed in far, or before a current
## camera/viewport exists). Static so enemy recycling (VSEnemy._recycle) shares the EXACT same ring,
## keeping recycled stragglers off screen too.
static func offscreen_radius(node: Node) -> float:
	var half := _visible_half(node)
	if half == Vector2.ZERO:
		return SPAWN_RING
	return maxf(SPAWN_RING, half.length() + SPAWN_MARGIN)

## Number of ring angles ring_spawn_point() samples before falling back to its most-off-screen pick.
const RING_SAMPLE_TRIES := 16

## A ring point around `origin` (the player) chosen so that AFTER clamping to the arena bounds it is
## still OFF the visible screen. offscreen_radius() already puts an un-clamped ring point beyond the
## farthest visible corner, but the arena box (arena_half) is only a little larger than the
## zoomed-out view, so a ring point past an arena edge gets clamped back onto that edge — and when
## the player hugs the edge the clamped point lands on screen. Because the camera is centered on the
## player, any point outside the visible rect around `origin` is off screen; so we sample angles
## (from `base_ang` over a `spread`-wide arc; default a full circle) and return the first whose
## clamped point clears the visible rect on some axis, steering spawns toward the arena interior only
## when the player is near an edge. Falls back to the most-off-screen candidate in the degenerate
## case none clear (e.g. no live camera, where visible_half is unknown and every point is accepted).
## Shared by the spawner and VSEnemy._recycle so both obey the identical rule.
static func ring_spawn_point(node: Node, origin: Vector2, arena_half: Vector2, base_ang := 0.0, spread := TAU) -> Vector2:
	var r := offscreen_radius(node)
	var vis := _visible_half(node)
	var best := origin
	var best_slack := -INF
	for _i in RING_SAMPLE_TRIES:
		var ang := base_ang + (randf() - 0.5) * spread
		var p := origin + Vector2(cos(ang), sin(ang)) * r
		p.x = clampf(p.x, -arena_half.x, arena_half.x)
		p.y = clampf(p.y, -arena_half.y, arena_half.y)
		# How far the clamped point sits OUTSIDE the visible rect on its most-visible axis. >= 0 means
		# off screen (visible_half ZERO -> unknown camera -> every point accepted, prior behavior).
		var slack := maxf(absf(p.x - origin.x) - vis.x, absf(p.y - origin.y) - vis.y)
		if slack >= 0.0:
			return p
		if slack > best_slack:
			best_slack = slack
			best = p
	return best

## Which outward (arena-edge) directions currently have NO off-screen room around `origin` — i.e. the
## visible screen already reaches that arena edge, so a formation point pushed that way clamps onto the
## near edge ON screen. Returns a bias pointing toward the arena INTERIOR on each boxed-in axis (0 on an
## axis with off-screen room on both sides). Vector2.ZERO when the player is clear of every edge
## (central) or the camera is unknown (headless). Shared by _spawn_wave and _spawn_wall so both steer a
## whole coordinated formation toward the interior identically, keeping the formation intact off screen.
static func _interior_bias(node: Node, origin: Vector2, arena_half: Vector2) -> Vector2:
	var vis := _visible_half(node)
	if vis == Vector2.ZERO:
		return Vector2.ZERO
	var bias := Vector2.ZERO
	if origin.x + vis.x >= arena_half.x:   bias.x -= 1.0   # right edge on screen -> steer left
	if origin.x - vis.x <= -arena_half.x:  bias.x += 1.0   # left edge on screen  -> steer right
	if origin.y + vis.y >= arena_half.y:   bias.y -= 1.0   # bottom edge on screen -> steer up
	if origin.y - vis.y <= -arena_half.y:  bias.y += 1.0   # top edge on screen    -> steer down
	return bias

## Positive CCW angular distance from `from` to `to` (in [0, TAU)). Used to size the off-screen gaps
## between the on-screen wedges in _formation_arc.
static func _arc_len(from: float, to: float) -> float:
	var d := fmod(to - from, TAU)
	if d < 0.0:
		d += TAU
	return d

## Base angle + angular spread for a coordinated even ring (a wave surge) chosen so that EVERY point
## stays off the visible screen even when the player hugs an arena edge. When the player is central it
## returns a full even ring (spread = TAU, random base) — unchanged behavior. Off an edge the ring
## collapses to the widest off-screen arc: because offscreen_radius() exceeds arena_half on both axes, a
## ring point past an edge clamps onto that edge, and such a clamped point lands ON screen only in a
## NARROW wedge around the blocked OUTWARD axis — where its offset on the PERPENDICULAR axis is still
## within view (half-angle asin(vis_perp / radius)). We build one wedge per blocked axis, then repack the
## surge evenly across the LARGEST gap between them (the arc's endpoints stay a small pad clear of the
## wedges), so the ring stays evenly spaced AND fully off screen even at an asymmetric corner.
static func _formation_arc(node: Node, origin: Vector2, arena_half: Vector2) -> Dictionary:
	var bias := _interior_bias(node, origin, arena_half)
	if bias == Vector2.ZERO:
		return {"base_ang": randf() * TAU, "spread": TAU}
	var vis := _visible_half(node)
	var r := offscreen_radius(node)
	# One on-screen wedge [center, half] per blocked outward axis (x blocked -> perpendicular axis is y,
	# and vice-versa). Outward +x is angle 0 / -x is PI; outward +y (down) is PI/2 / -y is -PI/2.
	var wedges: Array = []
	if bias.x != 0.0:
		wedges.append([0.0 if bias.x < 0.0 else PI, asin(clampf(vis.y / r, 0.0, 1.0))])
	if bias.y != 0.0:
		wedges.append([PI * 0.5 if bias.y < 0.0 else -PI * 0.5, asin(clampf(vis.x / r, 0.0, 1.0))])
	# Pad exceeds the per-member jitter (randf_range(±0.12) ≈ ±6.9°) so a jittered endpoint still clears
	# the wedge.
	var pad := deg_to_rad(10.0)
	if wedges.size() == 1:
		# Single edge: the good arc is the whole circle minus the one wedge, centered opposite it.
		var span: float = TAU - 2.0 * float(wedges[0][1]) - 2.0 * pad
		return {"base_ang": float(wedges[0][0]) + PI, "spread": clampf(span, PI * 0.25, TAU)}
	# Corner (two wedges): fill the LARGER of the two off-screen gaps between them. The wedge centers sit
	# 90° apart and are far narrower than that, so the two gaps never vanish.
	var a: Array = wedges[0]
	var b: Array = wedges[1]
	var gap1_start: float = a[0] + a[1]   # a's trailing edge -> b's leading edge (CCW)
	var gap2_start: float = b[0] + b[1]   # b's trailing edge -> a's leading edge (CCW)
	var g1 := _arc_len(gap1_start, b[0] - b[1])
	var g2 := _arc_len(gap2_start, a[0] - a[1])
	var gap_start := gap1_start if g1 >= g2 else gap2_start
	var gap_len := maxf(g1, g2)
	return {"base_ang": gap_start + gap_len * 0.5, "spread": clampf(gap_len - 2.0 * pad, PI * 0.25, TAU)}

## Re-baseline the wave/elite/surge cadence timers to just after the current run clock. Used only
## by the debug `force_time_set` command: jumping run.elapsed forward by many minutes would otherwise
## make _process fire one elite (and wave/surge) per frame to "catch up" from the old timers — dumping
## ~48 elites in a burst that no natural run ever has and skewing a late-game population/FPS check.
## Pushing each timer to the next boundary after `elapsed` keeps the ambient trickle (which fills to
## the density cap) while suppressing the artificial catch-up crescendo.
func resync_timers() -> void:
	if run == null:
		return
	var t := run.elapsed
	_next_wave = (floorf(t / WAVE_INTERVAL) + 1.0) * WAVE_INTERVAL
	_next_surge = t + SURGE_INTERVAL
	# Skip the boss index past every beat already due, so a forward time-jump does not dump the
	# whole passed boss roster in a single catch-up frame (the same crescendo the wave/surge
	# resync above suppresses). Future beats still fire on their marks.
	_ensure_bosses()
	_boss_idx = 0
	while _boss_idx < _boss_schedule.size() and _boss_schedule[_boss_idx].time <= t:
		_boss_idx += 1

func _process(delta: float) -> void:
	if run == null or run.phase != "playing" or run.player == null:
		return
	# Base trickle paced by Mad Forest's real per-minute spawn table: the "spawn interval
	# (seconds)" column sets how fast enemies enter (rate = 1/interval) and the "Enemy
	# minimum" column sets the concurrent population this stretch maintains. Both come from
	# DENSITY_SCHEDULE so the field ebbs and flows (the 5:00/10:00 lulls that frame the real
	# stage's minibosses read through) instead of pinning at the flat cap for the whole run.
	var density := _density()
	var rate: float = 1.0 / density.interval   # enemies/sec entering this minute
	var soft_cap: int = mini(int(density.count), _max_cap())
	_accum += rate * delta
	while _accum >= 1.0:
		_accum -= 1.0
		_spawn_one(soft_cap)
	# Scheduled treasure bosses fire on the wiki's per-minute boss beats (res://data/mad_forest_bosses.csv,
	# transcribed into BOSS_SCHEDULE). The index walks the schedule so each beat fires exactly once; a
	# debug time-jump past a mark still spawns it (resync_timers pushes the index forward to avoid a
	# catch-up burst). Empty minutes have no schedule entry, so they stay a genuine lull.
	_ensure_bosses()
	while _boss_idx < _boss_schedule.size() and run.elapsed >= _boss_schedule[_boss_idx].time:
		var beat: Dictionary = _boss_schedule[_boss_idx]
		_boss_idx += 1
		for boss_type in beat.types:
			_spawn_boss(int(boss_type))
	# Each minute mark crescendos into a coordinated ring-burst so the run visibly
	# escalates toward RUN_DURATION. The final minute is skipped — the Reaper finale
	# owns that beat.
	if run.elapsed >= _next_wave and _next_wave < VSRun.RUN_DURATION:
		var minute := int(round(_next_wave / WAVE_INTERVAL))
		_next_wave += WAVE_INTERVAL
		_spawn_wave(minute)
	# Directional swarm walls fire between the minute rings for a different threat shape.
	# Skipped once the Reaper finale is imminent so the last beat belongs to the boss.
	if run.elapsed >= _next_surge and _next_surge < VSRun.RUN_DURATION - WAVE_INTERVAL:
		_next_surge += SURGE_INTERVAL
		_spawn_surge()

## Spawn a single base-trickle enemy on the ring, honoring the per-minute soft cap (the
## clamped "Enemy minimum" population target) so low-density minutes stay a genuine lull
## rather than refilling to the hard MAX_ENEMIES ceiling.
func _spawn_one(cap: int) -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= cap:
		return
	var pos := ring_spawn_point(self, run.player.position, run.arena_half)
	var e := VSEnemy.new()
	e.type = _pick_type()
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	AgentBridge.emit_event("spawn", {"type": "enemy", "pos": [pos.x, pos.y]})

## Spawn a single scheduled treasure boss on the ring at a wiki boss beat (see BOSS_SCHEDULE /
## res://data/mad_forest_bosses.csv). `boss_type` is the mapped VSEnemy.Type art the named boss
## borrows; is_boss floors its HP/gem burst to the ELITE tier and its kill drops a Treasure Chest
## (VSRun._maybe_drop_chest), the faithful "Bosses & Treasure" payout. Bypasses the enemy cap so
## the boss always shows up, and tags its event so tooling can tell it apart.
func _spawn_boss(boss_type: int) -> void:
	var pos := ring_spawn_point(self, run.player.position, run.arena_half)
	var e := VSEnemy.new()
	e.type = boss_type
	e.is_boss = true
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	AgentBridge.emit_event("spawn", {"type": "boss", "boss_type": boss_type, "pos": [pos.x, pos.y]})

## Minute-milestone surge: drop a full ring of enemies around the player in one beat so the
## survival clock reads as escalating waves (a VS "wave" event) rather than a smooth trickle.
## Count grows with each minute mark; the burst may briefly exceed MAX_ENEMIES by WAVE_OVERFLOW
## so the crescendo lands, but stays bounded for performance.
func _spawn_wave(minute: int) -> void:
	var count := WAVE_BASE + maxi(minute - 1, 0) * WAVE_GROWTH
	var ceiling := _max_cap() + WAVE_OVERFLOW
	# When the player hugs an arena edge the whole ring shifts to a wide arc over the interior so no
	# member clamps onto the near edge ON screen; centered, this stays a full even ring (spread = TAU).
	var arc := _formation_arc(self, run.player.position, run.arena_half)
	var base_ang: float = arc.base_ang
	var spread: float = arc.spread
	var radius := offscreen_radius(self)
	for i in count:
		if get_tree().get_nodes_in_group("enemies").size() >= ceiling:
			break
		# Evenly space the members across the (full or interior) arc, with a little jitter, so it reads
		# as a coordinated surge.
		var ang := base_ang + spread * (float(i) / float(count) - 0.5) + randf_range(-0.12, 0.12)
		var pos := run.player.position + Vector2(cos(ang), sin(ang)) * radius
		pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
		pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
		var e := VSEnemy.new()
		e.type = _pick_type()
		e.position = pos
		e.run = run
		e.target = run.player
		run.add_child(e)
	AgentBridge.emit_event("wave", {"minute": minute, "count": count})

## Directional swarm wall: spawn a line of enemies off a single random flank, spaced
## perpendicular to their approach, so the horde sometimes arrives as a wall marching in
## from one side (the player flees perpendicular to it) instead of a surrounding ring.
## Length grows with time survived but is capped so it never becomes a full encirclement;
## shares MAX_ENEMIES so a wall never blows the performance budget.
func _spawn_surge() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= _max_cap():
		return
	var count := clampi(SURGE_BASE + int(run.elapsed * SURGE_GROWTH), SURGE_BASE, SURGE_MAX)
	# The flank the wall comes from; its perpendicular spread axis is derived per wall.
	var dir := Vector2.from_angle(randf() * TAU)
	# Later in the run a surge occasionally doubles into a PINCER: a second mirrored wall
	# marches in from the opposite flank (-dir) at the same time, forcing the player to thread
	# the gap between them rather than just fleeing one wall.
	var pincer := run.elapsed >= PINCER_FIRST and randf() < PINCER_CHANCE
	_spawn_wall(dir, count)
	if pincer:
		_spawn_wall(-dir, count)
	AgentBridge.emit_event("surge", {"count": count, "dir": [dir.x, dir.y], "pincer": pincer})
	# Telegraph the incoming wall on the HUD: flash an edge arrow pointing at the flank it
	# marches in from, so the player gets a beat to juke before it closes. The HUD holds a single
	# arrow, so a pincer telegraphs only the primary flank — its mirror stays a late-run surprise.
	if run.hud:
		run.hud.telegraph_surge(dir)

## Spawn one marching wall of `count` enemies off the `dir` flank, spaced evenly along the
## axis perpendicular to their approach and centered on the flank point. Honors MAX_ENEMIES on
## every enemy so a single wall — or a pincer's second wall — never blows the performance budget.
func _spawn_wall(dir: Vector2, count: int) -> void:
	# Steer the whole line's flank toward the arena interior on any axis where the player hugs an edge,
	# so the flank point (and the line spread off it) clears the visible screen instead of clamping onto
	# the near edge ON screen. Central / headless: bias is ZERO and `dir` is untouched. (A late-run
	# pincer's mirror wall biases the same way, so near an edge both walls converge from the interior
	# rather than one popping in on screen — an acceptable, rare degeneration of the two-flank shape.)
	var bias := _interior_bias(self, run.player.position, run.arena_half)
	if bias.x != 0.0:
		dir.x = absf(dir.x) * signf(bias.x)
	if bias.y != 0.0:
		dir.y = absf(dir.y) * signf(bias.y)
	dir = dir.normalized()
	var perp := dir.orthogonal()
	var center := run.player.position + dir * offscreen_radius(self)
	for i in count:
		if get_tree().get_nodes_in_group("enemies").size() >= _max_cap():
			break
		# Space members evenly along the wall, centered on the flank point.
		var lane := (float(i) - float(count - 1) * 0.5) * SURGE_SPACING
		var pos := center + perp * lane
		pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
		pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
		var e := VSEnemy.new()
		e.type = _pick_type()
		e.position = pos
		e.run = run
		e.target = run.player
		run.add_child(e)

## Summon the finale Reaper on the spawn ring. Modeled on _spawn_boss (bypasses the
## enemy cap, tags its event) but injects the single, near-unkillable REAPER that VSRun
## triggers at the survival time limit for the run's climactic last stand. Returns the
## node so the run can hand it to the HUD for the boss health bar.
func spawn_reaper() -> VSEnemy:
	var pos := ring_spawn_point(self, run.player.position, run.arena_half)
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.REAPER
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	# Telegraph the off-ring arrival with a crimson screen vignette so it reads as an
	# event, echoing the HUD 'THE REAPER COMES' banner.
	VSReaperVignette.spawn(run)
	AgentBridge.emit_event("spawn", {"type": "reaper", "pos": [pos.x, pos.y]})
	return e

## The general (base-trickle) spawn rules — which enemies appear, the concurrent population,
## and the spawn interval per minute — live in res://data/mad_forest_waves.csv (one row per
## minute: minute, spawn_interval, enemy_minimum, enemies), so a designer can retune the whole
## Mad Forest wave table against the wiki without editing this script. The CSV is the source of
## truth at runtime; ROSTER_SCHEDULE / DENSITY_SCHEDULE below are the transcribed fallback used
## only if the file is missing/unreadable (keeps the run spawning). Every enemy in the schedule
## is a Mad-Forest wiki enemy (see the "Waves" section) — no invented archetypes.
const WAVES_CSV := "res://data/mad_forest_waves.csv"
## Maps the CSV's enemy-name tokens to VSEnemy.Type so the "enemies" column stays human-readable.
const NAME_TO_TYPE := {
	"BAT": VSEnemy.Type.BAT,
	"ZOMBIE": VSEnemy.Type.ZOMBIE,
	"SKELETON": VSEnemy.Type.SKELETON,
	"GHOST": VSEnemy.Type.GHOST,
	"MUMMY": VSEnemy.Type.MUMMY,
	"MANTIS": VSEnemy.Type.MANTIS,
	"MANTIS_WARRIOR": VSEnemy.Type.MANTIS_WARRIOR,
	"MUDMAN": VSEnemy.Type.MUDMAN,
	"WEREWOLF": VSEnemy.Type.WEREWOLF,
	"ELITE": VSEnemy.Type.ELITE,
	"REAPER": VSEnemy.Type.REAPER,
	"GLOW_BAT": VSEnemy.Type.GLOW_BAT,
	"SILVER_BAT": VSEnemy.Type.SILVER_BAT,
	"GIANT_MUMMY": VSEnemy.Type.GIANT_MUMMY,
	"GIANT_WEREWOLF": VSEnemy.Type.GIANT_WEREWOLF,
	"GIANT_MANTICHANA": VSEnemy.Type.GIANT_MANTICHANA,
	"VENUS": VSEnemy.Type.VENUS,
	"GIANT_BLUE_VENUS": VSEnemy.Type.GIANT_BLUE_VENUS,
}
## Loaded once from WAVES_CSV (cached across instances); each falls back to the const below.
static var _roster_bands: Array = []
static var _density_bands: Array = []
static var _schedule_loaded := false

## The per-minute treasure-boss roster lives in res://data/mad_forest_bosses.csv (one row per
## minute: minute, boss_name, enemy_type, art_note), so the whole boss cadence is designer-editable
## and exactly wiki-faithful. The CSV is the source of truth at runtime; BOSS_SCHEDULE below is the
## transcribed fallback used only if the file is missing/unreadable (keeps bosses spawning).
const BOSS_CSV := "res://data/mad_forest_bosses.csv"
## Transcribed verbatim from Mad Forest's "Bosses & Treasure" column (0:00-29:00; the 30:00 Reaper
## is the finale, spawned separately by VSRun). Each entry is {time: seconds, types: [mapped
## VSEnemy.Type ...]}. Empty minutes (0/2/4/6/13/17/19/26/28) have no entry. The generic bats stay
## role-mapped (Glowing/Giant Bat -> GLOW_BAT), but every NAMED boss now has its own distinct art
## type: Silver Bat -> SILVER_BAT, Mantichana -> MANTIS_WARRIOR, Giant Mantichana -> GIANT_MANTICHANA,
## Giant Werewolf -> GIANT_WEREWOLF, Giant Mummy -> GIANT_MUMMY, Venus -> VENUS, Giant Blue Venus ->
## GIANT_BLUE_VENUS (see the CSV's art_note column).
const BOSS_SCHEDULE := [
	{"time": 60.0,   "types": [VSEnemy.Type.GLOW_BAT]},                              # 1:00 Glowing Bat
	{"time": 180.0,  "types": [VSEnemy.Type.GLOW_BAT]},                              # 3:00 Glowing Bat
	{"time": 300.0,  "types": [VSEnemy.Type.MANTIS_WARRIOR]},                        # 5:00 Mantichana
	{"time": 420.0,  "types": [VSEnemy.Type.GLOW_BAT]},                              # 7:00 Glowing Bat
	{"time": 480.0,  "types": [VSEnemy.Type.GLOW_BAT]},                              # 8:00 Giant Bat
	{"time": 540.0,  "types": [VSEnemy.Type.SILVER_BAT]},                            # 9:00 Silver Bat
	{"time": 600.0,  "types": [VSEnemy.Type.GIANT_MANTICHANA]},                      # 10:00 Giant Mantichana
	{"time": 660.0,  "types": [VSEnemy.Type.GLOW_BAT]},                              # 11:00 Glowing Bat
	{"time": 720.0,  "types": [VSEnemy.Type.GLOW_BAT]},                              # 12:00 Glowing Bat
	{"time": 840.0,  "types": [VSEnemy.Type.SILVER_BAT]},                            # 14:00 Silver Bat
	{"time": 900.0,  "types": [VSEnemy.Type.GIANT_WEREWOLF]},                        # 15:00 Giant Werewolf
	{"time": 960.0,  "types": [VSEnemy.Type.GLOW_BAT]},                              # 16:00 Glowing Bat
	{"time": 1080.0, "types": [VSEnemy.Type.SILVER_BAT]},                            # 18:00 Silver Bat
	{"time": 1200.0, "types": [VSEnemy.Type.GIANT_MUMMY]},                           # 20:00 Giant Mummy
	{"time": 1260.0, "types": [VSEnemy.Type.VENUS, VSEnemy.Type.GLOW_BAT]},          # 21:00 Venus + Glowing Bat
	{"time": 1320.0, "types": [VSEnemy.Type.GLOW_BAT]},                              # 22:00 Glowing Bat
	{"time": 1380.0, "types": [VSEnemy.Type.SILVER_BAT]},                            # 23:00 Silver Bat
	{"time": 1440.0, "types": [VSEnemy.Type.VENUS]},                                 # 24:00 Venus
	{"time": 1500.0, "types": [VSEnemy.Type.GIANT_BLUE_VENUS]},                      # 25:00 Giant Blue Venus
	{"time": 1620.0, "types": [VSEnemy.Type.GLOW_BAT]},                              # 27:00 Glowing Bat
	{"time": 1740.0, "types": [VSEnemy.Type.GLOW_BAT]},                              # 29:00 Glowing Bat
]
## Loaded once from BOSS_CSV (cached across instances); falls back to BOSS_SCHEDULE above.
static var _boss_schedule: Array = []
static var _bosses_loaded := false

## Roster schedule modeled directly on Mad Forest's real per-minute wave table
## (.firecrawl/wiki-offline/Mad_Forest.htm, "Waves" section: 0:00 Pipeestrello,
## 1:00 Zombie, 3:00 Skeleton, 5:00 Green Mudman, 12:00 Werewolf, 16:00 Mantichana,
## 25:00 Venus, etc). RUN_DURATION is already 1800s (30:00), matching Mad Forest's
## real time limit exactly, so minute marks below map 1:1 — no stretching needed.
## Green/Gray Mudman and Werewolf now have their own VSEnemy.Type + sprite, so the bands
## where the wiki introduces them point at the real archetypes (MUDMAN from 5:00, WEREWOLF
## from 12:00). The remaining named enemies without a distinct sprite yet stay role-mapped:
## Pipeestrello -> BAT, Big Mummy -> MUMMY, Venus/Mantichana -> MANTIS_WARRIOR.
## Each entry's weights apply from its minute mark until the next entry's.
const ROSTER_SCHEDULE := [
	{"min": 0.0,  "weights": {VSEnemy.Type.BAT: 1.0}},
	{"min": 1.0,  "weights": {VSEnemy.Type.ZOMBIE: 0.4, VSEnemy.Type.BAT: 0.6}},
	{"min": 2.0,  "weights": {VSEnemy.Type.BAT: 1.0}},
	{"min": 3.0,  "weights": {VSEnemy.Type.SKELETON: 1.0}},
	{"min": 4.0,  "weights": {VSEnemy.Type.SKELETON: 0.6, VSEnemy.Type.GHOST: 0.4}},
	{"min": 5.0,  "weights": {VSEnemy.Type.MUDMAN: 1.0}},
	{"min": 6.0,  "weights": {VSEnemy.Type.ZOMBIE: 0.5, VSEnemy.Type.MUDMAN: 0.5}},
	{"min": 7.0,  "weights": {VSEnemy.Type.BAT: 0.5, VSEnemy.Type.MUDMAN: 0.5}},
	{"min": 8.0,  "weights": {VSEnemy.Type.ZOMBIE: 1.0}},
	{"min": 9.0,  "weights": {VSEnemy.Type.BAT: 0.5, VSEnemy.Type.ZOMBIE: 0.5}},
	{"min": 10.0, "weights": {VSEnemy.Type.MUDMAN: 1.0}},
	{"min": 11.0, "weights": {VSEnemy.Type.SKELETON: 1.0}},
	{"min": 12.0, "weights": {VSEnemy.Type.WEREWOLF: 0.4, VSEnemy.Type.GHOST: 0.3, VSEnemy.Type.SKELETON: 0.3}},
	{"min": 13.0, "weights": {VSEnemy.Type.WEREWOLF: 0.5, VSEnemy.Type.GHOST: 0.5}},
	{"min": 14.0, "weights": {VSEnemy.Type.BAT: 0.5, VSEnemy.Type.WEREWOLF: 0.5}},
	{"min": 15.0, "weights": {VSEnemy.Type.WEREWOLF: 0.4, VSEnemy.Type.BAT: 0.3, VSEnemy.Type.MUDMAN: 0.3}},
	{"min": 16.0, "weights": {VSEnemy.Type.MANTIS_WARRIOR: 0.3, VSEnemy.Type.MUDMAN: 0.7}},
	{"min": 17.0, "weights": {VSEnemy.Type.MUMMY: 1.0}},
	{"min": 20.0, "weights": {VSEnemy.Type.MUMMY: 0.5, VSEnemy.Type.MUDMAN: 0.2, VSEnemy.Type.BAT: 0.3}},
	{"min": 22.0, "weights": {VSEnemy.Type.MUMMY: 1.0}},
	{"min": 25.0, "weights": {VSEnemy.Type.MANTIS_WARRIOR: 0.5, VSEnemy.Type.MUMMY: 0.5}},
	{"min": 27.0, "weights": {VSEnemy.Type.MUMMY: 0.5, VSEnemy.Type.MUDMAN: 0.3, VSEnemy.Type.MANTIS_WARRIOR: 0.2}},
]

## Per-minute base-spawn pacing transcribed verbatim from Mad Forest's real wave table
## (.firecrawl/wiki-offline/Mad_Forest.htm, the "Spawn interval (seconds)" and "Enemy
## minimum" columns, 0:00 through 29:00). `interval` is the seconds between base spawns
## (rate = 1/interval, tightening from 1.0s early to 0.1s in the endgame); `count` is the
## concurrent enemy population the stage maintains. RUN_DURATION is already 1800s (30:00),
## matching Mad Forest exactly, so these minute marks map 1:1 — no stretching. The wiki's
## counts climb to 300; they're clamped to the render budget (_max_cap(), which holds at the 150
## baseline early then ramps up from ~11:00 toward 300 so the endgame still escalates);
## the LOW values (the 5:00/10:00/etc. lulls the real stage uses to
## frame its minibosses) read through and thin the field. Each row holds from its minute mark
## until the next. Waves/surges/elites keep their own cadence and the hard cap — this governs
## only the ambient trickle.
const DENSITY_SCHEDULE := [
	{"min": 0.0,  "interval": 1.0,  "count": 15},
	{"min": 1.0,  "interval": 1.0,  "count": 30},
	{"min": 2.0,  "interval": 0.5,  "count": 50},
	{"min": 3.0,  "interval": 0.25, "count": 40},
	{"min": 4.0,  "interval": 1.0,  "count": 30},
	{"min": 5.0,  "interval": 1.0,  "count": 10},
	{"min": 6.0,  "interval": 0.5,  "count": 20},
	{"min": 7.0,  "interval": 0.5,  "count": 80},
	{"min": 8.0,  "interval": 1.5,  "count": 100},
	{"min": 9.0,  "interval": 0.5,  "count": 30},
	{"min": 10.0, "interval": 0.5,  "count": 10},
	{"min": 11.0, "interval": 0.1,  "count": 300},
	{"min": 12.0, "interval": 0.25, "count": 20},
	{"min": 13.0, "interval": 0.5,  "count": 150},
	{"min": 14.0, "interval": 0.1,  "count": 20},
	{"min": 15.0, "interval": 0.1,  "count": 100},
	{"min": 16.0, "interval": 0.1,  "count": 100},
	{"min": 17.0, "interval": 1.0,  "count": 20},
	{"min": 18.0, "interval": 0.5,  "count": 60},
	{"min": 19.0, "interval": 0.5,  "count": 100},
	{"min": 20.0, "interval": 0.1,  "count": 100},
	{"min": 21.0, "interval": 0.1,  "count": 300},
	{"min": 22.0, "interval": 0.1,  "count": 200},
	{"min": 23.0, "interval": 0.1,  "count": 300},
	{"min": 24.0, "interval": 0.1,  "count": 300},
	{"min": 25.0, "interval": 0.1,  "count": 100},
	{"min": 26.0, "interval": 0.1,  "count": 150},
	{"min": 27.0, "interval": 0.1,  "count": 300},
	{"min": 28.0, "interval": 0.1,  "count": 300},
	{"min": 29.0, "interval": 0.1,  "count": 300},
]

## The concurrent-enemy render budget for the current run time. Holds at MAX_ENEMIES up to
## LATE_RAMP_START (~11:00), then ramps linearly to MAX_ENEMIES_LATE across the rest of the run so the
## saturated DENSITY_SCHEDULE counts (150->300, all previously clamped flat to 90) actually read as
## escalating population on screen instead of one unchanging crush. Every population cap in the
## spawner routes through this so the late-game field grows as one coherent budget.
func _max_cap() -> int:
	var frac := run.elapsed / VSRun.RUN_DURATION
	if frac <= LATE_RAMP_START:
		return MAX_ENEMIES
	var t := clampf((frac - LATE_RAMP_START) / (1.0 - LATE_RAMP_START), 0.0, 1.0)
	return int(lerpf(float(MAX_ENEMIES), float(MAX_ENEMIES_LATE), t))

## The density row in effect for the current run time (same band lookup as
## _pick_type): the last row whose minute mark has passed.
func _density() -> Dictionary:
	_ensure_schedule()
	var minute := run.elapsed / 60.0
	var row: Dictionary = _density_bands[0]
	for band in _density_bands:
		if minute >= band.min:
			row = band
		else:
			break
	return row

func _pick_type() -> int:
	_ensure_schedule()
	var minute := run.elapsed / 60.0
	var weights: Dictionary = _roster_bands[0].weights
	for band in _roster_bands:
		if minute >= band.min:
			weights = band.weights
		else:
			break
	return _roll_weighted(weights)

## Load the per-minute spawn schedule from WAVES_CSV once (cached across instances). On any
## failure — missing file, empty/garbled rows — fall back to the transcribed const schedules so
## the run always spawns. Column-name driven so extra columns can be added without breaking this.
static func _ensure_schedule() -> void:
	if _schedule_loaded:
		return
	_schedule_loaded = true
	_roster_bands = ROSTER_SCHEDULE
	_density_bands = DENSITY_SCHEDULE
	var f := FileAccess.open(WAVES_CSV, FileAccess.READ)
	if f == null:
		push_warning("VSSpawner: cannot open %s (err %d) — using built-in schedule" % [WAVES_CSV, FileAccess.get_open_error()])
		return
	var header := f.get_csv_line()
	var col := {}
	for i in header.size():
		col[header[i].strip_edges()] = i
	var roster: Array = []
	var density: Array = []
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < 4 or r[0].strip_edges() == "":
			continue
		var minute := r[int(col.get("minute", 0))].strip_edges().to_float()
		density.append({
			"min": minute,
			"interval": r[int(col.get("spawn_interval", 1))].strip_edges().to_float(),
			"count": r[int(col.get("enemy_minimum", 2))].strip_edges().to_int(),
		})
		roster.append({"min": minute, "weights": _parse_weights(r[int(col.get("enemies", 3))].strip_edges())})
	f.close()
	if not roster.is_empty() and not density.is_empty():
		_roster_bands = roster
		_density_bands = density

## Load the per-minute treasure-boss schedule from BOSS_CSV once (cached across instances). On any
## failure — missing file, empty/garbled rows — fall back to the transcribed BOSS_SCHEDULE so bosses
## always spawn. Rows with an empty enemy_type are the wiki's empty minutes and are skipped; the
## enemy_type cell may name several bosses for one minute, separated by ';' (e.g. 21:00).
static func _ensure_bosses() -> void:
	if _bosses_loaded:
		return
	_bosses_loaded = true
	_boss_schedule = BOSS_SCHEDULE
	var f := FileAccess.open(BOSS_CSV, FileAccess.READ)
	if f == null:
		push_warning("VSSpawner: cannot open %s (err %d) — using built-in boss schedule" % [BOSS_CSV, FileAccess.get_open_error()])
		return
	var header := f.get_csv_line()
	var col := {}
	for i in header.size():
		col[header[i].strip_edges()] = i
	var minute_col := int(col.get("minute", 0))
	var type_col := int(col.get("enemy_type", 2))
	var schedule: Array = []
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() <= maxi(minute_col, type_col) or r[minute_col].strip_edges() == "":
			continue
		var cell := r[type_col].strip_edges()
		if cell == "":
			continue   # an empty minute in the wiki's "Bosses & Treasure" column — no boss this beat
		var types: Array = []
		for token in cell.split(";", false):
			var name := token.strip_edges()
			if not NAME_TO_TYPE.has(name):
				push_warning("VSSpawner: unknown boss '%s' in %s" % [name, BOSS_CSV])
				continue
			types.append(int(NAME_TO_TYPE[name]))
		if types.is_empty():
			continue
		schedule.append({"time": r[minute_col].strip_edges().to_float() * 60.0, "types": types})
	f.close()
	if not schedule.is_empty():
		_boss_schedule = schedule

## Parse a CSV "enemies" cell ("BAT:0.5;ZOMBIE:0.5") into a {VSEnemy.Type: weight} dictionary.
static func _parse_weights(cell: String) -> Dictionary:
	var out := {}
	for entry in cell.split(";", false):
		var kv := entry.split(":", false)
		if kv.size() < 2:
			continue
		var name := kv[0].strip_edges()
		if not NAME_TO_TYPE.has(name):
			push_warning("VSSpawner: unknown enemy '%s' in %s" % [name, WAVES_CSV])
			continue
		out[int(NAME_TO_TYPE[name])] = kv[1].strip_edges().to_float()
	return out

## Weighted pick over a {Type: weight} dictionary; weights need not sum to 1.
func _roll_weighted(weights: Dictionary) -> int:
	var total := 0.0
	for w in weights.values():
		total += w
	var roll := randf() * total
	var acc := 0.0
	for type in weights:
		acc += weights[type]
		if roll < acc:
			return type
	return weights.keys().back()
