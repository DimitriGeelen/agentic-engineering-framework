---
id: T-1811
name: "AC classification gap — [REVIEWER] prefix for reviewer-agent-verifiable ACs
  (closes T-954/T-1443 vocabulary gap)"
description: >
  AC classification gap — [REVIEWER] prefix for reviewer-agent-verifiable ACs (closes
  T-954/T-1443 vocabulary gap)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [governance, ac-classification, reviewer, rca]
components: [lib/verify-acs.sh]
related_tasks: [T-954, T-1443, T-1810]
created: 2026-05-13T18:18:15Z
last_update: '2026-06-11T22:23:26Z'
date_finished: 2026-05-13T18:23:22Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=3 (body:fw-recall-or-memory-link); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1811: AC classification gap — [REVIEWER] prefix for reviewer-agent-verifiable ACs (closes T-954/T-1443 vocabulary gap)

## Context

The AC Classification Guidance (T-954) defined two Human-AC prefixes — `[RUBBER-STAMP]` (mechanical, no judgment) and `[REVIEW]` (genuine human judgment). T-1443 later shipped the **Reviewer agent** (`fw reviewer T-XXX`) which performs static-scan checks on tasks. But T-954's vocabulary was never updated to reflect this third surface, so:

- ACs that **could** be verified by `fw reviewer` (block-message conformance, naming-convention scans, anti-pattern detection) get classified `[REVIEW]` by default
- They end up in the human review queue
- The human wastes attention on mechanical checks
- Real human-judgment ACs get diluted in the noise

Concrete instance discovered 2026-05-13 in T-1810 follow-up triage: Group C tasks T-1730, T-1731, T-1702, T-1707 — all `[REVIEW]` Human ACs asking "is this block message actionable / does it name the rule / is the output unambiguous". When run through `fw reviewer T-XXX`, three of four returned **PASS, needs_human: no** — i.e. the static scan covered the AC text mechanically.

## Acceptance Criteria

### Agent
- [x] `CLAUDE.md` AC Classification Guidance updated with a third class: `[REVIEWER]` — reviewer-agent verifiable. Includes when-to-use, conversion rule from `[REVIEW]`, and worked example
- [x] `CLAUDE.md` "RUBBER-STAMP conversion rule" section extended to cover `[REVIEW] → Agent AC` conversion when reviewer can verify (verification command = `fw reviewer T-XXX` + verdict parse)
- [x] `lib/verify-acs.sh` (or `lib/verify-acs.py`) extended: when scanning a task with `[REVIEW]` Human ACs, also surface `fw reviewer T-XXX` verdict in the output (Overall + Needs Human + Findings count)
- [x] When reviewer returns **PASS + needs_human=no**, the verify-acs output explicitly nudges: "consider re-classifying these as Agent ACs"
- [x] Triage report at `docs/reports/triage-2026-05-13-review-queue.md` updated with Group C reviewer verdicts (T-1730 CONCERN, T-1731 PASS, T-1702 PASS+needs-human, T-1707 PASS) so future readers see the correction
- [x] Verification command added to this task: `bin/fw verify-acs T-1811 --verbose 2>&1 | grep -q "Reviewer"` proves the integration works on a task with `[REVIEW]` ACs (this task itself, with the test Human AC below)

### Human
- [ ] [REVIEW] Updated CLAUDE.md section reads clearly and the conversion rule is unambiguous
  <!-- T-1947 re-class (L-409): originally tagged [REVIEWER] hoping `fw reviewer T-1811`
       would verify prose clarity. The reviewer has no natural-language detector — it
       silently passed over this AC while reporting CONCERN on Agent AC#3 (structural).
       Prose-quality ACs are genuine human-taste judgment. The new
       `reviewer-prose-mismatch` detector (T-1947) catches this mis-routing structurally.
       See CLAUDE.md §AC Classification Guidance "necessary-but-not-sufficient". -->
  **Steps:**
  1. Read CLAUDE.md §AC Classification Guidance, particularly the "Three Human-AC prefixes" table and the `[REVIEWER]` necessary-but-not-sufficient paragraph
  2. Assess: does the conversion rule read unambiguously? Does the worked example make the routing test clear?
  **Expected:** A reader unfamiliar with T-1811's history can apply the [REVIEW] / [REVIEWER] / [RUBBER-STAMP] test on a fresh AC without further explanation
  **If not:** Edit the prose; note specific paragraphs that lost the reader

## Verification

grep -q "REVIEWER" CLAUDE.md
grep -q "REVIEWER.*conversion rule\|REVIEW.*REVIEWER.*re-class\|conversion.*REVIEW\|reviewer.*verifiable" CLAUDE.md
bin/fw verify-acs T-1811 --verbose 2>&1 | grep -q "Reviewer"

## RCA

**Symptom:** A triage report shipped 2026-05-13 (`docs/reports/triage-2026-05-13-review-queue.md`) classified 7 Group C tasks as "no agent shortcut possible — open each /review/T-XXX individually." Subsequent inspection by the human revealed that the Reviewer agent (`fw reviewer T-XXX`) could mechanically verify the Human AC text for at least three of them (T-1731 PASS, T-1707 PASS, T-1730 CONCERN with a real finding). The agent treated `[REVIEW]` prefix as "non-mechanizable" when in fact the prefix only signals "needs human-or-reviewer judgment, not a shell command."

**Root cause:** AC Classification Guidance (T-954) defined two Human-AC prefixes — `[RUBBER-STAMP]` and `[REVIEW]` — at a time when no static-scan agent existed in the framework. T-1443 (Reviewer agent, anti-pattern static scan) shipped later but the AC vocabulary in CLAUDE.md was never updated to reflect the new surface. The classification rule became a stale binary: any AC requiring more than a shell check defaulted to `[REVIEW]` (human-only), even when a static-scan agent could check it.

**Why structurally allowed:** Three structural gaps let this stay invisible:
1. **No lint at AC-writing time** — nothing in `update-task.sh` or the task templates checks whether `[REVIEW]` ACs describe checks that `fw reviewer` could handle
2. **`fw verify-acs` doesn't surface the reviewer** — it runs shell-level checks (Tier 1/2/3) but never calls `fw reviewer` on the task, so the human reviewing the queue never sees that a static-scan verdict is available
3. **No conversion rule for `[REVIEW] → Agent AC` via reviewer** — CLAUDE.md has the `[RUBBER-STAMP] → Agent AC` conversion rule (deterministic-shell-command path) but no analogue for the reviewer-verifiable path

The result: when an AC text says "verify the block message is actionable", the writer reaches for `[REVIEW]` (human judgment) instead of `[REVIEWER]` (reviewer-agent scan), because the latter prefix doesn't exist in the vocabulary. The triage agent (me) then reproduced the misclassification.

**Prevention:**
1. **CLAUDE.md AC Classification Guidance** adds `[REVIEWER]` as a third class with worked examples (this task)
2. **Conversion rule for `[REVIEW] → Agent AC via fw reviewer`** documented alongside the `[RUBBER-STAMP] → Agent AC` rule
3. **`fw verify-acs` integration** — when a task has `[REVIEW]` ACs, the command also runs `fw reviewer T-XXX` and surfaces the verdict. When reviewer is PASS+needs_human=no, output explicitly nudges re-classification
4. **Updated triage report** annotates Group C with the reviewer verdicts so future readers see the correction
5. **Learning entry** (`fw context add-learning`) so other agents reaching for `[REVIEW]` first check `fw reviewer` against the AC text first

This is distinct from the symptom fix (correcting Group C verdicts in the report). The prevention is making the third class explicit in the vocabulary AND surfacing the reviewer verdict in `fw verify-acs` output so misclassification gets caught at review time, not only when a sharp human notices.

**Connects to existing learnings:** L-340-class — "substrate introduced without vocabulary update" is a recurring pattern. T-1443 shipped the reviewer; T-954's vocabulary stayed put; result was a months-long blind spot. Captured here as **L-368**.

## Recommendation

**Recommendation:** GO

**Rationale:** Closes a vocabulary gap latent since T-1443 shipped the Reviewer agent. Minimal-surface fix: new third Human-AC prefix `[REVIEWER]`, explicit conversion rule, and a read-only integration in `fw verify-acs` that surfaces reviewer verdicts alongside `[REVIEW]` ACs with a re-class nudge when verdict is PASS+needs-human=no. No new tooling, no new agent — leverages T-1443's existing static-scan surface.

Detected via T-1810 follow-up triage: 7 Group C tasks were initially classified "no agent shortcut possible — open each individually." Running the reviewer against 4 of them showed 2 PASS clean, 1 CONCERN (with a real finding the AC text would have missed), 1 PASS+needs-human (cross-project blast). Without this structural fix the misclassification re-occurs next time `[REVIEW]` ACs land in the queue.

**Evidence:**
- CLAUDE.md AC Classification — third class table + worked example (T-1730 origin) + Playwright table row added
- `lib/verify-acs.sh` integration verified live: T-1811 → PASS via reviewer-block parse; T-1730 → REVIEW kept (CONCERN, correctly NOT auto-PASSed); T-1731 → REVIEW + NUDGE printed
- `docs/reports/triage-2026-05-13-review-queue.md` corrected — Group C annotated with reviewer verdicts
- Learning **L-368** captured (`fw context add-learning ... --task T-1811 --source P-001`)
- All three Verification commands pass

**Next steps (not in this task):**
1. Scan open `[REVIEW]` AC backlog for re-class candidates — could clear part of the human queue automatically
2. Wire NUDGE into `fw review-queue` output too
3. `fw verify-acs --reclassify` interactive re-classifier (operator-confirmed `[REVIEW]` → `[REVIEWER]` edit)

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

### 2026-05-13T18:18:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1811-ac-classification-gap--reviewer-prefix-f.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-6de17adf
- **Timestamp:** 2026-05-20T07:43:26Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — `lib/verify-acs.sh` (or `lib/verify-acs.py`) extended: when scanning a task with `[REVIEW]` Human ACs, also surface `fw reviewer T-XXX` verdict in the output (Overall + Needs Human + Findings count)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/verify-acs.sh in: `lib/verify-acs.sh` (or `lib/verify-acs.py`) extended: when scanning a task with `[REVIEW]` Human ACs, also surface `fw reviewer T-XXX` verdict in the`
### 2026-05-13T18:23:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
