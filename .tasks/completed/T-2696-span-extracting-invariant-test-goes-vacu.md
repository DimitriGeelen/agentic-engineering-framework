---
id: T-2696
name: "span-extracting invariant test goes vacuous on a rename (832 T-312 class)"
description: >
  tests/lint/single-vendor-writer.bats bounds the step-4b span on the named successor '4c.'. Renaming that header runs the sed range to EOF (36 lines becomes 806) where the presence assertion passes on a comment. The test is also misnamed: it claims '4b uses do_vendor not inline cp' but never checks for cp. Bound structurally, assert both directions, add a negative control.

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-07-31T09:03:16Z
last_update: 2026-07-31T09:13:27Z
date_finished: 2026-07-31T09:13:27Z
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

# T-2696: span-extracting invariant test goes vacuous on a rename (832 T-312 class)

## Context

832 passed on a failure mode from their T-312 (rail 345): a scan that extracts a span of
source and asserts something about it, bounded on a **named successor**, silently swallows
anything inserted between — going wrong or vacuous with no signal. I said I would sweep for
it here rather than just acknowledge it. One real hit.

`tests/lint/single-vendor-writer.bats:25` bounds step 4b on the literal `4c.`:

```
step4b=$(sed -n '/4b.*Vendored/,/4c\./p' lib/upgrade.sh)
echo "$step4b" | grep -q 'do_vendor'
```

Measured, not theorised — renaming the 4c header to `── 4c-shim: Shim migration`:

| | span length | assertion |
|---|---|---|
| today | 36 lines | passes on step 4b's real `do_vendor` call |
| after rename | **806 lines** (range runs to EOF) | passes on a **comment** at line 1815 |

So a header rename nobody would flag as risky turns this into a test that cannot fail. It
lands on a comment, so it is also an L-519 instance: a text match cannot distinguish code
from prose about that code.

Second defect, independent: the test is named *"step 4b uses do_vendor **not inline cp**"*
and never checks for `cp` at all. It asserts one direction of a two-direction invariant.

## Acceptance Criteria

### Agent
- [x] The 4b span is bounded on a **structural** terminator (the next step header of any
      name), so inserting or renaming a step cannot silently widen it
- [x] A guard asserts the extracted span stays plausibly sized, so total-vacuity (range
      running to EOF) fails loudly instead of passing on distant content
- [x] The test asserts **both** directions its name claims: `do_vendor` present AND no
      inline per-file copy in the span — the invariant is "delegates, does not enumerate"
- [x] Comments are excluded before matching, so the assertion cannot be satisfied by prose
      describing the call (L-519, fifth and sixth instances were this same shape)
- [x] **Negative control:** the corrected test goes red when step 4b's `do_vendor` call is
      replaced with an inline copy, and red when the 4c header is renamed — both verified by
      running it, not by reading it
- [x] The rest of the span-extracting scans in the repo are checked and the result recorded
      — including the ones that turn out fine, since "we looked" is the finding when a sweep
      comes back mostly clean

## Negative controls (run, not reasoned about)

Mutations applied to a scratch copy of `lib/upgrade.sh`:

| control | mutation | old test | new test |
|---------|----------|----------|----------|
| A | rename `── 4c. Shim` → `── 4c-shim: Shim` | green (span→806 lines, matched a comment) | **red** (bound guard) |
| B | replace 4b's `do_vendor` with `cp -r` | green | **red** (copy guard) |
| C | **insert** a step doing `cp -r` between 4b and 4c — 832's exact trap | **green** | **red** |

Control C is the demonstration: on the precise mutation 832 described, the old test reports
success and the new one fails.

## Sweep result — the other span-extracting scans

Nine other range extractions exist. **Eight are already bounded structurally and need no
change**, which is worth recording as a result rather than a silence:

| site | bound | verdict |
|------|-------|---------|
| `tests/lint/help-router-parity.bats` ×2 | `esac`, `^}` | safe — block terminators |
| `tests/unit/install_scan.bats`, `disposition_gate.bats` ×6 | `^}$` | safe |
| `tests/unit/audit_d13_inception_limbo.bats` | heredoc `D13EOF` | safe |
| `tests/unit/create_task_inception_recommendation_gate.bats` | `^## ` (any heading) | safe |
| `tests/unit/test_approvals_style_tokens.py` | `</style>` | safe |
| `tools/corpus_overlay.py` | `splitlines()[0]` | not a span |
| `tests/unit/gaps_close.bats:83` | `^- id: G-TEST-B` — **named successor** | low risk: both markers are fixtures the test writes itself, so nothing external can be inserted between them. Left as-is deliberately. |

**Separate finding, filed as its own task (T-2697):** `tests/lint/` is not wired into any
runner. `fw test lint` runs shellcheck, not this directory — a name collision that explains
why nobody noticed. Seven tests across four of its seven files are currently red, one of
them since 2026-06-10. Found while running this test; out of scope here.

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

# NOTE: tests/lint/ is orphaned from every runner (T-2697) — run it explicitly.
out=$(bats tests/lint/single-vendor-writer.bats 2>&1); echo "$out" | grep -q "span is bounded"
test "$(bats tests/lint/single-vendor-writer.bats 2>&1 | grep -c '^not ok')" -le 1
# The old named-successor bound must not come back. Comments stripped first:
# the file quotes the banned pattern in the comment explaining why it is banned,
# and a bare grep matches that prose (L-519, 7th instance — caught by this very
# command failing on its first run). Strip, do not reword, do not allowlist.
# The `\\?` matters: the banned form appears in shell as `/4c\./` (escaped dot),
# so a pattern without it silently matches nothing — its own negative control
# caught that before this shipped.
test "$(grep -vE '^[[:space:]]*#' tests/lint/single-vendor-writer.bats | grep -cE '4c\\?\.')" = "0"

## RCA

**Symptom:** an invariant test that cannot fail. `tests/lint/single-vendor-writer.bats`
asserted step 4b of `lib/upgrade.sh` delegates to `do_vendor`, bounded on the literal `4c.`.

**Root cause:** the span was bounded on a **named successor** rather than on structure. A
sed range whose end pattern stops matching runs to EOF — the span grows from 36 lines to 806
and the assertion is satisfied by the string `do_vendor` inside an unrelated comment 650
lines away. Two ways to trip it, both routine: rename the successor, or insert a step
between. The insertion case is 832's T-312 finding, passed to us at rail 345.

**Why structurally allowed:** the failure direction is *toward green*. A widened span makes
a presence assertion more likely to pass, so the guard reports success precisely when it has
stopped guarding. Nothing measures whether an assertion is still discriminating. Compounded
here by the assertion matching a comment — a text match cannot distinguish code from prose
about that code (L-519).

**Prevention:** structural bound (next step header of any name), an explicit span-size guard
so run-to-EOF fails loudly, comments stripped before matching, both halves of the invariant
asserted, and three negative controls run — including 832's exact mutation, on which the old
test is green and the new one red.

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

### 2026-07-31T09:03:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2696-span-extracting-invariant-test-goes-vacu.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-48e241fa
- **Timestamp:** 2026-07-31T09:13:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-31T09:13:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
