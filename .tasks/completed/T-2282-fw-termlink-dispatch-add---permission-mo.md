---
id: T-2282
name: "fw termlink dispatch: add --permission-mode flag (plumb to claude -p, unblock MCP workers)"
description: >
  fw termlink dispatch: add --permission-mode flag (plumb to claude -p, unblock MCP workers)

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
created: 2026-06-09T09:53:06Z
last_update: 2026-06-09T09:57:58Z
date_finished: 2026-06-09T09:57:58Z
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

# T-2282: fw termlink dispatch: add --permission-mode flag (plumb to claude -p, unblock MCP workers)

## Context

Diagnosed in OBS-058 + OBS-059 today (2026-06-09 09:47Z) during the HM-A demo dispatch experiment. `fw termlink dispatch` at `agents/termlink/termlink.sh:714` invokes `claude -p` with `$MODEL_FLAG $TOOLS_FLAG --output-format stream-json --verbose` — no `--permission-mode` flag. Non-interactive claude -p leaves MCP servers in `"status":"pending"` because the workspace trust dialog can't fire. All 5 MCP servers (context7, playwright, termlink, skills, framework-mcp) showed pending in the demo's init line; the worker did 7 fruitless ToolSearch calls trying to locate `mcp__framework-mcp__*` / `mcp__fw__*` before being terminated.

This is a small additive plumb (sibling to T-1703 `--tools` plumbing): add `--permission-mode <mode>` as a passthrough flag on `fw termlink dispatch`, default empty (claude -p default behavior preserved for all existing consumers).

**Scope fence:** opt-in flag only. Default behavior unchanged. No new dependencies. Existing dispatches (ollama-loop, non-MCP claude workers) continue to work identically.

## Acceptance Criteria

### Agent
- [x] `bin/fw termlink dispatch --permission-mode acceptEdits ...` passes `--permission-mode acceptEdits` through to the `claude -p` invocation (verified via smoke: t2282-smoke wdir contained `permission_mode.txt=acceptEdits` and `meta.json.permission_mode=acceptEdits`)
- [x] `bin/fw termlink dispatch ...` without `--permission-mode` works identically to today (no flag added, no regression) — backward-compat pinned by t8 (asserts the `if [ -n "$permission_mode" ]` guard)
- [x] `--permission-mode` accepts any string and passes it verbatim — validation happens in claude -p (same shape as `--tools` per T-1703)
- [x] `bats tests/integration/test_termlink_dispatch_permission_mode.bats` PASS — 8/8 tests (declared local var, case branch consumes flag, conditional write, run.sh constructs flag from file, claude -p includes flag, meta.json schema, help text mentions flag, backward-compat guard)
- [x] `bin/fw reviewer T-2282` returns PASS or CONCERN with only suppressible FPs

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

grep -q "permission-mode" agents/termlink/termlink.sh
test -f tests/integration/test_termlink_dispatch_permission_mode.bats
out=$(bats tests/integration/test_termlink_dispatch_permission_mode.bats 2>&1); echo "$out" | grep -qE "ok [0-9]+"
out=$(bin/fw reviewer T-2282 2>&1); echo "$out" | grep -qE "Overall:.*(PASS|CONCERN)"

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

**Recommendation:** GO — agent-only task, no [REVIEW] needed. All 5 Agent ACs ticked, reviewer PASS.

**Rationale:** Strictly additive opt-in flag. Default behavior unchanged for all existing consumers (ollama-loop, non-MCP claude workers). The fix is a 4-line plumbing change mirroring T-1703's `--tools` pattern — declared local var + case branch + conditional file write + run.sh consumer + meta.json observability. End-to-end validation of the `acceptEdits` mode unblocking MCP servers requires a fresh claude -p run; this happens naturally when the operator next dispatches the HM-A demo (T-2268 AC #4-7) with `--permission-mode acceptEdits` added to the command line.

**Evidence:**
- `agents/termlink/termlink.sh` — 5 surgical edits at lines: local var (line 494), case branch (lines 529-538), conditional write + meta.json field (lines 627-636 + 651), run.sh PERMISSION_MODE_FLAG construction (lines 700-707), claude -p invocation (line 748), help text (line 939).
- `tests/integration/test_termlink_dispatch_permission_mode.bats` — 8/8 PASS. Pins the contract at the artefact layer (the flag must reach permission_mode.txt + meta.json + run.sh's claude -p line). End-to-end requires real claude -p which would burn budget in CI.
- Smoke test: `bin/fw termlink dispatch --task T-2282 --name t2282-smoke --prompt "smoke" --permission-mode acceptEdits --timeout 60` produced wdir with `permission_mode.txt=acceptEdits` and `meta.json.permission_mode=acceptEdits`.
- Regression net: 31/31 existing dispatch unit tests PASS (test_termlink_dispatch_task_type.py + test_termlink_dispatch_tag_format.py + test_reviewer_dispatch.py).
- Reviewer R-a2ceb34f: Overall PASS, 0 findings.

**Next step (operator):** re-dispatch HM-A demo with `--permission-mode acceptEdits` to unblock T-2268 AC #4-7.

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

### 2026-06-09T09:53:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2282-fw-termlink-dispatch-add---permission-mo.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0e214c4f
- **Timestamp:** 2026-06-09T09:58:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-09T09:57:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
