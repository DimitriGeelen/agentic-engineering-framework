---
id: T-2456
name: "fw note writes unescaped double-quoted YAML — backslash in note body corrupts inbox.yaml + audit does not validate inbox.yaml parse"
description: >
  fw note writes unescaped double-quoted YAML — backslash in note body corrupts inbox.yaml + audit does not validate inbox.yaml parse

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [C-004, agents/observe/observe.sh, tests/unit/observe.bats]
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
created: 2026-06-21T15:13:20Z
last_update: 2026-06-21T15:23:26Z
date_finished: 2026-06-21T15:23:26Z
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

# T-2456: fw note writes unescaped double-quoted YAML — backslash in note body corrupts inbox.yaml + audit does not validate inbox.yaml parse

## Context

`fw note` (agents/observe/observe.sh `do_add`) wrote `text: "$text"` — raw interpolation into a
double-quoted YAML scalar. A backslash in the note body (OBS-081's regex `- **IW-(\d+):`) is an invalid
YAML escape, so `.context/inbox.yaml` failed `yaml.safe_load` with a ScannerError ("unknown escape
character 'd'") and **`fw note list/triage` crashed — the whole observation register went unreadable for
~a day** (found at the prior session's budget-critical, captured as OBS-084 in memory). Two structural
gaps: the writer doesn't escape, and `.context/inbox.yaml` was outside the audit's YAML-parse set so
nothing detected the corruption.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **Writer:** `do_add` escapes `$text` (`\`→`\\`, then `"`→`\"`) before the double-quoted scalar, so a backslash/quote in a note body can no longer corrupt inbox.yaml; both readers (yaml.safe_load + the sed reader) stay correct
- [x] **Data:** the corrupt OBS-081 entry repaired (`\d`→`\\d`); `.context/inbox.yaml` parses again (81 obs) and `fw note list` is restored
- [x] **Detection:** the audit's YAML-parse check (agents/audit/audit.sh) extended to validate `.context/inbox.yaml` (was only `.context/{project,arcs}/*.yaml`) — proven in isolation to PASS on the valid inbox and FAIL on an unescaped-`\d` fixture
- [x] **Regression:** `tests/unit/observe.bats` +3 (16/16): backslash round-trip, embedded-quote round-trip, two-note parse — each asserting **exact value preservation** (single backslash in → single backslash out), not just "parses"
- [x] Junk test note (the OBS-084 throwaway written during live-fire) removed; no inbox pollution left behind

### Human
None — internal tooling change (note writer + audit check); all criteria agent-verifiable: deterministic,
reversible (git revert), internal scope, no render surface.

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

# T-2456 — env-independent (observe.bats runs observe.sh directly with PROJECT_ROOT=tmp):
out=$(bats tests/unit/observe.bats 2>&1); echo "$out" | grep -qE "^ok 16 " && ! echo "$out" | grep -q "^not ok"
python3 -c "import yaml; d=yaml.safe_load(open('.context/inbox.yaml')); assert isinstance(d, dict)"
grep -q 'text_yaml=${text//' agents/observe/observe.sh
grep -q 'inbox_yaml="$PROJECT_ROOT/.context/inbox.yaml"' agents/audit/audit.sh

## RCA

**Symptom:** `fw note list` (and `triage`/`promote`) crashed with `yaml.scanner.ScannerError: while
scanning a double-quoted scalar … found unknown escape character 'd'` at `.context/inbox.yaml:680`. The
entire observation register was unreadable for ~a day — no triage, no resolve, no new structured filing.

**Root cause:** `agents/observe/observe.sh:do_add` emitted the note body as `text: "$text"` — raw shell
interpolation into a **double-quoted** YAML scalar via a heredoc. YAML double-quotes process backslash
escapes, so a note body containing a backslash (OBS-081's regex `- **IW-(\d+):`) wrote a literal `\d`
that YAML rejects as an unknown escape. String-concatenation as a YAML serializer: any `\`, `"`, or other
escape-significant byte in the payload corrupts the file.

**Why structurally allowed:** two compounding gaps. (1) The writer never escaped — it trusted the heredoc,
which does no YAML-quoting. (2) `.context/inbox.yaml` was **outside every parse gate**: the audit's
YAML-parse check (T-207) iterates only `.context/project/*.yaml` and `.context/arcs/*.yaml` (T-1816), and
inbox.yaml is a top-level file under `.context/`. The only reader was `fw note` itself — and it crashed —
so the corruption was self-concealing: the one tool that would surface it was the one the bug disabled.

**Prevention (distinct from the fix):** (1) the writer now escapes `\`→`\\` then `"`→`\"` before the
scalar; (2) the audit validates `.context/inbox.yaml` parse explicitly, so any future corruption FAILs the
daily audit instead of silently disabling the inbox; (3) `observe.bats` +3 round-trip regressions assert
exact value preservation for backslash + embedded-quote bodies. Note the single-tool-reader trap: a data
file whose only consumer crashes on corruption needs an *independent* parse gate — the consumer can't be
its own detector.

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

### 2026-06-21T15:13:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2456-fw-note-writes-unescaped-double-quoted-y.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dbe4205d
- **Timestamp:** 2026-06-21T15:23:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-21T15:23:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
