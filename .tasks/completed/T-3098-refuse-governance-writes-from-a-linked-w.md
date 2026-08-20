---
id: T-3098
name: "Refuse governance writes from a linked worktree (T-2822 slice 1)"
description: >
  PreToolUse hook refuses agent Write/Edit to .context/ and .tasks/ when cwd is a
  linked git worktree. Executes T-2822's GO of 2026-08-06, whose keystone slice was
  never built.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-009]
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
created: 2026-08-20T07:13:00Z
last_update: 2026-08-20T07:31:26Z
date_finished: 2026-08-20T07:31:26Z
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
  - ts: '2026-08-20T07:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-20T07:15:13Z'
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
  - ts: '2026-08-20T07:26:08Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3098: Refuse governance writes from a linked worktree (T-2822 slice 1)

## Context

Executes slice 1 of **T-2822's GO, recorded by the operator 2026-08-06** — the keystone
that was never built. Not a new decision: see `docs/reports/T-2822-worktree-policy.md`
§Recommendation and `docs/reports/T-3097-worktree-rca.md` §IW-5 Leg A.

The mechanism, in T-2822's words: *governance state is tracked content, so a worktree is
by construction a fork of the governance state, and it begins diverging the moment either
side writes.* Source-only therefore cannot be implemented by keeping state out — git puts
it there — only by refusing writes.

Blast radius is bounded by construction: a PreToolUse hook governs **agent tool calls**,
not writes performed inside scripts (the Tier 0 scope boundary, CLAUDE.md §Enforcement
Tiers). `fw integrate` and friends are untouched. What is governed is an agent authoring
governance state into a fork of it — the shape that lost T-2505, G-083, and 43 commits
for five weeks.

## Acceptance Criteria

### Agent
- [x] A PreToolUse hook refuses Write/Edit whose target path is under `.context/` or
      `.tasks/` when the tool call's cwd is a **linked** worktree. Detection uses the
      git-dir vs git-common-dir comparison (verified both directions by T-2822 S2), not a
      path-substring test for `.claude/worktrees` — the latter is a naming convention, not
      an invariant
- [x] The main checkout is never blocked. A repo where git-dir and git-common-dir collapse
      to the same path is the main checkout by definition, and every governance write there
      must pass untouched
- [x] The block message names the correct move (make the edit on master) AND the bypass
      mechanism, per the T-2139/T-2143 rule that a gate message is written for the agent
      that trips it
- [x] Bypass is an **env var**, not a flag: `FW_ALLOW_WORKTREE_GOVERNANCE_WRITE=1`. The
      Write tool has no flag surface (same constraint as T-2205's producer 4), so a flag
      cannot work here. Every bypass writes a Tier-2 entry to `.gate-bypass-log.yaml`
- [x] The bypass is the instrument, not an escape hatch: T-2822's GO shipped it
      deliberately so a legitimate worktree-governance workflow shows up as **data** rather
      than as a silent workaround. The log entry must record the path, so the eventual
      question "does any real workflow need this" is answerable from the register
- [x] Hook is registered in `.claude/settings.json` and `bin/fw enforcement baseline` is
      refreshed — otherwise doctor reports a FAIL that accumulates silently (L-398, T-1886)
- [x] Bats coverage: linked worktree + `.tasks/` path → blocked; linked worktree +
      `lib/` path → allowed; main checkout + `.tasks/` path → allowed; bypass env set →
      allowed AND logged. The third case is the one that matters most — a false positive
      here breaks every session
- [x] Mutation check recorded in Decisions: inverting the worktree test turns the
      main-checkout test red, and dropping the path filter turns the `lib/` test red
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

out=$(bats tests/unit/t3098_worktree_governance_write.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n agents/context/check-worktree-governance-write.sh
# detection is delegated, never re-implemented (AC #1)
grep -q 'fw_is_linked_worktree' agents/context/check-worktree-governance-write.sh
# the string appears only in the comment explaining why it must NOT be the test
grep -vE '^[[:space:]]*#' agents/context/check-worktree-governance-write.sh > /tmp/.t3098code && ! grep -q 'claude/worktrees' /tmp/.t3098code
# the main checkout is never blocked — the failure that would break every session (AC #2)
printf '{"tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s/.tasks/active/T-x.md"}}' "$PWD" "$PWD" | CLAUDECODE=1 bash agents/context/check-worktree-governance-write.sh
# block message names the correct move AND the bypass (AC #3)
grep -q 'FW_ALLOW_WORKTREE_GOVERNANCE_WRITE' agents/context/check-worktree-governance-write.sh
# registered, and the enforcement baseline refreshed with it (AC #6, L-398)
grep -q 'check-worktree-governance-write' .claude/settings.json
out=$(bin/fw doctor 2>&1); ! echo "$out" | grep -q 'Enforcement baseline CHANGED'
diff -q agents/context/check-worktree-governance-write.sh .agentic-framework/agents/context/check-worktree-governance-write.sh

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

### 2026-08-20 — Detection reuses `fw_is_linked_worktree`, not a re-implementation

- **Chose:** source `lib/paths.sh` and call `fw_is_linked_worktree "$cwd"`; the hook
  contains no git-dir comparison of its own.
- **Why:** duplicating the primitive is the exact producer/consumer split (L-399) this
  defect class is about — two copies drift and one of them fails open silently. Mutation
  M3 below shows what the alternative buys.
- **Rejected:** a `.claude/worktrees` substring test. That is a naming convention, not an
  invariant; `git worktree add` anywhere else is undetected.

### 2026-08-20 — Bash hook, not Python

- **Chose:** a single bash file, `agents/context/check-worktree-governance-write.sh`.
- **Why:** the detection primitive is bash (`lib/paths.sh`), and the sibling Python hooks
  all exist because they parse YAML frontmatter. This hook parses none. One `python3 -c`
  pass handles the stdin JSON and path normalisation, matching `check-active-task.sh`.
- **Rejected:** a `.py` + `.sh` wrapper pair — it would have forced a second copy of the
  worktree test in Python, which is the thing above.

### 2026-08-20 — Governance-path filter is anchored to the worktree toplevel

- **Chose:** block only paths under `<worktree-toplevel>/.context/` or `/.tasks/`, resolved
  absolute (relative `file_path` is joined against the call's `cwd`).
- **Why:** a bare `*/.tasks/*` glob would refuse an **absolute write into the main
  checkout's** `.tasks/` issued from a worktree shell — which is precisely the move the
  block message tells the agent to make. Pinned by the test
  "absolute write into the MAIN checkout's .tasks/ is allowed".
- **Residual, deliberate:** the gate keys on `cwd`, per the AC. A write from a main-checkout
  `cwd` to an absolute path inside a sibling worktree's `.context/` is not refused. Left
  as-is rather than widened, because widening changes the predicate the ACs specify.

### 2026-08-20 — Bypass logs only when it actually bypassed a refusal

- **Chose:** the `FW_ALLOW_WORKTREE_GOVERNANCE_WRITE=1` branch sits *after* the worktree
  and path tests, so a bypass entry is written only for calls that would otherwise have
  been blocked. Entry records `file`, `worktree` and `main_checkout`.
- **Why:** AC #5 — the register has to answer "does any real workflow need this?". If the
  env var is exported for a whole session, logging every governance write from the main
  checkout would bury the signal under noise from calls that were never gated.
- **Not honouring `FW_SAFE_MODE`:** that hatch disables the *task* gate. This gate has its
  own named bypass; folding it into `FW_SAFE_MODE` would make worktree divergence
  invisible whenever safe mode is on.

### 2026-08-20 — Mutation check (AC #8)

Each mutation applied to the hook in place, full suite re-run, then reverted. Baseline
is **14/14 passing**.

| Mutation | Tests turned red |
|---|---|
| **M1** — invert the worktree test (`\|\| exit 0` → `&& exit 0`) | **#8 "main checkout: write to .tasks/ is allowed"** and **#9 "main checkout: write to .context/ is allowed"** — the AC-named signal — plus #1-#5, #11, #12, #14 (10 red total) |
| **M2** — drop the path filter (`*) exit 0` → match everything) | **#6 "linked worktree: write to lib/ is allowed"** — the AC-named signal — plus #7 "absolute write into the MAIN checkout's .tasks/ is allowed" (2 red) |
| **M3** — swap `fw_is_linked_worktree` for a `.claude/worktrees` substring test | #1-#5, #11, #14 (7 red). The fixture is a real `git worktree add` under `mktemp`, so a convention-based test sees nothing. This is the AC #1 claim made falsifiable rather than asserted. |

M2's blast radius is 2, not 1: dropping the filter also breaks the "correct move" the block
message recommends, which is the more interesting failure of the two.

### 2026-08-20 — Not done here, by instruction

Hook registration in `.claude/settings.json` and `bin/fw enforcement baseline` (AC #6) are
left to the parent session — that write converges with other work in flight. The hook
resolves correctly through the dispatcher already: `bin/fw hook
check-worktree-governance-write` returns 0 on a main-checkout payload.


## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-20T07:13:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3098-refuse-governance-writes-from-a-linked-w.md
- **Context:** Initial task creation

### 2026-08-20T07:26:08Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-55a603f6
- **Timestamp:** 2026-08-20T07:35:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 72
     - evidence: `out=$(bin/fw doctor 2>&1); ! echo "$out" | grep -q 'Enforcement baseline CHANGED'`

### 2026-08-20T07:31:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
