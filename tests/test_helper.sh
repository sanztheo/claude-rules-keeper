#!/usr/bin/env bash
# Shared test helpers for bats tests
# Provides sandboxed HOME to avoid touching real user files

export TEST_HOME="/tmp/crk-test-$$"
export HOME="${TEST_HOME}"
export GUARD_DIR="${HOME}/.claude/rules-keeper"
export HOOKS_DIR="${HOME}/.claude/hooks"
export SETTINGS_FILE="${HOME}/.claude/settings.json"
export CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
export BIN_DIR="${HOME}/.local/bin"

# Resolve the project root (parent of tests/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

setup_sandbox() {
    rm -rf "${TEST_HOME}"
    mkdir -p "${TEST_HOME}/.claude" "${TEST_HOME}/.local/bin"
    # Add bin to PATH so crk is findable
    export PATH="${BIN_DIR}:${REPO_ROOT}/bin:${PATH}"
}

teardown_sandbox() {
    rm -rf "${TEST_HOME}"
}

# Run install.sh in sandbox
run_install() {
    HOME="${TEST_HOME}" bash "${REPO_ROOT}/install.sh"
}

# Run crk from repo bin (not installed)
run_crk() {
    HOME="${TEST_HOME}" bash "${REPO_ROOT}/bin/crk" "$@"
}
