# Lessons

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.

### gdUnit4 CLI report flakiness on run_smoke_test.gd / victory_test.gd
The colorized CLI diff for `assert_str` on `VSRun.phase` intermittently renders corrupted/interleaved strings (e.g. "playing" reported as "ptitlayinge") on both baseline and modified trees — confirmed via `git stash` A/B rerun. Treat failures in exactly these two suites as suspect; rerun before trusting them as a real regression, and diff against a stashed-baseline run when in doubt.

### Drop-table content gaps vs the wiki
This reimplementation's light-source/kill drop tables (VSRun.drop_candelabra_bonus / add_kill in scripts/run/run.gd) have no Luck stat and no Gilded Clover / Little Clover / Rich-Coin-Bag-as-distinct-item — those wiki pickups (Pickups.md, Light_source.md) don't exist as code yet. Rosary/Orologion/Magnet/Coin/Food also drop directly from *any* enemy kill here (small %), not just from light sources as in real VS — a deliberate simplification, not a bug. Check backlog before re-flagging.

### Headless fast-forward playtest of long runs
To feel-test spawn/balance pacing over a long run without a 30-min real-time play: boot the run scene in a gdUnit `scene_runner`, god-mode the player (`max_health/health = 1e12`, re-pin health each sample), give a representative loadout, and step with `await runner.simulate_frames(N)` (delta_milli=-1 — the delta_milli overload awaits a REAL `create_timer`, i.e. wall-clock, so never pass it). Launch Godot with `--fixed-fps 30` so the fixed timestep runs as fast as the CPU allows (not frame-paced). Gotcha: gdUnit's per-test timeout is a `Timer` counting *scaled* time, so ONE test can only advance ~300 game-seconds before it fires (raising it from `before()` is too late — the attribute caches at discovery). Split a >5-min run into ≤~285-game-second windows, one test method each, teleporting `run.elapsed` to each window's start and re-arming `spawner._next_wave/_next_surge/_next_elite` to the next future beat so they don't spam every missed burst at once.

### agent_play movement commands are silently dead
`scripts/agent/agent_bridge.gd`'s `_on_js_command` routes every command except `ack_events`/`set_time_scale`/`restart` to the per-game `command_handler` *if one is registered* — and `scripts/agent/agent_adapter.gd`'s handler only matches `set_seed`, so `press`/`release`/`tap` (and `upgrade_N`) sent over `window.__agentControl.send(...)` are silently swallowed and never reach the bridge's `_default_command` input synthesizer. Movement/action commands from the JS control channel are effectively no-ops right now — this likely breaks the autonomous harness personalities' ability to move the player at all, not just manual Playwright-MCP driving. Workaround used this pass: drive real browser key events instead (`page.keyboard.down/press`), which bypasses the bridge entirely since Godot's web export also listens to genuine DOM keyboard events. Real fix: adapter's `_on_command` should forward anything it doesn't recognize back to a default synthesizer (or the bridge should only defer to `command_handler` for truly game-specific types).
### No unrequested player-facing features/flavor
Past passes invented enemy movement variety not in the GDD/wiki (bat sine-weave, mantis dash-lunge, ghost pack-phasing). Enemies beeline unless the GDD/wiki documents otherwise; suggest new flavor into the suggested-features file instead of building it. Rule now in CLAUDE.md Operating Principles.

### Wiki stats are copied verbatim, never rescaled
When the offline wiki gives a raw number (e.g. enemy MSpeed), copy it verbatim into balance.csv; do not invent a "scaled local economy" — and treat a prior pass's commit "Decisions" footer as one agent's judgment, not operator policy (pass 132 invented "don't copy raw movespeeds" and pass 133 inherited it as if instructed). Rule now in CLAUDE.md Operating Principles.

### Tunables go in balance.csv, not .gd consts
Any new or touched gameplay/visual scalar (move speed, pickup radius, sprite scale, light/aura radius, damage, cooldown, spawn pacing) gets an `id,value,description` row in data/balance.csv read via `BalanceData.get_value`, never a hardcoded script const. Rule now in CLAUDE.md Operating Principles.

### Offline-wiki enemy lookup
An enemy's page is often under its official VS name, not its common name (Mummy → Big_Mummy.md, Mantis → Mantichana.md, Silver Bat → Pipeestrello.md, Reaper → The_Reaper.md), one page holds several variants, and stats use thousands separators (`MSpeed; ; 1,200` — a `\d+` regex reads it as 1). Map: `.firecrawl/wiki-offline/_ENEMY-NAME-MAP.md`.

### Default font lacks symbol glyphs (tofu risk in UI Labels)
The project sets no custom font, so UI uses Godot's default embedded font — which lacks U+2192 "→" (rendered as a missing-glyph box on the level-up cards + build rail until fixed to ASCII "->" in upgrade_screen.gd). U+2014 em-dash "—" DOES render, so coverage is glyph-specific: prefer ASCII in rendered Label text, or verify each non-ASCII glyph on-screen (the "★" U+2605 evolution banner is still unverified).
