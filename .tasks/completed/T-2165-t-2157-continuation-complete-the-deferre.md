---
id: T-2165
name: "T-2157 continuation: complete the deferred consumer-code blast radius walk + open questions 1-10 for value-drivers.yaml v3"
description: >
  T-2157 continuation: complete the deferred consumer-code blast radius walk + open questions 1-10 for value-drivers.yaml v3

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:value-prioritisation, value-drivers, bvp, research]
components: [docs/reports/T-2157-value-drivers-v3-redesign.md, policy/value-drivers.yaml, lib/bvp.sh, web/blueprints/bvp.py, web/blueprints/arcs.py, lib/arc.sh, policy/bvp-scoring-rubric.md]
related_tasks: [T-2157, T-1915, T-1921, T-1922, T-1924, T-1926, T-1928, T-1929, T-1930, T-1931, T-1932]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T16:48:09Z
last_update: 2026-06-01T16:59:54Z
date_finished: 2026-06-01T16:59:54Z
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

# T-2165: T-2157 continuation: complete the deferred consumer-code blast radius walk + open questions 1-10 for value-drivers.yaml v3

## Context

T-2157 inception ("value-drivers.yaml v3 redesign") was filed with Recommendation: DEFER pending an evidence walk. The human ran `fw inception decide T-2157 go` (Decision: GO recorded 2026-06-01T09:51:22Z), but the deferred research — consumer-code blast radius (5 readers × 6 questions) + open questions 1-10 + semantic critique vs. CLAUDE.md "new meaning" bar — was NEVER conducted. The artifact `docs/reports/T-2157-value-drivers-v3-redesign.md` still has 8 of 10 "Next steps" unchecked.

This task closes that gap: complete the evidence walk inside the existing research artifact, then flip its Recommendation from DEFER to GO / NO-GO / GO-with-refinements based on findings. Build of the v3 migration itself (consumer-code changes, schema rename, migration logic) is **out of scope** — a separate task is filed after this one lands.

**Scope fence:** This task ONLY updates `docs/reports/T-2157-value-drivers-v3-redesign.md`. It does NOT edit `policy/value-drivers.yaml`, `lib/bvp.sh`, `web/blueprints/bvp.py`, `web/blueprints/arcs.py`, or `lib/arc.sh` — those reads are research input, not edit targets.

## Acceptance Criteria

### Agent
- [x] `docs/reports/T-2157-value-drivers-v3-redesign.md` "Consumer-code blast radius walk" section is no longer marked DEFERRED — concrete findings replace the placeholder. Each of the 5 readers (`lib/bvp.sh`, `lib/bvp.sh auto-promote`, `lib/arc.sh approve-driver`, `web/blueprints/bvp.py`, `web/blueprints/arcs.py`) has a Q1-Q6 walk with file:line evidence (or "not present in this reader" with grep-rationale).
- [x] Each of the 10 open questions has a concrete answer recorded in the artifact, with evidence cited (file path / line / `T-XXXX` reference). "Defer to build phase" is allowed for Q4/Q6/Q8 type tooling-additions, but the question must explain why.
- [x] Semantic critique sections (F-RECALL, F-ORCH, F-AUTONOMY) are revisited and finalised — each driver gets a single line: "**Verdict:** keep / refine / drop" with one-paragraph rationale grounded in the CLAUDE.md "new meaning, not louder D1-D4" criterion and the consumer-code walk findings.
- [x] The artifact's "Next steps" checklist (lines ~338-352) has items 2-9 ticked `[x]` matching what landed in this pass.
- [x] The artifact's final `## Recommendation` block (line ~353) flips from `DEFER` to one of: `GO`, `NO-GO`, `GO with refinements`. Evidence section lists the concrete findings that justify the flip.
- [x] If `GO` or `GO with refinements`, follow-up build tasks are pre-scoped (T-NEW-A estimator extension, T-NEW-B band 0-2 calibration, T-NEW-C retire_when audit, T-NEW-D per-driver display, T-NEW-E F-AUTONOMY activation gate) in the artifact's Refinements table. Filing the v3 schema-rename build task itself is left to operator review — the artifact recommends it but doesn't pre-file the implementation slice.
- [x] Five-condition self-check before close: artifact is up-to-date (no DEFERRED markers in body), all reader walks have file:line citations, all 10 open questions answered, semantic verdicts present, Recommendation flipped.

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

! grep -q "DEFERRED — to be filled before GO recommendation" docs/reports/T-2157-value-drivers-v3-redesign.md
grep -q "^**Recommendation:** \(GO\|NO-GO\|GO with refinements\)" docs/reports/T-2157-value-drivers-v3-redesign.md || grep -qE "^\*\*Recommendation:\*\* (GO|NO-GO|GO with refinements)" docs/reports/T-2157-value-drivers-v3-redesign.md
grep -c "^### F-\(RECALL\|ORCH\|AUTONOMY\)" docs/reports/T-2157-value-drivers-v3-redesign.md | grep -q "^3$"
grep -q "Verdict:" docs/reports/T-2157-value-drivers-v3-redesign.md
n=$(awk 'BEGIN{p=0} /^## Open Questions/{p=1; next} p && /^## /{p=0} p' docs/reports/T-2157-value-drivers-v3-redesign.md | grep -cE "^[0-9]+\. \*\*"); test "$n" -ge 10

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

### 2026-06-01 — DEFER-as-hedge averted by evidence walk

- **What changed:** Going into the walk, the artifact had three "Provisional verdicts" framed as "probably earns its slot, subject to revisit" — exactly the confidence-calibration hedge T-2144 warns about (rationale present but not committed). The consumer-code walk produced concrete file:line evidence that flipped each provisional verdict into a committed verdict (KEEP / KEEP / KEEP CARVED) with named follow-up slices instead of vague "calibrate later".
- **Plan impact:** The proposal's "Three slices" framing (rename + new fields + free drivers) collapses to ONE slice. Pre-walk sizing estimated 10-20 LoC with possible transition support; post-walk it's ~5 LoC YAML edit, zero consumer code, no transition support. The save: avoided over-scoping the v3 build into a multi-slice migration when it's a hard rename. T-2144 application: DEFER was right at filing-time (evidence genuinely absent); GO is right now (evidence present and walked).
- **Triggered:** Five follow-up slices pre-scoped in the artifact's Refinements table (T-NEW-A through T-NEW-E). None filed yet — operator review of this artifact decides which to file and at what horizon. The v3 schema-rename build task itself is also operator's call; this task does not pre-file it.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Continuation task completed the deferred T-2157 research. The updated artifact at `docs/reports/T-2157-value-drivers-v3-redesign.md` now contains: (a) concrete 5-reader × 6-question walk with file:line citations, (b) three KEEP verdicts on F-RECALL/F-ORCH/F-AUTONOMY-carved, (c) all 10 open questions resolved (5 RESOLVED, 4 named follow-up slices, 1 cosmetic to-human), (d) Recommendation flipped DEFER → **GO with refinements**. Operator's review of the artifact decides which follow-up slices (T-NEW-A..E) to file and at what horizon, and whether to file the v3 schema-rename build task directly.

**Evidence:**
- Walk findings: `/tmp/fw-agent-T-2165-walk.md` (Explore agent, read-only)
- Artifact update: `docs/reports/T-2157-value-drivers-v3-redesign.md` (+~150 LoC: new walk section, 3 verdict lines, 10 Q resolutions, new Recommendation block with refinements table)
- Zero silent-regression sites; v3 ships in one hard-rename slice (~5 LoC YAML)
- 5/5 verification commands PASS (no DEFERRED placeholder, Recommendation flipped, 3 driver sections, Verdict markers, ≥10 questions)
- No `policy/value-drivers.yaml` or consumer code touched — scope fence held

## Updates

### 2026-06-01T16:48:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2165-t-2157-continuation-complete-the-deferre.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-19c7def8
- **Timestamp:** 2026-06-01T16:59:56Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `docs/reports/T-2157-value-drivers-v3-redesign.md` "Consumer-code blast radius walk" section is no longer marked DEFERRED — concrete findings replace the placeholder. Each of the 5 readers (`lib/bvp.s
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/bvp.sh in: `docs/reports/T-2157-value-drivers-v3-redesign.md` "Consumer-code blast radius walk" section is no longer marked DEFERRED — concrete findings replace `

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `grep -q "^**Recommendation:** \(GO\|NO-GO\|GO with refinements\)" docs/reports/T-2157-value-drivers-v3-redesign.md || grep -qE "^\*\*Recommendation:\*\* (GO|NO-GO|GO with refinements)" docs/reports/T-`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `grep -c "^### F-\(RECALL\|ORCH\|AUTONOMY\)" docs/reports/T-2157-value-drivers-v3-redesign.md | grep -q "^3$"`

### 2026-06-01T16:59:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
