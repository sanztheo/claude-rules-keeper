#!/usr/bin/env bash
set -euo pipefail

# Session-start hook: injects saved context directly into Claude after compaction
# Uses SessionStart's additionalContext — guaranteed injection, no marker files needed

readonly GUARD_DIR="${HOME}/.claude/rules-keeper"
readonly BACKUPS_DIR="${GUARD_DIR}/backups"
readonly TASK_FILE="${GUARD_DIR}/current-task.md"
readonly RULES_FILE="${GUARD_DIR}/rules.md"
readonly PROJECTS_DIR="${GUARD_DIR}/projects"

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

detect_project_name() {
    # Try git first, fallback to cwd basename
    local project_name=""
    project_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
    echo "${project_name}"
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

    # Read global persistent rules (most important — standing orders)
    local rules_content=""
    if [[ -f "${RULES_FILE}" ]]; then
        rules_content=$(cat "${RULES_FILE}")
        # Only include if there are actual rules (not just the header)
        if echo "${rules_content}" | grep -q "^- " 2>/dev/null; then
            context="[COMPACTION RECOVERY] The conversation was just compacted.

## Your Persistent Rules (MUST follow)
${rules_content}"
        fi
    fi

    # Read project-specific rules
    local project_name
    project_name=$(detect_project_name)
    local project_rules_file="${PROJECTS_DIR}/${project_name}/rules.md"
    if [[ -n "${project_name}" && -f "${project_rules_file}" ]]; then
        local project_rules
        project_rules=$(cat "${project_rules_file}")
        if echo "${project_rules}" | grep -q "^- " 2>/dev/null; then
            if [[ -n "${context}" ]]; then
                context="${context}

## Project Rules: ${project_name} (MUST follow)
${project_rules}"
            else
                context="[COMPACTION RECOVERY] The conversation was just compacted.

## Project Rules: ${project_name} (MUST follow)
${project_rules}"
            fi
        fi
    fi

    # Read current-task.md (written by pre-compact hook from transcript)
    if [[ -f "${TASK_FILE}" ]]; then
        local task_content
        task_content=$(cat "${TASK_FILE}")
        if [[ -n "${task_content}" && "${task_content}" != *"(not set)"* ]]; then
            if [[ -n "${context}" ]]; then
                context="${context}

## Task Context Before Compaction
${task_content}"
            else
                context="[COMPACTION RECOVERY] The conversation was just compacted.

${task_content}"
            fi
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
