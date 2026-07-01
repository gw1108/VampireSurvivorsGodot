# DONE — append-only log (newest on top)

Each Ralph/Workshop pass appends `[x] <title> — <what landed>` here. Union-merged across lanes
(see `.gitattributes`) so parallel appends concatenate instead of conflicting.

[x] Recycle far-off enemies so kiting never empties the field — the player (157.5) outruns every
    enemy kind (bat 46.5 / ghost 84 / brute 31.5), yet enemies only ever left the "enemies" group on
    death, so a kiter left a permanent trail of stragglers that never catch up. Once MAX_ENEMIES=90
    fills with those off-screen bodies, _spawn_one() early-returns and NO new enemies spawn around the
    player — the field ahead empties as you move, and the cap is wasted on irrelevant far-away enemies.
    enemy.gd only: added const DESPAWN_DIST=1200 and, in _process right after the already-computed
    player distance d, a cull — `if d > DESPAWN_DIST and not is_reaper: remove_from_group("enemies");
    queue_free(); return` — a silent recycle (no gem, no kill, no despawn event) that frees the cap so
    the spawner keeps refilling the SPAWN_RING (520) around the moving player. 1200px is well beyond the
    ~950px visible corner (viewport 1445x920 @ zoom 0.9) so nothing on-screen ever pops out; spawn
    distance is <=520 so a fresh enemy is never culled on spawn; the reaper is explicitly excluded so
    the finale boss always reaches the duel; _dying enemies already return earlier so corpses aren't
    culled. queue_free defers to end-of-frame but remove_from_group is immediate, so other nodes
    iterating the group this frame already skip the recycling body. One file; no scene/art/API changes;
    a different KIND (gameplay/performance) from the recent art/UI/wording passes. Gate PASS exit 0
    (import registered VSEnemy with no parse errors — validating the new const + cull — + both smoke
    tests incl. run-scene boot which spawns enemies and runs their _process through the new cull path;
    the ~6s smoke never pushes an enemy 1200px out so no early free). Eyeball (feel the gate can't
    judge): kite in one direction for a while — instead of the field going empty behind you, distant
    stragglers vanish and fresh enemies keep pouring in from the ring ahead. Tune DESPAWN_DIST by feel.

[x] Reword the victory banner to reflect slaying the Reaper — winning is now killing the summoned
    Reaper, but the victory banner still read "YOU SURVIVED!", so the climax didn't name the deed.
    hud.gd only: changed the victory headline from "YOU SURVIVED!" to "YOU SLEW DEATH!" in both
    `_ready()` (the headline-only initial text) and `refresh()` (the victory-phase banner compose),
    matching the boss banner's "SLAY DEATH" wording; kept the run-recap line and "Press Enter to play
    again" beneath it untouched, and updated the two matching comments. One file; no scene/API/art
    changes; a small end-of-run UI-wording increment. Gate PASS exit 0 (import parsed VSHud with no
    errors + both smoke tests incl. run-scene boot which builds the HUD and calls refresh()). Eyeball:
    slay the Reaper — the banner now reads "YOU SLEW DEATH!" above the "Survived M:SS   Kills N   Lv N" recap.

[x] Show a run recap (time/kills/level) on the death & victory banners — the end-of-run banners were
    static text ("YOU DIED" / "YOU SURVIVED!"), so a finished run showed no summary of what it achieved —
    a bare, unsatisfying close for a slice whose GOAL is "polished, genuinely fun." hud.gd only: added
    `_recap(run)` — returns "Survived M:SS    Kills N    Lv N" with spacing/wording matching the top
    `_stat` readout so it reads as the same run's final tally — and `_format_time(secs)` (seconds → M:SS,
    e.g. 154.0 → "2:34"). `refresh()` now composes the recap into the banner text when each banner's phase
    is active: `"YOU DIED\n\n<recap>\n\nPress Enter to retry"` for game_over and
    `"YOU SURVIVED!\n\n<recap>\n\nPress Enter to play again"` for victory. The `_ready()` initial text is
    now headline-only (a comment notes refresh() rewrites it once visible); the banners already
    center-anchor with grow-both so the extra lines stay centred at any resolution. Composed only while the
    banner is up (a static screen until Enter reloads), so the per-frame string build is negligible and
    matches the existing per-frame `_stat.text` set. One file; no scene/API/art changes; a different KIND
    (end-of-run UI/closure) from the recent hitbox/icon/orbit/balance passes. Gate PASS exit 0 (import
    parsed VSHud with the new `_recap`/`_format_time` helpers + the refresh() change, no errors, + both
    smoke tests incl. run-scene boot which builds the HUD and calls refresh() per frame). Eyeball (the ~6s
    gate never reaches a run end): die, or slay the Reaper — the banner now shows a "Survived 2:34   Kills
    187   Lv 12" summary between the headline and the retry prompt; tune wording/spacing by eye.

[x] Unify the player hitbox that collides with enemies with player getting hurt — the player had TWO
    separate circular colliders: SOLID_RADIUS=9 (blocked enemy movement) and RADIUS=14 (the contact-damage
    hurt box), each checked separately in enemy.gd, so "how close before I get hurt" and "how close before
    an enemy is stopped" were two different circles. Unified them into ONE rectangle roughly the player's
    visual footprint. player.gd: removed SOLID_RADIUS; added `const HITBOX_HALF := Vector2(16.0, 21.0)`
    (half-extents ≈ the visible body, ~32×42 vs the 49×52 sprite); kept RADIUS=14 but it now serves ONLY
    gem-pickup assist (gem.gd), not enemy contact — doc comment updated to say so. enemy.gd `_process`:
    replaced the radial solid-block push (`VSPlayer.SOLID_RADIUS + radius` along the player→enemy line) AND
    the separate circular contact check (`d < radius + VSPlayer.RADIUS`) with a single Minkowski test — the
    player rect inflated by this enemy's own `radius`. If the enemy centre is inside that inflated rect it is
    BOTH ejected along the axis of least penetration (so the round body sits flush against the flat player
    edge; +x fallback if dead-centre) AND, on the 0.5s contact cooldown, deals contact damage. So "pressed
    against the player" and "hurting the player" are now literally the same boundary — the unification the
    task asked for. Two files (player.gd, enemy.gd); no scene/art/API changes; gem pickup (still reads
    VSPlayer.RADIUS) and enemy knockback (uses the enemy's own RADIUS) are untouched. Gate PASS exit 0
    (import registered VSPlayer+VSEnemy with no parse errors — validating HITBOX_HALF and the new rect math —
    plus both smoke tests incl. run-scene boot, which spawns enemies that chase/contact the player through
    the unified collider headless). Eyeball (feel the gate can't judge): let a swarm press on you — enemies
    stop flush against a body-shaped rectangle and the damage edge matches exactly where they're blocked; the
    taller box means top/bottom contact reads a touch further out than the old r=14 circle. Tune HITBOX_HALF
    by feel.

[x] Redraw the Empty Tome (firerate) icon as a book — the firerate upgrade was renamed Empty Tome
    (cooldown) but its icon at art/icons/firerate.png was still a flaming stopwatch, mismatching the name
    while every other upgrade icon already depicts its faithful VS item. Replaced firerate.png with a
    hand-drawn pixel-art closed TOME. Authored at 32x32 native pixel-art resolution then scaled x8 to
    256x256 with NEAREST (honors VISUAL_RULES: no filtering/mipmaps, integer scale) — kept the SAME
    256x256 dimensions as the old file so the documented integer-downscale invariant still holds (256->32
    via /8 for the level-up picker's ICON_MAX 32, 256->16 via /16 for the HUD loadout's LOADOUT_ICON_PX
    16; both NEAREST downscales were rendered and verified to still read as a book). Made it a TEAL magic
    tome — teal cover, gold ornate inset frame, cyan center gem, cream page edges peeking on the
    right+bottom, dark spine on the left — with a 1px black silhouette outline, deliberately distinct from
    the brown KJV bible orbit icon so the two book items never read the same. ONLY art/icons/firerate.png
    changed; the .import is untouched (same 256x256 RGBA PNG — the gate's headless import reimported it) and
    no script/scene/key changes were needed since levelup_screen.gd (ICONS) and hud.gd (ICONS) already
    preload res://art/icons/firerate.png by the 'firerate' key, so the new art shows with zero code change.
    Gate PASS exit 0 (godot --import reimported firerate.png with no errors + both smoke tests incl.
    run-scene boot). Eyeball (art the gate can't judge): open a level-up — the Empty Tome choice now shows
    a teal book instead of a flaming clock, and the bottom-left HUD loadout shows the same book at 16px;
    tune the palette/frame by eye.

[x] Reskin the King Bible orbit visual from blades to tomes — the orbit weapon was renamed King Bible
    (matching its bible icon + the GDD) but orbit.gd still drew steel blade polygons, a mismatch left over
    from the old "Blades" upgrade. orbit.gd (VSOrbit._draw) only: replaced the pointed blade-polygon +
    core glint at each orbit point with a small spinning holy book, drawn from primitives like the rest of
    the juice. New _draw_tome(lp, along, flat, bright) draws a closed book — a cream cover quad (Color
    0.90,0.86,0.72, lerped toward white by _pulse on a connecting tick), a dark-leather spine band on the
    -flat long edge (0.42,0.24,0.14), a bright page fore-edge on the +flat long edge (1.0,0.98,0.90), and a
    gold cross on the face (two draw_line bars, alpha 0.6 + _pulse*0.4). The book's local basis (along =
    tangent to travel, flat = radial) comes from the ring angle so each tome tumbles as it flies. Recolored
    the faint orbit path ring from steely blue to gold (0.95,0.85,0.50,0.12), and updated the class doc
    header (Blades → King Bible / N holy tomes). run.gd: King Bible picker desc changed from "Orbiting
    attack that strikes nearby foes" to "Spinning holy tomes that strike nearby foes". Two files (orbit.gd +
    run.gd); no scene/art/API changes; damage/count/spin/orbit_radius/level_up + the _tick hit logic are
    untouched so the weapon behaves identically. Gate PASS exit 0 (import registered VSOrbit+VSRun with no
    parse errors — validating _draw_tome + the recolored ring — + both smoke tests incl. run-scene boot; the
    ~6s smoke test never reaches a level-up so King Bible isn't picked and _draw_tome is parse-validated, not
    run at runtime). Eyeball (visual the gate can't judge): pick King Bible at a level-up — small cream books
    with a gold cross spin around Antonio instead of steel blades; tune HL/HW (book size) and the
    cover/spine/page colors by eye.

[x] Fix passive item movespeed (Wings +12%) — the Wings (speed) passive applied
    `player.speed *= 1.12`, so the "+12% move speed" label was inaccurate under stacking:
    multiplicative compounding (1.12^n) made each successive pick worth >12% of base and could
    balloon a stacked player past the gem magnet's edge speed (gem.gd MAGNET_SPEED_MIN 230),
    stranding XP behind a fleeing kiter (a documented concern). Fixed to a clean additive
    +12%-of-base per pick: player.gd now defines `const BASE_SPEED := 157.5` with
    `var speed := BASE_SPEED`, and run.gd apply_upgrade("speed") does
    `player.speed += VSPlayer.BASE_SPEED * 0.12`. Pick 1 is unchanged (157.5 → 176.4, same as
    *1.12); after that speed grows linearly at +18.9 px/s/pick, so the label is literally true at
    every stack and late picks no longer runaway. Two files (player.gd, run.gd); no scene/art/API
    changes. Gate PASS exit 0 (import registered VSPlayer+VSRun with no parse errors — validating
    the new const + the VSPlayer.BASE_SPEED reference in run.gd — + both smoke tests incl. run-scene
    boot which runs apply_upgrade headless). Eyeball: stack Wings a few times and feel the movement
    speed rise in even, predictable steps.

[x] Whip rework again — reworked the Multishot whip layout. A single whip now cracks FLAT toward the
    player's facing (box centre HSEP to the facing side, NO vertical offset) instead of a diagonal NE/NW
    corner. Multishot adds cracks alternating BACKWARD then FORWARD, each stacking one VSEP row UP on its
    own side: forward indices (even i) climb rows 0,1,2…; backward indices (odd i) climb rows 1,2,3… — so
    a 4-stack reads forward@row0 / NW@row1 / forward@row1 / NW@row2 (a forward column + a backward column
    climbing off the player, matching the task's WWW/WWW…[player]WWW sketch). whip.gd only: removed the
    old _alt up/down toggle and _swing_dirs(); new _swing_strikes(n) returns (hsign,row) packed in a
    Vector2 in Multishot order; _strike(hsign,row) centres the AABB pierce box at global_position +
    (HSEP*hsign, -VSEP*row); _spawn_slash(centre,hsign) mirrors the slash VFX purely by world horizontal
    sign (hsign<0 → -SLASH_ROT + scale.x flip). MAX_DIRS stays 4 (also the Duplicator cap in run.gd);
    fire_count/fire_interval/damage/projectile_count untouched so the smoke test + upgrades are
    unaffected. Gate PASS exit 0 (import + both smoke tests). Eyeball: facing right, a single whip cracks
    straight east at body height; Duplicator adds NW, then forward stacked above, then backward stacked
    above — two columns climbing off Antonio. Tune VSEP row spacing by eye.

[x] Pipeestrello variants — every bat shared one sprite, so a dense pack read as identical clones. We
    have no per-variant bat art, so per the task we vary the existing sprite's SIZE. spawner.gd
    _apply_kind only: added an explicit `else` bat branch (the bat was previously the implicit fallback
    that just kept the VSEnemy defaults) that picks one of three size variants — small/normal/large via
    `vscale := 0.9 + float(randi() % 3) * 0.1` (0.9 / 1.0 / 1.1) — and sets `e.base_scale = vscale` plus
    `e.radius = VSEnemy.RADIUS * vscale` so the swarm reads as a crowd of differently-sized creatures
    instead of one stamped texture. Radius tracks the scale so what-you-see is still what-you-hit;
    HP/damage/speed stay at the bat baseline (this is visual variety, not a new toughness tier), and
    _apply_difficulty's `*=` base_scale/radius tier growth still stacks on top so a hardened bat keeps its
    variant size. ghost/brute/reaper untouched. One file; no scene/art/API changes. Gate PASS exit 0
    (import registered VSSpawner with no parse errors — validating the new else branch + the
    `VSEnemy.RADIUS` reference — + both smoke tests incl. run-scene boot which spawns bats and runs their
    _draw through base_scale). Eyeball (feel the gate can't judge): play a wave — the bats should now be a
    mix of slightly smaller and larger bodies rather than identical clones; tune the ±10% spread by feel.

[x] Remove items/passives that should not exist — the level-up pool used INVENTED names that aren't
    in the GDD slice roster (thoughts/shared/game-design), out of sync with the already-faithful icon
    art. Renamed run.gd UPGRADES titles/descs to the canonical Vampire Survivors items (keys + both
    ICONS dicts + hud _title_for unchanged, so apply_upgrade still keys off them): Power→Spinach (leaf
    icon), Haste→Empty Tome (cooldown), Swift→Wings (winged-boots icon), Multishot→Duplicator (gold-ring
    icon), Blades→King Bible (the orbit icon was already a KJV bible). The made-up "Vitality"/regen is
    Pummarola/HP-recovery, which the GDD explicitly marks *not in slice* — reworked it into Hollow Heart
    (+20% max HP per pick, healing by the gain), a REAL slice passive the heart-"+1" icon already
    depicts: apply_upgrade("regen") now raises player.max_health/health instead of regen, and the
    now-dead `var regen` + its _process recovery loop were removed from player.gd (the stale Vitality
    reference in take_damage's Armor comment trimmed too). Also corrected run.gd's _roll_upgrades comment
    (Multishot→Duplicator). The agent adapter already reports health/max_health, so Hollow Heart shows to
    the harness with no adapter change. Two files (run.gd + player.gd); no scene/art/key/icon changes —
    every pool item now maps to a GDD weapon (Garlic, King Bible, Magic Wand) or passive (Spinach, Empty
    Tome, Wings, Duplicator, Hollow Heart, Armor), with Whip as the starter. Gate PASS exit 0 (import
    registered VSPlayer+VSRun with no parse errors — validating the reworked match arm and the field
    removal — + both smoke tests incl. run-scene boot which drives apply_upgrade). Eyeball (feel the gate
    can't judge): level up and confirm the picker reads the faithful names, and Hollow Heart widens the
    health bar (more max HP) rather than trickling HP back. Follow-ups queued: reskin the King Bible
    orbit visual (still steel blades) to tomes, and redraw the Empty Tome icon (still a flaming clock).

[x] Subtle small black outline by default — bodies blended into the busy ground (GOAL readability /
    FEEL-REVIEW "flat presentation"). Added a subtle thin black rim around the player and every enemy
    kind WITHOUT a shader/material/scene/art: the sprite silhouette drawn tinted SOLID black
    (OUTLINE_COLOR Color(0,0,0,0.7)) at 8 small offsets (OUTLINE_PX 1.5, diagonals normalized to unit
    length so the rim is even) BEHIND the real sprite — modulate keeps transparent pixels clear, so only
    the silhouette darkens (no box). player.gd: new _draw_outline(rect) reuses the same flipped facing
    rect, drawn between the ground shadow and the sprite (always, incl. the greyed death sprite).
    enemy.gd: the offset copies draw inside the existing draw_set_transform(scale), so the rim scales with
    the sprite (a brute/reaper gets a proportionally thicker rim), and are skipped while _dying so the
    bright fading death pop stays clean. New OUTLINE_COLOR/OUTLINE_PX/OUTLINE_OFFSETS consts (typed const
    Array[Vector2], matching whip.gd's DIRS) in both files. Two files (player.gd + enemy.gd); no
    scene/art/API changes. Gate PASS exit 0 (import registered VSPlayer+VSEnemy with no parse errors —
    validating the typed const array + the new outline draws — + both smoke tests incl. run-scene boot
    which spawns the player/enemies and runs their _draw through the outline path). Eyeball (feel the gate
    can't judge): the player and every enemy kind now carry a thin black rim that pops them off the
    background; tune OUTLINE_PX / the 0.7 alpha by feel.

[x] Simple blob shadow for player + enemies — the presentation read flat/floaty (FEEL-REVIEW
    flagged it), so bodies didn't sit on the ground. Added a soft, flattened dark-ellipse ground
    shadow under the feet, drawn FIRST in each entity's _draw() (above the z=-100 ground, beneath
    its own sprite) via a non-uniform draw_set_transform that squashes a draw_circle into a ground
    ellipse, then resets the transform. player.gd: new SHADOW_COLOR/SHADOW_W_FRAC/SHADOW_FLATTEN/
    SHADOW_LIFT consts + _draw_shadow() called at the top of _draw() (also shows on death). enemy.gd:
    _draw_shadow(alpha_mul) sized to the RESTING footprint (× base_scale, so a brute/reaper casts a
    bigger shadow than a bat) and faded out with the death pop's p; called before the existing
    sprite-scale transform. Two files (player.gd + enemy.gd); no scene/art/API changes. Gate PASS
    exit 0 (import registered VSPlayer+VSEnemy with no parse errors + both smoke tests incl. the
    run-scene boot, which spawns the player/enemies and runs their _draw). Eyeball (feel the gate
    can't judge): a soft oval shadow hugs the feet of the player and every enemy kind, growing for
    the brute/reaper; tune the alpha/flatten by feel.

[x] Show upgrade icons in the HUD loadout readout too — the bottom-left owned-build readout
    (hud.gd refresh_loadout) was text-only ("Power Lv2") while the level-up picker already shows item
    icons, so the owned build and the picker read inconsistently. hud.gd ONLY: added an ICONS preload
    set (the same res://art/icons/<key>.png art VSLevelUpScreen.ICONS uses, keyed by the VSRun.UPGRADES
    key) + const LOADOUT_ICON_PX 16 (64->16 ×4 and 256->16 ×16 are integer downscales — crisp on
    NEAREST). Changed _loadout from a Label to a VBoxContainer (still bottom-left, grows up, separation
    2, MOUSE_FILTER_IGNORE) built in _ready. refresh_loadout now queue_frees the previous rows and
    rebuilds one HBoxContainer per owned upgrade (acquisition order preserved by the Dictionary): a 16px
    TextureRect icon (EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_CENTERED; NO per-node texture_filter
    override, so it keeps the project NEAREST default per VISUAL_RULES) + an outlined "LvN" Label;
    falls back to "<title>  LvN" text when an upgrade has no icon (keeps _title_for). No scene/art/API
    changes — one file. Gate PASS exit 0 (import registered VSHud with no parse errors + both smoke
    tests incl. run-scene boot, which builds the HUD via _ready; the ~6s smoke test doesn't reach a
    level-up so refresh_loadout itself is parse-validated). Eyeball (feel the gate can't judge): pick a
    couple of upgrades and confirm the bottom-left readout shows crisp 16px item icons with "LvN"
    beside them, rows growing upward, matching the picker.

[x] Pre-spawn 'DEATH APPROACHES' warning before the Reaper — the finale telegraphed only at the
    instant the Reaper spawned (the 14-magnitude summon quake + the "THE REAPER COMES" banner), so it
    sprang with no foreshadowing. Added a build-up in the last few seconds before SURVIVE_SECONDS.
    run.gd: new consts REAPER_WARN_SECONDS 4.0 / REAPER_WARN_SHAKE_MIN 1.5 / REAPER_WARN_SHAKE_MAX 6.0
    (kept under the 14 summon quake) + a _reaper_warned once-guard. _process's summon check is now
    `if not _reaper_summoned: if elapsed >= SURVIVE_SECONDS: _summon_reaper() elif elapsed >=
    SURVIVE_SECONDS - REAPER_WARN_SECONDS: _warn_reaper()`. _warn_reaper() fires a one-time AgentBridge
    "reaper_warning" {time} event (so the headless FEEL reviewer, which can't see shake, observes the
    build-up) and each frame calls add_shake(lerpf(MIN,MAX,p), 0.25) with p = window progress 0->1 —
    add_shake takes the strongest pending kick, so a per-frame rising magnitude over a sustained 0.25s
    window yields a growing tremor that then hands off to the bigger 14 summon quake. hud.gd: new
    _warning Label "DEATH APPROACHES" (blood-red 0.95,0.10,0.12, font_size 30, outline 6, CENTER_TOP
    offset_top 44 — the same top slot the boss banner takes over) + const WARN_FLASH_HZ 3.0; refresh()
    shows it only while phase=="playing" and not reaper_alive and SURVIVE_SECONDS-REAPER_WARN_SECONDS <=
    elapsed < SURVIVE_SECONDS (so it hands off cleanly to "THE REAPER COMES" at the summon, never both at
    once) and pulses modulate.a via 0.25 + 0.75*(0.5 + 0.5*sin(t * WARN_FLASH_HZ * TAU)) so it flashes
    urgently. Two files (run.gd + hud.gd); no scene/art/API changes; the ~6s smoke test never reaches the
    296-300s window so reaper==null and the warning never shows — no regression. Gate PASS exit 0 (import
    registered VSRun+VSHud with no parse errors — validating the new consts, _warn_reaper, and the warning
    label/flash — + both smoke tests incl. run-scene boot which builds the HUD and runs the controller
    through _process/refresh each frame). Eyeball (feel the gate can't judge): lower SURVIVE_SECONDS to
    test quickly — in the last ~4s before Death descends a flashing red "DEATH APPROACHES" banner appears
    over a rising rumble, then it cuts to "THE REAPER COMES" + the big summon quake as the Reaper drops in.
    Tune REAPER_WARN_SECONDS / shake min-max / WARN_FLASH_HZ by feel.

[x] Boss HP bar for the Reaper finale — the Reaper (REAPER_HP 400) had only the banner, no health
    readout, so the duel gave no sense of progress. hud.gd (VSHud) only: a wide blood-red boss HP bar
    under the "THE REAPER COMES" banner. New consts BOSS_BAR_TOP 82 / BOSS_BAR_H 16 / BOSS_BAR_LEFT 0.2
    / BOSS_BAR_RIGHT 0.8 (anchors -> centre 60% of the viewport, centred at any width) / BOSS_BAR_TRACK
    (dark = drained) / BOSS_BAR_FILL (blood-red = Death's life). _ready builds two anchored ColorRects
    under the banner — a track + a fill on top, both MOUSE_FILTER_IGNORE, hidden until the Reaper is up.
    refresh() hoists the banner's "reaper_alive" test (phase=="playing" and run.reaper valid) to a local,
    reuses it for _boss.visible + both rects' visibility, and when alive drives the fill's right edge:
    anchor_right = BOSS_BAR_LEFT + (BOSS_BAR_RIGHT-BOSS_BAR_LEFT) * clampf(run.reaper.health /
    VSSpawner.REAPER_HP, 0, 1) — red drains right-to-left as Death is chipped, the dark track showing as
    lost HP. health is read only inside the reaper_alive guard, and _on_reaper_killed nulls reaper before
    phase flips to victory, so the bar hides cleanly on the kill (no null deref / zero-width flash). One
    file; no scene/art/API changes; the ~6s smoke test never hits 300s so reaper==null and the bar stays
    hidden — no regression. Gate PASS exit 0 (import parsed VSHud — validating the ColorRects, the
    VSSpawner.REAPER_HP reference, and the clampf ratio — + both smoke tests incl. run-scene boot which
    builds the HUD and calls refresh() per frame). Eyeball: lower SURVIVE_SECONDS to test quickly — when
    Death descends a wide blood-red bar appears under the banner and drains as you plink the Reaper down,
    then vanishes on the kill.

[x] Stop offering Multishot once the whip is maxed (no dead-choice trap) — the whip caps at
    VSWhip.MAX_DIRS=4 corners (n := clampi(projectile_count, 1, MAX_DIRS) in _fire), so a 4th+
    Multishot pick cost a level-up choice for ZERO effect. run.gd only: _roll_upgrades() now filters
    UPGRADES through a new _is_maxed(key) before shuffle()/slice(0,3); _is_maxed drops 'projectile'
    once weapon.projectile_count >= VSWhip.MAX_DIRS (the only capped upgrade today, else false), so a
    fully-stacked whip never offers the dead pick. 8 upgrades remain so slice(0,3) still yields 3.
    Gate PASS exit 0 (import parsed VSRun + both smoke tests incl. run-scene boot). Eyeball: cap
    Multishot at 4 corners, keep leveling — it no longer appears among the 3 offered choices.

[x] Flashing-colors XP bar during the level-up picker — during level_up the leftover xp had
    already been subtracted (VSRun._check_level_up's `xp -= need`), so the top-of-screen XP bar sat
    near-empty during the big moment. hud.gd (VSHud) only: refresh() now branches on run.phase — when
    phase=="level_up" it forces _xp_fill.anchor_right = 1.0 (bar shows FULL) and flashes the color by
    cycling the hue via Color.from_hsv(fmod(Time.get_ticks_msec()/1000.0 * XP_FLASH_HZ, 1.0), 0.8, 1.0,
    0.95) (new const XP_FLASH_HZ=1.5 full-rainbow cycles/sec); the normal branch restores the steady
    cyan-blue XP_FILL_COLOR (0.40,0.78,1.0,0.95 — extracted to a const, reused in _ready) and the
    xp/(level*5) fill ratio, so the bar snaps back to normal once the picker closes. refresh() is called
    every frame from run._process regardless of phase, so the flash animates while the world is frozen.
    One file; no scene/API changes. Gate PASS exit 0 (import parsed VSHud with no parse errors —
    validating Color.from_hsv / Time.get_ticks_msec — + both smoke tests incl. run-scene boot which
    builds the HUD and calls refresh() per frame). Eyeball: play to a level-up — the top XP bar appears
    full and rapidly cycles through colors while the picker is open, then returns to the blue progress
    fill when you pick.

[x] Level-up picker shows weapon/passive icons — the choice buttons were text-only; now each shows
    its item icon to the LEFT of the label. Imported 9 matching icons from SourceArt/extracted_clean
    into res://art/icons/ named by upgrade key (spinach->damage, fire_clock->firerate,
    winged_boots->speed, duplicator_ring_blue->projectile, garlic, bible->orbit, magic_wand->wand,
    plus_heart->regen, armor). levelup_screen.gd: new const ICONS (key->preloaded Texture2D) +
    ICON_MAX 32; each Button gets icon=ICONS[key], alignment=LEFT, icon_max_width=32 theme const,
    h_separation=10. Square 64/256px sources cap to 32 by an integer ratio (÷2, ÷8) so they stay crisp
    on the project's NEAREST filter (VISUAL_RULES; no per-node filter override). One script edit + 9
    PNGs(+9 .import). Gate PASS exit 0 (import reimported all 9 icons + both smoke tests incl. run-scene
    boot which loads VSLevelUpScreen so the preload dict resolves). Eyeball: at a level-up each of the 3
    choices shows its item icon on the left.

[x] Replace the instant survival-victory with a Reaper boss finale — faithful to VS, reaching
    SURVIVE_SECONDS no longer instantly wins; it summons Death, and the run is WON by slaying it.
    run.gd: _process now calls _summon_reaper() (was _on_victory()) at the time limit, once-guarded
    by `_reaper_summoned`; new fields `spawner: VSSpawner` (the _build_world local is now a field),
    `reaper: VSEnemy`, `_reaper_summoned`. _summon_reaper() asks the spawner to build the boss, stores
    run.reaper, kicks add_shake(14,0.6) and emits AgentBridge "reaper_summoned" {time} (no audio —
    GOAL minimizes sfx; the shake + giant sprite + banner carry the telegraph). Victory now fires only
    from _on_reaper_killed() — phase=="playing"-guarded so a same-frame player death can't be
    overwritten and a double lethal hit can't double-fire — which nulls reaper then calls _on_victory()
    (its guard tightened to `if phase != "playing": return`). The world stays "playing" during the duel
    so the player fights Death; on the kill phase flips to "victory" and freezes everything (incl. the
    boss mid-death-pop). spawner.gd: new summon_reaper() builds ONE VSEnemy on the SPAWN_RING with
    is_reaper=true, the ghost sprite tinted dark wraith-purple (0.55,0.42,0.72), base_scale 2.6,
    radius 40, speed 38 (kitable — player 157.5), health REAPER_HP 400, contact 30, xp 50; and _process
    early-returns while run.reaper is alive so the regular waves halt for a focused duel. enemy.gd: new
    `is_reaper` flag; hit()'s lethal branch calls run._on_reaper_killed() when set. hud.gd: new _boss
    Label ("THE REAPER COMES — SLAY DEATH") pinned top-center, shown while phase=="playing" and
    run.reaper is alive. Four files (run/spawner/enemy/hud); no scene/art/API changes; the ~6s smoke
    test never reaches 300s so reaper==null and the spawner runs normally — no regression. Gate PASS
    exit 0 (import registered VSEnemy/VSSpawner/VSRun/VSHud with no parse errors + both smoke tests incl.
    run-scene boot which builds the world with the new spawner field and runs the controller through
    _process). Eyeball (feel/balance the gate can't judge): lower SURVIVE_SECONDS to test quickly — at
    the time limit the ground quakes, a giant dark wraith descends from the edge, regular spawns stop,
    and "THE REAPER COMES" shows; kite + plink it down to win (gold "YOU SURVIVED!"), or it corners and
    kills you (game over). Tune REAPER_HP (400) / contact 30 / speed 38 / scale by feel.

[x] Whip strikes the way the player faces — whip.gd now reads the player's facing (its parent's
    `_facing` via get_parent()) instead of blind-cycling NE->SE->SW->NW. A single whip cracks the
    facing-side corner (right -> NE, left -> NW) and alternates up/down each swing (`_alt` toggle,
    replacing the old `_dir` index). Multishot grows the swing facing-first: 2nd strike mirrors to the
    OPPOSITE side at the same vertical, 3rd/4th add the other vertical of each side — so a stacked whip
    sweeps the top pair then the bottom pair, capped at MAX_DIRS=4 (every corner), per "max 4
    directional". New `_facing_sign()` (falls back to +1/right if not parented to a VSPlayer) and
    `_swing_dirs()` build the ordered corner sign-vectors; `_strike()` now takes the sign vector
    directly (was a DIRS index). The per-corner slash VFX mirroring (`_spawn_slash`) is unchanged — it
    keys off the same sign vector. One file (whip.gd); the smoke test reads `fire_count` which is
    untouched. Gate PASS exit 0 (import + both smoke tests incl. run-scene boot which swings the whip).
    Eyeball: walk right -> slash cracks upper-right; walk left -> flips upper-left; Multishot mirrors
    to the opposite flank and tops out covering all four corners.

[x] Reduce base speed of everybody 25% + 50% more starting/spawning monsters — a slower, denser
    slice. Cut every moving-character base speed 25% (relative speeds preserved, so kiting is
    unchanged and the player still outruns all kinds): player.gd 210 -> 157.5; enemy.gd bat 62 ->
    46.5; spawner.gd brute 42 -> 31.5, ghost 112 -> 84.0. Spawn rate +50% in ONE expression —
    spawner.gd `var rate := (1.0 + run.elapsed / 20.0) * 1.5`: the *1.5 lifts BOTH the starting count
    (the 1.0 base, now 1.5 enemies/sec at t=0 — the "starting monsters") AND the time-ramp ("rate of
    monsters spawning") 50%, so the field is denser from the opening and ramps harder; MAX_ENEMIES 90
    still caps the on-screen count so performance stays bounded. Updated the inline comments that
    quoted the old numbers (the ghost/brute speed comments + the _apply_kind doc's "player at 210") to
    the new values so they stay honest. The gem magnet's MAGNET_SPEED_MAX 560 stays comfortably above
    the new 157.5 top speed, so no XP is stranded; the smoke test's run.weapon.fire_count>0 progress
    signal is weapon-only, so it's unaffected. Three files (player.gd, enemy.gd, spawner.gd); no
    scene/art/API changes. Gate PASS exit 0 (import registered VSPlayer/VSEnemy/VSSpawner with no parse
    errors + both smoke tests incl. run-scene boot which spawns enemies and runs the controller through
    the new speed/spawn path). Eyeball (feel/balance the gate can't judge): play — everyone moves
    noticeably slower and more enemies pour in from the start; tune the 0.75 speed / 1.5 spawn factors
    by feel.

[x] Whip VFX rotation should be horizontal — the whip slashes read as steep up-right/down-left
    diagonals (the user reported "NE vertically"); the base SLASH_ROT 0.6 only nudged the already-
    diagonal warrior-VFX sprite. whip.gd only. Bumped SLASH_ROT 0.6 -> 1.0 — the rotation that lays
    the diagonal slash MOSTLY HORIZONTAL with a slight outward tilt — and rewrote _spawn_slash's
    per-corner transform. The four corners fall on two diagonals: the "/" corners NE & SW
    (s.x*s.y < 0) use +SLASH_ROT with no flip (outer end tilts UP at NE / DOWN at SW); the "\" corners
    SE & NW (s.x*s.y > 0) are the horizontal-axis mirror, realised as -SLASH_ROT AND a HORIZONTAL flip
    (scale.x = -SLASH_SCALE) — so the SE crack comes out flipped horizontally and tilts DOWN (the
    mirror of NE), NW its left-side twin. This replaces the old rot / -rot / PI-rot point-reflection
    that kept every swing diagonal. The engine rotation sign was pinned from the user's ground truth
    (the current +0.6 reads vertical => engine(g) == PIL.rotate(-deg g)) and the exact 4-corner layout
    was validated by rendering the real whip_slash.png frames at engine transforms before editing.
    Position logic (DIRS / HSEP / VSEP) and the stat fields (damage/fire_interval/projectile_count/
    fire_count) are untouched, so Power/Haste/Multishot and the run-scene smoke test work unchanged.
    One file; no scene/art/API changes. Gate PASS exit 0 (import registered VSWhip with no parse errors
    + both smoke tests incl. run-scene boot which swings the whip through _fire -> _strike ->
    _spawn_slash headless). Eyeball (VFX, the gate can't judge orientation): play — the whip should
    crack as four mostly-horizontal slashes around Antonio (NE/NW tilting up-and-out, SE/SW down-and-
    out) with SE visibly flipped horizontally; tune SLASH_ROT (1.0) if the tilt is too much/little.

[x] Add a survival-time victory state (win condition) — the run could only be LOST (game_over), never
    WON, so the build-up toward the mid-run power spike had nothing to survive TO. Added the counterpart
    to game_over. run.gd: const SURVIVE_SECONDS := 300.0 (tunable 5:00 slice goal); _process checks
    `if elapsed >= SURVIVE_SECONDS: _on_victory()` inside the existing `phase == "playing"` block (elapsed
    only ticks while playing, so it fires once); _on_victory() sets phase="victory" (re-entry guarded),
    which freezes the whole world EXACTLY like game_over since every entity gates on phase=="playing"
    (player/enemy/spawner/weapon/gem/projectile/aura/orbit), emits AgentBridge "victory" {time,kills,level},
    and reuses the rising C-E-G-C level-up fanfare as a triumphant win sting (the descending "gameover"
    stinger's opposite — no new asset); _unhandled_input restarts on Enter for victory too (was game_over
    only). hud.gd: new gold _win banner ("YOU SURVIVED!\nPress Enter to play again") mirroring the death
    banner, shown when phase=="victory"; the Time readout now shows the goal ("Time Xs / 300s") so the run
    has a legible destination. agent_adapter.gd: _actions() returns ["ui_accept"] for victory too so the
    harness can restart. Three files; no scene/art/API changes; a different KIND (run-lifecycle/win
    condition) from the recent juice/passive/pickup passes. Smoke test runs only ~6s so it never trips the
    300s goal — no regression. Gate PASS exit 0 (import registered VSRun+VSHud, both smoke tests incl.
    run-scene boot which drives _process through the victory check). Eyeball: survive to 5:00 (or lower
    SURVIVE_SECONDS to test) — the field freezes and a gold "YOU SURVIVED!" banner shows; Enter restarts.

[x] Level-up burst VFX on the player when the run resumes — punctuated the power spike with a golden
    bloom on the player, alongside the gem vacuum-sweep. The level-up moment had the gems streak in but
    no flourish on the hero himself. run.gd: new self-freeing inner Node2D `LevelUpBurst` (DUR 0.5s,
    z_index 120) modeled on projectile.gd's `ImpactSpark` — a soft warm-gold central flash (brightest at
    the instant of choice, gone by mid-life), an expanding golden halo ring (r 8→66, fading), a tighter
    trailing core ring for depth, and an 8-ray sunburst — all drawn with primitives like the rest of the
    juice and phase-gated on `run.phase` so it holds with a frozen world (a chained picker) and frees
    itself. `_spawn_levelup_burst()` lazily parents one on the player (centered, null-guarded), called
    from `_on_upgrade_chosen` right after phase returns to "playing" — so the bloom plays exactly as the
    world unfreezes. Gate PASS exit 0 (import registered VSRun + both smoke tests incl. run-scene boot).
    Eyeball: pick an upgrade — a golden ring + sunburst blooms off Antonio as the run resumes.

[x] Vacuum all on-screen XP gems to the player on level-up — leveling up now triggers the iconic VS
    sweep: every gem on the field streaks into the player. The gem magnet only homed within MAGNET 140px
    and froze entirely during the level-up picker, so far-flung gems from a kited death-pile could sit
    orphaned while the run resumed. gem.gd: new public `vacuum` flag; _process gains a branch ABOVE the
    normal ramped magnet — `if vacuum and d > 0.5: position += to/d * MAGNET_SPEED_MAX * delta` — homing
    the gem to the player regardless of distance at the 560 px/s snap speed (already kept above any player
    speed, so even distant gems catch up and none are stranded); the existing `if run.phase != "playing":
    return` keeps it frozen until the world unfreezes. run.gd _show_level_up(): right after phase =
    "level_up", loops `get_tree().get_nodes_in_group("gems")` setting `g.vacuum = true` — so the flag is
    raised while the picker freezes the world, and the rush actually PLAYS as _on_upgrade_chosen returns
    phase to "playing" and the world unfreezes (gated on the existing phase resume, exactly as specced).
    Idempotent across a chained multi-level XP burst (the chained _show_level_up just re-flags). Two files
    (gem.gd + run.gd); no scene/art/API changes; the normal magnet feel is untouched when vacuum is false
    (no regression), and a different KIND (core-loop level-up feel) from the recent magnet/passive passes.
    Gate PASS exit 0 (import registered VSGem+VSRun with no parse errors — validating the new vacuum branch
    and the group loop — + both smoke tests incl. run-scene boot which spawns, kills, and collects gems and
    runs the controller through the level-up path headless). Eyeball: play to a level-up — when you pick an
    upgrade and the world unfreezes, every on-screen gem streaks into you in a satisfying burst, leaving no
    orphaned XP behind. Tune MAGNET_SPEED_MAX if the rush feels too fast/slow.

[x] Stronger XP-gem magnet so kiting never strands XP — the gem magnet (MAGNET_SPEED 240 px/s)
    barely beat the player's 210 base speed and LOST to a Swift-stacked player (210*1.12^2 ~= 263),
    so a kiter fleeing the death-pile left gems chasing at only ~30 px/s net — and once Swift stacked
    they could never catch up, stranding XP and starving the level-up loop the GOAL centers on. The
    pull was also flat/sluggish with no satisfying vacuum snap. gem.gd only: MAGNET range 95->140 (a
    touch wider so your wake gets swept up) and the flat MAGNET_SPEED replaced by a distance-ramped
    pull — t = 1 - clampf(d/MAGNET,0,1) (0 at the edge, 1 at pickup), sp = lerpf(MAGNET_SPEED_MIN 230,
    MAGNET_SPEED_MAX 560, t) — so a gem starts homing gently at the edge and accelerates into a
    vacuum-snap right before pickup, with the peak (560) kept comfortably above any player speed
    (base 210, Swift-stacked higher) so a fleeing player's gems always catch up. Pickup geometry
    (d < PICKUP+RADIUS) and the post-pickup sparkle are untouched; one constant pair + ~4 lines in
    _process; no scene/art/API changes; a different KIND (core-loop pickup feel) from the recent
    survivability/physics/passive passes. Gate PASS exit 0 (import registered VSGem with no parse
    errors — validating the lerpf/clampf ramp — + both smoke tests incl. run-scene boot which spawns,
    kills, and collects gems through the new magnet path headless). Eyeball: kite a swarm and run past
    the gems your kills drop — they should now snap up into you with a satisfying vacuum even while
    you're moving away, and stacking Swift no longer leaves a trail of uncollected XP behind you. Tune
    MAGNET / MAGNET_SPEED_MIN / MAGNET_SPEED_MAX by feel.

[x] Armor passive (flat contact-damage reduction) — the only defensive option was Vitality's HP
    regen (recovery); there was no mitigation, the other half of VS defensive flavor (Pummarola vs
    armor). Added Armor as the mitigation counterpart. player.gd: new `var armor := 0.0` beside
    `regen`; take_damage now reduces the incoming hit at the TOP via `if armor > 0.0: amount =
    maxf(1.0, amount - armor)` — floored at 1 so stacking can never make you invulnerable and a touch
    always still stings, and placed before `health -= amount` / the "damage" event / the hurt flash so
    all three read the actual mitigated damage. take_damage is only ever called from enemy contact
    (enemy.gd:75), so this is exactly "flat contact-damage reduction." run.gd: added
    {key:armor,title:Armor,desc:"Take less contact damage"} to UPGRADES (pool now offers 3 of 9) + an
    apply_upgrade("armor") case stacking player.armor += 1.0 per pick. The picker UI (reads the rolled
    UPGRADES) and the HUD loadout (_title_for iterates UPGRADES) pick it up automatically — no UI
    changes; a survivability KIND that completes the recovery-vs-mitigation defensive choice. Two files
    (player.gd + run.gd); no scene/art/API changes. Gate PASS exit 0 (import registered VSPlayer+VSRun
    with no parse errors — validating the new field, the "armor" match arm, and the 9th UPGRADES entry
    — + both smoke tests incl. run-scene boot which builds the world and runs the controller through
    apply_upgrade). Eyeball: take Armor at a level-up, then let a bat chip you — each contact hit lands
    for noticeably less; stack it and the swarm becomes a survivable trickle, but a hit never drops
    below 1 damage. Tune the +1.0 step by feel.

[x] Vitality (HP-regen) survivability passive — the level-up pool was pure-offense (Power/Haste/
    Swift/Multishot/Garlic/Blades/Magic Wand) with zero sustain, so a long run was pure attrition and a
    player could die before the GOAL's "satisfying mid-run power spike." Added the first DEFENSIVE option,
    mirroring VS's Pummarola, so the central offense-vs-defense level-up tension finally exists. player.gd:
    new `var regen := 0.0` (HP/sec) + a per-frame heal in _process on the PLAYING path only (after the
    alive + run.phase=="playing" guards, so it never ticks while dead or frozen) and only when regen>0 and
    health<max_health: health = minf(max_health, health + regen*delta); the existing end-of-_process
    queue_redraw repaints the diegetic health bar so the refill reads. run.gd: added
    {"key":"regen","title":"Vitality","desc":"Recover health over time"} to UPGRADES (pool now offers 3 of
    8) + an apply_upgrade("regen") case that stacks player.regen += 0.6 HP/s per pick. The picker UI
    (levelup_screen reads the rolled UPGRADES) and the HUD loadout (_title_for iterates UPGRADES) pick it up
    automatically — no UI changes. Two files (player.gd + run.gd); no scene/art/API changes; a different
    KIND (survivability) from the recent weapon/physics/render passes. Gate PASS exit 0 (import registered
    VSPlayer+VSRun with no parse errors — validating the new field, the "regen" match arm, and the 8th
    UPGRADES entry — + both smoke tests incl. run-scene boot which builds the world and runs the controller
    through apply_upgrade). Eyeball: play to a level-up, pick Vitality — Antonio's red health bar slowly
    refills between hits; pick it again and it sustains harder, so investing in defense becomes a real
    choice against the escalating waves. Tune the 0.6 HP/s step by feel.

[x] Player collider — enemies pathed to the player's center and buried inside the 49x52 sprite. Added a
    small inner SOLID collider enemies can't pass through. player.gd: const SOLID_RADIUS := 9.0 (< hurt
    RADIUS 14, so contact damage still triggers). enemy.gd _process: after chase + separation + knockback
    (resolved last so it wins), if the enemy is within min_d = SOLID_RADIUS + radius it's pushed back out
    to that touching distance along the player->enemy line — a contacting enemy presses against the body
    instead of overlapping the sprite. Per-enemy radius holds a brute further out than a bat; knockback
    still flings enemies (block only engages when too close). Gate PASS exit 0. Eyeball: a swarm should
    ring up against Antonio and stop at his body edge, still chipping contact damage at that distance.

[x] Adjust resolution and zoom out 10% — bigger default window + a 10% camera zoom-out. project.godot:
    base viewport 800x640 -> 1445x920 (with canvas_items stretch this sets BOTH the base render res and
    the initial window size; kept 1:1 so pixels stay crisp and the apparent sprite size is unchanged —
    the larger window just reveals more field). run.gd: the player Camera2D now sets zoom=Vector2(0.9,0.9)
    — zoom<1 widens the view, so sprites read ~10% smaller than before (the literal "zoom out 10%").
    hud.gd: re-anchored the game-over banner from a hardcoded position (300,280) to PRESET_CENTER +
    GROW_DIRECTION_BOTH so it stays centred at the wider viewport (the fixed pos would drift left). Three
    files; no scene/art/API changes; the XP-bar/stat/loadout HUD anchors are already responsive. Gate
    PASS exit 0 (import registered VSRun+VSHud, no parse errors, + both smoke tests incl. run-scene boot
    which builds the world with the new camera zoom and recentred HUD). Eyeball: launch the build — window
    opens ~1445x920, field reads a touch wider / sprites ~10% smaller; at the extreme arena corner a ~3px
    sliver of clear-colour may peek past the ground MARGIN (negligible).

[x] Change whip hurt boxes — pushed the whip's strike box a bit further from Antonio AND gave it four
    diagonal corners (was two). whip.gd only. Horizontal/vertical reach: OVERLAP 18->10 so HSEP =
    STRIKE_W*0.5-OVERLAP (~64px, the box-centre's horizontal distance from the player), plus a new
    VSEP=30 vertical offset replacing VERT=14 — each swing now sits a touch further out horizontally
    AND vertically. Replaced the 2-way boolean _flip (up-right / down-left) with a `_dir` index that
    cycles a new `const DIRS: Array[Vector2]` of the four diagonal sign-vectors
    [NE(1,-1), SE(1,1), SW(-1,1), NW(-1,-1)] applied to (HSEP,VSEP); _fire advances _dir each swing
    so a Multishot-stacked whip fans across all four corners in turn. _strike takes the dir index,
    _spawn_slash takes the sign vector and tilts the slash into its corner: base SLASH_ROT reads as
    the NE crack, -rot mirrors it across the horizontal axis for a downward (s.y>0) swing, PI-rot
    mirrors it across the vertical axis for a leftward (s.x<0) swing — both flips compose to rot+PI,
    exactly the old up-right->down-left point-reflection, so NE/SW are unchanged and SE/NW are the new
    mirrored cracks. The hurt boxes stay axis-aligned wide-short rects with the same AABB pierce test,
    just at the 4 diagonal positions. One file; no scene/art/API changes; fire_count/fire_interval/
    damage/projectile_count untouched so the run-scene smoke test and the Power/Haste/Multishot upgrade
    pool work unchanged. Gate PASS exit 0 (import registered VSWhip with the typed const array + 4-way
    logic, no parse errors, + both smoke tests incl. run-scene boot which swings the whip through
    _fire->_strike->_spawn_slash). Eyeball: play — the whip cracks at NE/SE/SW/NW around Antonio, each
    a touch further out; tune HSEP/VSEP (offsets) and SLASH_ROT mirroring (slash orientation) by eye.

[x] Fix flip_h when moving left — the player sprite jumped a full body-width to the right whenever it
    faced left. player.gd _draw() built the flip as Rect2(-w*0.5*_facing, -h*0.5, w*_facing, h): BOTH
    the origin.x AND the width were scaled by _facing. But draw_texture_rect normalizes a negative-width
    rect (RendererCanvasCull::canvas_item_add_texture_rect) by negating the size and setting
    CANVAS_RECT_FLIP_H *without moving the position* — so facing-left left the origin pinned at +w*0.5
    while the (now-positive, mirrored) sprite drew from +w*0.5 to +1.5w, i.e. a full width to the RIGHT
    of the node origin and off the hurt collider — exactly the reported "flipped along the right vertical
    axis." Fix: pin origin.x to the LEFT edge -w*0.5 in BOTH headings and let only the width carry
    _facing's sign — Rect2(-size.x*0.5, -size.y*0.5, size.x*_facing, size.y). _facing 1 is unchanged
    (positive width, centered -0.5w..+0.5w); _facing -1 normalizes to the same centered rect with FLIP_H,
    so the mirror now pivots on the sprite center, staying over the body and health bar. One-line change +
    comment, player.gd only; no API/scene/art changes; the health bar (drawn after, symmetric) is
    untouched. Gate PASS exit 0 (import registered VSPlayer with no parse errors + both smoke tests incl.
    run-scene boot which draws the player). Eyeball: walk left then right — Antonio mirrors in place over
    his hurt collider / health bar instead of sliding a body-width sideways on the flip.

[x] Floating damage numbers on hit — hits flashed and recoiled but the amount wasn't quantified, so
    weapon power didn't read as a number. enemy.gd only: added a self-freeing `DamageNumber` inner
    Node2D (drawn primitively in _draw() via draw_string + draw_string_outline, no scene file) modeled
    on projectile.gd's ImpactSpark. It floats up RISE 24px and fades over DUR 0.55s (alpha holds, then
    fades near the end), centered over the head via font.get_string_size, with a dark outline (size 4)
    so it stays legible over the busy field. `_spawn_damage_number(amount, killed)` mounts it on `run`
    (a sibling, so it outlives the enemy's death pop) at position + (0, -radius - 6) — just above the
    head, and naturally higher over a big brute. It's called from BOTH branches of hit(): the non-lethal
    chip reads small warm-white (HIT_SIZE 14, Color 1,0.96,0.78), the killing blow reads bigger gold
    (KILL_SIZE 20, Color 1,0.80,0.25) so both the hit and the kill read as a quantity, not just a flash.
    z_index 110 (above the impact spark's 100) and phase-gated on run.phase so it holds with the frozen
    world (level-up picker / game over). One file; no scene/API/art changes — every weapon routes
    through hit(), so the whip / wand bolt / garlic tick / orbit blade all get numbers for free. Gate
    PASS exit 0 (import registered VSEnemy with no parse errors — validating the inner-class +
    draw_string/draw_string_outline signatures — + both smoke tests incl. run-scene boot which spawns
    and kills enemies through the hit() -> DamageNumber path headless). Eyeball: shoot/whip a bat — a
    small white number floats up from each chip hit and a bigger gold number pops on the kill; tune
    DUR / RISE / sizes / colors by eye.

[x] Player sprite faces movement direction (flip_h) — player.gd _draw always faced the sprite's
    default (right) heading, so Antonio looked identical walking left or right and direction didn't
    read. player.gd only: added a `_facing` var (1 = right = the Antonio art's default orientation,
    -1 = left), updated each _process from the last non-zero ACTUAL velocity.x via signf(velocity.x)
    — so it holds the prior heading on a wall-clamp (velocity.x == 0), while frozen (level-up picker /
    game over), and during purely-vertical motion. _draw now mirrors the sprite with one
    negative-width draw_texture_rect: Rect2(-size.x*0.5*_facing, -size.y*0.5, size.x*_facing, size.y)
    — Godot flips a texture when the rect width is negative, and scaling both the x-origin and the
    width by _facing keeps the flip centered on the node origin, so _facing 1 draws unflipped and
    _facing -1 mirrors horizontally. The health bar and the hurt/death tints are untouched (the bar is
    drawn separately and symmetric; tints are just the modulate). Reuses the existing per-frame
    queue_redraw in _process; no scene/API/art changes. Gate PASS exit 0 (import registered VSPlayer
    with no parse errors + both smoke tests incl. run-scene boot which draws the player). Eyeball:
    walk left then right — Antonio and his whip flip to face the way he last moved and hold that
    heading when standing still or moving purely vertically.

[x] Enemy knockback on hit — weapons hit like the enemy was a ghost: a white flash, but the enemy
    kept boring in at the same pace with no physical reaction. enemy.gd only: landed hits now fling
    the body back a touch before the chase reels it in, so every weapon reads as connecting. hit()
    already received the strike source but ignored it (_from); renamed to `from` and added
    _apply_knockback(from), called on the non-lethal branch — it sets a decaying _knockback velocity =
    dir.normalized() * KNOCKBACK (150 px/s) * (RADIUS/radius) where dir = position - from. The whip's
    AABB passes the enemy's OWN position (degenerate zero dir), so _apply_knockback falls back to
    (position - target.position) — push straight away from the player — guaranteeing the starter weapon
    flinches too. Heavier/bigger kinds flinch less via the RADIUS/radius mass factor (bat/ghost 1.0;
    brute radius 22 -> ~0.55x; hardened enemies whose radius scaled up resist more). _process applies it
    after chase+separation (position += _knockback*delta) and bleeds it off via move_toward(ZERO,
    KNOCKBACK_DECEL 950 * delta) -> a ~0.16s, ~12px recoil. Composes with chase+separation (brief recoil
    then chase resumes); rapid garlic/whip ticks refresh it into a gentle soft-pushback (a nice emergent
    VS feel). Lethal hits go _dying and the death-pop branch returns early, so corpses aren't knocked.
    One file; no call-site/scene/art changes (all 4 weapon call sites already pass a source positionally).
    Gate PASS exit 0 (import registered VSEnemy with no parse errors + both smoke tests incl. run-scene
    boot which spawns and kills enemies through the hit() -> knockback path headless). Eyeball: play —
    bats/ghosts visibly recoil from each whip slash / wand bolt / garlic tick / blade sweep while brutes
    barely budge; tune KNOCKBACK / KNOCKBACK_DECEL and the RADIUS/radius mass curve by feel.

[x] Give the Magic Wand bolt a distinct magic look — VSProjectile (the Magic Wand's bolt) drew a
    flat yellow circle (Color 1.0,0.95,0.4) with no trail, so it read like a generic bullet rather
    than "magic" and didn't separate from the Whip's slash. projectile.gd only: recolored the bolt to
    a violet body (CORE_COLOR 0.62,0.48,1.0) over a hot near-white core (INNER_COLOR 0.86,0.83,1.0,
    drawn at RADIUS*0.5), and added a short fading wake — _process appends the bolt's world position
    each frame into a PackedVector2Array `_trail` capped at TRAIL_LEN 8 (remove_at(0) when over), and
    _draw renders each stored point relative to the current position (point - position, so the wake
    trails opposite to travel) as a violet circle (TRAIL_COLOR 0.45,0.35,0.95) whose alpha (f*0.5) and
    radius (RADIUS*(0.35+f*0.55)) taper toward the tail. Also recolored the inner ImpactSpark from
    warm yellow to a matching violet burst (ring 0.70,0.55,1.0 / spokes 0.86,0.83,1.0) so the hit reads
    as magic too. One file; no scene/API changes. Gate PASS exit 0 (import registered VSProjectile with
    no parse errors + both smoke tests incl. run-scene boot which fires the wand and draws/trails
    projectiles headless). Eyeball: pick the Magic Wand and watch a bolt — it flies as a glowing violet
    comet with a short fading wake, clearly distinct from the Whip's horizontal slash; tune
    CORE/INNER/TRAIL colors and TRAIL_LEN by eye.

[x] Add Magic Wand as a level-up weapon — the projectile weapon (VSWeapon/VSProjectile), Antonio's
    old starter, was orphaned after the Whip replaced it: still in the codebase but never spawned. Wired
    it back in as the GDD's Magic Wand — a pickable level-up weapon that auto-fires a bolt at the nearest
    enemy (the core "you move, the weapon fights" loop), so weapon variety returns and the projectile code
    is in the game again. weapon.gd: gave VSWeapon a `level` var + level_up() mirroring VSAura/VSOrbit —
    first pick sets the base (fire_interval 0.6, damage 4, 1 bolt), repeats deepen it (fire_interval *=
    0.85 floored at 0.25, damage +2, and projectile_count +1 every other level via `if level % 2 == 1` so
    Lv3/Lv5/… add a bolt, fanned by the existing SPREAD); class doc updated from "starter" to "pickable
    level-up weapon." run.gd: added {"key":"wand","title":"Magic Wand","desc":"Bolt fired at the nearest
    enemy"} to UPGRADES (pool now offers 3 of 7), a `var wand: VSWeapon` field, and an apply_upgrade("wand")
    case that lazily mounts a VSWeapon on the player on first pick (so it auto-fires) and level_up()s it on
    every pick — matching the garlic/orbit lazy-spawn pattern. The picker UI and HUD loadout pick it up
    automatically (both read VSRun.UPGRADES). Power/Haste/Multishot still buff only the Whip (the starter
    weapon field), so the Magic Wand scales via its own re-picks, consistent with garlic/orbit. Two files
    (weapon.gd, run.gd); no scene/art changes. Gate PASS exit 0 (import registered VSRun+VSWeapon with no
    parse errors — confirming the new match arm is valid — + both smoke tests incl. run-scene boot which
    builds the world and runs the run controller through apply_upgrade). Eyeball: play to a level-up, pick
    Magic Wand — a yellow bolt auto-fires at the nearest enemy; pick it again and it fires faster/harder and
    eventually fans extra bolts. Tune base/scaling by feel.

[x] Health Bar — HP was only legible in the HUD corner; per the GOAL's clear-feedback/readability
    aim, moved it onto the character. player.gd: new _draw_health_bar() (called from _draw only while
    alive) draws a small diegetic bar hugging the bottom of the Antonio sprite — a 1px black outline
    (track.grow(1)) + a dark-red empty track (0.20,0.04,0.04,0.85) + a bright-red fill (0.86,0.18,0.18)
    whose width is HP_BAR_W(44) * clampf(health/max_health,0,1), at HP_BAR_GAP(5)px below the sprite,
    HP_BAR_H(5)px tall. Drawn with primitives like the rest of the juice (aura/spark/gem), no per-node
    texture_filter so VISUAL_RULES stays intact; redraws via the existing _process queue_redraw + on
    take_damage; hidden on death (the sprite already greys out). hud.gd: dropped the "HP %d" number from
    the corner stat line (now "Time/Kills/Lv (xp)") and removed the now-unused hp computation; doc line
    updated. Diegetic, so the player's gaze stays on the action instead of darting to a corner. Two files
    (player.gd, hud.gd); no scene/API changes. Gate PASS exit 0 (import registered VSPlayer/VSHud with no
    parse errors + both smoke tests incl. run-scene boot which builds the world and draws the player).
    Eyeball: take hits — a red bar under Antonio shrinks left-to-right as HP drains; tune
    HP_BAR_W/H/GAP and the colors by eye.

[x] Starting weapon, Whip — Antonio started with the Magic Wand projectile; per the GDD his
    starter is the Whip. New scripts/weapons/whip.gd (VSWhip extends Node2D): a horizontal-slash
    melee weapon that on its cooldown (fire_interval 1.1s, damage 5) PIERCES every enemy inside a
    wide, short box and ALTERNATES between an up-and-right swing and a down-and-left swing (it swings
    on cooldown whether or not anything is in reach, like VS). Box sized off the player sprite:
    STRIKE_W = 49*3 = ~147px (3 player widths) wide, STRIKE_H = 52*1.2 = ~62px (1.2 player heights)
    tall, offset OVERLAP 18 behind / VERT 14 up|down per the struck side; damage is an AABB test
    (|dx|<=hw+e.radius && |dy|<=hh+e.radius) over a get_nodes_in_group("enemies") snapshot so it cuts
    the whole flank at once with no double-hit. Keeps the same mutable stat fields the upgrade pool
    drives (damage/fire_interval/projectile_count), so apply_upgrade(Power/Haste/Multishot) works
    unchanged — Multishot adds an extra simultaneous swing on the opposite flank. VFX: new
    art/whip_slash.png (950x98, a 10-frame 95x98 horizontal strip built offline with PIL from
    SourceArt/pixel_art-animations-warrior/VFX 3/Frames, uniform-cropped to the union content bbox
    (7,27,102,125); lossless, mipmaps off, NEAREST, fix_alpha_border via headless --import, matching
    the other sprites). An inner WhipSlash Node2D one-shot plays the strip once via
    draw_texture_rect_region, rotated by SLASH_ROT (0.6 rad, +PI for the down-left swing) so the
    diagonal warrior slash reads horizontal, scaled SLASH_SCALE 1.5 toward the box, fading its tail,
    then frees itself (z 50, gated on run.phase — matches the impact-spark juice pattern). run.gd:
    `weapon` typed VSWhip and _build_world now spawns VSWhip instead of VSWeapon; lightly corrected
    the picker descs ("+1 weapon damage" / "+1 extra strike") now that the starter isn't a projectile.
    The projectile weapon (VSWeapon/VSProjectile) stays in the codebase as the GDD's Magic Wand (a
    future level-up weapon), just no longer the starter. Ported run_smoke_test.gd's progress signal
    from "projectiles in flight" (the whip has none, and enemies spawn ~520px out vs the whip's ~130px
    reach so kills aren't guaranteed in the 6s window) to run.weapon.fire_count > 0 — the weapon-
    agnostic "auto-weapon is alive" signal. Files: +whip.gd, +whip_slash.png(+.import), run.gd,
    run_smoke_test.gd. Gate PASS exit 0 (import registered VSWhip + reimported whip_slash.png with no
    parse errors + both smoke tests incl. run-scene boot which builds the world with the whip and
    swings it). Eyeball: play — the whip cracks a horizontal slash beside Antonio, alternating
    up-right / down-left, clearing the flank as the swarm closes; tune SLASH_ROT/SLASH_SCALE
    (orientation/size of the slash sprite) and damage/fire_interval (feel) by eye.

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
