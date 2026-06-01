---
id: T-1501
name: "Pickup: Extend verification-gate.sh: when task touches .vbproj/.xaml, require dotnet build (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-108. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [pickup, feature-proposal]
components: []
related_tasks: []
created: 2026-04-26T11:13:21Z
last_update: 2026-04-26T13:41:12Z
date_finished: 2026-04-27T12:09:29+02:00
source_task_id_in_origin: T-108
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1501: Pickup: Extend verification-gate.sh: when task touches .vbproj/.xaml, require dotnet build (from 003-NTB-ATC-Plugin)

## Problem Statement

**Toolchain-broken builds slip past P-011 verification when the task author forgets to write the build command into `## Verification`.**

Origin (003-NTB-ATC-Plugin / P-007 / T-108): T-077 closed work-completed with a broken WPF DLL on master. The .vbproj couldn't build on dev-box (missing `Microsoft.NET.Sdk`) or on Windows (missing .NET Framework 4.8 dev pack). Broken state sat in master 5 days until T-098 attempted to use the artifact. Agent ACs didn't include "dotnet build succeeds"; only a Human AC mentioned it, deferred. P-011 (verification gate) is shell-command-driven — the agent must remember to write the build command.

**Affects:** any consumer project where the agent edits compileable artifacts but omits the build command from `## Verification`. .NET is the immediate trigger; equivalent classes exist for Go, Rust, TypeScript, Java, Maven.

**Why now:** the trigger event already happened downstream (T-077 broken-build incident). Pickup is asking whether the framework should structurally prevent recurrence by inferring build requirements from file types, or stay toolchain-agnostic and rely on consumer discipline.

## Assumptions

- **A1:** A glob pattern (e.g. `*.vbproj`, `*.csproj`, `*.xaml`) reliably indicates "this task touched .NET code that must build". Falsifiable by sampling task histories: does .vbproj-touch correlate 1:1 with "needs dotnet build"? Edge cases: docs-only edits to a directory containing a .vbproj.
- **A2:** Detecting the toolchain trigger is cheap — a `git diff --name-only HEAD~..HEAD | grep -E '\.(vbproj|csproj|xaml)$'` at gate time. Falsifiable by timing on a real consumer repo.
- **A3:** Consumer projects can define their own toolchain mappings via `.framework.yaml` (e.g. `verification_triggers: { '*.vbproj': 'dotnet build' }`) without framework code changes. Falsifiable by sketching the config schema and checking it covers the .NET / Go / Rust cases without special-casing.
- **A4:** The framework can stay toolchain-agnostic (Portability directive #4) by making this a *consumer-config* feature rather than hard-coding `.vbproj → dotnet build` in framework source. Falsifiable: would the same config flow work for `*.go → go build`, `Cargo.toml → cargo check`, `tsconfig.json → tsc --noEmit`?
- **A5:** Pure documentation + a learning entry would NOT prevent recurrence — the next agent on the next .NET-flavoured project will hit the same trap. Falsifiable: count the prior bug-fix tasks where "agent forgot toolchain build in ## Verification" was the failure mode (need ≥2 to validate the structural-prevention case over per-task discipline).

## Exploration Plan

1. **Confirm A1+A2** (15 min) — script-spike on the framework repo: simulate a fictional `*.vbproj` edit, time `git diff | grep` at the verification gate. Confirm trigger reliability.
2. **Confirm A3** (20 min) — sketch the `.framework.yaml` schema for toolchain triggers. Try to express .NET, Go, Rust, TypeScript cases. Look for which cases need special handling vs. which fall out cleanly.
3. **Confirm A5 evidence** (10 min) — grep `learnings.yaml` and `concerns.yaml` for "forgot build" / "broken build" / "toolchain" patterns. Is T-077 the only instance, or is this systemic across consumers?
4. **Cost/benefit** (10 min) — if A4 holds (consumer-config), the framework change is ~30 LoC in `verification-gate.sh`. If not (hardcoded toolchain map), it's a long tail.
5. **Recommendation** (5 min).

## Technical Constraints

- **Toolchain-agnostic principle (Portability, directive #4):** the framework intentionally has no .NET, Go, Rust, etc. knowledge baked in. Hardcoding `.vbproj → dotnet build` violates this.
- **`verification-gate.sh` is already shell-driven:** the gate executes whatever lines the task author writes in `## Verification`. Adding "infer additional commands" changes the contract.
- **Cross-platform:** `dotnet`, `go`, `cargo` may not be installed on the host running `fw task update` (CI runner, framework-repo dev box). Inferred-but-failing commands would block on missing tooling.
- **No new framework dependency:** the fix must not require the framework to install/probe for toolchain SDKs.

## Scope Fence

**IN scope:**
- Decide whether the framework should infer toolchain build commands at the verification gate.
- If yes: scheme for declaring the inference (config vs. hardcoded vs. plugin).
- If no: alternative mitigation (template, learning entry, audit check, doctor warning).

**OUT of scope:**
- Implementing toolchain-specific build runners (separate build task post-GO).
- Fixing per-task verification omissions retroactively (those are individual incidents).
- Adding an `fw doctor` toolchain probe (separate concern — does the consumer's declared toolchain actually build at any time, not just at gate time).

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

**GO if:**
- A4 holds — the inference can be expressed via `.framework.yaml` consumer-config (toolchain map), keeping framework toolchain-agnostic
- A5 holds — evidence shows ≥2 instances of "agent forgot toolchain build in ## Verification" across consumers (systemic, not one-off)
- Implementation is bounded (≤50 LoC in verification-gate.sh + schema docs)

**NO-GO if:**
- Inference requires hardcoding toolchain knowledge into framework source (violates Portability)
- Only one instance exists (T-077) — per-task discipline + a learning entry is the cheaper, generalisable mitigation
- Cross-platform tooling availability makes the inferred command unreliable (false negatives where `dotnet` not on PATH but the task is legitimately complete on a different host)

**DEFER if:**
- Recurrence stays at 1 instance for ≥30 days post-T-077 — keep the option open without adding framework code yet

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

**Recommendation:** DEFER

**Rationale:** The bug is real and the structural-prevention case is honest, but two things weigh against immediate framework code:

1. **Toolchain-agnostic is load-bearing.** Hardcoding `*.vbproj → dotnet build` opens the long tail (`*.go`, `Cargo.toml`, `tsconfig.json`, `pom.xml`, ...). Each addition is a maintenance burden the framework can't actually validate (no .NET / Go / Rust test fixtures). Portability (directive #4) is one of four constitutional principles for a reason.

2. **Single-instance evidence.** T-077 is the only confirmed incident across all consumer projects audited. The systemic-prevention case requires ≥2 instances. One incident → learning + per-task discipline; ≥2 → structural fix. We're at 1.

The right path is documented mitigation now, structural fix later if the pattern repeats:
- **Now:** capture L-XXX learning ("agent edits *.vbproj/.csproj/.xaml → ## Verification MUST include `dotnet build`"). Add to the inception/build templates as a hint comment in `## Verification` for build/refactor tasks. Update CLAUDE.md §Verification with a "Toolchain build commands" subsection.
- **Watch:** if a second consumer hits the same class of bug within 30 days, promote DEFER → GO with the consumer-config schema (A3) as the implementation path.
- **Never:** hardcode `.vbproj → dotnet build` directly in `verification-gate.sh`.

**Evidence:**
- T-077 (003-NTB-ATC-Plugin): broken WPF DLL on master, 5 days undetected, single occurrence
- `learnings.yaml` grep: zero prior "forgot toolchain build" entries — pattern is not yet recurring
- Portability directive (CLAUDE.md): "No provider/language/environment lock-in; prefer standards"
- P-011 (`## Verification`) is intentionally a free-form shell-command list — the contract is "agent writes what must pass, framework runs it". Adding inferred commands changes the contract.
- T-115 inception (003-NTB-ATC-Plugin) already lists "Option 2 (convention-only)" as the cleaner design — that aligns with consumer-config (A3) when we get there.

**Alternative considered (REJECTED for now):** consumer-config map in `.framework.yaml`. Sound design, but premature without ≥2 instances. Adopting prematurely commits the framework to maintaining a config schema before we know what it should cover.

**Alternative considered (REJECTED):** hardcode `*.vbproj` detection in verification-gate.sh. Violates Portability directive. Single-toolchain solution to a multi-toolchain class of problem.

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

**Decision**: DEFER

**Rationale**: The bug is real and the structural-prevention case is honest, but two things weigh against immediate framework code:

1. Toolchain-agnostic is load-bearing. Hardcoding `*.vbproj → dotnet build` opens the long tail (`*.go`, `Cargo.toml`, `tsconfig.json`, `pom.xml`, ...). Each addition is a maintenance burden the framework can't actually validate (no .NET / Go / Rust test fixtures). Portability (directive #4) is one of four constitutional principles for a reason.

2. Single-instance evidence. T-077 is the only confirmed incident across all consumer projects audited. The systemic-prevention case requires ≥2 instances. One incident → learning + per-task discipline; ≥2 → structural fix. We're at 1.

The right path is documented mitigation now, structural fix later if the pattern repeats:
- Now: capture L-XXX learning ("agent edits *.vbproj/.csproj/.xaml → ## Verification MUST include `dotnet build`"). Add to the inception/build templates as a hint comment in `## Verification` for build/refactor tasks. Update CLAUDE.md §Verification with a "Toolchain build commands" subsection.
- Watch: if a second consumer hits the same class of bug within 30 days, promote DEFER → GO with the consumer-config schema (A3) as the implementation path.
- Never: hardcode `.vbproj → dotnet build` directly in `verification-gate.sh`.

**Date**: 2026-04-26T14:47:09Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-26T13:41:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-26T13:57:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** The bug is real and the structural-prevention case is honest, but two things weigh against immediate framework code:

1. Toolchain-agnostic is load-bearing. Hardcoding `*.vbproj → dotnet build` opens the long tail (`*.go`, `Cargo.toml`, `tsconfig.json`, `pom.xml`, ...). Each addition is a maintenance burden the framework can't actually validate (no .NET / Go / Rust test fixtures). Portability (directive #4) is one of four constitutional principles for a reason.

2. Single-instance evidence. T-077 is the only confirmed incident across all consumer projects audited. The systemic-prevention case requires ≥2 instances. One incident → learning + per-task discipline; ≥2 → structural fix. We're at 1.

The right path is documented mitigation now, structural fix later if the pattern repeats:
- Now: capture L-XXX learning ("agent edits *.vbproj/.csproj/.xaml → ## Verification MUST include `dotnet build`"). Add to the inception/build templates as a hint comment in `## Verification` for build/refactor tasks. Update CLAUDE.md §Verification with a "Toolchain build commands" subsection.
- Watch: if a second consumer hits the same class of bug within 30 days, promote DEFER → GO with the consumer-config schema (A3) as the implementation path.
- Never: hardcode `.vbproj → dotnet build` directly in `verification-gate.sh`.

### 2026-04-26T14:47:09Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** The bug is real and the structural-prevention case is honest, but two things weigh against immediate framework code:

1. Toolchain-agnostic is load-bearing. Hardcoding `*.vbproj → dotnet build` opens the long tail (`*.go`, `Cargo.toml`, `tsconfig.json`, `pom.xml`, ...). Each addition is a maintenance burden the framework can't actually validate (no .NET / Go / Rust test fixtures). Portability (directive #4) is one of four constitutional principles for a reason.

2. Single-instance evidence. T-077 is the only confirmed incident across all consumer projects audited. The systemic-prevention case requires ≥2 instances. One incident → learning + per-task discipline; ≥2 → structural fix. We're at 1.

The right path is documented mitigation now, structural fix later if the pattern repeats:
- Now: capture L-XXX learning ("agent edits *.vbproj/.csproj/.xaml → ## Verification MUST include `dotnet build`"). Add to the inception/build templates as a hint comment in `## Verification` for build/refactor tasks. Update CLAUDE.md §Verification with a "Toolchain build commands" subsection.
- Watch: if a second consumer hits the same class of bug within 30 days, promote DEFER → GO with the consumer-config schema (A3) as the implementation path.
- Never: hardcode `.vbproj → dotnet build` directly in `verification-gate.sh`.
