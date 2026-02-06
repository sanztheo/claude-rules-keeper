#!/usr/bin/env bash
set -euo pipefail

# Session-start hook: injects saved context directly into Claude after compaction
# Uses SessionStart's additionalContext — guaranteed injection, no marker files needed

readonly GUARD_DIR="${HOME}/.claude/rules-keeper"
readonly BACKUPS_DIR="${GUARD_DIR}/backups"
readonly TASK_FILE="${GUARD_DIR}/current-task.md"

# --- Helpers ---

read_stdin_json_field() {
    local field="$1"
    local input="$2"

    if command -v jq &>/dev/null; then
        echo "${input}" | jq -r ".${field} // \"\"" 2>/dev/null || echo ""
    elif command -v python3 &>/dev/null; then
        echo "${input}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('${field}',''))" 2>/dev/null || echo ""
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

# --- Main ---

main() {
    # Read stdin JSON from Claude Code
    local stdin_data=""
    if [[ ! -t 0 ]]; then
        stdin_data=$(cat)
    fi

    local source=""
    if [[ -n "${stdin_data}" ]]; then
        source=$(read_stdin_json_field "source" "${stdin_data}")
    fi

    # Only inject context after compaction
    if [[ "${source}" != "compact" ]]; then
        exit 0
    fi

    # Build context to inject
    local context=""

    # Read current-task.md (written by pre-compact hook from transcript)
    if [[ -f "${TASK_FILE}" ]]; then
        local task_content
        task_content=$(cat "${TASK_FILE}")
        if [[ -n "${task_content}" && "${task_content}" != *"(not set)"* ]]; then
            context="[COMPACTION RECOVERY] The conversation was just compacted. Here is the context from before compaction:

${task_content}"
        fi
    fi

    # If no task file, try the latest backup
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

    # If we have context, output JSON with additionalContext
    if [[ -n "${context}" ]]; then
        if command -v jq &>/dev/null; then
            jq -n --arg ctx "${context}" '{
                hookSpecificOutput: {
                    hookEventName: "SessionStart",
                    additionalContext: $ctx
                }
            }'
        elif command -v python3 &>/dev/null; then
            python3 -c "
import json
ctx = '''${context}'''
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': ctx
    }
}))
"
        else
            # Plain text fallback — stdout is also added as context for SessionStart
            echo "${context}"
        fi
    fi
}

main "$@"
