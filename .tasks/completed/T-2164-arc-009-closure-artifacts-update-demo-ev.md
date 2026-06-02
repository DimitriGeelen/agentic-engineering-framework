---
id: T-2164
name: "arc-009 closure artifacts: update demo evidence + arc description to reflect Slice 4 shipped"
description: >
  arc-009 closure artifacts: update demo evidence + arc description to reflect Slice 4 shipped

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:horizon-axis-hardening, docs]
components: [docs/reports/arc-009-demo-evidence.md, .context/arcs/horizon-axis-hardening.yaml]
related_tasks: [T-2159, T-2160, T-2161, T-2162, T-2163]
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-06-01T16:18:11Z
last_update: 2026-06-01T16:22:03Z
date_finished: 2026-06-01T16:22:03Z
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

# T-2164: arc-009 closure artifacts: update demo evidence + arc description to reflect Slice 4 shipped

## Context

arc-009 horizon-axis-hardening closed 4 slices in S-2026-0601-1249 successor
(see `project_arc009_loop_closed.md`). The closure artifacts (demo evidence
doc + arc YAML description) were captured mid-session when only 3 slices had
shipped — they then went stale when T-2163 (Slice 4 write-side prevention)
shipped under the same anchor. The human will hit `/arcs/horizon-axis-hardening/close`
after T-2160 [REVIEW] ticks and read these artifacts to decide closure.
Accuracy-of-closure-record is the deliverable.

## Acceptance Criteria

### Agent
- [x] `docs/reports/arc-009-demo-evidence.md` slice summary table includes a row for **T-2163 (Slice 4 — write-side prevention)** with status `completed` and a wire-level proof reference (the 4 bats green + `update-task.sh:1660` null-at-close write).
- [x] `docs/reports/arc-009-demo-evidence.md` "What didn't ship" section is removed (Slice 4 SHIPPED — not "filed candidate"). If the section is kept, it must contain no entries claiming Slice 4 is pending.
- [x] `docs/reports/arc-009-demo-evidence.md` header `**Slices shipped:**` line names all 4 slices (T-2160, T-2161, T-2162, T-2163) — currently names only first 3.
- [x] `.context/arcs/horizon-axis-hardening.yaml` `description:` is updated from "Three slices" wording to reflect the four-slice closure (Slice 4 = write-side prevention) — YAML still parses, no other fields touched.
- [x] No new build artifacts written; this is a documentation-accuracy task on two existing files only.

<!-- No Human ACs — both edits are deterministic doc-accuracy fixes verified by grep.
     Author-time routing default (T-1878): grep-able Expected → Agent AC + Verification,
     not [REVIEW]. No render surface touched (docs/reports/ and .context/arcs/ are
     not under web/templates|blueprints|static), so P-013 render-review skip is
     applied with rationale at close time.
-->

<!-- ORIGINAL HUMAN TEMPLATE (suppressed): kept commented for completeness.
### Human
Original template content:
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

grep -q "T-2163" docs/reports/arc-009-demo-evidence.md
grep -q "Slices shipped:.*T-2160.*T-2161.*T-2162.*T-2163" docs/reports/arc-009-demo-evidence.md
! grep -q "Slice 4 (write-side prevention):.*null horizon at close-time.*so that the migration is not needed" docs/reports/arc-009-demo-evidence.md
python3 -c "import yaml; d=yaml.safe_load(open('.context/arcs/horizon-axis-hardening.yaml')); assert 'Four slices' in d['description'] or 'four slices' in d['description'], 'description still says three slices'"
python3 -c "import yaml; yaml.safe_load(open('.context/arcs/horizon-axis-hardening.yaml'))"

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

### 2026-06-01 — closure-record-staleness as a recurrence class

- **What changed:** Realised that closure artifacts (`docs/reports/<arc>-demo-evidence.md` + arc YAML `description:`) are themselves subject to the same staleness class the arc-009 work was about — they were captured mid-session when only 3 slices had shipped, then went stale when T-2163 shipped under the same anchor. The doc and YAML were both filed *before* the arc was actually four-slice-shipped.
- **Plan impact:** The arc-009 close gate (`fw arc close` → `/arcs/.../close`) reads these artifacts; closure-record-staleness is therefore not cosmetic — it determines what the human reads when deciding closure. This task converts that from "doc cleanup" to "closure-readiness fix".
- **Triggered:** None yet — but the broader class (mid-arc closure artifacts going stale when more slices ship under the same anchor) might be worth a detector. Not filing as a follow-up because: (a) low instance count (this is the first observation), (b) the read-side rail for arcs already exists in §ACD/G-062 (`fw arc close` requires demo evidence + headline mechanic — but doesn't verify the demo matches what shipped). If a second instance lands, file a CTL detector then.

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

**Rationale:** Two doc-accuracy fixes on arc-009 closure artifacts so the human's
review at `/arcs/horizon-axis-hardening/close` reflects the four-slice closure
that actually shipped. Both files now state Slice 4 (T-2163, write-side prevention)
as done, the slice-summary table carries a row for it, and the "What didn't ship"
section is replaced by an explicit "Recurrence loop closed — both surfaces"
section that documents the write-side/read-side split and why each exists.

**Evidence:**
- `docs/reports/arc-009-demo-evidence.md` — header `**Slices shipped:**` now names T-2160/T-2161/T-2162/T-2163; slice-summary table has the Slice 4 row; "What didn't ship" replaced by "Recurrence loop closed — both surfaces"
- `.context/arcs/horizon-axis-hardening.yaml` — `description:` updated from "Three slices" to "Four slices" with the Slice 4 phrase; YAML still parses
- 5/5 verification commands PASS (AC1-AC4 + YAML parse)
- No render surface touched (docs/reports/, .context/arcs/ — outside web/) — P-013 skip applied at close

## Updates

### 2026-06-01T16:18:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2164-arc-009-closure-artifacts-update-demo-ev.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1e59ae87
- **Timestamp:** 2026-06-02T15:01:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-01T16:22:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
