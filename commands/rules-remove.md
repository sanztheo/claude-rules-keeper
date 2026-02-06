---
description: Remove a rule by number
argument-hint: [session|global|project] [number]
---

You are removing a rule from the user's rules files.

## Workflow

1. **Parse arguments** from: `$ARGUMENTS`
   - If arguments given (e.g. `session 2` or `global 1`): remove that rule directly
   - If no arguments: show all rules with numbers and ask which to remove

2. **When listing rules for selection**, use this format:
   ```
   Session:
     1. [rule text]
     2. [rule text]
   Global:
     3. [rule text]
   Project (my-app):
     4. [rule text]

   Which rule to remove? (number)
   ```

3. **Read the appropriate file:**
   - Session: `~/.claude/rules-keeper/session-rules.md`
   - Global: `~/.claude/rules-keeper/rules.md`
   - Project: detect via `git rev-parse --show-toplevel` basename, read `~/.claude/rules-keeper/projects/<project>/rules.md`

4. **Remove the line** starting with `- ` at the specified position
5. **Write** the file back without that line
6. **Confirm** what was removed

## Rules

- Show rules with numbers for easy selection
- If the scope+number is given directly, skip the listing step
- After removal, briefly confirm: "Removed: [rule text]"
- If no rules exist, say "No rules to remove."
