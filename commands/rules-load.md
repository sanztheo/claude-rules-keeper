---
description: Load a saved preset of rules into the current session
argument-hint: <preset-name>
---

You are loading a saved preset of rules to apply in the current conversation.

## Workflow

1. **Get preset name** from: `$ARGUMENTS`
   - If no argument, list available presets from `~/.claude/rules-keeper/presets/` and ask user to choose
2. **Read** the preset file: `~/.claude/rules-keeper/presets/<preset-name>.md`
3. **Show the rules** to the user for confirmation
4. **On confirmation**, merge the preset rules:
   - Global rules from preset → append to `~/.claude/rules-keeper/rules.md` (skip duplicates)
   - Project rules from preset → append to current project's rules file (skip duplicates)
5. **Confirm** what was loaded and how many rules were added

## Rules

- If preset doesn't exist, list available presets and suggest
- NEVER duplicate rules - check before appending
- Show what will be added before actually adding
- If listing presets, show name + creation date + rule count
