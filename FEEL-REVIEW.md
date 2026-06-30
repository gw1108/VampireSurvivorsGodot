# FEEL-REVIEW — periodic playtest feedback (newest on top)

Written by `tools/playtest-review.ps1`: it plays the current build with the `agent_play`
harness, then a goal-aware synthesis scores the build against `workshop/GOAL.md` and records
the gaps here. The Workshop reads the latest entry each pass and turns the gaps into work.
Union-merged (see `.gitattributes`) so it never conflicts.

_(no playtests yet — run `tools/playtest-review.ps1` once the web export prerequisites are in place; see its header.)_
