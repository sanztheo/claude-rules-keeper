# claude-compact-guard - Full Specification

## The Problem

When Claude Code's context window fills up (~75-92%), it automatically compresses/summarizes the conversation. This causes:

- Loss of precise task details
- Paraphrased rules losing accuracy (~95% -> ~60-70% compliance)
- Claude forgetting what the user was working on
- No built-in mechanism to recover

**claude-compact-guard** solves this with hooks, persistent memory files, and a small CLI.

---

## Installation Method

Single command install:

```bash
curl -fsSL https://raw.githubusercontent.com/sanz/claude-compact-guard/main/install.sh | bash
```

Installs everything into `~/.claude/compact-guard/` and configures Claude Code hooks automatically.

---

## Project Structure (Source)

```
claude-compact-guard/
├── install.sh                  # Main installer (curl | bash compatible)
├── uninstall.sh                # Clean uninstall
├── hooks/
│   ├── pre-compact.sh          # Runs BEFORE compaction: saves context snapshot
│   └── session-start.sh        # Runs on SessionStart: detects post-compaction resume
├── bin/
│   └── ccg                     # CLI tool (pure bash)
├── templates/
│   ├── claude-rules.md         # Rules to inject into user's CLAUDE.md
│   └── current-task.md         # Template for current task tracking
├── docs/
│   └── SPEC.md                 # This file
├── LICENSE                     # MIT
└── README.md
```

## Installed Layout (User's Machine)

```
~/.claude/
├── compact-guard/
│   ├── backups/                # Rotating context snapshots (max 10)
│   │   ├── 2026-02-05_14-30-22.md
│   │   └── 2026-02-05_16-45-10.md
│   ├── current-task.md         # Current task being worked on
│   ├── state.json              # Last compaction timestamp, stats
│   └── config.json             # User preferences
├── hooks/
│   ├── pre-compact.sh          # Hook script
│   └── session-start.sh        # Hook script
└── settings.json               # Claude Code hooks config (MERGED, never overwritten)
```

---

## Component Specifications

### 1. `install.sh`

**Constraints:**
- Zero dependencies (pure bash only)
- NEVER overwrite existing `settings.json` - MERGE hook entries into it
- NEVER overwrite existing `CLAUDE.md` - APPEND rules section with guard markers
- Idempotent: running twice produces same result as once
- Works on macOS and Linux

**Flow:**
1. Detect OS and shell (bash/zsh)
2. Create `~/.claude/compact-guard/{backups}` directory structure
3. Copy hook scripts to `~/.claude/hooks/`, make executable
4. Merge hook config into `~/.claude/settings.json`:
   - Read existing file (or create `{}`)
   - Use `jq` if available, fallback to `python3 -c`, last resort `sed`
   - Add `PreCompact` and `SessionStart` hook entries
   - Write back without destroying existing config
5. Append rules to `~/.claude/CLAUDE.md` between `<!-- CLAUDE-COMPACT-GUARD:START -->` and `<!-- CLAUDE-COMPACT-GUARD:END -->` markers (skip if already present)
6. Symlink `bin/ccg` to `~/.local/bin/ccg` (create dir if needed)
7. Initialize `state.json` and `config.json` with defaults
8. Print colored success message with usage instructions

---

### 2. `uninstall.sh`

- Remove `~/.claude/compact-guard/` (ask confirmation for backups)
- Remove hook scripts from `~/.claude/hooks/`
- Remove only our hook entries from `settings.json`
- Remove rules between guard markers from `CLAUDE.md`
- Remove `ccg` symlink

---

### 3. `hooks/pre-compact.sh`

**Trigger:** Claude Code fires this before every compaction (manual or auto).

**Input (stdin JSON from Claude Code):**
```json
{
  "session_id": "abc123",
  "compact_type": "auto",
  "transcript_path": "/tmp/..."
}
```

**Actions:**
1. Read `~/.claude/compact-guard/current-task.md`
2. Create timestamped backup: `backups/YYYY-MM-DD_HH-MM-SS.md`
3. Backup format:
   ```markdown
   # Compact Guard Backup
   - Date: 2026-02-05T14:30:22
   - Type: auto
   - Session: abc123

   ## Current Task
   [contents of current-task.md]
   ```
4. Rotate: delete oldest backups beyond `max_backups` (from config.json)
5. Update `state.json`: set `last_compaction`, `last_compaction_type`, increment `total_compactions`

---

### 4. `hooks/session-start.sh`

**Trigger:** Claude Code fires this when a session starts.

**Actions:**
1. Read `state.json`
2. If `last_compaction` is within the last 60 seconds:
   - Write marker file `~/.claude/compact-guard/.just-compacted`
3. The CLAUDE.md rules tell Claude to check for this marker and re-read context

---

### 5. `bin/ccg` - CLI

Pure bash script. All commands:

| Command | Description |
|---------|-------------|
| `ccg status` | Current state: last compaction, task, backup count, hook health |
| `ccg task` | Show current task |
| `ccg task set` | Set current task (opens `$EDITOR` or reads stdin) |
| `ccg task clear` | Clear current task to template |
| `ccg backups` | List all backups with timestamps |
| `ccg backups show` | Show most recent backup |
| `ccg restore` | Copy latest backup to current-task.md |
| `ccg config` | Show config |
| `ccg config set <key> <value>` | Update config value |
| `ccg help` | Show help |
| `ccg version` | Print version |

**`ccg status` output:**
```
claude-compact-guard v1.0.0
===========================
Last compaction:  2026-02-05 14:30 (auto) - 2h ago
Total compactions: 7
Backups stored:   7/10
Current task:     "Implement user auth for pen-backend"
Hooks:            pre-compact [OK]  session-start [OK]
```

---

### 6. `templates/claude-rules.md`

Rules appended to user's `~/.claude/CLAUDE.md`:

```markdown
<!-- CLAUDE-COMPACT-GUARD:START -->
## Context Compaction Awareness

You have claude-compact-guard installed. Follow these rules:

1. **At task start:** Write the current objective to `~/.claude/compact-guard/current-task.md`:
   ```
   Objective: [what the user wants]
   Key files: [files involved]
   Decisions made: [important choices]
   Last action: [what was just done]
   Next step: [what comes next]
   ```

2. **When context feels unclear or after compaction:** Read `~/.claude/compact-guard/current-task.md` and ask the user to confirm the objective is still correct.

3. **Before major actions:** Update `current-task.md` with latest decisions and progress.

4. **If `~/.claude/compact-guard/.just-compacted` exists:** Read `current-task.md`, summarize what you remember to the user, ask for confirmation, then delete the `.just-compacted` marker file.
<!-- CLAUDE-COMPACT-GUARD:END -->
```

---

### 7. `templates/current-task.md`

```markdown
# Current Task

Objective: (not set)
Key files: (none)
Decisions made: (none)
Last action: (none)
Next step: (none)

---
Updated: (never)
```

---

### 8. Default `config.json`

```json
{
  "max_backups": 10,
  "language": "en",
  "auto_confirm_after_compact": false,
  "backup_transcript": true
}
```

### 9. Default `state.json`

```json
{
  "last_compaction": null,
  "last_compaction_type": null,
  "total_compactions": 0,
  "install_date": "ISO-8601 timestamp",
  "version": "1.0.0"
}
```

---

## Technical Constraints

| Constraint | Detail |
|------------|--------|
| Runtime | Pure bash, zero external dependencies |
| JSON | `jq` preferred, `python3 -c` fallback, `sed` last resort |
| Platform | macOS (Darwin) + Linux (Ubuntu/Debian) |
| Safety | Never overwrite user files, always merge with guard markers |
| Idempotency | Install twice = same result as once |
| Atomicity | Temp file + `mv` pattern for state/config writes |

---

## README.md Structure

1. Header + one-line description + badges (license, version, bash)
2. The Problem (2-3 sentences)
3. The Solution (3 bullets)
4. Quick Demo (terminal screenshot placeholder)
5. Install (one-liner)
6. How It Works (flow diagram)
7. CLI Usage (all `ccg` commands with examples)
8. Configuration (options table)
9. Uninstall (one command)
10. Contributing
11. License (MIT)

---

## Implementation Order

1. `templates/` - Static files (claude-rules.md, current-task.md)
2. `hooks/pre-compact.sh` - Core backup logic
3. `hooks/session-start.sh` - Compaction detection
4. `bin/ccg` - CLI with all commands
5. `install.sh` - Installer
6. `uninstall.sh` - Uninstaller
7. `README.md` - GitHub documentation
8. `LICENSE` - MIT
9. `.gitignore` + git init
10. Manual testing of full flow

---

## Code Quality

- Named constants, no magic numbers/strings
- Actionable error messages
- One function = one responsibility
- Comments explain WHY, not WHAT
- Early returns over nested conditions
- Shellcheck compliant (`shellcheck *.sh`)
