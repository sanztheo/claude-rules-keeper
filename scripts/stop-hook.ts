#!/usr/bin/env bun

/**
 * Stop hook: forces Claude to save context when the conversation is getting long.
 *
 * Reads the transcript JSONL, estimates token usage, and if we're approaching
 * the compaction threshold, blocks Claude from stopping until it writes
 * a summary to current-task.md.
 */

import { readFileSync, statSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const GUARD_DIR = join(homedir(), ".claude", "compact-guard");
const TASK_FILE = join(GUARD_DIR, "current-task.md");

// Estimated bytes-per-token ratio for JSONL transcripts
// JSONL has JSON overhead, so ~6 bytes per actual token is reasonable
const BYTES_PER_TOKEN = 6;

// Max context window (tokens) — Claude Code uses ~200k
const MAX_CONTEXT_TOKENS = 200_000;

// Trigger save at this % of estimated context usage
const SAVE_THRESHOLD_PERCENT = 70;

// Don't nag if task file was updated less than 5 minutes ago
const STALENESS_MS = 5 * 60 * 1000;

interface StopHookInput {
  session_id: string;
  transcript_path: string;
  stop_hook_active: boolean;
  hook_event_name: string;
}

function readStdin(): string {
  try {
    return readFileSync("/dev/stdin", "utf-8");
  } catch {
    return "";
  }
}

function estimateTokensFromTranscript(transcriptPath: string): number {
  try {
    const size = statSync(transcriptPath).size;
    return Math.round(size / BYTES_PER_TOKEN);
  } catch {
    return 0;
  }
}

function isTaskFileStale(): boolean {
  if (!existsSync(TASK_FILE)) {
    return true;
  }

  try {
    const content = readFileSync(TASK_FILE, "utf-8");
    if (content.includes("(not set)") || content.includes("(never)")) {
      return true;
    }

    const mtime = statSync(TASK_FILE).mtimeMs;
    const age = Date.now() - mtime;
    return age > STALENESS_MS;
  } catch {
    return true;
  }
}

function main(): void {
  const raw = readStdin();
  if (!raw.trim()) {
    process.exit(0);
  }

  let input: StopHookInput;
  try {
    input = JSON.parse(raw);
  } catch {
    process.exit(0);
  }

  // Don't trigger if already in a stop-hook loop
  if (input.stop_hook_active) {
    process.exit(0);
  }

  const transcriptPath = input.transcript_path;
  if (!transcriptPath || !existsSync(transcriptPath)) {
    process.exit(0);
  }

  // Estimate context usage
  const estimatedTokens = estimateTokensFromTranscript(transcriptPath);
  const usagePercent = (estimatedTokens / MAX_CONTEXT_TOKENS) * 100;

  if (usagePercent < SAVE_THRESHOLD_PERCENT) {
    process.exit(0);
  }

  // Context is getting big — check if task file is fresh
  if (!isTaskFileStale()) {
    process.exit(0);
  }

  // Force Claude to save context
  const response = {
    decision: "block",
    reason: [
      "Context is ~" +
        Math.round(usagePercent) +
        "% full. Compaction is approaching.",
      "Before stopping, write a concise summary to ~/.claude/compact-guard/current-task.md:",
      "",
      "# Current Task",
      "",
      "Objective: [what the user wants - be specific]",
      "Key files: [files being worked on]",
      "Decisions made: [important choices made during this session]",
      "Rules to follow: [coding standards or constraints the user specified]",
      "Last action: [what was just completed]",
      "Next step: [what should happen next]",
      "",
      "---",
      "Updated: auto (pre-compaction save)",
      "",
      "Keep it under 15 lines. Focus on what's needed to resume after compaction.",
    ].join("\n"),
  };

  console.log(JSON.stringify(response));
}

main();
