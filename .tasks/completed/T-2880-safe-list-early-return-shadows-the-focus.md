---
id: T-2880
name: "Safe-list early-return shadows the focus-drift gate — pattern 2 unreachable
  since T-2878"
description: >
  is_bash_safe_command exits 0 before the focus-drift gate runs, so safe-listing a
  verb also exempts it from drift attribution. T-2878 safe-listed fw context add-*,
  which is exactly drift pattern 2 — measured: patterns 1 and 3 still reach the gate,
  pattern 2 does not.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/context/check-active-task.sh, 
      tests/unit/drift_gate_not_shadowed_by_safelist.bats]
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
created: 2026-08-08T18:47:34Z
last_update: '2026-08-16T22:25:21Z'
date_finished: 2026-08-08T19:27:34Z
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
  - ts: '2026-08-08T18:52:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 5
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4-5 (body:new-class); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=0
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-08T19:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2880: Safe-list early-return shadows the focus-drift gate — pattern 2 unreachable since T-2878

## Context

`check-active-task.sh:96` exits 0 as soon as `is_bash_safe_command` returns true. The
focus-drift gate lives at line ~305. **So safe-listing a verb also exempts it from drift
attribution** — two questions ("does this need a task?" and "is this attributed to the right
task?") answered by one early return, and only the first one is actually being asked.

T-2878 safe-listed `fw context add-*`. That is exactly **drift pattern 2**. Measured:

| command | reaches drift gate? |
|---|---|
| `bin/fw task update T-9002 --status issues` (pattern 1) | yes |
| `bin/fw context add-learning "x" --task T-9002` (pattern 2) | **NO — safe-listed, exits first** |
| `git commit -m "T-9002: x"` (pattern 3) | yes |

One of the gate's three patterns has been unreachable since T-2878 shipped, this session.
**I introduced this.** Before T-2878 the `context)` arm allowed only `status|focus|init`, so
`add-*` fell through to the drift check as designed.

Discovered while verifying T-2879's pattern-2 anchor: the anchored regex extracts the right
target in isolation, but the end-to-end probe showed no drift for any input — because the
command never reaches the gate. **T-2879's anchor is correct and currently inert. It cannot
fire until this is fixed**, so closing T-2879 on the isolation test alone would be shipping a
fix that provably cannot run — the exact vacuity the anti-vacuity legs exist to prevent.

**Why this is filed rather than fixed in T-2879:** the fix requires reordering the central
governance hook. `CURRENT_TASK` is not read until line 186, *after* the early return, so the
drift comparison cannot simply be hoisted — either the focus read moves up, or the safe
branch stops exiting and instead sets a flag that the later no-active-task and stale-task
checks honour. The second is likely right but changes what safe commands are exempt from at
three separate checkpoints, which is not a change to rush. One bug, one task (§Task Sizing).

**832 has this too.** They vendor our hook and applied the same capture-verb exemption
(their T-390, rail 474 §2), so the same pattern is shadowed on their side. Told them on the
rail rather than leaving it for them to hit.

## Acceptance Criteria

### Agent
- [x] `fw context add-learning "x" --task T-OTHER` reaches the focus-drift gate again and
      blocks, while STILL being allowed with no active task (the T-2878 property must not
      regress — both facts asserted in the same suite)
- [x] The other two drift patterns still fire, and no new block appears for ordinary safe
      commands (`fw doctor`, `git status`, `ls -la`) in the null-task state
- [x] The two questions are separated in the code with a comment saying why: "needs a task"
      and "attributed to the right task" are independent, and one early return answered both
- [x] Teeth by durable mutation of live source (not `git show HEAD~N:` — T-2874), asserting
      the shadowing returns when the reorder is reverted
- [x] T-2879's pattern-2 anchor verified end-to-end once this lands (it is inert until then)

## Measured Behaviour

Probe: real hook, synthetic PROJECT_ROOT injected through the stdin `cwd` re-anchor
(`lib/paths.sh:fw_reanchor_from_cwd`, T-2465) so the live focus is never touched. Every
row measured before and after. `add-learning --task T-9002` with focus `T-9001`:

| focus state | before | after |
|---|---|---|
| null (post-completion) | ALLOW | ALLOW ← T-2878 preserved |
| `T-9001` started-work, session current | **ALLOW** | **BLOCK (drift)** |
| `T-9001`, stale session | ALLOW | BLOCK (stale, remedy `fw work-on`) |
| `T-9001`, not in `active/` | ALLOW | BLOCK (G-013) |
| `T-9001`, status `captured` | ALLOW | BLOCK (status) |

Non-drift-naming safe commands (`fw doctor`, `git status`, `ls -la`, `fw note`,
`fw handover`, `fw context status`, bare `fw context add-learning`) are **unchanged
ALLOW in all five states** — the fast path still short-circuits for them, so the
stale/G-013/status gates are not newly reachable. That is the property that keeps this
from trading one deadlock for another.

## Decisions

### 2026-08-08 — the fix shape: hoist the QUESTION, not the focus read

- **Chose:** extract drift-target detection into `_fw_extract_drift_target()` and call it
  in the Bash fast path *before* the safe-list early return. Safe-listed commands that
  name **no** task exit immediately (unchanged). Safe-listed commands that **do** name one
  record `SAFE_ALLOWED=1` and fall through to the real gate.
- **Why:** the attribution question is *purely syntactic* — it reads the command string and
  nothing else. It never needed focus.yaml, so it never needed to live below the parse at
  line ~186. Once that is seen, no reordering of the hook is required at all.
- **Rejected — (A) hoist the focus read above the fast path.** Moves a filesystem read and
  a YAML parse into the hot path of every safe command, and makes the *safety* verdict
  depend on focus state, which is the coupling that caused this bug in the first place.
- **Rejected — (B) flag honoured at three later checkpoints** (null-focus, stale, G-013).
  832 named the deciding property from the other side (rail 478 §1): B "fails toward
  PERMITTING" because one checkpoint forgetting the flag silently stops enforcement.
  That is this exact bug's failure mode, so it is the one shape not to reach for.
- **The synthesis:** B's mechanism is fine; its *reach* was the problem. `SAFE_ALLOWED` is
  consumed at **one** site (the null-focus branch). A flag read at one place fails toward
  BLOCKING — the deadlock returns loudly with a remedy in the message — rather than toward
  silent permission. Recorded in the code so the next author must invert the argument
  before widening it.
- **Corroborating evidence, and the strongest of it:** line 221-224 of this same file
  already stated the rule, written for T-2054's `git commit` exemption: *"This lives here,
  NOT in `is_bash_safe_command`, on purpose: when focus is NON-null git commit must still
  reach the focus-drift gate — a context-free allowlist entry would short-circuit that."*
  T-2878 broke a rule the file already documented, two hundred lines above where it broke
  it. The fix is obedience to the existing rule, not a new mechanism.

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
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The suite is guarded (T-2738): assert the pass marker AND the absence of failures,
# because the capture form discards bats' exit code.
out=$(bats tests/unit/drift_gate_not_shadowed_by_safelist.bats 2>&1); echo "$out" | grep -q '^ok 11 ' && ! echo "$out" | grep -q '^not ok'
# T-2878 and T-2879 must not regress — this fix touches the same fast path.
out=$(bats tests/unit/capture_verbs_nulltask.bats tests/unit/fd_dup_not_chain_split.bats 2>&1); echo "$out" | grep -qE '^ok 15 ' && ! echo "$out" | grep -q '^not ok'
# The pre-existing drift/focus suites must stay green — 160 assertions over the same hook.
out=$(bats tests/unit/focus_drift_gate.bats tests/unit/check_active_task_switch_focus.bats tests/unit/check_active_task_fp_fix.bats tests/unit/focus_drift_remedy_scope.bats 2>&1); echo "$out" | grep -q '^ok ' && ! echo "$out" | grep -q '^not ok'
# Vendored parity — .agentic-framework/ is what consumers execute (T-2240 self-vendor drift).
diff -q agents/context/check-active-task.sh .agentic-framework/agents/context/check-active-task.sh
# The patterns have ONE definition — the gate consumes, it does not re-derive.
[ "$(grep -c 'fw\[\[:space:\]\]+task\[\[:space:\]\]+update' agents/context/check-active-task.sh)" -eq 1 ]
# LIVE probe: the hook as wired, not a copy. Pattern 2 against a non-focused task blocks.
rc=0; python3 -c "import json;print(json.dumps({'tool_name':'Bash','cwd':'$PWD','tool_input':{'command':'bin/fw context add-learning \"x\" --task T-9999'}}))" | CLAUDECODE=1 bash agents/context/check-active-task.sh >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 2 ]
# LIVE probe: an ordinary safe command is still allowed by that same wired hook.
rc=0; python3 -c "import json;print(json.dumps({'tool_name':'Bash','cwd':'$PWD','tool_input':{'command':'bin/fw doctor'}}))" | CLAUDECODE=1 bash agents/context/check-active-task.sh >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 0 ]

## RCA

**Symptom:** `fw context add-learning "x" --task T-OTHER` ran without complaint while focus
pointed at a different task. Drift pattern 2 — one of the focus-drift gate's three — had
been unreachable since T-2878 shipped earlier the same session. No test failed.

**Root cause:** `check-active-task.sh` used a single `exit 0` in the Bash fast path to
answer two independent questions. *"Does this need an active task?"* is about session
state; *"is this attributed to the right task?"* is about the command string. Safe-listing
a verb answered the first correctly and the second by omission. T-2878 added
`add-learning|add-pattern|add-decision` to the safe-list to fix a real deadlock (completion
nulls focus, and capture is what the framework prescribes at that moment) — and those verbs
are exactly what pattern 2 matches.

**Why structurally allowed:** the two questions are asked ~220 lines apart, and only the
first one has a guard. Nothing in the file made "adding a verb to the safe-list may disable
a drift pattern" visible at the point of the edit — even though line 221-224 already stated
the rule in prose, written for T-2054's `git commit` exemption, which handles the identical
tension correctly and says so. The rule existed; nothing enforced it or surfaced it.

The failure is silent by construction: a gate that stops being consulted produces exactly
the output of a gate that found nothing (L-555). Every one of the 160 existing assertions
over this hook stayed green, because none of them asserted the gate was still *reached* —
they asserted what it did once reached. T-2879's suite was green for the same reason.

**Prevention (distinct from the fix):**
- `tests/unit/drift_gate_not_shadowed_by_safelist.bats` asserts the two properties
  *simultaneously* — drift blocks with focus set, and the same command is allowed with focus
  null. Fixing either alone regresses the other, so the pair cannot be satisfied by
  re-introducing the shadowing.
- Teeth by durable mutation of live source (T-2874), with a **positive control** asserting
  the mutant still reaches the gate — without it the "defect reproduced" leg passes when the
  mutant dies at startup, which is the exact way 832's equivalent probe tested nothing twice
  (rail 477).
- The code now names the two questions and states why `SAFE_ALLOWED` is consumed at one
  site only, so widening it requires inverting a written argument rather than not noticing
  one.
- Not claimed as prevented: the general class. Nothing yet stops the *next* safe-list
  addition from shadowing a *future* gate placed below the fast path. That is G-078's
  territory and this task does not close it.

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

### 2026-08-08T18:47:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2880-safe-list-early-return-shadows-the-focus.md
- **Context:** Initial task creation

### 2026-08-08T18:52:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9ebd7654
- **Timestamp:** 2026-08-08T19:28:14Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats tests/unit/drift_gate_not_shadowed_by_safelist.bats 2>&1); echo "$out" | grep -q '^ok 11 ' && ! echo "$out" | grep -q '^not ok'`

### 2026-08-08T19:27:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
