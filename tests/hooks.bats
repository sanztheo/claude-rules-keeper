#!/usr/bin/env bats
# Tests for hook scripts (pre-compact.sh, session-start.sh)

load test_helper.sh

setup() {
    setup_sandbox
    run_install
}

teardown() {
    teardown_sandbox
}

# --- pre-compact.sh ---

@test "pre-compact creates a backup file" {
    echo '{"session_id":"test-123","trigger":"auto","transcript_path":"unknown"}' \
        | HOME="${TEST_HOME}" bash "${REPO_ROOT}/hooks/pre-compact.sh"
    local backup_count
    backup_count=$(find "${GUARD_DIR}/backups" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$backup_count" -ge 1 ]
}

@test "pre-compact increments total_compactions" {
    # Initial state
    local before
    if command -v jq &>/dev/null; then
        before=$(jq -r '.total_compactions' "${GUARD_DIR}/state.json")
    else
        before=0
    fi

    echo '{"session_id":"test","trigger":"auto","transcript_path":"unknown"}' \
        | HOME="${TEST_HOME}" bash "${REPO_ROOT}/hooks/pre-compact.sh"

    if command -v jq &>/dev/null; then
        local after
        after=$(jq -r '.total_compactions' "${GUARD_DIR}/state.json")
        [ "$after" -gt "$before" ]
    fi
}

@test "pre-compact respects max_backups rotation" {
    # Set max_backups to 3
    if command -v jq &>/dev/null; then
        local tmp="${GUARD_DIR}/config.json.tmp"
        jq '.max_backups = 3' "${GUARD_DIR}/config.json" > "${tmp}" && mv "${tmp}" "${GUARD_DIR}/config.json"
    fi

    # Create 5 backups
    for i in 1 2 3 4 5; do
        echo '{"session_id":"test-'"$i"'","trigger":"auto","transcript_path":"unknown"}' \
            | HOME="${TEST_HOME}" bash "${REPO_ROOT}/hooks/pre-compact.sh"
        sleep 1
    done

    local backup_count
    backup_count=$(find "${GUARD_DIR}/backups" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$backup_count" -le 3 ]
}

@test "pre-compact updates last_compaction timestamp" {
    echo '{"session_id":"test","trigger":"manual","transcript_path":"unknown"}' \
        | HOME="${TEST_HOME}" bash "${REPO_ROOT}/hooks/pre-compact.sh"

    if command -v jq &>/dev/null; then
        local last
        last=$(jq -r '.last_compaction' "${GUARD_DIR}/state.json")
        [ "$last" != "null" ]
        [ -n "$last" ]
    fi
}

# --- session-start.sh ---

@test "session-start with source=compact outputs JSON context" {
    # Create a task file for context injection
    echo "Objective: test objective" > "${GUARD_DIR}/current-task.md"

    local output
    output=$(echo '{"source":"compact"}' | HOME="${TEST_HOME}" bash "${REPO_ROOT}/hooks/session-start.sh")

    [[ "$output" == *"COMPACTION RECOVERY"* ]] || [[ "$output" == *"hookSpecificOutput"* ]]
}

@test "session-start without source clears session-rules" {
    # Create session rules
    echo "- some rule" > "${GUARD_DIR}/session-rules.md"

    echo '{"source":""}' | HOME="${TEST_HOME}" bash "${REPO_ROOT}/hooks/session-start.sh" || true

    [ ! -f "${GUARD_DIR}/session-rules.md" ]
}

@test "session-start new session clears session-rules" {
    echo "- temp rule" > "${GUARD_DIR}/session-rules.md"

    echo '{}' | HOME="${TEST_HOME}" bash "${REPO_ROOT}/hooks/session-start.sh" || true

    [ ! -f "${GUARD_DIR}/session-rules.md" ]
}

@test "session-start with rules includes them in output" {
    # Set global rules
    printf '# Rules\n\n- Always use French\n- Never skip tests\n' > "${GUARD_DIR}/rules.md"

    # Create task
    echo "Objective: some task" > "${GUARD_DIR}/current-task.md"

    local output
    output=$(echo '{"source":"compact"}' | HOME="${TEST_HOME}" bash "${REPO_ROOT}/hooks/session-start.sh")

    [[ "$output" == *"French"* ]] || [[ "$output" == *"Persistent Rules"* ]]
}
