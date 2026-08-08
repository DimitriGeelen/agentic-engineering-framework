---
id: T-2815
name: "Gated onboarding set contains an agent-unresolvable task (T-002 human+inception)"
description: >
  T-532 onboarding gate (check-active-task.sh:443-480) requires every active tags:onboarding
  task to reach work-completed before any other work. The seeded set contains T-002
  'Define project goals' with tags [onboarding, inception] and owner: human.
  An agent may never tick a ### Human AC, and fw inception decide refuses under CLAUDECODE=1
  — so the exit condition of the gate is an action the assisting agent is structurally
  forbidden to take. Measured 2026-08-05 against published bytes: fw init then fw
  work-on 'Add authentication' then agent Write returns exit 2, five onboarding tasks
  listed, no agent-reachable path to clear it. Arc-017's stated invariant: nothing
  owner:human or agent-unresolvable may sit in the gated onboarding set.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:onboarding-curriculum]
components: [agents/git/lib/hooks.sh]
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
created: 2026-08-05T20:52:27Z
last_update: 2026-08-05T23:34:44Z
date_finished: 2026-08-05T23:34:44Z
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
  - ts: '2026-08-05T21:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-05T21:00:14Z'
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
---

# T-2815: Gated onboarding set contains an agent-unresolvable task (T-002 human+inception)

## Context

Root cause confirmed by reading `agents/context/check-active-task.sh:438-486` and the
seed template `lib/seeds/tasks/greenfield/T-002-define-project-goals.md` directly (not
run live this session — see Updates for why). The onboarding gate's scan (line 448:
`grep -q '^tags:.*onboarding'`) treats ANY active task carrying the substring
`onboarding` in its tags as blocking until `status: work-completed`, with zero owner
or workflow_type check. T-002 ships `owner: human`, `workflow_type: inception`,
`tags: [onboarding, inception]`, an `### Agent` AC that itself requires
`fw inception decide T-002 go` (blocked for agents under `$CLAUDECODE=1`, T-1259/T-1260),
and an `### Agent`+`### Human` split where the Human AC can never be ticked by an agent.
No agent-reachable path exists to flip T-002 to `work-completed` — the gate is a
structural deadlock for any agent-only session.

> **CORRECTION (T-2720, 2026-08-08) — the "not yet implemented" below is STALE.**
> The work shipped in this task's own close commit `0e2eba1fd`, which created
> `agents/context/check-onboarding-gate.py` and wired it at `.claude/settings.json:91`.
> The heading was written during design and never updated when the work landed.
>
> Verified live under T-2720, all three states of the L-364 chain (present → wired →
> executes): `owner: human` + inception + onboarding → rc=0 allowed (sanctioned escape);
> `owner: agent` + onboarding + unticked `### Human` AC → rc=2 refused. Scan-side
> exemption live at `check-active-task.sh:506`. Coverage 16/16 green, 0 skips across
> `check_onboarding_gate.bats`, `onboarding_gate_owner_human_exempt.bats`,
> `t2815_onboarding_e2e_reachable.bats`.
>
> Left in place rather than rewritten, so the design record and the correction both
> survive. The error direction was safe — a stale "not implemented" reads as work
> remaining, so it cost duplicated investigation rather than a false green — but it
> made arc-017 look less complete than it is.

**Fix design (not yet implemented — see Updates):**
1. **Gate scan exclusion** — in `check-active-task.sh`'s onboarding loop, skip tasks
   whose frontmatter has `owner: human` when building `INCOMPLETE_ONBOARDING`. This
   alone unblocks T-002 without touching its content — "readable but never blocking".
2. **Retag, don't delete, to preserve intent-signalling** — keep `tags: [onboarding, inception]`
   on T-002 (still discoverable via `fw task list --tag onboarding`, still surfaced by
   `fw onboarding status`) rather than removing the tag; owner is already the
   correct discriminator so no new tag vocabulary is needed.
3. **Structural invariant guard (new PreToolUse check, likely extending
   `check-active-task.sh` or a sibling hook alongside `check-arc-id.sh`)** — when
   Write/Edit targets `.tasks/{active,completed}/T-*.md` and the resulting frontmatter
   has `tags:` containing `onboarding` AND `owner` is NOT `human`, but the task is
   otherwise agent-unresolvable (`workflow_type: inception`, or body contains an
   unticked `### Human` AC subsection) — refuse (exit 2), naming the task id and the
   specific reason (inception-decide-blocked / human-ac-present). This is the
   complementary case the scan-exclusion in (1) does NOT cover: an onboarding task
   that claims `owner: agent` but is still structurally stuck.
4. **Both-states proof (L-530, AC3)** — add two bats fixtures under
   `tests/unit/`: (a) an onboarding-tagged, `owner: human`, `workflow_type: inception`
   task → confirm the gate SKIPS it (doesn't block) and the new PreToolUse guard does
   NOT refuse it (owner:human is the sanctioned escape valve, not a violation); (b)
   an onboarding-tagged, `owner: agent` task with an unticked `### Human` AC → confirm
   the guard DOES refuse it. This exercises both the "exempted" and "genuinely broken"
   branches so the invariant is falsifiable, not just documented.
5. **End-to-end AC1 proof** — a bats/integration test that runs `fw init` (or
   reuses the existing greenfield seed fixture) then simulates `CLAUDECODE=1` +
   `fw work-on "..."` + an agent Write to a non-onboarding file, asserting exit 0
   once T-002 is the only remaining incomplete onboarding task.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The gated set's exit condition is reachable by the agent alone, demonstrated by
      running the seeded set to completion under `$CLAUDECODE=1` — not by arguing that
      it should be. Whatever the fix (ungate T-002, split it, make the curriculum
      non-blocking), the proof is a clean run from `fw init` to a non-onboarding Write
      that succeeds.
      Evidence: `tests/unit/t2815_onboarding_e2e_reachable.bats` seeds a real project
      via `fw init`, flips T-001/T-003/T-004/T-005 to `work-completed`, leaves T-002
      untouched (`owner: human`, `status: captured`), and asserts the PreToolUse gate
      returns exit 0 on a Write to a non-onboarding file. Passes; proven to fail
      without the fix (reverted `check-active-task.sh`, re-ran, got exit 2 / "Onboarding
      tasks incomplete... T-002").
- [x] The invariant is enforced structurally, not documented: adding an `owner: human`
      or otherwise agent-unresolvable task to the gated onboarding set is refused at
      the point it is added, with a message naming which task and why.
      Evidence: `agents/context/check-onboarding-gate.py` (wired via `check-onboarding-gate.sh`,
      registered PreToolUse Write|Edit in `.claude/settings.json`) refuses Write/Edit on
      `.tasks/{active,completed}/T-*.md` when `tags:` contains `onboarding`, `owner != human`,
      and the task is agent-unresolvable — block message names the task id and reason
      (`inception-decide-blocked` / `human-ac-present`).
- [x] The invariant guard is proven to fire — a deliberately human-owned onboarding
      fixture is refused, and an all-agent set passes (L-530 both-states rule).
      Evidence: `tests/unit/check_onboarding_gate.bats` (11/11 pass) exercises both
      states directly on the hook — owner:human PASSES (test 3), owner:agent+inception
      and owner:agent+unticked-Human-AC both BLOCK (tests 4, 5), owner:agent all-Agent-AC
      PASSES (test 6). `tests/unit/onboarding_gate_owner_human_exempt.bats` (4/4 pass)
      exercises the same both-states split on the gate SCAN in `check-active-task.sh`.
- [x] Sovereignty is preserved: the human curriculum still exists and is discoverable.
      The fix must not delete the operator's onboarding content to satisfy a gate —
      arc-017's mechanic is "readable but never blocking", not "removed".
      Evidence: `lib/seeds/tasks/greenfield/T-002-define-project-goals.md` was not
      touched by this task — its content, `tags: [onboarding, inception]`, and
      `owner: human` are unchanged. Only the gate SCAN in `check-active-task.sh` was
      edited to skip `owner: human` tasks when computing `INCOMPLETE_ONBOARDING` (a
      `continue` in the tag-matching loop, not a tag/content removal). The e2e test
      (AC1 evidence above) asserts T-002's `owner: human` / `status: captured` are
      still present in the seeded project's task file after the proof runs — it still
      exists, is still tagged `onboarding`, and still requires a human
      `fw inception decide T-002 go|no-go|defer` to close.

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

out=$(bats tests/unit/check_onboarding_gate.bats 2>&1); echo "$out" | grep -q "^ok 11 " && ! echo "$out" | grep -q "^not ok"
out=$(bats tests/unit/onboarding_gate_owner_human_exempt.bats 2>&1); echo "$out" | grep -q "^ok 4 " && ! echo "$out" | grep -q "^not ok"
out=$(bats tests/unit/t2815_onboarding_e2e_reachable.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
out=$(bats tests/unit/greenfield_seed_audit_prototype.bats tests/unit/check_active_task_cwd_resolution.bats tests/unit/check_active_task_memory_exempt.bats 2>&1); echo "$out" | grep -q "^ok " && ! echo "$out" | grep -q "^not ok"
bin/fw enforcement baseline

## RCA

**Symptom:** A fresh `fw init` project handed to an agent-only session deadlocks
immediately: `fw work-on 'Add authentication'` then a Write to any non-onboarding
file returns exit 2 forever, because T-002 (seeded `owner: human`,
`workflow_type: inception`, `tags: [onboarding, inception]`) never reaches
`work-completed` — no agent action can make it do so.

**Root cause:** `check-active-task.sh`'s onboarding-gate scan (T-535) treated
every active task carrying the `onboarding` tag as equally blocking, regardless
of `owner`. It never distinguished "an onboarding task the current agent session
can finish" from "an onboarding task only a human can finish" — the scan checked
tag + status only, not resolvability.

**Why structurally allowed:** T-532/T-535 were written for the common case
(agent completes the curriculum solo) and never had a fixture exercising the
`owner: human` seed (T-002) in combination with the gate's blocking branch.
Nothing tested the *set*, only individual onboarding subcommands (`fw onboarding
status`).

**Prevention:** (1) the gate scan now skips `owner: human` tasks when building
`INCOMPLETE_ONBOARDING` (`check-active-task.sh`); (2) a new PreToolUse hook
(`check-onboarding-gate.py`) refuses the complementary drift — an onboarding
task that claims `owner: agent` but is still agent-unresolvable (inception
workflow_type or an unticked `### Human` AC) — so the exemption in (1) can't be
used to smuggle a real deadlock past the scan; (3) `tests/unit/t2815_onboarding_e2e_reachable.bats`
pins the end-to-end path with a real `fw init` seed and is proven to fail
without the fix (verified by reverting `check-active-task.sh` and re-running).

## Evolution

### 2026-08-06 — implementation session
- **What changed:** The prior dispatched session (2026-08-05) had already done
  the root-cause read and written the 5-step fix design into `## Context`
  before hitting budget-critical with zero code changes. This session executed
  that design as written — no material deviation. The one addition not
  explicit in the original design: printing the raw `reason` code
  (`inception-decide-blocked` / `human-ac-present`) on its own stderr line in
  the new hook's block message, so the reason is grep-able by both humans and
  the bats fixtures without depending on prose wording.
- **Plan impact:** None — steps 1-5 in `## Context` were implemented as
  specified, including the both-states bats fixtures (step 4) and the AC1
  end-to-end proof (step 5).
- **Triggered:** No new sub-tasks. `.claude/settings.json` required
  `fw hook-enable` (not a direct Write) to register the new hook — B-005
  blocks agent Write/Edit on that file — and `bin/fw enforcement baseline`
  was re-run per L-398 since the hook set changed.
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

### 2026-08-05T20:52:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2815-gated-onboarding-set-contains-an-agent-u.md
- **Context:** Initial task creation

### 2026-08-05T21:XX:XXZ — root-cause + design captured, budget-critical stop [worker-dispatch]
- **Action:** Read `check-active-task.sh:438-486` and the T-002 seed template directly;
  confirmed the root cause and wrote a concrete 5-step fix design into `## Context`
  above. Did NOT implement — this dispatched worker session hit budget-gate critical
  (~96% of context window) before any code edit, and the gate structurally restricts
  Write/Edit to `.context/`/`.tasks/`/`.claude/` at that level. No source file was
  touched; no test was run; status remains `captured`.
- **Output:** Design in `## Context` above, ready for the next session/dispatch to
  implement directly (all file paths, line numbers, and test-fixture shapes specified).
- **Context:** Redispatch or resume with a fresh budget to execute steps 1-5 in Context.
  Do not mark this task `work-completed` from this analysis alone — none of the four
  Agent ACs have evidence yet.

### 2026-08-05T21:53:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6bbd2f5b
- **Timestamp:** 2026-08-05T23:35:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats tests/unit/check_onboarding_gate.bats 2>&1); echo "$out" | grep -q "^ok 11 " && ! echo "$out" | grep -q "^not ok"`

### 2026-08-05T23:34:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
