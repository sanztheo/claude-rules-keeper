#!/usr/bin/env bash
set -euo pipefail

# Session-start hook: injects saved context directly into Claude after compaction
# Uses SessionStart's additionalContext — guaranteed injection, no marker files needed

readonly GUARD_DIR="${HOME}/.claude/rules-keeper"
readonly BACKUPS_DIR="${GUARD_DIR}/backups"
readonly TASK_FILE="${GUARD_DIR}/current-task.md"
readonly RULES_FILE="${GUARD_DIR}/rules.md"
readonly SESSION_RULES_FILE="${GUARD_DIR}/session-rules.md"
readonly PROJECTS_DIR="${GUARD_DIR}/projects"

# --- Helpers ---

read_stdin_json_field() {
    local field="$1"
    local input="$2"

    if command -v jq &>/dev/null; then
        echo "${input}" | jq -r ".${field} // \"\"" 2>/dev/null || echo ""
    elif command -v python3 &>/dev/null; then
        echo "${input}" | CRK_FIELD="${field}" python3 -c "import sys,json,os; print(json.load(sys.stdin).get(os.environ['CRK_FIELD'],''))" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

get_latest_backup() {
    if [[ ! -d "${BACKUPS_DIR}" ]]; then
        return
    fi
    find "${BACKUPS_DIR}" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort -r | head -n 1
}

detect_project_name() {
    # Try git first, but guard against $HOME (monorepo / no local .git)
    local git_root=""
    git_root=$(git rev-parse --show-toplevel 2>/dev/null) || true
    if [[ -n "${git_root}" && "${git_root}" != "${HOME}" ]]; then
        basename "${git_root}"
    else
        basename "$(pwd)"
    fi
}

# --- Context Builder ---

# Appends a section to the context string, adding the recovery header if first section
append_context() {
    local header="$1"
    local body="$2"

    if [[ -z "${context}" ]]; then
        context="[COMPACTION RECOVERY] The conversation was just compacted."
    fi
    context="${context}

${header}
${body}"
}

# Outputs the final context as JSON (or plain text fallback)
output_context_json() {
    if command -v jq &>/dev/null; then
        jq -n --arg ctx "${context}" '{
            hookSpecificOutput: {
                hookEventName: "SessionStart",
                additionalContext: $ctx
            }
        }'
    elif command -v python3 &>/dev/null; then
        echo "${context}" | python3 -c "
import sys, json
ctx = sys.stdin.read()
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': ctx
    }
}))
"
    else
        echo "${context}"
    fi
}

# --- Main ---

main() {
    local stdin_data=""
    if [[ ! -t 0 ]]; then
        stdin_data=$(cat)
    fi

    local source=""
    if [[ -n "${stdin_data}" ]]; then
        source=$(read_stdin_json_field "source" "${stdin_data}")
    fi

    # New conversation (not compaction) → clear session rules
    if [[ "${source}" != "compact" ]]; then
        if [[ -f "${SESSION_RULES_FILE}" ]]; then
            rm -f "${SESSION_RULES_FILE}"
        fi
        exit 0
    fi

    # Build context to inject
    local context=""

    # Global persistent rules
    if [[ -f "${RULES_FILE}" ]]; then
        local rules_content
        rules_content=$(cat "${RULES_FILE}")
        if echo "${rules_content}" | grep -q "^- " 2>/dev/null; then
            append_context "## Your Persistent Rules (MUST follow)" "${rules_content}"
        fi
    fi

    # Project-specific rules
    local project_name
    project_name=$(detect_project_name)
    local project_rules_file="${PROJECTS_DIR}/${project_name}/rules.md"
    if [[ -n "${project_name}" && -f "${project_rules_file}" ]]; then
        local project_rules
        project_rules=$(cat "${project_rules_file}")
        if echo "${project_rules}" | grep -q "^- " 2>/dev/null; then
            append_context "## Project Rules: ${project_name} (MUST follow)" "${project_rules}"
        fi
    fi

    # Session rules (survive compaction, cleared on new conversation)
    if [[ -f "${SESSION_RULES_FILE}" ]]; then
        local session_rules
        session_rules=$(cat "${SESSION_RULES_FILE}")
        if echo "${session_rules}" | grep -q "^- " 2>/dev/null; then
            append_context "## Session Rules" "${session_rules}"
        fi
    fi

    # Task context (written by pre-compact hook from transcript)
    if [[ -f "${TASK_FILE}" ]]; then
        local task_content
        task_content=$(cat "${TASK_FILE}")
        if [[ -n "${task_content}" && "${task_content}" != *"(not set)"* ]]; then
            append_context "## Task Context Before Compaction" "${task_content}"
        fi
    fi

    # Fallback: latest backup if nothing else was found
    if [[ -z "${context}" ]]; then
        local latest_backup
        latest_backup=$(get_latest_backup)
        if [[ -n "${latest_backup}" ]]; then
            local backup_content
            backup_content=$(cat "${latest_backup}")
            context="[COMPACTION RECOVERY] The conversation was just compacted. Here is the saved backup:

${backup_content}"
        fi
    fi

    # Output JSON with additionalContext
    if [[ -n "${context}" ]]; then
        output_context_json
    fi
}

main "$@"
