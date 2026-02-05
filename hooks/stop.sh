#!/usr/bin/env bash
set -euo pipefail

# Stop hook: when context is getting full, force Claude to save a summary
# before it can stop responding. This guarantees current-task.md is fresh
# when compaction eventually happens.

readonly GUARD_DIR="${HOME}/.claude/compact-guard"
readonly TASK_FILE="${GUARD_DIR}/current-task.md"
# Threshold: force save when transcript > this size (bytes)
# ~500KB of JSONL ≈ 70-80% context usage on a 200k token window
readonly DEFAULT_TRANSCRIPT_THRESHOLD=500000

# Don't nag if task file was updated less than 5 minutes ago
readonly STALENESS_SECONDS=300

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

get_file_size() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        echo "0"
        return
    fi
    # Works on both macOS and Linux
    wc -c < "${file}" 2>/dev/null | tr -d ' '
}

is_task_file_stale() {
    if [[ ! -f "${TASK_FILE}" ]]; then
        # No file = definitely stale
        return 0
    fi

    # Check if content is just the template
    if grep -q "(not set)" "${TASK_FILE}" 2>/dev/null; then
        return 0
    fi

    # Check modification time
    local now
    now=$(date "+%s")

    local mtime
    if stat --version &>/dev/null 2>&1; then
        # GNU stat
        mtime=$(stat -c "%Y" "${TASK_FILE}" 2>/dev/null) || mtime=0
    else
        # macOS stat
        mtime=$(stat -f "%m" "${TASK_FILE}" 2>/dev/null) || mtime=0
    fi

    local age=$((now - mtime))
    [[ "${age}" -gt "${STALENESS_SECONDS}" ]]
}

# --- Main ---

main() {
    # Read stdin JSON from Claude Code
    local stdin_data=""
    if [[ ! -t 0 ]]; then
        stdin_data=$(cat)
    fi

    # Don't trigger if already in a stop-hook loop
    local stop_hook_active=""
    if [[ -n "${stdin_data}" ]]; then
        stop_hook_active=$(read_stdin_json_field "stop_hook_active" "${stdin_data}")
    fi

    if [[ "${stop_hook_active}" == "true" ]]; then
        exit 0
    fi

    # Get transcript path
    local transcript_path=""
    if [[ -n "${stdin_data}" ]]; then
        transcript_path=$(read_stdin_json_field "transcript_path" "${stdin_data}")
    fi

    if [[ -z "${transcript_path}" || ! -f "${transcript_path}" ]]; then
        exit 0
    fi

    # Check transcript size
    local size
    size=$(get_file_size "${transcript_path}")

    if [[ "${size}" -lt "${DEFAULT_TRANSCRIPT_THRESHOLD}" ]]; then
        # Context is small, no need to save
        exit 0
    fi

    # Context is getting big — check if task file is stale
    if ! is_task_file_stale; then
        # Task file was recently updated, we're good
        exit 0
    fi

    # Context is big AND task file is stale → force Claude to write summary
    cat <<'EOF'
{
  "decision": "block",
  "reason": "Context is getting large. Before stopping, write a concise summary to ~/.claude/compact-guard/current-task.md with this format:\n\n# Current Task\n\nObjective: [what the user wants - be specific]\nKey files: [files involved]\nDecisions made: [important architectural/design choices]\nRules to follow: [any coding standards or constraints discussed]\nLast action: [what was just completed]\nNext step: [what comes next]\n\n---\nUpdated: auto (pre-compaction save)\n\nKeep it under 15 lines. Focus on what matters to resume work after compaction."
}
EOF
}

main "$@"
