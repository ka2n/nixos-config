---
name: refine-test
description: Refine tests after implementation using the "four pillars" framework — remove or improve low-value tests and add missing ones. Use automatically after code changes, and whenever tests need review, improvement, or additions.
---

# Refine Test

After implementation, refine the tests related to the changed code against the criteria for valuable tests below.

## What makes a test valuable

The goal: enable sustainable growth of the project.

### 1. Has the four pillars

A test's value is the **product** of these four attributes. If any is zero, the test is worthless.

- **Protection against regressions** — reliably detects bugs introduced by changes
- **Resistance to refactoring** — does not fail (no false positives) when implementation details change but behavior does not
- **Fast feedback** — runs quickly
- **Maintainability** — easy to read; few out-of-process dependencies (DB, etc.)

The first three cannot all be maximized at once; balance them for the situation.

### 2. Targets important code

Focus effort on complex business logic (the domain model). Tests for trivial code are low value — skip them.

### 3. Runs in the development cycle

Tests only pay off if they run automatically on every change.

### 4. Maximizes value per maintenance cost

Test code is a **liability**, not an asset. Keep only tests whose value exceeds their maintenance cost.

## Workflow

1. Identify changed source files
2. Evaluate the corresponding tests against the four pillars — delete zero-value tests
3. Add missing tests, focusing on important code
4. Run the test suite and confirm all pass
