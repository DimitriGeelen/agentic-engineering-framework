---
id: T-2698
name: "config registry drift: 2 keys missing from Watchtower /config, 17 from the
  CLAUDE.md table"
description: >
  tests/lint/config-registry-parity.bats (red, unrun until T-2697): lib/config.sh
  defines 22 keys, web/blueprints/config.py 20. ARC_COMPLETION_THRESHOLD and DISPATCH_MODEL_DEFAULT
  are invisible in Watchtower /config. Separately, 17 keys are absent from the CLAUDE.md
  Configuration table — decide whether that table is meant to be exhaustive (test's
  assumption) or curated (CLAUDE.md says 'full reference: fw config list'), then make
  the test assert whichever is true.

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
created: 2026-07-31T09:21:11Z
last_update: 2026-10-20T23:47:07Z
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
  - ts: '2026-07-31T09:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 6
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=6 (lines=145,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-20T22:00:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=179,acs=5)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T09:30:12Z'
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

# T-2698: config registry drift: 2 keys missing from Watchtower /config, 17 from the CLAUDE.md table

## Context

Re-checked 2026-10-20 at HEAD c332f5b8d: the defect no longer reproduces. Both
halves were fixed by later tasks; no code change made under this task.

    $ bats tests/lint/config-registry-parity.bats
    ok 1 lib/config.sh and web/blueprints/config.py have the same config keys
    ok 2 CLAUDE.md references no config key that lib/config.sh does not define
    ok 3 config registry key count matches across sources

- Watchtower half: `web/blueprints/config.py:52-53` carry both keys — T-2838 (8b41090b4).
- CLAUDE.md half: decided "curated" — CLAUDE.md §Configuration (T-2841 paragraph)
  and the test inverted to "no phantom FW_ keys" — T-2841 (2c1b25466).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] ARC_COMPLETION_THRESHOLD and DISPATCH_MODEL_DEFAULT are present in web/blueprints/config.py SETTINGS (Watchtower /config) — fixed upstream by T-2838 (8b41090b4)
- [x] The CLAUDE.md question is decided and the test asserts it: table is curated (CLAUDE.md §Configuration, T-2841 paragraph), test asserts only "CLAUDE.md names no FW_ key the registry lacks" — fixed upstream by T-2841 (2c1b25466)
- [x] APPROVAL_PENDING_WARN_HOURS (added to lib/config.sh by T-3079, 0688ba4f1, without a Watchtower row) is present in web/blueprints/config.py SETTINGS
- [x] tests/lint/config-registry-parity.bats is green at HEAD (re-run 2026-10-21: it was red again, 67 vs 66 keys)
- [x] Vendored copy in sync: `bin/fw vendor self --check --task T-2698` clean

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
bats tests/lint/config-registry-parity.bats
grep -q '"ARC_COMPLETION_THRESHOLD"' web/blueprints/config.py
grep -q '"DISPATCH_MODEL_DEFAULT"' web/blueprints/config.py
grep -q '"APPROVAL_PENDING_WARN_HOURS"' web/blueprints/config.py
bin/fw vendor self --check --task T-2698

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

**Symptom:** tests/lint/config-registry-parity.bats red: 2 registry keys
(ARC_COMPLETION_THRESHOLD, DISPATCH_MODEL_DEFAULT) absent from Watchtower /config,
17 keys absent from the CLAUDE.md table.

**Root cause:** two separate gaps. (1) `lib/config.sh:291-292` gained keys without
the mirror `SETTINGS` list in `web/blueprints/config.py` being updated — two
hand-maintained copies of one registry. (2) The test required CLAUDE.md to list
every key, contradicting CLAUDE.md's own "curated subset" statement.

**Why structurally allowed:** the lint suite was not run by any gate until T-2697,
so the red test sat unseen.

**Prevention (already in place, verified at HEAD):** T-2838 (8b41090b4) added the
keys; test 1 of the parity bats fails on any future config.sh↔config.py drift.
T-2841 (2c1b25466) made the CLAUDE.md test assert the true direction (no phantom
keys) and wrote the curated-subset rationale into CLAUDE.md.

**Recurrence, 2026-10-21 (close-gate re-run):** the parity bats went red again —
`lib/config.sh:365` `APPROVAL_PENDING_WARN_HOURS` (T-3079, 0688ba4f1) shipped with no
row in `web/blueprints/config.py` SETTINGS. Same root cause as (1): two hand-maintained
copies. Why it slipped: the parity bats lives under `tests/lint/` and T-3079's own
Verification ran only its t3079 bats; nothing at T-3079's close ran the lint. Fix: add
the row after TIER0_APPROVAL_TTL (its sibling). Prevention: the existing parity test
(test 1 + test 3) is the detector and caught it here; the structural gap — a registry
edit's close not running the lint — is the same as T-2697's and stays covered by the
lint suite in the nightly/pre-push path.

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

### 2026-07-31T09:21:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2698-config-registry-drift-2-keys-missing-fro.md
- **Context:** Initial task creation

### 2026-10-20T21:52:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
