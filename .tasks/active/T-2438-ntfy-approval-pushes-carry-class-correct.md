---
id: T-2438
name: "ntfy approval pushes carry class-correct Watchtower URL (one-tap review)"
description: >
  ntfy approval pushes carry class-correct Watchtower URL (one-tap review)

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
created: 2026-06-19T10:14:38Z
last_update: 2026-06-19T10:14:38Z
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

# T-2438: ntfy approval pushes carry class-correct Watchtower URL (one-tap review)

## Context

Streamline human-gated approvals (Option B from the arc-013 approval-UX discussion). The ntfy doorbell + Watchtower console already exist; the gap is that approval pushes don't deep-link. The `"Review Needed: T-XXX"` push (update-task.sh:1747) carries NO URL at all, so the operator gets a buzz then has to go find the page.

**This task = framework-side only** (non-breaking, works regardless of dispatcher): thread the **class-correct Watchtower URL into the notification body** — ntfy renders body URLs as tappable. The dispatcher-side upgrade (ntfy `Click:`/`Actions:` header for whole-notification tap) is homed to **150-skills-manager** (separate repo/governance — file as a pending there; do NOT cross the project boundary from this session).

**Infra (for Option A enable, not this task):** ntfy server is on **ring20**, topic **`ring20-manager`**. The **`.107` ntfy server is decommissioned — do NOT use it.** notify-config/dispatcher must point at the ring20 server.

### Design of record (turnkey)

1. **New helper `fw_task_review_url <task_id> [task_file]`** in `lib/watchtower.sh` (URL-helpers home, next to `_watchtower_url` which ends at line ~148). Logic mirrors `emit_review` lib/review.sh:106-119:
   - `base=$(_watchtower_url "$task_id")` — tolerate failure (watchtower down) → echo nothing, return 1 (caller then passes no click_url).
   - discover task_file if not given (active/ then completed/), read `workflow_type`.
   - inception → `${base}/inception/${task_id}`; else → `${base}/review/${task_id}`. (Single source of class-correct routing — see [[feedback_per_class_review_url]] / CLAUDE.md §Per-class URL mapping.)
2. **Refactor `emit_review`** (lib/review.sh:111-119) to call `fw_task_review_url` for `review_url` (keep `review_label` local) — so the two paths can't diverge (the t2247-class staleness lesson).
3. **`fw_notify` 5th arg `click_url`** (lib/notify.sh:50-67): `local click_url="${5:-}"`; if non-empty, append `\n$click_url` to `$message` before dispatch. Non-breaking — existing 4-arg calls unaffected. (Do NOT add an unknown `--click` flag to the dispatcher call — dispatcher arg-handling is unverified across the project boundary and could break the existing call. Body-append is dispatcher-agnostic.)
4. **Wire the review-needed trigger** (update-task.sh:1744-1748): `url=$(fw_task_review_url "$TASK_ID" "$TASK_FILE" 2>/dev/null || true); fw_notify "Review Needed: $TASK_ID" "$TASK_NAME" "manual" "framework" "$url"`. (tier0 check-tier0.sh:444 already embeds `/approvals` — optionally unify later; out of scope here.)
5. **Re-vendor** (`fw vendor self`) — lib/watchtower.sh + lib/notify.sh + agents/task-create/update-task.sh + lib/review.sh all change.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] `fw_task_review_url` helper added in `lib/watchtower.sh`: returns `<base>/review/<id>` for build/refactor/test, `<base>/inception/<id>` for inception; returns non-zero + empty when the Watchtower base can't be resolved
- [ ] `emit_review` refactored to call `fw_task_review_url` for its review_url (exact-string-preserving; existing emit_review tests stay green)
- [ ] `fw_notify` accepts optional 5th arg `click_url` and appends it to the message body when non-empty; 4-arg calls unchanged (disabled-state still no-ops)
- [ ] review-needed trigger (update-task.sh) passes the class-correct URL; a partial-complete close produces a push body containing `/review/<id>` (or `/inception/<id>`)
- [ ] Tests: `tests/unit/t2438_notify_review_url.bats` — helper routing (build→/review, inception→/inception, no-base→empty) + fw_notify body-append (with/without click_url, disabled no-op); existing review bats green
- [ ] `bash -n` clean on all edited files; `fw vendor self --check` exits 0 (vendored copies synced)

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

### 2026-06-19T10:14:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.claude/worktrees/inception-gov-payload-mediation/.tasks/active/T-2438-ntfy-approval-pushes-carry-class-correct.md
- **Context:** Initial task creation
