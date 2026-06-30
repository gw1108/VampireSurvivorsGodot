# NOTES — cross-pass gotchas (newest on top)

Append one-line gotchas a future pass should know (a tricky import step, an API quirk, a balance
decision). Union-merged across lanes (see `.gitattributes`). For durable project lessons, also follow
the `tasks/lessons.md` workflow in `claude.md`.

- Godot 4.6 headless `--export-release "Web"` on Windows SEGFAULTS on shutdown (exit 139) AFTER writing
  a valid build. Judge export success by the artifacts (`index.html`/`.wasm`/`.pck`), NOT the exit code.
  `tools/playtest-review.ps1` does this and runs the harness with `--no-export`.
- `agent_play` harness needs a FUNDED Anthropic balance (it calls the API directly with `.env`'s
  `ANTHROPIC_API_KEY`). A valid key with no credits → every decide returns "credit balance is too low"
  and 0 findings; the build still boots and screenshots are still captured.
- Verify a web build boots + the adapter is wired WITHOUT spending tokens: `node agent_play/boot-check.mjs`.
