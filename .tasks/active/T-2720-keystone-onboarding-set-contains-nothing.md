---
id: T-2720
name: "Keystone: onboarding set contains nothing the agent cannot resolve"
description: >
  Arc keystone for T-2715 GO item 4. Redesign per IW-13/IW-14/IW-15: keep the agent
  prologue, interleave the human curriculum but leave it UNGATED, route to corpus
  maps rather than embedding content, and enforce the new invariant that nothing owner:
  agenthuman or agent-unresolvable may sit in the T-532-gated onboarding set. Carries
  the arc's closure Recommendation.

status: started-work
workflow_type: design
owner:
horizon: now
tags: [arc:onboarding-curriculum]
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
created: 2026-08-02T00:35:02Z
last_update: 2026-08-08T20:43:52Z
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
  - ts: '2026-08-02T00:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-08T17:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-02T00:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2720: Keystone: onboarding set contains nothing the agent cannot resolve

## Context

Keystone for **arc-017** (`onboarding-curriculum`). From T-2715 GO item 4 (IW-13/14/15).

The arc's headline mechanic has two halves, and they are at very different stages. That was
invisible until now because this keystone sat as an unscoped template — an arc anchor with
placeholder ACs cannot be worked, cannot be closed, and reports nothing about the arc's real
position. Scoped 2026-08-08 against live verification.

**Half B — the refusal invariant — IS BUILT AND PROVEN (T-2815).** Verified live this session,
not taken from the task body:

- `agents/context/check-onboarding-gate.py` exists, is wired at `.claude/settings.json:91`
  via `fw hook check-onboarding-gate`, and **executes** — checked all three states of the
  L-364 chain (present → wired → runs), because two mechanisms this session were present and
  inert.
- Both branches drive correctly against the real hook in a sandbox:
  - `owner: human` + `workflow_type: inception` + `tags:[onboarding]` → **rc=0**, allowed.
    This is the sanctioned escape valve, not a violation.
  - `owner: agent` + `tags:[onboarding]` + unticked `### Human` AC → **rc=2**, refused, naming
    the reason and the `FW_ALLOW_ONBOARDING_UNRESOLVABLE=1` bypass.
- Scan-side exemption is live at `check-active-task.sh:506` (`owner: human` → `continue`).
- Coverage: `check_onboarding_gate.bats`, `onboarding_gate_owner_human_exempt.bats`,
  `t2815_onboarding_e2e_reachable.bats` — **16/16 green, 0 skips**.

Worth recording as a finding in its own right: **T-2815's body says "Fix design (not yet
implemented — see Updates)" while the fix is in fact shipped, wired and covered.** The task
text and the tree disagree, in the safe direction, which is why nobody noticed — a stale
"not implemented" note reads as work remaining, so the cost was duplicated investigation
rather than a false green. Still worth correcting: it is what made this arc look less complete
than it is.

**Half A — the curriculum — is NOT built.** "Agent prologue kept; human curriculum interleaved
and ungated; routes to corpus maps rather than embedding content." No artefact exists yet.

## Acceptance Criteria

### Agent
- [x] Half B verified live end-to-end, not from task text: hook exists, is wired, executes,
      and refuses the agent-unresolvable case while allowing the `owner: human` escape valve
- [x] Both branches of the invariant covered by green bats with zero skips
- [x] T-2815's stale "not yet implemented" note corrected so the tree and the task agree
      (correction block added above the original, which is preserved rather than rewritten;
      shipping commit identified as `0e2eba1fd` by `git log --diff-filter=A`, not inferred)
- [x] Half A scoped into its own build task(s) with real ACs — this keystone does not itself
      carry the curriculum build (arc keystones anchor; slices build) → **T-2877**, tagged
      `arc:onboarding-curriculum`
- [x] Arc-017 status reflects reality: `draft` is wrong once Half B is proven shipped
      → `fw arc start arc-017`, draft → in-progress

**This keystone stays OPEN — and the reason changed on 2026-08-08.**

*Original reason (kept, not rewritten):* Half A is unbuilt, so the arc's headline mechanic
does not yet fire end-to-end. Per §Arc Completion Discipline, "substrate is in place" is not
closure — the mechanic is *operator finishes prologue AND starts their own first real task
with the curriculum readable alongside*, and no curriculum exists. Closing this on Half B
alone would be the exact substrate-vs-deliverable conflation G-062 exists to catch.

*Current reason:* Half A shipped (T-2877, closed 2026-08-08 — 6/6 Agent ACs, 6/6
verification). **Both halves now exist, and the keystone still stays open**, because the
mechanic is a thing an operator *does*, and no operator has done it. This is precisely the
moment G-062 is written for: the temptation to read "both halves built" as closure is
strongest when the substrate is genuinely complete. It is not closure. The two `[REVIEW]`
criteria below are the closure condition, and neither the agent nor any scan can tick them.

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

- [ ] [REVIEW] The curriculum reads well to someone who has never seen the framework

  This is the review that T-2877 should have carried and did not. It was drafted as a Human
  AC on that task, refused by arc-017's own Half B invariant (the T-2881 tag-matching bug),
  and never restored after the bug was fixed — so Half A shipped with no operator review of
  the one thing about it that only an operator can judge. Homed here rather than re-opening
  a closed task.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && for f in lib/seeds/tasks/greenfield/T-00*.md lib/seeds/tasks/existing-project/T-00*.md; do echo "=== $f ==="; sed -n '/^## For the Operator/,/^## Acceptance/p' "$f" | head -n -1; done | less`
  2. Read all eleven sections in order — greenfield first, then existing-project. They are
     written to be read in sequence, as the agent works through the seeded tasks.
  3. Judge them as a newcomer would: does each one tell you what the agent is doing right
     now, why it matters to you, and what you can usefully do while it works?

  **Expected:** the sections read as a colleague explaining what is happening, not as
  documentation of the framework. No section restates what a corpus map already says (they
  should route — `fw corpus explain <id>` — rather than duplicate). Nothing in them asks you
  to tick, approve, or decide anything: the curriculum is meant to be readable *past*, not a
  gate you have to clear.

  **If not:** note the file and the paragraph that reads wrong, and what it should have said
  instead. Prose fixes are cheap and unblocking — file them as one build task against
  `arc:onboarding-curriculum` rather than one task per section.

- [ ] [REVIEW] The headline mechanic actually fires: prologue finished with the curriculum alongside

  This is the arc's closure condition, and until 2026-08-08 it existed only as prose in the
  Agent block above — no unticked box, nothing a `/approvals` view could surface. Written out
  as a criterion so that "arc-017 is not closed" is visible structurally rather than only to
  someone who reads the paragraph.

  **Steps:**
  1. `cd /tmp && rm -rf aef-onboarding-trial && mkdir aef-onboarding-trial && cd aef-onboarding-trial && git init -q && /opt/999-Agentic-Engineering-Framework/bin/fw init`
  2. Work through the seeded tasks in `.tasks/active/` in order, as a new operator would —
     reading each `## For the Operator` section as you reach that step, not in advance.
  3. Then start one real task of your own choosing in that project (`.agentic-framework/bin/fw
     work-on "<something you actually want>" --type build`) and notice whether the curriculum
     left you able to do that without asking anyone.

  **Expected:** you reach your own first real task without needing to ask the agent or read
  `CLAUDE.md` to understand what just happened. That — not "both halves are built" — is the
  mechanic firing.

  **If not:** the gap between "the curriculum explained it" and "I could act on it" is the
  finding. Record which step you stalled at; that step is where Half A is thin, and it is
  worth more than any amount of additional prose elsewhere.

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

### 2026-08-02T00:35:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2720-keystone-onboarding-set-contains-nothing.md
- **Context:** Initial task creation

### 2026-08-02T00:36:51Z — status-update [task-update-agent]
- **Change:** tags: +arc:onboarding-curriculum

### 2026-08-08T17:35:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
