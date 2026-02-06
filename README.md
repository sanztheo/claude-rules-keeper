<p align="center">
  <h1 align="center">claude-rules-keeper</h1>
  <p align="center">
    <strong>Claude Code never forgets your rules.</strong><br>
    Persistent rules & context that survive compaction.
  </p>
  <p align="center">
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
    <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Made%20with-Bash-1f425f.svg" alt="Bash"></a>
    <a href="https://github.com/sanztheo/claude-rules-keeper/releases"><img src="https://img.shields.io/badge/version-1.3.0-blue.svg" alt="Version"></a>
    <a href="https://github.com/sanztheo/claude-rules-keeper/actions"><img src="https://github.com/sanztheo/claude-rules-keeper/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="https://github.com/sanztheo/claude-rules-keeper"><img src="https://img.shields.io/github/stars/sanztheo/claude-rules-keeper?style=social" alt="GitHub Stars"></a>
  </p>
</p>

---

## Why?

When Claude Code's context window fills up (~75-92%), it **automatically compresses** your conversation. This is called **compaction**, and it causes real problems:

| What happens | Impact |
|---|---|
| Custom rules get summarized | Claude stops following your coding standards |
| Task details get paraphrased | Accuracy drops from ~95% to ~60-70% |
| Working context is lost | Claude forgets what you were building |
| No built-in recovery | You have to re-explain everything |

**claude-rules-keeper** keeps your **persistent rules** and **task context** alive across compactions using a 2-layer protection system + slash commands to manage rules.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/sanztheo/claude-rules-keeper/main/install.sh | bash
```

That's it. Zero dependencies. Pure bash. Works on **macOS** and **Linux**.

> **Or clone and install locally:**
> ```bash
> git clone https://github.com/sanztheo/claude-rules-keeper.git
> cd claude-rules-keeper && ./install.sh
> ```

## How It Works

### 2-Layer Protection

```
  LAYER 1: CLAUDE.md Rules (passive)          ~70% compliance alone
  ──────────────────────────────────
  Injected into ~/.claude/CLAUDE.md
  between guard markers. Claude reads
  these as system instructions.

          +

  LAYER 2: rules-keeper Skill (active)       ~90% compliance alone
  ──────────────────────────────────────
  Installed to ~/.claude/skills/
  Invoked at the START of every
  conversation. Claude actively follows
  the skill + auto-detects new rules.

          =

  COMBINED: ~97%+ compliance
```

### 4-Scope Rules System

Your rules are organized in 4 scopes:

| Scope | File | Lifetime |
|---|---|---|
| **Session** | `~/.claude/rules-keeper/session-rules.md` | Current conversation only (cleared on new conv, survives compaction) |
| **Global** | `~/.claude/rules-keeper/rules.md` | Permanent, all conversations |
| **Project** | `~/.claude/rules-keeper/projects/<project>/rules.md` | Permanent, when in that project |
| **Task** | `~/.claude/rules-keeper/current-task.md` | Current session only |

**Session rules** live for the current conversation only — they survive compaction but are automatically cleared when you start a new conversation. **Global rules** apply everywhere, forever. **Project rules** apply only in a specific git repo. **Task state** tracks what you're currently doing.

### The Flow

```
  You're coding with Claude Code
              │
              ▼
  ┌─────────────────────────────┐
  │   rules-keeper skill        │  ← Layer 2 (active)
  │   loads at conversation     │
  │   start                     │
  │                             │
  │  ✓ Reads session rules       │
  │  ✓ Reads global rules       │
  │  ✓ Reads project rules      │
  │  ✓ Auto-detects new rules   │
  │  ✓ Writes task state        │
  └──────────────┬──────────────┘
                 │
  Context window fills up (~75-92%)
                 │
                 ▼
  ┌─────────────────────────────┐
  │     PreCompact Hook         │  ← Backup layer
  │                             │
  │  ✓ Extracts context from    │
  │    transcript               │
  │  ✓ Creates timestamped      │
  │    backup                   │
  └──────────────┬──────────────┘
                 │
        Compaction happens
                 │
                 ▼
  ┌─────────────────────────────┐
  │    SessionStart Hook        │  ← Recovery layer
  │                             │
  │  ✓ Injects global rules     │
  │  ✓ Injects project rules    │
  │  ✓ Injects session rules    │
  │  ✓ Injects task context     │
  │    via additionalContext     │
  └─────────────────────────────┘
```

### Slash Commands

Manage your rules directly from Claude Code:

| Command | Description |
|---|---|
| `/rules <text>` | Add a session rule (this conversation only, survives compaction) |
| `/rules-global <text>` | Add a permanent rule (all conversations, forever) |
| `/rules-create <text>` | Claude reformulates, you validate, then saved to session |
| `/rules-project <text>` | Add a permanent rule for the current project |
| `/rules-show` | Display all active rules (session + global + project) |
| `/rules-remove` | Remove a specific rule by number |
| `/rules-clear` | Clear all session rules |
| `/rules-save <name>` | Save current rules as a reusable preset |
| `/rules-load <name>` | Load a preset into the current session |

### Auto-Detection

The skill also detects when you state a preference during conversation and saves it automatically. By default, preferences are saved to **session scope** unless the user explicitly wants it permanent:

> "utilise async/await" → saved to **session** rules
> "toujours utiliser async/await" → saved to **global** rules (keyword "toujours")
> "dans ce projet on utilise Zod" → saved to **project** rules

### What gets saved?

**Session rules** last for the current conversation:
```markdown
# Session Rules

- Use async/await for this task
- Keep functions under 20 lines
```

**Global rules** persist forever:
```markdown
# Persistent Rules

- Commits: no AI references, no Co-Authored-By
- TypeScript: never use any, prefer unknown + narrowing
```

**Task state** tracks your current work:
```markdown
# Current Task

Objective: Implement OAuth2 login flow
Key files: src/auth/oauth.ts, src/middleware/auth.ts
Last action: Created token refresh middleware
Next step: Add logout endpoint and token revocation
```

## What Gets Installed

The installer sets up everything automatically:

| Component | Location | Purpose |
|---|---|---|
| **rules-keeper skill** | `~/.claude/skills/rules-keeper/` | Active layer - reads rules, auto-detects new ones |
| **CLAUDE.md rules** | `~/.claude/CLAUDE.md` (appended) | Passive layer - rules between guard markers |
| **Slash commands** | `~/.claude/commands/rules*.md` | 9 commands for managing rules |
| **PreCompact hook** | `~/.claude/hooks/pre-compact.sh` | Creates backups before compaction |
| **SessionStart hook** | `~/.claude/hooks/session-start.sh` | Injects rules + context after compaction |
| **crk CLI** | `~/.local/bin/crk` | Status, backups, restore, config |
| **Hook config** | `~/.claude/settings.json` (merged) | Registers hooks with Claude Code |

## CLI

The `crk` command gives you full control over your backups and task tracking.

### Status Dashboard

```bash
$ crk status
```
```
claude-rules-keeper v1.3.0
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
| `crk status` | Dashboard: last compaction, task, backups, hook health |
| `crk task` | Show current task |
| `crk task set` | Set current task (opens `$EDITOR` or reads stdin) |
| `crk task clear` | Reset task to empty template |
| `crk backups` | List all backups with timestamps |
| `crk backups show` | Show the most recent backup |
| `crk restore` | Restore latest backup to current task |
| `crk config` | Show configuration |
| `crk config set <key> <value>` | Update a config value |
| `crk rules` | Show all active rules (session + global + project) |
| `crk presets` | List saved rule presets |
| `crk doctor` | Run diagnostic checks on installation |
| `crk upgrade` | Check for updates and upgrade |
| `crk help` | Show help |
| `crk version` | Print version |

### Examples

```bash
# Check installation status
crk status

# View the last saved context
crk backups show

# Restore context after a bad compaction
crk restore

# Keep more backups
crk config set max_backups 20
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
├── rules-keeper/
│   ├── rules.md              # Global persistent rules
│   ├── session-rules.md      # Session rules (auto-cleared on new conv)
│   ├── projects/
│   │   └── my-app/
│   │       └── rules.md      # Project-specific rules
│   ├── presets/
│   │   └── typescript.md     # Saved rule presets
│   ├── backups/              # Rotating context snapshots
│   ├── current-task.md       # Current task state
│   ├── state.json            # Compaction stats
│   └── config.json           # User preferences
├── commands/
│   ├── rules.md              # /rules (session)
│   ├── rules-global.md       # /rules-global (permanent)
│   ├── rules-create.md       # /rules-create (reformulate)
│   ├── rules-project.md      # /rules-project (per-project)
│   ├── rules-show.md         # /rules-show (display all)
│   ├── rules-remove.md       # /rules-remove (delete by number)
│   ├── rules-clear.md        # /rules-clear (clear session)
│   ├── rules-save.md         # /rules-save (preset)
│   └── rules-load.md         # /rules-load (preset)
├── hooks/
│   ├── pre-compact.sh        # Backup before compaction
│   └── session-start.sh      # Rules + context injection after compaction
├── skills/
│   └── rules-keeper/
│       └── SKILL.md          # Active skill (Layer 2)
├── settings.json             # Claude Code hooks config (merged)
└── CLAUDE.md                 # Guard markers (Layer 1)
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
curl -fsSL https://raw.githubusercontent.com/sanztheo/claude-rules-keeper/main/uninstall.sh | bash
```

Or locally: `./uninstall.sh`

The uninstaller removes everything cleanly: hook entries from `settings.json`, guard markers from `CLAUDE.md`, the rules-keeper skill, slash commands, and optionally preserves your backups.

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

Testing showed that a CLAUDE.md rule alone achieves ~70% compliance - Claude sometimes skips following it. The skill layer actively triggers at conversation start, bringing compliance to ~90%+. Combined, they provide near-100% coverage.
</details>

<details>
<summary><strong>What's the difference between session, global, and project rules?</strong></summary>

**Session rules** (`session-rules.md`) live for the current conversation only — they survive compaction but are cleared when you open a new conversation. **Global rules** (`rules.md`) apply in every conversation forever. **Project rules** (`projects/<name>/rules.md`) apply only when you're in a specific git repo. `/rules` defaults to session scope. Use `/rules-global` for permanent rules.
</details>

<details>
<summary><strong>What are presets?</strong></summary>

Presets let you save a snapshot of your current rules (global + project) and reload them later. Use `/rules-save typescript-strict` to save, `/rules-load typescript-strict` to reload in any conversation. Think of them as rule "profiles".
</details>

<details>
<summary><strong>How does recovery work after compaction?</strong></summary>

The `SessionStart` hook detects compaction via the `"compact"` matcher. It injects global rules, project rules, session rules, and task context directly into Claude's context using `additionalContext` - guaranteed injection, not optional file reading. On new conversations (no compaction), it clears session rules automatically.
</details>

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Ensure all scripts pass shellcheck:
   ```bash
   shellcheck hooks/*.sh bin/crk install.sh uninstall.sh
   ```
4. Run the tests:
   ```bash
   ./tests/bats/bin/bats tests/*.bats
   ```
5. Test the install/uninstall flow
6. Open a Pull Request

## License

[MIT](LICENSE) - Use it however you want.

---

<p align="center">
  <sub>Built for developers who are tired of re-explaining their task to Claude after every compaction.</sub>
</p>
