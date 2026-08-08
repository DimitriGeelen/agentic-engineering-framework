---
id: T-2878
name: "Capture verbs unreachable in the state completion creates — note, context add-*,
  handover"
description: >
  Capture verbs unreachable in the state completion creates — note, context add-*,
  handover

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
created: 2026-08-08T18:00:40Z
last_update: '2026-08-08T18:15:12Z'
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
  - ts: '2026-08-08T18:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-08T18:15:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=3 (body:fw-recall-or-memory-link); F-AUTONOMY=0 (no-signal); F3=1
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2878: Capture verbs unreachable in the state completion creates — note, context add-*, handover

## Context

`fw task update --status work-completed` nulls `current_task` and moves the file to
`completed/`. The Bash task gate then refuses every verb the framework asks for **in exactly
that state**:

| verb | state after completion | who asks for it |
|------|------------------------|-----------------|
| `fw note "..."` | BLOCKED | §Error Escalation Ladder, observation capture |
| `fw context add-learning` | BLOCKED | update-task.sh prints "LEARNING PROMPT" *at completion* |
| `fw context add-pattern/add-decision` | BLOCKED | §Bug-Fix Learning Checkpoint |
| `fw handover [--commit]` | BLOCKED | §Session End Protocol, "do not end a session without" |

Measured against `is_bash_safe_command` (not read from the case statement): all four GATED,
while `fw task create` and `fw context focus` are ALLOWED. The `context` arm admits only
`status|focus|init`; there is no `note` or `handover` arm at all.

`fw handover` is the sharpest: budget-gate explicitly permits it at critical because it is the
wrap-up path, and the *task* gate refuses it anyway. Two gates, opposite verdicts, same command.

**Origin: 832 rail 474 (their T-390), verified here before adopting.** Hit twice in this
session without being recognised as a class — `fw vendor self` blocked immediately after
closing T-2875, and the `add-learning` capture needing a focus bypass.

**The shape, which is the real finding (832's G-026).** Three exemptions now exist and every
one arrived the same way:

- T-2052 `fw task create` — the gate's own advice is *"create a task"*, which it refused
- T-2054 `git commit` — completion nulls focus, but the completion still needs committing
- this task — completion nulls focus, and the framework asks for a learning in that breath

**The gate blocks the action its own advice depends on.** Each instance is something the
framework prescribes as the response to having just completed work, and completing work is
precisely the transition that nulls focus. The deadlock is generated by the state machine, so
further instances should be expected rather than hoped against.

And it is **G-077 in the opposite polarity**: G-077 is a DENY-list that cannot be closed by
enumeration because it cannot name every dangerous idiom; this is an ALLOW-list that cannot be
closed by enumeration because it cannot name every harmless one. Both grow only by field
discovery, both silent. Between the T-2054 fix and now, `fw note` was unreachable
post-completion and nothing reported it — **a blocked capture verb leaves no record of having
been wanted.** The omission cannot report itself.

This task ships the third instance, NOT the remedy for the shape. Registered separately.

## Acceptance Criteria

### Agent
- [x] `fw note`, `fw context add-learning|add-pattern|add-decision|generate-episodic`, and
      `fw handover` are allowed with `current_task: null`
- [x] Safety argument holds: each writes only under `.context/` or `.tasks/`, both already
      exempt paths for Write/Edit, and none can author source
- [x] WIDENING CONTROL — `fw config set` and other non-capture `fw` verbs stay BLOCKED. A fix
      that degraded into a blanket `fw` allowance emits identical ALLOWED rows for the capture
      verbs and cannot be distinguished by reading the case statement
- [x] bats coverage with an anti-vacuity leg mutating live source (not a `git show HEAD~N:`
      ref, which goes inert on the next commit — T-2874)
- [x] Gap registered for the SHAPE, with a closure condition stating that adding these three
      verbs does not satisfy it

## STATUS: FIX APPLIED — S-2026-0808-2019+1

Applied verbatim as composed below, vendored (`bin/fw vendor self`, confirmed present in
`.agentic-framework/agents/context/lib/safe-commands.sh`), and pinned by
`tests/unit/capture_verbs_nulltask.bats` — 7/7 pass, no skips.

Measured end-to-end against the real hook in the actual post-completion state (focus nulled,
`active/` empty): `fw note`, `fw handover` and all four `fw context add-*`/`generate-episodic`
verbs exit 0; `fw config set FW_PORT 3001` and `rm -rf` still exit 2. The two controls are the
only thing separating this from a blanket allowance, so they carry the weight of the fix.

Gap **G-078** registered for the SHAPE, with the closure condition stated explicitly: adding
these six verbs does NOT close it — that is the same fix applied for the third time (T-2052,
T-2054, this), and it is what left the shape intact after the first two.

**The change as applied** — `agents/context/lib/safe-commands.sh`, in
`_fw_single_command_is_safe`'s `fw_sub` case (the `context)` arm is at ~line 179):

```
                        status|focus|init)
```
becomes
```
                        status|focus|init|add-learning|add-pattern|add-decision|generate-episodic)
```

and two new sibling arms alongside `context)` / `task)`:

```
                note)
                    return 0
                    ;;
                handover)
                    return 0
                    ;;
```

Verb-scoped deliberately, **not** a blanket `context)` or `fw` allowance — a fix that widened
too far emits identical ALLOWED rows for these five and cannot be told apart by reading the
case statement. That is what the `fw config set` control exists to catch, and it is the leg I
would not skip.

**Then:** `bin/fw vendor self` (this file is vendored), and a bats suite
`tests/unit/capture_verbs_nulltask.bats` with: the five capture verbs ALLOWED; `fw config set`
and `rm -rf` still GATED (widening + anti-vacuity controls); teeth by mutating live source.

## RCA

**Symptom:** every verb the framework asks for at completion — `fw note`, `fw context add-*`,
`fw handover` — is refused in the state completion creates, because `--status work-completed`
nulls `current_task`.

**Root cause:** the safe-list enumerates *command names*, and the enumeration is grown only
when someone is blocked by its absence.

**Why structurally allowed:** a blocked capture verb leaves no record of having been wanted.
`fw note` was unreachable post-completion from the T-2054 fix until 832 hit it — the omission
cannot report itself, so nothing accumulated toward noticing. This is G-077's polarity
inverted: a deny-list that cannot name every dangerous idiom, and an allow-list that cannot
name every harmless one, both maintained by field discovery.

**Prevention:** the three verbs are the third instance, not the remedy. 832's unproposed
observation is the honest state of the art — all three exemptions share an unstated predicate
(*writes confined to already-exempt paths*), which would have admitted all three with nobody
blocked first, but a command's write-set is not statically knowable in general, which is the
G-077 problem a third time. Naming that is worth more than shipping a rule with the same hole
in a nicer shape.

## Evidence: the budget gauge under-reported by ~178K (fail-open)

Recorded here because the capture verbs it belongs in are blocked — by budget-gate, and by the
very defect this task fixes. The observation about unrecordable observations was, once again,
unrecordable.

`.context/working/.budget-status` read `{"level": "ok", "tokens": 116729}` at 1786211780. On
the next source Edit, budget-gate refused at **~294,439 tokens (98%, critical)**. Same session,
minutes apart, no compaction between. Earlier in the session the same gauge went 213,917 → 64,395
and 263,915 → 116,729.

The framework's own `/resume` rule names `.budget-status` as the **canonical** source and warns
against inferring budget from anything else. Acting on it as instructed, I began a source edit
at 98%. The error direction is **fail-open**: it under-reports, so it permits work that should
be refused. A gauge that over-reported would merely nag.

Not filed as a task from here — filing needs verbs I cannot reach at critical. Next session:
verify against the transcript-size source in `budget-gate.sh` / `checkpoint.sh`, then file.
Suspicion, unverified: the gauge reads a session transcript that rotates or is truncated, so it
measures the current file rather than cumulative context.

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

# 1. The suite, exit-code-preserved and guarded (T-2738: "3 failed, 9 passed" satisfies a
#    bare pass-grep). Carries the ALLOWED legs, both controls, and the anti-vacuity leg.
out=$(bats tests/unit/capture_verbs_nulltask.bats 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok"
# 2. Vendored parity — this file is vendored, and a fix that lives only in agents/ is not
#    the file consumers execute (T-2240 self-vendor drift class).
grep -q "add-learning|add-pattern|add-decision|generate-episodic" .agentic-framework/agents/context/lib/safe-commands.sh
# 3. The SHAPE is registered, not just the instance. AC 5.
bin/fw gaps > /tmp/.t2878g 2>&1 && grep -q "G-078" /tmp/.t2878g
# 4/5. LIVE end-to-end through the real hook in the actual post-completion state (focus
#    nulled, active/ empty) — one allow, one control. `|| rc=$?` is required: the hook exits
#    2 by design, which aborts the line under the gate's `set -e` before the assertion runs
#    (T-2743 — rehearsed with `bash -c 'set -eo pipefail; <line>'`, not by hand).
r=$(mktemp -d); mkdir -p "$r/.tasks/active" "$r/.tasks/completed" "$r/.context/working"; printf "current_task:\n" > "$r/.context/working/focus.yaml"; rc=0; printf "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bin/fw note add x\"}}" | CLAUDECODE=1 PROJECT_ROOT="$r" CONTEXT_DIR="$r/.context" TASKS_DIR="$r/.tasks" bash agents/context/check-active-task.sh > /tmp/.t2878a 2>&1 || rc=$?; test "$rc" -eq 0
r=$(mktemp -d); mkdir -p "$r/.tasks/active" "$r/.tasks/completed" "$r/.context/working"; printf "current_task:\n" > "$r/.context/working/focus.yaml"; rc=0; printf "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bin/fw config set FW_PORT 3001\"}}" | CLAUDECODE=1 PROJECT_ROOT="$r" CONTEXT_DIR="$r/.context" TASKS_DIR="$r/.tasks" bash agents/context/check-active-task.sh > /tmp/.t2878b 2>&1 || rc=$?; test "$rc" -eq 2

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

### 2026-08-08T18:00:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2878-capture-verbs-unreachable-in-the-state-c.md
- **Context:** Initial task creation
