---
id: T-1953
name: "G-064 gauge timezone fix — CRON_HOUR_UTC mismatches actual cron fire (crontab
  uses LOCAL time)"
description: >
  tools/g064-readiness.py defines CRON_HOUR_UTC=5 expecting UTC 05:33 fires, but /etc/cron.d/agentic-audit
  '33 5 * * *' is interpreted as LOCAL time. On this host (+02:00 summer) actual UTC
  fire is 03:33. Net effect: NO dispatch row ever matches the cron window — gauge
  structurally cannot detect cron-fire from dispatch.jsonl. Fix: make window check
  TZ-aware (convert dt to local before comparing) OR parameterise the cron schedule
  via env. Tests need TZ-portability fix too. Surfaced during T-1952 (v0.5 LATEST
  fallback) which masked but didn't fix the underlying TZ bug.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/test_g064_readiness.py, tools/g064-readiness.py]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-20T10:23:14Z
last_update: '2026-08-16T22:24:50Z'
date_finished: 2026-05-21T09:06:08Z
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
bvp_scores_proposed:
  - ts: '2026-05-20T10:28:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-20T10:30:01Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1953: G-064 gauge timezone fix — CRON_HOUR_UTC mismatches actual cron fire (crontab uses LOCAL time)

## Context

`tools/g064-readiness.py` defines `CRON_HOUR_UTC=5, CRON_MIN_UTC=33` matching crontab `33 5 * * *`. But cron interprets the crontab schedule as LOCAL time, not UTC. On non-UTC hosts (e.g. Europe/Amsterdam +02:00 summer), the actual UTC fire is 03:33 — outside the 05:33±5min window. Net: NO dispatch row from a real cron fire is ever flagged as cron-source. Bug is structurally invisible until T-1952's v0.5 fallback made it observable.

Origin: T-1952 build (2026-05-20) surfaced this when patched gauge correctly read the v0.5 LATEST timestamp (`generated: 2026-05-20T03:33:01+00:00`) but the cron-window check still didn't fire because the constant was wrong.

Related: L-411 (idempotent-cron observability blindspot) + L-364 (cron registry/generated/deployed three-stage drift class).

## Acceptance Criteria

### Agent
- [x] `_is_cron_firing()` converts dt to LOCAL time via `dt.astimezone()` (no-arg = system local TZ) and compares against `CRON_HOUR_LOCAL:CRON_MIN_LOCAL` — `tools/g064-readiness.py:81-89`
- [x] Constants renamed `CRON_HOUR_UTC`/`CRON_MIN_UTC` → `CRON_HOUR_LOCAL`/`CRON_MIN_LOCAL` (line 61-62); `cron_window` output string says `LOCAL` (line 207)
- [x] Existing tests pinned to TZ=UTC via `enforce_utc_tz` autouse fixture (lines 32-49) — all 21 pre-existing tests still pass under the rename
- [x] New test `test_non_utc_tz_recognises_utc_offset_dispatch` (line 391): pins TZ=Europe/Amsterdam, asserts UTC 03:33 dispatch → cron_firings=1. Plus `test_utc_05_33_does_not_fire_when_local_offset` (inverse case) and `test_cron_window_label_says_local` (operator-facing string)
- [x] `python3 tools/g064-readiness.py --json` on this host now shows `cron_firings=107 manual_runs=191 verdict=READY` (was structurally 0 before fix; G-064 closure-readiness signal restored)
- [x] T-1952's KNOWN BUG docstring note (lines 34-40 pre-fix) replaced with affirmative "Cron TZ semantics" doc — search confirms no residual `KNOWN BUG` mentions in tools/ tests/

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
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

python3 -m pytest tests/unit/test_g064_readiness.py -q
out=$(python3 tools/g064-readiness.py --json); python3 -c "import json,sys; d=json.loads('''$out'''); assert d['cron_firings']>0 and 'LOCAL' in d['cron_window'], d"
grep -q CRON_HOUR_LOCAL tools/g064-readiness.py
! grep -q "KNOWN BUG" tools/g064-readiness.py

## Recommendation

**Recommendation:** GO

**Rationale:** Fixes a structural observability lie. Pre-fix on any non-UTC host (this one runs Europe/Amsterdam +02), `_is_cron_firing` compared dispatch.UTC timestamps against UTC-labelled constants while real cron fires landed in dispatches.jsonl at UTC 03:33 (= local 05:33 = crontab `33 5 * * *`). Window was 152 min off the target — zero cron rows ever matched. The gauge therefore could not detect cron-source dispatches even when the substrate was healthy. With the fix, `python3 tools/g064-readiness.py` on this host reports `cron_firings=107 verdict=READY` — closure signal restored.

The fix is local in scope (3 constants + 1 function + 1 cron_window output string in `tools/g064-readiness.py`; TZ-pinning autouse fixture + 3 new regression tests in `tests/unit/test_g064_readiness.py`). No public-API changes; tool exit codes and JSON shape preserved.

**Evidence:**
- `python3 -m pytest tests/unit/test_g064_readiness.py -v` → 24/24 PASS (21 pre-existing + 3 new T-1953 regressions)
- `python3 tools/g064-readiness.py --json` (this host, TZ=+02) → `cron_firings=107 manual_runs=191 cron_window='05:33 LOCAL +/- 5 min' verdict=READY`
- New tests pin both directions: UTC 03:33 on TZ=+02 → cron-firing=1 ✓; UTC 05:33 on TZ=+02 → manual=1 (NOT cron) ✓
- `! grep -q "KNOWN BUG" tools/g064-readiness.py` — affirmative "Cron TZ semantics" doc replaces the bug note
- L-411 (idempotent-cron observability blindspot) + L-364 (registry/generated/deployed three-stage drift): both referenced; this task closes the **interpretation** leg (LOCAL vs UTC) that was orthogonal to deploy/registry drift

**Forward note:** Cron schedule is still hard-coded as `5:33`. A future enhancement could parameterise from `.context/cron-registry.yaml` (the canonical source) so the gauge auto-adapts when the schedule changes. Not in scope here; the structural blindness was the bug, the constant-rename is the fix.

## RCA

**Symptom:** `tools/g064-readiness.py` on Europe/Amsterdam host showed `cron_firings=0` for the entire post-T-1727 history despite hundreds of real cron-sourced rows in `.context/dispatches.jsonl`. T-1952's `v0.5 LATEST` fallback restored partial visibility for the most recent fire but still computed the window against the wrong TZ basis. G-064 closure could not be assessed mechanically on this host.

**Root cause:** `_is_cron_firing(dt)` converted dt to UTC and compared against `CRON_HOUR_UTC=5, CRON_MIN_UTC=33`. The crontab schedule `33 5 * * *` is interpreted by cron in **system local time**, not UTC. On TZ=+02 the actual UTC fire is 03:33 — 152 min away from 05:33 — outside the ±5 min window. The constant names and docstring asserted UTC semantics that did not match cron's actual behaviour.

**Why structurally allowed:** The bug was invisible on UTC hosts (where LOCAL==UTC and the comparison happened to be correct), and the tool emitted no signal that distinguished "no cron fires happened" from "we can't recognise the cron fires that did happen". The existing test suite used UTC-offset timestamps that always matched UTC-constants regardless of runner TZ, masking the bug class. No test asserted the LOCAL-vs-UTC directionality of `_is_cron_firing`.

**Prevention:** Three new regression tests pin the contract — (a) UTC 03:33 on TZ=+02 must be cron-firing; (b) UTC 05:33 on TZ=+02 must NOT be cron-firing; (c) `cron_window` output string must contain "LOCAL". The `enforce_utc_tz` autouse fixture pins the test runner TZ so the suite stays portable. A future test runner on a non-UTC host will see test (a) fail loudly if anyone tries to revert the fix.

## RCA-end

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

### 2026-05-20T10:23:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1953-g-064-gauge-timezone-fix--cronhourutc-mi.md
- **Context:** Initial task creation

### 2026-05-20T10:28:44Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-32e5bd8b
- **Timestamp:** 2026-06-02T15:00:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-21T09:06:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
