---
name: organize-commits
description: >-
  Reorganize messy git commit history on a feature branch into clean, reviewer-friendly commits.
  Use when: user says "コミットを整理", "organize commits", "squash commits", "clean up history",
  "rewrite commits", or wants to prepare a branch for PR review by removing trial-and-error noise.
  Handles soft reset, logical grouping, and recommitting with clear messages.
---

# Organize Commits

Reorganize feature branch commits into clean, logical units optimized for code review.

## Workflow

### 1. Analyze current commits

```bash
git log --oneline main..HEAD          # all commits on branch
git diff --stat main..HEAD            # full changeset summary
```

Read each commit's full diff to understand what changed and why.

### 2. Plan commit grouping

Group changes by **reviewer reading order** — the sequence that makes the change easiest to understand:

1. **Schema / data model** — DB migrations, type definitions, generated code
2. **Core logic** — business logic, actions, workflows, API changes
3. **UI** — components, templates, styles
4. **Tests** — unit tests, E2E tests, test helpers
5. **Docs / config** — documentation, configuration, CI changes

Merge trial-and-error fixes into the commit where the feature was introduced. Do not preserve fix-up commits that correct mistakes from earlier in the same branch.

### 3. Reset and recommit

```bash
git reset --soft $(git merge-base main HEAD)   # keep all changes staged
git reset HEAD -- .                             # unstage everything
```

Then selectively stage and commit each group:

```bash
git add <files-for-group>
git commit -m "$(cat <<'EOF'
<type>: <concise description>

<optional body explaining why, not what>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### 4. Verify

```bash
git diff main..HEAD --stat    # should match original changeset exactly
git log --oneline main..HEAD  # clean history
```

## Commit message conventions

- Follow the repo's existing style (check `git log --oneline -20` on main)
- Common prefixes: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Write in the language the repo uses for commits (check existing history)
- Keep subject line under 72 characters
- Body explains **why**, not what (the diff shows what)

## Guidelines

- **Never lose changes**: `git diff main..HEAD --stat` must match before and after
- **Atomic commits**: each commit should compile and (ideally) pass tests independently
- **No backward-compat hacks**: if a fix corrects something introduced in the same branch, fold it in
- **Generated files** (types, lock files) go with the commit that caused regeneration
- **3-7 commits** is typical for a medium feature branch; adjust to actual scope
- **Ask before force push**: reorganizing requires `git push --force-with-lease`, always confirm first
