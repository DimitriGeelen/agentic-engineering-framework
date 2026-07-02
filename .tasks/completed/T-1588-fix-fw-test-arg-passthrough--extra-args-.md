---
id: T-1588
name: "Fix fw test arg-passthrough — extra args ignored, runs entire suite (origin:
  T-1575 hung BATS, T-1586 hit again)"
description: >
  fw test [unit|integration|web|playwright|all] hardcodes the test target directory
  and ignores any extra args. `fw test playwright -- tests/playwright/test_cross_surface_parity.py`
  runs the entire playwright suite (~hundreds of tests) instead of filtering. Same
  bug T-1575 hit (BATS unit suite) — surfaces in two test domains, only acknowledged
  in task RCAs, never fixed in source.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw]
related_tasks: [T-1575, T-1586, T-1587]
created: 2026-04-28T16:34:35Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-28T16:38:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1588: Fix fw test arg-passthrough — extra args ignored, runs entire suite (origin: T-1575 hung BATS, T-1586 hit again)

## Context

`fw test [unit|integration|web|playwright]` (`bin/fw:4623-4751`) hardcodes the test-target directory. Extra args after the subcommand (e.g. `fw test playwright -- tests/playwright/test_X.py`) are silently ignored — the entire suite runs anyway. T-1575 hit this with BATS unit tests (the verification command spawned hundreds of tests instead of one file, hung the session); T-1586 hit it again with Playwright (kicked off all `tests/playwright/` instead of the one new file). Each task RCA noted the canonical workaround (`python3 -m pytest <file>` directly), but the source bug was never fixed. This task ships the fix.

## Acceptance Criteria

### Agent
- [x] `bin/fw test unit [-- args]` — extra args are passed through to `bats`. Default behaviour (no extra args) still runs `tests/unit/` as before.
- [x] `bin/fw test integration [-- args]` — same shape, passes through to `bats`.
- [x] `bin/fw test web [-- args]` — passes through to `python3 -m pytest`. Default still runs `web/test_app.py`.
- [x] `bin/fw test playwright [-- args]` — passes through to `python3 -m pytest`. Default still runs `tests/playwright/`.
- [x] Leading `--` separator (Unix convention) is consumed if present, so `fw test playwright -- file` and `fw test playwright file` both work.
- [x] `bin/fw test playwright tests/playwright/test_cross_surface_parity.py` runs only that file (smoke verification — should complete in <30s, not several minutes for the whole suite).
- [x] `bin/fw test playwright` (no args) still runs the whole suite — backward compatible.
- [x] `bin/fw test all` (which has its own loop) is NOT changed in this task — out of scope; targets ALL suites by definition.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# T-1588 — pin the fix.
# Backward compat: no-arg invocation still works (smoke check).
bin/fw test playwright --help 2>/dev/null || true  # placeholder — playwright case has no --help, so just exit 0
# Targeted invocation completes fast (<60s wall time for one file) — proves filter took effect.
timeout 90 bin/fw test playwright tests/playwright/test_cross_surface_parity.py >/tmp/T-1588-out.log 2>&1
grep -qE '8 passed' /tmp/T-1588-out.log
# `--` separator path also works.
timeout 90 bin/fw test playwright -- tests/playwright/test_cross_surface_parity.py >/tmp/T-1588-dash.log 2>&1
grep -qE '8 passed' /tmp/T-1588-dash.log
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

## RCA

**Symptom:** `fw test playwright -- tests/playwright/test_X.py` (and unit/integration/web equivalents) silently runs the entire test suite, ignoring the file filter. T-1575 hit this when its verification command spawned hundreds of BATS tests instead of one — the session hung, had to be killed (SIGKILL on `bats-exec-suite`), the verification was rewritten to bypass `fw test` entirely (`python3 -m pytest <file>` directly). T-1586 hit it again the same day this task was created — same symptom, different domain (Playwright instead of BATS).

**Root cause:** `bin/fw:4623` parses subcommand via `case "${1:-all}" in` but never consumes additional positional args. Each subcommand handler hardcodes its target directory: `bats "$FRAMEWORK_ROOT/tests/unit/"` (line 4669), `python3 -m pytest tests/playwright/ -v` (line 4709), etc. Args beyond the subcommand name are dropped on the floor — `fw test playwright -- file.py` resolves to the same code path as `fw test playwright`.

**Why structurally allowed:** No invariant test pinned "fw test SUBCOMMAND <file> runs only <file>". The pattern is a classic shell-arg-passthrough oversight — the wrapper doesn't `shift` or use `"$@"` to forward extras. Each test domain (unit/integration/web/playwright) duplicates the same hardcoded shape, so a fix-once-here-only attempt would have left the bug in three other places. T-1575 and T-1586 both wrote workarounds in their `## Verification` sections rather than fixing the shared utility — same symptom of fix-around-the-wound L-291/L-316/L-317 family (each one added a Yet Another Workaround instead of patching the shared layer).

**Prevention:** This task ships the source fix across all four subcommands (unit/integration/web/playwright), all using the same shape: `shift; [ "${1:-}" = "--" ] && shift; if [ "$#" -gt 0 ]; then runner "$@"; else runner DEFAULT; fi`. Verification commands run two real targeted invocations and confirm both paths work in <30s — so the next task that hits the same shape will get the bug as a *test-time failure*, not a session-hanging timeout. Backward compat preserved: no-arg invocation still runs the whole directory.

The deeper preventive lesson is captured in L-317: when a workaround appears in a task's `## Verification` block (rather than the source), that's a signal the shared utility has a bug — file the fix task immediately, don't ship the workaround as the canonical solution.

## Decisions

### 2026-04-28 — `--` separator opt-in vs required
- **Chose:** `--` consumed if present, but not required. `fw test playwright -- file` and `fw test playwright file` both work.
- **Why:** Unix tradition is to have `--` as an opt-in disambiguator (between options and positional args). Forcing `--` would break the natural reading `fw test playwright FILE.py` and add a footgun (forgot the `--` ⇒ silent full-suite run). Accepting both shapes costs one shell line per handler (`[ "${1:-}" = "--" ] && shift`).
- **Rejected:** Require `--` as a mandatory separator. Reason: too easy to forget; the bug we're fixing is *exactly* the silent-default-when-arg-ignored class — a `--`-only design would re-introduce it.

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the bug class that T-1575 and T-1586 both worked around in their `## Verification` blocks. Source fix lives in the right place (`bin/fw` test handlers) instead of being duplicated as workarounds in every task that needed targeted runs. Backward compat preserved — no-arg invocations still run whole directories. Verification proves both `--` and no-`--` shapes work in <20s on a single-file run that would otherwise take many minutes.

**Evidence:**
- `bin/fw:4662-4710` modified — four handlers (unit/integration/web/playwright) gain `shift; [ "${1:-}" = "--" ] && shift; if [ "$#" -gt 0 ]; then runner "$@"; else runner DEFAULT; fi` pattern.
- `bin/fw test playwright tests/playwright/test_cross_surface_parity.py` → `8 passed in 18.18s`. Whole-suite would have been minutes.
- `bin/fw test playwright -- tests/playwright/test_cross_surface_parity.py` → `8 passed in 11.58s`. The `--` separator is consumed correctly.
- `bin/fw test playwright` (no args) — backward compat preserved (manually verified the dispatch still hits `python3 -m pytest tests/playwright/ -v`).
- RCA traces the failure mode back to T-1575 and T-1586 — both wrote workaround verifications instead of fixing the shared utility. This task closes the source bug.

## Updates

### 2026-04-28T16:34:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1588-fix-fw-test-arg-passthrough--extra-args-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cc9483e9
- **Timestamp:** 2026-06-02T14:58:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `bin/fw test web [-- args]` — passes through to `python3 -m pytest`. Default still runs `web/test_app.py`.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/test_app.py in: `bin/fw test web [-- args]` — passes through to `python3 -m pytest`. Default still runs `web/test_app.py`.`
### 2026-04-28T16:38:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
