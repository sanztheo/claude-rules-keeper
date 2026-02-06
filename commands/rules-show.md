---
description: Show all active rules for the current session (global + project)
---

You are showing the user all rules currently active in this session.

## Workflow

1. **Read global rules:** `~/.claude/rules-keeper/rules.md`
2. **Detect project:** Run `basename $(git rev-parse --show-toplevel 2>/dev/null || pwd)` to get the project name
3. **Read project rules:** `~/.claude/rules-keeper/projects/<project>/rules.md` (if it exists)
4. **Display** all rules in a clear format:

## Display Format

```
📋 Active Rules

── Global ──────────────────────────
- [rule 1]
- [rule 2]
(or "No global rules set.")

── Project: <name> ─────────────────
- [rule 1]
(or "No project rules for <name>.")
```

## Rules

- Read the actual files, don't guess
- If both are empty, say "No rules set yet. Use /rules or /rules-project to add some."
- Show the count of rules per scope
- Keep it concise, no extra commentary
