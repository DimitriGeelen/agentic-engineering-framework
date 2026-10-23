# bats-heredoc-test

> T-4521 — tools/bats-heredoc-test-lint.py.

**Type:** script | **Subsystem:** tests | **Location:** `tests/lint/bats-heredoc-test.bats`

## What It Does

T-4521 — tools/bats-heredoc-test-lint.py. Bats <1.11 (Ubuntu 24.04 apt ships
1.10) finds tests by scanning source text, heredocs included, so a fixture
`@test` written through a heredoc becomes a test of the OUTER file; two with
the same name abort the whole run ("Duplicate test name(s)"). The first test
is the gate on the live corpus; the rest pin the lint against fixtures so a
lint that never fires cannot pass as green.
Fixtures here are written with printf on purpose: a heredoc would be the very
shape under test. `! cmd` at statement position is INERT in bats (L-628).

---
*Auto-generated from Component Fabric. Card: `tests-lint-bats-heredoc-test.yaml`*
*Last verified: 2026-10-21*
