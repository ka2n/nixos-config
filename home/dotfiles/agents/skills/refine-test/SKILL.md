---
name: refine-test
description: Use after code changes to refine tests with the four pillars: remove low-value tests, improve weak ones, and add missing coverage for important code. Also use whenever tests need review or refinement.
---

# Refine Test

After implementation, refine the tests related to the changed code against the criteria for valuable tests below.

## What makes a test valuable

The goal: make the project's growth sustainable.

### 1. Has the four pillars

A test's value is the **product** of these four attributes. If any is effectively zero, the test has little or no value.

- **Protection against regressions** — reliably detects bugs introduced by changes
- **Resistance to refactoring** — does not fail (no false positives) when implementation details change but behavior does not
- **Fast feedback** — runs quickly and surfaces regressions early
- **Maintainability** — easy to read and easy to run, with few out-of-process dependencies (DB, etc.)

The first three cannot all be maximized at once; balance them for the situation.

### 2. Targets important code

Focus effort on the parts most important to the system, especially complex business logic such as the domain model. Tests for trivial code are low value — skip them.

### 3. Runs in the development cycle

Tests only pay off when they are integrated into the development cycle and run automatically on every change.

### 4. Maximizes value per maintenance cost

Test code is a **liability**, not an asset. Keep only tests whose value exceeds their maintenance cost.

## Workflow

1. Identify changed source files
2. Evaluate the corresponding tests against the four pillars — delete zero-value tests
3. Add missing tests, focusing on important code
4. Run the relevant tests and confirm they pass
