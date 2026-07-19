---
id: T-2547
name: "make doctor_designer_pin_drift.bats hermetic (non-hermetic test corrupts live
  pin on interrupt)"
description: >
  make doctor_designer_pin_drift.bats hermetic (non-hermetic test corrupts live pin
  on interrupt)

status: started-work
workflow_type: build
owner: agent
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
created: 2026-07-19T12:41:36Z
last_update: '2026-07-19T12:45:09Z'
date_finished:
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
cost_estimate_proposed:
  - ts: '2026-07-19T12:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-19T12:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2547: make doctor_designer_pin_drift.bats hermetic (non-hermetic test corrupts live pin on interrupt)

## Context

`tests/unit/doctor_designer_pin_drift.bats` mutates the **live tracked**
`policy/designer-pin.yaml` in place (setup backs it up, each test rewrites it via a
yaml round-trip that strips comments + sets bogus sha/path, teardown restores). Each
test runs full `bin/fw doctor` (~100s), so a run takes ~400s. If interrupted (timeout,
pkill, agent teardown) mid-run, `teardown()` never fires → the working tree is left
with a corrupted pin (zeroed sha or `does-not-exist-t2524.html` path, comments stripped).
This corrupted the T-2546 0.3.0 re-pin twice live (2026-07-19); caught both via
re-verification before commit, but it nearly shipped a broken pin. Root: non-hermetic
test writes a tracked file. Fix: env-override the doctor pin path so the test mutates a
temp copy — the live file is never touched. See L-502 sibling; RCA below.

## Acceptance Criteria

### Agent
- [x] `bin/fw` doctor designer-pin check honors `FW_DESIGNER_PIN_FILE` (falls back to `$PROJECT_ROOT/policy/designer-pin.yaml`); `vendored_path` still resolves against `PROJECT_ROOT` — verified `bin/fw:1467`
- [x] `doctor_designer_pin_drift.bats` rewritten hermetic: mutations target a temp pin via `FW_DESIGNER_PIN_FILE`; the live `policy/designer-pin.yaml` is never written — verified (test lines 26-27 cp→temp + export)
- [x] all 4 cases still pass (t1 OK / t2 WARN / t3 SKIP-absent / t4 SKIP-missing-fields) — bats 5/5 rc=0 (t5 = hermetic guard)
- [x] interrupt-safety proven: `git diff --quiet policy/designer-pin.yaml` holds during and after a run (live file untouched even mid-run) — PROVEN LIVE: a SIGKILL'd run (exit 137) left the tracked pin clean, plus in-test t5 guard

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

grep -q 'FW_DESIGNER_PIN_FILE:-' bin/fw
grep -Fq 'export FW_DESIGNER_PIN_FILE="$PIN_TMP"' tests/unit/doctor_designer_pin_drift.bats
grep -Fq "p = '\$PIN_TMP'" tests/unit/doctor_designer_pin_drift.bats
git diff --quiet -- policy/designer-pin.yaml

## RCA

**Symptom:** During the T-2546 designer 0.3.0 re-pin, the working-copy
`policy/designer-pin.yaml` was corrupted twice mid-session — first `sha256` zeroed to
64 zeros, then `vendored_path` set to `vendor/designer/does-not-exist-t2524.html`, both
times with all comments stripped. Caught both via re-verification before commit, but a
broken pin (doctor drift + serving failure) nearly landed on master.

**Root cause:** `doctor_designer_pin_drift.bats` mutates the **live tracked**
`policy/designer-pin.yaml` in place (python yaml round-trip that sets bogus values and
drops comments), relying on `teardown()` to restore from a setup backup. bats `teardown`
is best-effort — it does **not** run on SIGTERM / timeout / pkill / agent teardown.
Each test also runs full `bin/fw doctor` (~100s), so a run holds the mutation live for a
~400s window. Two of my runs were killed mid-test (60s `timeout`; a `pkill` of a hung
background run) → the reparented bats kept cycling test cases, each rewriting the live
pin, and stranded the last mutation.

**Why structurally allowed:** the "mutate the live file + restore in teardown" isolation
pattern has no interrupt-safety — restoration is a best-effort epilogue, not a guarantee.
Nothing pointed the drift check at a sandbox pin; the tracked file itself *was* the
fixture. No guard asserted the live file stayed clean across a run.

**Prevention (distinct from the fix):**
1. `FW_DESIGNER_PIN_FILE` env override on the doctor check → the test mutates a temp copy;
   the live file is **never written** — interrupt-safe *by construction*, not by teardown.
2. New `t5` case asserts `git diff --quiet policy/designer-pin.yaml` after a mutating run
   (regression guard: fails if any test ever writes the live file again).
3. L-503 generalises the anti-pattern (mutate-in-place tests on tracked files) so the next
   such test — MCP manifest, cron registry — is written hermetically from the start.

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

### 2026-07-19T12:41:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2547-make-doctordesignerpindriftbats-hermetic.md
- **Context:** Initial task creation
