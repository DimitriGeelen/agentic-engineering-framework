---
id: T-2708
name: "Watchtower decision commit guard self-blocks on batched decisions"
description: >
  Watchtower decision commit guard self-blocks on batched decisions

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-07-31T12:19:16Z
last_update: '2026-07-31T12:30:10Z'
date_finished:
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
  - ts: '2026-07-31T12:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T12:30:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=2 (body:default-change); D4=2 
      (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2708: Watchtower decision commit guard self-blocks on batched decisions

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Mechanism proven arithmetically against the REAL predicate
      (`_is_decision_file`) and the REAL staged paths, not reasoned about — each
      decision's "1 unrelated staged file" is shown to be the OTHER decision's file
- [x] The operator's two GO decisions (T-2703, T-2704) committed and pushed, so the
      recorded-but-uncommitted state is cleared rather than left for later
- [x] Fix implemented so a decision commit cannot be blocked by, or leave behind,
      staged state — build a commit from a temporary index (`GIT_INDEX_FILE`) so the
      operator's real index is never read and never written
- [x] Regression test: two consecutive decisions in one batch both commit, proven by
      driving `_commit_decision` twice and asserting two commits exist
- [x] Regression test: a decision commit that FAILS leaves the index exactly as it
      found it (no staged residue to poison the next decision)
- [x] Pre-existing unrelated staged work is still not swept into a decision commit —
      the property the current guard was protecting must survive the fix

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

test -f web/blueprints/inception.py
git log --oneline -20 | grep -q "T-2708"
python3 -m pytest tests/unit/test_decide_commit.py -q


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

**Symptom.** Operator recorded two GO decisions through the Watchtower. Both were
written to disk correctly — `## Decision`, full rationale, timestamp,
`status: work-completed`, `owner: human`. Neither was committed. Both reported:
`Decision recorded but not committed: index has 1 unrelated staged file(s);
skipped to avoid bundling`.

**Root cause — the "unrelated" file was the other decision.** `_commit_decision`
(`web/blueprints/inception.py:707`) guards against bundling by rejecting any staged
path that fails `_is_decision_file(task_id, path)` — a predicate that only recognises
the single task id it was called with. Run against the real staged paths:

    deciding T-2703: foreign=1 -> ['.tasks/completed/T-2704-...md']
    deciding T-2704: foreign=1 -> ['.tasks/completed/T-2703-...md']

Two decisions taken six seconds apart in one operator batch are, to each other,
indistinguishable from an agent session concurrently staging unrelated work. The
guard is right that *something else* is in the index and wrong that it is unrelated:
it is the same artifact class, produced by the same flow, in the same batch.

**Why it cannot self-clear.** `git add` (:766) runs BEFORE `git commit`, and nothing
rolls it back if the commit fails. So a decision that stages and then fails leaves
its files in the index permanently. The guard then refuses every subsequent decision,
because the residue of the previous failure is exactly the "foreign" state it
protects against. **The guard converts a transient condition into a permanent one for
the rest of the batch** — one stuck decision guarantees all later ones stick too.
That is the antifragility inversion: the failure mode strengthens itself.

**Why structurally allowed.** The guard was written (T-2053) for the single-decision
case, where the only other writer is a concurrent agent session. Batch operator
review — the normal way an operator clears a queue — was never a modelled input. The
protection is real and worth keeping; its predicate is just scoped to one task while
the operator works in sets.

Compounding it: the commit is a WHOLE-INDEX commit by design (documented at :772-775,
because a pathspec commit was believed unable to capture the active→completed
deletion). Whole-index committing is what forces a foreign-staging guard to exist at
all. The guard is a consequence of the commit strategy, not an independent choice.

**Not established.** Which of the two decisions first left residue, and why its own
commit failed, is not directly observable: the Watchtower serving :3001 logs
elsewhere, and `.context/working/watchtower.log` ends at 10:14Z, before the 12:16Z
decisions. Two candidate origins — (a) the first decision staged, its commit failed,
residue blocked the second; (b) a genuine race, both flows interleaving between
status-read and add. **The fix below must handle both, and does, because it removes
the shared index as a channel entirely.** Recording this as unresolved rather than
picking the tidier story.

**Recommended fix — never touch the operator's index.** Build the decision commit
against a temporary index (`GIT_INDEX_FILE` pointing at a scratch file seeded from
`git read-tree HEAD`). Then:

- foreign staged state is irrelevant, because the real index is never read;
- a failed commit cannot leave residue, because the real index is never written;
- batched decisions stop blocking each other, with no weakening of the anti-bundling
  property the guard exists to provide — unrelated work is excluded by construction
  rather than by refusal.

The alternative (`git commit --only -- <old> <new>`) is smaller but keeps using the
shared index and needs the deletion-capture claim in the docstring tested rather than
inherited; a first attempt at that test was inconclusive (malformed invocation) and
should be redone before choosing.

**Prevention (distinct from the fix).** Two regression tests, both of which fail
against current code: (1) two consecutive decisions in one batch both produce
commits; (2) a decision whose commit fails leaves the index byte-identical to how it
found it.

**Immediate remediation.** Both GO decisions committed and pushed in
`dc49f8c84` — the recorded-but-uncommitted state is cleared. The defect that caused
it is not fixed; that is the remaining work on this task.

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

### 2026-07-31T12:19:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2708-watchtower-decision-commit-guard-self-bl.md
- **Context:** Initial task creation
