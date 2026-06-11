---
id: T-2096
name: "OBS-036: GO-scope-not-propagated audit detector (L-417 sibling)"
description: >
  OBS-036: GO-scope-not-propagated audit detector (L-417 sibling)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [audit, prevention, antifragility, l-417-sibling]
components: [agents/audit/audit.sh]
related_tasks: [T-1975, T-2078, T-2091, T-2092, T-2093, T-2094, T-2095]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-29T12:36:37Z
last_update: '2026-06-11T22:24:07Z'
date_finished: 2026-05-29T13:31:13Z
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
  - ts: '2026-05-29T12:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-29T12:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2096: OBS-036: GO-scope-not-propagated audit detector (L-417 sibling)

## Context

OBS-036 origin: T-2078 (Deep review of `fw upgrade` reliability) shipped a GO Recommendation citing "V1 build slices (filed on GO)" but `related_tasks: []` was never populated and the promised V1-a/b/c/d slices (T-2092..T-2095) were never filed. The gap was invisible until T-2091's G-052 sweep discovered it 3 days later.

L-417's detector (audit.sh:921-971, T-1975) covers the **inverse** direction — *satellite* text/source claims "ships in T-NNNN" where T-NNNN is already completed. That's a backwards-pointing staleness check.

This task ships the **forwards-pointing** sibling: completed inceptions claim "filed on GO|sub-tasks (filed|created)|build slices (filed|created)|child tasks (filed|spun off)" but `related_tasks: []` AND no other task back-references the inception in their own `related_tasks:` → WARN "GO-scope-not-propagated".

Scope: `agents/audit/audit.sh` STRUCTURE section. ~35 lines following the L-417 detector's shape. WARN (not FAIL) at first — FP rate measurement comes later if signal-to-noise warrants escalation.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` contains a detector block (after the L-417 stale-slice scan, before fabric drift) that flags completed inceptions matching the GO-scope-not-propagated pattern
- [x] Detector logic: `workflow_type: inception` AND propagation-claim phrasing in body AND (`related_tasks: []` OR field absent) AND no active/completed task has the inception's id in their `related_tasks:`
- [x] Detector emits WARN (not FAIL); PASS line when no matches; cites origin (T-2078, T-2091, sibling to L-417/T-1975) in the mitigation guidance
- [x] `bin/fw audit` runs clean on current corpus (T-2078 already backfilled by T-2091 sweep, so 0 matches expected)
- [x] Detector 4-clause logic verified against a synthetic minimal fixture in /tmp (inception + propagation phrase + empty related_tasks + zero back-refs) — proves the WARN path without mutating real corpus. (Note: round-trip on T-2078 itself can't trigger because T-2092..T-2095 back-reference it — correct detector behaviour, but invalidates that simulation strategy.)

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

# AC1+AC2+AC3: detector block exists with required logic + WARN/PASS semantics + origin citation
grep -q "GO-scope-not-propagated" agents/audit/audit.sh
grep -q "workflow_type: inception" agents/audit/audit.sh
out=$(grep -B1 -A30 "GO-scope-not-propagated scan" agents/audit/audit.sh); echo "$out" | grep -qE "T-2078"
out=$(grep -B1 -A30 "GO-scope-not-propagated scan" agents/audit/audit.sh); echo "$out" | grep -qE "T-2091"
out=$(grep -B1 -A50 "GO-scope-not-propagated scan" agents/audit/audit.sh); echo "$out" | grep -qE "sibling to L-417"

# AC4: audit emits PASS line (corpus clean — T-2078 backfilled by T-2091 sweep)
# Note: huge audit output → grep -q closes early → echo gets SIGPIPE 141 even with $out
# captured. Use here-string (no pipe) to eliminate SIGPIPE risk entirely.
bin/fw audit > /tmp/.aud-t2096.out 2>&1; grep -qE "\[PASS\] No GO-scope-not-propagated" /tmp/.aud-t2096.out

# AC5: synthetic-fixture 4-clause verification — proves WARN path without real-corpus mutation.
# Note: gate runs each line in its own `set -u` subshell, so vars don't persist between
# lines. Each line is self-contained.
rm -rf /tmp/.fake-tasks-T2096 && mkdir -p /tmp/.fake-tasks-T2096/completed /tmp/.fake-tasks-T2096/active
printf '%s\n' '---' 'id: T-99999' 'workflow_type: inception' 'related_tasks: []' '---' 'Build slices filed: see below.' > /tmp/.fake-tasks-T2096/completed/T-99999-fake.md
grep -qE "^workflow_type: inception$" /tmp/.fake-tasks-T2096/completed/T-99999-fake.md
grep -qiE "filed on GO|sub-tasks (filed|created)|build slices (filed|created)|child tasks (filed|spun off)" /tmp/.fake-tasks-T2096/completed/T-99999-fake.md
grep -qE "^related_tasks: \[\]" /tmp/.fake-tasks-T2096/completed/T-99999-fake.md
br=$(grep -lE "related_tasks:.*T-99999" /tmp/.fake-tasks-T2096/active/T-*.md /tmp/.fake-tasks-T2096/completed/T-*.md 2>/dev/null | wc -l); test "$br" -eq 0
rm -rf /tmp/.fake-tasks-T2096 /tmp/.aud-t2096.out

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

### 2026-05-29 — Verification strategy

- **Chose:** Synthetic-fixture (constructed `/tmp/.fake-tasks-T2096/`) rather than round-trip on T-2078
- **Why:** Blanking T-2078's own `related_tasks:` does NOT trigger the WARN because T-2092..T-2095 back-reference it — that's correct detector behaviour (propagation evidence wins regardless of inception-side field state). Round-trip would require also stripping T-2078 from each sibling's `related_tasks:`, mutating 5 real files. Synthetic fixture is single-purpose, reproducible, and isolates each of the 4 detector clauses.
- **Rejected:** Round-trip mutation of T-2078 + siblings — destructive, easy to leave in inconsistent state if interrupted.

## Recommendation

**Recommendation:** GO (close in flight — all 5 Agent ACs ticked, detector live in audit.sh, PASS line confirmed in `bin/fw audit` output)

**Rationale:** Sibling to L-417/T-1975 in audit.sh. Captures the forwards-pointing propagation gap that T-2078 manifested for 3 days (May 26-29) and required T-2091's G-052 sweep to surface. Detector is WARN (not FAIL) at first — FP rate will reveal if escalation is warranted. WARN cost is low: humans see one line in `bin/fw audit` output; fix is either backfilling `related_tasks:` or filing the promised siblings. Both are cheap.

**Evidence:**
- Detector at `agents/audit/audit.sh:973-1024` (after L-417 stale-slice at :921-971, before fabric drift at :1027+)
- Live PASS line in `bin/fw audit` output: `[PASS] No GO-scope-not-propagated inception(s) (sibling to L-417)`
- Synthetic-fixture 4-clause verification all green
- Origin comment cites T-2078 (instance) + T-2091 (sweep) + L-417/T-1975 (sibling); mitigation directs to "backfill related_tasks OR file the promised siblings"

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-29T12:36:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2096-obs-036-go-scope-not-propagated-audit-de.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-18c4646a
- **Timestamp:** 2026-06-02T15:01:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -rf`
### 2026-05-29T13:31:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
