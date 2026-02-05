# claude-compact-guard

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/sanztheo/claude-compact-guard)

**Protect Claude Code from context loss during auto-compaction.**

## The Problem

When Claude Code's context window fills up (~75-92%), it automatically compresses the conversation. This causes loss of precise task details, paraphrased rules losing accuracy, and Claude forgetting what you were working on — with no built-in way to recover.

## The Solution

- **Pre-compaction hooks** save your current task and context before every compaction
- **Session-start hooks** detect when you resume after compaction and prompt Claude to re-read context
- **A CLI tool** (`ccg`) to manage tasks, view backups, and check system health

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sanztheo/claude-compact-guard/main/install.sh | bash
```

Zero dependencies. Pure bash. Works on macOS and Linux.

## How It Works

```
                    Context fills up
                          |
                          v
              ┌──────────────────────┐
              │   PreCompact Hook    │
              │                      │
              │ 1. Read current task │
              │ 2. Save backup       │
              │ 3. Update state      │
              └──────────┬───────────┘
                         |
                    Compaction happens
                         |
                         v
              ┌──────────────────────┐
              │  SessionStart Hook   │
              │                      │
              │ 1. Check timestamp   │
              │ 2. Write marker if   │
              │    < 60s ago         │
              └──────────┬───────────┘
                         |
                         v
              ┌──────────────────────┐
              │    Claude resumes    │
              │                      │
              │ 1. Sees marker file  │
              │ 2. Reads saved task  │
              │ 3. Confirms with you │
              │ 4. Continues work    │
              └──────────────────────┘
```

## CLI Usage

```bash
# Check system health
ccg status

# Manage your current task
ccg task              # Show current task
ccg task set          # Set task (opens $EDITOR or reads stdin)
ccg task clear        # Reset to template

# View backups
ccg backups           # List all backups
ccg backups show      # Show most recent backup
ccg restore           # Restore latest backup to current task

# Configuration
ccg config            # Show config
ccg config set max_backups 20

# Info
ccg help
ccg version
```

### Status Output

```
claude-compact-guard v1.0.0
===========================
Last compaction:  2026-02-05 14:30 (auto) - 2h ago
Total compactions: 7
Backups stored:   7/10
Current task:     "Implement user auth for pen-backend"
Hooks:            pre-compact [OK]  session-start [OK]
```

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `max_backups` | `10` | Maximum backup files to keep (oldest rotated out) |
| `language` | `"en"` | Language preference |
| `auto_confirm_after_compact` | `false` | Auto-confirm task after compaction |
| `backup_transcript` | `true` | Include transcript info in backups |

Edit with: `ccg config set <key> <value>`

## File Layout

```
~/.claude/
├── compact-guard/
│   ├── backups/              # Rotating context snapshots (max 10)
│   ├── current-task.md       # Current task being tracked
│   ├── state.json            # Compaction stats
│   └── config.json           # User preferences
├── hooks/
│   ├── pre-compact.sh        # Saves context before compaction
│   └── session-start.sh      # Detects post-compaction resume
└── settings.json              # Claude Code hooks config (merged)
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/sanztheo/claude-compact-guard/main/uninstall.sh | bash
```

Or if cloned locally:

```bash
./uninstall.sh
```

Backups can optionally be preserved during uninstall.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Ensure scripts pass `shellcheck` (`shellcheck hooks/*.sh bin/ccg install.sh uninstall.sh`)
4. Commit your changes
5. Push to the branch
6. Open a Pull Request

## License

[MIT](LICENSE)
