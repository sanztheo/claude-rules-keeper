---
description: Save rules as a preset
argument-hint: <preset-name>
---

You are saving the current rules as a reusable preset that can be loaded in any future conversation.

## Workflow

1. **Get preset name** from: `$ARGUMENTS`
   - Sanitize: lowercase, hyphens instead of spaces, no special chars
2. **Read current rules:**
   - Global: `~/.claude/rules-keeper/rules.md`
   - Project (if exists): detect project name via `basename $(git rev-parse --show-toplevel 2>/dev/null || pwd)`, read `~/.claude/rules-keeper/projects/<project>/rules.md`
3. **Combine** into a single preset file at `~/.claude/rules-keeper/presets/<preset-name>.md`
4. **Confirm** with preset name and rule count

## Preset Format

```markdown
# Preset: <preset-name>
Created: <date>
Source project: <project-name or "global only">

## Global Rules
- [rules from global]

## Project Rules
- [rules from project, if any]
```

## Rules

- Create `~/.claude/rules-keeper/presets/` directory if it doesn't exist
- If preset name already exists, ask before overwriting
- Include both global and project rules in the preset
- Show a summary of what was saved
