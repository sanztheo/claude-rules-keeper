<!-- CLAUDE-COMPACT-GUARD:START -->
## Context Compaction Guard (MANDATORY)

You have **claude-compact-guard** installed. Context compaction can happen at ANY time and erases your memory. You MUST maintain `~/.claude/compact-guard/current-task.md` to survive it.

**Rules:**
1. **At task start:** Write objective, key files, and approach to `~/.claude/compact-guard/current-task.md`
2. **After major decisions:** Update the file with choices made and rationale
3. **After completing steps:** Update last action and next step
4. **After compaction (`[COMPACTION RECOVERY]`):** Read recovered context, confirm with user, update file

**Format** (keep under 15 lines):
```
Objective: [specific goal]
Key files: [files involved]
Decisions made: [important choices]
Rules to follow: [user constraints/standards]
Last action: [what was just done]
Next step: [what comes next]
```

This is NON-NEGOTIABLE. If you skip this, work will be lost on compaction.
<!-- CLAUDE-COMPACT-GUARD:END -->
