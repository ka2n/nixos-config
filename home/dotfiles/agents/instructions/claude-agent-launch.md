## Agent launch rules

- Delegate implementation (code editing) to subagents (e.g. `Agent(subagent_type: general-purpose, model: 'lighter'|'stronger')`)
  with concrete instructions: file paths, changes, verification commands, and any env caveats.
  The main session focuses on research, planning, judging review results, and reporting.
- When a subagent needs an isolated working copy (parallel edits, risky changes, or
  work that shouldn't touch the current tree), launch it with `isolation: worktree`
  from the start — don't create a worktree manually first. It (and EnterWorktree) goes
  through `git wt` via the WorktreeCreate/WorktreeRemove hooks, which also run direnv and cleanup.
- Delegate branch creation / commit / push / PR creation to a subagent as well
  (pre-push hooks are slow; keep them out of the main context). Always launch these with
  `model: 'lighter'` for mechanical work that does not need deep reasoning. Spell out the branch
  name, commit message, PR title/body, files to stage, and constraints in the prompt.
  Multiple repos → parallel subagents.
- For the reviews required in the Review section, use the code-reviewer agent (backed by Codex).

