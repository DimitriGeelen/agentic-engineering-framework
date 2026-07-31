---
id: T-2707
name: "T-2702 backticks in inline python disarmed the budget gate"
description: >
  T-2702 backticks in inline python disarmed the budget gate

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
created: 2026-07-31T11:53:50Z
last_update: 2026-07-31T11:53:50Z
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

# T-2707: T-2702 backticks in inline python disarmed the budget gate

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Substitution proven EMPIRICALLY, not argued: a stubbed `fw` on PATH is shown to
      be executed by the committed comment text, and the multi-line-stdout case is
      shown to raise `SyntaxError` inside the python block
- [x] Root cause traced to the exact commit and lines (T-2702,
      `agents/context/budget-gate.sh:152-155`) and blast radius stated in terms of
      what the gate then does — fails open
- [x] Comment-only fix applied: plain quotes replace backticks. No regex, threshold or
      allowlist logic changed; T-2702's actual behaviour fix stays intact
- [x] Tree swept for the same class and every genuine remaining instance fixed
      (`bin/fw:3981`). Escaped backticks (`\``) correctly NOT treated as defects
- [x] Guard `tests/lint/no-backticks-in-inline-python.bats` proven RED against the
      committed bytes (names all four offending lines) and GREEN after the fix
- [x] Guard carries negative controls in BOTH directions: it detects a planted
      backtick, and it does not fire on deliberate `$(...)` / `$VAR` interpolation
- [x] Guard's own first draft false-positived (line-based bounding leaked into shell
      comments across `bin/fw`); corrected to character-level bounding, with the
      reason recorded in the guard file itself rather than only in this task

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

bats tests/lint/no-backticks-in-inline-python.bats
bash -n agents/context/budget-gate.sh
bash -n bin/fw
out=$(bats tests/lint/no-backticks-in-inline-python.bats 2>&1); echo "$out" | grep -q "ok 2 negative control"


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

**Symptom.** `agents/context/budget-gate.sh` is a PreToolUse hook on Write/Edit/Bash,
so it runs on essentially every tool call. Since T-2702 it silently shelled out to
`fw context focus`, `fw context focus T-XXX`, `context init` and `context focus` on
every invocation — and when focus was set, its main python block died outright.

**Root cause.** `budget-gate.sh:119` opens `RESULT=$(echo "$INPUT" | python3 -c "`.
That is a DOUBLE-quoted bash string, so bash expands its contents before python
starts. T-2702 added an explanatory comment inside that string using markdown-style
backticks (`fw context focus T-XXX`, `context init`, `context focus`). Bash read them
as command substitution. Proven, not inferred: with a stub `fw` on PATH the repro
emits `STUB: fw EXECUTED with args: context focus T-XXX`.

**Why it is worse than a stray subprocess.** The substitution splices the command's
STDOUT into the python source text. `fw context focus` with no args is a *reporting*
form that prints two lines, so the second line lands as bare python:

    File "<string>", line 6
        Task: Compaction UX: budget messages must be allowed for the same reason...
    SyntaxError: invalid syntax

The block dies, RESULT is empty, and the gate takes its fail-open path. **The budget
gate was disarmed for the life of the T-2702 commit** — the control that is supposed
to stop a session overrunning its context window.

**Why structurally allowed.** Three things lined up. (1) A shell comment and a python
comment look identical; the *quoting context*, not the `#`, decides whether the text
is inert. Everywhere else in these scripts `# ...` genuinely is inert, so the habit is
safe right up until it is not. (2) The failure is silent by construction: the hook
still exits 0, hook stderr is not routinely surfaced, and a disarmed gate looks
exactly like a gate with nothing to complain about. (3) It was introduced by a task
whose entire purpose was to make this gate more correct, so it arrived carrying the
credibility of a fix.

Same class this session keeps producing: an action reporting success about the wrong
thing. Sibling to `fw test web` (right command, wrong noun), `--replay` (right digest,
wrong file), and 832's `grep "0 failed"` matching `10 failed`.

**Prevention.** `tests/lint/no-backticks-in-inline-python.bats`, collected by
`bin/fw test invariants`. Deliberately narrow (L-527): backticks only, only inside
double-quoted `python3 -c` bodies, escaped backticks excluded, `$(...)` untouched
because it is nearly always deliberate interpolation. Proven RED on the committed
bytes before being trusted GREEN, with negative controls in both directions.

**Honest note on the guard.** Its first draft used line-based bounding, never closed
the block, and reported every later *shell* comment in `bin/fw` as a defect — noise
that would have got it ignored, exactly the L-527 failure it exists to avoid. The fix
rests on a real invariant: inside `python3 -c "..."` a bare `"` cannot appear in the
python source, so the first unescaped `"` is always the terminator.

**Credit.** Found by the T-2705 TermLink worker while editing adjacent lines. I wrote
the defect and did not see it; the worker reported it as an aside to its own task.

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

### 2026-07-31T11:53:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2707-t-2702-backticks-in-inline-python-disarm.md
- **Context:** Initial task creation
