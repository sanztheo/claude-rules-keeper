#!/usr/bin/env bash
set -euo pipefail

# Pre-compact hook: saves context snapshot before Claude Code compaction
# Extracts context directly from the conversation transcript (guaranteed)
# + saves current-task.md if it exists

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

atomic_write() {
    local target="$1"
    local content="$2"
    local tmp="${target}.tmp.$$"

    printf '%s\n' "${content}" > "${tmp}"
    mv "${tmp}" "${target}"
}

# Extract context from the transcript JSONL file
# This is the guaranteed approach — no reliance on Claude writing to a file
extract_transcript_context() {
    local transcript_path="$1"

    if [[ ! -f "${transcript_path}" || "${transcript_path}" == "unknown" ]]; then
        echo "(transcript not available)"
        return
    fi

    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys

transcript_path = '${transcript_path}'
user_messages = []
files_touched = set()
tool_actions = []

try:
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg_type = entry.get('type', '')

            # Collect user messages
            if msg_type == 'human':
                content = entry.get('message', {}).get('content', '')
                if isinstance(content, str) and content.strip():
                    user_messages.append(content.strip()[:200])
                elif isinstance(content, list):
                    for part in content:
                        if isinstance(part, dict) and part.get('type') == 'text':
                            text = part.get('text', '').strip()
                            if text:
                                user_messages.append(text[:200])

            # Collect files from tool uses
            if msg_type == 'assistant':
                content = entry.get('message', {}).get('content', [])
                if isinstance(content, list):
                    for part in content:
                        if not isinstance(part, dict):
                            continue
                        if part.get('type') == 'tool_use':
                            tool_input = part.get('input', {})
                            tool_name = part.get('name', '')

                            # Track files
                            fp = tool_input.get('file_path', '')
                            if fp:
                                files_touched.add(fp)

                            # Track recent actions
                            if tool_name in ('Edit', 'Write', 'Bash'):
                                desc = tool_input.get('description', '')
                                cmd = tool_input.get('command', '')
                                action = desc or cmd or tool_name
                                tool_actions.append(f'{tool_name}: {action[:100]}')

except Exception:
    pass

# Build output
output_parts = []

# Last 3 user messages (most recent context)
if user_messages:
    recent = user_messages[-3:]
    output_parts.append('### Recent User Messages')
    for i, msg in enumerate(recent, 1):
        output_parts.append(f'{i}. {msg}')

# Files touched
if files_touched:
    output_parts.append('')
    output_parts.append('### Files Touched')
    for fp in sorted(files_touched)[-15:]:
        output_parts.append(f'- {fp}')

# Last 5 actions
if tool_actions:
    output_parts.append('')
    output_parts.append('### Recent Actions')
    for action in tool_actions[-5:]:
        output_parts.append(f'- {action}')

if output_parts:
    print('\n'.join(output_parts))
else:
    print('(no context extracted)')
" 2>/dev/null || echo "(python3 extraction failed)"
    elif command -v jq &>/dev/null; then
        # Simpler jq fallback: just grab last few user messages
        local messages
        messages=$(tail -50 "${transcript_path}" 2>/dev/null \
            | jq -r 'select(.type == "human") | .message.content' 2>/dev/null \
            | tail -3) || messages=""
        if [[ -n "${messages}" ]]; then
            echo "### Recent User Messages"
            echo "${messages}" | head -c 600
        else
            echo "(jq extraction: no messages found)"
        fi
    else
        echo "(no python3 or jq available for transcript extraction)"
    fi
}

# Generate a concise current-task.md from transcript
# Kept small (~10 lines) so it doesn't bloat context after compaction
auto_update_task_file() {
    local transcript_path="$1"

    if [[ ! -f "${transcript_path}" || "${transcript_path}" == "unknown" ]]; then
        return
    fi

    if ! command -v python3 &>/dev/null; then
        return
    fi

    local concise_task
    concise_task=$(python3 -c "
import json

transcript_path = '${transcript_path}'
user_messages = []
files_touched = set()
last_actions = []

try:
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg_type = entry.get('type', '')

            if msg_type == 'human':
                content = entry.get('message', {}).get('content', '')
                if isinstance(content, str) and content.strip():
                    user_messages.append(content.strip()[:150])
                elif isinstance(content, list):
                    for part in content:
                        if isinstance(part, dict) and part.get('type') == 'text':
                            text = part.get('text', '').strip()
                            if text:
                                user_messages.append(text[:150])

            if msg_type == 'assistant':
                content = entry.get('message', {}).get('content', [])
                if isinstance(content, list):
                    for part in content:
                        if not isinstance(part, dict):
                            continue
                        if part.get('type') == 'tool_use':
                            inp = part.get('input', {})
                            fp = inp.get('file_path', '')
                            if fp:
                                files_touched.add(fp)
                            name = part.get('name', '')
                            desc = inp.get('description', inp.get('command', ''))
                            if name and desc:
                                last_actions.append(f'{name}: {str(desc)[:80]}')
except Exception:
    pass

# Build concise task file
objective = user_messages[-1] if user_messages else '(unknown)'
files_list = ', '.join(sorted(files_touched)[-5:]) if files_touched else '(none)'
last_action = last_actions[-1] if last_actions else '(none)'

# Truncate objective
if len(objective) > 150:
    objective = objective[:147] + '...'

print(f'''# Current Task

Objective: {objective}
Key files: {files_list}
Last action: {last_action}
Next step: (continue from last action)

---
Updated: auto (pre-compaction)''')
" 2>/dev/null) || return

    if [[ -n "${concise_task}" ]]; then
        atomic_write "${TASK_FILE}" "${concise_task}"
    fi
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
    local transcript_path="unknown"

    if [[ -n "${stdin_data}" ]]; then
        session_id=$(read_stdin_json_field "session_id" "${stdin_data}")
        compact_type=$(read_stdin_json_field "trigger" "${stdin_data}")
        transcript_path=$(read_stdin_json_field "transcript_path" "${stdin_data}")
    fi

    # Read current task (if Claude wrote one)
    local task_content="(not set by Claude)"
    if [[ -f "${TASK_FILE}" ]]; then
        task_content=$(cat "${TASK_FILE}")
    fi

    # Extract context from transcript (guaranteed, doesn't depend on Claude)
    local transcript_context="(not available)"
    if [[ "${transcript_path}" != "unknown" ]]; then
        transcript_context=$(extract_transcript_context "${transcript_path}")
    fi

    # Auto-update current-task.md with concise extracted context
    # This is what Claude reads after compaction — must stay small
    auto_update_task_file "${transcript_path}"

    # Create timestamped backup with full details (for human reference only)
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

## Extracted Context
${transcript_context}
EOF
)

    atomic_write "${backup_file}" "${backup_content}"

    # Rotate old backups
    rotate_backups

    # Update state
    update_state "${compact_type}"
}

main "$@"
