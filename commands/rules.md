---
description: Add a session rule (this conversation only)
argument-hint: <rule for this session>
---

You are adding a **session-scoped** rule. This rule survives compaction but is cleared when a new conversation starts.

## Workflow

1. **Parse the rule** from: `$ARGUMENTS`
2. **Read** `~/.claude/rules-keeper/session-rules.md` to check for duplicates
3. **Append** the rule:
   - Add a `- ` prefix (markdown list item)
   - Keep the exact wording (no reformulation)
   - Don't duplicate
4. **Confirm** what was added, mention it's session-scoped

## Format in session-rules.md

```markdown
# Session Rules

- [rule 1]
- [rule 2]
```

## Rules

- NEVER reformulate - write EXACTLY as given
- If the file doesn't exist, create it with the `# Session Rules` header
- Warn if a similar rule already exists
- Briefly confirm: "Session rule added (cleared on new conversation)."
