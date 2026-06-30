# DONE — append-only log (newest on top)

Each Ralph/Workshop pass appends `[x] <title> — <what landed>` here. Union-merged across lanes
(see `.gitattributes`) so parallel appends concatenate instead of conflicting.

[x] Minimal playable slice + agent_play adapter — player/enemies/spawner/auto-weapon/projectiles/XP
    gems/HUD/game-over built in code under vampire-survivors-taskmaster/scripts; run.tscn set as main
    scene; AgentBridge adapter publishes state for the harness. Verified: clean import, 600-frame
    headless run, and a gdUnit4 smoke test (boots → spawns → makes kills) — gate green.
[x] Periodic goal-aware playtest-review loop — tools/playtest-review.ps1 (play via agent_play →
    score vs workshop/GOAL.md → write FEEL-REVIEW.md + append backlog items); Workshop PROMPT reads
    FEEL-REVIEW.md each pass. Play step's only remaining setup is a "Web" export preset (web export
    templates installed + ANTHROPIC_API_KEY present; preflight auto-detects Godot's real templates dir).
