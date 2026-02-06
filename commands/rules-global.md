---
description: Add a global rule (permanent, all conversations)
argument-hint: <rule to remember permanently>
---

You are adding a **permanent global rule**. This rule applies to every conversation and survives compaction forever.

## Workflow

1. **Parse the rule** from: `$ARGUMENTS`
2. **Read** `~/.claude/rules-keeper/rules.md` to check for duplicates
3. **Append** the rule:
   - Add a `- ` prefix (markdown list item)
   - Keep the exact wording (no reformulation)
   - Don't duplicate
4. **Confirm** what was added, mention it's global/permanent

## Format in rules.md

```markdown
# Persistent Rules

- [rule 1]
- [rule 2]
```

## Rules

- NEVER reformulate - write EXACTLY as given
- If the file doesn't exist, create it with the `# Persistent Rules` header
- Warn if a similar rule already exists
- Briefly confirm: "Global rule added (permanent, all conversations)."
