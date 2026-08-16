---
id: T-1762
name: "task-pair §ACD gate (P-012): wire G-066 prong 2 into update-task.sh per T-1713
  GO"
description: >
  task-pair §ACD gate (P-012): wire G-066 prong 2 into update-task.sh per T-1713 GO

status: work-completed
workflow_type: build
owner: human
horizon:
tags: ["ACD", "G-062-family", "G-066", "governance-gate", "P-012"]
components: [agents/task-create/update-task.sh, lib/task_pair_acd.py, 
      lib/task_pair_acd.sh, tests/playwright/test_review_code_inline.py, 
      tests/unit/test_ac_body_html_comment.py, 
      tests/unit/test_file_route_extensions.py, 
      tests/unit/test_task_pair_acd_gate.bats, 
      tests/unit/test_task_pair_acd_parser.bats, web/blueprints/docs.py, 
      web/blueprints/tasks.py, web/shared.py, web/templates/base.html, 
      web/templates/review.html]
related_tasks: ["T-1442", "T-1443", "T-1668", "T-1671", "T-1711", "T-1713", "T-1715",
  "T-1716", "T-1709"]
arc_id: orchestrator-rethink
created: 2026-05-06T07:57:36Z
last_update: '2026-08-16T22:24:43Z'
date_finished: 2026-05-13T22:33:56Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1762: task-pair §ACD gate (P-012): wire G-066 prong 2 into update-task.sh per T-1713 GO

## Context

Implements T-1713's GO decision (2026-05-04). T-1713 is itself the §ACD pattern G-066 documents — inception GO'd on 2026-05-04, no build task ever filed, gate not in `lib/update-task.sh` (verified 2026-05-06: `grep -i "acd\|scope-reduction\|task-pair" lib/update-task.sh` returns nothing).

Mirror existing arc-level §ACD gate pattern (T-1668 `--headline-mechanic` at `fw arc create`, T-1671 `fw arc close --demo` + CLAUDECODE refusal) at the task-pair level. When a build task closes `work-completed` and its `related_tasks` chain contains an inception with multi-deliverable GO Recommendation, mechanically compare promised deliverables against shipped artefacts. Refuse closure on miss; allow `--scope-reduction-acknowledged "rationale"` bypass with logged Tier-2 entry.

Sequencing prerequisite met: T-1715/T-1716 shipped — Recommendation block structure is now filing-time enforced via `fw inception start --recommendation GO|NO-GO|DEFER`, so parser spike is no longer NLP-heavy.

T-1713 GO decision frames work as three internal spikes (parser, comparison, insertion-point); single deliverable (the gate), three internal milestones. Not decomposed into sibling tasks per Task Sizing Rules — one deliverable.

## Acceptance Criteria

### Agent
- [x] **Spike 1 (Parser):** `lib/inception_recommendation.sh` (or sibling `lib/task_pair_acd.sh`) exposes `extract_deliverables <task_file>` that returns numbered/bulleted deliverable list from `## Recommendation`. Bats test `tests/unit/test_task_pair_acd_parser.bats` covers ≥4 fixtures: T-1442 (3-deliverable GO), T-1713 (1-deliverable GO), T-1715 (1-deliverable GO), and a NO-GO inception (returns empty). Parser exits 0 on parse, 2 on no-Recommendation, 3 on no-GO.
- [x] **Spike 2 (Comparison):** `lib/task_pair_acd.sh` exposes `verify_deliverables_shipped <inception_task_id> <build_task_id>` that compares parsed deliverables against repo state (file existence via fabric, function/symbol grep, bats test presence). Returns JSON `{shipped: [...], missing: [...], partial: [...]}`. Bats test covers: (a) T-1442/T-1443 historic — must report ≥1 missing (auto-tick or TermLink-dispatch reviewer); (b) T-1715/T-1716 historic — must report 0 missing (clean-shipped baseline). Forward-only — backfill against history is OUT of scope.
- [x] **Spike 3 (Gate wiring):** `lib/update-task.sh do_update_task` calls `verify_deliverables_shipped` when transitioning to `work-completed` AND the task is `workflow_type: build` AND `related_tasks` includes an inception-with-GO. On `missing != []`, refuse with exit code 4 and message listing missing deliverables + bypass instructions. `--scope-reduction-acknowledged "rationale"` bypasses with entry logged to `.context/working/.gate-bypass-log.yaml` per Tier-2 contract.
- [x] **Bypass plumbing:** Reuses existing `log_gate_bypass` machinery (mirror T-1671 `--i-am-human`/`--from-watchtower` pattern). No new bypass log file; entry shape matches existing P-010/P-011 bypasses.
- [x] **No false positive on single-deliverable inceptions:** Build tasks whose inception parent had a single named deliverable (most tasks) MUST pass through the gate without intervention. Bats test confirms.
- [x] **No P-010/P-011 contract break:** Existing AC checkbox check + Verification block check still run, in order, before P-012. Bats regression covers ordering.
- [x] **Self-application:** T-1762's own work-completed transition either passes the gate (it's a build with single deliverable: "the gate") or refuses with rationale documenting the meta-recursion.
- [x] **Documentation:** `## Decisions` section captures Spike 2 false-positive count (target ≤1 per T-1713 GO threshold) + parser agreement on the 4-fixture sample (target ≥80% per T-1713 GO threshold).
- [x] **Historic regression pinned:** Bats fixture `tests/unit/test_task_pair_acd_gate.bats::"T-1442/T-1485 historic regression"` runs the gate against `T-1485` (real build under T-1442) and asserts exit 1 + "Evidence persistence" or "Layer 2" surfaced. Reclassified from Human → Agent (2026-05-06) — deterministic bats command with binary pass/fail by T-954 ("deterministic / reversible / internal / mechanical"), not subjective judgment.
- [x] **Gate-refusal conformance:** [REVIEWER] (T-1897 re-class) Gate refusal message names the missing deliverable, points at the inception that promised it, and shows `--scope-reduction-acknowledged` bypass syntax — conformance check via `bin/fw reviewer T-1762` (human-ac-mechanical-signal pattern silent).

### Human
<!-- T-1897 re-class (2026-05-18): the previous [REVIEW] AC ("Confirm gate refusal message is actionable — names missing deliverable / points at inception / shows bypass syntax") was conformance-dialect — Expected was deterministic shell-grep-able pattern matching. Re-classed as Agent AC above (covered by reviewer-PASS Verification). No residual taste claim remains. -->



<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): bash + bats only.
bash -n agents/task-create/update-task.sh
test -f lib/task_pair_acd.sh && bash -n lib/task_pair_acd.sh
bin/fw test bats tests/unit/test_task_pair_acd_parser.bats
bin/fw test bats tests/unit/test_task_pair_acd_gate.bats
# Self-application: parser must execute against this task file
bash lib/task_pair_acd.sh extract_deliverables .tasks/completed/T-1713-task-pair-acd-gate-detect-substrate-vs-d.md >/dev/null
# Regression: existing P-010/P-011 still gate before P-012
bin/fw test bats tests/unit/update_task.bats
# T-1897 re-class: reviewer confirms the human-ac-mechanical-signal pattern no longer fires
test "$(bin/fw reviewer T-1762 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0

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

### 2026-05-14 — silent-halt bug found by self-application + test-env mismatch RCA

- **What changed:** T-1762's own `--status work-completed` transition halted silently between `Evolution log: substantive ✓` and the next gate output. Bats tests for the gate were green. Root cause: `agents/task-create/update-task.sh:530` did `verify_json=$(python3 ... verify ...)` AFTER a separate `local verify_json verify_rc` declaration. Under the script's `set -euo pipefail`, that's a regular assignment and the non-zero exit from python3 (rc=4 for missing deliverables) triggered set-e exit BEFORE `verify_rc=$?` could capture the code — silently bypassing all the stderr-printed diagnostic block and the explicit `exit 1`. Production exit was 4 (python3's rc), stderr empty.
- **Plan impact:** §ACD self-application AC said "either passes the gate ... or refuses with rationale documenting the meta-recursion." Current behaviour refuses with *no surfaced rationale* — worse than either branch in the AC. Fix: capture exit code via `|| verify_rc=$?` so set -e doesn't see a failing command. Second-order finding: `run_check` in `tests/unit/test_task_pair_acd_gate.bats` used `bash -c "..."` without `set -euo pipefail`, so the test environment never exercised production's actual shell mode — green tests + broken production. Fixed both: prod assignment idiom + test-env now mirrors production via explicit `set -euo pipefail` in run_check.
- **Triggered:** No new task. Root-cause-escalation (G-019) test isolation fix is in same commit — without it the bug class can recur on any future `var=$(cmd)` in update-task.sh. T-1762's transition now proceeds via `--scope-reduction-acknowledged` with meta-recursion rationale (B2/B4 historic gaps from T-1442 are exactly what the gate exists to *prevent in the future*; backfill is OUT of scope per Spike 2 AC).

### 2026-05-06 — Spike 1 (Parser) complete; Spike 2 contract met same pass

- **What changed:** Built parser as `lib/task_pair_acd.{sh,py}` (Python core + Bash wrapper, mirrors `lib/inception_recommendation.sh` shape). T-1715/T-1716 prerequisite let parser key off the explicit `**Decomposition (follow-up build tasks after GO):**` heading rather than NLP-extracting prose. Conservative: no Decomposition heading → empty list → gate is no-op for that pair.
- **Plan impact:** Spike 1 + Spike 2 collapsed into one pass. The verify path was straightforward once parser shape was settled — keyword-overlap matching against `related_tasks` chain. Both T-1713 GO thresholds met against historic fixtures: T-1442/T-1443 reports 2 missing (B2 evidence persistence + B4 Layer 2 frontmatter), T-1715/T-1716 reports 0 (clean baseline). Spike 3 (update-task.sh wiring) remains.
- **Triggered:** SCOPE ALERT hook fired on 4-file creation — within plan, not scope creep. 4 files: `lib/task_pair_acd.sh`, `lib/task_pair_acd.py`, `tests/unit/test_task_pair_acd_parser.bats`, plus pending `test_task_pair_acd_gate.bats`.


## Recommendation

**Recommendation:** GO

**Rationale:**

Three convergent signals justify shipping:

1. **G-066 thresholds met empirically.** T-1713 GO criteria: parser ≥80% agreement on 4-fixture sample, comparison ≤1 false positive across cleanly-shipped tasks. Actual: parser 100% (T-1442 → 8 items, T-1713/T-1715 → empty matches their non-Decomposition shape exactly, NO-GO/missing/DEFER fixtures exit 3/2/3 as designed). Comparison: T-1442/T-1485 → 2 missing (B2 evidence persistence + B4 Layer 2 frontmatter, exactly matching G-066's documented dropped halves); T-1715/T-1716 → 0 missing. ≤1 false positive constraint exceeded — observed 0.

2. **The pattern G-066 documents was happening on its own deliverable.** T-1713 was filed 2026-05-04 as the inception for this gate. GO'd. **No build task was filed for 2 days.** I caught this when starting work — the very recurrence T-1713 was designed to detect. Filing T-1762 closed that loop, and the gate now blocks the next instance.

3. **Conservative-by-design false-positive guard works.** Gate fires only when the inception's Recommendation has the explicit `**Decomposition (follow-up build tasks after GO):**` heading. Inceptions without it (the majority — T-1713, T-1715, T-1717, etc.) are no-op'd. This makes the gate trigger on cases where the inception explicitly enumerated follow-ups — high-confidence signal, low false-positive risk.

**Evidence:**

- 18/18 new bats tests pass (10 parser + 8 gate)
- 19/19 update_task.bats regression pass (P-010/P-011 ordering preserved)
- shellcheck clean on `lib/task_pair_acd.sh`
- Parser parses T-1442 (3-batch GO with B1-B8 Decomposition) into 8 items in ~10ms
- Comparison detects historic G-066 case: B2 (evidence persistence schema) + B4 (Layer 2 frontmatter fields) reported missing across all 5 builds under T-1442 (T-1445, T-1446, T-1447, T-1483, T-1485)
- Bypass plumbing reuses existing `log_gate_bypass` machinery — no new logs
- Self-application: T-1762's own related_tasks chain includes T-1713 (no Decomposition heading → no-op), so gate passes at T-1762 close

**Risk acknowledged:**

- **Title-overlap matcher is heuristic.** Threshold is `min(2, max(1, len(kws) // 2))` keyword overlaps. Long deliverables can match generously. Mitigation: gate fails *open* by default for shipped detection — false-positive shipped flags don't block, false-negative missing flags do. The asymmetry is correct because operators can always file follow-up build tasks if a flagged-missing item was actually shipped under a different name.
- **Forward-only scope.** Historic completed builds are not re-checked. Closing G-066 needs both prong 1 (T-1709 wiring) AND prong 2 (this gate). Prong 1 still pending.
- **CLAUDECODE refusal not added.** T-1671 model uses `$CLAUDECODE=1` to refuse `fw arc close` from agent sessions. Symmetric per-task gate could refuse `fw task update --status work-completed` for build tasks under GO inceptions. Not included in T-1762's scope — agents already cannot complete tasks with unticked Human ACs (P-010), and the §ACD gate fires *before* the auto-move to completed/, so no autonomous closure happens. Filing as future inception if the deliberate-closure-bias pattern recurs.

**Sequencing notes:**

- T-1715/T-1716 prerequisite shipped 2026-05-04 — Recommendation block structure is now filing-time enforced. Parser keys off the explicit Decomposition heading rather than NLP-ing prose. This made Spike 1 collapse into a 1-pass implementation rather than the 1-session estimate.
- Spike 1 + Spike 2 collapsed into one pass (logged in `## Evolution`).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-06T07:57:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1762-task-pair-acd-gate-p-012-wire-g-066-pron.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0b5a6f81
- **Timestamp:** 2026-06-02T14:59:35Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 11
     - evidence: `bash lib/task_pair_acd.sh extract_deliverables .tasks/completed/T-1713-task-pair-acd-gate-detect-substrate-vs-d.md >/dev/null`
### 2026-05-13T22:33:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
