# Godot Coding

## Known Pitfall: `.tscn` line-1 parse error (`Expected '['`)

### Trigger
- Error message:
  - `res://scenes/main.tscn:1 - Parse Error: Expected '['`

### Root Cause
- The file was saved as UTF-8 with BOM (`EF BB BF`) so the first parser-visible byte is not `[`. 
- Godot text scene parser expects the file to begin directly with `[gd_scene ...]`.

### Fix
- Save `.tscn` as UTF-8 without BOM.
- If writing files via PowerShell/scripts, enforce no-BOM UTF-8.

### PowerShell Safe Write (no BOM)
```powershell
$enc = New-Object System.Text.UTF8Encoding($false)
$content = Get-Content -Raw C:\my\Sultan-like\scenes\main.tscn
[System.IO.File]::WriteAllText('C:\my\Sultan-like\scenes\main.tscn', $content, $enc)
```

### Prevention
- Byte-check first 3 bytes should NOT be `239 187 191`.
- Prefer letting Godot editor save `.tscn` where possible.

## Known Pitfall: Chinese mojibake in `.gd` strings

### Symptom
- Chinese UI text becomes unreadable garbled characters.
- GDScript may also fail parse if quote characters inside string literals are corrupted.

### Root Cause
- File content is read/written through mismatched encodings (for example UTF-8 content treated as ANSI/GBK and written back).
- Re-saving already-corrupted text causes irreversible mojibake.

### Fix
- Replace corrupted strings from a known-good source; do not try to algorithmically repair random mojibake.
- Force UTF-8 no-BOM when writing `.gd` / `.tscn` files.

### Prevention
- Keep source files in UTF-8 consistently across editor, terminal, and scripts.
- Avoid mixed write paths (`Set-Content` defaults can vary across shells/versions).
- Prefer `WriteAllText(..., new UTF8Encoding(false))` for scripted writes.
## Workflow Rule: avoid mojibake when scripting edits

### Rule
- For generated or scripted `.gd` / `.tscn` updates, default to ASCII literals in code.
- Put user-facing Chinese text into a separate localization resource (CSV/JSON) and load at runtime.

### Why
- Terminal/editor encoding mismatch can silently corrupt non-ASCII literals.
- Corrupted quote punctuation can also break GDScript syntax.

### Safe write pattern
- Always write with UTF-8 no BOM via `.NET` APIs.
- After writing, verify first bytes and run a quick string sanity grep.