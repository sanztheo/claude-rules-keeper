<!-- CLAUDE-RULES-KEEPER:START -->
## Claude Rules Keeper (MANDATORY)

You have **claude-rules-keeper** installed. Context compaction erases your memory. You MUST:

1. **Read rules at conversation start:**
   - Global: `~/.claude/rules-keeper/rules.md`
   - Project: `~/.claude/rules-keeper/projects/<project>/rules.md` (detect via `git rev-parse --show-toplevel` basename)
2. **Auto-detect rules:** When the user states a permanent preference/constraint, save it (global or project scope)
3. **Maintain `~/.claude/rules-keeper/current-task.md`** with current task state (objective, progress, next step)
4. **After compaction (`[COMPACTION RECOVERY]`):** Read all rules + recovered context, confirm with user

**Commands:** `/rules`, `/rules-create`, `/rules-project`, `/rules-save`, `/rules-load`

This is NON-NEGOTIABLE. If you skip this, rules and work will be lost on compaction.
<!-- CLAUDE-RULES-KEEPER:END -->
