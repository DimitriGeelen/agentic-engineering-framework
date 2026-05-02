---
id: T-1692
name: "v1 Pi backend integration — RPC mode wrapper for worker_kind=pi"
description: >
  v1 third-flavour Worker integration. Per CONTEXT.md (Q11): pi (github.com/badlogic/pi-mono) spawned in RPC mode (LF-delimited JSONL stdin/stdout); 23+ providers via API keys plus subscription-backed inference (Anthropic Pro/Max, OpenAI Plus/Pro, GitHub Copilot — $0/call on subscription quotas); built-in tools only, no native MCP. Inception scopes the RPC wrapper, error handling, telemetry parity with TermLink path, fw doctor pi-installed check (Q13).

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, pi, multi-provider]
components: []
related_tasks: [T-1687]
created: 2026-05-02T22:56:06Z
last_update: 2026-05-02T22:56:06Z
date_finished: null
---

# T-1692: v1 Pi backend integration — RPC mode wrapper for worker_kind=pi

## Problem Statement

pi (github.com/badlogic/pi-mono) is the third Worker flavour for **subscription-backed inference** — Anthropic Pro/Max, OpenAI Plus/Pro, GitHub Copilot, all at $0/call on subscription quotas. Per CONTEXT.md (Q11): pi runs in RPC mode (LF-delimited JSONL stdin/stdout); 23+ providers via API keys; built-in tools only (read/write/edit/bash/grep/find/ls), no native MCP. This inception scopes the RPC wrapper, error handling, telemetry parity with the TermLink path, and the `fw doctor` pi-installed check (Q13).

## Assumptions

- A-1: pi RPC mode (LF-delimited JSONL) is stable enough for v1 — protocol documented and test-covered upstream.
- A-2: Subscription-quota errors surface as parseable RPC error frames, not silent failures.
- A-3: pi's built-in tool set covers ≥80% of dispatchable workflows that operators want on subscription auth.
- A-4: pi auth-token storage doesn't conflict with the framework's existing credential management.

## Exploration Plan

- Spike S-1 (½ sess): install pi (npm or cargo); run `pi rpc` standalone; wire framework wrapper module (`lib/pi.py` or shell shim).
- Spike S-2 (½ sess): dispatch a simple research task via pi using subscription auth (Anthropic Pro), measure latency + cost ($0 expected).
- Spike S-3 (½ sess): error handling — induce quota-exceeded, verify error frame parses correctly, dispatch fails gracefully with retryable signal.

## Technical Constraints

- pi is intentionally machine-wide (npm install -g or cargo install). Distribution model contrasts with framework's per-project isolation — operator installs once.
- pi auth uses provider-specific OAuth flows — interactive at install time, but headless after initial setup.
- pi has no MCP support — workflows declaring `worker_kind: pi` cannot use MCP tools (resolver must validate this and warn at workflow-lint time, T-1694).

## Scope Fence

- IN: RPC wrapper module (`lib/pi.py` or shell shim); env handling; `fw doctor` pi-installed check (Q13); telemetry parity with TermLink (`worker_kind=pi` rows in `dispatches.jsonl` carry the same fields modulo `mcp_config`); auth setup documentation; quota-error detection.
- OUT: pi MCP support (none upstream yet); pi-specific specialist registry; auto-install from `claude-fw` bootstrap (Q13 rejected this — doctor warns, operator installs); pi-internal token management (delegated to pi).

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

**GO if:**
- RPC wrapper works end-to-end for at least one subscription-backed model (Anthropic Pro confirmed)
- Telemetry parity holds (same `dispatches.jsonl` schema, modulo MCP fields)
- `fw doctor` pi-installed check warns correctly when pi is missing
- Quota-error detection works (parseable, retryable signal)

**NO-GO if:**
- pi RPC instability >5% spurious failures over a representative dispatch batch
- Subscription auth requires interactive prompt that can't be scripted (defer pi to v2)
- pi's built-in tool set is too narrow to support common framework workflows (worker_kind=pi becomes unusable in practice)

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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
