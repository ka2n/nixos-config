## GitHub and CI

- Use `gh` command for all GitHub-related operations
- PR descriptions: Do not include "Test plan" section
- Never use `git push --force` on main branch
- Post-push CI monitoring:
  1. Start `gh run watch $(gh run list -L 1 --json databaseId -q '.[0].databaseId') --exit-status` with `Bash(run_in_background=true)`
  2. Continue with other work (no report needed on CI success)
  3. On failure only: Check logs → Fix issue → Commit & push → Return to step 1 (max 3 attempts)

