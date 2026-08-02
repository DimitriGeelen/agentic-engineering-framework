---
id: T-2725
name: "Audit validate-init hook-path check across ALL carrier shapes, not just the one measured"
description: >
  Audit validate-init hook-path check across ALL carrier shapes, not just the one measured

status: started-work
workflow_type: test
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
created: 2026-08-02T06:29:29Z
last_update: 2026-08-02T06:29:29Z
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

# T-2725: Audit validate-init hook-path check across ALL carrier shapes, not just the one measured

## Context

Direct application of 832's rail-379 finding to our side, on a fix we shipped an hour ago.

Their measurement: a rule that fires on N carriers had its behaviour declared against the
ONE carrier whatever fixture was to hand happened to exercise. `E-LANE-FIELD` was "repaired"
per the `height` carrier and wrong for `id` and `authority`; `E-NODE-FIELD` likewise. Correct
for exactly the carrier the fixture omitted, wrong for 6 of the other 8 — "not coincidence,
the fixture IS what was measured." Their question to us, verbatim in substance:

> for each entry, WHICH input was it measured against, and how many others does that rule
> fire on?

T-2724 is a live instance in the making. The `hookpaths-6vc` / `func-paths` checks extract a
script with `next((p for p in parts if '=' not in p), '')` and then test it for existence.
That selector fires on **every hook command shape**, but the fix was verified against exactly
one: `${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <event>`, because that is the shape
`fw init` writes and therefore the shape my fixture had.

The concrete worry, unmeasured at filing: a command of the form
`bash ${CLAUDE_PROJECT_DIR}/scripts/foo.sh` selects `bash` as the "script", and
`os.path.exists('bash')` is False — so a perfectly valid wrapper-style hook would be reported
broken as `bash`, the exact failure mode T-2724 just fixed for the `fw` case, surviving under
a different carrier. Whether that shape occurs anywhere is the thing to measure rather than
assume; either answer is worth having written down.

This task measures every carrier shape present in the framework's own settings.json, its seed
templates, and the vendored copy, and states the check's verdict per shape — the per-carrier
verdict map 832 recommended, rather than a prose note that cannot fail.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every hook-command carrier shape present in the repo is enumerated with counts and a
      worked example — see the per-carrier map below
- [x] For each shape, the token the selector actually tests is recorded — not the token a
      reader would assume it tests
- [x] The check's verdict is stated per shape (correct / false-positive / false-negative),
      and any shape where the verdict is wrong is either fixed or filed with the reason it
      was left — shape D was a false positive and is fixed via PATH resolution
- [x] The wrapper-command shape is absent from the repo today; recorded explicitly below as
      an *occupancy* zero — reachable but unoccupied — rather than left to read as "cannot
      happen" (rail 378/379 vocabulary, OBS-124)
- [x] Result is committed as a durable per-carrier record, not left as terminal output —
      the table below plus two pinning tests in
      `tests/unit/validate_init_hook_path_expansion.bats`

## Per-carrier verdict map

Measured 2026-08-02 across every tracked `settings.json` and both generators
(`lib/init.sh`, `lib/upgrade.sh`).

| # | Carrier shape | Occurrences in repo | Token the selector tests | Verdict before T-2725 |
|---|---------------|--------------------|--------------------------|----------------------|
| A | `${CLAUDE_PROJECT_DIR}/…/fw hook <ev>` | 25 (all of `.claude/settings.json`) | `${CLAUDE_PROJECT_DIR}/bin/fw` → expanded | correct (as of T-2724) |
| B | absolute path | 0 | the path itself | correct |
| C | relative path | 0 | the path itself | correct |
| D | bare command / wrapper (`bash …`, `python3 …`) | **0** | `bash` | **FALSE POSITIVE** — fixed here |
| E | env-prefixed (`FOO=1 /path/x`) | 0 | first non-`=` token | correct (selector already skips `FOO=1`) |

**Shape D is an occupancy zero, not a capability zero.** Nothing prevents a user or a future
generator from writing `bash ${CLAUDE_PROJECT_DIR}/scripts/guard.sh` as a hook — it is a
perfectly ordinary shape. It simply does not occur in this repo today. Recorded as reachable
so a later reader does not promote "0 occurrences" to "cannot happen", which is the precise
failure 832 flagged at rail 378 and we filed as OBS-124.

**One false alarm, declared** (their "measure the control before the case" discipline): the
generators do contain bare `npx`, `python3` and `termlink` commands, and I initially read
those as live instances of shape D. They are `.mcp.json` MCP server definitions, which this
validator never reads. The shape-D finding stands on its own mechanics — `os.path.exists('bash')`
is False while `shutil.which('bash')` resolves — not on those occurrences.

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

### 2026-08-02T06:29:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2725-audit-validate-init-hook-path-check-acro.md
- **Context:** Initial task creation
