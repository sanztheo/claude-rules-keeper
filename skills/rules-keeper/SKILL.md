---
name: rules-keeper
description: Use at the start of every conversation and before every task - maintains rules and task state so important context survives compaction. Always active, no exceptions.
---

# Rules Keeper

## Overview

You have **claude-rules-keeper** installed. Context compaction erases your memory. You maintain persistent rules across 3 scopes:

| Scope | File | When loaded |
|-------|------|-------------|
| **Global** | `~/.claude/rules-keeper/rules.md` | Every conversation |
| **Project** | `~/.claude/rules-keeper/projects/<project>/rules.md` | When in that project |
| **Task** | `~/.claude/rules-keeper/current-task.md` | Current session only |

## At Conversation Start

1. **Read global rules:** `~/.claude/rules-keeper/rules.md`
2. **Read project rules:** Detect project via `git rev-parse --show-toplevel` basename, read `~/.claude/rules-keeper/projects/<project>/rules.md` if it exists
3. **Follow ALL rules** from both files

## Auto-Detect Rules

When the user states a preference, constraint, or standard that should persist, save it automatically:
- Permanent preference → append to **global** `rules.md`
- Project-specific preference → append to **project** rules file
- Confirm briefly: "Rule noted in [global/project] rules."

Detection signals: "toujours", "jamais", "je prefere", "utilise X pas Y", "les commits doivent", coding standards, naming conventions.

## User Commands

| Command | What it does |
|---------|-------------|
| `/rules <text>` | Add raw rule to global |
| `/rules-project <text>` | Add raw rule to current project |
| `/rules-create <text>` | Claude reformulates, then adds |
| `/rules-save <name>` | Save all rules as reusable preset |
| `/rules-load <name>` | Load a preset into current session |

## Task State

Write to `~/.claude/rules-keeper/current-task.md` at task start, after decisions, and before stopping. Keep under 15 lines.

## After Compaction

If you see `[COMPACTION RECOVERY]`:
1. Read global + project rules - these are standing orders
2. Read recovered task context
3. Confirm with user before continuing
