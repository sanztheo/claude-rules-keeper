---
name: rules-keeper
description: Use at the start of every conversation and before every task - maintains rules and task state so important context survives compaction. Always active, no exceptions.
---

# Rules Keeper

## Overview

You have **claude-rules-keeper** installed. Context compaction erases your memory. You maintain rules across 4 scopes:

| Scope | File | Lifetime |
|-------|------|----------|
| **Session** | `~/.claude/rules-keeper/session-rules.md` | Current conversation only (cleared on new conv) |
| **Global** | `~/.claude/rules-keeper/rules.md` | Permanent, all conversations |
| **Project** | `~/.claude/rules-keeper/projects/<project>/rules.md` | Permanent, when in that project |
| **Task** | `~/.claude/rules-keeper/current-task.md` | Current session only |

## At Conversation Start

1. **Read session rules:** `~/.claude/rules-keeper/session-rules.md` (if exists)
2. **Read global rules:** `~/.claude/rules-keeper/rules.md`
3. **Read project rules:** Detect project via `git rev-parse --show-toplevel` basename (if result equals `$HOME`, fallback to `basename $(pwd)`), read `~/.claude/rules-keeper/projects/<project>/rules.md` if it exists
4. **Follow ALL rules** from all files

## Auto-Detect Rules

When the user states a preference, constraint, or standard:
- Session preference → append to **session** `session-rules.md`
- Permanent preference → append to **global** `rules.md` (only if user says "toujours", "permanently", etc.)
- Project-specific preference → append to **project** rules file

Default to **session scope** unless the user explicitly wants it permanent. Confirm briefly: "Rule noted in [session/global/project] rules."

## User Commands

| Command | What it does |
|---------|-------------|
| `/rules-add <text>` | Add session rule (this conversation only) |
| `/rules-add-smart <text>` | Claude reformulates, you validate, then saved |
| `/rules-add-global <text>` | Add permanent global rule (all conversations) |
| `/rules-add-project <text>` | Add permanent rule for current project |
| `/rules-show` | Show all active rules |
| `/rules-remove` | Remove a specific rule by number |
| `/rules-clear` | Clear all session rules |
| `/rules-save <name>` | Save all rules as reusable preset |
| `/rules-load <name>` | Load a preset into current session |
| `/rules-doctor` | Run diagnostic checks |
| `/rules-upgrade` | Check for updates and upgrade |
| `/rules-status` | Show status dashboard |

## Task State

Write to `~/.claude/rules-keeper/current-task.md` at task start, after decisions, and before stopping. Keep under 15 lines.

## After Compaction

If you see `[COMPACTION RECOVERY]`:
1. Read global + project + session rules - these are your standing orders
2. Read recovered task context
3. Confirm with user before continuing
