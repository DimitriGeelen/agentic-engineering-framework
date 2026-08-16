---
id: T-2384
name: "Orchestrator scan script lost executable bit (audit WARN)"
description: >
  Audit WARNs "orchestrator-mcp-scan.sh not executable" but the script is invoked
  via bash (no +x needed). Root cause = check/invocation mismatch (audit's -x precondition
  vs bash invocation). Fix = relax precondition to -f, not chmod.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [audit, governance]
components: [C-004]
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
created: 2026-06-13T22:59:25Z
last_update: '2026-08-16T22:25:04Z'
date_finished: 2026-06-13T23:05:29Z
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
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=3 (body:portability-abstraction); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2384: Orchestrator scan script lost executable bit (audit WARN)

## Context

Remediation R2 from `.context/working/audit-remediation-plan-2026-06-14.md`. `bin/fw audit`
emits `WARN Orchestrator scan: agents/audit/orchestrator-mcp-scan.sh not executable` — the
file is `-rw-rw-r--` (no +x). Investigation found this is a **check/invocation mismatch**:
the audit's precondition tested `-x` but the actual invocation is `bash "$ORCH_SCRIPT"` (no +x
needed). Fix = relax the precondition to `-f` (existence), not `chmod +x` (which would recur on
the next mode-strip). See ## RCA.

## Acceptance Criteria

### Agent
- [x] The spurious "not executable" WARN is cleared — fixed at root by relaxing the audit precondition (audit.sh:4501) from `[ ! -x ]` to `[ ! -f ]` to match its own `bash "$ORCH_SCRIPT"` invocation; the orchestrator scan now runs. (No `chmod +x` — that papers over the check/invocation mismatch, re-triggers on the next mode-strip, and would make this one script inconsistent with 30+ non-+x sibling agent scripts.)
- [x] Swept the other audit `-x` checks for the same bug class: CTL-011 (pre-push, git invokes directly) + CTL-019 (claude-fw, run as a command — already `-rwxrwxr-x`) genuinely need +x and check correctly; CTL-002/CTL-005 (tier0/watchdog) are not in the audit FAIL set, so their scripts are +x. The orchestrator check was the only `-x`-vs-`bash` mismatch.
- [x] `bash -n agents/audit/audit.sh` passes; `bin/fw audit --section orchestrator` no longer emits the executable WARN (scan executes)
- [x] RCA filled; reviewer PASS (R-4290a596)

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
#
# --- R2 verification ---
# audit.sh parses.
bash -n agents/audit/audit.sh
# The precondition now checks existence, not +x (matches the bash invocation).
grep -q 'if \[ ! -f "\$ORCH_SCRIPT" \]' agents/audit/audit.sh
# Orchestrator section runs without the executable WARN.
# Herestring (not a pipe) so the negation is SIGPIPE-safe under set -eo pipefail (L-387/T-2090).
out=$(bin/fw audit --section orchestrator 2>&1); ! grep -q "not executable" <<<"$out"

## RCA

**Symptom:** `bin/fw audit` emitted `WARN Orchestrator scan: …/orchestrator-mcp-scan.sh not
executable`, with remediation hint `chmod +x`. The script's git mode is `100644` (never +x).

**Root cause:** a **check/invocation mismatch** in `audit.sh`. The precondition gate
(line 4501) tested `[ ! -x "$ORCH_SCRIPT" ]`, but the actual invocation (line 4511) is
`bash "$ORCH_SCRIPT" >/dev/null 2>&1` — which does not require the executable bit. So the gate
was *stricter than the thing it guards*: it WARNed on a state (`100644`) that nothing actually
breaks on. The only other references to the script (`tools/check_termlink_tag_drift.py`,
`tests/unit/test_orchestrator_mcp_classify.py`) are docs / `read_text()` — never an exec.

**Why structurally allowed:** "missing or not executable" is a common copy-paste audit idiom
(CTL-002/005/011/019 all use `-x`). For genuinely-direct-invoked scripts (git's pre-push hook,
the `claude-fw` command) the `-x` check is correct. It was pasted onto a `bash`-invoked script
without noticing the invocation doesn't need +x. There is no lint that cross-checks an audit's
`-x` precondition against how the same script is actually invoked, so the spurious WARN sat.

**Prevention (distinct from the fix):** the fix itself is recurrence-proof — relaxing the
precondition to `[ ! -f ]` means a future `git checkout` / vendor / mode-strip (which is how
`100644` arose) can never re-trigger this WARN, and the file stays convention-consistent with
its 30+ non-+x siblings. A `chmod +x` (the original plan / the audit's own hint) would have
been the *symptom* fix: correct today, WARN returns on the next mode-strip. Documented as a
learning so the next `-x`-on-a-`bash`-invoked-script audit idiom is caught at author time.
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

### 2026-06-13T22:59:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/arc012-continuous-run-s4s5/.tasks/active/T-2384-orchestrator-scan-script-lost-executable.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-10451043
- **Timestamp:** 2026-06-13T23:05:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-13T23:05:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
