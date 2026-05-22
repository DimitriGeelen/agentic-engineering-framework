---
id: T-1985
name: "T-1950A reviewer auto-tick [REVIEWER] Agent ACs v1.0 — dogfood of T-1984 substrate"
description: >
  T-1950A reviewer auto-tick [REVIEWER] Agent ACs v1.0 — dogfood of T-1984 substrate

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [reviewer, auto-tick, g-066, dogfood]
components: [lib/reviewer/static_scan.py]
related_tasks: [T-1950, T-1984, T-1443, T-1811, T-1947]
unlocks_inception_decision:
  - T-1950:trigger
  - T-1950:scope
  - T-1950:evidence-sufficiency
  - T-1950:sovereignty-rail
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-22T06:48:44Z
last_update: 2026-05-22T06:52:02Z
date_finished: null
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

# T-1985: T-1950A reviewer auto-tick [REVIEWER] Agent ACs v1.0 — dogfood of T-1984 substrate

## Context

Ships the implementation of T-1950's GO decision (the inception that answered
T-1443's four deferred questions). v1.0 scope: reviewer auto-ticks
**[REVIEWER]-prefixed Agent ACs only**, fires every reviewer scan, evidence-gated
on five conjunctive conditions, sovereignty-rail via digest-keyed feedback-stream.

T-1984 already shipped the structural-prevention substrate (`inception_decisions:`
schema + close gate). T-1985 (T-1950A in spirit) is the first dogfood consumer —
once shipped, the file will carry `unlocks_inception_decision:` referencing T-1950's
four decisions (link added after T-1950's `inception_decisions:` backfill — see
related sequencing in S-2026-0522 session).

T-1443 already sanctioned the principle (decisions 36/113/213 — auto-tick
Agent ACs, NEVER Human ACs). T-1950 answered the implementation questions:

| T-1950 decision | v1.0 choice |
|---|---|
| Trigger | Whenever reviewer scan runs (writeback in same pass as verdict block) |
| Scope | `[REVIEWER]`-prefixed Agent ACs ONLY |
| Evidence | Conjunctive: overall PASS + zero per-AC findings + AC currently unticked + no suppress override + prefix matches |
| Sovereignty rail | Digest-keyed feedback-stream: one tick per `(task_id, ac_index, ac_text_digest)` tuple |

Substrate already in place:
- `lib/reviewer/static_scan.py` v1.4 — `Finding.ac_index/ac_subhead/ac_text` (per-AC findings)
- `lib/reviewer/static_scan.py:7,1130` — `"NEVER modifies AC checkboxes"` guard (to be lifted ONLY for `[REVIEWER]` Agent ACs)
- Feedback-stream + overrides infrastructure (v1.4)
- `update-task.sh` already invokes reviewer post-verification

Research artifact: `docs/reports/T-1950-reviewer-auto-tick-inception.md`.

## Acceptance Criteria

### Agent
- [ ] `lib/reviewer/static_scan.py` — guard at lines 7/1130 narrowed: the "NEVER modifies AC checkboxes" rule is preserved for Human ACs and non-[REVIEWER]-prefixed Agent ACs; lifted only for Agent ACs whose text starts with `[REVIEWER]` (after the leading `- [ ] ` / `- [x] `)
- [ ] Tick is conjunctive on five conditions: (1) overall verdict PASS, (2) zero `Finding` entries match the AC's `ac_index` AND `ac_text_digest`, (3) AC is currently unticked (`- [ ]`), (4) no active suppress override targets this AC, (5) AC text matches `[REVIEWER]` prefix. Implemented as `_should_auto_tick(ac, findings, overrides) -> bool` with unit-test parity for each of the five negative cases.
- [ ] Tick fires within the same reviewer scan pass as the verdict block write (single `os.replace`/atomic write; no second pass on the task file). When tick fires, the verdict block reports it explicitly: `Auto-ticked: <count> AC(s)` with each line `- AC #N: <digest-prefix> [<text-excerpt>]`.
- [ ] Sovereignty rail: digest-keyed feedback-stream entry `auto_tick:<task_id>:<ac_index>:<ac_text_digest>` written to `.context/working/feedback-stream.yaml` on every tick. Re-scanning the same task with the same AC and the same `[ ]` state will NOT re-tick if a feedback-stream entry already exists for that `(task, ac_index, digest)` tuple — protects against re-ticking what the human un-ticked.
- [ ] Human ACs are NEVER ticked regardless of prefix or evidence — original T-1443 invariant. Test: a `### Human` AC with text `[REVIEWER] X` and a clean PASS verdict + no findings remains unticked after the scan.
- [ ] Tests: pytest covering — (a) tick fires on clean PASS + [REVIEWER] Agent AC; (b) no tick on FAIL verdict; (c) no tick on AC with matching `ac_index` finding; (d) no tick on already-`[x]` AC; (e) no tick when suppress override targets the AC; (f) no tick on non-[REVIEWER] Agent AC; (g) no tick on Human AC even with [REVIEWER] prefix and clean verdict; (h) re-scan after human-untick respects feedback-stream and does NOT re-tick; (i) digest of AC text changes (AC rewritten) → eligible to tick again under new digest. Target ≥9 tests under `tests/unit/test_reviewer_auto_tick.py`.
- [ ] End-to-end dogfood: this task (T-1985) carries one `[REVIEWER]` Agent AC (this very AC OR a dedicated sentinel one — see #H1); after `bin/fw reviewer T-1985` runs, the targeted AC is auto-ticked, the verdict block reports `Auto-ticked: 1`, and a feedback-stream entry exists.
- [ ] No regression: `bin/fw reviewer audit` (Layer 3 daily Pass-B re-scan) still completes with no new FAIL class introduced; pre-existing `[ ]` AC counts on completed tasks are not retroactively mutated (only mutates active/ tasks).

### Human
- [ ] [REVIEW] Auto-tick rhythm respects sovereignty in a real session — manually `- [x] → - [ ]` un-tick one `[REVIEWER]` AC on a real active task, re-run `bin/fw reviewer T-XXX`, verify it does NOT re-tick (digest cache holds). Then trivially rewrite the AC text (change one word) and re-run — verify it DOES tick (digest changed = fresh consent).
  **Steps:**
  1. Pick any active task with a `[REVIEWER]` Agent AC where the reviewer would PASS (e.g. T-1985 itself after this builds)
  2. Confirm `bin/fw reviewer T-XXX` ticks the AC; note the digest in the verdict
  3. Manually un-tick: `sed -i 's/- \[x\] \[REVIEWER\]/- [ ] [REVIEWER]/' .tasks/active/T-XXX-*.md` for one specific line
  4. Re-run `bin/fw reviewer T-XXX`
  **Expected:** AC stays unticked; verdict reports `Auto-ticked: 0`; feedback-stream still carries the prior digest entry. After step 5 (rewrite AC text), re-run reviewer → AC re-ticks because digest changed.
  **If not:** lift sovereignty rail logic in `lib/reviewer/static_scan.py:_should_auto_tick` — the human-untick path must check feedback-stream before mutating

## Verification

out=$(python3 -m pytest tests/unit/test_reviewer_auto_tick.py -q 2>&1); echo "$out" | tail -3
out=$(python3 -m py_compile lib/reviewer/static_scan.py 2>&1); [ -z "$out" ]
out=$(bin/fw reviewer T-1985 2>&1); echo "$out" | grep -q "Overall:.*PASS"
out=$(bin/fw reviewer audit 2>&1); echo "$out" | tail -5
test -f tests/unit/test_reviewer_auto_tick.py

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

### 2026-05-22T06:48:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1985-t-1950a-reviewer-auto-tick-reviewer-agen.md
- **Context:** Initial task creation

### 2026-05-22T06:51:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)
