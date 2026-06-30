# DONE — append-only log (newest on top)

Each Ralph/Workshop pass appends `[x] <title> — <what landed>` here. Union-merged across lanes
(see `.gitattributes`) so parallel appends concatenate instead of conflicting.

[x] Add a top-of-screen XP progress bar to the HUD — level-up progress was only legible as the
    "(N xp)" number, so the central VS pacing meter (how close am I to the next choice?) didn't read at
    a glance — a clear-feedback/readability gap the GOAL calls out. hud.gd (VSHud) only: added the iconic
    top-of-screen XP bar — a dark full-width track ColorRect (_xp_bg, set_anchors_preset PRESET_TOP_WIDE,
    offset_bottom = XP_BAR_H 10px) + a cyan-blue fill ColorRect (_xp_fill, color 0.40,0.78,1.0 matching the
    XP gem) anchored top-left with offset_bottom = XP_BAR_H. refresh() drives the fill width each frame by
    setting _xp_fill.anchor_right = clampf(run.xp / maxi(1, run.level*5), 0, 1) — threshold mirrors
    VSRun._check_level_up's level*5 — so the bar grows toward the next level and snaps back on level-up.
    Anchored so it spans any viewport width; both rects set mouse_filter = MOUSE_FILTER_IGNORE so they never
    block the picker/clicks. Nudged the stat label from y=8 to y=XP_BAR_H+4 so it sits just below the bar.
    One file; no scene/project.godot/API changes; a different KIND (UI/readability) from the recent audio
    passes. Gate PASS exit 0 (import parsed VSHud with no errors + both smoke tests incl. run-scene boot
    which builds the HUD and calls refresh() per frame through the new XP-bar update path). Eyeball: play and
    collect gems — a blue bar across the very top fills toward the next level and resets when the level-up
    picker pops; tune XP_BAR_H / colors by eye.

[x] Duck the ambient music during the level-up modal — the level-up arpeggio (C-E-G-C at -9 dB)
    competed with the always-on ambient bed (-22 dB), so the big moment didn't pop. sfx.gd: new
    duck_music(on) ATTENUATES the dedicated _music player by MUSIC_DUCK_DB (-14) rather than stopping
    it, so the loop keeps its position and resumes click-free; guarded by a _music_ducked flag
    (idempotent) and a null check (headless-safe — just sets volume_db on the existing player, which is
    inert under the gate's dummy audio driver). run.gd: Sfx.duck_music(true) at the top of
    _show_level_up() (entering the level_up phase, before the levelup cue plays) and Sfx.duck_music(false)
    in _on_upgrade_chosen() right where phase returns to "playing". In a multi-level XP burst the chained
    _check_level_up()->_show_level_up() re-ducks in the SAME frame (idempotent, no audible blip);
    game_over can only follow "playing" (the world freezes during the modal), so no unduck is needed
    there. Two files (sfx.gd + run.gd); no scene/API changes. Gate PASS exit 0 (import parsed VSSfx+VSRun
    + both smoke tests incl. run-scene boot which builds the music bed and runs the run controller through
    level-up paths). Eyeball: play to a level-up — the ambient drone should drop noticeably while the
    picker is open so the rising arpeggio reads, then return on resume; tune MUSIC_DUCK_DB by ear.

[x] Add a game-over death stinger — the run end was silent: player.gd plays "hurt" on the lethal hit
    but nothing distinct marked HP hitting 0 / the transition to game over. sfx.gd: added a "gameover"
    cue to _build_streams — a somber DESCENDING arpeggio (_arp([392, 311.13, 261.63, 196], 0.16, 0.8) =
    G4-Eb4-C4-G3), deliberately the MIRROR of the rising C-E-G-C level-up fanfare so defeat reads as the
    opposite of triumph; slower 0.16s steps land it as a stinger. Added a "gameover":0.0 COOLDOWN entry
    (like "levelup", a one-shot big-moment cue that should never be de-duped). run.gd: in _on_player_died()
    (already double-fire guarded by the phase==game_over early-return), after the existing "death" event,
    emit AgentBridge.emit_event("sfx_played",{name:"gameover"}) then Sfx.play("gameover") — matching the
    emit-before-play ordering at every other call site so the headless FEEL reviewer (can't hear audio)
    can observe/score it too. Two files (sfx.gd + run.gd); no scene/API changes; reuses the existing Sfx
    autoload + _arp synth. Gate PASS exit 0 (import parsed VSSfx+VSRun with no errors + both smoke tests
    incl. run-scene boot which builds every stream incl. the new arpeggio and runs the run controller
    headless). Eyeball: play the web/desktop build until HP hits 0 — a short descending defeat jingle
    plays as the run flips to game over, distinct from the "hurt" buzz of the killing blow. Tune the
    notes/step/volume by ear.

[x] Add a low looping ambient/music bed — the game had SFX but no music, leaving the audio polish
    thin. scripts/audio/sfx.gd (VSSfx) only: added a quiet, seamlessly-LOOPING ambient bed SYNTHESIZED
    in code as an AudioStreamWAV (LOOP_FORWARD with loop_begin/loop_end), matching the project's
    build-audio-in-code style — no binary asset / .import pipeline. _build_music() stacks four low
    drone partials (root 55 / fifth 82.41 / octave 110 / faint shimmer 164.81 Hz) under a slow 0.25 Hz
    amplitude swell; every partial AND the LFO is snapped by a new _loopf() helper to an integer number
    of cycles over the MUSIC_DUR=8s loop, so value and slope match at the wrap point and the buffer loops
    with NO click. It plays on its OWN dedicated AudioStreamPlayer (_music) at MUSIC_DB -22 (well under
    the -9 dB SFX blips), kept entirely separate from the 12-voice SFX round-robin pool so it never
    interacts with the per-sound de-dupe cooldown. Default ON; press M (an InputEventKey keycode check in
    _unhandled_input — no input-map change, so no conflict with the harness's mapped actions; echo-guarded
    so a held key toggles once) flips it via set_music_enabled()/toggle_music(). Emits a one-time
    AgentBridge "music" {state:start|stop} event (inert off web) so the headless FEEL reviewer, which
    can't hear audio, can still observe/score the bed. Headless-safe: under the gate's dummy audio driver
    play() is a no-op and building ~176k samples is instant; uses no gameplay RNG. One file (sfx.gd); no
    scene / project.godot / autoload changes (reused the existing Sfx autoload + AgentBridge). Gate PASS
    (import parsed VSSfx + both smoke tests incl. run-scene boot which instantiates Sfx, builds the music
    stream, and starts the looping player, exit 0). Eyeball: play the web/desktop build — a low, slow,
    non-intrusive drone loops under everything with no audible seam; press M to mute/unmute. Tune
    MUSIC_DB / partials / swell by ear.

[x] Emit sfx_played events for the new SFX cues (hit/kill/pickup/hurt/levelup) — The silent-audio pass added Sfx.play(name) at 5 sites but only weapon/aura/orbit paired it with the AgentBridge 'sfx_played' event the headless FEEL reviewer reads (it can't hear audio), so hit/kill/pickup/hurt/levelup were invisible to the event stream. Added AgentBridge.emit_event('sfx_played',{name}) immediately before each new Sfx.play, matching the weapon/aura/orbit ordering: enemy.gd hit() ('kill' lethal / 'hit' chip), run.gd collect_xp() ('pickup') + _show_level_up() ('levelup'), player.gd take_damage() ('hurt', beside its existing 'damage' emit). Now the full feedback set is observable/scorable by the goal-aware playtest reviewer. Three files, 5 one-line emits; no scene/API changes. Gate PASS (import + both smoke tests incl. run-scene boot, exit 0).

[x] Play actual SFX — the game was silent — weapon/aura/orbit emitted AgentBridge "sfx_played" events
    but those only feed the agent harness (inert off web), so nothing was ever audible: the biggest
    remaining "feel" gap. New autoload scripts/audio/sfx.gd (VSSfx, registered as Sfx in project.godot
    [autoload] beside AgentBridge) SYNTHESIZES tiny percussive AudioStreamWAV blips IN CODE — no binary
    WAV assets / .import pipeline, matching the project's build-everything-in-code style — for
    shoot/hit/kill/pickup/hurt/garlic/orbit plus a C-E-G-C level-up arpeggio (each a short swept tone,
    optionally noisy, under an exp percussive-decay envelope). Plays them through a 12-voice round-robin
    pool of AudioStreamPlayers at low volume_db (-9) with a per-sound de-dupe cooldown (so an AoE garlic
    tick wounding 30 enemies, or rapid multishot, plays ONE blip not a clipping wall) and a slight random
    pitch wobble so repeats don't grate. Uses its OWN RandomNumberGenerator so it never perturbs the
    gameplay seed; headless-safe (the gate's dummy audio driver makes play() a no-op). Call sites:
    Sfx.play(name) beside the existing sfx_played emits in weapon.gd(shoot)/aura.gd(garlic)/orbit.gd
    (orbit), plus enemy.hit (kill on lethal / hit on chip), run.collect_xp (pickup), player.take_damage
    (hurt), run._show_level_up (levelup). One new file + one project.godot autoload line + 6 one-line call
    sites; no scene changes. Gate PASS (import created the Sfx autoload + registered classes with no parse
    errors + both smoke tests incl. run-scene boot which fires weapons/kills/pickups through Sfx.play, exit
    0). Eyeball: play the web/desktop build — shooting, hits/kills, gem pickups, taking damage, and the
    level-up fanfare should all be audible, low and de-duped (dense waves don't clip), with subtle pitch
    variation; Garlic/Blades tick audibly once acquired. Tune volumes/cooldowns/timbres by ear.

[x] Enemy separation so the swarm reads as a crowd — every enemy pathed straight at the player with no
    separation, so a 90-strong wave stacked into a single overlapping blob (bad readability; the VS
    "swarmed by a horde" feel was lost). enemy.gd only: two tuning consts (SEPARATION 0.55 = push as a
    fraction of move speed; PERSONAL_SPACE 1.5 = neighbor-avoidance reach in body-radius multiples) and a
    _separation() helper that sums a soft push away from each nearby enemy in the "enemies" group
    (stronger the closer, 0 at the edge), then limit_length(1)*SEPARATION caps it so it only spaces the
    crowd out and never overpowers the chase. Applied in _process right after the chase move
    (position += _separation()*speed*delta) — chase pulls in, separation pushes apart, so a dense wave
    settles into a readable ring of individual bodies around the player instead of one point. Reach
    scales with radius so a brute claims more personal space than a bat; dying enemies are already out of
    the group so they don't push. O(n) per enemy over the capped (MAX_ENEMIES 90) group — cheap. One
    file; no API/scene changes; different KIND from the recent UI/weapon passes. Gate PASS (import
    registered VSEnemy + both smoke tests incl. run-scene boot/spawn/kill/progress, exit 0). Eyeball:
    survive into a crowd — the horde should fan out into a legible mass of bodies around you instead of
    collapsing onto a single stacked sprite. Tune SEPARATION/PERSONAL_SPACE by feel.

[x] Show owned upgrade level on the level-up picker buttons — the picker showed only title+desc, so a
    player stacking upgrades couldn't tell what they were reinforcing. VSLevelUpScreen.setup() now takes
    an optional `owned` Dictionary (key -> times chosen); each button renders as
    "[N]  Title (TAG) — desc" where TAG is "NEW" when owned==0 else "Lv<owned>". run.gd _show_level_up
    threads the existing run.upgrade_levels dict in via screen.setup(options, upgrade_levels) — no new
    state; the level is the count already tracked for the HUD loadout. Two files (levelup_screen.gd +
    run.gd); no scene changes. Gate PASS (import registered VSRun+VSLevelUpScreen + both smoke tests,
    exit 0). Eyeball: re-offered upgrades read e.g. "Power (Lv2)", unowned ones read "(NEW)".

[x] HUD loadout readout of owned weapons + upgrade levels — once upgrades started stacking
    (Power/Haste/Swift/Multishot/Garlic/Blades) the player had no way to tell what they owned.
    VSRun now tracks per-upgrade levels in an ordered `upgrade_levels` dict (key -> times chosen),
    incremented in _on_upgrade_chosen. hud.gd (VSHud) gained a bottom-left Label (_loadout, anchored
    PRESET_BOTTOM_LEFT, grow_vertical = BEGIN so it stacks upward, with a black font outline so it
    reads over the busy lower field) and refresh_loadout(run) — rebuilt ONLY on upgrade_chosen, not
    per-frame — that lists each acquired weapon/passive as "Title  LvN" in acquisition order
    (Dictionaries preserve insertion order, so the readout grows as the build does; titles are mapped
    from VSRun.UPGRADES via _title_for). Two files (run.gd + hud.gd); no scene changes. Gate PASS
    (import registered VSRun+VSHud + both smoke tests incl. run-scene boot/spawn/progress, exit 0).
    Eyeball: play to a couple of level-ups and pick upgrades — a small list (e.g. "Power  Lv2" /
    "Garlic  Lv1") builds in the bottom-left corner so build progress is legible.

[x] Add an orbiting-blades weapon (Blades) to the level-up pool — the slice had one auto-projectile
    + a Garlic aura, so weapon-choice variety toward the power spike was still thin. Added a second
    active weapon mirroring the Garlic pattern: new scripts/weapons/orbit.gd (VSOrbit extends Node2D)
    — N steel blades that spin around the player and cut any enemy the ring sweeps past (a melee orbit
    like VS King Bible; no aim, no chase). A Node2D child of the player; on a TICK (0.18s) _tick()
    samples each blade's reach and calls e.hit(damage, blade_pos) on enemies within
    blade_radius+e.radius, with a `struck` dict so two blades never double-cut one enemy in a single
    tick (and hit() drops the corpse from the "enemies" group, so no double-kill). Spins via
    _angle = fmod(_angle + spin*delta, TAU); z_index 1 so blades read over enemies (z 0); draws
    primitives like the other juice — a faint orbit ring (draw_arc) + a steel blade-polygon glint at
    each blade with a bright core, brightening briefly on a connecting tick (_pulse); emits sfx_played
    "orbit" on a connecting tick. Frozen with run.phase. Wired into run.gd: added
    {"key":"orbit","title":"Blades","desc":"Spinning blades that cut nearby foes"} to UPGRADES (pool now
    offers 3 of 6), a `var orbit: VSOrbit` field, and an apply_upgrade("orbit") case that lazily spawns
    the ring on the player on first pick (1 blade, dmg 4, radius 64) and levels it on repeats (+1 blade
    up to MAX_BLADES 6, +2 dmg, ring widens +4 up to 92) — an escalating power spike. One new file +
    ~10 lines in run.gd; no scene changes. Gate PASS (import registered VSOrbit + both smoke tests incl.
    run-scene boot/spawn/progress, exit 0). Eyeball: play to a level-up, pick Blades — a steel ring
    spins around you and shreds nearby swarms; pick it again and another blade joins and the cut
    deepens. Tune blade count/damage/spin/tick by feel.

[x] Add a Garlic damaging-aura weapon to the level-up pool — the slice had ONE weapon (a single
    auto-projectile) + four stat-tweak upgrades, so the GOAL's "satisfying mid-run power spike" and
    "weapon choices" were thin. Added the iconic VS swarm-clearer: new scripts/weapons/aura.gd
    (VSAura) — a pale-green halo child of the player (z_index -10, ground-hugging) that every 0.5s
    loops the "enemies" group and calls e.hit(damage, global_position) on every enemy within
    radius+e.radius (no aim, no chase). Safe to wound many per tick: get_nodes_in_group returns a
    snapshot and hit() only marks the corpse _dying + drops it from the group (frees later), so no
    double-kill. Drawn with primitives like the other juice (faint fill circle + brighter arc),
    swells briefly on each tick via a _pulse so the bite reads; emits sfx_played "garlic" on a
    connecting tick; gated on run.phase so it freezes with the level-up picker / game over. run.gd:
    added {"key":"garlic","title":"Garlic","desc":"Damaging aura around you"} to UPGRADES (pool now
    offers 3 of 5), a `var aura: VSAura` field, and an apply_upgrade("garlic") case that lazily spawns
    the aura on the player on first pick (radius 70, dmg 3) and levels it on repeats (radius +22,
    dmg +2) — an escalating power spike. One new file + ~12 lines in run.gd; no scene changes, no
    enemy/spawner touch (different KIND from the recent enemy-tuning passes). Gate PASS (import
    registered VSAura + both smoke tests incl. run-scene boot/spawn/progress, exit 0). Eyeball: play
    to a level-up, pick Garlic — a pale-green halo chews nearby swarms; pick it again and it widens
    and bites harder. Tune radius/damage/tick by feel.

[x] Tanky enemies drop a richer XP gem — killing a 20-HP brute dropped the same 1-XP gem as a 3-HP
    bat, so the high-HP target wasn't rewarding. VSEnemy now carries an `xp_value` (default 1; spawner
    sets brute 5). enemy.gd hit() passes it through run.add_kill(position, xp_value); run.gd
    add_kill/_spawn_gem thread it into VSGem.xp_value; gem.gd grants run.collect_xp(xp_value) on pickup
    (pickup event now carries `value`) and draws a distinct RED sprite when xp_value>1. Art: new
    vampire-survivors-taskmaster/art/gem_xp_red.png 12x16 — SourceArt/extracted_clean/gem_red cropped to
    its alpha bbox, premultiplied-alpha LANCZOS downscaled to the SAME framing as the blue gem
    (opaque-avg ~131,36,43, pops against the dark-green ground and is maximally distinct from the blue
    standard gem; Zelda red-rupee = high value); lossless, mipmaps off, NEAREST, fix_alpha_border
    (.import via headless --import, matches gem_xp.png). So soaking a brute pays ~5 bats' worth of XP and
    feeds the mid-run power spike. Four scripts (enemy/spawner/run/gem) + one new sprite (+.import); no
    scene changes. Gate PASS (import registered the new gem + both smoke tests incl. run-scene
    boot/spawn/kill/gem, exit 0). Eyeball: kill a brute — it drops a red gem worth a chunk of a level;
    bats/ghosts still drop the blue 1-XP gem. Tune the brute's xp_value by feel.

[x] Per-enemy contact radius so the big brute is a real wall — VSEnemy.RADIUS (shared const 12)
    drove BOTH the contact check (enemy.gd) and the projectile hit-test (projectile.gd, via
    VSEnemy.RADIUS), so a brute drawn 1.5x bigger still had a bat-sized body you could clip past
    and shoot through the edges of. Gave VSEnemy a per-enemy `radius` var (default RADIUS=12);
    contact check reads `radius`, projectile reads `e.radius` — one number drives both, so what
    you see is what you hit. spawner _apply_kind sets brute radius 22 (matches its 27x30 sprite at
    1.5x); _apply_difficulty scales radius alongside base_scale (*= 1+vis*0.05) so a hardened
    enemy's hitbox stays honest. bat/ghost keep the 12 default. Three files; no scene changes.
    Gate PASS (import + both smoke tests, exit 0).

[x] Add a slow, tanky "brute" enemy as a third kind — waves had only the slow sturdy bat and the
    fast fragile ghost. Added a rare slow/tanky "brute" WALL as a third KIND. Art: new
    vampire-survivors-taskmaster/art/enemy_brute.png 27x30 — werewolf (SourceArt/extracted_clean)
    cropped to its alpha bbox, premultiplied-alpha LANCZOS downscaled, ~0.78 dark tint baked in
    (opaque-avg ~71,51,39 warm brown that pops against the dark-green ground 37,87,17 and is distinct
    from the dark bat ~43,40,48 and pale-cyan ghost ~183,225,238); chose werewolf over the green
    zombie because a green brute would camouflage on the green ground. Lossless, mipmaps off, NEAREST,
    fix_alpha_border (.import via headless --import, matches the bat/ghost). spawner.gd: const
    BRUTE_SPRITE + _apply_kind now rolls ONE randf() partitioned — brute first (brute_chance =
    clampf((elapsed-30)/180, 0, 0.18): rare, none before 30s, caps ~18% by ~3.5min), then ghost
    (unchanged slice), else bat (so bats never vanish). A brute gets speed 42 (< bat's 62 — a wall you
    kite), health 20 (very tanky), contact 14 (heavy vs bat 8 / ghost 5), base_scale 1.5 (reads BIG).
    _apply_difficulty's base_scale assignment changed to *= so tier growth STACKS on the kind's base
    (brute stays big as it hardens; bat/ghost default 1.0 unaffected). enemy.gd: doc comments only
    (three kinds now). Two scripts + one new sprite (+.import). Gate PASS (import registered
    VSEnemy+VSSpawner + reimported enemy_brute.png + both smoke tests incl. run-scene boot/spawn/
    progress, exit 0). Eyeball: play a few minutes — rare big dark-brown brutes lumber in, soak many
    shots and hit hard, so kiting + Power/Multishot matter; tune odds/stats by feel.

[x] Add a second enemy type for wave variety — waves varied only in toughness; every enemy was the
    same slow bat. Added a fast/fragile "ghost" swarmer so escalation varies in KIND, not just
    numbers. Art: offline-downscaled SourceArt/extracted_clean/ghost.png (cropped to its alpha bbox,
    premultiplied-alpha LANCZOS) → vampire-survivors-taskmaster/art/enemy_ghost.png 16x20, a small
    pale-cyan wisp (opaque-avg ~183,225,238) that contrasts the dark bat (~43,40,48); lossless,
    mipmaps off, NEAREST, fix_alpha_border (.import generated via headless --import, matches the bat).
    enemy.gd: VSEnemy now carries a per-enemy `kind` + `sprite` (defaulting to the bat) and _draw uses
    `sprite`, so one class is either kind. spawner.gd: const GHOST_SPRITE + a new _apply_kind(e) run
    before _apply_difficulty — ghost_chance = clampf((elapsed-5)/120, 0, 0.5) mixes the swarmer in more
    often the longer you survive (capped 50% so bats never vanish); a ghost gets speed 112 (~1.8x the
    bat's 62, still under the player's 210 so it's kiteable), health 2 (fragile), contact 5 (the danger
    is the pile-up). Time-tier hardening still stacks on top of whichever kind, so late ghosts also gain
    HP/damage. The spawn event now carries the kind. Two scripts + one new sprite (+.import); no scene
    changes. Gate PASS (import registered VSEnemy+VSSpawner, both smoke tests incl. run-scene
    boot/spawn/progress, exit 0). Eyeball: play ~30s+ — small pale-cyan ghosts should start mixing in
    and rush you noticeably faster than the bats, so standing still stops working; tune the ramp/stats
    by feel.

[x] Escalate enemy toughness over the run — waves were density-only (every bat a fixed 3-HP target
    forever), so Power/Multishot had nothing tougher to bite into. scripts/enemies/spawner.gd now
    hardens each spawned enemy by a time tier (int(elapsed/30) — a new tier every 30s survived) in a
    new _apply_difficulty(e): +1 HP per tier (capped +10), +0.5 contact damage per tier (capped +5),
    and a legible cue so the escalation reads — up to ~1.30x bigger + red-shifted (vis capped at tier
    6). Speed left constant (fast enemies feel unfair; this is a hardening siege, not a sprint).
    scripts/enemies/enemy.gd gained base_scale + tier_tint folded into _draw (flash/death pop still
    override with their bright/white tints and now multiply base_scale). Stat growth is capped so a
    long run plateaus into a grind, never an un-killable wall. Two files; no scene changes. Gate PASS
    (import registered VSEnemy+VSSpawner + both smoke tests incl. run-scene boot/spawn/progress, exit
    0). Eyeball: play a few minutes — later bats look bigger/redder and take more shots, so the upgrade
    spike feels needed; tune the 30s cadence / caps by feel.

[x] Report real player velocity to the agent harness — agent_adapter.gd _provide() hardcoded velocity
    to [0,0], so the agent persona read the player as motionless even while walking. Added velocity:Vector2
    to VSPlayer (scripts/player/player.gd), set each _process from the ACTUAL displacement
    ((position - prev) / delta), not the intended dir*speed — so it reports zero when wall-clamped at the
    arena edge, zero when frozen (level-up picker / game over) or dead, and tracks the real Swift speed
    multiplier. agent_adapter.gd now reports [p.velocity.x, p.velocity.y]. Two files only. Gate PASS
    (import registered VSPlayer + gdUnit4 + run-scene smoke, exit 0). Eyeball: re-run
    tools/playtest-review.ps1 with a funded balance — the persona's state should show live velocity
    matching its movement (and ~0 when pinned to a wall or during a level-up choice).

[x] Mark the arena boundary so it reads — the player hard-clamps to arena_half, but the now-visible
    tiled field turned that edge into an invisible wall. scripts/run/ground.gd (VSGround) only: _draw()
    now, past arena_half, stacks 6 translucent NIGHT rings (new _draw_ring helper — 4 non-overlapping
    rects each, leaving the playable rect untouched) that deepen the dark from the rim outward over a
    220px band — a stepped, pixel-friendly vignette where the field fades into night — then strokes a
    3px worn-dirt RIM exactly on the clamp boundary so the edge stays unambiguous up close. All static
    (drawn once, no queue_redraw) and at z_index -100, beneath the foreground. Gate PASS (import
    validated VSGround + gdUnit4 + run-scene smoke boots the world and runs _draw, exit 0). Eyeball:
    open run.tscn and walk to an edge — a crisp worn-dirt rim marks the wall and the ground darkens
    into night beyond it.

[x] Projectile impact spark on hit — projectiles vanished silently on contact; now a landed shot
    reads. scripts/weapons/projectile.gd only: on an enemy hit, _spawn_impact() drops a self-freeing
    inner ImpactSpark (Node2D) at the hit point before queue_free — an expanding warm ring (draw_arc,
    r 3->14) + 4 short radial spokes, ~0.12s, z_index 100, fading to transparent. Spawned under run and
    gated on run.phase so it holds with the frozen world (level-up picker), matching the gem-sparkle /
    death-pop juice pattern; no new scene files, single file changed. Gate PASS (import validated the
    inner-class syntax + gdUnit4 + run-scene smoke which fires projectiles and makes kills, exit 0).
    Eyeball: shoot a bat in run.tscn — a brief yellow-white spark ring flashes where each shot connects.

[x] Make agent movement effective in the harness — the agent_play harness freezes the game
    (time_scale 0), sends ONE 'tap' (press+release in the same frozen frame), then unfreezes for a
    step, so the player's Input.get_vector poll saw the move action already released → ~0 displacement
    and the agent never moved. Adapter-only fix (scripts/agent/agent_adapter.gd): added MOVE_ACTIONS +
    _held_move and _hold_move() — a movement tap now HOLDS that direction (releasing any prior one) so
    get_vector reports it across the whole unfrozen step and the player travels. One direction at a
    time (an opposite without release cancels in get_vector); next tap replaces it; a noop step keeps
    it held (continuous VS-style movement). Discrete choices (choose_1/2/3, ui_accept) stay real taps.
    Gate PASS (import + gdUnit4 + run-scene smoke, exit 0). Eyeball: re-run tools/playtest-review.ps1
    with a funded balance — the agent should now walk a route instead of hovering near spawn.

[x] Tile a ground texture under the arena — the empty flat-gray field now has a floor. Offline-
    downscaled grassy_ground_tile.png (a 1024² JPEG-in-a-.png) to a clean 256² true-PNG art/ground.png
    via 4:1 area-averaging (recovers crisp native texels + averages out JPEG ringing; lossless, mipmaps
    off, NEAREST per VISUAL_RULES; verified seamless — edge-wrap diff ~24 ≈ interior baseline ~23). New
    scripts/run/ground.gd (VSGround): draws the tile seam-free across arena_half + a viewport margin
    (snapped to whole tiles) at z_index -100 with texture_repeat ENABLED, dimmed/cooled by a DUSK
    modulate (0.72,0.74,0.80) so the foreground pops; instantiated first in run.gd _build_world().
    project.godot default_clear_color set to a dark earthy green (0.03,0.07,0.02) sampled from the tile's
    shadow tones, so any rim beyond the field reads as night-swallowed ground, not flat gray. Gate PASS
    (import registered VSGround + imported ground.png + run-scene smoke, exit 0). Eyeball: open run.tscn —
    a tiled grass/dirt field under everything; player + blue gem pop; no visible tile seams; arena edge
    is still an invisible wall (queued follow-up).

[x] Juice pass: hit flash, death pop, pickup sparkle, screen shake — lightweight feedback, no new
    files. enemy.gd: over-bright white hit-flash (0.08s) on a non-lethal hit; on death the enemy leaves
    the "enemies" group (no double-kill / re-target / wasted projectiles) and plays a 0.14s scale-up +
    fade death pop before freeing (kill + gem still register immediately). gem.gd: pickup grants XP at
    once, then a 0.18s sparkle (scale-up + brighten + fade + 8-spoke star burst) plays and frees,
    independent of phase so it finishes even when the pickup triggers the level-up picker. player.gd:
    brief red over-bright hurt flash (0.12s) + camera kick via run.add_shake(7, 0.22). run.gd: stores the
    Camera2D and adds add_shake()/_update_shake() — a decaying camera.offset shake (strongest pending kick
    wins). Gate PASS (import + gdUnit4 + run-scene smoke, exit 0). Eyeball: take a hit (red flash + screen
    kick), kill a bat (white flash on chip hits, pop on death), grab a gem (sparkle burst).

[x] Add a level-up upgrade screen (choose 1 of 3) — on level-up the run enters a new "level_up"
    phase that freezes the whole field (player/enemy/spawner/weapon/gem/projectile all gate on
    phase) and shows a modal picker (scripts/ui/levelup_screen.gd, dim + 3 buttons). It offers 3 of
    4 upgrades — Power (+1 dmg), Haste (-15% fire interval), Swift (+12% move speed), Multishot (+1
    projectile, fired in a fan). The choice applies to weapon/player stats and resumes play, chaining
    pickers if one XP burst earned multiple levels. Pickable by mouse or keys 1/2/3; the agent_adapter
    now exposes choose_1/2/3 and synthesizes press/release/tap (it had been swallowing all command-
    channel input but set_seed), so the harness can pick and move. Made weapon fire_interval/damage/
    projectile_count and player speed mutable vars. Gate PASS (import + gdUnit4 + run-scene smoke).
    Eyeball: play to Lv2 (~5 gems) — field pauses, 1-3 & clicks both pick, Multishot shows a bullet fan.

[x] Replace placeholder circles with SourceArt sprites — offline-downscaled Antonio/bat/gem_blue
    into vampire-survivors-taskmaster/art (player 49x52, bat 30x15, gem 12x16; lossless, no mipmaps,
    NEAREST per VISUAL_RULES) and swapped the _draw() circles in player/enemy/gem for draw_texture
    centered on origin (player greys on death). No scene-graph changes. Gate PASS (import + gdUnit4 +
    run-scene smoke). Eyeball: open run.tscn — sprites should sit centered on their logical positions.

[x] Minimal playable slice + agent_play adapter — player/enemies/spawner/auto-weapon/projectiles/XP
    gems/HUD/game-over built in code under vampire-survivors-taskmaster/scripts; run.tscn set as main
    scene; AgentBridge adapter publishes state for the harness. Verified: clean import, 600-frame
    headless run, and a gdUnit4 smoke test (boots → spawns → makes kills) — gate green.
[x] Periodic goal-aware playtest-review loop — tools/playtest-review.ps1 (play via agent_play →
    score vs workshop/GOAL.md → write FEEL-REVIEW.md + append backlog items); Workshop PROMPT reads
    FEEL-REVIEW.md each pass. Play step's only remaining setup is a "Web" export preset (web export
    templates installed + ANTHROPIC_API_KEY present; preflight auto-detects Godot's real templates dir).
