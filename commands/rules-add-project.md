---
description: Add a permanent rule for the current project only
argument-hint: <rule for this project>
---

You are adding a **permanent project rule**. This rule only applies when working in the current project.

## Workflow

1. **Detect the project name:**
   - Run `git rev-parse --show-toplevel` — if it succeeds and the result is NOT `$HOME`, use its basename
   - Otherwise fallback to `basename $(pwd)`
2. **Determine the rules file:** `~/.claude/rules-keeper/projects/<project-name>/rules.md`
3. **Create directory** if it doesn't exist
4. **Read** the existing rules file to check for duplicates
5. **Append** the rule from: `$ARGUMENTS`
   - Add a `- ` prefix (markdown list item)
   - Keep the exact wording
   - Don't duplicate
6. **Confirm** what was added and which project

## Format in rules file

```markdown
# Project Rules: <project-name>

- [rule 1]
- [rule 2]
```

## Rules

- NEVER reformulate - write EXACTLY as given
- Use `git rev-parse --show-toplevel` basename as project name, but guard against `$HOME` — fallback to `basename $(pwd)` if git root equals `$HOME` or is empty
- Create the directory and file if they don't exist
- Warn if a similar rule already exists
