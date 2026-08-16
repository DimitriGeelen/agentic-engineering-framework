---
id: T-2246
name: "file BVP driver prompt bundle (Path B, T-2245 implementation)"
description: >
  Author 8 files under policy/prompts/ derived from T-2245 / INGESTION-bvp-driver-prompt-bundle-2026-06-06.md
  §6. Operator-authorized Path B 2026-06-08.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-07T23:37:46Z
last_update: '2026-08-16T22:24:58Z'
date_finished: 2026-06-07T23:52:15Z
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
  - ts: '2026-06-07T23:37:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 3
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=3 
      (body:prompt-meaningful); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 3
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=3 
      (body:prompt-meaningful); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-07T23:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2246: file BVP driver prompt bundle (Path B, T-2245 implementation)

## Context

T-2245 ingestion task captured `INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` at `docs/reports/`. Operator selected **Path B** 2026-06-08 in direct response to surfaced A/B/C options: agent authors the 8 bundle files from §6 design specs rather than holding for upstream paste (Path A) or holding entirely (Path C).

Per T-2245's pickup doc §1, bundle structure is:

```
policy/prompts/
├── README.md                                  (~120 lines)
├── bvp-driver-session.md                       (~260 lines — the prompt loaded by both verbs)
├── artefact-template.md                        (~200 lines)
└── bvp-references/
    ├── sharpening-subroutine.md                (~180 lines)
    ├── global-driver-examples.md               (~150 lines)
    ├── arc-scoped-driver-examples.md           (~220 lines)
    ├── discipline-failure-modes.md             (~180 lines)
    └── sharpening-tactics.md                   (~180 lines)
```

Per CLAUDE.md inception-discipline: T-2245 is the parent inception, this task is the implementation. Bundle is text/docs only — no executable code. CLI verbs (`fw bvp driver suggest|create|recompute|init`) remain operator-only per pickup §7 step 5 (separate inception scope).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] All 8 bundle files exist at `policy/prompts/` per §1 structure with non-trivial content derived from T-2245 §6 design dialogue + decisions ledger.
- [x] `policy/prompts/bvp-driver-session.md` carries the three workflows (A=batch-propose, B=discover+sharpen, C=sharpen named topic) and the sharpening subroutine (R1+R2 required, O1-O4 optional with skip-when-stuck), per §6.4.5 decision and §6.4.9 v2 build.
- [x] `policy/prompts/artefact-template.md` references §6 of `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` as the canonical worked example (per §6.4.12 D5 + §7 step 4).
- [x] Cross-references valid: `README.md` links to `bvp-driver-session.md`; `bvp-driver-session.md` links to `bvp-references/*` files; `artefact-template.md` references §6 of the ingestion doc.
- [x] [REVIEWER] Reviewer PASS — verified via `bin/fw reviewer T-2246`.

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

# 8 expected files exist
test -f policy/prompts/README.md
test -f policy/prompts/bvp-driver-session.md
test -f policy/prompts/artefact-template.md
test -f policy/prompts/bvp-references/sharpening-subroutine.md
test -f policy/prompts/bvp-references/global-driver-examples.md
test -f policy/prompts/bvp-references/arc-scoped-driver-examples.md
test -f policy/prompts/bvp-references/discipline-failure-modes.md
test -f policy/prompts/bvp-references/sharpening-tactics.md

# bvp-driver-session.md carries the three workflows + sharpening subroutine
grep -q "Workflow A" policy/prompts/bvp-driver-session.md
grep -q "Workflow B" policy/prompts/bvp-driver-session.md
grep -q "Workflow C" policy/prompts/bvp-driver-session.md
grep -q "R1" policy/prompts/bvp-driver-session.md
grep -q "R2" policy/prompts/bvp-driver-session.md

# artefact-template references §6 of ingestion doc (per §7 step 4 cross-ref discipline)
grep -q "INGESTION-bvp-driver-prompt-bundle-2026-06-06" policy/prompts/artefact-template.md

# Cross-references valid
grep -q "bvp-driver-session.md" policy/prompts/README.md
grep -q "bvp-references" policy/prompts/bvp-driver-session.md

# Reviewer PASS (L-387 safe — small output)
out=$(bin/fw reviewer T-2246 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

## Recommendation

**Recommendation:** GO

**Rationale:** All 8 bundle files authored under `policy/prompts/` (1499 lines total — within 1% of §1's ~1490 line estimate). Content derived from T-2245's `INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §6 design dialogue, decisions ledger, and rejected paths. Three workflows + sharpening subroutine + R1/R2/O1-O4 structure encoded per §6.4.5 and §6.4.9 v2 build description. Cross-references valid (verified in Verification block). Artefact template references §6 of the ingestion doc as canonical worked example per §7 step 4. Bundle is text-only documentation; no executable surface created; reversible (`git rm -r policy/prompts/`). G-020 satisfied by parent inception T-2245 (operator-authorized Path B 2026-06-08).

**Out of scope (operator-only, per pickup §7 step 5 + §8):**
- CLI verbs (`fw bvp driver suggest|create|recompute|init`) — separate inception
- HANDOFF-value-prioritisation-2026-05-15 v2 revision — operator action
- Operational testing (the bundle becomes operationally useful only when CLI verbs land)

**Evidence:**
- 8 files at `policy/prompts/` per §1 structure (`ls policy/prompts/ policy/prompts/bvp-references/`)
- 1499 total lines (`wc -l policy/prompts/*.md policy/prompts/bvp-references/*.md`)
- bvp-driver-session.md contains "Workflow A", "Workflow B", "Workflow C", "R1", "R2" (grep)
- artefact-template.md references "INGESTION-bvp-driver-prompt-bundle-2026-06-06" (grep)
- README.md links to bvp-driver-session.md (grep)
- bvp-driver-session.md links to bvp-references (grep)

**Follow-on tasks unblocked by this:**
- Operator can now run `fw task review T-2245` → Sovereign GO decision on T-2245 (the parent inception consummates with this filing)
- Operator can file the CLI verb build inception when ready (still §7 step 5 operator-only)

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

### 2026-06-07T23:37:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2246-file-bvp-driver-prompt-bundle-path-b-t-2.md
- **Context:** Initial task creation

### 2026-06-07T23:37:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0388ec20
- **Timestamp:** 2026-06-07T23:52:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-07T23:52:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
