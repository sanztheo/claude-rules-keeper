#!/usr/bin/env bats
# Tests for crk CLI commands

load test_helper.sh

setup() {
    setup_sandbox
    # Run install to get a working environment
    run_install
}

teardown() {
    teardown_sandbox
}

# --- help ---

@test "crk help exits 0 and contains Usage" {
    run run_crk help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "crk --help exits 0" {
    run run_crk --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

# --- version ---

@test "crk version prints v1.3.0" {
    run run_crk version
    [ "$status" -eq 0 ]
    [[ "$output" == *"v1.3.0"* ]]
}

# --- status ---

@test "crk status works without state.json" {
    rm -f "${GUARD_DIR}/state.json"
    run run_crk status
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-rules-keeper"* ]]
}

@test "crk status shows compaction info" {
    run run_crk status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Last compaction"* ]]
    [[ "$output" == *"Total compactions"* ]]
    [[ "$output" == *"Backups stored"* ]]
}

# --- task ---

@test "crk task without file shows info message" {
    rm -f "${GUARD_DIR}/current-task.md"
    run run_crk task
    [ "$status" -eq 0 ]
    [[ "$output" == *"No task file"* ]]
}

@test "crk task set via stdin" {
    run bash -c 'echo "Objective: test task" | HOME="'"${TEST_HOME}"'" bash "'"${REPO_ROOT}"'/bin/crk" task set'
    [ "$status" -eq 0 ]
    [[ -f "${GUARD_DIR}/current-task.md" ]]
    run cat "${GUARD_DIR}/current-task.md"
    [[ "$output" == *"test task"* ]]
}

@test "crk task clear resets to template" {
    echo "some task content" > "${GUARD_DIR}/current-task.md"
    run run_crk task clear
    [ "$status" -eq 0 ]
    run cat "${GUARD_DIR}/current-task.md"
    [[ "$output" == *"(not set)"* ]]
}

# --- config ---

@test "crk config shows JSON" {
    run run_crk config
    [ "$status" -eq 0 ]
    [[ "$output" == *"max_backups"* ]]
}

@test "crk config set updates value" {
    run run_crk config set max_backups 20
    [ "$status" -eq 0 ]
    run run_crk config
    [[ "$output" == *"20"* ]]
}

# --- rules ---

@test "crk rules shows 3 scopes" {
    run run_crk rules
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session"* ]]
    [[ "$output" == *"Global"* ]]
    [[ "$output" == *"Project"* ]]
}

# --- presets ---

@test "crk presets without presets shows info" {
    run run_crk presets
    [ "$status" -eq 0 ]
    [[ "$output" == *"No presets"* ]]
}

# --- backups ---

@test "crk backups with no backups shows message" {
    rm -rf "${GUARD_DIR}/backups/"*.md 2>/dev/null || true
    run run_crk backups
    [ "$status" -eq 0 ]
    [[ "$output" == *"No backups"* ]]
}

# --- doctor ---

@test "crk doctor runs all checks" {
    run run_crk doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"crk doctor"* ]]
    [[ "$output" == *"Rules-keeper directory"* ]]
    [[ "$output" == *"config.json valid"* ]]
    [[ "$output" == *"state.json valid"* ]]
    [[ "$output" == *"/13 checks passed"* ]]
}

@test "crk doctor passes most checks after install" {
    run run_crk doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK]"* ]]
    # Should have at least 10 passing checks (crk in PATH may vary)
    local ok_count
    ok_count=$(echo "$output" | grep -c '\[OK\]') || true
    [ "$ok_count" -ge 10 ]
}

# --- unknown command ---

@test "unknown command returns 1" {
    run run_crk nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown command"* ]]
}

# --- upgrade ---

@test "crk upgrade is listed in help" {
    run run_crk help
    [ "$status" -eq 0 ]
    [[ "$output" == *"upgrade"* ]]
}

@test "crk upgrade shows checking message" {
    # Mock curl to return current version (already up to date)
    mock_curl() { echo 'readonly VERSION="1.3.0"'; }
    export -f mock_curl
    # Replace curl in PATH with mock
    mkdir -p "${TEST_HOME}/mock-bin"
    printf '#!/usr/bin/env bash\nmock_curl "$@"\n' > "${TEST_HOME}/mock-bin/curl"
    chmod +x "${TEST_HOME}/mock-bin/curl"

    run bash -c 'export PATH="'"${TEST_HOME}"'/mock-bin:${PATH}"; HOME="'"${TEST_HOME}"'" bash "'"${REPO_ROOT}"'/bin/crk" upgrade'
    [[ "$output" == *"Checking for updates"* ]]
    [[ "$output" == *"Already up to date"* ]]
}

@test "crk upgrade handles curl failure gracefully" {
    # Mock curl that always fails
    mkdir -p "${TEST_HOME}/mock-bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "${TEST_HOME}/mock-bin/curl"
    chmod +x "${TEST_HOME}/mock-bin/curl"

    run bash -c 'export PATH="'"${TEST_HOME}"'/mock-bin:${PATH}"; HOME="'"${TEST_HOME}"'" bash "'"${REPO_ROOT}"'/bin/crk" upgrade'
    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not fetch"* ]]
}
