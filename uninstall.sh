#!/usr/bin/env bash
set -euo pipefail

# claude-rules-keeper uninstaller
# Cleanly removes all components

readonly CLAUDE_DIR="${HOME}/.claude"
readonly GUARD_DIR="${CLAUDE_DIR}/rules-keeper"
readonly HOOKS_DIR="${CLAUDE_DIR}/hooks"
readonly SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
readonly CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
readonly BIN_DIR="${HOME}/.local/bin"

readonly GUARD_MARKER_START="<!-- CLAUDE-RULES-KEEPER:START -->"
readonly GUARD_MARKER_END="<!-- CLAUDE-RULES-KEEPER:END -->"

# --- Colors ---

readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'

info() { echo -e "${YELLOW}[remove]${RESET} $1"; }
success() { echo -e "${GREEN}[ok]${RESET} $1"; }
warn() { echo -e "${YELLOW}[warn]${RESET} $1"; }

# --- Step 1: Remove hook scripts ---

remove_hooks() {
    local removed=0

    if [[ -f "${HOOKS_DIR}/pre-compact.sh" ]]; then
        rm -f "${HOOKS_DIR}/pre-compact.sh"
        removed=1
    fi

    if [[ -f "${HOOKS_DIR}/session-start.sh" ]]; then
        rm -f "${HOOKS_DIR}/session-start.sh"
        removed=1
    fi

    if [[ "${removed}" -eq 1 ]]; then
        success "Hook scripts removed"
    else
        warn "No hook scripts found"
    fi
}

# --- Step 2: Remove hook entries from settings.json ---

remove_settings_hooks() {
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        warn "No settings.json found"
        return
    fi

    if command -v jq &>/dev/null; then
        local tmp="${SETTINGS_FILE}.tmp.$$"
        jq '
        if .hooks then
            .hooks.PreCompact //= [] |
            .hooks.PreCompact = [.hooks.PreCompact[] | select((.hooks // []) | all(.command != "~/.claude/hooks/pre-compact.sh"))] |
            .hooks.SessionStart //= [] |
            .hooks.SessionStart = [.hooks.SessionStart[] | select((.hooks // []) | all(.command != "~/.claude/hooks/session-start.sh"))] |
            if (.hooks.PreCompact | length) == 0 then del(.hooks.PreCompact) else . end |
            if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end |
            if (.hooks | keys | length) == 0 then del(.hooks) else . end
        else . end
        ' "${SETTINGS_FILE}" > "${tmp}" && mv "${tmp}" "${SETTINGS_FILE}"
        success "Hook entries removed from settings.json (jq)"
    elif command -v python3 &>/dev/null; then
        local tmp="${SETTINGS_FILE}.tmp.$$"
        python3 -c "
import json

with open('${SETTINGS_FILE}') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})

if 'PreCompact' in hooks:
    hooks['PreCompact'] = [
        entry for entry in hooks['PreCompact']
        if not any(h.get('command') == '~/.claude/hooks/pre-compact.sh' for h in entry.get('hooks', []))
    ]
    if not hooks['PreCompact']:
        del hooks['PreCompact']

if 'SessionStart' in hooks:
    hooks['SessionStart'] = [
        entry for entry in hooks['SessionStart']
        if not any(h.get('command') == '~/.claude/hooks/session-start.sh' for h in entry.get('hooks', []))
    ]
    if not hooks['SessionStart']:
        del hooks['SessionStart']

if not hooks:
    settings.pop('hooks', None)

with open('${tmp}', 'w') as f:
    json.dump(settings, f, indent=2)
" && mv "${tmp}" "${SETTINGS_FILE}"
        success "Hook entries removed from settings.json (python3)"
    else
        warn "Cannot modify settings.json without jq or python3"
        warn "Please manually remove rules-keeper hook entries"
    fi
}

# --- Step 3: Remove rules from CLAUDE.md ---

remove_claude_rules() {
    if [[ ! -f "${CLAUDE_MD}" ]]; then
        warn "No CLAUDE.md found"
        return
    fi

    if ! grep -q "${GUARD_MARKER_START}" "${CLAUDE_MD}" 2>/dev/null; then
        warn "No rules-keeper rules found in CLAUDE.md"
        return
    fi

    local tmp="${CLAUDE_MD}.tmp.$$"

    # Remove everything between markers (inclusive) and any trailing blank line
    if command -v python3 &>/dev/null; then
        python3 -c "
import re

with open('${CLAUDE_MD}') as f:
    content = f.read()

pattern = r'\n?${GUARD_MARKER_START}.*?${GUARD_MARKER_END}\n?'
content = re.sub(pattern, '\n', content, flags=re.DOTALL)
content = content.strip() + '\n'

with open('${tmp}', 'w') as f:
    f.write(content)
" && mv "${tmp}" "${CLAUDE_MD}"
    else
        # sed fallback
        sed "/${GUARD_MARKER_START}/,/${GUARD_MARKER_END}/d" "${CLAUDE_MD}" > "${tmp}" && mv "${tmp}" "${CLAUDE_MD}"
    fi

    success "Rules removed from CLAUDE.md"
}

# --- Step 4: Remove context-guard skill ---

remove_skill() {
    local skill_dir="${CLAUDE_DIR}/skills/context-guard"
    if [[ -d "${skill_dir}" ]]; then
        rm -rf "${skill_dir}"
        success "Skill context-guard removed"
    else
        warn "No context-guard skill found"
    fi
}

# --- Step 5: Remove CLI symlink ---

remove_cli() {
    if [[ -f "${BIN_DIR}/crk" ]]; then
        rm -f "${BIN_DIR}/crk"
        success "CLI removed from ${BIN_DIR}/crk"
    else
        warn "No crk CLI found at ${BIN_DIR}/crk"
    fi
}

# --- Step 5: Remove rules-keeper directory ---

remove_guard_dir() {
    if [[ ! -d "${GUARD_DIR}" ]]; then
        warn "No rules-keeper directory found"
        return
    fi

    local backup_count=0
    if [[ -d "${GUARD_DIR}/backups" ]]; then
        backup_count=$(find "${GUARD_DIR}/backups" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [[ "${backup_count}" -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}You have ${BOLD}${backup_count}${RESET}${YELLOW} backup(s) in ${GUARD_DIR}/backups/${RESET}"
        echo -n "Delete backups too? [y/N] "

        # Handle non-interactive (piped) mode
        if [[ -t 0 ]]; then
            read -r answer
        else
            answer="y"
            echo "y (non-interactive)"
        fi

        if [[ "${answer}" != "y" && "${answer}" != "Y" ]]; then
            local backup_dest="${HOME}/claude-rules-keeper-backups"
            mkdir -p "${backup_dest}"
            cp -r "${GUARD_DIR}/backups/"* "${backup_dest}/" 2>/dev/null || true
            echo -e "${GREEN}Backups saved to ${backup_dest}/${RESET}"
        fi
    fi

    rm -rf "${GUARD_DIR}"
    success "Compact guard directory removed"
}

# --- Main ---

main() {
    echo ""
    echo -e "${BOLD}claude-rules-keeper uninstaller${RESET}"
    echo ""

    remove_hooks
    remove_settings_hooks
    remove_claude_rules
    remove_skill
    remove_cli
    remove_guard_dir

    echo ""
    echo -e "${GREEN}${BOLD}Uninstall complete.${RESET}"
    echo -e "${DIM}Claude Code hooks have been cleaned up.${RESET}"
    echo ""
}

main "$@"
