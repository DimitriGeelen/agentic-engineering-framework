---
id: T-2150
name: "classify 5 new MCP tools via naming convention (T-1755 batch pattern)"
description: >
  classify 5 new MCP tools via naming convention (T-1755 batch pattern)

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: [.context/audits/orchestrator-mcp-baseline.yaml]
related_tasks: [T-1755, T-1760, T-1867, T-2073, T-1761, T-1646]
arc_id: orchestrator-rethink
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-31T18:53:51Z
last_update: '2026-06-11T22:24:09Z'
date_finished: 2026-05-31T18:57:16Z
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
  - ts: '2026-06-11T22:24:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2150: classify 5 new MCP tools via naming convention (T-1755 batch pattern)

## Context

Fifth iteration of the manual-classification batch pattern (T-1755 → T-1760 → T-1867 → T-2073).
`orchestrator-mcp-scan` flagged 5 unclassified tools on the 2026-05-31T18:48 audit:
`termlink_agent_chat_arc_recent`, `termlink_chat_arc_broadcast`,
`termlink_check_fleet_doorbell_mail_health`, `termlink_fleet_adoption_snapshot`,
`termlink_recent_dm`. Classify by the same naming-convention rule the four predecessor
batches used: action verbs → mutator (ungated), read-shape suffixes (recent/check/snapshot/
status/list/stats/summary) → readonly_exempt. Bump `baseline_count` 246 → 251.

Handler-level verification deferred per the established convention (`/opt/termlink` outside
PROJECT_ROOT; T-559 strict path isolation). T-1761 inception remains the structural
question of whether to automate this away; this task is a 5th data point for that inception.

## Acceptance Criteria

### Agent
- [x] `termlink_chat_arc_broadcast` added to `mutators_ungated:` (action verb `broadcast` → mutator)
- [x] `termlink_agent_chat_arc_recent`, `termlink_check_fleet_doorbell_mail_health`, `termlink_fleet_adoption_snapshot`, `termlink_recent_dm` added to `readonly_exempt:` (read-shape suffixes)
- [x] `baseline_count` bumped 246 → 251 (+5)
- [x] `last_verified` bumped to 2026-05-31
- [x] Header comment block updated with T-2150 entry documenting this batch
- [x] `orchestrator-mcp-scan.sh` no longer emits `NEW: ... unclassified tool(s)` on this set (audit re-run clean)

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

python3 -c "import yaml; b=yaml.safe_load(open('.context/audits/orchestrator-mcp-baseline.yaml')); assert b['baseline_count']==251, b['baseline_count']"
grep -q "termlink_chat_arc_broadcast" .context/audits/orchestrator-mcp-baseline.yaml
grep -q "termlink_agent_chat_arc_recent" .context/audits/orchestrator-mcp-baseline.yaml
grep -q "termlink_check_fleet_doorbell_mail_health" .context/audits/orchestrator-mcp-baseline.yaml
grep -q "termlink_fleet_adoption_snapshot" .context/audits/orchestrator-mcp-baseline.yaml
grep -q "termlink_recent_dm" .context/audits/orchestrator-mcp-baseline.yaml

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
-->

### 2026-05-31 — 5th batch in 30 days; T-1761 inception data point updated

- **What changed:** Fifth manual-classification batch since the convention was
  established (T-1755 2026-05-06, T-1760 2026-05-06, T-1867 2026-05-15, T-2073
  2026-05-28 + follow-on, T-2150 2026-05-31). Cadence: roughly one batch per
  week, growing in size (T-1755=59, T-1760=18, T-1867=14, T-2073=74+4, T-2150=5).
- **Plan impact:** T-1761's marginal-leverage rationale from filing (cost ≈ savings
  per batch) is increasingly tenuous as cumulative toil compounds. Five batches
  × ~15min each = ~75min spent; T-1761's implementation estimate was ~30-45min.
  We have now spent more on the toil than the structural fix would have cost.
- **Triggered:** T-1761 inception research artifact should reflect the updated
  evidence — leaving for the operator to formally revisit at next focus. This
  task is the data point, not the decision.

## Recommendation

**Recommendation:** GO (close as work-completed)

**Rationale:** Mechanical classification by the established convention. 1 mutator
(action verb `broadcast`) + 4 read-shapes (`recent`/`check`/`snapshot`/`recent`).
Handler-level verification deferred per the prevailing batch-pattern policy
(/opt/termlink outside PROJECT_ROOT). Baseline ratchets 246 → 251; audit WARN
clears.

**Evidence:**
- All 5 ACs ticked with concrete diffs
- `python3 -c ... assert baseline_count==251` passes
- 5 grep assertions for tool presence pass
- `bash agents/audit/orchestrator-mcp-scan.sh` no longer emits NEW unclassified WARN

<!-- Evolution template tail (template hygiene only; Evolution entry above is canonical). -->

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

### 2026-05-31T18:53:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2150-classify-5-new-mcp-tools-via-naming-conv.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-33b70905
- **Timestamp:** 2026-06-02T15:01:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **external-publish** (high) — External publish or release
     - matched: `broadcast`
### 2026-05-31T18:57:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
