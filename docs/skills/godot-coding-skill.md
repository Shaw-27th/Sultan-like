# Godot Coding Skill Notes

## Incident: `main.tscn` Parse Error `Expected '['`

### Symptom
- Godot debug output:
  - `res://scenes/main.tscn:1 - Parse Error: Expected '['`

### Root Cause
- The scene file was saved as UTF-8 **with BOM** (`EF BB BF`) at byte start.
- Godot text scene parser expects the first visible character to be `[` from `[gd_scene ...]`.
- BOM at file head can break this expectation and trigger a line-1 parse failure.

### Fix
- Re-save `.tscn` (and other text assets) as UTF-8 **without BOM**.
- In PowerShell, avoid `Set-Content -Encoding UTF8` (Windows PowerShell often writes BOM).
- Use `.NET` writer with `new UTF8Encoding(false)` for no-BOM writes.

### Prevention Checklist
- Before running, verify first bytes of `.tscn`/`.gd` are not `239 187 191`.
- Prefer editing via Godot editor for scene files when possible.
- If scripts generate scene files, enforce no-BOM output in generator code.
