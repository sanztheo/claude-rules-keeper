#!/usr/bin/env bats
# Tests for install.sh and uninstall.sh

load test_helper.sh

setup() {
    setup_sandbox
}

teardown() {
    teardown_sandbox
}

# --- Fresh install ---

@test "install creates rules-keeper directory" {
    run_install
    [ -d "${GUARD_DIR}" ]
}

@test "install creates backups directory" {
    run_install
    [ -d "${GUARD_DIR}/backups" ]
}

@test "install copies hooks and makes them executable" {
    run_install
    [ -f "${HOOKS_DIR}/pre-compact.sh" ]
    [ -x "${HOOKS_DIR}/pre-compact.sh" ]
    [ -f "${HOOKS_DIR}/session-start.sh" ]
    [ -x "${HOOKS_DIR}/session-start.sh" ]
}

@test "install creates settings.json with hook entries" {
    run_install
    [ -f "${SETTINGS_FILE}" ]
    run grep "pre-compact.sh" "${SETTINGS_FILE}"
    [ "$status" -eq 0 ]
    run grep "session-start.sh" "${SETTINGS_FILE}"
    [ "$status" -eq 0 ]
}

@test "install merges into existing settings.json" {
    # Create existing settings with some custom content
    mkdir -p "$(dirname "${SETTINGS_FILE}")"
    echo '{"custom_key": "value"}' > "${SETTINGS_FILE}"
    run_install
    # Custom key preserved
    run grep "custom_key" "${SETTINGS_FILE}"
    [ "$status" -eq 0 ]
    # Hooks added
    run grep "pre-compact.sh" "${SETTINGS_FILE}"
    [ "$status" -eq 0 ]
}

@test "install adds CLAUDE.md guard markers" {
    run_install
    [ -f "${CLAUDE_MD}" ]
    run grep "CLAUDE-RULES-KEEPER:START" "${CLAUDE_MD}"
    [ "$status" -eq 0 ]
    run grep "CLAUDE-RULES-KEEPER:END" "${CLAUDE_MD}"
    [ "$status" -eq 0 ]
}

@test "install creates skill" {
    run_install
    [ -f "${HOME}/.claude/skills/rules-keeper/SKILL.md" ]
}

@test "install creates slash commands" {
    run_install
    [ -f "${HOME}/.claude/commands/rules.md" ]
    [ -f "${HOME}/.claude/commands/rules-global.md" ]
    [ -f "${HOME}/.claude/commands/rules-create.md" ]
    [ -f "${HOME}/.claude/commands/rules-doctor.md" ]
    [ -f "${HOME}/.claude/commands/rules-upgrade.md" ]
    [ -f "${HOME}/.claude/commands/rules-status.md" ]
}

@test "install creates config.json" {
    run_install
    [ -f "${GUARD_DIR}/config.json" ]
    # Validate JSON
    if command -v jq &>/dev/null; then
        run jq '.' "${GUARD_DIR}/config.json"
        [ "$status" -eq 0 ]
    fi
}

@test "install creates state.json" {
    run_install
    [ -f "${GUARD_DIR}/state.json" ]
    if command -v jq &>/dev/null; then
        run jq '.' "${GUARD_DIR}/state.json"
        [ "$status" -eq 0 ]
    fi
}

@test "install creates rules.md" {
    run_install
    [ -f "${GUARD_DIR}/rules.md" ]
}

# --- Idempotence ---

@test "install is idempotent (2x = same result)" {
    run_install

    # Capture state after first install
    local config_before state_before
    config_before=$(cat "${GUARD_DIR}/config.json")
    state_before=$(cat "${GUARD_DIR}/state.json")

    run_install

    # State preserved (not overwritten)
    local config_after state_after
    config_after=$(cat "${GUARD_DIR}/config.json")
    state_after=$(cat "${GUARD_DIR}/state.json")
    [ "$config_before" = "$config_after" ]
    [ "$state_before" = "$state_after" ]
}

@test "install does not duplicate CLAUDE.md markers" {
    run_install
    run_install
    local marker_count
    marker_count=$(grep -c "CLAUDE-RULES-KEEPER:START" "${CLAUDE_MD}") || true
    [ "$marker_count" -eq 1 ]
}
