---
id: T-2256
name: "T-2209 Slice 1 pre-stage — OR-2 scan extension draft for orchestrator-mcp-scan.sh"
description: >
  T-2209 Slice 1 pre-stage — OR-2 scan extension draft for orchestrator-mcp-scan.sh

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
created: 2026-06-08T11:31:02Z
last_update: '2026-06-11T22:24:13Z'
date_finished: 2026-06-08T11:36:17Z
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
  - ts: '2026-06-11T22:24:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 3
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2256: T-2209 Slice 1 pre-stage — OR-2 scan extension draft for orchestrator-mcp-scan.sh

## Context

Pre-stage of the **OR-2 scan extension** (T-2216 §16, named as Slice 1's one real build leg in the capability-overlay arc). T-2209 is GO 2026-06-05 but `fw arc create capability-overlay` is Sovereign-only and hasn't fired yet. Until then, the Slice 1 author has no concrete code-shape to start from beyond T-2216's ~15-LoC sketch. This task lands the full draft (probe functions, baseline scaffold, wiring options A/B/C, three edge cases, LoC budget validation) at `docs/reports/T-2256-or-2-scan-extension-draft.md` + `.context/audits/framework-mcp-baseline.yaml.draft`, so Slice 1's bash+python authoring is a copy-and-customize, not a re-design. No source files under `agents/`, `bin/`, `lib/`, `web/` modified — Slice 1 carries the patch when the arc fires.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Research artefact written at `docs/reports/T-2256-or-2-scan-extension-draft.md` with sections: Context (T-2209/T-2216 trace), Current Scan Surface (probe_tools/probe_gate_calls anatomy), Proposed `probe_framework_tools()` (function sketch + edge cases — empty-cleanly when manifest absent, direct-read fallback, TermLink remote fallback), Proposed `framework-mcp-baseline.yaml` shape (mirror of orchestrator-mcp-baseline.yaml), Verification Block Addition (per OR-6), Convention-Classifier Reuse Decision (does T-2154's verb whitelist apply to mcp__framework__*?), LoC Budget Validation (verify T-2216's ~15 LoC estimate).
- [x] Draft scaffold file at `.context/audits/framework-mcp-baseline.yaml.draft` mirroring `orchestrator-mcp-baseline.yaml`'s shape (header comments + `gated:`, `mutators_ungated:`, `readonly_exempt:` keys empty, `baseline_count: 0`), so Slice 1 author has a concrete drop-in starting point.
- [x] Artefact's "Edge cases" enumeration includes at least three: (a) framework MCP server not yet deployed (empty return, not error), (b) cross-host scan via TermLink remote (degrade silently per existing `probe_via_direct_read` pattern), (c) baseline file absent on first run (exit 2 per existing pattern at scan.sh:40-44).
- [x] Artefact cites at minimum two existing-scan code anchor lines for the new code (per §2 "Current scan surface anatomy" table in the artefact: direct-read fallback pattern at lines 48-53; empty-probe error handling at lines 84-87 — both referenced in artefact body). Verification: `grep -c "scan.sh:" docs/reports/T-2256-or-2-scan-extension-draft.md` returns ≥2.
- [x] No source file under `agents/`, `bin/`, `lib/`, or `web/` is modified (this is pre-stage research only — Slice 1 carries the actual patch).
- [x] [REVIEWER] `bin/fw reviewer T-2256` returns Overall: PASS.

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

# Artefact exists
test -f docs/reports/T-2256-or-2-scan-extension-draft.md

# Draft baseline scaffold exists
test -f .context/audits/framework-mcp-baseline.yaml.draft

# Scaffold YAML parses
python3 -c "import yaml; yaml.safe_load(open('.context/audits/framework-mcp-baseline.yaml.draft'))"

# Artefact references the existing scan code as anchors
out=$(cat docs/reports/T-2256-or-2-scan-extension-draft.md); echo "$out" | grep -q "orchestrator-mcp-scan.sh"

# No source files modified under agents/bin/lib/web (pre-stage only — Slice 1 carries the patch)
[ "$(git diff --name-only HEAD | grep -E '^(agents|bin|lib|web)/' | wc -l)" -eq 0 ]
[ "$(git status --short | awk '{print $2}' | grep -E '^(agents|bin|lib|web)/' | wc -l)" -eq 0 ]

# Artefact cites scan-code anchor lines (≥2)
[ "$(grep -c 'scan.sh:' docs/reports/T-2256-or-2-scan-extension-draft.md)" -ge 2 ]

# Reviewer PASS (L-387 capture-then-grep — bold-aware regex per memory)
out=$(bin/fw reviewer T-2256 2>&1); echo "$out" | grep -qE "Overall:.*PASS"

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

### 2026-06-08T11:31:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2256-t-2209-slice-1-pre-stage--or-2-scan-exte.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c7afb9a3
- **Timestamp:** 2026-06-08T11:36:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-08T11:36:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
