---
name: opsx-run
description: "Autonomous execution helper for OpenSpec tasks. Checks change readiness, then selects execution method based on task size: ralph-loop (small) or ralph-tui (large). Triggers: 'run tasks autonomously', 'ralph run', 'opsx:run', 'auto-execute', 'loop execute', 'run with ralph'"
disable-model-invocation: true
---

# opsx-run: OpenSpec Autonomous Task Execution Helper

Assess and prepare autonomous execution of OpenSpec change tasks.

## Workflow

### Step 1: Select Change and Check Readiness

1. Use the change name from arguments if provided. Otherwise run `openspec list --json` and prompt the user to select.
2. Check status:
   ```bash
   openspec status --change "<name>" --json
   ```
3. Get apply instructions:
   ```bash
   openspec instructions apply --change "<name>" --json
   ```

**Blocked**: If proposal, specs, or tasks are incomplete, advise the user to run `opsx:continue` SKILL first and stop.

### Step 2: Determine Task Size

Read `tasks.md` and analyze incomplete tasks (`- [ ]`).

| Criteria | Small | Large |
|----------|-------|-------|
| Incomplete tasks | 5 or fewer | 6 or more |
| Estimated files affected | Few | Many / multiple domains |
| Dependency complexity | Linear / simple | Branching / parallelizable |

Present the assessment to the user for confirmation. Defer to the user if they override.

### Step 3A: Small Tasks → ralph-loop

Build the following command and **present it to the user for confirmation before executing** via the Skill tool.

Skill name: `ralph-loop:ralph-loop`

**IMPORTANT**: The argument MUST be a single line. `ralph-loop` passes `$ARGUMENTS` directly to a Bash command, so newlines will break parsing.

Argument template (single line):

```
--completion-promise COMPLETE --max-iterations <N> Implement tasks for OpenSpec change "<CHANGE_NAME>": run /opsx:apply <CHANGE_NAME> to implement tasks sequentially, then run /opsx:verify <CHANGE_NAME> to validate, if verify reports no CRITICAL issues output <promise>COMPLETE</promise> to signal completion, if CRITICAL issues exist fix them and re-run verify, use best judgment if a task is unclear, on errors analyze root cause and attempt a fix, update tasks.md checkboxes after completing each task
```

- `<N>`: task count x 2 as a guideline (minimum 5, maximum 20)
- Once the user confirms, invoke `ralph-loop:ralph-loop` with the above arguments via the Skill tool

### Step 3B: Large Tasks → ralph-tui (prd.json)

1. Read `tasks.md`, `proposal.md`, and `design.md` (if present) from `openspec/changes/<name>/`
2. Invoke `ralph-tui-create-json` SKILL with the change artifacts as context to generate `openspec/changes/<name>/prd.json`
3. Instruct the user:
   ```
   Generated prd.json: openspec/changes/<name>/prd.json

   Run the following in a separate terminal:
   ralph-tui run --prd openspec/changes/<name>/prd.json --agent claude

   After completion, run /opsx:verify <name> in this session to validate.
   ```

## Important Notes

- run `opsx:verify` SKILL after completion.
