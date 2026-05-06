---
id: T-1762
name: "task-pair §ACD gate (P-012): wire G-066 prong 2 into update-task.sh per T-1713 GO"
description: >
  task-pair §ACD gate (P-012): wire G-066 prong 2 into update-task.sh per T-1713 GO

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: ["arc:orchestrator-rethink", "ACD", "G-062-family", "G-066", "governance-gate", "P-012"]
components: ["lib/update-task.sh", "lib/inception_recommendation.sh", "agents/task-create/update-task.sh"]
related_tasks: ["T-1442", "T-1443", "T-1668", "T-1671", "T-1711", "T-1713", "T-1715", "T-1716", "T-1709"]
created: 2026-05-06T07:57:36Z
last_update: 2026-05-06T07:57:36Z
date_finished: null
---

# T-1762: task-pair §ACD gate (P-012): wire G-066 prong 2 into update-task.sh per T-1713 GO

## Context

Implements T-1713's GO decision (2026-05-04). T-1713 is itself the §ACD pattern G-066 documents — inception GO'd on 2026-05-04, no build task ever filed, gate not in `lib/update-task.sh` (verified 2026-05-06: `grep -i "acd\|scope-reduction\|task-pair" lib/update-task.sh` returns nothing).

Mirror existing arc-level §ACD gate pattern (T-1668 `--headline-mechanic` at `fw arc create`, T-1671 `fw arc close --demo` + CLAUDECODE refusal) at the task-pair level. When a build task closes `work-completed` and its `related_tasks` chain contains an inception with multi-deliverable GO Recommendation, mechanically compare promised deliverables against shipped artefacts. Refuse closure on miss; allow `--scope-reduction-acknowledged "rationale"` bypass with logged Tier-2 entry.

Sequencing prerequisite met: T-1715/T-1716 shipped — Recommendation block structure is now filing-time enforced via `fw inception start --recommendation GO|NO-GO|DEFER`, so parser spike is no longer NLP-heavy.

T-1713 GO decision frames work as three internal spikes (parser, comparison, insertion-point); single deliverable (the gate), three internal milestones. Not decomposed into sibling tasks per Task Sizing Rules — one deliverable.

## Acceptance Criteria

### Agent
- [ ] **Spike 1 (Parser):** `lib/inception_recommendation.sh` (or sibling `lib/task_pair_acd.sh`) exposes `extract_deliverables <task_file>` that returns numbered/bulleted deliverable list from `## Recommendation`. Bats test `tests/unit/test_task_pair_acd_parser.bats` covers ≥4 fixtures: T-1442 (3-deliverable GO), T-1713 (1-deliverable GO), T-1715 (1-deliverable GO), and a NO-GO inception (returns empty). Parser exits 0 on parse, 2 on no-Recommendation, 3 on no-GO.
- [ ] **Spike 2 (Comparison):** `lib/task_pair_acd.sh` exposes `verify_deliverables_shipped <inception_task_id> <build_task_id>` that compares parsed deliverables against repo state (file existence via fabric, function/symbol grep, bats test presence). Returns JSON `{shipped: [...], missing: [...], partial: [...]}`. Bats test covers: (a) T-1442/T-1443 historic — must report ≥1 missing (auto-tick or TermLink-dispatch reviewer); (b) T-1715/T-1716 historic — must report 0 missing (clean-shipped baseline). Forward-only — backfill against history is OUT of scope.
- [ ] **Spike 3 (Gate wiring):** `lib/update-task.sh do_update_task` calls `verify_deliverables_shipped` when transitioning to `work-completed` AND the task is `workflow_type: build` AND `related_tasks` includes an inception-with-GO. On `missing != []`, refuse with exit code 4 and message listing missing deliverables + bypass instructions. `--scope-reduction-acknowledged "rationale"` bypasses with entry logged to `.context/working/.gate-bypass-log.yaml` per Tier-2 contract.
- [ ] **Bypass plumbing:** Reuses existing `log_gate_bypass` machinery (mirror T-1671 `--i-am-human`/`--from-watchtower` pattern). No new bypass log file; entry shape matches existing P-010/P-011 bypasses.
- [ ] **No false positive on single-deliverable inceptions:** Build tasks whose inception parent had a single named deliverable (most tasks) MUST pass through the gate without intervention. Bats test confirms.
- [ ] **No P-010/P-011 contract break:** Existing AC checkbox check + Verification block check still run, in order, before P-012. Bats regression covers ordering.
- [ ] **Self-application:** T-1762's own work-completed transition either passes the gate (it's a build with single deliverable: "the gate") or refuses with rationale documenting the meta-recursion.
- [ ] **Documentation:** `## Decisions` section captures Spike 2 false-positive count (target ≤1 per T-1713 GO threshold) + parser agreement on the 4-fixture sample (target ≥80% per T-1713 GO threshold).

### Human
- [ ] [REVIEW] Verify gate trips correctly on a real-world test pair
  **Steps:**
  1. Open `https://watchtower.docker.ring20.geelenandcompany.com/tasks/T-1762` (or `fw watchtower url`/tasks/T-1762 locally)
  2. Run the recreate-test-pair command from the Verification block (`bin/fw test bats tests/unit/test_task_pair_acd_gate.bats -v`)
  3. Confirm the historic T-1442/T-1443 fixture trips with ≥1 missing deliverable
  **Expected:** Bats output shows `1..N ok` with the missing-deliverable assertion green; gate-bypass log entry created and logged when bypass flag exercised
  **If not:** Capture failure output + comment on which spike's contract broke; recommend NO-GO or scope-reduction with rationale
- [ ] [REVIEW] Confirm gate refusal message is actionable
  **Steps:**
  1. From a scratch consumer / test instance, attempt to close a fake build task that's missing one of its inception's deliverables: `cd /tmp/scratch && /opt/999-Agentic-Engineering-Framework/bin/fw task update T-FAKE --status work-completed`
  2. Read the refusal message
  **Expected:** Message names the missing deliverable, points at the inception that promised it, and shows the `--scope-reduction-acknowledged` bypass syntax explicitly
  **If not:** Note which information was missing or unclear; recommend message revision before close


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
bash -n lib/update-task.sh
test -f lib/task_pair_acd.sh && bash -n lib/task_pair_acd.sh
bin/fw test bats tests/unit/test_task_pair_acd_parser.bats
bin/fw test bats tests/unit/test_task_pair_acd_gate.bats
# Self-application: parser must execute against this task file
bash lib/task_pair_acd.sh extract_deliverables .tasks/completed/T-1713-task-pair-acd-gate-detect-substrate-vs-d.md >/dev/null
# Regression: existing P-010/P-011 still gate before P-012
bin/fw test bats tests/unit/update_task.bats

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

## Updates

### 2026-05-06T07:57:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1762-task-pair-acd-gate-p-012-wire-g-066-pron.md
- **Context:** Initial task creation
