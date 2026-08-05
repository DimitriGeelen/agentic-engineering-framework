---
id: T-2719
name: "Keystone: README five-minute path tested by-hand as its own persona"
description: >
  Arc keystone for T-2715 GO item 3. IW-11 reproduced: the README's own five-minute
  walkthrough reaches the T-532 block by instruction, not by misclassification — fw
  init then fw work-on 'Add authentication' then an agent Write hits exit 2 with five
  untouched onboarding tasks listed. The by-hand failure is structurally invisible
  to the agent-assisted test, so the two personas need separate scenarios rather than
  one shared path. Carries the arc's closure Recommendation.

status: started-work
workflow_type: design
owner: agent
horizon: now
tags: [arc:readme-first-run]
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
created: 2026-08-02T00:34:23Z
last_update: 2026-08-05T21:18:22Z
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
  - ts: '2026-08-03T00:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 3
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=3 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-05T21:00:07Z'
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
  - ts: '2026-08-05T21:00:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2719: Keystone: README five-minute path tested by-hand as its own persona

## Context

Arc-016 keystone. Both personas were re-run end to end on 2026-08-05 against the
**published GitHub bytes** (mirror at `970da8a9d`), isolated `HOME`, no global
framework. IW-11 still reproduces, and the re-run found a *second*, distinct
defect that the original framing did not name.

### Persona A — by hand (no agent)

README.md:350-351 step 2 reads:

```
# 2. Try to edit without a task — the gate refuses
#    (You will see the BLOCKED message from §Clear Direction above.)
```

Measured: `echo "some change" > src.txt` → **RC=0, file created**. No block, no
message. The task gate is a Claude Code `PreToolUse` hook
(`.claude/settings.json` → `fw hook check-active-task`); it fires on the *agent's*
Write/Edit/Bash tool calls. A person typing into a terminal is not routed through
it and never can be.

So the walkthrough's one demonstration of the framework's headline property —
"nothing gets done without a task" — **silently no-ops for the persona the
walkthrough is written for.** It does not fail; it produces the opposite of the
documented outcome while looking like nothing happened. This is the arc's thesis
in one line: the by-hand failure is structurally invisible to the agent-assisted
test, because in the agent-assisted run that same step *does* block and the step
is marked correct.

### Persona B — agent-assisted

Steps 1 and 3 exactly as written, then an agent Write:

```
STEP 1  install.sh my-project --provider claude        RC=0
STEP 3  fw work-on "Add authentication" --type build   RC=0, focus=T-006
Write   → BLOCKED  exit 2   Policy: T-532 (Onboarding Enforcement Gate)
```

Reproduced by firing the real `agents/context/check-active-task.sh` against the
seeded fixture — exit 2, five untouched onboarding tasks listed.

**The block is not the defect; the block is correct.** The defect is that it
cannot be cleared. `check-active-task.sh:443-480` requires *every* active
`tags:.*onboarding` task to reach `work-completed`, and the seeded set contains:

| Task | tags | owner | agent can complete? |
|------|------|-------|--------------------|
| T-001 | `[onboarding]` | agent | yes |
| **T-002** | `[onboarding, inception]` | **human** | **no** — human-owned *and* inception |
| T-003/4/5 | `[onboarding]` | agent | yes |

T-002 is unresolvable by the agent twice over: an agent may never tick a `### Human`
AC, and `fw inception decide` refuses under `$CLAUDECODE=1`. So step 3's own
instruction walks the user into a gate whose exit requires an action the assisting
agent is structurally forbidden to take.

That second finding is **arc-017's invariant**, not this arc's ("nothing
`owner: human` or agent-unresolvable may sit in the gated onboarding set"). It is
filed separately rather than fixed here — see Decisions.

### What this task delivers

The persona split, made permanent: the by-hand path gets its own scenario that
runs the README's literal commands and fails loudly when they stop being true.
Scope fence: this task does **not** redesign the onboarding set (arc-017) and does
not touch the T-532 gate.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Both personas are reproduced against **published** bytes (not the working tree)
      under an isolated `HOME` with no global framework, and each result is recorded
      with its exit code — the by-hand edit's RC and the agent Write's RC. A claim that
      a step "works" is not evidence; the RC is.
- [x] README step 2 no longer asserts an outcome the by-hand reader cannot observe.
      Either the step states which persona sees the block, or it is replaced by a
      command a person at a terminal can actually run and see refuse. Verified by
      running the corrected text literally, not by reading it.
- [x] A by-hand persona scenario exists as an executable test that runs the README's
      five-minute commands **extracted from README.md**, not retyped into the test —
      so the test tracks the document rather than a copy of it that can drift.
- [x] The persona test fails loudly when the path regresses, proven by mutation:
      break one README step, watch the test go red, restore it, watch it go green
      (L-530 — a guard that has only ever seen the passing state is evidence it is
      implemented, not that it works).
- [x] The persona test is executed by a runner that actually runs today, verified by
      a `bats --count` delta rather than by file presence (T-2696 — `tests/lint/`
      sat red for 51 days because no runner globbed it).
- [x] The agent-persona dead end (T-002 human-owned + inception inside the gated
      onboarding set) is filed as its own task against arc-017 with the measured
      evidence, and is NOT fixed here (one bug = one task; scope fence above).

**Evidence (measured 2026-08-05):**

| AC | Proof |
|----|-------|
| both personas reproduced | published mirror `970da8a9d`, isolated HOME. By hand: `echo x > src.txt` **RC=0, file created**. Agent: Write → **exit 2**, T-532 |
| step 2 corrected | now demonstrates the *commit* gate, which is git-level and fires for both personas; the edit-time gate is named as agent-only |
| commands extracted | `five_minute_block()` awk-parses the fenced block under the README heading; test 1 is the non-vacuity guard on that extraction |
| fails loudly | mutation: restored the old wording → **test 2 red**; restored → green |
| real runner | `bats --count tests/integration/` **532 with / 528 without = delta 4**; `bin/fw:7827` runs that directory |
| dead end filed | T-2815 (arc-017), with the measured table and a fence against deleting the curriculum |

Two defects surfaced *by* this work and fixed under their own tasks:
**T-2816** (the by-hand persona's only observable gate printed a remedy path no
consumer has) and **T-2817** (`fw init` wrote the framework's origin URL,
credential included, into the new project's tracked `.framework.yaml` — the new
project's first commit was refused by the framework's own secret-scan hook).
Neither was visible from the agent-assisted path.

Also recorded, unfixed: **OBS-170** (fresh machine has no git identity, so the
first governed commit dies RC=128 before any hook runs) and **OBS-171**
(`fw init` refuses a non-existent target and names no path in the error).

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

out=$(bats tests/integration/readme_five_minute_by_hand.bats 2>&1); echo "$out" | grep -q '^ok 4 ' && ! echo "$out" | grep -q '^not ok'
! grep -qE '^#.*(edit|write).*(gate refuses|BLOCKED)' README.md
grep -q '2. Try to commit without a task' README.md
test "$(bats --count tests/integration/readme_five_minute_by_hand.bats)" -eq 4


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

### 2026-08-02T00:34:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2719-keystone-readme-five-minute-path-tested-.md
- **Context:** Initial task creation

### 2026-08-02T00:36:51Z — status-update [task-update-agent]
- **Change:** tags: +arc:readme-first-run

### 2026-08-02T07:26:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0a876f68
- **Timestamp:** 2026-08-02T08:29:40Z
- **Catalogue:** v1.3-seed
- **Overall:** FAIL
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — [First criterion]
  - **empty-body** (severe, deterministic) — `- [ ] [First criterion]`
- **AC#2 (Agent)** — [Second criterion]
  - **empty-body** (severe, deterministic) — `- [ ] [Second criterion]`
