---
description: Clear all session rules
---

You are clearing all session rules for the current conversation.

## Workflow

1. **Read** `~/.claude/rules-keeper/session-rules.md`
2. If no session rules exist, say "No session rules to clear."
3. **Show** the rules that will be removed
4. **Delete** the file: `~/.claude/rules-keeper/session-rules.md`
5. **Confirm**: "Session rules cleared (X rules removed)."

## Rules

- Only clears session rules, never global or project rules
- No confirmation prompt needed (session rules are temporary by nature)
