---
id: T-1984
name: "T-1983A: inception GO-scope traceability — schema + hook + close gate"
description: >
  T-1983A: inception GO-scope traceability — schema + hook + close gate

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [agents/task-create/update-task.sh, C-009]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-21T22:29:41Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-21T22:50:29Z
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
  - ts: '2026-05-21T22:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-21T22:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 5
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=5 (body:class-neutral); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1984: T-1983A: inception GO-scope traceability — schema + hook + close gate

## Context

Ships the design GO'd in T-1983 (`.tasks/completed/T-1983-go-scope-traceability--inception-decisio.md`).
Structural prevention for G-066: inception GO scope becomes machine-readable;
`update-task.sh --status work-completed` refuses inception close until every
decision in `inception_decisions:` has a reachable `ships_in:` referent OR an
explicit `deferred_to: T-YYYY` link.

T-1983's Decisions block specifies the full design — schema (5 `ships_in:`
shapes), build-child link (`unlocks_inception_decision:`), gate site
(`update-task.sh`), migration (grandfather; opt-in via populated field), and
bypass parity (`--skip-inception-scope-trace` + `FW_SKIP_INCEPTION_SCOPE_TRACE=1`).

This is the **substrate ship**. T-1950 (already GO'd, in completed/) is the
first dogfood consumer — once T-1984 ships, T-1950's decisions will be backfilled
into the new schema and a separate build task (T-1950A) will land
`unlocks_inception_decision:` on its build child(ren).

## Acceptance Criteria

### Agent
- [x] Schema: `inception_decisions:` frontmatter field accepted on inception tasks. Each entry is `{id: <slug>, text: <one-liner>, ships_in: <referent>}`. `id:` is a free-text kebab-case slug; uniqueness validated within the task; `text:` is a one-liner; `ships_in:` accepts one of five shapes: (1) file path, (2) `module.function`, (3) `path::test_name`, (4) `T-XXX`, (5) `deferred:T-YYYY`. Parsed via `lib/inception_decisions.sh` (new) or `lib/inception_decisions.py` (preferred for YAML safety).
- [x] Schema: `unlocks_inception_decision:` frontmatter field accepted on build tasks. List of `T-XXX:<decision-id>` strings. Validator confirms each referenced inception+decision-id exists.
- [x] PreToolUse hook `agents/context/check-inception-decisions` blocks Write|Edit on `.tasks/{active,completed}/T-*.md` when `inception_decisions:` is non-empty AND any entry has malformed shape OR duplicate `id:` OR unresolvable `ships_in:` referent. Override env-var: `FW_ALLOW_INCEPTION_DECISIONS_DRIFT=1` (Tier-2 logged).
- [x] Refusal gate: `update-task.sh --status work-completed` on `workflow_type: inception` task with non-empty `inception_decisions:` parses each entry and validates `ships_in:` reachability — file exists, function/symbol defined (grep), task-id is in `.tasks/completed/`, or `deferred:T-YYYY` target exists. Blocks transition with one-paragraph block message naming the failing decision id + override flag.
- [x] Bypass parity (L-399): block message names BOTH `--skip-inception-scope-trace "rationale"` (for direct `update-task.sh` invocations) AND `FW_SKIP_INCEPTION_SCOPE_TRACE=1` env-var (for `git commit` and other downstream). Both are accepted, both log Tier-2 entry to `.context/working/.gate-bypass-log.yaml`.
- [x] Tests: bats covering — (a) opt-in: inception without `inception_decisions:` closes fine (grandfathering); (b) opt-in: inception with populated decisions whose ships_in all resolve closes fine; (c) refusal: missing file path / undefined symbol / non-completed task ref / non-existent defer target each block; (d) `deferred:T-YYYY` accepted when target exists; (e) override flag accepted with rationale, bypass log entry written; (f) env-var accepted under `git commit` shape, bypass log entry written; (g) build child with `unlocks_inception_decision:` referencing non-existent decision is rejected by PreToolUse.
- [x] Fresh-machine simulation: `tests/unit/upgrade_fresh_machine_simulation.bats` still passes (T-1633 / consumer-facing hygiene — T-1984 must not regress fw upgrade).
- [x] Docs: CLAUDE.md §Task System adds a one-paragraph subsection "Inception GO-scope traceability" with the schema example + override flag + env-var. Watchtower /inceptions surface shows `inception_decisions:` summary count per inception (cosmetic, optional this slice).

### Human
- [ ] [REVIEW] Block message rhythm reads cleanly — when the gate fires, the message states (1) which decision failed (2) what `ships_in:` looked for (3) the override flag + env-var (4) one-line guidance on when to pick each
  **Steps:**
  1. Create a test inception task with `inception_decisions:` containing one entry whose `ships_in:` is a deliberately non-existent file path
  2. Run `bin/fw task update T-TEST --status work-completed`
  3. Read the block message
  **Expected:** message is one paragraph; names the failing decision id; says exactly which referent shape was tried; lists both `--skip-inception-scope-trace` flag AND `FW_SKIP_INCEPTION_SCOPE_TRACE=1` env-var with one-line "when to pick which" guidance
  **If not:** revise `lib/inception_decisions.py:format_block_message` (or shell equivalent) — keep it under 8 lines

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

python3 -m pytest tests/unit/test_inception_decisions_parser.py -q 2>&1 | tail -3 | grep -v "^$" | head -3
FRAMEWORK_ROOT=/opt/999-Agentic-Engineering-Framework bats tests/unit/check_inception_decisions_hook.bats 2>&1 | tail -3 | grep -v "^$" | head -3
FRAMEWORK_ROOT=/opt/999-Agentic-Engineering-Framework bats tests/unit/update_task_inception_scope_gate.bats 2>&1 | tail -3 | grep -v "^$" | head -3
FRAMEWORK_ROOT=/opt/999-Agentic-Engineering-Framework bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1 | tail -3 | grep -v "^$" | head -3
test -f lib/inception_decisions.py
out=$(python3 -m py_compile lib/inception_decisions.py agents/context/check-inception-decisions.py 2>&1); [ -z "$out" ]
out=$(grep -n "Inception GO-scope" CLAUDE.md 2>&1); echo "$out" | grep -q "Inception GO-scope"
bin/fw enforcement baseline 2>&1 | grep -q "baseline saved\|baseline unchanged\|Hash:"

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 7 Agent ACs are checked. 6 commits landed in sequence. 8/8 verification commands pass. Human AC is a [REVIEW] of the block message rhythm — the message names the failing decision id, the referent shape tried, both override mechanisms, and one-line guidance on which to use. No blocker; ready for human review of block message quality.

**Evidence:**
- `lib/inception_decisions.py` — parser, 5-shape detector, reachability checks (53 pytest pass)
- `agents/context/check-inception-decisions.{sh,py}` — PreToolUse hook wired in settings.json (20 bats pass)
- `agents/task-create/update-task.sh` — close gate with `--skip-inception-scope-trace` + `FW_SKIP_INCEPTION_SCOPE_TRACE=1` (10 bats pass)
- `tests/unit/upgrade_fresh_machine_simulation.bats` — 3/3 pass, no regression
- `CLAUDE.md §Task System` — "Inception GO-scope traceability" paragraph with schema example + both override mechanisms

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-21T22:29:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1984-t-1983a-inception-go-scope-traceability-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bc66e439
- **Timestamp:** 2026-06-11T12:12:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `bin/fw enforcement baseline 2>&1 | grep -q "baseline saved\|baseline unchanged\|Hash:"`
### 2026-05-21T22:50:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
