<p align="center">
  <h1 align="center">claude-compact-guard</h1>
  <p align="center">
    <strong>Never lose context again.</strong><br>
    Auto-backup & recovery for Claude Code compaction events.
  </p>
  <p align="center">
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
    <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Made%20with-Bash-1f425f.svg" alt="Bash"></a>
    <a href="https://github.com/sanztheo/claude-compact-guard/releases"><img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version"></a>
    <a href="https://github.com/sanztheo/claude-compact-guard"><img src="https://img.shields.io/github/stars/sanztheo/claude-compact-guard?style=social" alt="GitHub Stars"></a>
  </p>
</p>

---

## Why?

When Claude Code's context window fills up (~75-92%), it **automatically compresses** your conversation. This is called **compaction**, and it causes real problems:

| What happens | Impact |
|---|---|
| Task details get paraphrased | Accuracy drops from ~95% to ~60-70% |
| Custom rules get summarized | Claude stops following your coding standards |
| Working context is lost | Claude forgets what you were building |
| No built-in recovery | You have to re-explain everything |

**claude-compact-guard** hooks into Claude Code's lifecycle to automatically save your context before compaction and restore it seamlessly after.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/sanztheo/claude-compact-guard/main/install.sh | bash
```

That's it. Zero dependencies. Pure bash. Works on **macOS** and **Linux**.

> **Or clone and install locally:**
> ```bash
> git clone https://github.com/sanztheo/claude-compact-guard.git
> cd claude-compact-guard && ./install.sh
> ```

## How It Works

claude-compact-guard uses [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) to intercept compaction events:

```
  You're coding with Claude Code
              │
              ▼
  Context window fills up (~75-92%)
              │
              ▼
  ┌─────────────────────────────┐
  │     PreCompact Hook         │  ← claude-compact-guard
  │                             │
  │  ✓ Saves current task       │
  │  ✓ Creates timestamped      │
  │    backup                   │
  │  ✓ Updates compaction stats  │
  └──────────────┬──────────────┘
                 │
        Compaction happens
        (context compressed)
                 │
                 ▼
  ┌─────────────────────────────┐
  │    SessionStart Hook        │  ← claude-compact-guard
  │                             │
  │  ✓ Detects recent           │
  │    compaction (<60s)        │
  │  ✓ Writes .just-compacted   │
  │    marker                   │
  └──────────────┬──────────────┘
                 │
                 ▼
  ┌─────────────────────────────┐
  │    Claude resumes           │
  │                             │
  │  1. Sees marker file        │
  │  2. Reads saved task        │
  │  3. Asks you to confirm     │
  │  4. Picks up where you      │
  │     left off                │
  └─────────────────────────────┘
```

### What gets saved?

Before every compaction, the guard saves a **structured snapshot** of your current work:

```markdown
# Current Task

Objective: Implement OAuth2 login flow
Key files: src/auth/oauth.ts, src/middleware/auth.ts
Decisions made: Using PKCE flow, storing tokens in httpOnly cookies
Last action: Created token refresh middleware
Next step: Add logout endpoint and token revocation
```

Claude automatically updates this file as you work (via rules injected into your `CLAUDE.md`).

## CLI

The `ccg` command gives you full control over your backups and task tracking.

### Status Dashboard

```bash
$ ccg status
```
```
claude-compact-guard v1.0.0
===========================
Last compaction:  2026-02-05 14:30 (auto) - 2h ago
Total compactions: 7
Backups stored:   7/10
Current task:     "Implement OAuth2 login flow"
Hooks:            pre-compact [OK]  session-start [OK]
```

### All Commands

| Command | Description |
|---|---|
| `ccg status` | Dashboard: last compaction, task, backups, hook health |
| `ccg task` | Show current task |
| `ccg task set` | Set current task (opens `$EDITOR` or reads stdin) |
| `ccg task clear` | Reset task to empty template |
| `ccg backups` | List all backups with timestamps |
| `ccg backups show` | Show the most recent backup |
| `ccg restore` | Restore latest backup to current task |
| `ccg config` | Show configuration |
| `ccg config set <key> <value>` | Update a config value |
| `ccg help` | Show help |
| `ccg version` | Print version |

### Examples

```bash
# Set a task via pipe
echo "Objective: Fix authentication bug in login flow" | ccg task set

# Set a task with your editor
EDITOR=nano ccg task set

# Check how many compactions happened today
ccg status

# View the last saved context
ccg backups show

# Restore context after a bad compaction
ccg restore

# Keep more backups
ccg config set max_backups 20
```

## Configuration

| Key | Default | Description |
|---|---|---|
| `max_backups` | `10` | Maximum backup files to keep (oldest are rotated out) |
| `language` | `"en"` | Language preference |
| `auto_confirm_after_compact` | `false` | Auto-confirm task after compaction |
| `backup_transcript` | `true` | Include transcript info in backups |

## Architecture

```
~/.claude/
├── compact-guard/
│   ├── backups/              # Rotating context snapshots
│   │   ├── 2026-02-05_14-30-22.md
│   │   └── 2026-02-05_16-45-10.md
│   ├── current-task.md       # Current task (updated by Claude)
│   ├── state.json            # Compaction stats & timestamps
│   └── config.json           # User preferences
├── hooks/
│   ├── pre-compact.sh        # Runs before every compaction
│   └── session-start.sh      # Runs on session start
├── settings.json             # Claude Code hooks config (merged safely)
└── CLAUDE.md                 # Rules injected between guard markers
```

### Design Principles

| Principle | How |
|---|---|
| **Zero dependencies** | Pure bash, no Node/Python runtime needed |
| **Never overwrites** | Merges into `settings.json`, appends to `CLAUDE.md` with guard markers |
| **Idempotent** | Running install twice produces the same result |
| **Atomic writes** | Uses `tmp + mv` pattern to prevent file corruption |
| **JSON fallback chain** | `jq` → `python3` → `grep/sed` (works everywhere) |

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/sanztheo/claude-compact-guard/main/uninstall.sh | bash
```

Or locally: `./uninstall.sh`

The uninstaller will ask if you want to **preserve your backups** before removing everything. It cleanly removes hook entries from `settings.json` and guard markers from `CLAUDE.md` without touching the rest of your config.

## FAQ

<details>
<summary><strong>Does this work with manual /compact too?</strong></summary>

Yes. The `PreCompact` hook fires for both automatic and manual compaction events. Both are backed up with the type recorded (`auto` or `manual`).
</details>

<details>
<summary><strong>Will this slow down Claude Code?</strong></summary>

No. The hooks run in under 100ms. They read a small markdown file, write a backup, and update a JSON counter. No network calls, no heavy processing.
</details>

<details>
<summary><strong>What if I don't have jq installed?</strong></summary>

The tool falls back to `python3` for JSON operations, then to `grep/sed` as a last resort. Most systems have at least one of these available.
</details>

<details>
<summary><strong>Does it modify my existing Claude Code settings?</strong></summary>

It **merges** hook entries into your `settings.json` without overwriting existing config. Rules are appended to `CLAUDE.md` between clearly marked `<!-- CLAUDE-COMPACT-GUARD:START/END -->` markers. The uninstaller removes only what it added.
</details>

<details>
<summary><strong>How many backups are kept?</strong></summary>

10 by default. The oldest are automatically rotated out. Change with `ccg config set max_backups 20`.
</details>

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Ensure all scripts pass shellcheck:
   ```bash
   shellcheck hooks/*.sh bin/ccg install.sh uninstall.sh
   ```
4. Test the install/uninstall flow
5. Open a Pull Request

## License

[MIT](LICENSE) - Use it however you want.

---

<p align="center">
  <sub>Built for developers who are tired of re-explaining their task to Claude after every compaction.</sub>
</p>
