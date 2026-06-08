---
id: T-2201
name: "AEF pre-flight Claude CLI config before fw termlink dispatch"
description: >
  T-2200 worker died with cryptic JSON parse error because /root/.claude.json was
  corrupted. fw termlink dispatch should pre-flight the Claude CLI config and refuse
  fast with precise diagnostic.

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-04T07:43:22Z
last_update: 2026-06-08T07:44:40Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-04T07:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-04T07:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2201: AEF pre-flight Claude CLI config before fw termlink dispatch

## Problem Statement

T-2200 (2026-06-04) dispatched a claude-p worker via `fw termlink dispatch` against `/opt/fan-dashboard`. The worker exited rc=1 within seconds with this output (only):

```
Configuration error in /root/.claude.json: JSON Parse error: Unterminated string
Claude configuration file at /root/.claude.json is corrupted: JSON Parse error: Unterminated string
The corrupted file has already been backed up.
A backup file exists at: /root/.claude/backups/.claude.json.backup.1780508533646
You can manually restore it by running: cp "..." "..."
```

The framework's dispatch surface did NOT pre-flight the Claude CLI config before spending the cost of: tmux session creation, worker dir creation under `/tmp/tl-dispatch/`, prompt file write, env file write, telemetry write, and worker.done event emission. From the parent session's perspective, the failure looked exactly like a worker that ran-and-died, requiring forensic file-reading to find the real cause. The actionable diagnostic was buried in the worker's log output, three steps removed from the dispatch surface.

**For whom:** Any agent or operator using `fw termlink dispatch` (and other claude-p spawn surfaces: `fw reviewer --dispatch`, `fw peer subscribe` responder spawn-bridge). Every session that ever calls these surfaces is exposed.

**Why now:** The first known incident landed in this session; the framework's "always work, never silently fail" stance means a single-incident pattern that wastes resources + obscures the diagnostic deserves a structural pre-flight, even before it recurs. The fix is small (a single check before tmux spawn) and the cost-of-skip is observable (T-2200's wasted dispatch + agent forensics).

## Assumptions

- A1: `claude -p` always reads `/root/.claude.json` at startup, regardless of project or dispatch context. If true, pre-flighting that file from the dispatch surface is sufficient. Test: `strace -f -e openat claude -p 'hi' 2>&1 | grep claude.json`.
- A2: A simple `python3 -c "import json; json.load(open('/root/.claude.json'))"` (or equivalent) catches the unterminated-string class. Other corruption modes (missing keys, schema drift, expired tokens) may need different checks. Test: corrupt the file in 3 different ways, observe each diagnostic.
- A3: The parent session's project-boundary hook will refuse to let an agent INSPECT `/root/.claude.json` directly — pre-flight must therefore live inside `fw termlink dispatch` (which already runs out-of-process from the agent's tool calls) or be a hook-exempt path. Verify: bin/fw boundary hook behaviour on read-only access.

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Second incident — same class (2026-06-04, ~30min after T-2200)

Both `fan-dashboard-aef-setup` (T-2200) and `workflow-designer-aef-setup` (T-2202) workers exhibited the SAME observable when reaching Step 2 (discover commands): the parent's `FRAMEWORK_ROOT=/opt/999-Agentic-Engineering-Framework` env var leaked into the worker subprocess, so the worker's `fw help` consulted the framework repo's lib, not its own vendored `.agentic-framework/`. The workers adapted by prefixing every fw call with `FRAMEWORK_ROOT=/opt/<project>/.agentic-framework PROJECT_ROOT=/opt/<project>`. This isn't fatal — the worker reasoned around it — but it IS dispatch-time hygiene the framework should own, not delegate to the worker's reasoning budget.

This widens IW-2's "which corruption modes" question: **the pre-flight should arguably also strip / re-pin worker environment** (PROJECT_ROOT, FRAMEWORK_ROOT, possibly more) so workers start in a clean, project-local env. Adjacent class to L-456 (bats `unset PROJECT_ROOT` discipline shipped this session). Adds candidate **B+** to the working set: shared helper does config pre-flight AND env scrubbing before spawn.

## Open Questions

- **IW-1: Should `fw termlink dispatch` pre-flight `/root/.claude.json` parseability, OR should that check live in a deeper layer (`agents/termlink/termlink.sh::ensure_termlink` or a shared helper)?**
  confidence: 1
  disposition: <filled at decide-time>
  rationale: <filled at decide-time>

- **IW-2: Which corruption modes should pre-flight catch — (a) JSON parse error only (the burning case), (b) plus missing required keys, (c) plus expired/revoked auth tokens?**
  confidence: 2
  disposition: <filled at decide-time>
  rationale: <filled at decide-time>

- **IW-3: Should the same pre-flight wrap `fw reviewer --dispatch` and the `fw peer subscribe` responder spawn-bridge, OR live in a shared helper that all claude-p spawn paths invoke?**
  confidence: 2
  disposition: <filled at decide-time>
  rationale: <filled at decide-time>

- **IW-4: Where should the diagnostic be surfaced — stderr from `fw termlink dispatch` only, or also a structured envelope on the result bus / a `fw doctor` check?**
  confidence: 1
  disposition: <filled at decide-time>
  rationale: <filled at decide-time>

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.
-->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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

**Recommendation:** GO — Candidate B (shared helper for all claude-p spawn surfaces)

**Rationale:** Two-incident pattern in one session. T-2200 surfaced the burning case (`/root/.claude.json` corruption diagnostic buried 3 file-reads deep from the dispatch surface, after tmux session + worker dir + prompt write + env write + telemetry all spent). T-2202 added the env-leak class (`FRAMEWORK_ROOT` leaks from parent into worker, worker reasons around it instead of dispatch surface scrubbing). Both observations are dispatch-time hygiene the framework should own. Fix shape is bounded — single shared helper `lib/claude_cli_preflight.{sh,py}` invoked from `cmd_dispatch` + `fw reviewer --dispatch` + `fw peer subscribe` responder, single python `json.load` check plus env-scrub before tmux spawn. Risk is low (one check, no behaviour change on healthy config). Adjacent classes already addressed (L-291 toolchain-build-missing-from-Verification, L-364 cron-drift-not-surfaced-at-audit) use the same "detect → refuse fast → name the specific bypass" pattern. Defer Candidate C (`fw doctor` advisory) to a sibling — separate concern, separate cadence.

**Evidence:**
- T-2200 worker exited rc=1 within seconds with diagnostic only in worker stdout log — three file reads removed from the dispatch surface; ~3 minutes of agent forensics.
- T-2202 worker (same session, ~30 min later) hit `FRAMEWORK_ROOT` env-leak from parent — worker adapted by prefixing every fw call with `FRAMEWORK_ROOT=...` and `PROJECT_ROOT=...`. Second-incident evidence for IW-2's "which corruption modes" question.
- `agents/termlink/termlink.sh::cmd_dispatch` flow has no `claude -p` config pre-flight between arg parse and tmux spawn — verified by inspection.
- `fw reviewer --dispatch` (T-1951) and `fw peer subscribe` responder spawn-bridge would both inherit the same gap.
- Adjacent pattern shipped: L-291 (toolchain) and L-364 (cron-drift) both use the same "fail-late surface → detect → refuse fast" fix shape that Candidate B mirrors.

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

**Rationale**: Two-incident pattern in one session. T-2200 surfaced the burning case (`/root/.claude.json` corruption diagnostic buried 3 file-reads deep from the dispatch surface, after tmux session + worker dir + prompt write + env write + telemetry all spent). T-2202 added the env-leak class (`FRAMEWORK_ROOT` leaks from parent into worker, worker reasons around it instead of dispatch surface scrubbing). Both observations are dispatch-time hygiene the framework should own. Fix shape is bounded — single shared helper `lib/claude_cli_preflight.{sh,py}` invoked from `cmd_dispatch` + `fw reviewer --dispatch` + `fw peer subscribe` responder, single python `json.load` check plus env-scrub before tmux spawn. Risk is low (one check, no behaviour change on healthy config). Adjacent classes already addressed (L-291 toolchain-build-missing-from-Verification, L-364 cron-drift-not-surfaced-at-audit) use the same "detect → refuse fast → name the specific bypass" pattern. Defer Candidate C (`fw doctor` advisory) to a sibling — separate concern, separate cadence.

**Date**: 2026-06-04T19:47:12Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-04T19:47:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Two-incident pattern in one session. T-2200 surfaced the burning case (`/root/.claude.json` corruption diagnostic buried 3 file-reads deep from the dispatch surface, after tmux session + worker dir + prompt write + env write + telemetry all spent). T-2202 added the env-leak class (`FRAMEWORK_ROOT` leaks from parent into worker, worker reasons around it instead of dispatch surface scrubbing). Both observations are dispatch-time hygiene the framework should own. Fix shape is bounded — single shared helper `lib/claude_cli_preflight.{sh,py}` invoked from `cmd_dispatch` + `fw reviewer --dispatch` + `fw peer subscribe` responder, single python `json.load` check plus env-scrub before tmux spawn. Risk is low (one check, no behaviour change on healthy config). Adjacent classes already addressed (L-291 toolchain-build-missing-from-Verification, L-364 cron-drift-not-surfaced-at-audit) use the same "detect → refuse fast → name the specific bypass" pattern. Defer Candidate C (`fw doctor` advisory) to a sibling — separate concern, separate cadence.
