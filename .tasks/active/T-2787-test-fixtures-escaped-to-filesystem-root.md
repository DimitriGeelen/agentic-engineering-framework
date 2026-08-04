---
id: T-2787
name: "test fixtures escaped to filesystem root — guard against framework markers at /"
description: >
  test fixtures escaped to filesystem root — guard against framework markers at /

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-04T13:03:27Z
last_update: 2026-08-04T13:13:00Z
date_finished: 2026-08-04T13:13:00Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-2787: test fixtures escaped to filesystem root — guard against framework markers at /

## Context

The filesystem root of this host carries live framework markers:

```
/.tasks/active/T-994-unjudged.md     Aug  3 15:01
/.tasks/active/T-995-port.md         Aug  3 15:01
/.tasks/active/T-9999-test.md        Jun 27 19:28
/.context/working/.fw-secret-key
```

`T-994-unjudged` and `T-995-port` are byte-for-byte the fixtures from
`tests/unit/verification_unjudged_test_run.bats` (T-2738) and the T-2732
port-literal work. They are test fixtures that escaped their temp directory and
were written to `/`.

**Mechanism.** 106 bats files build fixture paths as `mkdir -p "$PROJECT_ROOT/.tasks/active"`.
`$PROJECT_ROOT` is set inside each file's own `setup()`. When it is unset — a
`setup()` that errors before assigning it, a file that forgot, a helper invoked
outside bats — the expression is literally `mkdir -p "/.tasks/active"`, which
succeeds silently as root. Subsequent `cat > "$project_dir/.tasks/active/…"`
calls then populate it.

**How it surfaced.** `tests/unit/test_hook_paths.py::test_noop_when_cwd_outside_any_project`
is red. It asserts that `reanchor_project_root` no-ops when cwd is outside any
project; it returns `/` instead. That is a **true positive** — the resolver walks
up looking for `.framework.yaml` or `.tasks`, and `/.tasks` exists, so `/` *is* a
valid project root by the resolver's own rule. The function is correct; the host
is polluted. Any hook firing with a cwd outside a project resolves
`PROJECT_ROOT=/` and reads/writes `/.tasks` and `/.context`.

**Scope fence.** This task ships the *detective* guard only. Removing the stray
directories is Tier 0 (`rm -rf` at filesystem root) and belongs to the operator.
Auditing all 106 bats files for the unguarded-`$PROJECT_ROOT` pattern is a
separate task — it is a sweep, not a guard.

**The guard will be RED on this host until the operator clears root.** That is
the intended state: the hazard is live, and a guard that passed while `/.tasks`
existed would be the false green this session has spent its length removing.

## Acceptance Criteria

### Agent
- [x] A guard test asserts that no framework marker (`/.tasks`, `/.context`,
      `/.framework.yaml`) exists at the filesystem root.
      → `tests/unit/no_root_framework_markers.bats`
- [x] Its failure message names the *cause* (a test writing through an unset
      `$PROJECT_ROOT`) and the operator remedy, not merely "file exists" — an
      operator reading it cold must know what to do without opening this task.
- [x] The guard is proven to distinguish both states rather than only the one it
      currently sees: demonstrated PASS against a synthetic clean root and FAIL
      against a synthetic polluted root (L-530 — a guard that has never been both
      is only evidence that it is implemented).
      → 3 control tests, all green; live assertion red.
- [x] The guard is picked up by a runner that actually executes it — verified by
      running that runner and seeing the test named in its output, not by the
      file's presence in a directory (T-2696: `tests/lint/` was globbed by no
      runner for 51 days).
      → `bats --count tests/unit/` = **3080** with the file, **3076** without.
- [x] `## Findings` records the live evidence (paths, mtimes, fixture provenance)
      so the record survives the operator clearing root, after which the evidence
      is unreproducible.
- [x] The follow-up sweep of the 106 `mkdir -p "$PROJECT_ROOT/…"` call sites is
      filed as its own task with the count and file list, not folded in here.
      → **T-2788**

### Human
- [ ] [REVIEW] Clear the framework markers from filesystem root

  **Steps:**
  1. Inspect first — confirm nothing of value is there:
     `ls -la /.tasks/active/ /.context/working/`
  2. The three task files are test fixtures (`T-994`, `T-995`, `T-9999`) and the
     only other item is `/.context/working/.fw-secret-key`. Confirm you agree
     none is real project state.
  3. Remove (Tier 0 — destructive, at filesystem root, your call not the agent's):
     `sudo rm -rf /.tasks /.context`
  4. Re-run both — the guard (bats) and the test that was red because of this:
     `cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/no_root_framework_markers.bats && python3 -m pytest tests/unit/test_hook_paths.py -q`

  **Expected:** guard 4/4 ok (the live assertion flips from `not ok 4` to `ok 4`),
  and `test_noop_when_cwd_outside_any_project` passes — because `/` is no longer a
  project root by the resolver's rule. Neither needed a code change.

  **Also worth doing:** `/.context/working/.fw-secret-key` is a framework secret
  that has sat in a world-readable directory at filesystem root since May 5.
  Consider rotating it rather than only deleting it.

  **If not:** something else is re-creating the markers — capture which test with
  `sudo find / -maxdepth 1 -name ".tasks" -newermt "-1 hour"` after a full suite
  run, and re-open this task rather than deleting again.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# The three control tests must pass. The live assertion is expected RED until the
# operator clears filesystem root (Human AC) — so this gate checks the controls,
# not the whole file. Once root is clean, tighten to `! grep -q "^not ok"`.
bats tests/unit/no_root_framework_markers.bats > /tmp/.t2787.out 2>&1 || true
grep -q "^ok 1 predicate reports a clean root" /tmp/.t2787.out
grep -q "^ok 2 predicate detects every marker kind" /tmp/.t2787.out
grep -q "^ok 3 predicate detects a partially polluted root" /tmp/.t2787.out
# the guard is reachable from the runner's own directory form, not merely present
test "$(bats --count tests/unit/ 2>/dev/null)" -gt 3076

# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## Recommendation

**Recommendation:** GO — merge the guard, then clear filesystem root.

**Rationale:** The guard is complete and its red state is the correct reading of a
live hazard, not a defect in the guard. Every agent AC is closed with measurement
rather than assertion: three control tests exercise the predicate against clean,
fully-polluted and partially-polluted roots, and collection by the real runner is
proven by a count delta rather than by the file existing in a directory.

What remains is yours because it is Tier 0 and destructive at filesystem root —
`sudo rm -rf /.tasks /.context`. I have deliberately not touched it. Please read
the three stray files first (they are quoted in `## Findings`, all three are test
fixtures) and confirm you agree none is real state before removing.

Two things worth your attention beyond the removal:

1. `test_hook_paths.py::test_noop_when_cwd_outside_any_project` has been red
   because of this, and it is a **true positive** — while `/.tasks` exists, `/`
   genuinely is a project root by the resolver's own rule. Clearing root turns
   that test green without touching the resolver.
2. The stray `/.context/working/.fw-secret-key` is a framework secret sitting in
   a world-readable directory at filesystem root. Worth rotating rather than only
   deleting, since it has been there since May 5.

**Evidence:**
- `tests/unit/no_root_framework_markers.bats` — 3 controls PASS, live assertion
  FAIL with a diagnostic naming cause and remedy.
- Runner collection: `bats --count tests/unit/` = 3080 with the guard, 3076
  without (delta 4 = the guard's own tests).
- Fixture provenance traced to `verification_unjudged_test_run.bats` (T-2738) and
  the T-2732 port-literal work — slug, task id and Verification body all match.
- Writer mechanism located: 106 bats files build paths on an unguarded
  `$PROJECT_ROOT`; filed as T-2788 rather than folded in here.
- OBS-145 filed separately: `tests/unit/*.py` (164 files, 2,095 tests) is
  executed by no `fw` runner — which is why the 11 red unit tests went unnoticed,
  and why this guard is `.bats`.

## Findings

### Live evidence, captured 2026-08-04 (unreproducible once root is cleared)

```
drwxr-xr-x  /.tasks                                 Jun 27 15:56
drwxr-xr-x  /.tasks/active                          Aug  3 15:01
-rw-r--r--  /.tasks/active/T-994-unjudged.md   438b Aug  3 15:01
-rw-r--r--  /.tasks/active/T-995-port.md       416b Aug  3 15:01
-rw-r--r--  /.tasks/active/T-9999-test.md       99b Jun 27 19:28
drwxr-xr-x  /.context                               May  5 18:31
            /.context/working/.fw-secret-key
/.framework.yaml — absent
```

Fixture provenance, from file contents:

| File | `name:` | Verification body | Origin |
|---|---|---|---|
| `T-994-unjudged.md` | "Unjudged test run" | `out=$(python3 -m pytest x.py -q 2>&1); echo "$out" \| grep -q "2 passed"` | `tests/unit/verification_unjudged_test_run.bats` (T-2738) |
| `T-995-port.md` | "Port literal test" | `curl -sf http://localhost:3000/costs -o /dev/null` | T-2732 port-literal gate |
| `T-9999-test.md` | — | (AC-only stub) | older, Jun 27 |

`make_task()` in `verification_unjudged_test_run.bats` writes to
`"$project_dir/.tasks/active/${task_id}-unjudged.md"` with `task_id` defaulting
to `T-994` — matching the stray file exactly, including the slug.

### Mechanism

`create_test_project()` in `tests/test_helper.bash` defaults safely
(`"${1:-$TEST_TEMP_DIR/project}"`), so it is not the source. The exposure is
**106 bats files** that build paths directly:

```bash
mkdir -p "$PROJECT_ROOT/.tasks/active"
```

`$PROJECT_ROOT` is assigned inside each file's own `setup()`. Unset at that
moment, the expression is literally `mkdir -p "/.tasks/active"` — which succeeds
silently under a root-owned suite, after which fixture writes populate it.

### Why this is a live hazard, not litter

`lib/hook_paths.py:reanchor_project_root` (and its bash twin
`lib/paths.sh:fw_reanchor_from_cwd`) walk up from a hook's cwd and return the
**first** directory holding `.framework.yaml` or `.tasks`. With `/.tasks`
present, `/` satisfies that rule. Any hook firing with a cwd outside a project
therefore resolves `PROJECT_ROOT=/`.

`tests/unit/test_hook_paths.py::test_noop_when_cwd_outside_any_project` is red
against this: it expects the fallback and gets `/`. **It is a true positive.**
The resolver is correct and the host is polluted — which is why the fix is to
clear root, not to relax the test.

### Guard verification

| Check | Result |
|---|---|
| clean root (negative control) | PASS |
| all three markers present (positive control) | PASS |
| `.tasks` only — the real-world partial shape | PASS |
| live `/` assertion | **FAIL** (intended — hazard is live) |
| collected by `bats tests/unit/` | 3080 with / 3076 without = **+4** |

### Why the guard is `.bats` and not `.py`

Measured while writing it: `fw test unit` runs `bats "$FRAMEWORK_ROOT/tests/unit/"`
(`bin/fw:7638`) and `fw test all` points pytest at `web/test_app.py tests/web/`
(`bin/fw:7789`) — never at `tests/unit/`. The 164 `.py` files / 2,095 pytest
tests in that directory are executed by **no** `fw` runner (OBS-145). A pytest
guard would have become the 2,096th unexecuted test — the exact trap it exists
to help close.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-04T13:03:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2787-test-fixtures-escaped-to-filesystem-root.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f3083049
- **Timestamp:** 2026-08-04T13:13:46Z
- **Catalogue:** v1.3-seed
- **Overall:** FAIL
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **swallowed-errors** (severe, deterministic) @ Verification:line 62
     - evidence: `bats tests/unit/no_root_framework_markers.bats > /tmp/.t2787.out 2>&1 || true`

### 2026-08-04T13:13:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
