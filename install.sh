#!/usr/bin/env bash
set -euo pipefail

# claude-compact-guard installer
# Usage: curl -fsSL https://raw.githubusercontent.com/sanztheo/claude-compact-guard/main/install.sh | bash

readonly VERSION="1.0.0"
readonly CLAUDE_DIR="${HOME}/.claude"
readonly GUARD_DIR="${CLAUDE_DIR}/compact-guard"
readonly HOOKS_DIR="${CLAUDE_DIR}/hooks"
readonly BACKUPS_DIR="${GUARD_DIR}/backups"
readonly SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
readonly CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
readonly BIN_DIR="${HOME}/.local/bin"

readonly GUARD_MARKER_START="<!-- CLAUDE-COMPACT-GUARD:START -->"
readonly GUARD_MARKER_END="<!-- CLAUDE-COMPACT-GUARD:END -->"

readonly REPO_URL="https://raw.githubusercontent.com/sanztheo/claude-compact-guard/main"

# --- Colors ---

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'

# --- Helpers ---

info() { echo -e "${BLUE}[info]${RESET} $1"; }
success() { echo -e "${GREEN}[ok]${RESET} $1"; }
warn() { echo -e "${YELLOW}[warn]${RESET} $1"; }
error() { echo -e "${RED}[error]${RESET} $1" >&2; }

atomic_write() {
    local target="$1"
    local content="$2"
    local tmp="${target}.tmp.$$"
    echo "${content}" > "${tmp}"
    mv "${tmp}" "${target}"
}

# --- Step 1: Create directory structure ---

create_directories() {
    info "Creating directory structure..."
    mkdir -p "${GUARD_DIR}" "${BACKUPS_DIR}" "${HOOKS_DIR}" "${BIN_DIR}"
    success "Directories created"
}

# --- Step 2: Download/copy hook scripts ---

install_hooks() {
    info "Installing hook scripts..."

    # Detect if running from cloned repo or curl pipe
    local script_dir=""
    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    fi

    if [[ -n "${script_dir}" && -f "${script_dir}/hooks/pre-compact.sh" ]]; then
        cp "${script_dir}/hooks/pre-compact.sh" "${HOOKS_DIR}/pre-compact.sh"
        cp "${script_dir}/hooks/session-start.sh" "${HOOKS_DIR}/session-start.sh"
    else
        # Download from GitHub
        curl -fsSL "${REPO_URL}/hooks/pre-compact.sh" -o "${HOOKS_DIR}/pre-compact.sh"
        curl -fsSL "${REPO_URL}/hooks/session-start.sh" -o "${HOOKS_DIR}/session-start.sh"
    fi

    chmod +x "${HOOKS_DIR}/pre-compact.sh"
    chmod +x "${HOOKS_DIR}/session-start.sh"
    success "Hooks installed"
}

# --- Step 3: Install CLI ---

install_cli() {
    info "Installing ccg CLI..."

    local script_dir=""
    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    fi

    if [[ -n "${script_dir}" && -f "${script_dir}/bin/ccg" ]]; then
        cp "${script_dir}/bin/ccg" "${BIN_DIR}/ccg"
    else
        curl -fsSL "${REPO_URL}/bin/ccg" -o "${BIN_DIR}/ccg"
    fi

    chmod +x "${BIN_DIR}/ccg"
    success "CLI installed at ${BIN_DIR}/ccg"
}

# --- Step 4: Merge hooks into settings.json ---

merge_settings() {
    info "Configuring Claude Code hooks..."

    local hook_config_pre_compact
    hook_config_pre_compact=$(cat <<'HOOKJSON'
{
    "type": "command",
    "event": "PreCompact",
    "command": "~/.claude/hooks/pre-compact.sh",
    "timeout": 10000
}
HOOKJSON
)

    local hook_config_session_start
    hook_config_session_start=$(cat <<'HOOKJSON'
{
    "type": "command",
    "event": "SessionStart",
    "command": "~/.claude/hooks/session-start.sh",
    "timeout": 5000
}
HOOKJSON
)

    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        # Create fresh settings
        cat > "${SETTINGS_FILE}" <<'EOF'
{
  "hooks": {
    "PreCompact": [
      {
        "type": "command",
        "command": "~/.claude/hooks/pre-compact.sh",
        "timeout": 10000
      }
    ],
    "SessionStart": [
      {
        "type": "command",
        "command": "~/.claude/hooks/session-start.sh",
        "timeout": 5000
      }
    ]
  }
}
EOF
        success "Created settings.json with hooks"
        return
    fi

    # Merge into existing settings
    if command -v jq &>/dev/null; then
        merge_settings_jq
    elif command -v python3 &>/dev/null; then
        merge_settings_python
    else
        merge_settings_sed
    fi
}

merge_settings_jq() {
    local tmp="${SETTINGS_FILE}.tmp.$$"

    jq '
    .hooks //= {} |
    .hooks.PreCompact //= [] |
    .hooks.SessionStart //= [] |
    (if (.hooks.PreCompact | map(select(.command == "~/.claude/hooks/pre-compact.sh")) | length) == 0
     then .hooks.PreCompact += [{"type": "command", "command": "~/.claude/hooks/pre-compact.sh", "timeout": 10000}]
     else . end) |
    (if (.hooks.SessionStart | map(select(.command == "~/.claude/hooks/session-start.sh")) | length) == 0
     then .hooks.SessionStart += [{"type": "command", "command": "~/.claude/hooks/session-start.sh", "timeout": 5000}]
     else . end)
    ' "${SETTINGS_FILE}" > "${tmp}" && mv "${tmp}" "${SETTINGS_FILE}"

    success "Merged hooks into settings.json (jq)"
}

merge_settings_python() {
    local tmp="${SETTINGS_FILE}.tmp.$$"

    python3 -c "
import json

with open('${SETTINGS_FILE}') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
pre_compact = hooks.setdefault('PreCompact', [])
session_start = hooks.setdefault('SessionStart', [])

pre_exists = any(h.get('command') == '~/.claude/hooks/pre-compact.sh' for h in pre_compact)
if not pre_exists:
    pre_compact.append({'type': 'command', 'command': '~/.claude/hooks/pre-compact.sh', 'timeout': 10000})

ss_exists = any(h.get('command') == '~/.claude/hooks/session-start.sh' for h in session_start)
if not ss_exists:
    session_start.append({'type': 'command', 'command': '~/.claude/hooks/session-start.sh', 'timeout': 5000})

with open('${tmp}', 'w') as f:
    json.dump(settings, f, indent=2)
" && mv "${tmp}" "${SETTINGS_FILE}"

    success "Merged hooks into settings.json (python3)"
}

merge_settings_sed() {
    # Last resort: check if hooks already exist, skip if so
    if grep -q "pre-compact.sh" "${SETTINGS_FILE}" 2>/dev/null; then
        warn "Hooks appear to already exist in settings.json (sed fallback - skipping merge)"
        return
    fi

    warn "Cannot safely merge settings.json without jq or python3"
    warn "Please install jq (brew install jq) and re-run, or manually add hooks"
    echo ""
    echo "Add to ~/.claude/settings.json:"
    echo '  "hooks": {'
    echo '    "PreCompact": [{"type": "command", "command": "~/.claude/hooks/pre-compact.sh", "timeout": 10000}],'
    echo '    "SessionStart": [{"type": "command", "command": "~/.claude/hooks/session-start.sh", "timeout": 5000}]'
    echo '  }'
}

# --- Step 5: Append rules to CLAUDE.md ---

append_claude_rules() {
    info "Configuring CLAUDE.md rules..."

    # Check if already present
    if [[ -f "${CLAUDE_MD}" ]] && grep -q "${GUARD_MARKER_START}" "${CLAUDE_MD}" 2>/dev/null; then
        success "CLAUDE.md rules already present (skipping)"
        return
    fi

    # Load rules template
    local rules_content=""
    local script_dir=""
    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    fi

    if [[ -n "${script_dir}" && -f "${script_dir}/templates/claude-rules.md" ]]; then
        rules_content=$(cat "${script_dir}/templates/claude-rules.md")
    else
        rules_content=$(curl -fsSL "${REPO_URL}/templates/claude-rules.md" 2>/dev/null) || true
    fi

    if [[ -z "${rules_content}" ]]; then
        # Inline fallback
        rules_content=$(cat <<'RULES'
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
RULES
)
    fi

    # Append to CLAUDE.md (create if needed)
    if [[ -f "${CLAUDE_MD}" ]]; then
        echo "" >> "${CLAUDE_MD}"
        echo "${rules_content}" >> "${CLAUDE_MD}"
    else
        echo "${rules_content}" > "${CLAUDE_MD}"
    fi

    success "Rules appended to CLAUDE.md"
}

# --- Step 6: Initialize current-task.md ---

init_task_file() {
    if [[ -f "${GUARD_DIR}/current-task.md" ]]; then
        success "current-task.md already exists (keeping)"
        return
    fi

    local script_dir=""
    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    fi

    if [[ -n "${script_dir}" && -f "${script_dir}/templates/current-task.md" ]]; then
        cp "${script_dir}/templates/current-task.md" "${GUARD_DIR}/current-task.md"
    else
        curl -fsSL "${REPO_URL}/templates/current-task.md" -o "${GUARD_DIR}/current-task.md" 2>/dev/null || cat > "${GUARD_DIR}/current-task.md" <<'EOF'
# Current Task

Objective: (not set)
Key files: (none)
Decisions made: (none)
Last action: (none)
Next step: (none)

---
Updated: (never)
EOF
    fi

    success "Task file initialized"
}

# --- Step 7: Initialize state.json and config.json ---

init_state_files() {
    if [[ ! -f "${GUARD_DIR}/state.json" ]]; then
        local install_date
        install_date=$(date "+%Y-%m-%dT%H:%M:%S")
        atomic_write "${GUARD_DIR}/state.json" "{
  \"last_compaction\": null,
  \"last_compaction_type\": null,
  \"total_compactions\": 0,
  \"install_date\": \"${install_date}\",
  \"version\": \"${VERSION}\"
}"
        success "state.json initialized"
    else
        success "state.json already exists (keeping)"
    fi

    if [[ ! -f "${GUARD_DIR}/config.json" ]]; then
        atomic_write "${GUARD_DIR}/config.json" '{
  "max_backups": 10,
  "language": "en",
  "auto_confirm_after_compact": false,
  "backup_transcript": true
}'
        success "config.json initialized"
    else
        success "config.json already exists (keeping)"
    fi
}

# --- Step 8: Check PATH ---

check_path() {
    if ! echo "${PATH}" | tr ':' '\n' | grep -q "^${BIN_DIR}$"; then
        warn "${BIN_DIR} is not in your PATH"
        echo ""
        local shell_rc=""
        if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL}" == *"zsh"* ]]; then
            shell_rc="${HOME}/.zshrc"
        else
            shell_rc="${HOME}/.bashrc"
        fi
        echo -e "  Add this to ${BOLD}${shell_rc}${RESET}:"
        echo -e "  ${DIM}export PATH=\"\${HOME}/.local/bin:\${PATH}\"${RESET}"
        echo ""
    fi
}

# --- Main ---

main() {
    echo ""
    echo -e "${BOLD}claude-compact-guard v${VERSION}${RESET}"
    echo -e "${DIM}Protecting Claude Code from context loss${RESET}"
    echo ""

    create_directories
    install_hooks
    install_cli
    merge_settings
    append_claude_rules
    init_task_file
    init_state_files
    check_path

    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
    echo ""
    echo -e "  ${BOLD}Quick start:${RESET}"
    echo -e "    ccg status     ${DIM}# Check installation${RESET}"
    echo -e "    ccg help       ${DIM}# See all commands${RESET}"
    echo ""
    echo -e "  ${DIM}Hooks are now active. Claude Code will automatically${RESET}"
    echo -e "  ${DIM}save context before compaction and detect resume.${RESET}"
    echo ""
}

main "$@"
