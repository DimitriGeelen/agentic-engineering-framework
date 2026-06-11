---
id: T-2172
name: "BVP T-NEW-B: F-RECALL band 0-2 calibration — data-driven thresholds after ≥10
  confirmed scores"
description: >
  v3 schema (T-2166) ships F-RECALL with the rubric defined verbatim from T-2157 research,
  but the band 0-2 thresholds are best-guess and need calibration against actual confirmed
  scores. Gated on ≥10 human-confirmed F-RECALL scores in the corpus (current: 0 —
  fw bvp confirm hasn't run on any task yet). When the threshold lands, re-examine
  the rubric's level descriptions against the actual distribution and adjust if real-world
  signal shows a different shape.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [v3-followup-B, f-recall-calibration, arc:value-prioritisation, 
      data-driven]
components: []
related_tasks: [T-2166, T-2168, T-2170, T-2171]
arc_id: value-prioritisation
created: 2026-06-01T22:37:09Z
last_update: '2026-06-11T22:23:32Z'
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
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 3
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2172: BVP T-NEW-B: F-RECALL band 0-2 calibration — data-driven thresholds after ≥10 confirmed scores

## Context

T-2166 shipped F-RECALL with the rubric verbatim from `docs/reports/T-2157-value-drivers-v3-redesign.md`. Band 0 (no durable artifact), 1 (session-scoped capture), and 2 (lightly promoted, not retrievable) are descriptive but their thresholds were authored without corpus evidence — they're educated guesses about how real tasks distribute.

This task waits for ≥10 confirmed F-RECALL scores in the corpus (`bvp_scores.F-RECALL`), then:
1. Survey the distribution of confirmed scores across band 0/1/2.
2. Compare each confirmed score to the rubric description it should match.
3. If real-world signal shows a different shape (e.g., 80% of scores landing at 0, no scores at 1, 20% at 2), rewrite the level descriptions to match what humans actually rate.
4. Re-confirm with the operator before merging.

**Activation precondition** (mechanical gate): `python3 -c "import yaml,glob; n=sum(1 for f in glob.glob('.tasks/**/T-*.md', recursive=True) if 'F-RECALL' in (yaml.safe_load(open(f).read().split('---')[1]) or {}).get('bvp_scores',{})); print(n)"` returns ≥10.

## Acceptance Criteria

### Agent
- [ ] Confirmation count gate fires: at least 10 tasks in `.tasks/{active,completed}/` carry `bvp_scores.F-RECALL` (operator-confirmed via `fw bvp confirm`). Verification: see precondition command in Context; expect `>= 10`.
- [ ] Distribution report written to `docs/reports/T-2172-f-recall-calibration.md`: histogram of confirmed scores 0-5, count per band, optional task IDs per bucket.
- [ ] Per-bucket evidence walk: for each band 0/1/2, cite 2-3 confirmed tasks at that score, quote the rubric text, and assess fit (match / drift / ambiguous).
- [ ] If drift detected: propose revised rubric language for band 0/1/2 in the report, anchored to the cited tasks. If no drift: report concludes "current rubric matches corpus signal" and the build slice ends without a YAML change.
- [ ] If a YAML change is recommended: apply the change to `policy/value-drivers.yaml` F-RECALL `rubric:` block AND bump `version: 3` → `version: 4` in the policy file header (T-2166 versioning convention).
- [ ] No regression on the v3 smoke: `fw bvp` rc=0, `fw bvp --include-proposed` rc=0. Verification: `out=$(bin/fw bvp 2>&1); echo $?` == 0 (capture pattern per L-387).
- [ ] Update `[[project_value_drivers_v3_landed]]` memory pointer to record the calibration outcome (rubric unchanged OR re-anchored).

### Human
- [ ] [REVIEW] The proposed rubric language (if any) reads cleanly and matches how the operator actually scores in practice.
  **Steps:**
  1. Open `docs/reports/T-2172-f-recall-calibration.md`
  2. For each cited task, read the rubric quote alongside the operator's actual score
  3. If a revised rubric is proposed, sanity-check whether the new language would change *your* score on the cited tasks
  **Expected:** Revised rubric (if any) aligns better with operator intuition than the original.
  **If not:** Push back with specific cases; agent re-runs the calibration walk.

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

### 2026-06-01T22:37:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2172-bvp-t-new-b-f-recall-band-0-2-calibratio.md
- **Context:** Initial task creation
