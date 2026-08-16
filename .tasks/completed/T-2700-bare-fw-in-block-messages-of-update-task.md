---
id: T-2700
name: "bare fw in block messages of update-task.sh and check-active-task.sh"
description: >
  tests/lint/no-bare-fw-in-gate-scripts.bats tests 1 and 8 (red, unrun until T-2697):
  both scripts emit bare 'fw ...' in agent-facing block messages, violating CLAUDE.md
  Copy-Pasteable Commands (bare fw may resolve to a stale global shim; framework repo
  wants bin/fw, consumers .agentic-framework/bin/fw). check-active-task.sh is the
  gate agents trip most often, so its message is the most-read text in the framework.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/update-task.sh, bin/fw, 
      tests/lint/no-bare-fw-in-gate-scripts.bats, 
      tests/lint/no-orphaned-test-dirs.bats]
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
created: 2026-07-31T09:22:42Z
last_update: '2026-08-16T22:25:14Z'
date_finished: 2026-07-31T09:40:25Z
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
  - ts: '2026-07-31T09:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T09:30:13Z'
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
  - ts: '2026-08-16T22:25:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 4
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2700: bare fw in block messages of update-task.sh and check-active-task.sh

## Context

Filed from the T-2697 triage: two tests in `tests/lint/no-bare-fw-in-gate-scripts.bats` are
red, having never run. Inspecting the six flagged lines splits them three ways:

| line | flagged as | actually |
|------|-----------|----------|
| `update-task.sh:305` `FW_…=1 fw task update …` | bare fw | **real** — a copy-pasteable command |
| `update-task.sh:552` `fw inception decide …` | bare fw | **real** — a copy-pasteable command |
| `update-task.sh:164`, `:1377` | bare fw | **false positive** — already `bin/fw`; `\bfw\b` matches inside `bin/fw` because `/` is a word boundary |
| `update-task.sh:681`, `:683`, `check-active-task.sh:366`, `:367` | bare fw | **false positive** — prose *about* the command ("Works for: fw task update, fw context add-*"), not a command to run |

So the invariant is right and the detector is wrong in two independent ways. The second is
L-519 from the other side: this time a text match flagged prose *describing* a command as if
it were the command. Same root inability, opposite sign.

Two real offenders is a genuine hygiene defect — CLAUDE.md §Copy-Pasteable Commands exists
because bare `fw` may resolve to a stale global shim, and `update-task.sh` messages are read
mid-gate when the reader is already blocked.

## Acceptance Criteria

### Agent
- [x] The two real offenders emit `bin/fw`, so every command in a block message is
      copy-pasteable in the framework repo
- [x] The detector no longer flags `bin/fw` — matching inside the very form it wants is a
      false positive that makes the guard un-actionable
- [x] The detector distinguishes a **command** from **prose about a command**: it fires only
      when the message's command position starts with `fw`, not when a sentence mentions a
      verb. Prose stays prose; the four prose lines above are not rewritten to satisfy a
      scanner
- [x] **Negative controls, run:** re-introducing a bare `fw` command turns the test red, and
      adding a prose mention of `fw task update` does not
- [x] `bats tests/lint/no-bare-fw-in-gate-scripts.bats` is 14/14 (13 original + a self-test
      for the command-vs-prose distinction, which is the guard's whole value)

## Third confusion, found by running it

After fixing the two known false-positive classes, the detector still flagged
`check-active-task.sh`. The hit was `case "fw hook "*|"bin/fw hook "*)` — a **dispatch
pattern matching an incoming command line**, not a message telling anyone to run anything.
The rewrite had widened extraction to every quoted string in the file; the original at least
scoped to lines containing `echo`.

So one detector held three variants of the same confusion: it must not merely find the text
`fw`, it must find it **where a human is being told to type it**. Extraction is now scoped to
emitting lines, comments excluded, and the match is positional.

Left deliberately unflagged: `echo "  1. Run this: fw task update …"` — a command preceded by
prose in the same string. Weaker form, not chased, because the fix would be to over-match
sentences again.

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

test "$(timeout 90 bats tests/lint/no-bare-fw-in-gate-scripts.bats 2>&1 | grep -c '^not ok')" = "0"
out=$(timeout 90 bats tests/lint/no-bare-fw-in-gate-scripts.bats 2>&1); echo "$out" | grep -q "distinguishes a command from prose"
bash -n agents/task-create/update-task.sh

## RCA

**Symptom:** two red tests asserting no bare `fw` in gate-script messages — red, and unrun
until T-2697 wired the directory in.

**Root cause, two independent halves.** The *invariant* was being violated: two block
messages in `update-task.sh` emitted pasteable commands starting with bare `fw`, which may
resolve to a stale global shim. The *detector* was also wrong, and in three ways — it matched
`fw` inside `bin/fw` (`/` is a word boundary, so it flagged the exact form it wanted), it
could not tell a command from a sentence mentioning one, and after the first rewrite it
matched a `case` dispatch pattern.

**Why structurally allowed:** a guard with a high false-positive rate is not a weaker guard,
it is an *unusable* one — the only way to satisfy it was to stop mentioning `fw` in prose, so
the honest response to it was to ignore it. That it was also unrun (T-2697) meant nobody had
to decide.

**Prevention:** the rule is positional rather than lexical — within an emitted string, after
whitespace, a list marker and any `ENV=value` prefixes, does the *command position* start
with `fw `? Prose is left alone. The distinction carries a self-test in the same file, since
it is the guard's entire value, plus negative controls verifying a bare command goes red and
a prose mention does not.

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

### 2026-07-31T09:22:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2700-bare-fw-in-block-messages-of-update-task.md
- **Context:** Initial task creation

### 2026-07-31T09:33:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ad8c9efd
- **Timestamp:** 2026-07-31T09:40:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-31T09:40:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
