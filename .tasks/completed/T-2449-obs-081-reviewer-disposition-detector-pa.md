---
id: T-2449
name: "OBS-081: reviewer disposition detector parses Open-Questions template comment
  as real IW entry"
description: >
  OBS-081: reviewer disposition detector parses Open-Questions template comment as
  real IW entry

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/reviewer/static_scan.py]
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
created: 2026-06-21T11:40:31Z
last_update: '2026-08-16T22:25:06Z'
date_finished: 2026-06-21T11:44:07Z
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
  - ts: '2026-08-16T22:25:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2449: OBS-081: reviewer disposition detector parses Open-Questions template comment as real IW entry

## Context

`detect_disposition_completeness` (lib/reviewer/static_scan.py:1533) read the `## Open Questions`
section via `extract_section` **without stripping HTML comments**, so the IW-1 example shipped in the
`.tasks/templates/inception.md` template comment (`<!-- … - **IW-1: <question text>** … rationale:
<one-line evidence…> -->`) was sliced as a *real* entry and failed the answered-without-citation check
→ spurious `disposition-incomplete` CONCERN. Discovered live on T-2447: the inception had a properly
cited IW-1 yet the reviewer still flagged it; removing the redundant template comment cleared it
(filed as OBS-081). Sibling-parity gap: the AC parser already strips comments via the same
`_strip_html_comments` helper (L-414); the disposition detector simply never called it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — `detect_disposition_completeness` strips `<!-- … -->` from the Open Questions section
      (via the existing `_strip_html_comments` helper) before slicing IW-N entries, so template
      placeholders are never parsed as real entries.
- [x] AC2 — regression tests reproduce the OBS-081 shape: a template-comment IW-1 example (comment-only,
      and comment + real valid entry) produce **zero** findings. `reviewer_disposition_incomplete.bats`
      stays green (11/11, incl. the 2 new tests).

## Verification

out=$(bats tests/unit/reviewer_disposition_incomplete.bats 2>&1); echo "$out" | grep -qE "^ok 11 " && ! echo "$out" | grep -q "^not ok"
python3 -c "import ast; ast.parse(open('lib/reviewer/static_scan.py').read())"
grep -q "_strip_html_comments(oq_section)" lib/reviewer/static_scan.py


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

**Symptom:** `fw reviewer` emitted a `disposition-incomplete` CONCERN on T-2447 even though its IW-1
entry carried a proper evidence citation. The CONCERN cleared only when the redundant Open-Questions
template comment was deleted from the task file.

**Root cause:** `detect_disposition_completeness` sliced IW-N entries straight out of
`extract_section(body, "Open Questions")`, which returns the section text **including** the
`<!-- … -->` template comment. The inception template (`.tasks/templates/inception.md:44-47`) ships a
documentation example `- **IW-1: <question text>** … disposition: answered … rationale: <one-line
evidence — file:line…>`. The slicer's `^\s*-\s*\*\*IW-(\d+):` regex matched that placeholder, parsed it
as a real entry, and the placeholder's non-citing rationale failed check D (answered → citation) →
false-positive finding on a phantom entry.

**Why structurally allowed:** the AC parser hit this exact class first (L-414) and was fixed by stripping
comments via `_strip_html_comments` before parsing. The disposition detector (T-2191, added later) read
the same template-bearing body shape but never adopted the helper — a sibling-parity gap. No test
exercised a comment-bearing Open-Questions section, so the gap stayed silent until a real inception
(T-2447) carried both a real entry and the leftover template comment.

**Prevention:** (1) the detector now calls `_strip_html_comments(oq_section)` — the same helper the AC
parser uses, so the two stay in lockstep. (2) Two regression tests in
`reviewer_disposition_incomplete.bats` pin the comment-only and comment+real-entry cases at zero
findings, so any future refactor that drops the strip re-fails immediately.

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

### 2026-06-21T11:40:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2449-obs-081-reviewer-disposition-detector-pa.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9446d702
- **Timestamp:** 2026-06-21T11:44:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-21T11:44:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
