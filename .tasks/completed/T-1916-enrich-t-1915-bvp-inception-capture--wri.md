---
id: T-1916
name: "Enrich T-1915 BVP inception capture — write docs/reports/T-1915-bvp-inception.md
  (risks/assumption-review/framings) + file 18 build slices under arc-006"
description: >
  Enrich T-1915 BVP inception capture — write docs/reports/T-1915-bvp-inception.md
  (risks/assumption-review/framings) + file 18 build slices under arc-006

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [docs/reports/T-1915-bvp-inception.md, .tasks/active/]
related_tasks: [T-1915, T-1846, T-1849, T-1668]
arc_id: value-prioritisation
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-19T06:41:19Z
last_update: '2026-06-11T22:24:03Z'
date_finished: 2026-05-19T07:07:04Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1916: Enrich T-1915 BVP inception capture — write docs/reports/T-1915-bvp-inception.md (risks/assumption-review/framings) + file 18 build slices under arc-006

## Context

T-1915 (BVP inception, decide-go via Watchtower) closed before its task body could be fully enriched. Critical re-audit identified 9 gaps (G1-G9) between the saved handoff and what landed in T-1915's task body. Since T-1915 is now `work-completed`, the enrichment is re-targeted:

- **G2 (risks), G7 (assumption-review schedule), G9 (framings)** → consolidate into `docs/reports/T-1915-bvp-inception.md` (a frozen research artefact that future build agents inherit without re-deriving from the handoff)
- **G1 (components), G3 (sub-task splits), G4 (mechanics), G5 (cross-slice deps), G6 (full CLI surface), G8 (workflow_type)** → land per-slice in each of the 17 build tasks (T-NEW-2..15 with splits 7a/7b, 12a/12b, 14a/14b) as they're filed

Source: `.context/handoffs/HANDOFF-value-prioritisation-2026-05-15.md`

## Acceptance Criteria

### Agent
- [x] `docs/reports/T-1915-bvp-inception.md` exists, covers §1 decision-recap, §2 risks register R1-R9, §3 assumption-review schedule A1-A6, §4 framings F4-deep/D7-reframe/D8/F8-mechanic/Geelen/reversibility, §5 cross-slice dependency graph, §6 build-slice manifest, §7 specific mechanics M1-M7
- [x] 17 build tasks filed under arc-006 (`arc_id: value-prioritisation`), each with real ACs (no placeholders), full components list, and explicit dependencies in body
- [x] Each filed build task references the corresponding T-NEW-N slice from the handoff
- [x] `bin/fw arc show value-prioritisation` reports 19 tasks (T-1915 anchor + T-1916 enrichment + 17 build slices) — note: 19 not 18, T-1916 itself counts in the arc once tagged with arc_id
- [x] Final commit ties the enrichment artefact + all build-slice files under one logical change

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

test -f docs/reports/T-1915-bvp-inception.md
# Build-slice count: arc-006 should hold T-1915 + T-1916 + 17 build slices = 19 tasks once everything is filed.
# (Initial filing count is 18; T-1916 itself is added by the time this gate fires.)
out=$(bin/fw arc show value-prioritisation 2>&1); echo "$out" | grep -q "T-1915"
# Each build slice has real ACs (no unfilled "- [ ] [First criterion]" template AC remaining in arc-006 build slices)
# Anchored on the actual AC line — string occurrences inside Verification blocks or comments don't count.
out=$(grep -l "^- \[ \] \[First criterion\]" .tasks/active/T-19[0-9][0-9]-*.md 2>/dev/null | xargs -r grep -l "^arc_id: value-prioritisation" 2>/dev/null); test -z "$out"

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

### 2026-05-19 — Filing & verification regex
- **What changed:** Original Verification command (`! grep -l "\[First criterion\]" .tasks/active/T-19[0-9][0-9]-* | xargs grep -l "arc_id: value-prioritisation"`) was self-referential — it matched T-1916 itself because the Verification line and Recommendation evidence quoted the placeholder string literally. Discovered at first work-completed attempt: gate failed pointing at T-1916.
- **Plan impact:** Verification must anchor on the actual unfilled-AC line shape (`^- [ ] [First criterion]`), not the string anywhere in the file. String references in commentary/evidence are legitimate and shouldn't trip the gate.
- **Triggered:** in-task fix only — verification command rewritten to `grep -l "^- \[ \] \[First criterion\]" ... | xargs -r grep -l "^arc_id: value-prioritisation" ...; test -z "$out"`. No external pivot. Self-referential verification is a class to watch for in any "no unfilled placeholders" check that lives inside the task body it audits.

### 2026-05-19 — T-1915 auto-close discovery
- **What changed:** Started this task expecting to enrich T-1915 in-place; mid-filing discovered T-1915 had transitioned to `work-completed` via a `--skip-sovereignty` bypass that looked like an §ACD violation. User clarified it was a Watchtower POST (the legitimate `--from-watchtower` exemption from T-1259/T-1260). Bypass log doesn't distinguish "Watchtower POST" from "agent bypass" at that surface.
- **Plan impact:** Re-targeted enrichment from T-1915's body to `docs/reports/T-1915-bvp-inception.md` (frozen artefact) + per-slice build task bodies. Closed task body can't be edited anyway.
- **Triggered:** Filed observation worth-considering — bypass log entries for Watchtower POSTs are indistinguishable from genuine bypasses, future agent could mis-alarm. Not a separate task yet; if it recurs, would land as a bypass-log enrichment task (annotate POST source).

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

## Recommendation

**Recommendation:** GO

**Rationale:** Pure scaffolding work — wrote one research artefact + 17 build-task files. No source code changed. All ACs satisfied: artefact covers §1–§7 per spec; 17 build slices filed under arc-006 with full ACs (no placeholders), explicit dependencies, M1–M7 mechanics distributed across the right slices, R1–R9 risks cited where mitigations land, and Q1–Q4 defaults surfaced in the slices that consume them. The arc-006 transition gate (draft → in-progress) deliberately blocks on T-1926 shipping; that's the documented circular-by-design dependency.

**Evidence:**
- `docs/reports/T-1915-bvp-inception.md` exists, ~470 lines covering all 7 sections
- `bin/fw arc show value-prioritisation` → 19 tasks (T-1915 + T-1916 + 17 build slices)
- No placeholder `[First criterion]` remains in any arc-006 task (verified per Verification command)
- Each T-NEW-N slice from handoff §7 mapped 1:1 to a T-1917..T-1933 task (with splits 7→7a/7b, 12→12a/12b, 14→14a/14b)

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

### 2026-05-19T06:41:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1916-enrich-t-1915-bvp-inception-capture--wri.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7d2294ab
- **Timestamp:** 2026-06-02T15:00:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-19T07:07:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
