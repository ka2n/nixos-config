## Agent launch rules

- Delegate implementation (code editing) to subagents (e.g. `Agent(subagent_type: general-purpose, model: 'lighter'|'stronger')`)
  with concrete instructions: file paths, changes, verification commands, and any env caveats.
  The main session focuses on research, planning, judging review results, and reporting.
- When a subagent needs an isolated working copy (parallel edits, risky changes, or
  work that shouldn't touch the current tree), launch it with `isolation: worktree`
  from the start — don't create a worktree manually first. It goes through `git wt`
  via hooks, so the standard worktree layout and lifecycle hooks are applied
  automatically.
- Delegate branch creation / commit / push / PR creation to a subagent as well
  (pre-push hooks are slow; keep them out of the main context). Always launch these with
  `model: 'lighter'` for mechanical work that does not need deep reasoning. Spell out the branch
  name, commit message, PR title/body, files to stage, and constraints in the prompt.
  Multiple repos → parallel subagents.
- After completing large code changes (3 or more files, or 100+ lines), you must launch the code-reviewer agent.
- When changes span multiple files, launch code-reviewer agents in parallel.

