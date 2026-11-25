---
name: quint-counterexample-test
description: Model a feature or PR in Quint, find counterexamples, and turn concrete failing traces into regression tests against the implementation. Use when asked to verify a design with Quint or derive implementation tests from model checking.
---

# Quint Counterexample Tests

Use Quint by default to connect specification checking to executable regression tests.
The outcome is a model, recorded verification evidence, and implementation tests that
reproduce real counterexamples. A model-only failure is not yet an implementation bug.

## Establish the contract

Identify the target PR, revision, or feature and read its implementation, tests, and
stated requirements. Derive intended properties from the domain contract, rather than
copying implementation behavior into a model and calling it correct.

Model the state and transitions relevant to those properties. Include concrete failure
boundaries where relevant: concurrent workers, retries, lease expiry, partial failure,
external side effects, and stale state. State assumptions about external systems.
If a requirement is ambiguous, distinguish the alternatives and ask only when that
ambiguity blocks a meaningful conclusion.

Prefer a small bounded model that can expose the suspected failure. Record which
production behaviors are abstracted away. When reviewing a refactor, distinguish
existing defects from regressions introduced by the change.

## Write and check the Quint model

Follow existing repository conventions; otherwise place the model and a concise
verification README under `spec/quint/` in the affected component.
Use separate configurations or instances for current and proposed behavior when useful.
Keep the relevant properties consistent across them.

Use the repository's pinned Quint version and development environment. If none exists,
select and record an explicit version. Check that version's CLI help before choosing
backend flags; do not assume command syntax or backend availability. Use Quint as the
source specification. Use another specification language only when requested or when
a concrete Quint limitation requires it, and explain the reason.

Typecheck first. Use `quint run` to explore traces and `quint verify` with an available
backend to check properties. Select bounded symbolic checking or finite exhaustive
checking according to the property and state space. Random simulation complements
verification but does not establish exhaustive coverage.

Record the exact commands, version, constants/bounds, checked properties, backend,
seed when applicable, and result. Distinguish counterexample found, no violation within
the checked scope, timeout, and incomplete execution. Never describe a bounded or
random check as proof of correctness for arbitrary production executions.
Follow the environment's heavy-compute rules when running expensive checks.

## Turn counterexamples into implementation tests

For each relevant counterexample:

1. Extract the concrete initial values and ordered transitions. Map them to production
   operations and identify the violated contract.
2. Check that the trace is feasible in the implementation. Refine an inaccurate model
   instead of reporting an abstraction artifact as a bug.
3. Write the smallest regression test at the existing unit-test boundary that preserves
   the failure mechanism. Use controlled clocks, deferred promises, or explicit mocks
   for interleavings and failures; avoid sleeps and probabilistic races. If a unit test
   cannot preserve the mechanism, use the narrowest suitable integration boundary and
   explain why.
4. Run the test against the target implementation and confirm it fails for the expected
   assertion. Compilation errors, broken fixtures, and unrelated failures do not count.
   Record the revision and failure evidence. Do not weaken the expected contract to
   make the test pass.

If no counterexample is found, report the checked scope and limitations. Do not invent
an implementation defect or force an irrelevant failing test.

## Fix only within the requested scope

A request to model and demonstrate a failure authorizes the model and reproducing
tests, not an automatic production fix. When a fix is requested, preserve the failing
regression test, fix the implementation, and confirm red-to-green. Update the model to
represent the actual fix and recheck the same properties. Run the relevant existing
tests as well.

Report the contract, concrete counterexample, implementation test and observed failure,
verification scope, and any remaining mismatch between model and code. Link the model,
tests, and recorded commands so another engineer can reproduce the result. Commit,
push, and PR actions remain governed by the user's request.
