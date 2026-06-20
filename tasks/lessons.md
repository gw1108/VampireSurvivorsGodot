# Lessons

### MediaWiki link rewriting
This wiki emits `/w/<Title>` short URLs (not `/wiki/` or `?title=`) — match `/w/` when rewriting internal links to local `.md`.

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.
