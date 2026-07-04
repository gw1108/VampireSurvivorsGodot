# Lessons

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.

### gdUnit4 CLI report flakiness on run_smoke_test.gd / victory_test.gd
The colorized CLI diff for `assert_str` on `VSRun.phase` intermittently renders corrupted/interleaved strings (e.g. "playing" reported as "ptitlayinge") on both baseline and modified trees — confirmed via `git stash` A/B rerun. Treat failures in exactly these two suites as suspect; rerun before trusting them as a real regression, and diff against a stashed-baseline run when in doubt.

### Drop-table content gaps vs the wiki
This reimplementation's light-source/kill drop tables (VSRun.drop_candelabra_bonus / add_kill in scripts/run/run.gd) have no Luck stat and no Gilded Clover / Little Clover / Rich-Coin-Bag-as-distinct-item — those wiki pickups (Pickups.md, Light_source.md) don't exist as code yet. Rosary/Orologion/Magnet/Coin/Food also drop directly from *any* enemy kill here (small %), not just from light sources as in real VS — a deliberate simplification, not a bug. Check backlog before re-flagging.

### agent_play movement commands are silently dead
`scripts/agent/agent_bridge.gd`'s `_on_js_command` routes every command except `ack_events`/`set_time_scale`/`restart` to the per-game `command_handler` *if one is registered* — and `scripts/agent/agent_adapter.gd`'s handler only matches `set_seed`, so `press`/`release`/`tap` (and `upgrade_N`) sent over `window.__agentControl.send(...)` are silently swallowed and never reach the bridge's `_default_command` input synthesizer. Movement/action commands from the JS control channel are effectively no-ops right now — this likely breaks the autonomous harness personalities' ability to move the player at all, not just manual Playwright-MCP driving. Workaround used this pass: drive real browser key events instead (`page.keyboard.down/press`), which bypasses the bridge entirely since Godot's web export also listens to genuine DOM keyboard events. Real fix: adapter's `_on_command` should forward anything it doesn't recognize back to a default synthesizer (or the bridge should only defer to `command_handler` for truly game-specific types).