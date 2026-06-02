---
id: T-1104
name: "META-Inception: CLAUDE.md / fw help / code drift — structural enforcement of doc parity (G-035)"
description: >
  Inception task — investigate the recurring class of bug where CLAUDE.md Quick Reference + agent memory drifts from actual fw command surface (new flags, new subcommands, distribution model changes) and propose structural enforcement. This is the meta-pattern that subsumes G-025 (fw upgrade not surfaced), G-029 (termlink distribution undocumented), G-031 evidence #4 (fw vendor not in CLAUDE.md), AND the THIS-session incident: agent dispatched 4 TermLink workers in parallel without --task because CLAUDE.md Quick Reference table for fw termlink dispatch says '--name N --prompt P [--project DIR] [--model M]' — the required --task added by T-652 is missing. All 4 workers failed identically. Investigate: (1) audit CLAUDE.md Quick Reference table against fw help and bin/fw subcommand parsers — find every drift instance; (2) audit fw help against bin/fw — does fw help cover all subcommands? (3) audit subcommand --help against parser implementation; (4) sketch options for structural enforcement: (a) test that asserts CLAUDE.md table matches fw help, (b) auto-generate CLAUDE.md table from bin/fw introspection, (c) fw doctor doc-drift check, (d) CI step that regenerates docs on every fw change, (e) commit hook that flags doc-less feature commits; (5) recommend ONE remediation pattern with rationale. Origin: G-035 (META). Trigger: same-day triplet 2026-04-11 + this session's --task incident.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: [T-1093, G-035, T-652, T-630]
created: 2026-04-11T12:44:58Z
last_update: 2026-04-13T06:23:15Z
date_finished: 2026-04-12T10:41:08Z
---

# T-1104: META-Inception: CLAUDE.md / fw help / code drift — structural enforcement of doc parity (G-035)

## Problem Statement

This is a **meta-gap** that subsumes multiple individual gaps registered same day:
- **G-025** — `fw upgrade` exists and is the canonical onboarding command, but it's not in CLAUDE.md as such; agents reinvent the process
- **G-029** — termlink's machine-wide distribution model is not contrasted with framework's per-project model in CLAUDE.md
- **G-031 evidence #4** — `fw vendor` exists at `bin/fw:3359` ("Copy framework into project for full isolation") and is not in CLAUDE.md Quick Reference
- **THIS-session incident** — agent dispatched 4 TermLink workers in parallel without `--task`, all 4 failed identically with `Missing --task — TermLink workers require a task reference for governance (T-652, T-630)`. CLAUDE.md Quick Reference table for `fw termlink dispatch` says `--name N --prompt P [--project DIR] [--model M]`. The `--task` parameter is REQUIRED but NOT listed. T-652 added the requirement; CLAUDE.md was never updated. The same agent making the same dispatch four times in parallel is the canonical "stale doc cached in memory" failure mode.

**The class:** Framework features (new subcommands, new required flags, distribution model changes) get added without updating CLAUDE.md Quick Reference, agent memory, or sometimes even `fw help` and per-subcommand `--help`. Agents read CLAUDE.md as canonical, copy a stale form, and fail at invocation time. The framework correctly errors with a clear message — but the agent shouldn't have hit the error. The canonical reference lied.

**For whom:** Every agent operating on the framework. Every agent's session-start memory. Every consumer-project agent that reads CLAUDE.md as the single source of truth.

**Why now:** Three same-day incidents (2026-04-11) all of the same class, all caught by humans rather than by structural enforcement. The agent's memory has now cached at least three stale forms; the next session will repeat the same mistakes unless either (a) memory gets corrected explicitly per form OR (b) the framework structurally enforces parity.

**Severity:** High. Compounds with everything — every other gap that depends on agents reading CLAUDE.md correctly assumes CLAUDE.md is correct. If it's not, governance erodes silently.

## Assumptions

A-1: The drift is one-directional — code/help moves forward, CLAUDE.md and agent memory lag. The fix is at the doc-update or test-enforcement layer, not at the code layer. (Testable by sampling 10 recent fw subcommand changes and checking which surfaces were updated alongside.)

A-2: A single mechanism can catch all drift cases: a test that introspects `fw help` + `bin/fw` argument parsers and asserts they match the CLAUDE.md Quick Reference table. (Testable by sketching the test and running it against current state — count drift instances.)

A-3: Auto-generation of CLAUDE.md Quick Reference from `bin/fw` introspection is feasible — bash argparse / case-statement parsing is mechanical. (Testable by writing the introspector and comparing output to current hand-maintained table.)

A-4: An `fw doctor` doc-drift check is the right venue — it runs every session, surfaces warnings before they become bugs. (Testable by sketching the check and integrating with existing doctor output.)

A-5: A commit hook that flags "code change without doc update" is too noisy — most code changes don't affect public surface. Better at the surface layer (help text + Quick Reference). (Testable by sampling 20 recent fw commits and counting how many touched user-facing surface.)

A-6: Agent memory itself cannot be structurally enforced — the framework can update CLAUDE.md, but agent memory caches at session start and doesn't refresh. The fix has to live in the framework, not in the agent's persistence layer. (Acknowledgement, not testable in this inception.)

## Exploration Plan

**Phase 1 — Drift census.** Enumerate every drift instance currently in production. For each `fw <subcommand>`, compare: CLAUDE.md Quick Reference row → `fw help` line → `fw <subcommand> --help` (if it exists) → actual parser in `bin/fw` or `lib/<subcommand>.sh`. Count drifts. Sample by category: missing required flag, missing whole subcommand, stale parameter description.

**Phase 2 — T-652/T-630 history.** Read both task files and any episodic. When `--task` was added to `fw termlink dispatch`, what was the doc-update step? Was there one? If not, why not — process gap, oversight, or active decision?

**Phase 3 — Mechanism options.** Sketch each:
- (a) Test that asserts CLAUDE.md table == fw help (check-via-grep)
- (b) Auto-generate CLAUDE.md table from `bin/fw` introspection (one-way)
- (c) `fw doctor` doc-drift check (read-only warning)
- (d) CI step that regenerates docs on every fw-touching commit
- (e) Pre-commit hook that flags `bin/fw` or `lib/*.sh` changes without `CLAUDE.md` update

For each: cost, blast radius, false-positive rate, who maintains it.

**Phase 4 — Memory propagation.** How does the fix reach agent memory? Options: (a) accept stale memory and rely on framework error messages to correct it (status quo); (b) auto-write a "framework command surface changelog" memory entry on every release; (c) restructure CLAUDE.md so the Quick Reference row IS the source of truth for both agents and humans (auto-generated, agent reads it).

**Phase 5 — Recommendation.** Pick ONE mechanism + one memory strategy. Justify with cited drift census numbers and the same-day triplet evidence. GO Mechanism X / DEFER (accept current rate of drift) / NO-GO (drift is unavoidable, document it instead).

## Scope Fence

**IN scope:** RCA, drift census, mechanism sketches, recommendation. May read CLAUDE.md, `bin/fw`, all `lib/*.sh`, T-652, T-630. May write findings to `docs/reports/T-1104-doc-parity-rca.md`.

**OUT of scope:** Implementing any mechanism. Updating CLAUDE.md Quick Reference (that's a build task downstream). Updating agent memory directly (the agent's `.claude/memory` is per-user, out of band). Touching `bin/fw` or `lib/*.sh` except to read.

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
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Drift census confirms multiple instances of the same class (confirmed: 1 required-flag drift, 30+ missing commands)
- Mechanism is buildable in one session and has <20% false positive rate in fw doctor (confirmed for (c)+(f))
- The failure cost (4 parallel worker failures, sessions lost to stale forms) exceeds the fix cost

**NO-GO if:**
- Only a single isolated incident (disproved: 3 same-day incidents + this session = 4th instance)
- No feasible structural mechanism exists (disproved: (c)+(f) are both ~40-line changes)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** GO

**Rationale:** Three same-day incidents (G-025, G-031-F4, THIS-session) plus 4 identical parallel
worker failures confirm this is a recurring structural failure, not a one-off. The drift is
one-directional (code advances, docs lag), invisible to manual review (survived 2 explicit
doc-update passes on the same function), and self-perpetuating (authors copy the stale canonical
form). Two complementary mechanisms cover both failure classes at low cost and near-zero false
positive rate.

**Evidence:**
- Census: 1 required-flag drift (fw termlink dispatch, missing --task) across 2 surfaces (CLAUDE.md + fw termlink help); 30+ commands in fw help absent from CLAUDE.md Quick Reference; 0 phantom commands (drift is one-directional)
- T-652 (2026-03-28) added --task as REQUIRED: zero doc ACs, CLAUDE.md not in commit `280d2888`, in-binary help not updated. The task was framed as "enforcement change," not "CLI surface change" — documentation was invisible from that framing.
- Drift survived T-1063 (added --project, explicitly updated help + CLAUDE.md) and T-1065 (added --model, explicitly updated both) because authors copied the stale form and appended their new flag. The stale form self-perpetuates once in the canonical reference.
- Drift window: 14 days. Would repeat in the next session that uses fw termlink dispatch.
- Recommended mechanism: (c) fw doctor command-gap scan + (f) canonical-form comments in CLI functions. Combined cost ~1 day; blast radius zero (warnings); covers both missing-command and flag-level drift classes.
- Downstream build tasks needed: (1) add canonical-form comment + fix cmd_help() in termlink.sh; (2) add doctor doc-drift check in bin/fw; (3) fix CLAUDE.md Quick Reference row for fw termlink dispatch; (4) add highest-value missing commands to QR (fw upgrade, fw vendor, fw onboarding).

**Full research artifact:** `docs/reports/T-1104-doc-parity-rca.md`

## Structural Upgrade (added 2026-04-11 — chokepoint+test discipline pass per T-1105)

The worker's `(c) fw doctor doc-drift check + (f) canonical-form comments` is good but still relies on human authors copying canonical-form comments correctly. T-1104 IS the meta-pattern, but it can be made even more structural by making CLAUDE.md NOT the source of truth at all:

**Chokepoint (single source of truth):**
- The Quick Reference table in CLAUDE.md becomes **auto-generated** from `bin/fw` introspection. A script `scripts/regen-quick-reference.sh` walks the `case` statements in `bin/fw`, extracts subcommand names + flags + help text, and emits the markdown table. Run as part of `fw upgrade` (already syncs CLAUDE.md) and as a pre-commit hook. The hand-edited table is replaced with a `<!-- AUTO-GENERATED — do not edit -->` block.
- This eliminates "author copies stale form" because the canonical form comes from the code itself, not from a manually-maintained snapshot.

**Invariant test:**
- `tests/lint/quick-reference-fresh.bats` — runs the regen script in `--check` mode and asserts no diff. Fails CI if `bin/fw` was changed without regenerating the table.
- `tests/lint/all-fw-subcommands-documented.bats` — asserts every subcommand in `bin/fw` appears in the CLAUDE.md Quick Reference (closes the 30+ missing-commands gap the worker found).

**Per-flag enforcement (worker fix retained as fallback):**
- The `(f) canonical-form comments` proposal stays as a soft guard for the cases auto-gen can't reach (e.g., `--task` on `fw termlink dispatch` is required only when `TERMLINK_TASK_GOVERNANCE=1`). The comment becomes machine-readable: a structured `# CANONICAL: fw termlink dispatch --task TASK --name NAME --prompt PROMPT [--project DIR] [--model M]` block above each `cmd_*()` function, parsed by the regen script.

**Memory propagation:**
- Auto-gen alone doesn't update agent memory. Add a session-start hook that warns when CLAUDE.md Quick Reference has been regenerated since the last session (timestamp comparison) — invalidates the agent's cached form. Forces a re-read.

**Why this is more reliable:** `fw doctor` warns about drift; auto-gen makes drift impossible. The two combined make the meta-class structurally extinct. Worker's mechanism (c)+(f) catches drift; this upgrade prevents it.

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Three same-day incidents (G-025, G-031-F4, THIS-session) plus 4 identical parallel
worker failures confirm this is a recurring structural failure, not a one-off. The drift is
one-directional (code advances, docs lag), invisible to manual review (survived 2 explicit
doc-update passes on the same function), and self-perpetuating (authors copy the stale canonical
form). Two complementary mechanisms cover both failure classes at low cost and near-zero false
positive rate.

Evidence:
- Census: 1 required-flag drift (fw termlink dispatch, missing --task) across 2 surfaces (CLAUDE.md + fw termlink help); 30+ commands in fw help absent from CLAUDE.md Quick Reference; 0 phantom commands (drift is one-directional)
- T-652 (2026-03-28) added --task as REQUIRED: zero doc ACs, CLAUDE.md not in commit `280d2888`, in-binary help not updated. The task was framed as "enforcement change," not "CLI surface change" — documentation was invisible from that framing.
- Drift survived T-1063 (added --project, explicitly updated help + CLAUDE.md) and T-1065 (added --model, explicitly updated both) because authors copied the stale form and appended their new flag. The stale form self-perpetuates once in the canonical reference.
- Drift window: 14 days. Would repeat in the next session that uses fw termlink dispatch.
- Recommended mechanism: (c) fw doctor command-gap scan + (f) canonical-form comments in CLI functions. Combined cost ~1 day; blast radius zero (warnings); covers both missing-command and flag-level drift classes.
- Downstream build tasks needed: (1) add canonical-form comment + fix cmd_help() in termlink.sh; (2) add doctor doc-drift check in bin/fw; (3) fix CLAUDE.md Quick Reference row for fw termlink dispatch; (4) add highest-value missing commands to QR (fw upgrade, fw vendor, fw onboarding).

Full research artifact: `docs/reports/T-1104-doc-parity-rca.md`

**Date**: 2026-04-11T20:08:29Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Three same-day incidents (G-025, G-031-F4, THIS-session) plus 4 identical parallel
worker failures confirm this is a recurring structural failure, not a one-off. The drift is
one-directional (code advances, docs lag), invisible to manual review (survived 2 explicit
doc-update passes on the same function), and self-perpetuating (authors copy the stale canonical
form). Two complementary mechanisms cover both failure classes at low cost and near-zero false
positive rate.

Evidence:
- Census: 1 required-flag drift (fw termlink dispatch, missing --task) across 2 surfaces (CLAUDE.md + fw termlink help); 30+ commands in fw help absent from CLAUDE.md Quick Reference; 0 phantom commands (drift is one-directional)
- T-652 (2026-03-28) added --task as REQUIRED: zero doc ACs, CLAUDE.md not in commit `280d2888`, in-binary help not updated. The task was framed as "enforcement change," not "CLI surface change" — documentation was invisible from that framing.
- Drift survived T-1063 (added --project, explicitly updated help + CLAUDE.md) and T-1065 (added --model, explicitly updated both) because authors copied the stale form and appended their new flag. The stale form self-perpetuates once in the canonical reference.
- Drift window: 14 days. Would repeat in the next session that uses fw termlink dispatch.
- Recommended mechanism: (c) fw doctor command-gap scan + (f) canonical-form comments in CLI functions. Combined cost ~1 day; blast radius zero (warnings); covers both missing-command and flag-level drift classes.
- Downstream build tasks needed: (1) add canonical-form comment + fix cmd_help() in termlink.sh; (2) add doctor doc-drift check in bin/fw; (3) fix CLAUDE.md Quick Reference row for fw termlink dispatch; (4) add highest-value missing commands to QR (fw upgrade, fw vendor, fw onboarding).

Full research artifact: `docs/reports/T-1104-doc-parity-rca.md`

**Date**: 2026-04-11T20:08:29Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-11T20:08:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Three same-day incidents (G-025, G-031-F4, THIS-session) plus 4 identical parallel
worker failures confirm this is a recurring structural failure, not a one-off. The drift is
one-directional (code advances, docs lag), invisible to manual review (survived 2 explicit
doc-update passes on the same function), and self-perpetuating (authors copy the stale canonical
form). Two complementary mechanisms cover both failure classes at low cost and near-zero false
positive rate.

Evidence:
- Census: 1 required-flag drift (fw termlink dispatch, missing --task) across 2 surfaces (CLAUDE.md + fw termlink help); 30+ commands in fw help absent from CLAUDE.md Quick Reference; 0 phantom commands (drift is one-directional)
- T-652 (2026-03-28) added --task as REQUIRED: zero doc ACs, CLAUDE.md not in commit `280d2888`, in-binary help not updated. The task was framed as "enforcement change," not "CLI surface change" — documentation was invisible from that framing.
- Drift survived T-1063 (added --project, explicitly updated help + CLAUDE.md) and T-1065 (added --model, explicitly updated both) because authors copied the stale form and appended their new flag. The stale form self-perpetuates once in the canonical reference.
- Drift window: 14 days. Would repeat in the next session that uses fw termlink dispatch.
- Recommended mechanism: (c) fw doctor command-gap scan + (f) canonical-form comments in CLI functions. Combined cost ~1 day; blast radius zero (warnings); covers both missing-command and flag-level drift classes.
- Downstream build tasks needed: (1) add canonical-form comment + fix cmd_help() in termlink.sh; (2) add doctor doc-drift check in bin/fw; (3) fix CLAUDE.md Quick Reference row for fw termlink dispatch; (4) add highest-value missing commands to QR (fw upgrade, fw vendor, fw onboarding).

Full research artifact: `docs/reports/T-1104-doc-parity-rca.md`

### 2026-04-12T09:30:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T10:41:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Build task T-1147 completed — fw doctor doc-drift check added

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ef603e99
- **Timestamp:** 2026-06-02T14:55:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
