---
id: T-3128
name: "the framework has a canonical list of its own self-churning paths and one consumer
  uses it"
description: >
  the framework has a canonical list of its own self-churning paths and one consumer
  uses it

status: captured
workflow_type: build
owner: agent
horizon: next
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
created: 2026-08-24T20:31:10Z
last_update: '2026-08-25T22:45:13Z'
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
  - ts: '2026-08-24T20:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=251,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-24T20:45:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-24T22:32:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-25T22:45:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3128: the framework has a canonical list of its own self-churning paths and one consumer uses it

## Context

Two consumer projects reported the same symptom independently, four days apart, on trees
with no shared history: the main checkout is permanently dirty on exactly the paths a
landing operation must touch, so `git merge --ff-only` and `fw integrate` abort on files
nobody edited.

- 001-CashWeb (T-102 / their G-023): measured seven tracked collision paths; the abort
  named two.
- 832-Workflow-designer (chat-arc offset 350), unasked and explicitly not filing a
  duplicate: same seven-path shape present on open, "none of it written by us, none of it
  committed by its writer". They do not use worktrees, so nothing aborts for them — the
  precondition is simply visible.
- This tree, verified here rather than relayed: 22 tracked files modified under `.context/`
  with no session edit; `agents/audit/audit.sh` writes `.context/audits/<DATE>.yaml`,
  `metrics-history.yaml`, `feedback-stream.yaml` and the monitor JSONLs, and contains no
  `git add` or `git commit` for any of them.

So 832 is right that this is a property of the framework's writers, not of any repo's
history. It reproduces wherever the audit cron runs.

**But the sharper finding is what is already in the tree.** `agents/audit/audit.sh:3045`
defines `_SESSION_STATE_FILTER` — a canonical regex naming precisely these self-churning
paths (`working/watchtower.*`, `session.yaml`, `focus.yaml`, `.session-metrics.yaml`, the
counters, `audits/`, `monitors/`, ephemeral `approvals/`, `project/metrics-history.yaml`,
`locks/`). T-1392 built it. It is used in exactly one place: the audit's own "uncommitted
changes" check, which is why the audit cheerfully reports *"Working directory clean (22
session-state file(s) churning, ignored)"* while a landing on the same tree aborts on those
same 22 files.

The defect is therefore not "the framework does not know which of its files are noise" —
it knows, precisely, in one regex. The defect is that the knowledge shipped to one consumer
and no other. That is the producer/consumer parity class (L-399, T-1890): a contract
implemented on one side only, where the second side's failure looks like an unrelated bug.

Note the direction of the fix matters. Making the writers commit their own records is the
obvious reading and is probably wrong — it would put a commit on every cron tick and put
audit records into the history of every landing. Lifting the existing list into a shared
library and teaching the landing path to consume it keeps the churn uncommitted, which is
what it should be.

Sibling of T-2831 (worktree remove refuses on dirt) but a different axis: T-2831 is about
dirt that is *real uncommitted work* being destroyed by the `--force` its refusal trains
toward. This is about dirt that is *definitionally noise* blocking an operation that has no
business reading it.

### Refinement from 001-CashWeb (chat-arc 365-368) — a filter is the wrong shape

The framing above, and the ACs below, assume the answer is a *filter*: one list, one binary
question, ignore-or-abort. 001-CashWeb's measurement says that is too coarse, and checking it
here rather than taking it on report confirms it. `.context/working/feedback-stream.yaml` is
dirty on this tree right now, is **not** in `_SESSION_STATE_FILTER`, and is a **4155-document**
YAML stream. It is not noise. Both sides genuinely append to it, so ignoring the local copy
during a landing silently discards whatever this session wrote.

So the self-churning paths are three kinds, not one:

| Kind | Right behaviour on a landing | Examples |
|------|------------------------------|----------|
| **Noise** — regenerated or ephemeral, no cross-session content | Ignore | counters, `watchtower.{pid,log}`, `locks/` |
| **Accumulating record** — both sides append independently | **Union merge on a content key**, never take-one-side | `feedback-stream.yaml`, `metrics-history.yaml`, the monitor JSONLs, `audits/` |
| **Regenerated pointer** — rewritten whole each time | Newer-wins by an **in-file** timestamp | `handovers/LATEST.md` |

CashWeb's union patch on feedback-stream keys on `(kind, timestamp, scan_id, task_id)` and was
measured against both real sides: 80 docs local, 130 on the branch, 132 in the union, with
*every* one-sided record surviving in both directions and no duplicates. They also make the
point that a naive test passes against the discard-one-side bug, so the test has to assert
both directions — a fixture where each side holds a document the other lacks.

Two consequences for the ACs below, which were written before this and are wrong as stated:

- **AC1 is insufficient.** Lifting `_SESSION_STATE_FILTER` verbatim into a library propagates a
  binary answer to a three-way question. The shared thing should be a *classification* — path →
  kind — with the current filter recoverable from it as "kind == noise".
- **AC3 is unsafe for the accumulating class.** "Do not abort when the only dirty paths match
  the list" is right for noise and actively destructive for `feedback-stream.yaml`: proceeding
  without merging drops this session's appended records with no error.

### The list is anchored to the wrong prefix

Found while checking this tree for uncommitted work before a handover, so it is a live
instance and not a hypothetical: `docs/reports/T-1549-escalation-scan-v0.md` is a tracked
file, rewritten by a cron scan (`Run:` and `Corpus:` lines advanced 2026-08-22 → 2026-08-24,
2718 → 2732 tasks), and never committed by its writer. Textbook self-churn.

But `_SESSION_STATE_FILTER` is anchored `^\.context/`. A self-churning path under `docs/` is
not merely absent from the list — it is outside the regex's reach by construction, so adding
it would require changing the anchor, not just the alternation. That means the list's *shape*
encodes an assumption ("all framework self-churn lives under `.context/`") that is already
false, and every audit of the list against reality will keep coming back clean while missing
this class, because the check inherits the same anchor.

Worth stating as its own AC6 clause: the reality-check must scan the whole tracked tree for
paths that change without a session edit, not just `.context/`. A list that can only find
what it already covers is the proxy-vs-property class again (T-1828, T-3125, T-3126) — the
instrument and the claim share a blind spot, so the measurement can never contradict it.

CashWeb also self-corrected an over-claim in the same thread: they had said `LATEST.md` was the
next blocker, then opened it and found it clean locally, so it is not. Recorded because the
design guidance for the regenerated-pointer class survives the correction and is worth having
before we rule that path — and specifically the note that newer-wins must not compare mtime,
since the merge itself rewrites the file.

## Acceptance Criteria

### Agent
- [ ] AC1 — (REVISED after the CashWeb refinement above; the original wording said "lift `_SESSION_STATE_FILTER` verbatim", which propagates a binary answer to a three-way question.) A shared library holds a *classification* — path pattern → kind ∈ {noise, accumulating, regenerated} — with the existing filter recoverable as "kind == noise". `audit.sh` consumes it, and its uncommitted-changes verdict is byte-identical before and after the lift.
- [ ] AC2 — Enumerate every consumer that reads working-tree dirtiness and decides something on it (`fw integrate`, `fw worktree remove`/`gc`, the pre-push hooks, `fw sync`, doctor's branch hygiene). For each, record whether it currently honours the list, and whether it *should* — some legitimately must refuse on any dirt. Write the table into the task body. Do not change a consumer you cannot justify.
- [ ] AC3 — (REVISED — the original "do not abort when dirty paths match the list" is right for noise and destructive for the accumulating class.) The landing path no longer aborts on `noise` paths; **merges** `accumulating` paths rather than taking either side; resolves `regenerated` paths newer-wins by an in-file timestamp, never mtime (the merge rewrites the file, so mtime records when git touched it). Real dirt outside the classification still aborts, unchanged.
- [ ] AC3b — The merge is asserted in BOTH directions. A test where each side holds a record the other lacks must show both surviving — a discard-one-side bug passes a naive one-sided test. Reference measurement from 001-CashWeb on `feedback-stream.yaml`: 80 docs local, 130 branch, 132 union, no duplicates, round-trips through `safe_dump_all`.
- [ ] AC4 — When the landing path proceeds past session-state dirt, it says so: names how many paths it ignored and where the list lives. Silence here would make a skipped abort indistinguishable from no dirt at all.
- [ ] AC5 — Regression test in its own fixture tree (L-599 — do not pin to this repo's current dirty state, which is the live defect and will be cleaned): (a) only-session-state dirt → land proceeds; (b) one real dirty file → aborts; (c) both → aborts; (d) the list is read from the shared definition, so a test that edits the shared list changes both consumers. Report how many tests fail against pre-change code.
- [ ] AC6 — The list itself is checked against reality: every path in the regex is confirmed to be written by a framework writer that does not commit it, and any self-churning tracked path found NOT in the list is either added or recorded as a deliberate exclusion.
- [ ] AC6b — The reality-check scans the WHOLE tracked tree, not just `.context/`. `_SESSION_STATE_FILTER` is anchored `^\.context/`, and at least one self-churning tracked file lives outside it (`docs/reports/T-1549-escalation-scan-v0.md`, rewritten by a cron scan, never committed). A check that inherits the list's own anchor can only ever find what the list already covers — the instrument and the claim would share a blind spot, and the measurement could never contradict the assumption. Record every path found this way with its writer.

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
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-08-24T20:31:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3128-the-framework-has-a-canonical-list-of-it.md
- **Context:** Initial task creation

### 2026-08-24T20:32:35Z — status-update [task-update-agent]
- **Change:** horizon: next → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-08-24T22:01:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-08-24T22:02:17Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-08-24T22:32:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-08-24T22:33:16Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)
