---
id: T-2233
name: "fw consumer-recover wrapper — one-command SSH + clone + env-scoped upgrade
  for legacy consumers"
description: >
  Inception: fw consumer-recover wrapper — one-command SSH + clone + env-scoped upgrade
  for legacy consumers

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-06-06T21:04:07Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-07T12:12:46Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-06-06T21:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-06-06T21:15:03Z'
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
  - ts: '2026-06-11T22:24:12Z'
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

# T-2233: fw consumer-recover wrapper — one-command SSH + clone + env-scoped upgrade for legacy consumers

## Problem Statement

**Who:** framework operator running an upgrade against a legacy consumer (vendored before T-1634 auto-clone / T-2232 sentinel + 3-leg fallback).

**What:** the consumer's vendored `bin/fw` is too old to self-heal. `fw upgrade` from inside the consumer hits T-1542's bare-from-consumer guard and refuses. The recovery recipe is mechanical but four-step and easy to typo:

1. SSH (or TermLink `remote exec`) to the consumer's host
2. `git clone https://github.com/DimitriGeelen/agentic-engineering-framework.git /tmp/fw-fresh`
3. `FRAMEWORK_ROOT=/tmp/fw-fresh PROJECT_ROOT=<consumer-path> /tmp/fw-fresh/bin/fw upgrade <consumer-path>` — the env scoping is **mandatory** (without it `resolve_framework` re-picks the consumer's broken vendored copy; same root cause as T-2099)
4. `rm -rf /tmp/fw-fresh`

**Why now:** ring20-dashboard hit this exact path on 2026-06-06 (memory `feedback_t2232_forward_looking_recovery`). The recipe worked — 26 changes applied, T-2094 F10 advisory fired in production first time — but a forgotten `FRAMEWORK_ROOT=` would have silently re-failed against the consumer's broken fw with no diagnostic. T-2232 protects only consumers vendored AT OR AFTER T-2232. Any consumer that predates T-2232 (and the framework will inevitably accumulate more of these as installations age out of the supported window) needs this recipe. Wrapping it removes a class of typo / forgetting / inverted-env-scope errors.

## Assumptions

- A-1: The consumer host is SSH-reachable from the framework dev host (or has a registered TermLink remote session). False if the consumer is offline / NAT'd — then the wrapper degrades to printing the recipe for the operator to run by hand (still better than the current "remember the recipe" state).
- A-2: The legacy consumer has `git` available and `/tmp` writable. False would surface as a clear early-step failure (the wrapper does not need to fix the consumer's tooling).
- A-3: `https://github.com/DimitriGeelen/agentic-engineering-framework.git` is the durable canonical upstream. Already pinned by T-2232's `--from-upstream` / `upstream_repo:` / sentinel chain.
- A-4: The set of legacy consumers fits the "a handful, known to the operator" cardinality — this wrapper is for hand-run recovery, not fleet-wide automation. (If the fleet grew to 10+ legacy consumers we would file a separate batch/parallel-recover task; out of scope here.)

## Open Questions

- **IW-1: CLI surface — separate verb `fw consumer-recover` vs. flag on existing verb (e.g. `fw upgrade --recover --host HOST`)?**
  confidence: 3
  disposition: answered
  rationale: Separate verb. `fw upgrade` is already overloaded (10 flags, 1562 LOC at lib/upgrade.sh) and its mental model is "this fw, this consumer" — adding a `--recover --host` flag conflates "local upgrade" with "remote bootstrap" and would muddy the T-1542 guard logic that exists precisely to distinguish these. Sibling verb is honest about the orchestration role.

- **IW-2: Transport — SSH only, TermLink only, or both?**
  confidence: 3
  disposition: answered
  rationale: Both, with SSH as default. TermLink remote exec was the actual mechanism used in the ring20 recovery (CLAUDE.md §Cross-Agent Communication Protocol — `termlink remote exec` is the sync command path). But SSH is the universal floor: works against any host with SSH key, no TermLink install required, doesn't depend on `termlink hub` being up. Wrapper picks TermLink when `--via termlink` is passed OR `termlink remote list | grep -q <host>` resolves, falls back to SSH otherwise.

- **IW-3: Upstream URL discovery — hard-coded, dispatcher arg, or auto-detect?**
  confidence: 3
  disposition: answered
  rationale: Auto-detect from the framework repo's own `git remote get-url origin` (sibling to the lib/init.sh:209-237 pattern used by `fw init`), with `--upstream URL` as explicit override. Hard-coding loses portability the moment we change upstream; requiring a dispatcher arg is too much ceremony for hand-recovery. Auto-detect is the same model `fw init` uses and was field-validated this session.

- **IW-4: Cleanup discipline — auto-rm temp clone, leave it, or ask?**
  confidence: 3
  disposition: answered
  rationale: Auto-rm by default, `--keep-temp` override for debugging. The ring20 recovery explicitly listed `rm -rf /tmp/fw-fix-T2232` as the final step — leaving stale `/tmp/fw-fresh-*` clones on consumer hosts is a janitorial debt and a security smell (random source trees on prod boxes). `--keep-temp` covers the "I want to inspect what was upgraded" case without making it the default.

- **IW-5: Idempotency on already-current consumers — refuse, no-op, or proxy to plain upgrade?**
  confidence: 3
  disposition: answered
  rationale: Refuse with a redirect. Detect post-T-2232 vintage by SSHing in and reading `.agentic-framework/.upstream` sentinel file (the T-2232 mark). If present → `echo "Consumer is post-T-2232; use 'ssh HOST cd PROJECT && .agentic-framework/bin/fw upgrade' instead"` + exit 0. Don't silently re-do the heavy clone+env-scope recipe when the consumer can self-heal — that train wrecks the cost asymmetry (10s vs. 60s) AND obscures whether the durable fix is working.

- **IW-6: Dry-run mode — required, optional, or omit?**
  confidence: 3
  disposition: answered
  rationale: Required. The wrapper's first job is "print the recipe with concrete host/path/upstream values filled in"; the SECOND job (gated on `--apply` or `--execute`) is to actually run it. This makes the wrapper safe-by-default (matches `fw upgrade --dry-run` convention), gives operators a single artifact they can paste into a runbook, and shifts the recovery teaching from CLAUDE.md memory into the verb itself.

## Exploration Plan

This inception is design-only — no spikes needed. The ring20-dashboard recovery this session is the empirical evidence. Build slice (separate task on GO) will be:

- **B-1 (≈30 min):** `lib/consumer-recover.sh` skeleton — flag parser, transport selection, sentinel detection
- **B-2 (≈45 min):** SSH leg (heredoc-driven `ssh HOST bash -s -- <args>`), TermLink leg (`termlink remote exec HOST <cmd>`), dry-run printer
- **B-3 (≈30 min):** bats tests under `tests/unit/` — mock SSH/TermLink transports, assert recipe correctness + sentinel-refuse path + cleanup
- **B-4 (≈15 min):** wire into `bin/fw` dispatcher, update `fw help`, add to Quick Reference in CLAUDE.md

Total budget ≈ 2 hours. Reviewer + close on landing.

**Full design spec:** `docs/reports/T-2233-consumer-recover-design.md` — written this session so the build slice has a complete CLI surface, heredoc, test list, and risk register to follow.

## Technical Constraints

- **SSH availability:** wrapper requires `ssh HOST` to work non-interactively (key auth or agent). No password fallback.
- **TermLink hub liveness:** TermLink leg requires `termlink hub status` healthy AND the target host's listener registered. Falls back to SSH if not.
- **Consumer-side floor:** consumer must have `git` and writable `/tmp`. Both are universal in practice but the wrapper checks and reports clearly if missing.
- **Upstream reachability:** consumer host must be able to clone from GitHub. If the consumer is air-gapped, the operator would need to bundle a local mirror — out of scope.

## Scope Fence

**IN scope:**
- Single-host recovery (one consumer at a time)
- SSH + TermLink transports
- Dry-run printer (recipe artifact)
- Sentinel-based "already current" refusal
- Auto-cleanup with `--keep-temp` opt-out

**OUT of scope:**
- Fleet-parallel recovery (multi-host fan-out) — file a separate task if needed
- Air-gapped / mirror-bundle recovery — file separately
- Modifying the consumer's `.framework.yaml` beyond what `fw upgrade` already does
- Replacing T-2232's durable fix — this wrapper coexists with it for the legacy consumers that predate it

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

**Rationale:**

Field-validated need 2026-06-06: ring20-dashboard recovery required SSH + git clone + explicit FRAMEWORK_ROOT=/PROJECT_ROOT= env scoping + fresh fw upgrade + cleanup — a 4-step recipe (per feedback_t2232_forward_looking_recovery memory). Shape is clear, evidence is the successful ring20 recovery this session, the wrapper is mechanical. No design ambiguity — needs only to be filed and scheduled. GO so the recipe becomes a one-liner before the next legacy-consumer incident; low priority (horizon:later) so V2 step-driver refactor (T-2078) gets priority. NOT a DEFER: not an evidence gap, just a priority call.

**Evidence:**

- `feedback_t2232_forward_looking_recovery.md` — full ring20-dashboard recovery walkthrough this session; the 4-step recipe this wrapper would replace
- `lib/upgrade.sh:306-385` — T-1542 bare-from-consumer guard + T-2232's 3-leg fallback chain (the durable fix that protects post-T-2232 consumers only)
- `lib/init.sh:209-237` — `git remote get-url origin` auto-detect pattern this wrapper would mirror
- `bin/fw:164-187` — `_detect_fw_mode` returns the 4 shapes the wrapper needs to classify (consumer-vendored-skewed is the recovery case)
- `lib/upgrade.sh:372` — the `env FRAMEWORK_ROOT=... PROJECT_ROOT=...` scoping pattern (originally for T-2099 fork-bomb prevention, repurposed here)
- Memory `feedback_path_isolation_cross_machine_prompts.md` — why the wrapper must NOT bake source-host paths into the SSH heredoc
- `docs/dispatch-templates/consumer-update-worker.md` — landed in T-2234; the dispatch-side companion to this wrapper

## Decisions

### 2026-06-07 — Separate verb over flag-on-existing-verb

- **Chose:** `fw consumer-recover <host> [<project-path>]` as a sibling verb to `fw upgrade`
- **Why:** clean mental separation — `fw upgrade` is "this fw, this consumer"; `fw consumer-recover` is "this fw, remote-bootstrap-then-upgrade *that* consumer". The two have different transport, different cleanup, different idempotency rules.
- **Rejected:** `fw upgrade --recover --host HOST --project PATH` — would muddy `lib/upgrade.sh`'s 1562 LOC and the T-1542 guard which exists precisely to refuse the bare-from-consumer case the wrapper has to perform.

### 2026-06-07 — SSH default with TermLink as opt-in upgrade

- **Chose:** SSH is the default transport. TermLink is selected when `--via termlink` is passed OR `termlink remote list` resolves the host.
- **Why:** SSH is the universal floor (key auth, no dependency on TermLink hub liveness). TermLink is the richer option (observability, replay via the bus) but its absence shouldn't block recovery — recovery is the moment you most need a transport that always works.
- **Rejected:** TermLink-only — would refuse to recover hosts without TermLink listeners, defeating the wrapper's purpose. SSH-only — would lose the bus-envelope reply path that this session demonstrated as a clean evidence channel.

### 2026-06-07 — Dry-run is the default; `--apply` opts in to execute

- **Chose:** Wrapper prints the recipe (with concrete substituted values) by default; only `--apply` (or `--execute`) actually runs the SSH/TermLink commands.
- **Why:** matches `fw upgrade --dry-run` precedent (safety-by-default for mutating verbs) and turns the wrapper into a teaching artifact — the operator gets a runbook line they can paste, audit, or share before the irreversible step.
- **Rejected:** execute-by-default with `--dry-run` opt-out — inverts the safety polarity for a verb that operates on a remote host; one typo on `--host` could re-vendor the wrong consumer.

## Decision

**Decision**: GO

**Rationale**: Field-validated need 2026-06-06: ring20-dashboard recovery required SSH + git clone + explicit FRAMEWORK_ROOT=/PROJECT_ROOT= env scoping + fresh fw upgrade + cleanup — a 4-step recipe (per feedback_t2232_forward_looking_recovery memory). Shape is clear, evidence is the successful ring20 recovery this session, the wrapper is mechanical. No design ambiguity — needs only to be filed and scheduled. GO so the recipe becomes a one-liner before the next legacy-consumer incident; low priority (horizon:later) so V2 step-driver refactor (T-2078) gets priority. NOT a DEFER: not an evidence gap, just a priority call.

**Date**: 2026-06-07T12:12:46Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-07T12:05:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-07T12:12:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Field-validated need 2026-06-06: ring20-dashboard recovery required SSH + git clone + explicit FRAMEWORK_ROOT=/PROJECT_ROOT= env scoping + fresh fw upgrade + cleanup — a 4-step recipe (per feedback_t2232_forward_looking_recovery memory). Shape is clear, evidence is the successful ring20 recovery this session, the wrapper is mechanical. No design ambiguity — needs only to be filed and scheduled. GO so the recipe becomes a one-liner before the next legacy-consumer incident; low priority (horizon:later) so V2 step-driver refactor (T-2078) gets priority. NOT a DEFER: not an evidence gap, just a priority call.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a6844b33
- **Timestamp:** 2026-06-07T12:12:47Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-6
     - evidence: `IW-6 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

### 2026-06-07T12:12:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
