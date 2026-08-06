---
id: T-2842
name: "three honoured settings are absent from the config registry"
description: >
  three honoured settings are absent from the config registry

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [lib/config.sh, web/blueprints/config.py]
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
created: 2026-08-06T21:42:07Z
last_update: 2026-08-06T21:50:12Z
date_finished: 2026-08-06T21:50:12Z
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
  - ts: '2026-08-06T21:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T21:45:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 3
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2842: three honoured settings are absent from the config registry

## Context

Three settings are read by shipped code with documented defaults, are described
in CLAUDE.md §Configuration, and are absent from `lib/config.sh`
`FW_CONFIG_REGISTRY`:

| Key | Read at | Default |
|-----|---------|---------|
| `FW_BRANCH_BEHIND_WARN` | `agents/handover/handover.sh:301,303` | 50 |
| `FW_STALE_ARC_DAYS` | `agents/audit/audit.sh:768` | 30 |
| `FW_RETIRE_WHEN_ADVISORY` | `agents/audit/audit.sh:859` | 1 |

Consequence: `fw config list` does not list them, `fw config set` cannot persist
them to `.framework.yaml`, and Watchtower `/config` does not show them. They are
settable only as environment variables — which contradicts CLAUDE.md's own
4-tier resolution contract (flag > env > `.framework.yaml` > default), because
the `.framework.yaml` tier does not exist for these keys.

Found by T-2841, which inverted `config-registry-parity` test 2 from "every
registry key must be in CLAUDE.md" to "CLAUDE.md must not name a key the
registry lacks". The old direction could not have found these: all three *are*
documented — that was never the problem. The first run of the new direction
surfaced all three.

One root cause, three instances: a setting was added to code and to the docs
without the registry entry that makes it configurable. Sibling to T-2838, where
keys had a registry entry but no UI row.

## Acceptance Criteria

### Agent
- [x] All three keys are in `lib/config.sh` `FW_CONFIG_REGISTRY` with the
      defaults the consuming code actually uses (50 / 30 / 1) — read from the
      call sites, not from CLAUDE.md, so a doc/code disagreement surfaces rather
      than being copied forward.
- [x] All three appear in `web/blueprints/config.py` `SETTINGS`, keeping
      `config-registry-parity` tests 1 and 3 green (key sets and counts agree).
- [x] The registry entries are live on a user-visible surface: `/config` renders
      all three, verified after a Watchtower restart.

      **This AC originally read "`fw config get` returns the documented default
      for each key".** That was wrong about the CLI, not about the code:
      `fw config get` reports only explicitly-set values and returns empty for
      *every* registry key including `PORT`, and `fw config list` prints only
      the `.framework.yaml` custom settings. Neither surfaces defaults, so
      neither could ever have proven what the AC claimed. Rewritten to assert
      against the surface that does show them. The `get`/`list` semantics are
      pre-existing and unchanged by this task — noted, not touched.
- [x] `config-registry-parity` test 2 (phantom direction) passes: CLAUDE.md
      names no key the registry lacks. 3/3 green.
- [x] Defaults in code, registry, and CLAUDE.md agree for all three — checked
      pairwise against the call sites; no disagreement found.

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

- [ ] [REVIEW] The /config table still reads well at 25 rows

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url` — open the printed URL with `/config` appended
  2. Read the whole table top to bottom, not just the new rows
  3. Look at the last six rows (the five added by T-2838 and T-2842)

  **Expected:** The table grew from 20 to 25 rows across two tasks today. It
  should still scan as one list rather than a wall — consistent row height, no
  column collapsing under the longer description text, and the newest entries
  not visually orphaned at the bottom.

  **If not:** Say whether the problem is length (needs grouping or sectioning)
  or width (needs column re-proportioning). Grouping would be a follow-on task,
  not a tweak — the current template renders one flat list by design.

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

bash -n lib/config.sh
python3 -c "import ast; ast.parse(open('web/blueprints/config.py').read())"
out=$(bats tests/lint/config-registry-parity.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
curl -sf "$(bin/fw watchtower url)/config" -o /tmp/t2842-config.html && grep -q "BRANCH_BEHIND_WARN" /tmp/t2842-config.html
curl -sf "$(bin/fw watchtower url)/config" -o /tmp/t2842-config.html && grep -q "STALE_ARC_DAYS" /tmp/t2842-config.html
curl -sf "$(bin/fw watchtower url)/config" -o /tmp/t2842-config.html && grep -q "RETIRE_WHEN_ADVISORY" /tmp/t2842-config.html

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

**Recommendation:** GO

**Rationale:** Three settings the code already honours become configurable and
visible. No behaviour changes: the defaults written into the registry were read
from the call sites (`${FW_BRANCH_BEHIND_WARN:-50}`, `${FW_STALE_ARC_DAYS:-30}`,
`${FW_RETIRE_WHEN_ADVISORY:-1}`), so an unset key resolves exactly as before.
The whole invariant suite is green for the first time in this session's memory —
51/51. The open Human AC is about table legibility after five rows were added
today, not about correctness.

**Evidence:**
- `lib/config.sh` `FW_CONFIG_REGISTRY` 22 → 25 entries; `web/blueprints/config.py`
  `SETTINGS` matched, so parity tests 1 and 3 stay green.
- `tests/lint/config-registry-parity.bats` 3/3; full `tests/lint/` 51/51, zero red.
- `/config` renders all three, verified live after a Watchtower restart.
- One AC was rewritten mid-task after `fw config get` turned out not to report
  defaults for *any* key. The original AC could never have passed; that is
  recorded in the AC itself rather than quietly swapped.

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

### 2026-08-06T21:42:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2842-three-honoured-settings-are-absent-from-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9c01446a
- **Timestamp:** 2026-08-06T21:50:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-06T21:50:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
