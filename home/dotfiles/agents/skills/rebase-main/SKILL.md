---
name: rebase-main
description: Safely rebase the current branch onto the latest origin/main. Stashes uncommitted work, fetches, rebases, and restores.
---

## Steps

1. Stash any uncommitted changes (including untracked files):
   ```bash
   git stash -u -m "rebase-main: auto-stash"
   ```
   Record whether the stash was created (exit code 0 and stash list changed).

2. Fetch latest:
   ```bash
   git fetch origin main
   ```

3. Rebase:
   ```bash
   git rebase origin/main
   ```
   If conflicts occur, report them and stop — do not auto-resolve.

4. Restore stash if one was created:
   ```bash
   git stash pop
   ```

5. Print the result: new base commit, number of replayed commits, whether stash was restored.
