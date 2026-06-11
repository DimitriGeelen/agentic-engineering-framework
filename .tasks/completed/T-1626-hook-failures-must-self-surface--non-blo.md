---
id: T-1626
name: "Hook failures must self-surface — non-blocking != invisible (CWD-invariant
  resolution + telemetry)"
description: >
  Hook failures must self-surface — non-blocking != invisible (CWD-invariant resolution
  + telemetry)

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-30T21:15:27Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-04-30T21:18:21Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1626: Hook failures must self-surface — non-blocking != invisible (CWD-invariant resolution + telemetry)

## Problem Statement

A consumer-project Claude Code session (`/root/ring20-dashboard/...`) repeatedly fired `PostToolUse:Edit` / `PreToolUse:Bash` / `PostToolUse:Read` hooks that all failed with:
```
/bin/sh: 1: .agentic-framework/bin/fw: not found
```
The agent had `cd`-ed into `/root/ring20-dashboard/deploy/lan-proxy`. The hook command in `.claude/settings.json` is the **CWD-relative path** `.agentic-framework/bin/fw`, which resolves only when CWD is the consumer root. From `deploy/lan-proxy`, the path resolves to nothing → `not found`.

The errors are labelled "non-blocking status code" by Claude Code, so:
1. The tool calls succeeded
2. The framework recorded **zero** signal of breakage
3. No telemetry counter incremented; `concerns.yaml` saw nothing; `fw doctor` would have passed
4. The agent kept working through dozens of these errors as visual wallpaper
5. Only the human watching the chat noticed

**Root cause = framework blindness, not the broken hook.** The hook breakage is trivial to fix (one line). What's not trivial is that we didn't *know* it was broken. This is structurally identical to G-019: the immune system was desensitised to the very signal that should have triggered it.

**Why now:** observed 2026-04-30 in a live consumer session; affects every consumer that vendors hooks via `fw upgrade`. We have several consumers (`/003-NTB-ATC-Plugin`, `/050-email-archive`, `/root/ring20-dashboard`) — uniform exposure. Cross-cutting per T-1333; gap homes here because the *fix* lives in framework hook-installation + telemetry code.

## Assumptions

- **A1:** Hook commands in `.claude/settings.json` use CWD-relative `.agentic-framework/bin/fw` paths today. *(Verify: `grep -rn "\.agentic-framework/bin/fw" .claude/settings.json` in any consumer.)*
- **A2:** Hook failures with non-zero exit on PostToolUse / non-blocking PreToolUse never write to `.context/working/` or `concerns.yaml` — i.e. zero structural footprint. *(Verify: search framework for hook-failure-counter / hook-watchdog primitives.)*
- **A3:** `fw doctor` does not exercise hooks from a non-root CWD. *(Verify: read `agents/audit/audit.sh` + `bin/fw doctor`.)*
- **A4:** `fw upgrade` (the install path) has the consumer's absolute path at the moment it writes `.claude/settings.json`, but doesn't bake it in. *(Verify: read `lib/init.sh` / vendor logic.)*
- **A5:** Claude Code's PreToolUse / PostToolUse hooks run with CWD = the agent's current shell CWD, not the project root. *(Verify: Claude Code docs / observed behaviour above.)*
- **A6:** The cost of running each registered hook once at SessionStart for a self-test is <100ms total (current set: ~5 hooks × ~20ms each). *(Verify: `time bash -c 'bin/fw hook check-active-task < /dev/null'`.)*

## Exploration Plan

Three time-boxed spikes, total ≤90 min:

**Spike 1 (≤20 min) — Reproduce + characterise.**
- Pick a consumer (`/003-NTB-ATC-Plugin` or `/050-email-archive`).
- `cd` into a subdir (e.g. `tests/`, `deploy/`).
- Run `bin/fw hook check-active-task` directly → expect "command not found" or path error.
- Confirm A1 + A5 + A2 (no telemetry footprint after the failure).
- Record exact error shape and how many tool calls per session would carry the noise.

**Spike 2 (≤30 min) — Surface design.**
- Walk-up resolution shim: prototype `~/.local/bin/fw-hook` that walks from `$PWD` up to find `.agentic-framework/bin/fw` or `.framework.yaml`, then exec.
- Compare to alternative: `bash -c 'cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && .agentic-framework/bin/fw hook ...'` inline in `settings.json`.
- Pick one, document trade-offs (shim = single point of update; inline = no install dependency).

**Spike 3 (≤40 min) — Telemetry + escalation design.**
- Sketch `.context/working/.hook-counter` + `.hook-failure-counter` shape (per-hook fire/fail counts).
- Sketch threshold rule: ≥N failures in M minutes → write to `concerns.yaml` as auto-generated G-XXX; surface in Watchtower `/hooks` page and `fw doctor`.
- Sketch SessionStart self-test: invoke each configured hook with a known-safe stdin; warn if any returns "command not found" or non-zero on the safe input.
- Decide what counts as "failure" (exit 1 always vs. exit 2 only vs. specific error patterns).

## Technical Constraints

- **Hook execution context:** Claude Code runs hooks via `/bin/sh -c "<command>"` with CWD = agent's shell CWD. Agents `cd` freely → CWD is unstable.
- **Non-blocking semantics:** PreToolUse hooks blocking on exit 2; PostToolUse and "advisory" hooks treated as non-blocking by Claude Code regardless of exit code. Cannot rely on Claude Code surfacing the failure to the user — must surface ourselves.
- **Cross-consumer reach:** any fix must propagate via `fw upgrade` to existing consumers without user intervention.
- **Bash 3.2 compat (T-518 closed):** install-time path-baking must work on macOS bash 3.2 if/when we re-engage with macOS.
- **Performance budget:** hook fires on every Bash/Edit/Write call. Adding telemetry must not add >5ms per fire.

## Scope Fence

**IN scope for this inception:**
- Hook-resolution path strategy (shim vs. inline vs. absolute-path-baking) — pick one
- Telemetry shape (counter file format, fail-rate threshold)
- Escalation surface (concerns.yaml auto-entry, Watchtower /hooks page, fw doctor check)
- SessionStart self-test design

**OUT of scope (separate tasks if GO):**
- Migrating Claude Code's "non-blocking" semantics — that's an upstream Claude Code behaviour we work around, not change
- Replacing the hook system with something else (e.g. MCP) — too big
- Per-tool hook performance optimisation — separate concern
- Cross-machine hook telemetry aggregation (TermLink-side)
- The actual implementation: GO ⇒ separate build tasks (a) install-time path fix, (b) telemetry, (c) doctor check, (d) Watchtower page

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:** This is a structural blindness, not a tactical bug. The framework's enforcement loop is *structural problem → hook fires → action blocked or telemetry recorded → audit notices → gap registered → fix shipped*. For "non-blocking" hook failures the loop snaps at step 3 — nothing records, nothing audits, no gap appears, no fix lands. We saw this in a live session today: dozens of `PostToolUse:Edit hook error … fw: not found` messages flowed past while the framework reported clean. **A framework that doesn't notice its own broken plumbing is structurally identical to G-019** (symptom-level OK while root cause persists). The fix path is bounded (4 small build tasks, each <2h), reversible (every change is a settings.json edit + a counter file), and immediately testable from any subdir.

**Evidence:**
- Live transcript (2026-04-30, ring20-dashboard session) showing dozens of `PostToolUse / PreToolUse` failures, all "non-blocking", all invisible to framework telemetry.
- `~/.local/bin/fw` already does the walk-up resolution for the user-facing CLI — extending to hooks is symmetric, low-risk.
- G-011 (PostToolUse hooks advisory-only) and G-019 (no self-escalation to systemic root cause) are the pre-existing parents of this gap.
- Cross-consumer reach: same fragile pattern in every project initialised via `fw upgrade`.
- T-1333 gap-homing rule applies: hit happened in a consumer, fix lives here.

**If GO, build task carve-out (each ≤2h):**
1. **B-1 — CWD-invariant hook resolution.** Choose between (a) `~/.local/bin/fw-hook` shim that walks up, or (b) inline `cd "$(git rev-parse --show-toplevel)" && ...` in settings.json, or (c) install-time absolute-path baking in `fw upgrade`. Pick whichever has lowest blast radius; bats-test from `/tmp` and from a deep subdir.
2. **B-2 — Hook telemetry.** `.context/working/.hook-counter` + `.hook-failure-counter` (per-hook fire/fail counts). Increment on every hook entry/exit. <5ms per fire.
3. **B-3 — Threshold escalation + Watchtower /hooks page.** N failures in M minutes → auto-register a G-XXX in `concerns.yaml`. Watchtower `/hooks` page surfaces fire/fail rates per configured hook. `fw doctor` adds a check that exercises every hook from `/tmp`.
4. **B-4 — SessionStart self-test.** Invoke each configured hook once at session start with known-safe stdin; one-shot warning to the agent if any returns command-not-found / non-zero on safe input.

These are ordered by criticality (B-1 fixes the bleeding; B-2/B-3 prevent recurrence; B-4 catches the next class).

**If DEFER:** acceptable only if a higher-priority structural blindness is being fixed first. Note that delaying this means every consumer keeps shipping silently broken hooks until either (a) a human notices in chat (today's case) or (b) the broken hook happens to be a Tier-0 gate, at which point the failure is no longer "non-blocking" — it becomes a security incident.

**If NO-GO:** would require evidence that hook-failure blindness is acceptable risk. Not seeing that evidence.

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

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: This is a structural blindness, not a tactical bug. The framework's enforcement loop is structural problem → hook fires → action blocked or telemetry recorded → audit notices → gap registered → fix shipped. For "non-blocking" hook failures the loop snaps at step 3 — nothing records, nothing audits, no gap appears, no fix lands. We saw this in a live session today: dozens of `PostToolUse:Edit hook error … fw: not found` messages flowed past while the framework reported clean. A framework that doesn't notice its own broken plumbing is structurally identical to G-019 (symptom-level OK while root cause persists). The fix path is bounded (4 small build tasks, each <2h), reversible (every change is a settings.json edit + a counter file), and immediately testable from any subdir.

Evidence:
- Live transcript (2026-04-30, ring20-dashboard session) showing dozens of `PostToolUse / PreToolUse` failures, all "non-blocking", all invisible to framework telemetry.
- `~/.local/bin/fw` already does the walk-up resolution for the user-facing CLI — extending to hooks is symmetric, low-risk.
- G-011 (PostToolUse hooks advisory-only) and G-019 (no self-escalation to systemic root cause) are the pre-existing parents of this gap.
- Cross-consumer reach: same fragile pattern in every project initialised via `fw upgrade`.
- T-1333 gap-homing rule applies: hit happened in a consumer, fix lives here.

If GO, build task carve-out (each ≤2h):
1. B-1 — CWD-invariant hook resolution. Choose between (a) `~/.local/bin/fw-hook` shim that walks up, or (b) inline `cd "$(git rev-parse --show-toplevel)" && ...` in settings.json, or (c) install-time absolute-path baking in `fw upgrade`. Pick whichever has lowest blast radius; bats-test from `/tmp` and from a deep subdir.
2. B-2 — Hook telemetry. `.context/working/.hook-counter` + `.hook-failure-counter` (per-hook fire/fail counts). Increment on every hook entry/exit. <5ms per fire.
3. B-3 — Threshold escalation + Watchtower /hooks page. N failures in M minutes → auto-register a G-XXX in `concerns.yaml`. Watchtower `/hooks` page surfaces fire/fail rates per configured hook. `fw doctor` adds a check that exercises every hook from `/tmp`.
4. B-4 — SessionStart self-test. Invoke each configured hook once at session start with known-safe stdin; one-shot warning to the agent if any returns command-not-found / non-zero on safe input.

These are ordered by criticality (B-1 fixes the bleeding; B-2/B-3 prevent recurrence; B-4 catches the next class).

If DEFER: acceptable only if a higher-priority structural blindness is being fixed first. Note that delaying this means every consumer keeps shipping silently broken hooks until either (a) a human notices in chat (today's case) or (b) the broken hook happens to be a Tier-0 gate, at which point the failure is no longer "non-blocking" — it becomes a security incident.

If NO-GO: would require evidence that hook-failure blindness is acceptable risk. Not seeing that evidence.

**Date**: 2026-04-30T21:18:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-30T21:18:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: This is a structural blindness, not a tactical bug. The framework's enforcement loop is structural problem → hook fires → action blocked or telemetry recorded → audit notices → gap registered → fix shipped. For "non-blocking" hook failures the loop snaps at step 3 — nothing records, nothing audits, no gap appears, no fix lands. We saw this in a live session today: dozens of `PostToolUse:Edit hook error … fw: not found` messages flowed past while the framework reported clean. A framework that doesn't notice its own broken plumbing is structurally identical to G-019 (symptom-level OK while root cause persists). The fix path is bounded (4 small build tasks, each <2h), reversible (every change is a settings.json edit + a counter file), and immediately testable from any subdir.

Evidence:
- Live transcript (2026-04-30, ring20-dashboard session) showing dozens of `PostToolUse / PreToolUse` failures, all "non-blocking", all invisible to framework telemetry.
- `~/.local/bin/fw` already does the walk-up resolution for the user-facing CLI — extending to hooks is symmetric, low-risk.
- G-011 (PostToolUse hooks advisory-only) and G-019 (no self-escalation to systemic root cause) are the pre-existing parents of this gap.
- Cross-consumer reach: same fragile pattern in every project initialised via `fw upgrade`.
- T-1333 gap-homing rule applies: hit happened in a consumer, fix lives here.

If GO, build task carve-out (each ≤2h):
1. B-1 — CWD-invariant hook resolution. Choose between (a) `~/.local/bin/fw-hook` shim that walks up, or (b) inline `cd "$(git rev-parse --show-toplevel)" && ...` in settings.json, or (c) install-time absolute-path baking in `fw upgrade`. Pick whichever has lowest blast radius; bats-test from `/tmp` and from a deep subdir.
2. B-2 — Hook telemetry. `.context/working/.hook-counter` + `.hook-failure-counter` (per-hook fire/fail counts). Increment on every hook entry/exit. <5ms per fire.
3. B-3 — Threshold escalation + Watchtower /hooks page. N failures in M minutes → auto-register a G-XXX in `concerns.yaml`. Watchtower `/hooks` page surfaces fire/fail rates per configured hook. `fw doctor` adds a check that exercises every hook from `/tmp`.
4. B-4 — SessionStart self-test. Invoke each configured hook once at session start with known-safe stdin; one-shot warning to the agent if any returns command-not-found / non-zero on safe input.

These are ordered by criticality (B-1 fixes the bleeding; B-2/B-3 prevent recurrence; B-4 catches the next class).

If DEFER: acceptable only if a higher-priority structural blindness is being fixed first. Note that delaying this means every consumer keeps shipping silently broken hooks until either (a) a human notices in chat (today's case) or (b) the broken hook happens to be a Tier-0 gate, at which point the failure is no longer "non-blocking" — it becomes a security incident.

If NO-GO: would require evidence that hook-failure blindness is acceptable risk. Not seeing that evidence.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8a746f04
- **Timestamp:** 2026-06-02T14:58:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T21:18:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
