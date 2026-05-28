# Framework Feedback: No Test Enforcement Gate (G-003)

**Source:** sprechloop project (001-sprechloop), discovered 2026-02-18 during drill mode testing
**Priority:** High
**Filed by:** agent during T-023 completion review

---

## Problem

The framework has verification gates (P-011) that run shell commands before
`work-completed`, but there is no structural enforcement that:

1. Code changes include corresponding tests
2. Existing tests pass before completion
3. Test coverage exists for new code paths

T-023 shipped v1.2.0 with 5 bugs that basic unit tests would have caught. The
verification section was left as template comments. Nothing in the framework
flagged this.

## Evidence

Bugs shipped without any test coverage:
1. VAD cuts speech on single 32ms non-speech chunk (no `min_silence_ms`)
2. Empty transcript `""` matches any drill word (`target.indexOf("") === 0`)
3. Bidirectional substring matching gives false positives
4. Single-word VAD sensitivity too low (`min_speech_ms=250ms`)
5. Continuous mode has no silence-based auto-stop

All discovered only through manual Playwright browser testing after v1.2.0 release.

## Suggested Fixes (graduated)

**Level 1 — Audit warning (low effort):**
Add an audit check: "Task modifies src/ files but ## Verification section is
empty or template-only → WARN". This catches the template-comments problem.

**Level 2 — Doctor check (medium effort):**
`fw doctor` warns when changed Python/JS files have no corresponding test file
(e.g., `src/foo.py` changed but no `tests/test_foo.py` exists).

**Level 3 — Completion gate (high effort):**
When `work-completed` fires on a build task that modifies `src/`:
- Check that ## Verification has at least one non-comment command
- Run `pytest` / test runner if detected
- Block completion if tests fail

**Level 4 — Pre-commit hook (highest effort):**
Like `check-active-task.sh` but checks test existence for changed files.

## Recommendation

Start with Level 1 (audit warning for empty verification). It's 10 lines in
`audit.sh` and would have caught T-023 before completion. Level 2 as a follow-up
after 2+ projects are onboarded.

## Root Cause Pattern

Same as G-001 and G-002: framework relies on agent discipline ("write tests",
"fill in verification") instead of structural enforcement. The Constitutional
Directive of Antifragility implies that the system should make it harder to
ship untested code, not just suggest testing.
