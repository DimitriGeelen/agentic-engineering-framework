---
id: T-2672
name: "healing resolve.sh: append breaks on column-0 YAML + max-id scan misses unindented ids (832 field T-295)"
description: >
  healing resolve.sh: append breaks on column-0 YAML + max-id scan misses unindented ids (832 field T-295)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/healing/lib/resolve.sh]
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
created: 2026-07-29T06:20:16Z
last_update: 2026-07-29T06:27:22Z
date_finished: 2026-07-29T06:27:22Z
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

# T-2672: healing resolve.sh: append breaks on column-0 YAML + max-id scan misses unindented ids (832 field T-295)

## Context

832 field report (rail 306, their T-295, third instance of the vendor-boundary
regression class L-213/L-214): `agents/healing/lib/resolve.sh` as vendored breaks
on consumer hosts whose `learnings.yaml` top-level list sits at column 0 —
(a) the heredoc appends a hard-coded 2-space-indented `- id:` block → invalid YAML
(caught by their pre-push YAML gate, second occurrence after their T-262);
(b) the max-id grep `^  - id: L-` only matches the indented form → column-0 ids are
invisible and every run re-mints L-001 (duplicate-learnings class). CONFIRMED LIVE
IN-TREE: our own learnings.yaml's recent entries are column-0 (`- id: L-511` at
line 3906) — the scanner is blind to them right now. Same class exists on the
FP/patterns.yaml path in the same file (fixed-indent awk insert + `^  - id: FP-`
scan). Fix per 832's scratch-verified design: detect the indent of the last
existing `- id:` entry and emit at that indent; widen scans to
`^[[:space:]]*- id: (L|FP)-[0-9]+`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Learnings path: max-id scan widened to match any indent; append emits at the
      detected indent of the last existing entry (default 2-space when file has no
      entries). Verified against both file shapes (column-0 and 2-space-indented).
- [x] Patterns (FP) path: same treatment for the awk insert + FP max-id scan.
- [x] Bats regression test covering both file shapes for both paths (yaml-parses
      after append, id increments instead of re-minting) —
      tests/unit/healing_resolve_indent.bats, 4/4 green; sibling healing bats
      suites still green (35 ok, 0 fail); vendored copy synced (fw vendor self).
- [x] 832 informed on the rail that the fix is upstream, with commit ref, so their
      next re-vendor doesn't regress their in-tree T-295 fix — rail offset 309,
      commit 806577d24 (reply-to their 306).

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

out=$(bats tests/unit/healing_resolve_indent.bats 2>&1); echo "$out" | grep -q "^ok 4" && ! echo "$out" | grep -q "^not ok"
diff -q agents/healing/lib/resolve.sh .agentic-framework/agents/healing/lib/resolve.sh

## RCA

**Symptom:** On consumer hosts whose `learnings.yaml` top-level list sits at
column 0, `fw healing resolve` appends an invalidly-indented block (file fails
YAML parse) and re-mints `L-001` on every run because the max-id scan is blind to
column-0 entries. Reported by 832 (rail 306, their T-295); confirmed live in our
own tree — recent learnings entries are column-0 (`- id: L-511`), invisible to the
old scanner.

**Root cause:** A single 2-space indent assumption baked into BOTH the emitter
(hard-coded heredoc / awk block) and the scanner (`^  - id:` anchors) in
`agents/healing/lib/resolve.sh`. The two defects are one assumption expressed
twice.

**Why structurally allowed:** resolve.sh had zero tests (healing_diagnose and
healing_suggest bats exist; resolve had none), and the framework repo's own
YAML shape historically matched the assumption, so in-tree use never surfaced it.
The vendor boundary shipped the assumption to hosts with different file shapes —
third instance of the L-213/L-214 class (fix/behavior diverging across the
vendored copy).

**Prevention:** `tests/unit/healing_resolve_indent.bats` pins both file shapes
(column-0 and indented) for both append paths (L and FP), asserting id increment
+ post-append YAML validity. Vendored copy synced in the same commit
(`fw vendor self`), and doctor's self-vendor drift check guards future divergence.

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

### 2026-07-29T06:20:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2672-healing-resolvesh-append-breaks-on-colum.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-606c88a2
- **Timestamp:** 2026-07-29T06:27:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-29T06:27:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
