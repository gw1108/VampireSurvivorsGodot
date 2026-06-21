# Lessons

### MediaWiki link rewriting
This wiki emits `/w/<Title>` short URLs (not `/wiki/` or `?title=`) — match `/w/` when rewriting internal links to local `.md`.

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.

### Godot project location
The Godot 4.6 project is in `vampire-survivors-taskmaster/`, not the repo root — all `res://` paths and `godot --path` resolve there.

### gdUnit4 / Godot 4.6.2 compat
Bundled gdUnit4 needed a vendored patch to compile against 4.6.2 (`get_as_text(true)`→`get_as_text()`); see AgentMD.md before reinstalling the addon.

### Shell CWD per loop turn
Bash CWD resets to repo root each iteration (not the Godot subdir) — use absolute `--path` and `cmd //d //c "cd /d <projdir> && ..."`, else commands silently run in the wrong place.
