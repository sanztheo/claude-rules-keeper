<p align="center">
  <h1 align="center">claude-compact-guard</h1>
  <p align="center">
    <strong>Never lose context again.</strong><br>
    Multi-layered context protection for Claude Code compaction events.
  </p>
  <p align="center">
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
    <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Made%20with-Bash-1f425f.svg" alt="Bash"></a>
    <a href="https://github.com/sanztheo/claude-compact-guard/releases"><img src="https://img.shields.io/badge/version-1.1.0-blue.svg" alt="Version"></a>
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

**claude-compact-guard** uses a **2-layer protection system** to ensure Claude never loses your work context.

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

## How It Works: 2-Layer Protection

Unlike tools that rely on a single mechanism, claude-compact-guard stacks **two independent layers** to maximize compliance:

```
  LAYER 1: CLAUDE.md Rules (passive)          ~70% compliance alone
  ──────────────────────────────────
  Injected into ~/.claude/CLAUDE.md
  between guard markers. Claude reads
  these rules as part of its system
  instructions.

          +

  LAYER 2: context-guard Skill (active)       ~90% compliance alone
  ──────────────────────────────────────
  Installed to ~/.claude/skills/
  Invoked at the START of every
  conversation. Claude actively
  processes and follows the skill.

          =

  COMBINED: ~97%+ compliance
  ──────────────────────────────────
  Claude writes to current-task.md
  at task start, after decisions,
  and before stopping.
```

### The Flow

```
  You're coding with Claude Code
              │
              ▼
  Claude starts a task
              │
              ▼
  ┌─────────────────────────────┐
  │   context-guard skill       │  ← Layer 2 (active)
  │   triggers automatically    │
  │                             │
  │   Claude writes objective,  │
  │   key files, decisions to   │
  │   current-task.md           │
  └──────────────┬──────────────┘
                 │
  Context window fills up (~75-92%)
                 │
                 ▼
  ┌─────────────────────────────┐
  │     PreCompact Hook         │  ← Backup layer
  │                             │
  │  ✓ Extracts context from    │
  │    transcript (python3)     │
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
  │    SessionStart Hook        │  ← Recovery layer
  │                             │
  │  ✓ Detects compaction       │
  │  ✓ Injects saved context    │
  │    via additionalContext    │
  │  ✓ Claude resumes with      │
  │    full awareness           │
  └─────────────────────────────┘
```

### What gets saved?

Claude maintains a **structured snapshot** of your current work in `~/.claude/compact-guard/current-task.md`:

```markdown
# Current Task

Objective: Implement OAuth2 login flow
Key files: src/auth/oauth.ts, src/middleware/auth.ts
Decisions made: Using PKCE flow, storing tokens in httpOnly cookies
Rules to follow: No any types, async/await only, early returns
Last action: Created token refresh middleware
Next step: Add logout endpoint and token revocation
```

## What Gets Installed

The installer sets up everything automatically:

| Component | Location | Purpose |
|---|---|---|
| **context-guard skill** | `~/.claude/skills/context-guard/` | Active layer - forces Claude to maintain current-task.md |
| **CLAUDE.md rules** | `~/.claude/CLAUDE.md` (appended) | Passive layer - rules between guard markers |
| **PreCompact hook** | `~/.claude/hooks/pre-compact.sh` | Creates backups before compaction |
| **SessionStart hook** | `~/.claude/hooks/session-start.sh` | Injects context after compaction |
| **ccg CLI** | `~/.local/bin/ccg` | Status, backups, restore, config |
| **Hook config** | `~/.claude/settings.json` (merged) | Registers hooks with Claude Code |

## CLI

The `ccg` command gives you full control over your backups and task tracking.

### Status Dashboard

```bash
$ ccg status
```
```
claude-compact-guard v1.1.0
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
# Check installation status
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
│   ├── current-task.md       # Current task (maintained by Claude)
│   ├── state.json            # Compaction stats & timestamps
│   └── config.json           # User preferences
├── hooks/
│   ├── pre-compact.sh        # Backup before compaction
│   └── session-start.sh      # Context injection after compaction
├── skills/
│   └── context-guard/
│       └── SKILL.md          # Active skill (Layer 2)
├── settings.json             # Claude Code hooks config (merged safely)
└── CLAUDE.md                 # Rules between guard markers (Layer 1)
```

### Design Principles

| Principle | How |
|---|---|
| **2-layer protection** | Passive rules + active skill = ~97%+ compliance |
| **Zero dependencies** | Pure bash, no Node/Python runtime needed |
| **Never overwrites** | Merges into `settings.json`, appends to `CLAUDE.md` with guard markers |
| **Idempotent** | Running install twice produces the same result |
| **Atomic writes** | Uses `tmp + mv` pattern to prevent file corruption |
| **JSON fallback chain** | `jq` > `python3` > `grep/sed` (works everywhere) |
| **Guaranteed recovery** | SessionStart hook injects context via `additionalContext` - no reliance on Claude reading files |

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/sanztheo/claude-compact-guard/main/uninstall.sh | bash
```

Or locally: `./uninstall.sh`

The uninstaller removes everything cleanly: hook entries from `settings.json`, guard markers from `CLAUDE.md`, the context-guard skill, and optionally preserves your backups.

## FAQ

<details>
<summary><strong>Does this work with manual /compact too?</strong></summary>

Yes. The `PreCompact` hook fires for both automatic and manual compaction events. Both are backed up with the type recorded (`auto` or `manual`).
</details>

<details>
<summary><strong>Will this slow down Claude Code?</strong></summary>

No. The hooks run in under 100ms. The skill adds zero latency - it's just instructions that Claude reads at task start.
</details>

<details>
<summary><strong>What if I don't have jq installed?</strong></summary>

The tool falls back to `python3` for JSON operations, then to `grep/sed` as a last resort. Most systems have at least one of these available.
</details>

<details>
<summary><strong>Why two layers instead of one?</strong></summary>

Testing showed that a CLAUDE.md rule alone achieves ~70% compliance - Claude sometimes skips writing to the file. The skill layer actively triggers at conversation start, bringing compliance to ~90%+. Combined, they provide near-100% coverage.
</details>

<details>
<summary><strong>What's the difference between the skill and the CLAUDE.md rule?</strong></summary>

The **CLAUDE.md rule** (Layer 1) is passive - it's text in Claude's system instructions that it may or may not follow. The **skill** (Layer 2) is active - it gets invoked as a specific instruction set that Claude processes and follows, with anti-rationalization patterns built in.
</details>

<details>
<summary><strong>How does recovery work after compaction?</strong></summary>

The `SessionStart` hook detects when a session starts after compaction (via the `"compact"` matcher). It reads `current-task.md` and injects it directly into Claude's context using `additionalContext` - this is guaranteed injection, not optional reading.
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
