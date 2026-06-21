# AgentMD

Surprises and gotchas discovered while working in this project. Flag the developer when you add one.

---

## gdUnit4 addon is patched for Godot 4.6.2 (vendored fix)

**Surprise:** the bundled gdUnit4 (`vampire-survivors-taskmaster/addons/gdUnit4/`) does not compile out-of-the-box against Godot 4.6.2 — `GdUnitFileAccess.gd:199` called `FileAccess.get_as_text(true)`, but in this Godot build `FileAccess.get_as_text()` takes **0** arguments (no `skip_cr` param). The single compile error cascades and made the entire test runner fail to load (`-a test` produced "Failed to compile depended scripts" for the whole addon).

**Fix applied (task 2):** changed that one line to `file.get_as_text()`. After the patch the runner works: `addons/gdUnit4/runtest.cmd --godot_binary <godot.exe> -a test`.

**Heads-up for the developer:** this is a *vendored addon edit*. If gdUnit4 is ever reinstalled/updated, the patch will be lost and tests may break again until re-applied (or until a gdUnit4 release that officially supports 4.6.2 is used). Watch for similar removed-argument API mismatches elsewhere in the addon.
