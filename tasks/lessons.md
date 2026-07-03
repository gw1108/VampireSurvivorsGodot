# Lessons

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.

### Drop-table content gaps vs the wiki
This reimplementation's light-source/kill drop tables (VSRun.drop_candelabra_bonus / add_kill in scripts/run/run.gd) have no Luck stat and no Gilded Clover / Little Clover / Rich-Coin-Bag-as-distinct-item — those wiki pickups (Pickups.md, Light_source.md) don't exist as code yet. Rosary/Orologion/Magnet/Coin/Food also drop directly from *any* enemy kill here (small %), not just from light sources as in real VS — a deliberate simplification, not a bug. Check backlog before re-flagging.