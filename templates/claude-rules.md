<!-- CLAUDE-COMPACT-GUARD:START -->
## Context Compaction Awareness

You have claude-compact-guard installed. Follow these rules:

1. **At task start:** Write the current objective to `~/.claude/compact-guard/current-task.md`:
   ```
   Objective: [what the user wants]
   Key files: [files involved]
   Decisions made: [important choices]
   Last action: [what was just done]
   Next step: [what comes next]
   ```

2. **When context feels unclear or after compaction:** Read `~/.claude/compact-guard/current-task.md` and ask the user to confirm the objective is still correct.

3. **Before major actions:** Update `current-task.md` with latest decisions and progress.

4. **If `~/.claude/compact-guard/.just-compacted` exists:** Read `current-task.md`, summarize what you remember to the user, ask for confirmation, then delete the `.just-compacted` marker file.
<!-- CLAUDE-COMPACT-GUARD:END -->
