#!/usr/bin/env bash
set -euo pipefail

# Pre-compact hook: saves context snapshot before Claude Code compaction
# Triggered automatically by Claude Code before every compaction event

readonly GUARD_DIR="${HOME}/.claude/compact-guard"
readonly BACKUPS_DIR="${GUARD_DIR}/backups"
readonly TASK_FILE="${GUARD_DIR}/current-task.md"
readonly STATE_FILE="${GUARD_DIR}/state.json"
readonly CONFIG_FILE="${GUARD_DIR}/config.json"
readonly DEFAULT_MAX_BACKUPS=10

# --- Helpers ---

get_timestamp() {
    date "+%Y-%m-%d_%H-%M-%S"
}

get_iso_timestamp() {
    date "+%Y-%m-%dT%H:%M:%S"
}

read_max_backups() {
    local max_backups="${DEFAULT_MAX_BACKUPS}"

    if [[ -f "${CONFIG_FILE}" ]]; then
        # Try jq first, then python3, then grep fallback
        if command -v jq &>/dev/null; then
            max_backups=$(jq -r '.max_backups // 10' "${CONFIG_FILE}" 2>/dev/null) || max_backups="${DEFAULT_MAX_BACKUPS}"
        elif command -v python3 &>/dev/null; then
            max_backups=$(python3 -c "import json; print(json.load(open('${CONFIG_FILE}')).get('max_backups', 10))" 2>/dev/null) || max_backups="${DEFAULT_MAX_BACKUPS}"
        else
            max_backups=$(grep -o '"max_backups"[[:space:]]*:[[:space:]]*[0-9]*' "${CONFIG_FILE}" 2>/dev/null | grep -o '[0-9]*$') || max_backups="${DEFAULT_MAX_BACKUPS}"
        fi
    fi

    echo "${max_backups}"
}

read_stdin_json_field() {
    local field="$1"
    local input="$2"

    if command -v jq &>/dev/null; then
        echo "${input}" | jq -r ".${field} // \"unknown\"" 2>/dev/null || echo "unknown"
    elif command -v python3 &>/dev/null; then
        echo "${input}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('${field}','unknown'))" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Atomic write: write to temp file then move
atomic_write() {
    local target="$1"
    local content="$2"
    local tmp="${target}.tmp.$$"

    echo "${content}" > "${tmp}"
    mv "${tmp}" "${target}"
}

update_state() {
    local compact_type="$1"
    local iso_ts
    iso_ts=$(get_iso_timestamp)

    local total_compactions=0
    local install_date="${iso_ts}"
    local version="1.0.0"

    if [[ -f "${STATE_FILE}" ]]; then
        if command -v jq &>/dev/null; then
            total_compactions=$(jq -r '.total_compactions // 0' "${STATE_FILE}" 2>/dev/null) || total_compactions=0
            install_date=$(jq -r '.install_date // ""' "${STATE_FILE}" 2>/dev/null) || install_date="${iso_ts}"
            version=$(jq -r '.version // "1.0.0"' "${STATE_FILE}" 2>/dev/null) || version="1.0.0"
        elif command -v python3 &>/dev/null; then
            total_compactions=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('total_compactions',0))" 2>/dev/null) || total_compactions=0
            install_date=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('install_date',''))" 2>/dev/null) || install_date="${iso_ts}"
            version=$(python3 -c "import json; d=json.load(open('${STATE_FILE}')); print(d.get('version','1.0.0'))" 2>/dev/null) || version="1.0.0"
        fi
    fi

    total_compactions=$((total_compactions + 1))
    [[ -z "${install_date}" ]] && install_date="${iso_ts}"

    local state_json
    state_json=$(cat <<EOF
{
  "last_compaction": "${iso_ts}",
  "last_compaction_type": "${compact_type}",
  "total_compactions": ${total_compactions},
  "install_date": "${install_date}",
  "version": "${version}"
}
EOF
)

    atomic_write "${STATE_FILE}" "${state_json}"
}

rotate_backups() {
    local max_backups
    max_backups=$(read_max_backups)

    local backup_count
    backup_count=$(find "${BACKUPS_DIR}" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ "${backup_count}" -gt "${max_backups}" ]]; then
        local to_delete=$((backup_count - max_backups))
        # Delete oldest files first (sorted by name = chronological)
        find "${BACKUPS_DIR}" -maxdepth 1 -name "*.md" -type f 2>/dev/null \
            | sort \
            | head -n "${to_delete}" \
            | while IFS= read -r file; do
                rm -f "${file}"
            done
    fi
}

# --- Main ---

main() {
    mkdir -p "${BACKUPS_DIR}"

    # Read stdin JSON from Claude Code
    local stdin_data=""
    if [[ ! -t 0 ]]; then
        stdin_data=$(cat)
    fi

    local session_id="unknown"
    local compact_type="auto"

    if [[ -n "${stdin_data}" ]]; then
        session_id=$(read_stdin_json_field "session_id" "${stdin_data}")
        compact_type=$(read_stdin_json_field "compact_type" "${stdin_data}")
    fi

    # Read current task
    local task_content="(no task set)"
    if [[ -f "${TASK_FILE}" ]]; then
        task_content=$(cat "${TASK_FILE}")
    fi

    # Create timestamped backup
    local timestamp
    timestamp=$(get_timestamp)
    local backup_file="${BACKUPS_DIR}/${timestamp}.md"

    local backup_content
    backup_content=$(cat <<EOF
# Compact Guard Backup
- Date: $(get_iso_timestamp)
- Type: ${compact_type}
- Session: ${session_id}

## Current Task
${task_content}
EOF
)

    atomic_write "${backup_file}" "${backup_content}"

    # Rotate old backups
    rotate_backups

    # Update state
    update_state "${compact_type}"
}

main "$@"
