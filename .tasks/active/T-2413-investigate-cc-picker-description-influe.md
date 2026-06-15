---
id: T-2413
name: "investigate CC picker description influence — claude-fw project prefix"
description: >
  Inception: investigate CC picker description influence — claude-fw project prefix

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-15T22:13:50Z
last_update: 2026-06-15T22:15:05Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-06-15T22:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-15T22:15:05Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F-AUTONOMY=2 
      (no-signal); F3=2 (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2413: investigate CC picker description influence — claude-fw project prefix

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Can `claude-fw` stamp a project prefix into the CC session picker's per-row name without losing CC's auto-summarised content?**
  confidence: 3
  disposition: answered
  rationale: `claude --name <name>` is a first-class CLI flag — *"Set a display name for this session picker, and terminal title"* (verified via `claude --help`). Tradeoff: setting `--name` REPLACES the auto-summary entirely (`nameSource: "user"` short-circuits the auto path); does not prefix it.

- **IW-2: Is the picker UI agent (`claude agents`) configurable to add a project column directly, bypassing the name-prefix workaround?**
  confidence: 3
  disposition: answered
  rationale: `claude agents --help` shows only `--cwd <path>` for filtering — no display-project-column flag. Native UI is fixed; the name-prefix workaround is the right path.

- **IW-3: Does CC overwrite `name` on subsequent state syncs if `nameSource: user` is set?**
  confidence: 3
  disposition: answered
  rationale: workshop session at `/root/.claude/sessions/1447696.json` still carries `"name": "***workshop***"` 200K+ seconds after launch (`updatedAt` >> `startedAt`). User-set names are stable across the session lifetime.

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
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Rationale:**

CC has a first-class `claude -n/--name <name>` flag that sets the session picker's display name (and terminal title). This means `claude-fw` can stamp a project prefix into the picker by passing `-n` when invoking `claude`. One-liner sketch:

```bash
# In bin/claude-fw, before `exec claude "$@"`:
_args_have_name() { for a in "$@"; do case "$a" in -n|--name) return 0;; esac; done; return 1; }
if [ "${FW_NO_PICKER_NAME:-0}" != "1" ] && ! _args_have_name "$@"; then
    PICKER_NAME="${FW_PROJECT_NAME:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")}"
    set -- -n "$PICKER_NAME" "$@"
fi
```

Operator overrides:
- Explicit `claude-fw --name "<custom>"` wins (we honour the user's flag)
- `FW_PROJECT_NAME=AEF claude-fw` for a short alias
- `FW_NO_PICKER_NAME=1` to opt out entirely
- Bare invocation defaults to project basename (`999-Agentic-Engineering-Framework`, etc.)

**Tradeoff:** setting `--name` REPLACES CC's auto-summary; we lose the auto-derived "what is this session doing" text in the picker's left column. Mitigations:
1. CC still shows `detail`/`needs` in the right-side description column (e.g. *"What would you like to work on?"*), which carries the auto-summary semantic content.
2. The T-2411 startup banner I shipped still fires post-attach to show focus + arc once the operator picks a session.
3. Operator can rename ad-hoc per session via `--name` if they want session-specific labels.

Net: project visibility WINS across the cross-project picker view; the within-project session distinction shifts from "left column auto-summary" to "right column detail + post-attach banner". Aligns with operator's 2026-06-16 ask (project visible in overview).

**Evidence:**

- `claude --help` line 84-86: `-n, --name <name>  Set a display name for this session picker, and terminal title`
- `/root/.claude/sessions/1447696.json`: `name: "***workshop***"`, `cwd: "/opt/025-WokrshopDesigner"` — proves user-set names work and persist.
- `/root/.claude/jobs/<id>/state.json` distribution: 15 `auto` / 1 `user` (`for d in jobs/*; do jq -r .nameSource state.json; done | sort | uniq -c`) — name override path is rarely used but functional.
- `claude agents --help`: no display-column flag; only `--cwd <path>` filter — confirms no cleaner alternative.

**Build scope:** one-file edit to `bin/claude-fw` (~10 LOC), 1 bats test (real wrapper + stub `claude` asserting `-n <project>` is present in argv when not user-provided), self-vendor sync.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-15T22:15:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
